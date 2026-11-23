#!/bin/bash
# compare dynamic deps and exported symbols of our build with V39
V39="/mnt/d/Games/ZORCT ROM/0400486024DEC000-work/drivers/v39/libvulkan_freedreno.so"
OURS=${1:-$HOME/turnip-swap2/build-android/src/freedreno/vulkan/libvulkan_freedreno.so}
for f in "$V39" "$OURS"; do
  echo "== $f"
  readelf -d "$f" | grep -E "NEEDED|SONAME"
  readelf --dyn-syms -W "$f" | awk '$5=="GLOBAL" && $7!="UND" {print $8}' | sort | tr '\n' ' '; echo
  readelf -n "$f" | grep -A1 android.ident | tail -1
done
