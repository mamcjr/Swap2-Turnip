#!/bin/bash
# capture Kokiri frame 4500 on 891.14, replay it on Swap2-Turnip with TU_DEBUG=flushall, print the comparison with the live frame, clean up
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
T=D:/Projetos/Jogos/Android/turnip-swap2; P=/data/local/tmp/nxreplay
F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
adb exec-out "run-as com.swap2native.test tar c -C files/gpu_drivers Swap2-Turnip" > $T/replay-stage/drv/Swap2-Turnip.tar
adb push $T/replay-stage/drv/Swap2-Turnip.tar $P/drv/ >/dev/null; adb shell "cd $P/drv && tar xf Swap2-Turnip.tar && rm Swap2-Turnip.tar"
adb shell am force-stop com.swap2native.test; adb shell rm -f $F/env-0400486024DEC000.txt
for dbg in flushall none; do
  e=""; [ $dbg != none ] && e="TU_DEBUG=$dbg"
  echo "== Swap2-Turnip $dbg"
  adb shell "cd $P && $e DM_TEMP=$P/temp DM_VK_DRIVER=$P/drv/Swap2-Turnip LD_LIBRARY_PATH=. ./nxreplay $C/kokiri.nvncap --warm 2 --no-png > fa_$dbg.log 2>&1; echo exit \$?; grep -a -e 'pixels differ' -e 'nxreplay:' -e MATCH -e 'submits CPU' -e RED fa_$dbg.log | head -14 | cut -c1-220"
  adb pull $P/fa_$dbg.log "$T/out/zelda/fa_$dbg.log" >/dev/null
done
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null; rm -rf $P/drv/Swap2-Turnip $P/fa_*.log"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell run-as com.swap2native.test sh -c "'grep -h \"name=\\\"gpu_driver\\\"\" shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
adb shell run-as com.swap2native.test sh -c "'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml; grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'"
