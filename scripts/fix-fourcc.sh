#!/bin/bash
set -e
cd ~/turnip-swap2/mesa
python3 - src/util/u_gralloc/u_gralloc_aimapper.c <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="""   gr->mapper->v5.freeBuffer(b);

   if (!layout_ok || !fourcc) {"""
new="""   gr->mapper->v5.freeBuffer(b);

   /* QTI's mapper gives no PIXEL_FORMAT_FOURCC for a UBWC buffer (there is
    * no linear DRM format to name); the handle's HAL format says it.
    */
   if (!fourcc)
      fourcc = get_fourcc_from_hal_format(hnd->hal_format);

   if (!layout_ok || !fourcc) {"""
if "no PIXEL_FORMAT_FOURCC for a UBWC" not in s:
    assert old in s; s=s.replace(old,new); open(p,'w').write(s)
PY
grep -n "get_fourcc_from_hal_format" src/util/u_gralloc/u_gralloc_aimapper.c
