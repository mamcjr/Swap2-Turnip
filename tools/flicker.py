#!/usr/bin/env python3
"""flicker.py <video.mp4> <out_prefix> [--crop x,y,w,h] [--thr 40]

Finds flicker in a screen recording of a still scene: pixels that change strongly from one game
frame to the next and come back in the frame after (A -> B -> A). Motion (a falling leaf) passes a
pixel once and does not come back, so it is not counted.

- Frames are decoded with ffmpeg at half resolution (grey and RGB), and repeated frames (the
  recording runs faster than the game) are dropped: a frame identical to the previous one within
  a small noise level is not a new game frame.
- For each triple of consecutive game frames f0, f1, f2: a pixel flickers when |f1 - f0| > thr,
  |f1 - f2| > thr, the two changes have the same sign, and |f2 - f0| < thr / 2.
- Writes <out_prefix>-heat.png (the count per pixel over the scene, red over the first frame),
  <out_prefix>-flash-<k>.png (the triple with the most flicker, side by side) and prints the
  per-triple fractions and the total.
"""
import subprocess, sys, argparse
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("video"); ap.add_argument("out")
ap.add_argument("--crop", default="")
ap.add_argument("--thr", type=int, default=40)
ap.add_argument("--scale", type=int, default=2)
a = ap.parse_args()

probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                        "-of", "csv=p=0", a.video], capture_output=True, text=True, check=True).stdout.strip().split(",")
W, H = int(probe[0]), int(probe[1])
vf = []
if a.crop:
    x, y, w, h = map(int, a.crop.split(",")); vf.append(f"crop={w}:{h}:{x}:{y}"); W, H = w, h
W2, H2 = W // a.scale, H // a.scale
vf.append(f"scale={W2}:{H2}:flags=area")
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", a.video, "-vf", ",".join(vf), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                     capture_output=True, check=True).stdout
n = len(raw) // (W2 * H2 * 3)
rgb = np.frombuffer(raw, np.uint8)[: n * W2 * H2 * 3].reshape(n, H2, W2, 3)
grey = (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114).astype(np.float32)

# drop repeated frames: a new game frame differs from the last kept one by more than encoder noise
keep = [0]
for i in range(1, n):
    d = np.abs(grey[i] - grey[keep[-1]])
    if (d > 12).mean() > 0.002:
        keep.append(i)
g = grey[keep]; c = rgb[keep]
print(f"{a.video}: {n} recorded frames, {len(keep)} game frames, {W2}x{H2}")

heat = np.zeros((H2, W2), np.int32)
fr = []
for k in range(len(g) - 2):
    d01 = g[k + 1] - g[k]; d21 = g[k + 1] - g[k + 2]; d02 = np.abs(g[k + 2] - g[k])
    m = (np.abs(d01) > a.thr) & (np.abs(d21) > a.thr) & (np.sign(d01) == np.sign(d21)) & (d02 < a.thr / 2)
    heat += m
    fr.append(m.mean())
fr = np.array(fr)
print("flicker fraction per triple (%):", " ".join(f"{100*x:.3f}" for x in fr))
print(f"mean {100*fr.mean():.4f} %  max {100*fr.max():.4f} %  pixels flickering at least twice: {(heat >= 2).sum()}  at least 3x: {(heat >= 3).sum()}")

base = c[0].astype(np.float32) * 0.45
hm = np.clip(heat / max(1, heat.max()), 0, 1)
over = base.copy(); over[..., 0] = np.maximum(over[..., 0], hm * 255 * (heat > 0)); over[..., 1] *= 1 - 0.8 * (heat > 0); over[..., 2] *= 1 - 0.8 * (heat > 0)
Image.fromarray(over.astype(np.uint8)).save(a.out + "-heat.png")
if len(fr):
    k = int(fr.argmax())
    Image.fromarray(np.concatenate([c[k], c[k + 1], c[k + 2]], axis=1)).save(a.out + f"-flash-{k}.png")
