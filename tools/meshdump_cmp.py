#!/usr/bin/env python3
"""meshdump_cmp.py <dirA> <dirB>: compares DM_VK_MESH_DUMP files of two drivers replaying one capture (same file names).
For each draw and batch: the info block (word 0 the batch's workgroups, 10 tasks, 18 generated groups, 12 stride in words), the task payload,
and the mesh output word by word over the batch's workgroups: how many words differ, in how many workgroups, and at which offsets of a workgroup's slot
(as floats where they look like floats), so the outputs that differ (positions, attributes, primitive indices or counts) can be named."""
import sys, os, re, collections, struct
import numpy as np
A, B = sys.argv[1], sys.argv[2]
files = sorted(f for f in os.listdir(A) if f.endswith('.bin') and os.path.exists(os.path.join(B, f)))
def load(d, f): return np.fromfile(os.path.join(d, f), dtype=np.uint32)
for f in files:
    if '_info_' in f or '_payload' in f: continue
    m = re.match(r'f(\d+)_d(\d+)_out_b(\d+)\.bin', f)
    if not m: continue
    fr, dn, b = m.groups()
    ia, ib = load(A, f'f{fr}_d{dn}_info_b{b}.bin'), load(B, f'f{fr}_d{dn}_info_b{b}.bin')
    wa, sw = int(ia[0]), int(ia[12])
    print(f"== frame {fr} draw {dn} batch {b}: workgroups A {ia[0]} B {ib[0]}, tasks A {ia[10]} B {ib[10]}, groups A {ia[18]} B {ib[18]}, flags A {ia[17]} B {ib[17]}, stride {sw} words")
    if (ia[[0, 10, 18]] != ib[[0, 10, 18]]).any(): print("   the counts differ")
    pf = f'f{fr}_d{dn}_payload.bin'
    if b == '0' and os.path.exists(os.path.join(A, pf)):
        pa, pb = load(A, pf), load(B, pf); n = min(len(pa), len(pb)); d = np.nonzero(pa[:n] != pb[:n])[0]
        print(f"   payload: {len(d)} of {n} words differ" + (f", first at {d[0]}" if len(d) else ""))
    if not sw or not wa: continue
    oa, ob = load(A, f), load(B, f); n = min(wa * sw, len(oa), len(ob))
    a, bb = oa[:n].reshape(-1, sw), ob[:n].reshape(-1, sw)
    diff = a != bb
    fa, fb = a.view(np.float32), bb.view(np.float32)
    with np.errstate(all='ignore'): big = diff & ~(np.abs(fa - fb) <= 1e-3 * np.maximum(1, np.abs(fa)))
    print(f"   output: {diff.sum()} of {n} words differ in {diff.any(1).sum()} of {a.shape[0]} workgroups; {big.sum()} differ by more than 1e-3 relative (in {big.any(1).sum()} workgroups)")
    if big.any():
        off = collections.Counter(np.nonzero(big)[1].tolist())
        print("   offsets in the slot with large differences (offset: count):", ', '.join(f"{k}:{v}" for k, v in sorted(off.items())[:24]), '...' if len(off) > 24 else '')
        g, o = np.argwhere(big)[0]
        print(f"   first: workgroup {g} word {o}: A {a[g, o]:#010x} ({fa[g, o]:.6g}) B {bb[g, o]:#010x} ({fb[g, o]:.6g}); the slot's first 8 words A {[hex(x) for x in a[g, :8]]} B {[hex(x) for x in bb[g, :8]]}")
