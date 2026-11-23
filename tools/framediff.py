#!/usr/bin/env python3
"""Frame-to-frame differences of raw `screencap` captures (12- or 16-byte header, RGBA8888).
For each consecutive pair: share of sampled pixels (every 4th in x and y, inside the game area) that changed by more
than 48 in any channel. Flicker shows as pairs with many more changed pixels than the scene's own motion."""
import sys, glob, struct
files = sorted(glob.glob(sys.argv[1] + "/raw*.bin"))
def load(p):
    b = open(p, "rb").read()
    w, h, f = struct.unpack("<III", b[:12])
    hdr = len(b) - w * h * 4
    return w, h, b[hdr:]
prev = None
for p in files:
    w, h, px = load(p)
    if prev:
        pw, ph, pp = prev
        x0, x1 = int(w * 0.12), int(w * 0.88)   # skip the black bars and on-screen buttons' outer columns
        n = ch = 0
        for y in range(int(h * 0.08), h, 4):
            row = y * w * 4
            for x in range(x0, x1, 4):
                i = row + x * 4
                n += 1
                if abs(px[i] - pp[i]) > 48 or abs(px[i + 1] - pp[i + 1]) > 48 or abs(px[i + 2] - pp[i + 2]) > 48:
                    ch += 1
        print(f"{p[-9:]}: {100.0 * ch / n:5.2f} % changed")
    prev = (w, h, px)
