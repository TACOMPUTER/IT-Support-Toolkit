param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 55,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

# Force mã hóa Console sang UTF-8 để hiển thị tiếng Việt có dấu không bị lỗi font
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# Thống nhất đường dẫn cục bộ tại C:\SW
$SystemDriveSW  = "C:\SW"
$LocalScriptPath = Join-Path $SystemDriveSW "IT_Github-call.ps1"
$DestExePath     = Join-Path $SystemDriveSW "IT_Github.exe"

# URL để tự nâng quyền Admin từ RAM nếu chạy lần đầu qua Web
$ScriptWebUrl = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/cmd-Powershell/IT_Github.ps1"

# ===== INIT WINAPI =====
if (-not ("NativeMethods" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
}
$consoleHandle = [WinAPI]::GetConsoleWindow()

# Check Admin
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Đang nâng quyền Administrator..." -ForegroundColor Yellow
    if (Test-Path $LocalScriptPath) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$LocalScriptPath`"" -Verb RunAs
    } else {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Invoke-RestMethod -Uri '$ScriptWebUrl' | Invoke-Expression`"" -Verb RunAs
    }
    exit
}

# Chỉ cho 1 script chạy
# Chờ 1 giây để đảm bảo tiến trình đã định hình xong tiêu đề
Start-Sleep -Seconds 1

$targetTitle = "Running IT_Github.ps1"
$processList = Get-Process | Where-Object { $_.MainWindowTitle -like "*$targetTitle*" -and $_.Id -ne $PID }

foreach ($p in $processList) {
    try { 
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue 
        Write-Host "Đã đóng phiên bản cũ (PID: $($p.Id))..." -ForegroundColor DarkGray
    } catch {}
}

# Title giao diện
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running IT_Github.ps1 $adminText <<< Github\cmd-Powershell"

# Resize Console 
try {
    $maxWidth  = $host.UI.RawUI.MaxWindowSize.Width
    $maxHeight = $host.UI.RawUI.MaxWindowSize.Height
    $PSWidth  = [Math]::Min($PSWidth,  $maxWidth)
    $PSHeight = [Math]::Min($PSHeight, $maxHeight)
    
    [Console]::BufferWidth  = [Math]::Max($PSWidth,  [Console]::BufferWidth)
    [Console]::BufferHeight = [Math]::Max($PSHeight, [Console]::BufferHeight)
    [Console]::WindowWidth  = $PSWidth
    [Console]::WindowHeight = $PSHeight
} catch {
    try {
        $size = $host.UI.RawUI.WindowSize
        $size.Width = $PSWidth
        $size.Height = $PSHeight
        $host.UI.RawUI.WindowSize = $size
    } catch {}
}

$handle = (Get-Process -Id $PID).MainWindowHandle
$rect = New-Object WinMove+RECT
[WinMove]::GetWindowRect($handle, [ref]$rect)
$widthPx  = $rect.Right - $rect.Left
$heightPx = $rect.Bottom - $rect.Top
[WinMove]::MoveWindow($handle, $PosX, $PosY, $widthPx, $heightPx, $true) | Out-Null


# =====================================================
# KHU VỰC THIẾT LẬP ĐƯỜNG DẪN (TỰ ĐỘNG THEO VỊ TRÍ SCRIPT)
# =====================================================

# Lấy đường dẫn thư mục chứa chính file script này
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# $SourceSW là thư mục gốc nơi chứa bộ công cụ của bạn
$SourceSW = $ScriptDir

# $SourceSW2 là thư mục "Software2" nằm cùng cấp với thư mục chứa script
$SourceSW2 = Join-Path (Split-Path -Parent $ScriptDir) "Software2"

$currentUser = "$env:COMPUTERNAME\$env:USERNAME"

# IT_Github.exe nằm ngay trong thư mục chứa file script (theo như bạn nói)
$ExeSourcePath = Join-Path $ScriptDir "IT_Github.exe"

# Định nghĩa Base URL (phần chung của tất cả các file)
$BaseGithubUrl = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/refs/heads/main/cmd-Powershell"

# =====================================================


# =====================================================
# CHÉP FILE VÀO C:\SW + TẠO SHORTCUT START MENU
# =====================================================
if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }

# Định nghĩa nội dung chuẩn cho file IT_Github-call.ps1
$CallScriptContent = 'Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/cmd-Powershell/IT_Github.ps1?t=$([DateTime]::Now.Ticks)")'

# Kiểm tra nếu file đang chạy KHÔNG nằm trong C:\SW
if ($MyInvocation.MyCommand.Path -notlike "$SystemDriveSW\*") {
    
    if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }
    
    # Copy file IT_Github-call.ps1 (Giả định nó nằm cùng thư mục với file exe bạn đang chạy)
    $SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SourceCallScript = Join-Path $SourceDir "IT_Github-call.ps1"
    $SourceExe = Join-Path $SourceDir "IT_Github.exe"
    
    if (Test-Path $SourceCallScript) { Copy-Item $SourceCallScript $LocalScriptPath -Force }
    if (Test-Path $SourceExe) { Copy-Item $SourceExe $DestExePath -Force }
    
    Write-Host "[SYSTEM] Đã sao chép file vào $SystemDriveSW. Đang khởi động lại từ C:\SW..." -ForegroundColor Green
    
    # Chạy file .exe từ C:\SW
    Start-Process -FilePath $DestExePath
    exit
}

# 🚩 <<<--- TẠO SHORTCUT IT_Github.exe --->>>

$WshShell = New-Object -ComObject WScript.Shell

    # Đảm bảo C:\SW tồn tại
if (-not (Test-Path $SystemDriveSW)) {
    New-Item -ItemType Directory -Path $SystemDriveSW -Force | Out-Null
}

    # 3. Định nghĩa đường dẫn Start Menu
$StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
$ShortcutStartMenuPath = Join-Path $StartMenuProgramsPath "IT_Github.exe.lnk"

    # 4. Tạo shortcut trong Start Menu
if (Test-Path $ShortcutStartMenuPath) {
    Remove-Item $ShortcutStartMenuPath -Force
}

$ShortcutStartMenu = $WshShell.CreateShortcut($ShortcutStartMenuPath)
$ShortcutStartMenu.TargetPath = $DestExePath
$ShortcutStartMenu.WorkingDirectory = $SystemDriveSW
$ShortcutStartMenu.Description = "IT Github by TACOMPUTER"
$ShortcutStartMenu.IconLocation = $DestExePath
$ShortcutStartMenu.Save()

    # 5. Thông báo kết quả
Write-Host "[SYSTEM] Đã tạo Shortcut tại Start Menu!" -ForegroundColor Green
Write-Host "Path: $ShortcutStartMenuPath" -ForegroundColor DarkGray

# 🏁 <<<--- KẾT THÚC TẠO SHORTCUT --->>>

# =====================================================
# KHU VỰC CORE TIẾN TRÌNH CON - CHẠY HOÀN TOÀN TRÊN RAM
# =====================================================

# =====================================================
# CẤU TRÚC MENU PHÂN CẤP (IT-113 -> IT-113-1 -> IT-113-1-1)
# =====================================================

# --- MENU CẤP 3: IT-113-1-1 ---
function Show-SubSubMenu-WindowsSetup {
    $subSubChoice = ""
    while ($subSubChoice -ne "0") {
        Clear-Host
        Write-Host "=== CÀI ĐẶT WINDOWS (LOCAL MANAGER) IT-113-1-1 ===" -ForegroundColor Cyan
        Write-Host "1. Tác vụ 1..." -ForegroundColor Yellow
        Write-Host "2. Tác vụ 2..." -ForegroundColor Yellow
        Write-Host "0. Quay lại Menu Deployment (IT-113-1)" -ForegroundColor DarkGray
        
        $subSubChoice = Read-Host "Nhập lựa chọn (1-8 hoặc 0)"
        switch ($subSubChoice) {
            '1' { Write-Host "Đang chạy 1..." -ForegroundColor Green; Start-Sleep 1 }
            '0' { return }
            default { Write-Host "Lựa chọn không hợp lệ!"; Start-Sleep 1 }
        }
    }
}

# --- MENU CẤP 2: IT-113-1 ---
function Show-Deployment-Menu {
    $subChoice = ""
    while ($subChoice -ne "0") {
        Clear-Host
        Write-Host "=== TRIỂN KHAI WINDOWS (DEPLOYMENT) IT-113-1 ===" -ForegroundColor Cyan
        Write-Host "1. Vừa cài đặt xong Windows (Vào IT-113-1-1)" -ForegroundColor Yellow
        Write-Host "2. Tác vụ 2..." -ForegroundColor Yellow
        Write-Host "0. Quay lại Menu IT-113" -ForegroundColor DarkGray
        
        $subChoice = Read-Host "Nhập lựa chọn (1-5 hoặc 0)"
        switch ($subChoice) {
            '1' { Show-SubSubMenu-WindowsSetup }
            '2' { Write-Host "Đang xử lý..." -ForegroundColor Green; Start-Sleep 1 }
            '0' { return }
            default { Write-Host "Lựa chọn không hợp lệ!"; Start-Sleep 1 }
        }
    }
}

# --- MENU CẤP 1: IT-113 ---
function Invoke-IT113-Menu {
    # Thực hiện các thiết lập cần thiết (ExclusionPath)
    # ... (Giữ nguyên logic của bạn ở đây) ...

    $choice = ""
    while ($choice -ne "0") {
        Clear-Host
        Write-Host "=== MENU CHÍNH IT-113 ===" -ForegroundColor Cyan
        Write-Host "1. Triển khai Windows (IT-113-1)" -ForegroundColor Yellow
        Write-Host "2. Fix Network" -ForegroundColor Yellow
        Write-Host "3. Tiện ích SW2" -ForegroundColor Yellow
        Write-Host "0. Quay lại Menu chính" -ForegroundColor DarkGray
        
        $choice = Read-Host "Vui lòng nhập số"
        switch ($choice) {
            '1' { Show-Deployment-Menu }
            '2' { Write-Host "🚀 Đang chạy: Fix Network..." -ForegroundColor Green; Start-Sleep 1 }
            '3' { Write-Host "🚀 Đang chạy: Tiện ích SW2..." -ForegroundColor Green; Start-Sleep 1 }
            '0' { return }
            default { Write-Host "Lựa chọn không hợp lệ!"; Start-Sleep 1 }
        }
    }
}

# --- MENU 115 ---
function Invoke-IT115-Menu {
    Clear-Host
    Write-Host "=== KHU VỰC HỖ TRỢ IT-115 (RAM MODE) ===" -ForegroundColor Magenta
    Read-Host "`nNhấn Enter để quay lại Menu chính..."
}

# =====================================================
# GIAO DIỆN MENU CHÍNH (MAIN MENU)
# =====================================================
function Show-Menu-IT {
    Clear-Host
    # Mảng lưu thông tin xuất file HTML
    $script:ReportLines = New-Object System.Collections.Generic.List[string]

    $ConsoleWidth = $Host.UI.RawUI.WindowSize.Width
    $LineWidth = [Math]::Max(40, $ConsoleWidth - 1) 

    # Header Console (Không ghi vào file HTML)
    $BorderLine = "+" * $LineWidth
    Write-Host $BorderLine -ForegroundColor DarkGray
    $text = " IT support, Scripted by TACOMPUTER & GPT, 0933.848.990 "
    $pad = [Math]::Max(0, $LineWidth - $text.Length)
    $left  = [Math]::Floor($pad / 2)
    $right = $pad - $left
    Write-Host ("+" * $left) -ForegroundColor DarkGray -NoNewline
    Write-Host $text -NoNewline
    Write-Host ("+" * $right) -ForegroundColor DarkGray
    Write-Host $BorderLine -ForegroundColor DarkGray

    # BẮT ĐẦU ĐOẠN LẤY DỮ LIỆU CHO HTML từ [ PC Information ]
    $IsLaptop = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) -ne $null
    if ($IsLaptop) {
        Write-Host "[ Laptop Information ]" -ForegroundColor Cyan
        $script:ReportLines.Add("<span class='cyan'>[ Laptop Information ]</span>")
    } else {
        Write-Host "[ PC Information ]" -ForegroundColor Cyan
        $script:ReportLines.Add("<span class='cyan'>[ PC Information ]</span>")
    }

    $global:LabelWidth = 20
    $global:SubLabelWidth = 18

    # Hàm in dòng chính
    function Show-Line {
        param($label, $value)
        $fmtLabel = "{0,-$global:LabelWidth}" -f $label
        $script:ReportLines.Add("<span class='green'>$fmtLabel &gt;&gt;&gt; </span><span class='yellow'>$value</span>")
        Write-Host ("{0,-$global:LabelWidth} >>> " -f $label) -NoNewline -ForegroundColor Green
        Write-Host $value -ForegroundColor Yellow
    }

    # Hàm in dòng phụ
    function Show-SubLine {
        param($label, $value)
        $fmtSubLabel = "  {0,-$global:SubLabelWidth}" -f $label
        $script:ReportLines.Add("<span class='blue'>$fmtSubLabel : $value</span>")
        Write-Host ("  {0,-$global:SubLabelWidth} : " -f $label) -NoNewline -ForegroundColor Blue
        Write-Host $value -ForegroundColor Blue
    }

    $CS      = Get-CimInstance Win32_ComputerSystem
    $BB      = Get-CimInstance Win32_BaseBoard
    $CPU     = Get-CimInstance Win32_Processor
    $BIOS    = Get-CimInstance Win32_BIOS
    $GPU     = Get-CimInstance Win32_VideoController
    $OS      = Get-CimInstance Win32_OperatingSystem
    $RegOS   = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    Show-Line "Brand (OEM)" $CS.Manufacturer
    Show-Line "Mainboard" $BB.Manufacturer
    Show-Line "Product" $BB.Product
    Show-Line "Model" $CS.Model
    Show-Line "Serial" $BIOS.SerialNumber
    Show-Line "BIOS ver" $BIOS.SMBIOSBIOSVersion
    
    $script:ReportLines.Add("")
    Write-Host ""

    if ($CPU.Count -gt 1) {
        Show-Line "CPU" ""
        $i = 1; foreach ($c in $CPU) { Show-SubLine "CPU $i" $c.Name; $i++ }
    } else { Show-Line "CPU" $CPU.Name }

    # RAM Info
    $RAM = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $arrays = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
    $ramType = if ($arrays.MemoryErrorCorrection -in 5,6) { "ECC" } else { "Non-ECC" }
    $totalRAM = "{0:N0}" -f (($RAM | Measure-Object Capacity -Sum).Sum / 1GB)
    Show-Line "RAM (Total)" "$totalRAM GB ($ramType)"
    
    $trueUsedSlots = 0
    $i = 1
    foreach ($ram in $RAM) {
        $size = "{0:N0}" -f ($ram.Capacity / 1GB)
        $slot = if ($ram.DeviceLocator) { $ram.DeviceLocator.Trim() } else { "Slot $i" }
        $manufacturer = if ($ram.Manufacturer) { $ram.Manufacturer.Trim() } else { "Unknown" }
        $partNumber = if ($ram.PartNumber) { $ram.PartNumber.Trim() } else { "Unknown" }
        
        $RamDetails = "$size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
        Show-SubLine $slot $RamDetails
        $i++; $trueUsedSlots++
    }
    $TotalSlots = if ($arrays) { @($arrays)[0].MemoryDevices } else { 2 }
    Show-SubLine "Used Slots" "$trueUsedSlots/$TotalSlots"

    # Disk Info
    $disks = Get-CimInstance Win32_DiskDrive
    $totalDisk = "{0:N0}" -f (($disks | Measure-Object Size -Sum).Sum / 1GB)
    Show-Line "Storage (Total)" "$totalDisk GB"
    $i = 1; foreach ($disk in $disks) { Show-SubLine "Disk $i" ("{0} | {1:N0} GB" -f $disk.Model, ($disk.Size / 1GB)); $i++ }

    # GPU Info
    $vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) { if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ } }
    Show-Line "Graphics" ("$vgaCount VGA / $gpuCount GPU")
    foreach ($g in $GPU) { Show-SubLine "GPU_Info" ("" + $g.Name) }
    
    $script:ReportLines.Add("")
    Write-Host ""
    
    # MAC Info
    Show-Line "MAC Address" ""
    $netAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -and $_.PhysicalAdapter -eq $true }
    foreach ($adapter in $netAdapters) {
        $Type = "LAN"
        if ($adapter.Name -match "Wireless|Wi-Fi|802.11") { $Type = "Wi-Fi" }
        elseif ($adapter.Name -match "Bluetooth") { $Type = "Bluetooth" }
        
        $LabelName = "$Type - $($adapter.Name)"
        $script:ReportLines.Add("<span class='blue'>  $LabelName</span>")
        Write-Host "  $LabelName" -ForegroundColor Blue
        Show-SubLine "" $adapter.MACAddress
    }
    
    $script:ReportLines.Add("")
    Write-Host ""

    $version = $RegOS.DisplayVersion
    if (!$version) { $version = $RegOS.ReleaseId }
    Show-Line "Windows" "$($RegOS.ProductName) | $version | $($RegOS.CurrentBuild)"
    
    # DÒNG CUỐI CÙNG CHO FILE HTML
    Show-Line "Current User" $currentUser
    
    # =====================================================
    # ĐÓNG GÓI XUẤT FILE HTML (TẮT TỰ ĐỘNG WRAP TEXT)
    # =====================================================
    $Serial = if ($BIOS.SerialNumber) { $BIOS.SerialNumber.Trim() } else { "UnknownSerial" }
    $CleanModel = ($CS.Model -replace '[\\/:*?"<>|]', '').Trim()
    $Content = $script:ReportLines -join "`r`n"
    
    $HtmlTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>System Report - $CleanModel</title>
    <style>
        body { background-color: #0c0c0c; color: #cccccc; font-family: 'Consolas', 'Courier New', monospace; padding: 20px; font-size: 14px; line-height: 1.4; }
        pre { margin: 0; white-space: pre; }
        .gray { color: #555555; font-weight: bold; }
        .white { color: #ffffff; font-weight: bold; }
        .cyan { color: #00ffff; font-weight: bold; }
        .green { color: #00ff00; }
        .yellow { color: #ffff00; font-weight: bold; }
        .blue { color: #3b82f6; }
        .magenta { color: #ff00ff; }
    </style>
</head>
<body>
    <pre>$Content</pre>
</body>
</html>
"@

    $FileNameReport = "{0}_{1}.html" -f $CleanModel, $Serial
    $LocalReportsFolder = Join-Path $SystemDriveSW "Reports"
    
    try {
        if (-not (Test-Path $LocalReportsFolder)) { 
            New-Item -Path $LocalReportsFolder -ItemType Directory -Force | Out-Null 
        }
        $LocalFile = Join-Path $LocalReportsFolder $FileNameReport
        [System.IO.File]::WriteAllText($LocalFile, $HtmlTemplate, [System.Text.Encoding]::UTF8)
    } catch {
        Write-Host "[LOCAL] ERROR -> Không thể ghi file báo cáo vào ổ C!" -ForegroundColor Red
    }
    
    # Đẩy lên Server LAN
    $ServerHost = "IT"
    $NetworkFolder = "\\$ServerHost\Guest\Computer list"
    if (Test-Connection -ComputerName $ServerHost -Count 1 -Quiet) {
        try {
            if (-not (Test-Path $NetworkFolder)) { 
                New-Item -Path $NetworkFolder -ItemType Directory -Force | Out-Null 
            }
            $NetworkFile = Join-Path $NetworkFolder $FileNameReport
            [System.IO.File]::WriteAllText($NetworkFile, $HtmlTemplate, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Host "[ONLINE] OK -> Nhưng folder mạng LAN đang chặn quyền ghi báo cáo!" -ForegroundColor Red
        }
    } else {
        Write-Host "[OFFLINE] Không thấy Server mạng '$ServerHost', hoàn tất chạy phần mềm." -ForegroundColor DarkGray
    }

    # =====================================================
    # PHẦN ĐƯỜNG DẪN DƯỚI MENU (CHỈ IN TRÊN CONSOLE)
    # =====================================================
    Write-Host $BorderLine -ForegroundColor DarkGray
    Write-Host ("{0,-$global:LabelWidth} >>> " -f "IT_Github.exe & IT_Github-call.ps1 Path") -NoNewline -ForegroundColor Green
    Write-Host $SourceSW -ForegroundColor Yellow
    
    Write-Host "User vui lòng nhập số 115 để được hỗ trợ: " -NoNewline
    $topMenu = Read-Host
    switch ($topMenu) {
        "111" { 
            Write-Host "`n→ Đang khởi động lại hệ thống..." -ForegroundColor Cyan
            
            # 1. Tìm đường dẫn file .exe đang chạy
            $ExePath = (Get-Process -Id $PID).Path # Hoặc trỏ cứng đến vị trí file nếu biết rõ
            
            # 2. Khởi động lại file .exe từ ổ mạng
            # Dùng Start-Process để chạy .exe độc lập với tiến trình PowerShell hiện tại
            if (Test-Path $ExeSourcePath) {
                Start-Process -FilePath $ExeSourcePath
            }
            
            # 3. Thoát tiến trình hiện tại
            exit 
        }
        "113" { Invoke-IT113-Menu } 
        "115" { Invoke-IT115-Menu } 
        default { exit }            
    }
}

# Vòng lặp duy trì giao diện
while ($true) { 
    Show-Menu-IT 
}
