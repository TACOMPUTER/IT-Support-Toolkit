param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 55,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

# Thống nhất đường dẫn cục bộ tại C:\SW
$SystemDriveSW  = "C:\SW"
$LocalScriptPath = Join-Path $SystemDriveSW "IT_Github.ps1"
$DestExePath     = Join-Path $SystemDriveSW "IT_Github.exe"

# URL để tự nâng quyền Admin từ RAM nếu chạy lần đầu qua Web
$ScriptWebUrl = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/cmd-Powershell/IT_Github.ps1"

# ===== INIT WINAPI =====
if (-not ("WinAPI" -as [type])) {
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
    Write-Host "⚠️ Dang nang quyen Administrator..." -ForegroundColor Yellow
    if (Test-Path $LocalScriptPath) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$LocalScriptPath`"" -Verb RunAs
    } else {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Invoke-RestMethod -Uri '$ScriptWebUrl' | Invoke-Expression`"" -Verb RunAs
    }
    exit
}

# Chỉ cho 1 script chạy
$currentPID = $PID
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
    $_.ProcessId -ne $currentPID -and
    ($_.CommandLine -match "IT_Github.ps1" -or $_.CommandLine -match "Invoke-Expression")
} | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
}

# Title giao diện (Đã cập nhật theo cấu trúc đường dẫn Github anh yêu cầu)
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running IT_Github.ps1 $adminText <<< Github\cmd-Powershell"

# Resize Console 
try {
    $maxWidth  = $host.UI.RawUI.MaxWindowSize.Width
    $maxHeight = $host.UI.RawUI.MaxWindowSize.Height
    $PSWidth  = [Math]::Min($PSWidth,  $maxWidth)
    $PSHeight = [Math]::Min($PSHeight, $maxHeight)
    
    [Console]::BufferWidth  = [Math]::Max($PSWidth,  [Console]::BufferWidth)
    [Console]::BufferHeight = [Math]::Max($PSHeight, [Console]::BufferHeight)
    [Console]::WindowWidth  = $PSWidth
    [Console]::WindowHeight = $PSHeight
} catch {
    try {
        $size = $host.UI.RawUI.WindowSize
        $size.Width = $PSWidth
        $size.Height = $PSHeight
        $host.UI.RawUI.WindowSize = $size
    } catch {}
}

# Move Window
if (-not ("WinMove" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinMove {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
}
$handle = (Get-Process -Id $PID).MainWindowHandle
$rect = New-Object WinMove+RECT
[WinMove]::GetWindowRect($handle, [ref]$rect)
$widthPx  = $rect.Right - $rect.Left
$heightPx = $rect.Bottom - $rect.Top
[WinMove]::MoveWindow($handle, $PosX, $PosY, $widthPx, $heightPx, $true) | Out-Null


# =====================================================
# KHU VỰC THIẾT LẬP ĐƯỜNG DẪN 
# =====================================================
$TargetFolder = "OneDrive\TACOMPUTER\Software"
$SourceSW = "C:\SW" 

$AllDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.Name -ne "C:\" }
foreach ($d in $AllDrives) {
    $CheckPath = Join-Path $d.Name $TargetFolder
    if (Test-Path $CheckPath) {
        $SourceSW = $CheckPath
        break
    }
}
if ($SourceSW -eq "C:\SW") {
    $CheckC = Join-Path "C:\" $TargetFolder
    if (Test-Path $CheckC) { $SourceSW = $CheckC }
}

if ($SourceSW -match "OneDrive\\TACOMPUTER\\Software$") {
    $drive = [System.IO.Path]::GetPathRoot($SourceSW)
    $SourceSW2 = Join-Path $drive "Software2"
} else {
    $SourceSW2 = $SourceSW + "2"
}
$currentUser = "$env:COMPUTERNAME\$env:USERNAME"
$ExeSourcePath = Join-Path $SourceSW "OS Tools\cmd-Powershell\IT_Github.exe"


# =====================================================
# CHÉP FILE VÀO C:\SW + TẠO SHORTCUT START MENU
# =====================================================
if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }

# 1. Lưu/Đồng bộ file IT_Github.ps1 vào C:\SW
if ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript' -or $MyInvocation.MyCommand.Path -ne $LocalScriptPath) {
    try {
        $CurrentCode = Get-Content -Path $MyInvocation.MyCommand.Path -Raw -ErrorAction SilentlyContinue
        if (-not $CurrentCode) {
            $CurrentCode = Invoke-RestMethod -Uri $ScriptWebUrl -Headers @{ "Cache-Control" = "no-cache" } -ErrorAction SilentlyContinue
        }
        if ($CurrentCode) { [System.IO.File]::WriteAllText($LocalScriptPath, $CurrentCode) }
    } catch {}
}

# 2. Sao chép file IT_Github.exe vào C:\SW
if (Test-Path $ExeSourcePath) {
    Copy-Item -Path $ExeSourcePath -Destination $DestExePath -Force | Out-Null
    Write-Host "[SYSTEM] Da sao chep IT_Github.exe vao $SystemDriveSW" -ForegroundColor Green
}

# 3. Tạo Shortcut Start Menu trỏ vào file C:\SW\IT_Github.exe vừa chép
try {
    $StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
    $StartMenuProgramslnk  = "$StartMenuProgramsPath\IT_Github.exe.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    
    if (Test-Path $StartMenuProgramslnk) { Remove-Item $StartMenuProgramslnk -Force }
    
    $ShortcutStartMenu = $WshShell.CreateShortcut($StartMenuProgramslnk)
    $ShortcutStartMenu.TargetPath = $DestExePath
    $ShortcutStartMenu.WorkingDirectory = $SystemDriveSW
    $ShortcutStartMenu.Save()
} catch {
    Write-Host "[WARNING] Khong the tao shortcut Start Menu!" -ForegroundColor Yellow
}


# =====================================================
# KHU VỰC CORE TIẾN TRÌNH CON - CHẠY HOÀN TOÀN TRÊN RAM
# =====================================================

# --- MENU 113 CHẠY TRÊN RAM ---
function Invoke-IT113-Menu {
    $requiredPaths = @("\\IT\Software", "\\IT\Software2", "\\IT-E580\Software", "\\IT-E580\Software2", "C:\SW")
    $validDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -in 2,3 }
    $existingPaths = @()
    foreach ($drive in $validDrives) {
        $root = $drive.DeviceID
        if (Test-Path (Join-Path $root "Software")) { $existingPaths += Join-Path $root "Software" }
        if (Test-Path (Join-Path $root "Software2")) { $existingPaths += Join-Path $root "Software2" }
        if (Test-Path (Join-Path $root "OneDrive\TACOMPUTER\Software")) { $existingPaths += Join-Path $root "OneDrive\TACOMPUTER\Software" }
    }
    $currentRaw = @((Get-MpPreference).ExclusionPath) | Where-Object { $_ }
    $currentNorm = $currentRaw | ForEach-Object { ($_.TrimEnd('\')).ToLower() }
    
    foreach ($path in ($requiredPaths + $existingPaths)) {
        if (($path.TrimEnd('\')).ToLower() -notin $currentNorm) {
            try { Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue } catch {}
        }
    }

    while ($true) {
        Clear-Host
        $ConsoleWidth = $Host.UI.RawUI.WindowSize.Width
        $LineWidth = [Math]::Max(40, $ConsoleWidth - 1)

        Write-Host "<<< Current 'Windows Security\Exclusions' list >>>" -ForegroundColor Cyan
        $preferences = Get-MpPreference
        $paths = if ($preferences.ExclusionPath) { $preferences.ExclusionPath } else { @("Không có") }
        $paths | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        
        Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray
        Write-Host "=== KHU VỰC IT QUẢN LÝ (RAM MODE) ===" -ForegroundColor Cyan
        Write-Host "1. Triển khai 'Windows Deployment'" -ForegroundColor Yellow
        Write-Host "2. Các vấn đề về 'Network, Firmware'" -ForegroundColor Magenta
        Write-Host "3. Các vấn đề khác liên quan 'SW2'" -ForegroundColor Yellow
        Write-Host "111. Quay lại Menu chính" -ForegroundColor Gray
        Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray
        
        $choice = Read-Host "Vui long nhap so (1-3 hoac 111)"
        switch ($choice) {
            '1' { 
                Clear-Host
                Write-Host "🚀 Dang chay: Windows Deployment hoan toan tren RAM..." -ForegroundColor Green
                Read-Host "`nNhan Enter de quay lai Menu IT-113..."
            }
            '2' { 
                Clear-Host
                Write-Host "🚀 Dang chay: Fix Network & Update Firmware tren RAM..." -ForegroundColor Green
                Read-Host "`nNhan Enter de quay lai Menu IT-113..."
            }
            '3' { 
                Clear-Host
                Write-Host "🚀 Dang chay: Tien ich SW2 tren RAM..." -ForegroundColor Green
                Read-Host "`nNhan Enter de quay lai Menu IT-113..."
            }
            '111' { return } 
            default { Write-Host "Lua chon khong hop le!"; Start-Sleep -Seconds 1 }
        }
    }
}

# --- MENU 115 CHẠY TRÊN RAM ---
function Invoke-IT115-Menu {
    Clear-Host
    Write-Host "=== KHU VỰC HỖ TRỢ IT-115 (RAM MODE) ===" -ForegroundColor Magenta
    Read-Host "`nNhan Enter de quay lai Menu chinh..."
    return
}


# =====================================================
# GIAO DIỆN MENU CHÍNH (MAIN MENU)
# =====================================================
function Show-Menu-IT {
    Clear-Host
    # Khởi tạo mảng lưu thông tin xuất file HTML sạch
    $script:ReportLines = New-Object System.Collections.Generic.List[string]

    $ConsoleWidth = $Host.UI.RawUI.WindowSize.Width
    $LineWidth = [Math]::Max(40, $ConsoleWidth - 1) 

    # Header Console (Không ghi vào file HTML)
    $BorderLine = "+" * $LineWidth
    Write-Host $BorderLine -ForegroundColor DarkGray
    $text = " IT support, Scripted by TACOMPUTER & GPT, 0933.848.990 "
    $pad = [Math]::Max(0, $LineWidth - $text.Length)
    $left  = [Math]::Floor($pad / 2)
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
        $fmtSubLabel = "  {0,-$global:SubLabelWidth}" -f $label
        $script:ReportLines.Add("<span class='blue'>$fmtSubLabel : $value</span>")
        Write-Host ("  {0,-$global:SubLabelWidth} : " -f $label) -NoNewline -ForegroundColor Blue
        Write-Host $value -ForegroundColor Blue
    }

    $CS      = Get-CimInstance Win32_ComputerSystem
    $BB      = Get-CimInstance Win32_BaseBoard
    $CPU     = Get-CimInstance Win32_Processor
    $BIOS    = Get-CimInstance Win32_BIOS
    $GPU     = Get-CimInstance Win32_VideoController
    $OS      = Get-CimInstance Win32_OperatingSystem
    $RegOS   = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

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
        
        $RamDetails = "$size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
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
        $script:ReportLines.Add("<span class='blue'>  $LabelName</span>")
        Write-Host "  $LabelName" -ForegroundColor Blue
        Show-SubLine "" $adapter.MACAddress
    }
    
    $script:ReportLines.Add("")
    Write-Host ""

    $version = $RegOS.DisplayVersion
    if (!$version) { $version = $RegOS.ReleaseId }
    Show-Line "Windows" "$($RegOS.ProductName) | $version | $($RegOS.CurrentBuild)"
    
    # DÒNG CUỐI CÙNG ĐƯỢC PHÉP CHÈN VÀO FILE HTML
    Show-Line "Current User" $currentUser
    
    # =====================================================
    # ĐÓNG GÓI XUẤT FILE HTML (TỐI ƯU: TẮT TỰ ĐỘNG WRAP TEXT)
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
        /* THAY ĐỔI TẠI ĐÂY: white-space: pre để khoá cuộn ngang, bỏ hoàn toàn wrap text */
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
        Write-Host "[LOCAL] ERROR -> Khong the ghi file bao cao vao o C!" -ForegroundColor Red
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
            Write-Host "[ONLINE] OK -> Nhung folder mang mang LAN dang chan quyen ghi bao cao!" -ForegroundColor Red
        }
    } else {
        Write-Host "[OFFLINE] Khong thay Server mang '$ServerHost', hoan tat chay phan mem." -ForegroundColor DarkGray
    }

    # =====================================================
    # PHẦN ĐƯỜNG DẪN DƯỚI MENU (CHỈ IN TRÊN CONSOLE - HTML KHÔNG LẤY)
    # =====================================================
    Write-Host $BorderLine -ForegroundColor DarkGray
    Write-Host ("{0,-$global:LabelWidth} >>> " -f "SOFTWARE Path") -NoNewline -ForegroundColor Green
    Write-Host $SourceSW -ForegroundColor Yellow

    Write-Host ("{0,-$global:LabelWidth} >>> " -f "SOFTWARE2 Path") -NoNewline -ForegroundColor Green
    Write-Host $SourceSW2 -ForegroundColor Yellow
    Write-Host $BorderLine -ForegroundColor DarkGray

    Write-Host "User vui long nhap so 115 de duoc ho tro: " -NoNewline
    $topMenu = Read-Host
    switch ($topMenu) {
        "111" { return }           
        "113" { Invoke-IT113-Menu } 
        "115" { Invoke-IT115-Menu } 
        default { exit }            
    }
}

# Vòng lặp duy trì giao diện
while ($true) { 
    Show-Menu-IT 
}
