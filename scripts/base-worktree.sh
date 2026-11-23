#!/bin/bash
# An unpatched worktree of the same Mesa commit and its host build, to compare compiles with and
# without our patches. Also saves the current patch set from the main checkout.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
cd "$TS/mesa"
git diff > /mnt/d/Projetos/Jogos/Android/turnip-swap2/patches/0001-ir3-spill-sparse-next-use.patch
[ -d "$TS/mesa-base" ] || git worktree add -q --detach "$TS/mesa-base" 2648b2059f
B=$TS/build-host-base
if [ ! -f "$B/build.ninja" ]; then
  CC=clang CXX=clang++ meson setup "$B" "$TS/mesa-base" \
    -Dbuildtype=debugoptimized -Db_ndebug=false \
    -Dplatforms= -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm \
    -Dtools=drm-shim -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dglx=disabled \
    -Dllvm=disabled -Dzstd=disabled -Dexpat=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
    -Dcpp_args=-Wno-c++11-narrowing > /dev/null
fi
ninja -C "$B" src/freedreno/vulkan/libvulkan_freedreno.so src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so | tail -1
wc -l /mnt/d/Projetos/Jogos/Android/turnip-swap2/patches/0001-ir3-spill-sparse-next-use.patch
du -sh "$TS/mesa-base" "$B"
