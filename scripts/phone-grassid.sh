#!/bin/bash
# Which of Ocarina of Time's Foliage.Product mesh families are the tall grass (for the profile's grass_mesh row): one Hyrule Field run on Turnip V39 (save copy
# user1117, keys 35:A,41:A,47:A, Link standing still, DM_VK_CHUNK=200) with the grass levels' APK (swap2-native-test-grass.apk: DM_VK_GRASS, DM_VK_GRASS_KEYS, live).
# From 255 s, live control lines left out one family at a time (DM_VK_GRASS_KEYS = all variants of one BNSH offset of Foliage.Product, DM_VK_GRASS=0) and a
# screenshot 6 s after each; the first and the last screenshot with every family drawn. The installed APK is put back at the end; the library v-706d0c7262fa is
# in the test pack. Screenshots and the log in out/zelda/grassid. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/grassid; B=/data/local/tmp/s2bench
RA="run-as com.swap2native.test sh -c"; ZD=/sdcard/Switch2/Work/0400486024DEC000/test-pack/shaders; V=v-706d0c7262fa
APK=$T/out/swap2-native-test-grass.apk; CTL=/sdcard/Android/data/com.swap2native.test/files/ctl.txt
mkdir -p $O
[ -f "$APK" ] || { echo "NOT RUN: APK missing"; exit 2; }
adb shell "[ -f $ZD/$V/dmsh_vk.lib ]" || { echo "NOT RUN: library $V not in the test pack"; exit 2; }
P=$(adb shell pm path com.swap2native.test | head -1 | sed 's/package://' | tr -d '\r')
adb pull "$P" "$O/before.apk" | tail -1 || exit 1
adb shell am force-stop com.swap2native.test
adb install -r "$APK" | tail -1 || exit 1
SV=$(adb shell "$RA 'grep -h folder_save_0400486024DEC000 shared_prefs/launcher.xml'" | tr -d '\r'); echo "save pref before: $SV"
adb shell "$RA 'sed -i s#saves-test/ports-0400486024DEC000#saves-test/0400486024DEC000# shared_prefs/launcher.xml'"
drv() { adb shell am start -n com.swap2native.test/dev.nxnative.android.MainActivity --es gpu_driver $1 >/dev/null 2>&1; sleep 4; adb shell am force-stop com.swap2native.test; }
FAM=(
"all-drawn:"
"F12c000:eed1add7c89f5d34+92343fd5c0f3ecb2+0c1ffecd02018fb0+ae104328f80e5fb8"
"F159000:73dc0b90c4082e43+fed013936b4efa76+25c4a740753e7d7a+7fd36d22b1f0fd14"
"F185000:17c8ab6419068d4b+e7088344596a80aa+101ecb327aafe9b1+7eef23eeb0784836"
"F1b1000:4c7d6be5a7717c8d+140a2125c2e3c9ce+839241636fce850a+626fbf48041cb82b"
"F1e9000:bc9d26e29a45e6b6+e6df2f14035e7be7+68691c9a4a821751"
"F216000:edeefae4c37b0257+3a6340a04bf09797+a934ed1af79131cc+bc05374f59a92b2b"
"F238000:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d"
"F25a000:fed302d791a4ba43+a8df4b4354adef06+d98076e4148db34f+819c33c90234fcb6"
"F281000:f85bb2e8d78b864c+ac2f3feb11427426+d00c020b43022a68"
"F2a6000:604134a5262ff670+6a1ceebb6cff56dd+eebdb9347d09b344+ca03b41694d4c196"
"Ff9000:eb021183bf9b0092+65a079a285d693a0+96843c3dbdded1e7"
"all-drawn-again:")
shots() {
  sleep 255
  for f in "${FAM[@]}"; do
    n=${f%%:*}; k=${f#*:}
    if [ -n "$k" ]; then adb shell "echo 'env DM_VK_GRASS_KEYS=$k' >> $CTL; echo 'env DM_VK_GRASS=0' >> $CTL"
    else adb shell "echo 'env DM_VK_GRASS=2' >> $CTL"; fi
    sleep 6; adb exec-out screencap -p > $O/$n.png; echo "shot $n $(date +%T)"
  done
}
drv Turnip_Gen8_V39; adb shell input keyevent KEYCODE_WAKEUP
shots & SP=$!
python -I $R/dm/tools/android_bench.py --variant grassid:DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200 --runs 1 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A \
  --start 250 --secs 100 --tag grassid --out $O/hf 2>&1 | tail -1
wait $SP
grep -a -h "grass (DM_VK_GRASS" $O/hf/*/log.txt | cut -c1-200 | head -30
for f in $O/hf/*/log.txt; do echo "== crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
