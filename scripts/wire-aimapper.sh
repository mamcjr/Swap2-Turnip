#!/bin/bash
# registers u_gralloc_aimapper.c in Mesa's u_gralloc (type, create list, meson)
set -euo pipefail
cd ~/turnip-swap2/mesa/src/util/u_gralloc
grep -q U_GRALLOC_TYPE_AIMAPPER u_gralloc.h || sed -i 's/^   U_GRALLOC_TYPE_FALLBACK,$/   U_GRALLOC_TYPE_FALLBACK,\n   U_GRALLOC_TYPE_AIMAPPER,/' u_gralloc.h
grep -q u_gralloc_aimapper_create u_gralloc_internal.h || sed -i 's/^extern struct u_gralloc \*u_gralloc_fallback_create(void);$/extern struct u_gralloc *u_gralloc_fallback_create(void);\nextern struct u_gralloc *u_gralloc_aimapper_create(void);/' u_gralloc_internal.h
grep -q u_gralloc_aimapper_create u_gralloc.c || sed -i 's/^   {.type = U_GRALLOC_TYPE_LIBDRM, .create = u_gralloc_libdrm_create},$/   \/* IMapper 5 through its stable C API (no libui): Android 15+ Qualcomm phones *\/\n   {.type = U_GRALLOC_TYPE_AIMAPPER, .create = u_gralloc_aimapper_create},\n   {.type = U_GRALLOC_TYPE_LIBDRM, .create = u_gralloc_libdrm_create},/' u_gralloc.c
grep -q u_gralloc_aimapper.c meson.build || sed -i "s/^  'u_gralloc_qcom.c',$/  'u_gralloc_qcom.c',\n  'u_gralloc_aimapper.c',/" meson.build
grep -n "AIMAPPER\|aimapper" u_gralloc.h u_gralloc_internal.h u_gralloc.c meson.build
grep -n "^u_gralloc_destroy" -A12 u_gralloc.c | head -16
