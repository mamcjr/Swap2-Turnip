#!/bin/bash
# the shared-memory probe: SPIR-V for 64 KiB and 32 KiB, its layout, and the arm64 harness, into out/phone
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
O=/mnt/d/Projetos/Jogos/Android/turnip-swap2/out/phone
for w in 16384 8192; do
  glslangValidator -V --target-env vulkan1.1 -DWORDS=$w -o $O/shm$w.spv "$here/../tools/shm_probe.comp" | tail -1
done
python3 -I "$here/../tools/spv_layout.py" $O/shm16384.spv > $O/shm.layout; cat $O/shm.layout
bash "$here/build-phone-probe.sh" > /dev/null && cp "$TS/phone/tu_compile" $O/
# and on the PC (drm-shim compiles but cannot run): compile check only
