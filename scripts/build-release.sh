#!/bin/bash
# The Swap2-Turnip release zip: a clean mesa-rel worktree with the shipping patches (rel-worktree.sh: 0001, 0002, 0004, then 0005), built by
# build-android.sh into build-android-rel and named out/Swap2-Turnip-2648b2059f-release.zip. An older release zip is kept as -release-<date>.zip.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
OUT=/mnt/d/Projetos/Jogos/Android/turnip-swap2/out
bash "$here/rel-worktree.sh" 0005
rel=$OUT/Swap2-Turnip-2648b2059f-release.zip
[ -f "$rel" ] && cp --update=none "$rel" "$OUT/Swap2-Turnip-2648b2059f-release-$(date -r "$rel" +%Y%m%d).zip"
stage=$(mktemp -d)
SRC=$TS/mesa-rel BUILD=$TS/build-android-rel OUT=$stage bash "$here/build-android.sh" Swap2-Turnip "Turnip built by Swap2-Native, A8xx Android/KGSL, release (patches 0001 0002 0004 0005)" | tail -3
z=$(ls "$stage"/*.zip); cp "$z" "$rel"; rm -rf "$stage"
python3 -c "import sys,zipfile; print(zipfile.ZipFile(sys.argv[1]).read('meta.json').decode())" "$rel"; sha256sum "$rel"
