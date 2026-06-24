param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 55,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

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

# Xác định Script Path
$callStack = Get-PSCallStack
if ($callStack.Count -gt 1 -and $callStack[1].ScriptName) {
    $MainScript = $callStack[-1].ScriptName
} else {
    $MainScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
}

if (-not $MainScript) { $MainScript = "C:\SW\cmd-Powershell\IT_Github.ps1" } 
$CurrentScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MainScript -Parent }

# Check Admin
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Dang nang quyen Administrator..." -ForegroundColor Yellow
    Start-Process powershell `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$MainScript`"" `
        -Verb RunAs
    exit
}

# Chỉ cho 1 script chạy
$currentPID = $PID
$scriptName = [System.IO.Path]::GetFileName($MainScript)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
    $_.ProcessId -ne $currentPID -and
    $_.CommandLine -match [regex]::Escape($scriptName)
} | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
}

# Set Title (Hiển thị động dạng <<< Github\tên-thư-mục)
$fileName = Split-Path $MainScript -Leaf
$folderPath = Split-Path $MainScript -Parent
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }

# Lấy tên thư mục cuối cùng (Ví dụ: cmd-Powershell)
$lastFolder = Split-Path $folderPath -Leaf

# Gán vào WindowTitle
$host.UI.RawUI.WindowTitle = "Running $fileName $adminText <<< Github\$lastFolder"

# Resize Console (Có bọc chống lỗi Handle khi chạy trực tiếp từ Web URL)
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
    # Nếu không lấy được console handle khi chạy qua IE/URL, sử dụng Host UI thay thế
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

# Set Font size
$psKey = "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe"
$DesiredFontSize = 0x000E0000
if (-not (Test-Path $psKey)) { New-Item -Path $psKey -Force | Out-Null }
$CurrentFontSize = (Get-ItemProperty -Path $psKey -Name FontSize -ErrorAction SilentlyContinue).FontSize

if ($CurrentFontSize -ne $DesiredFontSize) {
    try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont" `
          -Name "000" -Value "Consolas" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $psKey -Name FaceName -Value "Consolas"
        Set-ItemProperty -Path $psKey -Name FontSize -Value $DesiredFontSize
        Write-Host "⚠️ Dang cap nhat Font Size moi, khoi dong lai..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$MainScript`""
        exit
    } catch { }
}

# =====================================================
# KHU VỰC ĐỊNH NGHĨA BIẾN HỆ THỐNG (FIX CHUẨN THEO VỊ TRÍ MỚI)
# =====================================================
# $CurrentScriptRoot hiện tại là: ...\IT-Support-Toolkit\cmd-Powershell
$ITScriptRoot = $CurrentScriptRoot

# Folder 'IT' nằm ngay bên trong 'cmd-Powershell', không cần nhảy về thư mục cha nữa!
$LibScript   = Join-Path $ITScriptRoot "IT\Library"
$IT113Script = Join-Path $ITScriptRoot "IT\IT-113"
$IT115Script = Join-Path $ITScriptRoot "IT\IT-115"

# Tự động quét tìm đường dẫn Software thực tế trên các ổ đĩa của máy
$TargetFolder = "OneDrive\TACOMPUTER\Software"
$SourceSW = "C:\SW" # Giá trị mặc định nếu không tìm thấy ổ nào khác

# Quét qua tất cả các ổ đĩa đang sẵn sàng (Fixed, Removable...) trừ ổ C ra cho nhanh
$AllDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.Name -ne "C:\" }
foreach ($d in $AllDrives) {
    $CheckPath = Join-Path $d.Name $TargetFolder
    if (Test-Path $CheckPath) {
        $SourceSW = $CheckPath
        break
    }
}

# Nếu quét các ổ khác không thấy, thử tìm ngay trên ổ C
if ($SourceSW -eq "C:\SW") {
    $CheckC = Join-Path "C:\" $TargetFolder
    if (Test-Path $CheckC) { $SourceSW = $CheckC }
}

# Tính toán đường dẫn SOFTWARE2 dựa trên SOFTWARE vừa tìm được
if ($SourceSW -match "OneDrive\\TACOMPUTER\\Software$") {
    $drive = [System.IO.Path]::GetPathRoot($SourceSW)
    $SourceSW2 = Join-Path $drive "Software2"
} else {
    $SourceSW2 = $SourceSW + "2"
}

$SystemDriveSW         = "C:\SW"
$ExePath               = Join-Path $SourceSW "OS Tools\cmd-Powershell\IT_Github.exe"
$SystemDriveSWlnk      = "$SystemDriveSW\IT_Github.exe.lnk"
$currentUser           = "$env:COMPUTERNAME\$env:USERNAME"
$StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
$StartMenuShortPath    = $StartMenuProgramsPath.Substring($StartMenuProgramsPath.IndexOf("\Start Menu"))
$StartMenuProgramslnk  = "$StartMenuProgramsPath\IT_Github.exe.lnk"
$ExpandedStartMenuPath = [Environment]::ExpandEnvironmentVariables($StartMenuProgramsPath)
$ExpandedStartMenuLnk  = [Environment]::ExpandEnvironmentVariables($StartMenuProgramslnk)
$exportvariablePath    = "$SystemDriveSW\variable_IT.ps1"

# Xuất biến
if (Test-Path $exportvariablePath) { Remove-Item $exportvariablePath -Force }
function Is-PathLike($str) {
    return ($str -is [string]) -and ($str -match '^[a-zA-Z]:\\' -or $str -match '^\\\\' -or $str -match '\\.+\\' -or $str -match '\\$')
}
$excludedNames = @('HOME', 'PSHOME', 'PROFILE', 'PID', 'ExecutionContext', 'Host', 'ShellId','env', 'args', 'Error', 'MyInvocation', 'PSBoundParameters', 'PSCommandPath','PSCulture', 'PSEdition', 'PSScriptRoot', 'PSUICulture', 'PSVersionTable','input', 'output', 'null')
$vars = Get-Variable | Where-Object { ($_.Value -is [string]) -and (Is-PathLike $_.Value) -and (-not ($excludedNames -contains $_.Name)) -and ($_.Options -notmatch 'ReadOnly|Constant|AllScope') }
$lines = @()
foreach ($var in $vars) {
    $name = $var.Name
    $value = '"' + $var.Value.Replace('"', '`"') + '"'
    $lines += "`$$name = $value"
}
if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }
$lines | Set-Content $exportvariablePath

# 1. Định nghĩa đường dẫn file EXE đích nằm trong C:\SW
$DestExePath = Join-Path $SystemDriveSW "IT_Github.exe"

# 2. Tiến hành kiểm tra và copy file EXE gốc vào C:\SW
if (Test-Path $ExePath) {
    Copy-Item -Path $ExePath -Destination $DestExePath -Force | Out-Null
    Write-Host "[SYSTEM] Da sao chep IT_Github.exe vao $SystemDriveSW" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Khong tim thay file nguon de copy: $ExePath" -ForegroundColor Yellow
}

# 3. Tạo lại Shortcut trong Start Menu trỏ vào file C:\SW\IT_Github.exe vừa copy
try {
    # Khởi tạo đối tượng COM để làm việc với Shortcut
    $WshShell = New-Object -ComObject WScript.Shell
    
    # Xóa shortcut cũ nếu tồn tại trước đó
    if (Test-Path $ExpandedStartMenuLnk) { Remove-Item $ExpandedStartMenuLnk -Force }
    
    # Khởi tạo tạo shortcut mới
    $ShortcutStartMenu = $WshShell.CreateShortcut($ExpandedStartMenuLnk)
    $ShortcutStartMenu.TargetPath = $DestExePath        # Trỏ chuẩn vào C:\SW\IT_Github.exe
    
    # ĐÃ SỬA: Phải giữ thư mục gốc của bộ source để file EXE tìm thấy file .ps1 ngầm
    $ShortcutStartMenu.WorkingDirectory = $ITScriptRoot 
    
    $ShortcutStartMenu.Save()
} catch {
    Write-Host "[WARNING] Khong the tao shortcut Start Menu!" -ForegroundColor Yellow
}

function Run-IT-xxx {
    param([string]$ScriptPath)
    [WinAPI]::ShowWindow($consoleHandle, 6)
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
    [WinAPI]::ShowWindow($consoleHandle, 9)
}

function Show-Menu-IT {
    Clear-Host
    $script:ReportLines = New-Object System.Collections.Generic.List[string]

    # LOGO IT - Tu dong co gian linh hoat theo chieu rong cua so console
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
        $script:ReportLines.Add("[ Laptop Information ]")
    } else {
        Write-Host "[ PC Information ]" -ForegroundColor Cyan
        $script:ReportLines.Add("[ PC Information ]")
    }

    # Định nghĩa độ rộng để căn chỉnh thẳng hàng dấu >>> và dấu : của SubLine
    $global:LabelWidth = 20
    $global:SubLabelWidth = 18

    function Show-Line {
        param($label, $value)
        $script:ReportLines.Add(("{0,-$global:LabelWidth} >>> {1}" -f $label, $value))
        Write-Host ("{0,-$global:LabelWidth} >>> " -f $label) -NoNewline -ForegroundColor Green
        Write-Host $value -ForegroundColor Yellow
    }

    function Show-SubLine {
        param($label, $value)
        $script:ReportLines.Add(("  {0,-$global:SubLabelWidth} : {1}" -f $label, $value))
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
    Write-Host ""

    if ($CPU.Count -gt 1) {
        Show-Line "CPU" ""
        $i = 1; foreach ($c in $CPU) { Show-SubLine "CPU $i" $c.Name; $i++ }
    } else { Show-Line "CPU" $CPU.Name }

    # --- PHẦN RAM (ĐÃ FIX KHOẢNG CÁCH ĐỀU) ---
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
        
        # Định dạng gọn gàng từng cột bằng dấu | cách đều
        $RamDetails = "$size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
        Show-SubLine $slot $RamDetails
        $i++; $trueUsedSlots++
    }
    $TotalSlots = if ($arrays) { @($arrays)[0].MemoryDevices } else { 2 }
    Show-SubLine "Used Slots" "$trueUsedSlots/$TotalSlots"

    # --- PHẦN Ổ CỨNG ---
    $disks = Get-CimInstance Win32_DiskDrive
    $totalDisk = "{0:N0}" -f (($disks | Measure-Object Size -Sum).Sum / 1GB)
    Show-Line "Storage (Total)" "$totalDisk GB"
    $i = 1; foreach ($disk in $disks) { Show-SubLine "Disk $i" ("{0} | {1:N0} GB" -f $disk.Model, ($disk.Size / 1GB)); $i++ }

    # --- PHẦN ĐỒ HỌA ---
    $vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) { if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ } }
    Show-Line "Graphics" ("$vgaCount VGA / $gpuCount GPU")
    foreach ($g in $GPU) { Show-SubLine "GPU_Info" ("" + $g.Name) }
    Write-Host ""
    
    # --- PHẦN MAC ADDRESS (PHÂN LOẠI CHI TIẾT LAN/WIFI/BLUETOOTH + CĂN THẲNG HÀNG) ---
    Show-Line "MAC Address" ""
    $netAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -and $_.PhysicalAdapter -eq $true }
    foreach ($adapter in $netAdapters) {
        $Type = "LAN"
        if ($adapter.Name -match "Wireless|Wi-Fi|802.11") { $Type = "Wi-Fi" }
        elseif ($adapter.Name -match "Bluetooth") { $Type = "Bluetooth" }
        
        $LabelName = "$Type - $($adapter.Name)"
        
        # In Label Card mạng màu xanh dương nhạt (giống SubLine nhưng không in dấu : ở đây)
        $script:ReportLines.Add(("  $LabelName"))
        Write-Host "  $LabelName" -ForegroundColor Blue
        
        # In dấu : thẳng hàng với các thông số cấp 2 ở trên để hiển thị địa chỉ MAC
        Show-SubLine "" $adapter.MACAddress
    }
    Write-Host ""

    $version = $RegOS.DisplayVersion
    if (!$version) { $version = $RegOS.ReleaseId }
    Show-Line "Windows" "$($RegOS.ProductName) | $version | $($RegOS.CurrentBuild)"
    Show-Line "Current User" $currentUser
    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray
    
    # Export HTML (Tự động xóa file cũ nếu có và upload lên Server)
    $Serial = $BIOS.SerialNumber
    $CleanModel = ($CS.Model -replace '[\\/:*?"<>|]', '').Trim()
    $Content = $script:ReportLines -join "`r`n"
    $HtmlContent = "<html><body><pre>$Content</pre></body></html>"
    
    $FileNameReport = "{0}_{1}.html" -f $CleanModel, $Serial
    $LocalFolder = "C:\SW\Reports"
    
    if (-not (Test-Path $LocalFolder)) { 
        New-Item -Path $LocalFolder -ItemType Directory -Force | Out-Null 
    }
    $HtmlFile = Join-Path $LocalFolder $FileNameReport
    
    # 1. Ghi file Local (Không cần Remove-Item trước)
    [System.IO.File]::WriteAllText($HtmlFile, $HtmlContent)

    $ServerHost = "IT"
    $NetworkFolder = "\\$ServerHost\Guest\Computer list"

    if (Test-Connection -ComputerName $ServerHost -Count 1 -Quiet) {
        try {
            if (-not (Test-Path $NetworkFolder)) { 
                New-Item -Path $NetworkFolder -ItemType Directory -Force | Out-Null 
            }
            $NetworkFile = Join-Path $NetworkFolder $FileNameReport
            
            # 2. Ghi file lên Server (Đã sửa từ $HtmlFile thành $NetworkFile và bỏ Remove-Item)
            [System.IO.File]::WriteAllText($NetworkFile, $HtmlContent)
            
            Write-Host "[ONLINE] OK -> Da cap nhat bao cao moi len Server ($ServerHost)" -ForegroundColor Cyan
        } catch {
            Write-Host "[ONLINE] OK -> Nhung folder mang chan quyen ghi/xoa!" -ForegroundColor Red
        }
    } else {
        Write-Host "[OFFLINE] Khong thay Server '$ServerHost', da cap nhat bao cao tai local C:\SW\Reports" -ForegroundColor DarkGray
    }

    # Ktra Path
    Show-Line "SOFTWARE Path" $SourceSW
    Show-Line "SOFTWARE2 Path" $SourceSW2
    Write-Host ("+" * $LineWidth) -ForegroundColor DarkGray

    Write-Host "User vui long nhap so 115 de duoc ho tro: " -NoNewline
    $topMenu = Read-Host
    switch ($topMenu) {
        "111" { GoTo-IT-111 }
        "115" { GoTo-IT-115 }
        "113" { GoTo-IT-113 }
        default { return }
    }
}

function GoTo-IT-111 {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$MainScript`""
    exit
}
function GoTo-IT-115 {
    Run-IT-xxx "$IT115Script\IT-115.ps1"
    return
}
function GoTo-IT-113 {
    Run-IT-xxx "$IT113Script\IT-113.ps1"
    return
}

while ($true) { Show-Menu-IT }
