# Release 签名配置
# 首次运行: powershell -ExecutionPolicy Bypass -File D:\organize-life\setup-release-signing.ps1
# 构建正式包: cd D:\organize-life\flutter_app && flutter build apk --release

$ErrorActionPreference = "Stop"
$androidDir = Join-Path $PSScriptRoot "flutter_app\android"
$keystore = Join-Path $androidDir "app\organize_life_release.jks"
$keyProps = Join-Path $androidDir "key.properties"

if (-not (Test-Path $keystore)) {
    $keytool = "keytool"
    if ($env:JAVA_HOME) {
        $keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    } elseif (Test-Path "D:\Android\Android Studio\jbr\bin\keytool.exe") {
        $keytool = "D:\Android\Android Studio\jbr\bin\keytool.exe"
    }

    Write-Host "Generating release keystore..."
    & $keytool -genkeypair -v `
        -keystore $keystore `
        -storepass organize2026 `
        -keypass organize2026 `
        -alias organize_life `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=Organize Life, OU=Dev, O=OrganizeLife, L=Shanghai, ST=Shanghai, C=CN"
}

if (-not (Test-Path $keyProps)) {
    @"
storePassword=organize2026
keyPassword=organize2026
keyAlias=organize_life
storeFile=organize_life_release.jks
"@ | Set-Content -Path $keyProps -Encoding UTF8
}

Write-Host "Release signing ready."
Write-Host "Keystore: $keystore"
Write-Host "Build: cd flutter_app; flutter build apk --release"
