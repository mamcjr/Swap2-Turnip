#!/bin/bash
# Waits (up to ~6 h) until the POCO is unlocked (the test app's storage readable), then removes this session's leftovers: the Zelda capture, the env file if any,
# the Swap2-Turnip copy in nxreplay/drv; and, unless another session has the test app open, the default driver back to Turnip_Gen8_V39 and Zelda's save folder
# back to ports-0400486024DEC000
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
P=/data/local/tmp/nxreplay; F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
for i in $(seq 1 2160); do adb shell "ls /storage/emulated/0/Switch2 >/dev/null 2>&1 && run-as com.swap2native.test ls shared_prefs/launcher.xml >/dev/null 2>&1 && echo ok" 2>/dev/null | grep -q ok && break; sleep 10; done
adb shell "run-as com.swap2native.test ls shared_prefs/launcher.xml" >/dev/null 2>&1 || { echo "still locked $(date +%H:%M)"; exit 1; }
echo "unlocked $(date +%H:%M)"
adb shell "pkill -f nxreplay; rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null; rm -rf $P/drv/Swap2-Turnip $P/tw2_*.log; rm -f $F/env-0400486024DEC000.txt; ls $C 2>&1 | head -1"
focus=$(adb shell "dumpsys window | grep mCurrentFocus")
echo "focus: $focus"
if echo "$focus" | grep -q com.swap2native.test; then echo "test app in use by someone: prefs left (driver 891.14, Zelda save folder saves-test/0400486024DEC000)"; exit 2; fi
adb shell am force-stop com.swap2native.test
adb shell "run-as com.swap2native.test sh -c 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "run-as com.swap2native.test sh -c 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME; adb shell "df -h /data | tail -1"
cd /d/Projetos/Jogos/Android && python - <<'PY'
import time
p='POCO-FILA.md'
s=open(p,encoding='utf-8').read()
t=time.strftime('%H:%M')
s=s.replace("Um script meu faz isso sozinho logo após o desbloqueio (só arquivos e prefs do app de teste; não fecha o app se outra sessão estiver com ele aberto).",
            f"**{t}: limpeza feita depois do desbloqueio** (captura apagada, driver padrão Turnip_Gen8_V39, folder_save do Zelda em ports-0400486024DEC000, app de teste fechado).",1)
open(p,'w',encoding='utf-8').write(s)
PY
echo "done $(date +%H:%M)"
