#!/bin/bash
# ir3 optimizations: capture Kokiri frame 4500 on 891.14 (test save), replay on Swap2-Turnip with IR3_SHADER_DEBUG options that turn ir3 passes off (fresh DM_TEMP,
# Mesa's shader cache off, so every shader is compiled again): all of them, two halves, fullsync; logs to out/zelda/ir3_<label>.log; clean up
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
RA="run-as com.swap2native.test sh -c"
OVR=${OVR:-${TMPDIR:-/tmp}/ovr}
F0=$(adb shell df -k /data | tail -1 | awk '{print $4}' | tr -d ''); echo "free at start: ${F0} KiB"
[ "${F0:-0}" -ge 9961472 ] || { echo "NOT RUN: under 9.5 GB free for an ~8 GB capture"; exit 2; }
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
# the driver's compile statistics (VK_KHR_pipeline_executable_properties) of the mesh programs whose fallback compute is slowest on Turnip (the nxreplay session's profile,
# 2026-11-21: 65a079a2 19.2 ms against 1.9 on 891.14, eb021183 24.3 against 5.5), on both drivers; logs out/zelda/ps_<driver>.log
for drv in 891.14 Swap2-Turnip; do
  echo "== stats $drv"
  adb shell "cd $P && DM_VK_PIPE_STATS=1 DM_VK_PIPE_STATS_KEYS=65a079a285d693a0,eb021183bf9b0092,e6df2f14035e7be7,fed302d791a4ba43,bc9d26e29a45e6b6,604134a5262ff670 DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 1 --no-png > ps_$drv.log 2>&1; grep -a -c 'pipeline stats' ps_$drv.log"
  adb pull $P/ps_$drv.log "$T/out/zelda/ps_$drv.log" >/dev/null; adb shell rm -f $P/ps_$drv.log
done
# task/mesh compute modules with their shuffles through workgroup memory (shuffle_lds applied to MOD_MESH_COMPUTE, 54 of the library's 520, DM_VK_SPV_OVERRIDE):
# Turnip profiled without and with them (one frame in 1 timed, draws ranked), and 891.14 with them (it replays faithfully, so a correct rewrite keeps it near the live frame)
adb shell "rm -rf $P/ovr && mkdir -p $P/ovr"; adb push $OVR/. $P/ovr/ >/dev/null; adb shell "ls $P/ovr | wc -l"
for v in "Swap2-Turnip base -" "Swap2-Turnip lds ovr" "891.14 lds ovr"; do
  set -- $v; drv=$1; lab=$1-$2; E="DM_VK_GPUPROF=1 DM_VK_GPUPROF_DRAWS=1"; [ "$3" = ovr ] && E="$E DM_VK_SPV_OVERRIDE=$P/ovr"
  echo "== $lab"
  adb shell "cd $P && $E DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/$drv LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --no-png > lds_$lab.log 2>&1; grep -a 'pixels differ' lds_$lab.log | head -3; grep -a 'gpu prof draws: frame' lds_$lab.log | tail -2 | cut -c1-220; grep -a -c 'DM_VK_SPV_OVERRIDE: shader' lds_$lab.log"
  adb pull $P/lds_$lab.log "$T/out/zelda/lds_$lab.log" >/dev/null; adb shell rm -f $P/lds_$lab.log
done
adb shell "rm -rf $P/ovr"
adb shell "rm -rf $P/ir3 && mkdir -p $P/ir3"
for v in "all nofp16,nopreamble,noearlypreamble,nodescprefetch,noaliastex,noaliasrt,expandrpt,thread64" "sync fullsync"; do
  set -- $v; lab=$1
  echo "== Swap2-Turnip IR3_SHADER_DEBUG=$2"
  adb shell "rm -rf $P/ir3/temp && mkdir -p $P/ir3/temp && cp $P/temp/vk_view_formats.txt $P/ir3/temp/ 2>/dev/null; cd $P/ir3 && IR3_SHADER_DEBUG=$2 MESA_SHADER_CACHE_DISABLE=true DM_TEMP=$P/ir3/temp DM_VK_DRIVER=$P/drv/Swap2-Turnip LD_LIBRARY_PATH=$P $P/nxreplay $C/kokiri.nvncap --warm 1 --no-png > $P/ir3_$lab.log 2>&1; echo exit \$?; grep -a 'pixels differ' $P/ir3_$lab.log | head -2"
  adb pull $P/ir3_$lab.log "$T/out/zelda/ir3_$lab.log" >/dev/null; adb shell rm -f $P/ir3_$lab.log
done
adb shell "rm -rf $P/ir3"
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null"
adb shell "rm -rf $P/drv/Swap2-Turnip"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
