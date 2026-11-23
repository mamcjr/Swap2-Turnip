#!/bin/bash
# Waits (up to ~4 h) for the POCO on adb, then cleans up after phone-twice2.sh was cut by the disconnect, and releases the queue row
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
P=/data/local/tmp/nxreplay; F=/storage/emulated/0/Android/data/com.swap2native.test/files; C=/storage/emulated/0/Switch2/Work/0400486024DEC000/captures
for i in $(seq 1 1440); do adb devices | grep -q "^$ANDROID_SERIAL\s*device" && break; sleep 10; done
adb devices | grep -q "^$ANDROID_SERIAL\s*device" || { echo "phone not back $(date +%H:%M)"; exit 1; }
echo "phone back $(date +%H:%M)"; sleep 5
adb shell "pkill -f nxreplay; sleep 1; ps -A | grep -c nxreplay"
adb shell "rm -f $C/kokiri.nvncap $C/kokiri.nvncap.live.png; rmdir $C 2>/dev/null; rm -rf $P/drv/Swap2-Turnip $P/tw2_*.log; rm -f $F/env-0400486024DEC000.txt"
adb shell am force-stop com.swap2native.test
adb shell "run-as com.swap2native.test sh -c 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver Turnip_Gen8_V39 >/dev/null; sleep 3
adb shell "run-as com.swap2native.test sh -c 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell am force-stop com.swap2native.test; adb shell input keyevent KEYCODE_HOME
adb shell "ls $C 2>&1 | head -2; ls $F | grep -c env-; df -h /data | tail -1; dumpsys window | grep mCurrentFocus"
cd /d/Projetos/Jogos/Android && python - <<'PY'
import time
p='POCO-FILA.md'
s=open(p,encoding='utf-8').read()
row=[l for l in s.splitlines() if l.startswith('| Turnip próprio [turnip-swap2] | com.swap2native.test')][0]
s=s.replace(row+'\n','')
t=time.strftime('%H:%M')
e=(f'- 21/11 12:05-{t} — Turnip próprio [turnip-swap2]: só o app de teste e adb shell, sem APK novo. Troquei o `nxreplay` e o `libnxhost.so` de /data/local/tmp/nxreplay por builds de diagnóstico (a do commit 6993fa3 com DM_VK_MESH_DUMP de entradas e DM_VK_MESH_TWICE com dois sentinelas). '
 '4 capturas do Zelda no 891.14 (quadro 4500, ~2,2 GB; folder_save do Zelda trocado para saves-test/0400486024DEC000 durante as capturas) e replays com dumps e com DM_VK_MESH_TWICE. '
 '**O celular saiu do adb às ~12:47, no meio do último replay**; quando voltou, o script de limpeza parou o nxreplay e apagou a captura, os logs, a cópia do Swap2-Turnip em drv e o `env-0400486024DEC000.txt`; folder_save do Zelda de volta para **ports-0400486024DEC000**, driver padrão de volta para **Turnip_Gen8_V39**, app fechado, tela inicial. com.swap2native não tocado. Celular livre.\n\n')
h='## Histórico\n\n'
s=s.replace(h,h+e,1)
open(p,'w',encoding='utf-8').write(s)
PY
echo "released $(date +%H:%M)"
