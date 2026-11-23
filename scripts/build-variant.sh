#!/bin/bash
# build-variant.sh <tag> <TU_DEBUG default>: a diagnostic Swap2-Turnip whose TU_DEBUG default is compiled in,
# in its own build folder; zip out/Swap2-Turnip-<tag>.zip with the name "Swap2-Turnip <tag>"
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
tag=$1; dbg=$2
B=$TS/build-android-$tag
if [ ! -f "$B/build.ninja" ]; then
  cp -r "$TS/build-android" "$B" 2>/dev/null || true
  meson setup --wipe "$B" "$TS/mesa" --cross-file "$TS/android-aarch64.cross" \
    -Dbuildtype=release -Db_ndebug=true -Dstrip=true \
    -Dplatforms=android -Dplatform-sdk-version=36 -Dandroid-stub=true -Dandroid-libbacktrace=disabled \
    -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl \
    -Dvulkan-beta=true -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dglx=disabled \
    -Dllvm=disabled -Dzstd=disabled -Dexpat=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
    -Dcpp_rtti=false "-Dcpp_args=-DTU_DEBUG_DEFAULT=$dbg" > /dev/null
fi
BUILD=$B bash "$here/build-android.sh" "Swap2-Turnip $tag" "diagnostic: TU_DEBUG=$dbg by default" | tail -1
cd /mnt/d/Projetos/Jogos/Android/turnip-swap2/out && mv -f "$(ls -t Swap2-Turnip-2648b2059f-p*.zip | head -1)" "Swap2-Turnip-$tag.zip" && ls -la "Swap2-Turnip-$tag.zip"
