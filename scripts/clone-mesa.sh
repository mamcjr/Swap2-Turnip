#!/bin/bash
# Blobless clone of upstream Mesa (history without file contents; blobs come on checkout)
set -euo pipefail
TS=${TS:-$HOME/turnip-swap2}
cd "$TS"
if [ ! -d mesa/.git ]; then
  git clone --filter=blob:none --no-checkout https://gitlab.freedesktop.org/mesa/mesa.git mesa
fi
cd mesa
git checkout -q 2648b2059f
git log -1 --format='%H %cd %s' 
git describe --tags --always 2>/dev/null || true
du -sh .git . 
