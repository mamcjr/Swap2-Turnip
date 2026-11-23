#!/bin/bash
# The raw memory loads' word hit (DM_VK_RAW_WORD_HIT, vka_spv_raw_word_hit): capture Kokiri frame 4500 on 891.14 (test save), replay with a step profile on 891.14 and
# Swap2-Turnip with the rewrite off and on (each run its own DM_TEMP: its pipelines compile again); logs to out/zelda/wh_<label>.log; clean up
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
RA="run-as com.swap2native.test sh -c"
F0=$(adb shell df -k /data | tail -1 | awk '{print $4}' | tr -d ''); echo "free at start: ${F0} KiB"
[ "${F0:-0}" -ge 9961472 ] || { echo "NOT RUN: under 9.5 GB free for an ~8 GB capture"; exit 2; }
# the test APK with Zelda's library chain (45cedbd878f7: the one on the phone) and the word hit, for the capture; the usual test APK of that chain back at the end
adb install -r $T/out/swap2-native-test-wordhit.apk | tail -1
adb push $T/replay-build-head/nxreplay $T/replay-build-head/libnxhost.so $P/ >/dev/null && adb shell chmod 755 $P/nxreplay
adb exec-out "run-as com.swap2native.test tar c -C files/gpu_drivers Swap2-Turnip" > $T/replay-stage/drv/Swap2-Turnip.tar
adb push $T/replay-stage/drv/Swap2-Turnip.tar $P/drv/ >/dev/null; adb shell "cd $P/drv && tar xf Swap2-Turnip.tar && rm Swap2-Turnip.tar"
adb shell am force-stop com.swap2native.test
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver 891.14 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
adb shell "mkdir -p $C; echo DM_NVN_CAPTURE=4500:1:$C/kokiri.nvncap > $F/env-0400486024DEC000.txt"
adb logcat -c; adb shell am start -n com.swap2native.test/com.swap2native.test.Launch -e title_id 0400486024DEC000 >/dev/null
sleep 40; for k in 1 2 3; do adb shell input tap 2949 477; sleep 4; done
for i in $(seq 1 50); do sleep 10; l=$(adb logcat -d | grep -a "DM_NVN_CAPTURE: frame [0-9]*: [0-9]* submits" | tail -1 | cut -c60-200); [ -n "$l" ] && { echo "capture: $l"; break; }; done
adb shell am force-stop com.swap2native.test; adb shell rm -f $F/env-0400486024DEC000.txt
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
# (nopfb: the texture pool reads not reported, DM_VK_POOL_FB=0: pixel shaders without the feedback's memory writes, which turn off early depth tests and LRZ on Turnip)
for v in "891.14 off 0" "891.14 on 1" "Swap2-Turnip off 0" "Swap2-Turnip on 1" "Swap2-Turnip nopfb 1 DM_VK_POOL_FB=0"; do
  set -- $v; drv=$1; lab=$1-$2; E="DM_VK_GPUPROF=1 DM_VK_GPUPROF_LIST=1 DM_VK_RAW_WORD_HIT=$3 DM_VK_PIPE_STATS=1 DM_VK_PIPE_STATS_KEYS=b1f06157308e3b22 $4"
  echo "== $lab"
  adb shell "rm -rf $P/t_wh && mkdir -p $P/t_wh && cp $P/temp/vk_view_formats.txt $P/t_wh/ 2>/dev/null; cd $P && $E DM_TEMP=$P/t_wh DM_VK_DRIVER=$P/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --no-png > wh_$lab.log 2>&1; grep -a 'pixels differ' wh_$lab.log | head -3; grep -a 'gpu prof: frame [0-9]*: [0-9]* timestamps' wh_$lab.log | tail -1 | cut -c1-230; grep -a 'search the pool table once' wh_$lab.log | tail -1 | cut -c1-200; grep -a -c RED wh_$lab.log"
  adb pull $P/wh_$lab.log "$T/out/zelda/wh_$lab.log" >/dev/null; adb shell rm -f $P/wh_$lab.log
done
# Turnip's own performance warnings for the same frame (TU_DEBUG=perf: LRZ disabled and why, sysmem fallbacks, ...), the word hit on
adb logcat -c; adb shell "rm -rf $P/t_wh && mkdir -p $P/t_wh && cp $P/temp/vk_view_formats.txt $P/t_wh/ 2>/dev/null; cd $P && TU_DEBUG=perf DM_TEMP=$P/t_wh DM_VK_DRIVER=$P/drv/Swap2-Turnip LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 1 --no-png > wh_perf.log 2>&1; grep -a -c -i lrz wh_perf.log"
adb pull $P/wh_perf.log "$T/out/zelda/wh_perf.log" >/dev/null; adb shell rm -f $P/wh_perf.log
adb logcat -d > "$T/out/zelda/wh_perf_logcat.txt"; grep -a -i -c lrz "$T/out/zelda/wh_perf_logcat.txt"
adb shell "rm -rf $P/t_wh"
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null"
adb shell "rm -rf $P/drv/Swap2-Turnip"
adb install -r D:/Projetos/Jogos/Android/MKWDroid/android/app/out/swap2-native-test-45cedbd878f7.apk | tail -1
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
