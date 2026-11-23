# Test APK (com.swap2native.test) from turnip-swap2 apk-tree-grass: a copy of MKWDroid's working tree of 2026-11-22 14:00 (chain 706d0c7262fa, DM_VK_MESH_EXACT, DM_VK_CHUNK 200,
# the linked-pipeline fix) with the grass levels in the mesh fallback (DM_VK_GRASS, DM_VK_GRASS_KEYS; vka_mesh.inc grass_level, selftest/mesh_control.comp keep).
# The APK lands in apk-tree-grass android app out (copied to turnip-swap2 out as swap2-native-test-grass.apk)
$ErrorActionPreference = 'Continue'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
Set-Location 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-grass\android\app'
& .\gradlew.bat "-PnxPackStage=\\wsl.localhost\Ubuntu-26.04\home\$env:USERNAME\swap2-ondevice\stage" apk --offline --console=plain 2>&1 | Tee-Object -FilePath 'D:\Projetos\Jogos\Android\turnip-swap2\out\build-apk-grass.log' | Select-Object -Last 25
"exit $LASTEXITCODE"
$apk = Get-ChildItem 'D:\Projetos\Jogos\Android\turnip-swap2\apk-tree-grass\android\app\out\*test*.apk' | Sort-Object LastWriteTime | Select-Object -Last 1
if ($apk) { Copy-Item $apk.FullName 'D:\Projetos\Jogos\Android\turnip-swap2\out\swap2-native-test-grass.apk' -Force; $apk | Select-Object Name, Length, LastWriteTime }
