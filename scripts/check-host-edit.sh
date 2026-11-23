#!/bin/bash
# unit test + NDK syntax check of the host files changed for the shared memory cap
set -uo pipefail
R=/mnt/d/Projetos/Jogos/Android/MKWDroid
T=$(mktemp -d)
echo "== t_android_shmcap (gcc, ASan/UBSan)"
gcc -O1 -g -Wall -Werror -Wno-unused-function -fsanitize=address,undefined -I$R/dm/host -o $T/t $R/dm/host/tests/t_android_shmcap.c && $T/t; echo "exit=$?"
echo "== game profile header"
GEN=$T/gen; mkdir -p $GEN
$HOME/venv-swap2/bin/python3 $R/dm/games/game.py header 0400486024DEC000 $GEN/game_profile.h && $HOME/venv-swap2/bin/python3 $R/dm/games/game.py seed 0400486024DEC000 $GEN/vk_prewarm_seed.h; echo "exit=$?"
echo "== vka_dev.c, NDK clang -fsyntax-only"
CC=$HOME/android-ndk-r30/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android33-clang
$CC -fsyntax-only -O1 -Wall -Wno-unused-function -Wno-format -D_GNU_SOURCE -DDM_NUP_ZSTD -I$GEN -I$R/dm/gfx/nvn/include -I$R/dm/third_party/vulkan-headers/include \
  -I$R/dm/third_party/libvpx -I$R/dm/third_party/libvpx/config -I$R/dm/third_party/stb_vorbis -I$R/dm/third_party/dav1d/include -I$R/dm/host \
  $R/dm/gfx/vk_android/vka_dev.c; echo "exit=$?"
rm -rf $T
