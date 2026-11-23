#!/bin/bash
# Is the GPU at its highest clock in Hyrule Field with the grass? (chain 706d0c7262fa with DM_VK_MESH_EXACT, DM_VK_CHUNK=200; the host's GPU clock floor at its
# default 100 %: VK_QCOM_queue_perf_hint on 891.14, the KGSL power constraint on Turnip). Per driver (891.14, Turnip V39): one run as is and one with
# DM_VK_ADPF_SPAN_ANY=1, while a sampler reads the GPU's clock (/sys/class/kgsl/kgsl-3d0: gpuclk, devfreq/cur_freq), its limits (max_gpuclk, min_clock_mhz,
# devfreq/max_freq) and temperature (temp) once a second into out/zelda/clock/<driver>-<variant>.tsv (seconds from the run's start). The parent session's APK
# swap2-native-test-706d0c7262fa-exact.apk over the installed one (put back at the end), the library v-706d0c7262fa in the test pack. Save copy user1117, keys
# 35:A,41:A,47:A, window 250+40 s. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/clock; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
APK=$R/android/app/out/swap2-native-test-706d0c7262fa-exact.apk; K=/sys/class/kgsl/kgsl-3d0
mkdir -p $O
[ -f "$APK" ] || { echo "NOT RUN: APK missing"; exit 2; }
adb shell "[ -f $ZD/$V/dmsh_vk.lib ]" || { echo "NOT RUN: library $V not in the test pack"; exit 2; }
adb shell "for f in gpuclk max_gpuclk min_clock_mhz max_clock_mhz temp devfreq/cur_freq devfreq/max_freq devfreq/min_freq devfreq/governor devfreq/available_frequencies; do printf '%s: ' \$f; cat $K/\$f 2>&1 | head -c 200; echo; done"
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
C=DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200
sampler() {   # $1 the tsv; until the stop file exists: seconds, gpuclk, cur_freq, max_gpuclk, max_freq, temp
  local t0=$(date +%s); echo -e "s\tgpuclk\tcur_freq\tmax_gpuclk\tmax_freq\ttemp" > $1
  while [ ! -f $O/.stop ]; do
    v=$(adb shell "cat $K/gpuclk $K/devfreq/cur_freq $K/max_gpuclk $K/devfreq/max_freq $K/temp 2>/dev/null" | tr -d '\r' | paste -sd'\t')
    echo -e "$(( $(date +%s) - t0 ))\t$v" >> $1; sleep 1
  done
}
for d in 891.14 Turnip_Gen8_V39; do
  for v in base: spanany:DM_VK_ADPF_SPAN_ANY=1; do
    tag=${v%%:*}; ex=${v#*:}; E=$C${ex:+,$ex}
    drv $d; adb shell input keyevent KEYCODE_WAKEUP
    rm -f $O/.stop; sampler $O/$d-$tag.tsv & SP=$!
    python -I $R/dm/tools/android_bench.py --variant $tag:$E --runs 1 --cool 20 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 40 \
      --tag clock-$d-$tag --out $O/$d-$tag 2>&1 | tail -1
    touch $O/.stop; wait $SP; rm -f $O/.stop
    awk -F'\t' 'NR>1 && $1>=255 && $1<=300 {n++; c+=$2; f+=$3; t+=$6; if(mx<$4) mx=$4} END {if(n) printf "window: gpuclk mean %.0f, cur_freq mean %.0f, max_gpuclk %s, temp mean %.0f (%d samples)\n", c/n, f/n, mx, t/n, n}' $O/$d-$tag.tsv
  done
done
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f)"; grep -a -i "gpu clock floor\|queue_perf_hint\|kgsl.*constraint\|ADPF" $f | head -3 | cut -c1-200; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
