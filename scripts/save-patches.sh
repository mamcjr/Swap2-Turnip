#!/bin/bash
# writes the Mesa working-tree changes as one patch per topic into patches/
set -euo pipefail
cd ~/turnip-swap2/mesa
P=/mnt/d/Projetos/Jogos/Android/turnip-swap2/patches
git diff -- src/freedreno/ir3/ir3_spill.c > $P/0001-ir3-spill-sparse-next-use.patch
git diff -- src/vulkan/runtime/vk_android.c > $P/0002-vk-android-linear-swapchain-when-gralloc-cannot-tell.patch
git diff -- src/freedreno/vulkan/tu_util.cc > $P/0003-tu-build-time-TU_DEBUG-default.patch
git add -N src/util/u_gralloc/u_gralloc_aimapper.c
git diff -- src/util/u_gralloc/u_gralloc_aimapper.c src/util/u_gralloc/u_gralloc.c src/util/u_gralloc/u_gralloc.h src/util/u_gralloc/u_gralloc_internal.h src/util/u_gralloc/meson.build > $P/0004-u_gralloc-imapper5-stable-c-backend.patch
git diff -- src/util/u_gralloc/u_gralloc_fallback.c > $P/9001-diag-log-gralloc-handle.patch
wc -l $P/*.patch
