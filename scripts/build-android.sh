#!/bin/bash
# Cross-build Turnip (Mesa's Vulkan driver for Adreno) for Android arm64 / KGSL with NDK r30,
# and pack it as an adrenotools zip (meta.json + libvulkan_freedreno.so), the format
# Swap2-Native's host loads (dm/gfx/vk_android/vka_driver.c, --es gpu_driver_zip).
# Usage: build-android.sh [name] [description]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
API=${API:-29}            # NDK target: the oldest Android the .so loads on
SDK=${SDK:-36}            # Mesa platform-sdk-version: extensions Mesa hides on Android below their level (vk_extensions.py); 36 = what V39 exposes
NAME=${1:-Swap2-Turnip}
DESC=${2:-Turnip built by Swap2-Native, A8xx Android/KGSL}
SRC=${SRC:-$TS/mesa}   # (rel-worktree.sh: $TS/mesa-rel, the shipping patches only)
BUILD=${BUILD:-$TS/build-android}
OUT=${OUT:-/mnt/d/Projetos/Jogos/Android/turnip-swap2/out}
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
mkdir -p "$OUT"
cat > "$TS/android-aarch64.cross" <<CROSS
[binaries]
ar = '$TC/llvm-ar'
c = ['$TC/aarch64-linux-android$API-clang']
cpp = ['$TC/aarch64-linux-android$API-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++', '-Wno-c++11-narrowing']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$TC/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$TS/pkgconfig-empty', '/usr/bin/pkg-config']
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
CROSS
mkdir -p "$TS/pkgconfig-empty"
if [ ! -f "$BUILD/build.ninja" ]; then
  meson setup "$BUILD" "$SRC" --cross-file "$TS/android-aarch64.cross" \
    -Dbuildtype=release -Db_ndebug=true -Dstrip=true \
    -Dplatforms=android -Dplatform-sdk-version=$SDK -Dandroid-stub=true \
    -Dandroid-libbacktrace=disabled \
    -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl \
    -Dvulkan-beta=true -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false -Dglx=disabled \
    -Dllvm=disabled -Dzstd=disabled -Dexpat=disabled -Dvalgrind=disabled -Dlibunwind=disabled \
    -Dcpp_rtti=false -Db_lto=${LTO:-false}
fi
t0=$(date +%s)
ninja -C "$BUILD" src/freedreno/vulkan/libvulkan_freedreno.so
t1=$(date +%s)
echo "build seconds: $((t1 - t0))"
so=$BUILD/src/freedreno/vulkan/libvulkan_freedreno.so
rev=$(git -C "$SRC" rev-parse --short=10 HEAD)
dirty=$(git -C "$SRC" status --porcelain --untracked-files=no | wc -l)
stage=$(mktemp -d)
"$TC/llvm-strip" --strip-unneeded -o "$stage/libvulkan_freedreno.so" "$so"   # ninja leaves .symtab (meson strips only on install)
cat > "$stage/meta.json" <<META
{
  "schemaVersion": 1,
  "name": "$NAME",
  "description": "$DESC (mesa git-$rev, $dirty files patched)",
  "author": "Swap2-Native",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "Vulkan 1.4",
  "minApi": $API,
  "libraryName": "libvulkan_freedreno.so"
}
META
zipname="$OUT/Swap2-Turnip-$rev${dirty:+-p$dirty}.zip"; [ "$dirty" = 0 ] && zipname="$OUT/Swap2-Turnip-$rev-vanilla.zip"
rm -f "$zipname"
(cd "$stage" && python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w',zipfile.ZIP_DEFLATED); [z.write(f) for f in ('meta.json','libvulkan_freedreno.so')]" "$zipname")
rm -rf "$stage"
ls -la "$so" "$zipname"
