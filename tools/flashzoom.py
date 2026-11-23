#!/usr/bin/env python3
"""flashzoom.py <video> <out_prefix> <triple index> [thr]: the A->B->A pixels of one game-frame triple at full resolution:
where they are (bounding boxes of the largest clusters) and crops of the three frames around the largest one."""
import subprocess, sys
import numpy as np
from PIL import Image
v, out, K = sys.argv[1], sys.argv[2], int(sys.argv[3]); thr = int(sys.argv[4]) if len(sys.argv) > 4 else 40
W, H = map(int, subprocess.run(["ffprobe","-v","error","-select_streams","v:0","-show_entries","stream=width,height","-of","csv=p=0",v],capture_output=True,text=True).stdout.strip().split(","))
raw = subprocess.run(["ffmpeg","-v","error","-i",v,"-f","rawvideo","-pix_fmt","rgb24","-"],capture_output=True).stdout
n = len(raw)//(W*H*3); rgb = np.frombuffer(raw,np.uint8)[:n*W*H*3].reshape(n,H,W,3)
g = (rgb[...,0]*.299+rgb[...,1]*.587+rgb[...,2]*.114).astype(np.float32)
small = g[:, ::2, ::2]
keep=[0]
for i in range(1,n):
    if (np.abs(small[i]-small[keep[-1]])>12).mean()>0.002: keep.append(i)
a,b,c = (g[keep[K+j]] for j in range(3)); ca,cb,cc = (rgb[keep[K+j]] for j in range(3))
d01=b-a; d21=b-c; m=(np.abs(d01)>thr)&(np.abs(d21)>thr)&(np.sign(d01)==np.sign(d21))&(np.abs(c-a)<thr/2)
print(f"triple {K}: recorded frames {keep[K]},{keep[K+1]},{keep[K+2]}; {m.sum()} pixels ({100*m.mean():.3f} %), brighter in B: {(m&(d01>0)).sum()}, darker: {(m&(d01<0)).sum()}")
# coarse grid of where they are
gs=40; hy,hx=H//gs,W//gs; grid=m[:hy*gs,:hx*gs].reshape(hy,gs,hx,gs).sum((1,3))
for yy,xx in sorted(zip(*np.nonzero(grid)), key=lambda t:-grid[t])[:8]: print(f"  cell x {xx*gs}-{xx*gs+gs} y {yy*gs}-{yy*gs+gs}: {grid[yy,xx]}")
yy,xx = np.unravel_index(grid.argmax(), grid.shape); cy,cx = yy*gs+gs//2, xx*gs+gs//2
x0=max(0,min(W-320,cx-160)); y0=max(0,min(H-200,cy-100))
crop=lambda im: Image.fromarray(im[y0:y0+200,x0:x0+320]).resize((640,400),Image.NEAREST)
mm=np.zeros_like(ca); mm[m]=(255,0,0)
row=Image.new("RGB",(640*4+30,400),(255,255,255))
for j,im in enumerate([ca,cb,cc,mm]): row.paste(crop(im),(j*(640+10),0))
row.save(out+f"-zoom-{K}.png"); print("crop at", x0, y0)
