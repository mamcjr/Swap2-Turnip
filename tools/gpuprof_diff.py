"""Where two runs' GPU frames differ, step by step, from the host's own profiler (DM_VK_GPUPROF=<n> with DM_VK_GPUPROF_LIST=1: `gpu prof: frame` and
`gpu prof: step` lines in the app's log.txt).

usage: python gpuprof_diff.py <log A> <log B> [--last N] [--top N] [--names A B]

Each timed frame's steps get a key: the step's site, its pass (size and attachments) and its first shaders, and the how-many-th step with that signature in
the frame. Per key, the mean time over the last N full frames of each log (frames with at least half the most timestamps). Prints the frame totals, the
time by site kind and the keys whose time differs most between the two, so the same work on two drivers lines up.
"""
import argparse
import collections
import re

STEP = re.compile(r'gpu prof: step #(\d+) ([0-9.]+) ms: (.*)$')
FRAME = re.compile(r'gpu prof: frame (\d+): (\d+) timestamps, ([0-9.]+) ms GPU')


def frames_of(path):
    frames = []   # (frame, timestamps, total ms, [(sig, ms)])
    cur = None
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = FRAME.search(line)
            if m:
                cur = (int(m.group(1)), int(m.group(2)), float(m.group(3)), [])
                frames.append(cur)
                continue
            m = STEP.search(line)
            if m and cur is not None:
                rest = m.group(3)
                site = rest.split(',')[0].strip()
                draws = re.search(r'(\d+) draws', rest)
                pas = re.search(r'pass (\S+)', rest)
                vs = re.search(r'\bvs ([0-9a-f]{16})', rest)
                fs = re.search(r'\bfs ([0-9a-f]{16})', rest)
                ms_ = re.search(r'\b(?:ms|mesh) ([0-9a-f]{16})', rest)
                cs = re.search(r'\bcs ([0-9a-f]{16})', rest)
                sig = (site, pas.group(1) if pas else '', (vs.group(1) if vs else '') + (fs.group(1) if fs else '') + (ms_.group(1) if ms_ else '') + (cs.group(1) if cs else ''))
                cur[3].append((sig, float(m.group(2)), rest, int(draws.group(1)) if draws else 0))
    return frames


def summarize(path, last):
    fr = [f for f in frames_of(path) if f[3]]
    if not fr:
        raise SystemExit(f'{path}: no timed frames with steps')
    most = max(f[1] for f in fr)
    full = [f for f in fr if f[1] >= most / 2][-last:]
    per = collections.defaultdict(float); text = {}; draws = {}
    kind = collections.Counter()
    for f in full:
        seen = collections.Counter()
        for sig, ms, rest, d in f[3]:
            seen[sig] += 1
            k = sig + (seen[sig],)
            per[k] += ms; text.setdefault(k, rest[:160]); draws[k] = d
            kind[sig[0].split(':')[0] + (' (pass)' if sig[1] else '')] += ms
    n = len(full)
    return {k: v / n for k, v in per.items()}, text, {k: v / n for k, v in kind.items()}, n, sum(f[2] for f in full) / n, [f[0] for f in full]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('a'); ap.add_argument('b')
    ap.add_argument('--last', type=int, default=20)
    ap.add_argument('--top', type=int, default=30)
    ap.add_argument('--names', nargs=2, default=['A', 'B'])
    a = ap.parse_args()
    A, ta, ka, na, tota, fa = summarize(a.a, a.last)
    B, tb, kb, nb, totb, fb = summarize(a.b, a.last)
    na_, nb_ = a.names
    print(f'{na_}: {na} frames ({fa[0]}..{fa[-1]}), GPU {tota:.2f} ms a frame, steps summed {sum(A.values()):.2f}')
    print(f'{nb_}: {nb} frames ({fb[0]}..{fb[-1]}), GPU {totb:.2f} ms a frame, steps summed {sum(B.values()):.2f}')
    keys = set(A) | set(B)
    common = [k for k in keys if k in A and k in B]
    print(f'keys: {len(A)} / {len(B)}, {len(common)} in both; time in keys of one run only: {sum(v for k, v in A.items() if k not in B):.2f} / {sum(v for k, v in B.items() if k not in A):.2f} ms\n')
    print(f'| site kind | {na_} ms | {nb_} ms | difference |\n|---|---|---|---|')
    for k in sorted(set(ka) | set(kb), key=lambda k: -abs(ka.get(k, 0) - kb.get(k, 0))):
        x, y = ka.get(k, 0), kb.get(k, 0)
        if max(x, y) >= 0.05:
            print(f'| {k} | {x:.2f} | {y:.2f} | {x - y:+.2f} |')
    print(f'\n| step (site, pass, shaders, n-th) | {na_} ms | {nb_} ms | difference | step |\n|---|---|---|---|---|')
    for k in sorted(common, key=lambda k: -abs(A[k] - B[k]))[:a.top]:
        print(f'| {k[0]} {k[1]} {k[2][:16]} #{k[3]} | {A[k]:.3f} | {B[k]:.3f} | {A[k] - B[k]:+.3f} | {ta[k][:110]} |')
    # the same grouped by the step's first shaders (a pass's work across its occurrences)
    g = collections.defaultdict(lambda: [0.0, 0.0, 0])
    for k in common:
        s = g[(k[0], k[1], k[2][:16])]; s[0] += A[k]; s[1] += B[k]; s[2] += 1
    print(f'\n| grouped (site, pass, first shader) | {na_} ms | {nb_} ms | difference | steps |\n|---|---|---|---|---|')
    for k, s in sorted(g.items(), key=lambda kv: -abs(kv[1][0] - kv[1][1]))[:a.top]:
        print(f'| {k[0]} {k[1]} {k[2]} | {s[0]:.3f} | {s[1]:.3f} | {s[0] - s[1]:+.3f} | {s[2]} |')


if __name__ == '__main__':
    main()
