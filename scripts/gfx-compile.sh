#!/bin/bash
# Compile one vertex + fragment SPIR-V pair into a graphics pipeline with the PC build of Turnip as an Adreno 830 (drm-shim), printing ir3's statistics
# (and with IR3_SHADER_DEBUG=disasm the disassembly). usage: gfx-compile.sh <vertex.spv> <fragment.spv> [extra env...]
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
vs=$1; fs=$2; shift 2
lay=$T/$(basename "$vs").gfx.layout
{ python3 -I "$here/../tools/spv_layout.py" "$vs"; python3 -I "$here/../tools/spv_layout.py" "$fs"; } | grep -v '^entry' | sort -u > "$lay"
export LD_PRELOAD=$B/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so
export FD_GPU_ID=${FD_GPU_ID:-830}
export MESA_SHADER_CACHE_DISABLE=true
env TU_GFX_FS="$fs" "$@" "$T/tu_compile" "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$vs" "$lay"
