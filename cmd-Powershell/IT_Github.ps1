param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 55,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

# Thống nhất đường dẫn cục bộ tại C:\SW chỉ dùng cho EXE và Reports
$SystemDriveSW  = "C:\SW"
$DestExePath     = Join-Path $SystemDriveSW "IT_Github.exe"

# URL gốc GitHub của anh
$ScriptWebUrl = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/cmd-Powershell/IT_Github.ps1"

# ===== 💥 CƯỠNG BỨC GIẢI PHÓNG TIẾN TRÌNH TREO NGẦM =====
$currentPID = $PID
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='IT_Github.exe'" | Where-Object {
    $_.ProcessId -ne $currentPID
} | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
}

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

# Check Admin
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Dang nang quyen Administrator truc tiep tu RAM..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Invoke-RestMethod -Uri '$ScriptWebUrl' | Invoke-Expression`"" -Verb RunAs
    exit
}

# Title giao diện
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running IT_Github.ps1 $adminText <<< Powered by RAM"

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
# CHÉP FILE PHỤ TRỢ (NẾU CÓ) + TẠO SHORTCUT START MENU
# =====================================================
if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }

# 1. Chỉ sao chép file IT_Github.exe nếu tìm thấy nguồn phân phối LAN/USB
if (Test-Path $ExeSourcePath) {
    Copy-Item -Path $ExeSourcePath -Destination $DestExePath -Force | Out-Null
    Write-Host "[SYSTEM] Da đồng bộ IT_Github.exe vao $SystemDriveSW" -ForegroundColor Green
    
    try {
        $StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
        $StartMenuProgramslnk  = "$StartMenuProgramsPath\IT_Github.exe.lnk"
        $WshShell = New-Object -ComObject WScript.Shell
        
        if (Test-Path $StartMenuProgramslnk) { Remove-Item $StartMenuProgramslnk -Force }
        
        $ShortcutStartMenu = $WshShell.CreateShortcut($StartMenuProgramslnk)
        $ShortcutStartMenu.TargetPath = $DestExePath
        $ShortcutStartMenu.WorkingDirectory = $SystemDriveSW
        $ShortcutStartMenu.Save()
    } catch {}
}


# =====================================================
# KHU VỰC CORE TIẾN TRÌNH CON - MENU CHẠY TRÊN RAM
# =====================================================

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

function Invoke-IT115-Menu {
    Clear-Host
    Write-Host "=== KHU VỰC HỖ TRỢ IT-115 (RAM MODE) ===" -ForegroundColor Magenta
    Read-Host "`nNhan Enter de quay lai Menu chinh..."
    return
}


# =====================================================
# ⚡️ QUÉT PHẦN CỨNG 1 LẦN DUY NHẤT LÚC LÊN TOOL
# =====================================================
Write-Host "🔍 Dang quet nhanh cau hinh may tinh..." -ForegroundColor Cyan

$global:CS      = Get-CimInstance Win32_ComputerSystem
$global:BB      = Get-CimInstance Win32_BaseBoard
$global:CPU     = Get-CimInstance Win32_Processor
$global:BIOS    = Get-CimInstance Win32_BIOS
$global:GPU     = Get-CimInstance Win32_VideoController
$global:OS      = Get-CimInstance Win32_OperatingSystem
$global:RegOS   = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$global:RAM     = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
$global:Arrays  = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
$global:Disks   = Get-CimInstance Win32_DiskDrive
$global:NetAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -and $_.PhysicalAdapter -eq $true }


# =====================================================
# GIAO DIỆN MENU CHÍNH (MAIN MENU)
# =====================================================
function Show-Menu-IT {
    Clear-Host
    
    # Giải phóng triệt để các biến rác thu gom chuỗi vòng trước
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    
    $script:ReportLines = New-Object System.Collections.Generic.List[string]
    $ConsoleWidth = $Host.UI.RawUI.WindowSize.Width
    $LineWidth = [Math]::Max(40, $ConsoleWidth - 1) 

    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray
    $text = " IT support, Scripted by TACOMPUTER & GPT, 0933.848.990 "
    $pad = [Math]::Max(0, $LineWidth - $text.Length)
    $left  = [Math]::Floor($pad / 2)
    $right = $pad - $left
    Write-Host ("+" * $left) -ForegroundColor DarkGray -NoNewline
    Write-Host $text -NoNewline
    Write-Host ("+" * $right) -ForegroundColor DarkGray
    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray

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

    function Show-Line {
        param($label, $value)
        if ($value) {
            $script:ReportLines.Add("<span class='green'>{0,-$global:LabelWidth} &gt;&gt;&gt; </span><span class='yellow'>{1}</span>" -f $label, $value)
        } else {
            $script:ReportLines.Add("<span class='green'>{0,-$global:LabelWidth} &gt;&gt;&gt; </span>" -f $label)
        }
        Write-Host ("{0,-$global:LabelWidth} >>> " -f $label) -NoNewline -ForegroundColor Green
        Write-Host $value -ForegroundColor Yellow
    }

    function Show-SubLine {
        param($label, $value)
        if ($label) {
            $script:ReportLines.Add("<span class='blue'>  {0,-$global:SubLabelWidth} : {1}</span>" -f $label, $value)
        } else {
            $script:ReportLines.Add("<span class='blue'>  {0,-$global:SubLabelWidth} : {1}</span>" -f "", $value)
        }
        Write-Host ("  {0,-$global:SubLabelWidth} : " -f $label) -NoNewline -ForegroundColor Blue
        Write-Host $value -ForegroundColor Blue
    }

    # Đọc dữ liệu tĩnh từ RAM
    Show-Line "Brand (OEM)" $global:CS.Manufacturer
    Show-Line "Mainboard" $global:BB.Manufacturer
    Show-Line "Product" $global:BB.Product
    Show-Line "Model" $global:CS.Model
    Show-Line "Serial" $global:BIOS.SerialNumber
    Show-Line "BIOS ver" $global:BIOS.SMBIOSBIOSVersion
    Write-Host ""
    $script:ReportLines.Add("") 

    if ($global:CPU.Count -gt 1) {
        Show-Line "CPU" ""
        $i = 1; foreach ($c in $global:CPU) { Show-SubLine "CPU $i" $c.Name; $i++ }
    } else { Show-Line "CPU" $global:CPU.Name }

    # RAM Info
    $ramType = if ($global:Arrays.MemoryErrorCorrection -in 5,6) { "ECC" } else { "Non-ECC" }
    $totalRAM = "{0:N0}" -f (($global:RAM | Measure-Object Capacity -Sum).Sum / 1GB)
    Show-Line "RAM (Total)" "$totalRAM GB ($ramType)"
    
    $trueUsedSlots = 0
    $i = 1
    foreach ($ram in $global:RAM) {
        $size = "{0:N0}" -f ($ram.Capacity / 1GB)
        $slot = if ($ram.DeviceLocator) { $ram.DeviceLocator.Trim() } else { "Slot $i" }
        $manufacturer = if ($ram.Manufacturer) { $ram.Manufacturer.Trim() } else { "Unknown" }
        $partNumber = if ($ram.PartNumber) { $ram.PartNumber.Trim() } else { "Unknown" }
        
        $RamDetails = "$size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
        Show-SubLine $slot $RamDetails
        $i++; $trueUsedSlots++
    }
    $TotalSlots = if ($global:Arrays) { @($global:Arrays)[0].MemoryDevices } else { 2 }
    Show-SubLine "Used Slots" "$trueUsedSlots/$TotalSlots"

    # Disk Info
    $totalDisk = "{0:N0}" -f (($global:Disks | Measure-Object Size -Sum).Sum / 1GB)
    Show-Line "Storage (Total)" "$totalDisk GB"
    $i = 1; foreach ($disk in $global:Disks) { Show-SubLine "Disk $i" ("{0} | {1:N0} GB" -f $disk.Model, ($disk.Size / 1GB)); $i++ }

    # GPU Info
    $vgaCount = 0; $gpuCount = 0
    foreach ($g in $global:GPU) { if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ } }
    Show-Line "Graphics" ("$vgaCount VGA / $gpuCount GPU")
    foreach ($g in $global:GPU) { Show-SubLine "GPU_Info" ("" + $g.Name) }
    Write-Host ""
    $script:ReportLines.Add("")
    
    # MAC Info
    Show-Line "MAC Address" ""
    foreach ($adapter in $global:NetAdapters) {
        $Type = "LAN"
        if ($adapter.Name -match "Wireless|Wi-Fi|802.11") { $Type = "Wi-Fi" }
        elseif ($adapter.Name -match "Bluetooth") { $Type = "Bluetooth" }
        
        $LabelName = "$Type - $($adapter.Name)"
        $script:ReportLines.Add("<span class='blue'>  $LabelName</span>")
        Write-Host "  $LabelName" -ForegroundColor Blue
        Show-SubLine "" $adapter.MACAddress
    }
    Write-Host ""
    $script:ReportLines.Add("")

    $version = $global:RegOS.DisplayVersion
    if (!$version) { $version = $global:RegOS.ReleaseId }
    Show-Line "Windows" "$($global:RegOS.ProductName) | $version | $($global:RegOS.CurrentBuild)"
    Show-Line "Current User" $currentUser
    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray
    
    # --- 🚩 XUẤT HTML BẰNG PHƯƠNG THỨC REPLACE (TUYỆT ĐỐI KHÔNG DÙNG -F) ---
    $Serial = $global:BIOS.SerialNumber
    $CleanModel = ($global:CS.Model -replace '[\\/:*?"<>|]', '').Trim()
    $Content = $script:ReportLines -join "`r`n"
    $FileNameReport = "{0}_{1}.html" -f $CleanModel, $Serial
    
    # Đóng băng template HTML bằng chuỗi Raw Script
    $HtmlTemplate = @'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title></title>
<style>
body { font-family: 'Consolas', 'Courier New', monospace; background-color: #0c0c0c; color: #cccccc; margin: 20px; line-height: 1.4; }
pre { font-size: 14px; white-space: pre-wrap; margin: 0; }
.green { color: #00ff00; font-weight: bold; }
.yellow { color: #ffff00; }
.blue { color: #3b8ec2; }
.cyan { color: #00ffff; font-weight: bold; }
</style>
</head>
<body><pre></pre></body>
</html>
'@
    # Dùng phương thức Replace chính thống của hệ thống để nhét dữ liệu
    $HtmlContent = $HtmlTemplate.Replace("", $Serial).Replace("", $Content)
    
    # --- GHI BÁO CÁO LOCAL ---
    $LocalReportsFolder = Join-Path $SystemDriveSW "Reports"
    try {
        if (-not (Test-Path $LocalReportsFolder)) { New-Item -Path $LocalReportsFolder -ItemType Directory -Force | Out-Null }
        $LocalFile = Join-Path $LocalReportsFolder $FileNameReport
        $HtmlContent | Set-Content $LocalFile -Encoding UTF8 -Force
        Write-Host "[LOCAL] OK -> Da luu bao cao tai local $LocalReportsFolder" -ForegroundColor Green
    } catch {}
    
    # --- ĐẨY BÁO CÁO LÊN SERVER MẠNG ---
    $ServerHost = "IT"
    $NetworkFolder = "\\$ServerHost\Guest\Computer list"
    if (try { Test-Connection -ComputerName $ServerHost -Count 1 -Quiet } catch { $false }) {
        try {
            if (-not (Test-Path $NetworkFolder)) { New-Item -Path $NetworkFolder -ItemType Directory -Force | Out-Null }
            $NetworkFile = Join-Path $NetworkFolder $FileNameReport
            $HtmlContent | Set-Content $NetworkFile -Encoding UTF8 -Force
            Write-Host "[ONLINE] OK -> Da cap nhat bao cao len Server ($ServerHost)" -ForegroundColor Cyan
        } catch {}
    }

    Show-Line "SOFTWARE Path" $SourceSW
    Show-Line "SOFTWARE2 Path" $SourceSW2
    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray

    Write-Host "User vui long nhap so 115 de duoc ho tro: " -NoNewline
    $topMenu = Read-Host
    switch ($topMenu) {
        "111" { return }           
        "113" { Invoke-IT113-Menu } 
        "115" { Invoke-IT115-Menu } 
        default { exit }            
    }
}

# Vòng lặp chính luôn giữ trạng thái sạch
while ($true) { 
    Show-Menu-IT 
}
