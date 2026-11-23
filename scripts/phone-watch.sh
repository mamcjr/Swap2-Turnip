#!/bin/bash
# phone-watch.sh <tag> <seconds>: samples the test app's game process every 10 s (memory, maps, screenshots), keeps logcat
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
P=com.swap2native.test; TAG=$1; SECS=${2:-480}; OUT=/d/Projetos/Jogos/Android/turnip-swap2/out/zelda
(timeout $((SECS + 5)) adb logcat -v time Swap2Native:V DEBUG:V libc:F AndroidRuntime:E ActivityManager:I '*:S' > $OUT/$TAG.logcat &)
: > $OUT/$TAG.mem
for ((t = 10; t <= SECS; t += 10)); do
  sleep 10
  pid=$(adb shell pidof $P:game | tr -d '\r')
  if [ -z "$pid" ]; then echo "t=$t: no game process" | tee -a $OUT/$TAG.mem; [ $t -ge 60 ] && break; continue; fi
  maps=$(adb shell "run-as $P cat /proc/$pid/maps | wc -l" | tr -d '\r')
  adb shell "dumpsys meminfo $pid" | tr -d '\r' | awk -v t=$t -v m="$maps" '/TOTAL PSS:/ {p=$3} /Graphics:/ {g=$2} END {printf "t=%3d pss %5d MB graphics %5d MB maps %s\n", t, p/1024, g/1024, m}' | tee -a $OUT/$TAG.mem
  case $t in 30|60|120|180|240|300|360|420|480) adb exec-out screencap -p > $OUT/$TAG-t$t.png;; esac
done
L=$(adb shell "ls -t /sdcard/Android/data/$P/files/logs/*.log | head -1" | tr -d '\r')
adb exec-out cat "$L" > $OUT/$TAG.log
echo "log: $L ($(wc -l < $OUT/$TAG.log) lines)"
