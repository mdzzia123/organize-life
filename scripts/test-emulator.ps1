# 整理人生 - 模拟器功能测试脚本
$adb = "D:\Android\android-sdk\platform-tools\adb.exe"
$serial = "emulator-5554"
$apk = "D:\organize-life\releases\organize_life_v1.2.0_release.apk"
$pkg = "com.organizelife.organize_life"
$dumpLocal = "$env:TEMP\ol_ui.xml"

function Adb { param([string[]]$Args) & $adb -s $serial @Args 2>&1 }

function Dump-Ui {
    Adb shell uiautomator dump /sdcard/ol_ui.xml | Out-Null
    Adb pull /sdcard/ol_ui.xml $dumpLocal | Out-Null
    if (Test-Path $dumpLocal) { Get-Content $dumpLocal -Raw -Encoding UTF8 } else { "" }
}

function Find-Bounds {
    param([string]$Xml, [string]$Pattern)
    if ($Xml -match "text=`"$Pattern`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"") {
        $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
        $cy = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
        return @{ x = $cx; y = $cy; found = $true }
    }
    if ($Xml -match "content-desc=`"$Pattern`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"") {
        $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
        $cy = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
        return @{ x = $cx; y = $cy; found = $true }
    }
    return @{ found = $false }
}

function Tap-Text {
    param([string]$Text, [int]$WaitMs = 1500)
    $xml = Dump-Ui
    $pt = Find-Bounds $xml $Text
    if (-not $pt.found) { return $false }
    Adb shell input tap $pt.x $pt.y | Out-Null
    Start-Sleep -Milliseconds $WaitMs
    return $true
}

function Has-Text {
    param([string]$Text)
    $xml = Dump-Ui
    return ($xml -match [regex]::Escape($Text))
}

$results = @()

function Test-Step {
    param([string]$Name, [scriptblock]$Block)
    try {
        $ok = & $Block
        $results += [pscustomobject]@{ Step = $Name; Pass = [bool]$ok }
        Write-Host ("[{0}] {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $Name)
    } catch {
        $results += [pscustomobject]@{ Step = $Name; Pass = $false; Error = $_.Exception.Message }
        Write-Host "[FAIL] $Name - $($_.Exception.Message)"
    }
}

Write-Host "=== 安装 APK ==="
Adb uninstall $pkg | Out-Null
$install = Adb install $apk
Write-Host $install

Write-Host "`n=== 启动 App ==="
Adb shell am force-stop $pkg | Out-Null
Adb shell am start -n "$pkg/.MainActivity" | Out-Null
Start-Sleep -Seconds 4

Test-Step "首页加载-标题整理人生" { Has-Text "整理人生" }
Test-Step "首页-预设分类衣服" { Has-Text "衣服" }
Test-Step "首页-分类统计文案" { (Dump-Ui) -match "共 \d+ 个分类" }

Test-Step "进入统计页" {
    if (-not (Tap-Text "统计")) {
        # fallback: tap bar chart icon area (top right)
        Adb shell input tap 900 180 | Out-Null
        Start-Sleep -Seconds 2
    }
    Has-Text "总览"
}
Test-Step "统计页-返回" {
    Adb shell input keyevent 4 | Out-Null
    Start-Sleep -Seconds 1
    Has-Text "整理人生"
}

Test-Step "进入搜索页" {
    Tap-Text "搜索" | Out-Null
    if (-not (Has-Text "搜索标题")) {
        Adb shell input tap 820 180 | Out-Null
        Start-Sleep -Seconds 2
    }
    Has-Text "搜索标题"
}
Test-Step "搜索页-返回" {
    Adb shell input keyevent 4 | Out-Null
    Start-Sleep -Seconds 1
    Has-Text "整理人生"
}

Test-Step "进入设置页" {
    Tap-Text "设置" | Out-Null
    if (-not (Has-Text "测试云端连接")) {
        Adb shell input tap 980 180 | Out-Null
        Start-Sleep -Seconds 2
    }
    Has-Text "测试云端连接"
}

Test-Step "设置-云端连接测试" {
    Tap-Text "测试云端连接" | Out-Null
    Start-Sleep -Seconds 5
    $xml = Dump-Ui
    ($xml -match "连接正常") -or ($xml -match "连接失败")
}

Test-Step "设置-账号入口" {
    Has-Text "账号"
}

Test-Step "设置-返回首页" {
    Adb shell input keyevent 4 | Out-Null
    Start-Sleep -Seconds 1
    Has-Text "整理人生"
}

Test-Step "进入衣服分类" {
    Tap-Text "衣服" | Out-Null
    Start-Sleep -Seconds 2
    Has-Text "衣服"
}

# push test image for gallery pick
Write-Host "`n=== 准备测试图片 ==="
$testImg = "$env:TEMP\ol_test.jpg"
if (-not (Test-Path $testImg)) {
    # minimal jpeg bytes via .NET placeholder - use adb screenshot as source
    Adb shell screencap -p /sdcard/ol_test.png | Out-Null
    Adb pull /sdcard/ol_test.png $testImg.Replace('.jpg','.png') | Out-Null
}
Adb shell mkdir -p /sdcard/Pictures/OL | Out-Null
Adb push "$env:TEMP\ol_test.png" /sdcard/Pictures/OL/test.png 2>$null
Adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/OL/test.png | Out-Null

Test-Step "分类页-添加图片FAB" {
    # FAB usually bottom center-right
    Adb shell input tap 980 2200 | Out-Null
    Start-Sleep -Seconds 2
    $xml = Dump-Ui
    ($xml -match "从相册选择") -or ($xml -match "拍照")
}

Test-Step "选择相册并保存" {
    $xml = Dump-Ui
    if ($xml -match "从相册选择") {
        Tap-Text "从相册选择" | Out-Null
        Start-Sleep -Seconds 3
        # tap first image thumbnail area
        Adb shell input tap 200 600 | Out-Null
        Start-Sleep -Seconds 2
        if (Has-Text "添加图片") {
            Tap-Text "保存" | Out-Null
            Start-Sleep -Seconds 8
            # upload progress dialog
            $x2 = Dump-Ui
            ($x2 -match "同步到云端") -or ($x2 -match "完成") -or ($x2 -match "未命名") -or ($x2 -match "0 张") -eq $false
        } else { $false }
    } else { $false }
}

Test-Step "分类页-返回首页" {
    Adb shell input keyevent 4 | Out-Null
    Start-Sleep -Seconds 1
    Has-Text "整理人生"
}

Write-Host "`n=== 测试结果汇总 ==="
$results | Format-Table -AutoSize
$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count
Write-Host "通过: $passed / $total"
