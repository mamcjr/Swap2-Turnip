#!/bin/bash
# A Mesa worktree of the release's commit with the shipping patches only (0001, 0002, 0004) and, when asked, more patches after them: the tree a release-like
# Swap2-Turnip builds from, apart from the main checkout and its diagnostic 9xxx patches. Usage: rel-worktree.sh [extra patch numbers...] (e.g. 0005)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
P=/mnt/d/Projetos/Jogos/Android/turnip-swap2/patches
cd "$TS/mesa"
[ -d "$TS/mesa-rel" ] || git worktree add -q --detach "$TS/mesa-rel" 2648b2059f
cd "$TS/mesa-rel"
git checkout -q -- . && git clean -qfd
for n in 0001 0002 0004 "$@"; do
  f=$(ls $P/$n-*.patch); git apply "$f"; echo "applied $(basename "$f")"
done
git status --short | wc -l
