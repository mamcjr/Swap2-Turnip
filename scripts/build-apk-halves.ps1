# Test APK (com.swap2native.test) from turnip-swap2\apk-tree: a git archive of MKWDroid's HEAD with the host's shuffle rewrite (vka_shader.c, vka_spvpatch.c/.h) on top,
# every game, the usual ondevice stage. Output: turnip-swap2\out\swap2-native-test-halves.apk
$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
Set-Location 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree\android\app'
& .\gradlew.bat "-PnxPackStage=\\wsl.localhost\Ubuntu-26.04\home\$env:USERNAME\swap2-ondevice\stage" apk --offline --console=plain 2>&1 | Tee-Object -FilePath 'D:\Projetos\Jogos\Android\turnip-swap2\out\build-apk-halves.log' | Select-Object -Last 25
"exit $LASTEXITCODE"
Get-ChildItem 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree\android\app\out\*.apk' | Select-Object Name, Length, LastWriteTime
