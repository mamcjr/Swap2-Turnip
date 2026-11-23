#!/usr/bin/env python3
"""meshdump_match.py <dirA> <dirB>: like meshdump_cmp.py, but matches each workgroup slot of A to its nearest slot of B (any position), so a different order of the
same meshlets is told apart from different contents. Prints, per draw and batch, how many of A's slots have an equal (1e-3 relative) slot in B, and at which slot."""
import sys, os, re
import numpy as np
A, B = sys.argv[1], sys.argv[2]
def load(d, f): return np.fromfile(os.path.join(d, f), dtype=np.uint32)
for f in sorted(os.listdir(A)):
    m = re.match(r'f(\d+)_d(\d+)_out_b(\d+)\.bin', f)
    if not m or not os.path.exists(os.path.join(B, f)): continue
    fr, dn, b = m.groups()
    ia, ib = load(A, f'f{fr}_d{dn}_info_b{b}.bin'), load(B, f'f{fr}_d{dn}_info_b{b}.bin')
    wa, wb, sw = int(ia[0]), int(ib[0]), int(ia[12])
    if not sw or not wa: continue
    a = np.fromfile(os.path.join(A, f), dtype=np.float32, count=wa * sw).reshape(wa, sw)
    bb = np.fromfile(os.path.join(B, f), dtype=np.float32, count=wb * sw).reshape(wb, sw)
    k = min(sw, 256)   # match on the slot's first words (the first vertices' positions)
    same = moved = 0; worst = []
    for i in range(wa):
        with np.errstate(all='ignore'):
            d = np.abs(bb[:, :k] - a[i, :k]) > 1e-3 * np.maximum(1, np.abs(a[i, :k]))
            d |= np.isnan(bb[:, :k]) != np.isnan(a[i, :k])
        n = d.sum(1); j = int(n.argmin())
        if n[j] == 0:
            same += 1; moved += j != i
        else: worst.append((int(n[j]), i, j))
    worst.sort()
    print(f"draw {dn} batch {b}: {wa} workgroups (B {wb}); {same} have an equal slot in B ({moved} of them at another slot); {len(worst)} have none"
          + (f", nearest differs in {worst[0][0]}-{worst[-1][0]} of {k} words" if worst else ""))
