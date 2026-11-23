# Test APK (com.swap2native.test) from turnip-swap2 apk-tree-gm: a copy of MKWDroid's working tree of 2026-11-22 05:15 (chain 4eb05e585fb0 and its ports) with the
# 8,192-entry raw global memory table (vk_android_spv.py 13-step searches, vka_draw.c VKA_GMEM_MAP_ENTRIES; chain 706d0c7262fa), every game, the usual ondevice stage.
# The APK lands in apk-tree-gm android app out (copied to turnip-swap2 out as swap2-native-test-gm.apk)
$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
Set-Location 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-gm\android\app'
& .\gradlew.bat "-PnxPackStage=\\wsl.localhost\Ubuntu-26.04\home\$env:USERNAME\swap2-ondevice\stage" apk --offline --console=plain 2>&1 | Tee-Object -FilePath 'D:\Projetos\Jogos\Android\turnip-swap2\out\build-apk-gm.log' | Select-Object -Last 25
"exit $LASTEXITCODE"
$apk = Get-ChildItem 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-gm\android\app\out\*test*.apk' | Sort-Object LastWriteTime | Select-Object -Last 1
if ($apk) { Copy-Item $apk.FullName 'D:\Projetos\Jogos\Android\turnip-swap2\out\swap2-native-test-gm.apk' -Force; $apk | Select-Object Name, Length, LastWriteTime }
