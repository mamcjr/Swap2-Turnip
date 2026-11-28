#!/bin/bash
# Offline compile of one compute module as an Adreno 830 (drm-shim) with the main PC build and with the release-like build plus 0005 (build-host-rel): the result,
# time, and in the disassembly the shfl / movs counts and the instruction count. Usage: cmp-0005.sh <module.spv>
here=$(cd "$(dirname "$0")" && pwd)
TS=${TS:-$HOME/turnip-swap2}
spv=$1
for B in $TS/build-host $TS/build-host-rel; do
  echo "== $(basename $B)"
  BUILD=$B bash "$here/run-compile.sh" "$spv" 2>&1 | grep -E "^result|Elapsed|error|Assert|assert|Segmentation|signal" | head -5
  out=$(mktemp)
  ( export LD_PRELOAD=$B/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so FD_GPU_ID=830 MESA_SHADER_CACHE_DISABLE=true IR3_SHADER_DEBUG=disasm
    "$TS/tools-bin/tu_compile" "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$spv" "$TS/tools-bin/$(basename "$spv").layout" ) > "$out" 2>&1
  echo "   shfl $(grep -c ' shfl' "$out")  movs $(grep -c ' movs' "$out")  instructions $(grep -cE '^ *:[0-9]+:[0-9]+:|^ *[0-9]+\[' "$out")  lines $(wc -l < "$out")"
  grep -m3 -iE "max_reg|instrlen|nops" "$out"
  rm -f "$out"
done
