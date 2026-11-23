#!/bin/bash
# After the phone dropped off adb in the middle of the baseline bench (2026-11-21 18:09): waits for it to come back unlocked, then puts the test app as it was
# (no bench env.txt, the Zelda test save from s2bench/0400486024DEC000-test1121, folder_save on ports-, default driver V39), releases "Agora" and logs the history
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
F=/sdcard/Android/data/com.swap2native.test/files; S=/sdcard/Switch2/saves-test/0400486024DEC000; B=/data/local/tmp/s2bench/0400486024DEC000-test1121
RA="run-as com.swap2native.test sh -c"
for i in $(seq 1 4320); do
  if adb devices | grep -q "^$ANDROID_SERIAL\s*device" && adb shell "ls $S/slot_00 >/dev/null 2>&1 && $RA 'ls shared_prefs/launcher.xml' >/dev/null 2>&1 && echo ok" 2>/dev/null | grep -q ok; then break; fi
  sleep 10
done
echo "back $(date +%H:%M)"
adb shell am force-stop com.swap2native.test
adb shell "rm -f $F/env.txt $F/bench-frames.tsv $F/temp/0400486024DEC000/vk_backing-*.txt; [ -d $B/main ] && [ -d $B/work ] && rm -rf $S/* $S.work/* && cp -r $B/main/. $S/ && cp -r $B/work/. $S.work/ && echo save restored; ls $F | grep -c env.txt"
adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"; adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell df -h /data | tail -1
cd /d/Projetos/Jogos/Android && python - <<'PY'
import time
p='POCO-FILA.md'; s=open(p,encoding='utf-8').read()
rows=[l for l in s.splitlines() if l.startswith('| Turnip próprio [turnip-swap2] | com.swap2native.test | 21/11 18:12')]
for r in rows: s=s.replace(r+'\n','')
old='Fico em "Agora" até limpar. com.swap2native não tocado.'
s=s.replace(old, f'**{time.strftime("%H:%M")}: limpeza feita** (env.txt apagado, save de teste do Zelda devolvido da cópia test1121, folder_save em ports-0400486024DEC000, driver padrão Turnip_Gen8_V39, app de teste fechado). com.swap2native não tocado. Celular livre.',1)
open(p,'w',encoding='utf-8').write(s)
PY
echo "released $(date +%H:%M)"
