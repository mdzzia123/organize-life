# 整理人生 - 本地开发启动脚本

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$FlutterApp = Join-Path $Root "flutter_app"

$env:Path = "D:\flutter\bin;" + $env:Path
$env:ANDROID_HOME = "D:\Android\android-sdk"
$env:JAVA_HOME = "D:\Android\Android Studio\jbr"

Write-Host "==> Flutter 版本"
flutter --version

Set-Location $FlutterApp

if (-not (Test-Path "android")) {
    Write-Host "==> 生成平台工程 ..."
    flutter create . --org com.organizelife --project-name organize_life
}

Write-Host "==> 安装依赖 ..."
flutter pub get

Write-Host "==> 生成 ObjectBox 代码 ..."
dart run build_runner build --delete-conflicting-outputs

Write-Host ""
Write-Host "完成！常用命令："
Write-Host "  cd $FlutterApp"
Write-Host "  flutter run                                    # 连接手机/模拟器运行"
Write-Host "  flutter build apk --debug                      # 构建调试 APK"
Write-Host ""
Write-Host "云函数 API 已配置为："
Write-Host "  https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/organize_life"
Write-Host ""
Write-Host "部署云函数："
Write-Host "  tcb login"
Write-Host "  powershell -File D:\organize-life\deploy-cloud.ps1"
