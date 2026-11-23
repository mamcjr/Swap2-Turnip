#!/bin/bash
# tu_compile for arm64 Android (run from adb shell in /data/local/tmp against a driver .so)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source "$here/env.sh"
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
mkdir -p "$TS/phone"
"$TC/aarch64-linux-android29-clang" -O1 -g -I"$TS/mesa/include" -o "$TS/phone/tu_compile" "$here/../tools/tu_compile.c" -ldl
python3 -I "$here/../tools/spv_layout.py" "/mnt/d/Games/ZORCT ROM/0400486024DEC000-work/mesh-emulation/efaa4fa6a80ba719-fallback.comp.spv" > "$TS/phone/small.layout"
cp "/mnt/d/Games/ZORCT ROM/0400486024DEC000-work/mesh-emulation/efaa4fa6a80ba719-fallback.comp.spv" "$TS/phone/small.spv"
cp "$TS/build-android/src/freedreno/vulkan/libvulkan_freedreno.so" "$TS/phone/ours-unstripped.so"
ls -la "$TS/phone"
