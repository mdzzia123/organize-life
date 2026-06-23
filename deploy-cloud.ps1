# 部署 organize_life 云函数到腾讯云 CloudBase
# 首次运行需先登录: tcb login

$ErrorActionPreference = "Stop"
$CloudDir = Join-Path $PSScriptRoot "cloud"
$FnDir = Join-Path $CloudDir "organize_life"

Write-Host "==> 安装云函数依赖 ..."
Set-Location $FnDir
npm install --production 2>&1 | Out-Null

Write-Host "==> 检查 CloudBase 登录状态 ..."
$envList = tcb env list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "请先登录腾讯云：" -ForegroundColor Yellow
    Write-Host "  tcb login"
    Write-Host ""
    Write-Host "登录完成后重新运行此脚本。"
    exit 1
}

Set-Location $CloudDir
Write-Host "==> 部署 HTTP 云函数 organize_life ..."
tcb fn deploy organize_life --dir organize_life --httpFn --path /organize_life --force 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "部署成功！" -ForegroundColor Green
    Write-Host "API 地址: https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/organize_life"
    Write-Host ""
    Write-Host "测试命令:"
    Write-Host '  curl -X POST "https://madi-213-8gs6wu0se568f2d1-1302661085.ap-shanghai.app.tcloudbase.com/organize_life" -H "Content-Type: application/json" -d "{\"action\":\"ping\"}"'
} else {
    Write-Host "部署失败，请检查登录状态和控制台权限。" -ForegroundColor Red
    exit 1
}
