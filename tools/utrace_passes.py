"""Where a Turnip frame's GPU time goes, from u_trace's CSV (MESA_GPU_TRACES=print_csv, MESA_GPU_TRACEFILE).

usage: python utrace_passes.py <ut.csv> [--skip N] [--top N]

Pairs every start_X / end_X range, takes the top-level ranges of each frame (render passes, compute dispatches, blits, ...)
and prints, as averages per frame over the complete frames in the file (the first --skip and the last one left out):
  - the frame's GPU span, the sum of its top-level ranges and the gaps between them (GPU idle or waiting between ranges);
  - per kind of top-level range: time and count;
  - render passes grouped by size / attachments / mode / reason: time, count, draws, loads and stores, LRZ;
  - inside render passes: binning, draw IBs, GMEM loads / stores, sysmem clears;
  - the compute shaders (cs_sha1) that take the most time.
The trace's own timestamps add a little work to every range; compare shares, not absolute times, with an untraced run.
"""
import argparse
import collections
import re
import sys

KV = re.compile(r'(\w+)=(.*?)(?=, \w+=|, ctx=\d+$|$)')


def parse(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            p = line.rstrip('\n').split(',', 4)
            if len(p) < 4 or not p[0].isdigit():
                continue
            frame, batch, ns, ev = int(p[0]), int(p[1]), int(p[2]), p[3]
            rest = p[4] if len(p) > 4 else ''
            m = re.search(r'ctx=(\d+)$', rest)
            ctx = int(m.group(1)) if m else 0
            args = dict(KV.findall(rest))
            yield frame, batch, ns, ev, args, ctx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('csv')
    ap.add_argument('--skip', type=int, default=1)
    ap.add_argument('--top', type=int, default=25)
    ap.add_argument('--frames', type=float, help="when the file has one frame number for everything (Turnip's u_trace without frame boundaries: 0 throughout), the game frames it covers (the window's span times the run's fps): averages per frame divide by this")
    a = ap.parse_args()

    # per (ctx, frame): list of closed ranges (name, start, end, start args, end args, depth)
    frames = collections.defaultdict(list)
    stacks = collections.defaultdict(list)
    for frame, batch, ns, ev, args, ctx in parse(a.csv):
        if ev.startswith('start_'):
            stacks[ctx].append((ev[6:], ns, args, frame))
        elif ev.startswith('end_'):
            name = ev[4:]
            st = stacks[ctx]
            # close the innermost open range of that name (ranges nest)
            for i in range(len(st) - 1, -1, -1):
                if st[i][0] == name:
                    n, t0, sa, fr = st.pop(i)
                    frames[(ctx, fr)].append((name, t0, ns, sa, args, i))
                    break
    if not frames:
        sys.exit('no ranges in the file')
    keys = sorted(frames)
    # one context is the game's; take the one with the most ranges
    ctxc = collections.Counter(k[0] for k in keys for _ in frames[k])
    ctx = ctxc.most_common(1)[0][0]
    fr = sorted(k[1] for k in keys if k[0] == ctx)
    use = fr[a.skip:-1] if len(fr) > a.skip + 1 else fr
    n = len(use)
    if len(fr) == 1 and a.frames:   # one block for the whole window
        use = fr; n = a.frames
    print(f'context {ctx}: {len(fr)} frames in the file, {n} used ({use[0]}..{use[-1]})\n')

    span = busy = gaps = 0.0
    kind = collections.Counter(); kindn = collections.Counter()
    rp = collections.defaultdict(lambda: [0.0, 0, 0, collections.Counter(), collections.Counter()])
    sub = collections.Counter(); subn = collections.Counter()
    cs = collections.Counter(); csn = collections.Counter(); csdim = {}
    lrzr = collections.Counter()
    for f in use:
        rs = sorted(frames[(ctx, f)], key=lambda r: r[1])
        if not rs:
            continue
        # top-level: not contained in the cmd_buffer ranges' children logic; take ranges at stack depth 1 inside cmd_buffer
        # (depth 0 is cmd_buffer itself) or depth 0 when not a cmd_buffer.
        top = [r for r in rs if (r[5] == 1 and r[0] != 'cmd_buffer') or (r[5] == 0 and r[0] != 'cmd_buffer')]
        top.sort(key=lambda r: r[1])
        if not top:
            continue
        span += (max(r[2] for r in top) - top[0][1]) / 1e6
        end = top[0][1]
        for r in top:
            d = (r[2] - r[1]) / 1e6
            busy += d; kind[r[0]] += d; kindn[r[0]] += 1
            if r[1] > end:
                gaps += (r[1] - end) / 1e6
            end = max(end, r[2])
            if r[0] == 'render_pass':
                s, e = r[3], r[4]
                key = (f"{s.get('width')}x{s.get('height')}", s.get('attachment_count'), 'gmem' if e.get('tiledRender') == 'true' else 'sysmem',
                       e.get('forceRenderModeReason') or 'autotune', s.get('numberOfBins'), s.get('hasDepth'))
                g = rp[key]; g[0] += d; g[1] += 1; g[2] += int(e.get('drawCount') or 0)
                g[3][f"L{s.get('loadCPP')}/S{s.get('storeCPP')}/C{s.get('clearCPP')}"] += 1
                g[4]['lrz' if e.get('lrz') == 'true' else 'nolrz'] += 1
                if e.get('lrzDisableReason'):
                    lrzr[e.get('lrzDisableReason')] += 1
            if r[0] in ('compute', 'compute_indirect'):
                k = r[3].get('cs_sha1', '?')[:16]
                cs[k] += d; csn[k] += 1
                csdim.setdefault(k, f"{r[3].get('local_size_x')}x{r[3].get('local_size_y')}x{r[3].get('local_size_z')}")
        for r in rs:
            if r[0] in ('binning_ib', 'concurrent_binning_ib', 'draw_ib_gmem', 'draw_ib_sysmem', 'gmem_load', 'gmem_store',
                        'sysmem_clear', 'sysmem_clear_all', 'gmem_clear', 'sysmem_resolve', 'concurrent_binning_barrier'):
                k = r[0] + (f" {r[3].get('format')}" if r[3].get('format') else '')
                sub[k] += (r[2] - r[1]) / 1e6; subn[k] += 1

    pf = lambda x: x / n
    print(f'per frame: GPU span {pf(span):.2f} ms, top-level ranges {pf(busy):.2f} ms, gaps between them {pf(gaps):.2f} ms\n')
    print('| top-level range | ms/frame | count/frame |\n|---|---|---|')
    for k, v in kind.most_common():
        print(f'| {k} | {pf(v):.2f} | {pf(kindn[k]):.1f} |')
    print('\n| render pass (size, attachments, mode, reason, bins, depth) | ms/frame | count/frame | draws/pass | load/store/clear cpp | lrz |\n|---|---|---|---|---|---|')
    for k, g in sorted(rp.items(), key=lambda kv: -kv[1][0])[:a.top]:
        print(f'| {" ".join(str(x) for x in k)} | {pf(g[0]):.2f} | {pf(g[1]):.1f} | {g[2] / max(g[1], 1):.1f} | '
              f'{", ".join(f"{x} x{c}" for x, c in g[3].most_common(3))} | {", ".join(f"{x} {c}" for x, c in g[4].items())} |')
    print('\n| inside render passes | ms/frame | count/frame |\n|---|---|---|')
    for k, v in sub.most_common(a.top):
        print(f'| {k} | {pf(v):.2f} | {pf(subn[k]):.1f} |')
    print('\n| compute shader (cs_sha1, local size) | ms/frame | dispatches/frame | us/dispatch |\n|---|---|---|---|')
    for k, v in cs.most_common(a.top):
        print(f'| {k} {csdim[k]} | {pf(v):.2f} | {pf(csn[k]):.1f} | {1000 * v / csn[k]:.0f} |')
    if lrzr:
        print('\nLRZ disabled (render passes, whole file window):')
        for k, v in lrzr.most_common(15):
            print(f'- {v}: {k}')


if __name__ == '__main__':
    main()
