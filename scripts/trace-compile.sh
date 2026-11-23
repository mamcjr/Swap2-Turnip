#!/bin/bash
# run-compile.sh with the bigalloc tracer, then name its sites with addr2line
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
TS=${TS:-$HOME/turnip-swap2}
B=${BUILD:-$TS/build-host}
T=$TS/tools-bin
mkdir -p "$T"
clang -O1 -g -shared -fPIC -o "$T/bigalloc.so" "$here/../tools/bigalloc.c" -ldl -lpthread
bash "$here/run-compile.sh" "$1" >/dev/null 2>&1 || true   # builds tu_compile and the layout
spv=$1
lay=$T/$(basename "$spv").layout
log=$T/$(basename "$spv").bigalloc
LD_PRELOAD="$B/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so:$T/bigalloc.so" FD_GPU_ID=830 MESA_SHADER_CACHE_DISABLE=true \
  "$T/tu_compile" "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$spv" "$lay" > "$log" 2>&1 || true
grep -E "^result|peak" "$log"
grep "bigalloc: site" "$log" | while read -r _ _ loc rest; do
  off=${loc##*+}
  fn=$(addr2line -f -C -i -e "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$off" | paste -sd" " | tr '\n' ' ')
  echo "$rest  <- $fn"
done | sort -t' ' -k4 -g -r | head -20
