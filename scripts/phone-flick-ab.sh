#!/bin/bash
# phone-flick-ab.sh <tag> "<ctl lines;...>" ...: in the running game, for each argument: append its ctl lines (env KEY=VAL, ';'-separated),
# wait 4 s, record 6 s into out/zelda/flick-<tag>-<i>/flick.mp4. Arguments are applied in order (they accumulate, as ctl does).
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
F=/storage/emulated/0/Android/data/com.swap2native.test/files
tag=$1; shift; i=0
for cfg in "$@"; do
  i=$((i+1)); O=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda/flick-$tag-$i; mkdir -p $O
  IFS=';' read -ra L <<< "$cfg"; for l in "${L[@]}"; do [ -n "$l" ] && adb shell "echo 'env $l' >> $F/ctl.txt"; done
  echo "$cfg" > $O/cfg.txt; sleep 4
  adb shell screenrecord --time-limit ${SECS:-6} --bit-rate 40000000 --size 1600x720 /sdcard/Download/flick.mp4
  adb pull /sdcard/Download/flick.mp4 "$(cygpath -w $O)/flick.mp4" >/dev/null; adb shell rm /sdcard/Download/flick.mp4
  echo "$i: $cfg"
done
