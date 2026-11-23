#!/bin/bash
# Which of Ocarina of Time's Foliage.Product mesh families make Hyrule Field's grass (second run: the tall grass is F238000; which layer is left under it, and the
# medium level with a recording for flicker and sky): one Hyrule Field run on Turnip V39 (save copy
# user1117, keys 35:A,41:A,47:A, Link standing still, DM_VK_CHUNK=200) with the grass levels' APK (swap2-native-test-grass.apk: DM_VK_GRASS, DM_VK_GRASS_KEYS, live).
# From 255 s, live control lines left out one family at a time (DM_VK_GRASS_KEYS = all variants of one BNSH offset of Foliage.Product, DM_VK_GRASS=0) and a
# screenshot 6 s after each; the first and the last screenshot with every family drawn. The installed APK is put back at the end; the library v-706d0c7262fa is
# in the test pack. Screenshots and the log in out/zelda/grassid. folder_save and the default driver as they were.
export MSYS_NO_PATHCONV=1 ANDROID_SERIAL=${ANDROID_SERIAL:?set ANDROID_SERIAL to the phone adb serial}
R=D:/Projetos/Jogos/Android/MKWDroid; T=D:/Projetos/Jogos/Android/turnip-swap2; O=$T/out/zelda/grassid2; B=/data/local/tmp/s2bench
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
"all-drawn:2:"
"F238000:0:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d"
"F238000+F216000:0:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d+edeefae4c37b0257+3a6340a04bf09797+a934ed1af79131cc+bc05374f59a92b2b"
"F238000+F2a6000:0:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d+604134a5262ff670+6a1ceebb6cff56dd+eebdb9347d09b344+ca03b41694d4c196"
"F238000+F216000+F2a6000:0:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d+edeefae4c37b0257+3a6340a04bf09797+a934ed1af79131cc+bc05374f59a92b2b+604134a5262ff670+6a1ceebb6cff56dd+eebdb9347d09b344+ca03b41694d4c196"
"F238000+F216000+F2a6000+F25a000:0:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d+edeefae4c37b0257+3a6340a04bf09797+a934ed1af79131cc+bc05374f59a92b2b+604134a5262ff670+6a1ceebb6cff56dd+eebdb9347d09b344+ca03b41694d4c196+fed302d791a4ba43+a8df4b4354adef06+d98076e4148db34f+819c33c90234fcb6"
"Ff9000:0:eb021183bf9b0092+65a079a285d693a0+96843c3dbdded1e7"
"F238000-medium:1:3fa631a86435d3e8+a203347bb7bdbd03+a667b8bba94befa2+6311cb728285f17d"
"all-drawn-again:2:")
shots() {
  sleep 255
  for f in "${FAM[@]}"; do
    n=${f%%:*}; r=${f#*:}; lv=${r%%:*}; k=${r#*:}
    [ -n "$k" ] && adb shell "echo 'env DM_VK_GRASS_KEYS=$k' >> $CTL"
    adb shell "echo 'env DM_VK_GRASS=$lv' >> $CTL"
    sleep 6; adb exec-out screencap -p > $O/$n.png; echo "shot $n $(date +%T)"
    [ "$n" = F238000-medium ] && adb shell screenrecord --time-limit 8 --bit-rate 40000000 --size 1600x720 /sdcard/Download/grass-medium.mp4 && adb pull /sdcard/Download/grass-medium.mp4 $O/ | tail -1 && adb shell rm -f /sdcard/Download/grass-medium.mp4
  done
}
drv Turnip_Gen8_V39; adb shell input keyevent KEYCODE_WAKEUP
shots & SP=$!
python -I $R/dm/tools/android_bench.py --variant grassid:DM_VK_CHUNK=200,DM_VK_CHUNK_PASS=200 --runs 1 --save-ref $B/0400486024DEC000-user1117 --keys 35:A,41:A,47:A \
  --start 250 --secs 120 --tag grassid2 --out $O/hf 2>&1 | tail -1
wait $SP
grep -a -h "grass (DM_VK_GRASS" $O/hf/*/log.txt | cut -c1-200 | head -30
for f in $O/hf/*/log.txt; do echo "== crash=$(grep -a -c 'CRASH sig' $f) hang=$(grep -a -c 'GPU hang:' $f)"; done
echo "$SV" | grep -q ports- && adb shell "$RA 'sed -i s#saves-test/0400486024DEC000#saves-test/ports-0400486024DEC000# shared_prefs/launcher.xml'"
adb install -r "$O/before.apk" | tail -1
drv Turnip_Gen8_V39
adb shell "$RA 'grep -h -e \"name=.gpu_driver.\" -e folder_save_0400486024DEC000 shared_prefs/*.xml'"
adb shell input keyevent KEYCODE_HOME; rm -f "$O/before.apk"; echo "== end $(date)"
