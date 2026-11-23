#!/usr/bin/env python3
"""diffmap.py <folder> <out.png>: over raw screencap frames, a quarter-size image of the first frame, darkened, with every
pixel that changed by more than 48 in some consecutive pair painted red (brighter = changed in more pairs). Standard library only."""
import sys, glob, struct, zlib

files = sorted(glob.glob(sys.argv[1] + "/raw*.bin"))
frames = []
for p in files:
    b = open(p, "rb").read()
    w, h = struct.unpack("<II", b[:8])
    frames.append(b[len(b) - w * h * 4:])
S = 4
ow, oh = w // S, h // S
count = [0] * (ow * oh)
for a, c in zip(frames, frames[1:]):
    for oy in range(oh):
        row = oy * S * w * 4
        for ox in range(ow):
            i = row + ox * S * 4
            if abs(a[i] - c[i]) > 48 or abs(a[i + 1] - c[i + 1]) > 48 or abs(a[i + 2] - c[i + 2]) > 48:
                count[oy * ow + ox] += 1
base = frames[0]
raw = bytearray()
for oy in range(oh):
    raw.append(0)
    row = oy * S * w * 4
    for ox in range(ow):
        i = row + ox * S * 4
        n = count[oy * ow + ox]
        if n:
            v = min(255, 90 + 40 * n)
            raw += bytes((v, 0, 0))
        else:
            raw += bytes((base[i] // 3, base[i + 1] // 3, base[i + 2] // 3))
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", ow, oh, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b"")
open(sys.argv[2], "wb").write(png)
print("pairs", len(frames) - 1, "changed pixels", sum(1 for x in count if x), "of", ow * oh, "; changed in 3+ pairs", sum(1 for x in count if x >= 3))
