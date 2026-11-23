#!/bin/bash
# Compile one SPIR-V compute module with the PC build of Turnip as an Adreno 830 (drm-shim).
# usage: run-compile.sh <module.spv> [extra env...]; MMAP_LIKE_SCUDO=1 makes glibc map every
# allocation of 64 KiB or more on its own (as Android's scudo secondary allocator does), so the
# peak mapping count approximates the phone's.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
TS=${TS:-$HOME/turnip-swap2}
B=${BUILD:-$TS/build-host}
T=$TS/tools-bin
mkdir -p "$T"
src=$here/../tools/tu_compile.c
if [ ! -x "$T/tu_compile" ] || [ "$src" -nt "$T/tu_compile" ]; then
  clang -O1 -g -I"$TS/mesa/include" -o "$T/tu_compile" "$src" -ldl -lpthread
fi
spv=$1; shift
lay=$T/$(basename "$spv").layout
python3 -I "$here/../tools/spv_layout.py" "$spv" > "$lay"
export LD_PRELOAD=$B/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so
export FD_GPU_ID=${FD_GPU_ID:-830}
export MESA_SHADER_CACHE_DISABLE=true
[ "${MMAP_LIKE_SCUDO:-0}" = 1 ] && export MALLOC_MMAP_THRESHOLD_=65536
env "$@" /usr/bin/time -v "$T/tu_compile" "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$spv" "$lay" 2>&1 | grep -E "^result|^rss|^device|Maximum resident|Elapsed|error|Assert|assert|Segmentation|signal|ir3|fail" | head -40
