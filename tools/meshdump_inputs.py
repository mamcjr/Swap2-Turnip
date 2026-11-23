#!/usr/bin/env python3
"""meshdump_inputs.py <dirA> <dirB>: compares the mesh program's input buffers (DM_VK_MESH_DUMP in_<binding>.bin) of two drivers replaying one capture:
per draw and binding, the guest address and size (index.txt), how many 32-bit words differ, and the first differing words (as floats where they look like floats)."""
import sys, os, re
import numpy as np
A, B = sys.argv[1], sys.argv[2]
meta = {}
for line in open(os.path.join(A, 'index.txt'), encoding='utf-8', errors='replace'):
    m = re.match(r'(\S+_in_\d+\.bin) .*?; binding (\d+) (\w+) at (0x[0-9a-f]+) size (0x[0-9a-f]+|0)', line)
    if m: meta[m.group(1)] = m.groups()[1:]
for f in sorted(f for f in os.listdir(A) if re.search(r'_(t?in_\d+|groups|t?c0)\.bin$', f)):
    if not os.path.exists(os.path.join(B, f)): print(f, 'missing in B'); continue
    a, b = np.fromfile(os.path.join(A, f), np.uint32), np.fromfile(os.path.join(B, f), np.uint32)
    n = min(len(a), len(b)); d = np.nonzero(a[:n] != b[:n])[0]
    bnd, kind, addr, size = meta.get(f, ('?', '?', '?', '?'))
    print(f"{f}: binding {bnd} {kind} at {addr} size {size}, {n * 4} bytes dumped: {len(d)} words differ" + (f" (words {d[0]}-{d[-1]})" if len(d) else ""))
    for i in d[:6]:
        fa, fb = a[i:i+1].view(np.float32)[0], b[i:i+1].view(np.float32)[0]
        print(f"   word {i} (+{i*4:#x}): {a[i]:#010x} {fa:.6g}  vs  {b[i]:#010x} {fb:.6g}")
