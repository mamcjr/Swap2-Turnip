#!/bin/bash
# Foliage option, phone block 1 (queue row of turnip-swap2), with swap2-native-test-foliage.apk (DM_VK_FOLIAGE / _GRASS / _PLANTS, the launcher hook, grass_mesh rows).
# A) Kokiri Forest (save copy test1121, Link's porch), Turnip V39: which Foliage.Product families are ground plants (plant_mesh) and which are trees: from 105 s,
#    live lines leave one family out at a time (DM_VK_FOLIAGE_GRASS = the family, DM_VK_FOLIAGE=1, DM_VK_FOLIAGE_PLANTS a key nothing has), a screenshot 6 s
#    after each; then the profile's grass at levels 3, 2, 1 (the canopy check).
# B, C) Hyrule Field (save copy user1117, keys 35:A,41:A,47:A, window 250+130 s) on V39 and on 891.14: levels 3, 2, 1, 0 for 32 s each (live), a screenshot
#    20 s into each; fps and GPU time per level from frames.tsv (@t_s).
# The installed APK goes back at the end; folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/foliage1; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
APK=$T/out/swap2-native-test-foliage.apk; CTL=/sdcard/Android/data/com.swap2native.test/files/ctl.txt
BENCH="python -I $R/dm/tools/android_bench.py"
mkdir -p $O/kokiri $O/hf-v39 $O/hf-891
[ -f "$APK" ] || { echo "NOT RUN: APK missing"; exit 2; }
adb shell "[ -f $ZD/$V/dmsh_vk.lib ]" || { echo "NOT RUN: library $V not in the test pack"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
started() { local i=0; while [ -z "$(adb shell pidof com.swap2native.test:game | tr -d '')" ]; do i=$((i+1)); [ $i -gt 600 ] && { echo "no game process after 300 s"; return 1; }; sleep 0.5; done; echo "launch $(date +%T)"; }
ctl() { adb shell "echo '$1' >> $CTL"; }
G="3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d+edeefae4c37b0257+3a6340a04bf09797+a934ed1af79131cc+bc05374f59a92b2b"
FAM=(
"all-drawn:"
"F12c000:eed1add7c89f5d34+92343fd5c0f3ecb2+0c1ffecd02018fb0+ae104328f80e5fb8"
"F159000:73dc0b90c4082e43+fed013936b4efa76+25c4a740753e7d7a+7fd36d22b1f0fd14"
"F185000:17c8ab6419068d4b+e7088344596a80aa+101ecb327aafe9b1+7eef23eeb0784836"
"F1b1000:4c7d6be5a7717c8d+140a2125c2e3c9ce+839241636fce850a+626fbf48041cb82b"
"F1e9000:bc9d26e29a45e6b6+e6df2f14035e7be7+68691c9a4a821751"
"F25a000:fed302d791a4ba43+a8df4b4354adef06+d98076e4148db34f+819c33c90234fcb6"
"F281000:f85bb2e8d78b864c+ac2f3feb11427426+d00c020b43022a68"
"F2a6000:604134a5262ff670+6a1ceebb6cff56dd+eebdb9347d09b344+ca03b41694d4c196"
"Ff9000:eb021183bf9b0092+65a079a285d693a0+96843c3dbdded1e7"
"grass:$G"
"all-drawn-again:")
kshots() {
  sleep 3; started; sleep 105
  ctl 'env DM_VK_FOLIAGE_PLANTS=0000000000000000'
  for f in "${FAM[@]}"; do
    n=${f%%:*}; k=${f#*:}
    if [ -n "$k" ]; then ctl "env DM_VK_FOLIAGE_GRASS=$k"; ctl 'env DM_VK_FOLIAGE=1'; else ctl 'env DM_VK_FOLIAGE=3'; fi
    sleep 6; adb exec-out screencap -p > $O/kokiri/$n.png; echo "shot $n $(date +%T)"
  done
  ctl 'env DM_VK_FOLIAGE_GRASS='
  for l in 3 2 1; do ctl "env DM_VK_FOLIAGE=$l"; sleep 6; adb exec-out screencap -p > $O/kokiri/level$l.png; echo "shot level$l $(date +%T)"; done
}
hshots() {   # $1 out dir
  sleep 3; started; sleep 250
  for l in 3 2 1 0; do sleep 20; adb exec-out screencap -p > $1/level$l.png; echo "shot level$l $(date +%T)"; sleep 12; done
}
LV=(--ctl '0:env DM_VK_FOLIAGE=3' --ctl '32:env DM_VK_FOLIAGE=2' --ctl '64:env DM_VK_FOLIAGE=1' --ctl '96:env DM_VK_FOLIAGE=0')
drv Turnip_Gen8_V39; adb shell input keyevent KEYCODE_WAKEUP
echo "== A kokiri $(date +%T)"
kshots & SP=$!
$BENCH --variant fol:DM_VK_FOLIAGE=3 --runs 1 --cool 30 --save-ref $B/0400486024DEC000-test1121 --start 100 --secs 120 --tag fol-kokiri --out $O/kokiri 2>&1 | tail -1
wait $SP
echo "== B hf v39 $(date +%T)"
hshots $O/hf-v39 & SP=$!
$BENCH --variant fol:DM_VK_FOLIAGE=3 --runs 1 --cool 60 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 130 "${LV[@]}" --tag fol-hf-v39 --out $O/hf-v39 2>&1 | tail -1
wait $SP
echo "== C hf 891 $(date +%T)"
drv 891.14
hshots $O/hf-891 & SP=$!
$BENCH --variant fol:DM_VK_FOLIAGE=3 --runs 1 --cool 60 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A --start 250 --secs 130 "${LV[@]}" --tag fol-hf-891 --out $O/hf-891 2>&1 | tail -1
wait $SP
for f in $O/*/*/log.txt; do echo "== $f crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f)"; grep -a -h "foliage (DM_VK_FOLIAGE" $f | cut -c1-160 | head -20; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
