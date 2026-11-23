#!/bin/bash
# x86_64 Linux build of the same Turnip with the msm kernel interface and freedreno's no-op
# drm-shim, so that the driver runs on the PC as an Adreno 830 (FD_GPU_ID=830) and compiles
# pipelines offline: shader compile crashes, memory and time can be measured without the phone.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
SRC=$TS/mesa
BUILD=${BUILD:-$TS/build-host}
if [ ! -f "$BUILD/build.ninja" ]; then
  CC=clang CXX=clang++ meson setup "$BUILD" "$SRC" \
    -Dbuildtype=debugoptimized -Db_ndebug=false \
    -Dplatforms= -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm \
    -Dtools=drm-shim -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dglx=disabled \
    -Dllvm=disabled -Dzstd=disabled -Dexpat=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
    -Dcpp_args=-Wno-c++11-narrowing
fi
t0=$(date +%s)
ninja -C "$BUILD" src/freedreno/vulkan/libvulkan_freedreno.so src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so
echo "build seconds: $(( $(date +%s) - t0 ))"
ls -la "$BUILD/src/freedreno/vulkan/libvulkan_freedreno.so" "$BUILD/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so"
