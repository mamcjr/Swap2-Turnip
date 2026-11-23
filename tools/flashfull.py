#!/usr/bin/env python3
"""flashfull.py <video> <out.png> <triple>: frames A, B (the flash), C of a game-frame triple at recording resolution, stacked, plus |B - (A+C)/2| amplified."""
import subprocess, sys
import numpy as np
from PIL import Image
v, out, K = sys.argv[1], sys.argv[2], int(sys.argv[3])
W, H = map(int, subprocess.run(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=width,height","-of","csv=p=0",v],capture_output=True,text=True).stdout.strip().split(","))
raw = subprocess.run(["ffmpeg","-v","error","-i",v,"-f","rawvideo","-pix_fmt","rgb24","-"],capture_output=True).stdout
n = len(raw)//(W*H*3); rgb = np.frombuffer(raw,np.uint8)[:n*W*H*3].reshape(n,H,W,3)
g = rgb[:, ::2, ::2].astype(np.float32).mean(-1)
keep=[0]
for i in range(1,n):
    if (np.abs(g[i]-g[keep[-1]])>12).mean()>0.002: keep.append(i)
a,b,c = (rgb[keep[K+j]].astype(np.float32) for j in range(3))
d = np.clip(np.abs(b-(a+c)/2).mean(-1)*4,0,255).astype(np.uint8)
img = np.concatenate([a,b,c,np.stack([d]*3,-1)],0).astype(np.uint8)
Image.fromarray(img).save(out)
