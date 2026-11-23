#!/bin/bash
# Compile a set of modules with IR3_SHADER_DEBUG=disasm and keep the disassembly and the
# time / peak memory per module: disasm-set.sh <tag> <module.spv>...
here=$(cd "$(dirname "$0")" && pwd)
TS=${TS:-$HOME/turnip-swap2}
tag=$1; shift
out=$TS/results/$tag
mkdir -p "$out"
for spv in "$@"; do
  n=$(basename "$(dirname "$spv")")_$(basename "$spv" .spv)
  ( ulimit -v 10000000
    IR3_SHADER_DEBUG=disasm timeout 1200 bash "$here/run-compile.sh" "$spv" > "$out/$n.summary" 2>&1 )
  T=$TS/tools-bin
  # full disassembly (run-compile filters its output; run once more unfiltered is too slow, so
  # this one keeps stdout+stderr of the compile directly)
  ( ulimit -v 10000000
    LD_PRELOAD=${BUILD:-$TS/build-host}/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so FD_GPU_ID=830 MESA_SHADER_CACHE_DISABLE=true IR3_SHADER_DEBUG=disasm \
      timeout 1200 "$T/tu_compile" "${BUILD:-$TS/build-host}/src/freedreno/vulkan/libvulkan_freedreno.so" "$spv" "$T/$(basename "$spv").layout" > "$out/$n.disasm" 2>&1 )
  # strip timing lines so runs compare
  grep -v "^result\|^rss\|^device" "$out/$n.disasm" | grep -v "seconds" > "$out/$n.asm"
  echo "$n $(grep -E '^result' "$out/$n.summary" | head -1) $(grep -E 'Maximum resident' "$out/$n.summary") asm_lines=$(wc -l < "$out/$n.asm") sha=$(sha1sum < "$out/$n.asm" | cut -c1-12)"
done
