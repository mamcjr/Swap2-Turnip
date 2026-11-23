# Test APK (com.swap2native.test) from turnip-swap2 apk-tree-grass, re-exported from MKWDroid HEAD 83cb654 (2026-11-22 21:45: Foliage, Fog, DM_VK_CMD_CHECK, chunks of 200).
# The APK is copied to turnip-swap2 out as swap2-native-test-main.apk
$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
Set-Location 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-grass\android\app'
& .\gradlew.bat "-PnxPackStage=\\wsl.localhost\Ubuntu-26.04\home\$env:USERNAME\swap2-ondevice\stage" apk --offline --console=plain 2>&1 | Tee-Object -FilePath 'D:\Projetos\Jogos\Android\turnip-swap2\out\build-apk-main.log' | Select-Object -Last 25
"exit $LASTEXITCODE"
$apk = Get-ChildItem 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-grass\android\app\out\*test*.apk' | Sort-Object LastWriteTime | Select-Object -Last 1
if ($apk) { Copy-Item $apk.FullName 'D:\Projetos\Jogos\Android\turnip-swap2\out\swap2-native-test-main.apk' -Force; $apk | Select-Object Name, Length, LastWriteTime }

