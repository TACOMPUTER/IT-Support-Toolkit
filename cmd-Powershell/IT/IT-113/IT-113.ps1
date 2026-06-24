# =====================================================
# LINE TEST TẠM THỜI - XÓA SAU KHI CHẠY OK
# =====================================================
Clear-Host
Write-Host "====== [DEBUG] DA VAO DUOC FILE IT-113.PS1 ======" -ForegroundColor Magenta
Write-Host "Thu muc dang dung (PSScriptRoot): $PSScriptRoot" -ForegroundColor Cyan
Read-Host "Bam Enter de tiep tuc load cac thong so he thong..."
# =====================================================

# 🚩 <<<--- 'VARIABLE_IT.PS1' --->>>
$SystemDriveSW = "C:\SW"
if (Test-Path "$SystemDriveSW\variable_IT.ps1") {
    . "$SystemDriveSW\variable_IT.ps1"
}
# 🏁 <<<--- 'VARIABLE_IT.PS1' --->>>

# ... (các đoạn code phía dưới giữ nguyên)

# 🚩 <<<--- 'VARIABLE_IT.PS1' --->>>
$SystemDriveSW = "C:\SW"
if (Test-Path "$SystemDriveSW\variable_IT.ps1") {
    . "$SystemDriveSW\variable_IT.ps1"
}
# 🏁 <<<--- 'VARIABLE_IT.PS1' --->>>

# 🚩 <<<--- 'HEADER_FOR_IT-XXX.PS1' --->>>
if ($LibScript -and (Test-Path "$LibScript\Header_for_IT-xxx.ps1")) {
    . "$LibScript\Header_for_IT-xxx.ps1" -PSWidth 71 -PSHeight 23 -PosX 0 -PosY 60
}
# 🏁 <<<--- 'HEADER_FOR_IT-XXX.PS1' --->>>

# 🚩 <<<--- 'FORM-NOTIACT.PS1' --->>>
if ($LibScript -and (Test-Path "$LibScript\Form-NotiAct.ps1")) {
    . "$LibScript\Form-NotiAct.ps1"
}
# 🏁 <<<--- 'FORM-NOTIACT.PS1' --->>>


# =====================================================
# LOG & KHỞI TẠO TIẾN TRÌNH DEFENDER
# =====================================================
$Logs = "C:\Temp\DefenderExclusion.txt"
$logDir = Split-Path $Logs
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
Start-Transcript $Logs -Append -Force | Out-Null

function Normalize { param($p) return ($p.TrimEnd('\')).ToLower() }
function Get-RealPath {
    param($p)
    try { return (Get-Item -LiteralPath $p -ErrorAction Stop).FullName } catch { return $p }
}

function Wait-Defender {
    $svc = Get-Service WinDefend -ErrorAction SilentlyContinue
    if (-not $svc) { return $false }
    for ($i = 0; $i -lt 20; $i++) {
        if ($svc.Status -eq 'Running') {
            try { Get-MpPreference -ErrorAction Stop | Out-Null; return $true } catch {}
        }
        Start-Sleep 1
        try { $svc.Refresh() } catch {}
    }
    return $false
}

if (-not (Wait-Defender)) {
    Write-Host "❌ Defender chưa sẵn sàng" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit
}
Write-Host "✅ Defender OK" -ForegroundColor Cyan


# =====================================================
# CẤU HÌNH ĐƯỜNG DẪN LOẠI TRỪ (EXCLUSIONS)
# =====================================================
$requiredPaths = @(
    "\\IT\Software",
    "\\IT\Software2",
    "\\IT-E580\Software",
    "\\IT-E580\Software2",
    "C:\SW"
)
$desiredProcess = @("SppExtComObjHook.dll")
$desiredExt = @()

$validDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -in 2,3 }
$existingPaths = @()

foreach ($drive in $validDrives) {
    $root = $drive.DeviceID
    $softwareRoot = Join-Path $root "Software"
    if (Test-Path $softwareRoot) { $existingPaths += $softwareRoot }

    $software2Root = Join-Path $root "Software2"
    if (Test-Path $software2Root) { $existingPaths += $software2Root }

    $softwareOneDrive = Join-Path $root "OneDrive\TACOMPUTER\Software"
    if (Test-Path $softwareOneDrive) { $existingPaths += $softwareOneDrive }
}

# Add Tĩnh
$currentRaw = @((Get-MpPreference).ExclusionPath) | Where-Object { $_ }
$currentNorm = $currentRaw | ForEach-Object { Normalize $_ }
$toAdd = $requiredPaths | Where-Object { (Normalize $_) -notin $currentNorm }

foreach ($path in $toAdd) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction Stop
        Write-Host "ADD PATH : $path" -ForegroundColor Yellow
    } catch {
        Write-Host "FAIL ADD PATH : $path" -ForegroundColor Red
    }
}
if ($toAdd.Count -eq 0) { Write-Host "✔ PATH đủ, không cần thêm" -ForegroundColor Green }

# Add Động (Quét ổ đĩa)
$currentPaths = @((Get-MpPreference).ExclusionPath) | Where-Object { $_ }
$currentNorm  = $currentPaths | ForEach-Object { Normalize $_ }
$toAddDynamic = $existingPaths | Where-Object { (Normalize $_) -notin $currentNorm }

foreach ($p in $toAddDynamic) {
    try {
        Add-MpPreference -ExclusionPath $p | Out-Null
        Write-Host "ADD DYNAMIC PATH : $p" -ForegroundColor Yellow
    } catch { Write-Host "FAIL ADD PATH : $p" -ForegroundColor Red }
}
if ($toAddDynamic.Count -eq 0) { Write-Host "✔ Không có path mới cần thêm" -ForegroundColor Green }


# =====================================================
# ĐỒNG BỘ CONFIG VÀ PROCESS
# =====================================================
$tempJson = "C:\Temp\DefenderExclusions.json"
$data = @{ Path = $requiredPaths; Process = @(); Extension = @() }
$data | ConvertTo-Json -Depth 3 | Set-Content $tempJson -Encoding UTF8

$proc = "SppExtComObjHook.dll"
$fullPath = "$env:WINDIR\System32\$proc"
$currentProcess = @((Get-MpPreference).ExclusionProcess) | Where-Object { $_ }

if (Test-Path -LiteralPath $fullPath) {
    if ($proc -notin $currentProcess) {
        try { Add-MpPreference -ExclusionProcess $proc; Write-Host "ADD PROCESS : $proc" -ForegroundColor Yellow } catch {}
    } else { Write-Host "OK PROCESS  : $proc" -ForegroundColor Green }
} else {
    if ($proc -in $currentProcess) {
        try { Remove-MpPreference -ExclusionProcess $proc; Write-Host "REMOVE PROCESS : $proc (not found)" -ForegroundColor Red } catch {}
    } else { Write-Host "SKIP PROCESS : $proc (not found)" -ForegroundColor DarkGray }
}

# Khởi chạy giao diện Tray ẩn
try {
    Start-Process -FilePath "$env:WINDIR\system32\SecurityHealthSystray.exe" | Out-Null
} catch {}

Write-Host "`nDONE CONFIGURATION" -ForegroundColor Green
Stop-Transcript | Out-Null
Start-Sleep -Seconds 1


# =====================================================
# HÀM ĐIỀU HƯỚNG VÀ HIỂN THỊ MENU CLI
# =====================================================
function Run-IT-xxx {
    param([string]$ScriptPath)
    
    # Kiểm tra an toàn xem class WinAPI từ file gốc IT_Github.ps1 có tồn tại không
    if ("WinAPI" -as [type]) {
        $consoleHandle = [WinAPI]::GetConsoleWindow()
        [WinAPI]::ShowWindow($consoleHandle, 6) # Minimize file cha xuống
    }
    
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
    
    if ("WinAPI" -as [type]) {
        [WinAPI]::ShowWindow($consoleHandle, 9) # Restore lại file cha
    }
}

function Show-Menu-IT-113 {
    Clear-Host
    Write-Host "<<< Current 'Windows Security\Exclusions' list >>>" -ForegroundColor Cyan

    $preferences = Get-MpPreference
    [string[]]$paths = if ($preferences.ExclusionPath) { $preferences.ExclusionPath } else { @("Không có") }
    [string[]]$proc  = if ($preferences.ExclusionProcess) { $preferences.ExclusionProcess } else { @("Không có") }
    [string[]]$ext   = if ($preferences.ExclusionExtension) { $preferences.ExclusionExtension } else { @("Không có") }

    $col1 = [Math]::Max(($paths | Measure-Object -Property Length -Maximum).Maximum, "ExclusionPath".Length) + 3
    $col2 = [Math]::Max(($proc | Measure-Object -Property Length -Maximum).Maximum, "ExclusionProcess".Length) + 3
    $col3 = [Math]::Max(($ext | Measure-Object -Property Length -Maximum).Maximum, "ExclusionExtension".Length) + 3

    $max = ($paths.Count,$proc.Count,$ext.Count | Measure-Object -Maximum).Maximum

    Write-Host ("{0,-$col1}{1,-$col2}{2}" -f "ExclusionPath","ExclusionProcess","ExclusionExtension")
    Write-Host ("{0,-$col1}{1,-$col2}{2}" -f ("-"*($col1-3)),("-"*($col2-3)),("-"*($col3-3)))

    for ($i=0; $i -lt $max; $i++) {
        $p1 = if ($i -lt $paths.Count) { $paths[$i] } else { "" }
        $p2 = if ($i -lt $proc.Count)  { $proc[$i] } else { "" }
        $p3 = if ($i -lt $ext.Count)   { $ext[$i] } else { "" }
        Write-Host ("{0,-$col1}{1,-$col2}{2}" -f $p1,$p2,$p3) -ForegroundColor Yellow
    }
    
    $ConsoleWidth = if ($Host.UI.RawUI.WindowSize.Width) { $Host.UI.RawUI.WindowSize.Width } else { 80 }
    Write-Host ("+" * ($ConsoleWidth - 1)) -ForegroundColor DarkGray

    # LOGO TRUNG TÂM
    $text = " Khu vực IT quản lý "
    $pad = [Math]::Max(0, ($ConsoleWidth - 1) - $text.Length)
    $left  = [Math]::Floor($pad / 2)
    $right = $pad - $left
    Write-Host ("+" * $left) -ForegroundColor DarkGray -NoNewline
    Write-Host $text -NoNewline
    Write-Host ("+" * $right) -ForegroundColor DarkGray
    Write-Host ("+" * ($ConsoleWidth - 1)) -ForegroundColor DarkGray

    # DANH SÁCH HỖ TRỢ
    Write-Host "<<< Danh sách MENU >>>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Triển khai 'Windows Deployment'" -ForegroundColor Yellow
    Write-Host "2. Các vấn đề về 'Network, Firmware'" -ForegroundColor Magenta
    Write-Host "3. Các vấn đề khác liên quan 'SW2'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Vui lòng nhập số " -NoNewline
    Write-Host "(1-3)" -ForegroundColor Yellow -NoNewline
    Write-Host " để tiến hành: " -NoNewline

    $choice = Read-Host
    switch ($choice) {
        '1' {
            Write-Host "`n→ Đang chuyển đến: 1. Triển khai Windows Deployment..." -ForegroundColor Cyan
            Run-IT-xxx "$IT113Script\IT-113-1.ps1"
        }
        '2' {
            Write-Host "`n→ Đang chuyển đến: 2. Các vấn đề về Network..." -ForegroundColor Cyan
            Run-IT-xxx "$IT113Script\IT-113-2.ps1"
        }
        '3' {
            Write-Host "`n→ Đang chuyển đến: 3. Các vấn đề khác liên quan 'SW2'..." -ForegroundColor Cyan
            Run-IT-xxx "$IT113Script\IT-113-3.ps1"
        }
        '111' {
            Write-Host "`n→ Đang khởi động lại script..." -ForegroundColor Cyan
            $TargetScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$TargetScript`""
            exit
        }
        default { return }
    }
}

# Vòng lặp duy trì Menu tương tác
while ($true) {
    Show-Menu-IT-113
}
