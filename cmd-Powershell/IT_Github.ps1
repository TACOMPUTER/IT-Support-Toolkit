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

# Lấy handle console
$consoleHandle = [WinAPI]::GetConsoleWindow()


# 🚩 <<<--- XÁC ĐỊNH SCRIPT PATH CHUẨN (FIX CALLSTACK & REMOTE RUN) --->>>
$callStack = Get-PSCallStack
if ($callStack.Count -gt 1 -and $callStack[1].ScriptName) {
    $MainScript = $callStack[-1].ScriptName
} else {
    $MainScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
}

if (-not $MainScript) { $MainScript = "C:\SW\cmd-Powershell\IT_Github.ps1" } 
$CurrentScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MainScript -Parent }
# 🏁 <<<--- END --->>>


# 🚩 <<<--- CHECK ADMIN (BỎ LẶP CODE) --->>>
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Đang nâng quyền Administrator..." -ForegroundColor Yellow
    Start-Process powershell `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$MainScript`"" `
        -Verb RunAs
    exit
}
# 🏁 <<<--- END --->>>


# 🚩 <<<--- CHỈ CHO 1 SCRIPT CHẠY --->>>
$currentPID = $PID
$scriptName = [System.IO.Path]::GetFileName($MainScript)

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
    $_.ProcessId -ne $currentPID -and
    $_.CommandLine -match [regex]::Escape($scriptName)
} | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
}
# 🏁 <<<--- END --->>>


# 🚩 <<<--- SET WINDOW TITLE --->>>
$fileName = Split-Path $MainScript -Leaf
$folderPath = Split-Path $MainScript -Parent
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running '$fileName' $adminText <<< $folderPath"
# 🏁 <<<--- END --->>>


# 🚩 <<<--- RESIZE CONSOLE --->>>
$maxWidth  = $host.UI.RawUI.MaxWindowSize.Width
$maxHeight = $host.UI.RawUI.MaxWindowSize.Height

$PSWidth  = [Math]::Min($PSWidth,  $maxWidth)
$PSHeight = [Math]::Min($PSHeight, $maxHeight)

[Console]::BufferWidth  = [Math]::Max($PSWidth,  [Console]::BufferWidth)
[Console]::BufferHeight = [Math]::Max($PSHeight, [Console]::BufferHeight)

[Console]::WindowWidth  = $PSWidth
[Console]::WindowHeight = $PSHeight
# 🏁 <<<--- END --->>>


# 🚩 <<<--- MOVE WINDOW --->>>
if (-not ("WinMove" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinMove {
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    public struct RECT {
        public int Left; public int Top; public int Right; public int Bottom;
    }
}
"@
}
$handle = (Get-Process -Id $PID).MainWindowHandle
$rect = New-Object WinMove+RECT
[WinMove]::GetWindowRect($handle, [ref]$rect)
$widthPx  = $rect.Right - $rect.Left
$heightPx = $rect.Bottom - $rect.Top
[WinMove]::MoveWindow($handle, $PosX, $PosY, $widthPx, $heightPx, $true) | Out-Null
# 🏁 <<<--- END --->>>


# 🚩 <<<--- SET FONT SIZE CONSOLAS --->>>
$psKey = "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe"
$DesiredFontSize = 0x000E0000 # Size 14

if (-not (Test-Path $psKey)) { New-Item -Path $psKey -Force | Out-Null }
$CurrentFontSize = (Get-ItemProperty -Path $psKey -Name FontSize -ErrorAction SilentlyContinue).FontSize

if ($CurrentFontSize -ne $DesiredFontSize) {
    try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont" `
          -Name "000" -Value "Consolas" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

        Set-ItemProperty -Path $psKey -Name FaceName -Value "Consolas"
        Set-ItemProperty -Path $psKey -Name FontSize -Value $DesiredFontSize

        Write-Host "⚠️ Đang cập nhật Font Size mới, script sẽ khởi động lại..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$MainScript`""
        exit
    }
    catch { 
        Write-Host "⚠️ Không thể cập nhật font size: $($_.Exception.Message)" -ForegroundColor Red
    }
}
# 🏁 <<<--- END --->>>


# 🚩 <<<--- KHU VỰC KHAI BÁO BIẾN SỬ DỤNG TOÀN BỘ SCRIPT ---->>>
$ITScriptRoot = $CurrentScriptRoot

$LibScript   = Join-Path $ITScriptRoot "IT\Library"
$IT113Script = Join-Path $ITScriptRoot "IT\IT-113"
$IT115Script = Join-Path $ITScriptRoot "IT\IT-115"

# Nhận diện thư mục Software gốc (Vì script nằm ở C:\SW\cmd-Powershell)
$SourceSW = Split-Path $ITScriptRoot -Parent    # Kết quả trả về: C:\SW

if ($SourceSW -match "OneDrive\\TACOMPUTER\\Software$") {
    $drive = ([System.IO.Path]::GetPathRoot($SourceSW))
    $SourceSW2 = Join-Path $drive "Software2"
}
elseif ($SourceSW -match "^[A-Z]:\\Software$") {
    $SourceSW2 = $SourceSW + "2"
}
elseif ($SourceSW -match "^\\\\.*\\Software$") {
    $SourceSW2 = $SourceSW + "2"
}
else {
    $SourceSW2 = $SourceSW + "2" 
}

$SystemDriveSW         = "C:\SW"
$ExePath               = Join-Path $ITScriptRoot "IT_Github.exe"
$SystemDriveSWlnk      = "$SystemDriveSW\IT_Github.exe.lnk"
$currentUser           = "$env:COMPUTERNAME\$env:USERNAME"
$StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
$StartMenuShortPath    = $StartMenuProgramsPath.Substring($StartMenuProgramsPath.IndexOf("\Start Menu"))
$StartMenuProgramslnk  = "$StartMenuProgramsPath\IT_Github.exe.lnk"
$ExpandedStartMenuPath = [Environment]::ExpandEnvironmentVariables($StartMenuProgramsPath)
$ExpandedStartMenuLnk  = [Environment]::ExpandEnvironmentVariables($StartMenuProgramslnk)
$exportvariablePath    = "$SystemDriveSW\variable_IT.ps1"
# 🏁 <<<--- KẾT THÚC KHU VỰC KHAI BÁO BIẾN ---->>>


# 🚩 <<<--- XUẤT CÁC BIẾN RA FILE 'VARIABLE_IT.PS1' --->>>
if (Test-Path $exportvariablePath) {
    Remove-Item $exportvariablePath -Force
    Write-Host "Đã xóa file cũ: $exportvariablePath`n" -ForegroundColor Yellow
}

function Is-PathLike($str) {
    return ($str -is [string]) -and (
        $str -match '^[a-zA-Z]:\\' -or
        $str -match '^\\\\' -or
        $str -match '\\.+\\' -or
        $str -match '\\$'
    )
}

$excludedNames = @(
    'HOME', 'PSHOME', 'PROFILE', 'PID', 'ExecutionContext', 'Host', 'ShellId',
    'env', 'args', 'Error', 'MyInvocation', 'PSBoundParameters', 'PSCommandPath',
    'PSCulture', 'PSEdition', 'PSScriptRoot', 'PSUICulture', 'PSVersionTable',
    'input', 'output', 'null'
)

$vars = Get-Variable | Where-Object {
    ($_.Value -is [string]) -and
    (Is-PathLike $_.Value) -and
    (-not ($excludedNames -contains $_.Name)) -and
    ($_.Options -notmatch 'ReadOnly|Constant|AllScope')
}
$lines = @()
foreach ($var in $vars) {
    $name = $var.Name
    $value = '"' + $var.Value.Replace('"', '`"') + '"'
    $lines += "`$$name = $value"
}

if (-not (Test-Path $SystemDriveSW)) {
    New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null
}
$lines | Set-Content $exportvariablePath
# 🏁 <<<--- END --->>>


# 🚩 <<<--- TẠO SHORTCUT IT_Github.exe --->>>
$WshShell = New-Object -ComObject WScript.Shell

if (-not (Test-Path $SystemDriveSW)) {
    New-Item -ItemType Directory -Path $SystemDriveSW -Force | Out-Null
}

$ShortcutSystemDrive = $WshShell.CreateShortcut($SystemDriveSWlnk)
$ShortcutSystemDrive.TargetPath = $ExePath
$ShortcutSystemDrive.WorkingDirectory = $ITScriptRoot
$ShortcutSystemDrive.Description = "Shortcut to IT_Github.exe"
$ShortcutSystemDrive.IconLocation = $ExePath
$ShortcutSystemDrive.Save()

if (-not (Test-Path $ExpandedStartMenuPath)) {
    New-Item -ItemType Directory -Path $ExpandedStartMenuPath -Force | Out-Null
}

if (Test-Path $ExpandedStartMenuLnk) {
    Remove-Item $ExpandedStartMenuLnk -Force
}

$ShortcutStartMenu = $WshShell.CreateShortcut($ExpandedStartMenuLnk)
$ShortcutStartMenu.TargetPath = $ExePath
$ShortcutStartMenu.WorkingDirectory = $ITScriptRoot
$ShortcutStartMenu.Description = "Shortcut to IT_Github.exe"
$ShortcutStartMenu.IconLocation = $ExePath
$ShortcutStartMenu.Save()

$StartMenuIndex = $ExpandedStartMenuLnk.IndexOf("Start Menu")
$DesiredOutput = "...\" + $ExpandedStartMenuLnk.Substring($StartMenuIndex)
# 🏁 <<<--- END --->>>


function Run-IT-xxx {
    param([string]$ScriptPath)
    [WinAPI]::ShowWindow($consoleHandle, 6) # Minimize
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
    [WinAPI]::ShowWindow($consoleHandle, 9) # Restore
}


# 🚩 <<<--- CHỌN HỖ TRỢ 113 114 115 --->>>
function Show-Menu-IT {
    Clear-Host
    $script:ReportLines = New-Object System.Collections.Generic.List[string]

    # LOGO IT
    Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray
    $text = " IT support, Scripted by TACOMPUTER & GPT, 0933.848.990 "
    $width = $Host.UI.RawUI.WindowSize.Width
    $pad = [Math]::Max(0, $width - $text.Length)
    $left  = [Math]::Floor($pad / 2)
    $right = $pad - $left
    Write-Host ("+" * $left) -ForegroundColor DarkGray -NoNewline
    Write-Host $text -NoNewline
    Write-Host ("+" * $right) -ForegroundColor DarkGray
    Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray

    # THÔNG TIN CƠ BẢN MÁY TÍNH
    $IsLaptop = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) -ne $null
    if ($IsLaptop) {
        Write-Host "<<< Laptop Information >>>" -ForegroundColor Cyan
        $script:ReportLines.Add("<span class='cyan'>&lt;&lt;&lt; Laptop Information &gt;&gt;&gt;</span>")
    } else {
        Write-Host "<<< PC Information >>>" -ForegroundColor Cyan
        $script:ReportLines.Add("<span class='cyan'>&lt;&lt;&lt; PC Information &gt;&gt;&gt;</span>")
    }

    $global:LabelWidth = 18
    $global:SubLabelWidth = 16

    function Show-Line {
        param($label, $value)
        $htmlLabel = "{0,-$global:LabelWidth}" -f $label
        $htmlLine = "<span class='green'>$htmlLabel   &gt;&gt;&gt; </span><span class='yellow'>$value</span>"
        $script:ReportLines.Add($htmlLine)

        Write-Host ("{0,-$global:LabelWidth}   >>> " -f $label) -NoNewline -ForegroundColor Green
        Write-Host $value -ForegroundColor Yellow
    }

    function Show-SubLine {
        param($label, $value)
        $htmlSubLabel = "{0,-$global:SubLabelWidth}" -f $label
        $htmlLine = "<span class='blue'>  $htmlSubLabel&rarr; $value</span>"
        $script:ReportLines.Add($htmlLine)

        Write-Host ("  {0,-$global:SubLabelWidth}-> " -f $label) -NoNewline -ForegroundColor Blue
        Write-Host $value -ForegroundColor Blue
    }

    # GET DATA
    $CS      = Get-CimInstance Win32_ComputerSystem
    $BB      = Get-CimInstance Win32_BaseBoard
    $CPU     = Get-CimInstance Win32_Processor
    $RAM     = @(Get-CimInstance Win32_PhysicalMemory)
    $arrays  = Get-CimInstance Win32_PhysicalMemoryArray
    $BIOS    = Get-CimInstance Win32_BIOS
    $GPU     = Get-CimInstance Win32_VideoController
    $OS      = Get-CimInstance Win32_OperatingSystem
    $RegOS   = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    # SYSTEM
    Show-Line "Brand (OEM)" $CS.Manufacturer
    Show-Line "Mainboard" $BB.Manufacturer
    Show-Line "Product" $BB.Product
    Show-Line "Model" $CS.Model
    Show-Line "Serial" $BIOS.SerialNumber
    Show-Line "BIOS ver" $BIOS.SMBIOSBIOSVersion
    Write-Host ""
    $script:ReportLines.Add("")

    # CPU
    if ($CPU.Count -gt 1) {
        Show-Line "CPU" ""
        $i = 1
        foreach ($c in $CPU) { Show-SubLine ("CPU $i") $c.Name; $i++ }
    } else {
        Show-Line "CPU" $CPU.Name
    }

    # RAM
    $RAM = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $arrays = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
    $ramType = if ((Get-CimInstance Win32_PhysicalMemoryArray).MemoryErrorCorrection -in 5,6) { "ECC" } else { "Non-ECC" }

    $totalRAM = "{0:N0}" -f (($RAM | Measure-Object Capacity -Sum).Sum / 1GB)
    Show-Line "RAM (Total)" "$totalRAM GB ($ramType)"
    
    $trueUsedSlots = 0
    $i = 1
    
    foreach ($ram in $RAM) {
        $size = "{0:N0}" -f ($ram.Capacity / 1GB)
        $slot = if ($ram.DeviceLocator) { $ram.DeviceLocator } else { "Slot $i" }
        $manufacturer = $ram.Manufacturer.Trim()
        $partNumber   = $ram.PartNumber.Trim()

        Show-SubLine $slot "$size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
        $i++
        $trueUsedSlots++
    }
    
    $TotalSlots = if ($arrays) { @($arrays)[0].MemoryDevices } else { 8 }
    $availableSlots = $TotalSlots - $trueUsedSlots
    if ($availableSlots -lt 0) { $availableSlots = 0 }
    Show-SubLine "Available Slots" "$availableSlots/$TotalSlots"

    # STORAGE
    $disks = Get-CimInstance Win32_DiskDrive
    $totalDisk = "{0:N0}" -f (($disks | Measure-Object Size -Sum).Sum / 1GB)
    Show-Line "Storage (Total)" "$totalDisk GB"
    $i = 1
    foreach ($disk in $disks) {
        $size = "{0:N0}" -f ($disk.Size / 1GB)
        $subLabel = "Disk $i"
        Show-SubLine $subLabel "$($disk.Model)  $size GB"
        $i++
    }

    # GPU
    $vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) {
        if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ }
    }
    Show-Line "Graphics" ("{0} VGA / {1} GPU" -f $vgaCount, $gpuCount)
    foreach ($g in $GPU) {
        $label = if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { "VGA" } else { "GPU" }
        Show-SubLine $label $g.Name
    }
    Write-Host ""
    $script:ReportLines.Add("")
    
    # MAC ADDRESS
    $netAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -and $_.PhysicalAdapter -eq $true } | Sort-Object NetConnectionID, Name
    Show-Line "MAC Address" ""
    foreach ($adapter in $netAdapters) {
        $type = if ($adapter.Name -match "Bluetooth") { "Bluetooth" } elseif ($adapter.Name -match "Wireless|Wi-Fi|WLAN|802\.11") { "WiFi" } else { "LAN" }
        $adapterName = "$type - $($adapter.Name)"
        
        $script:ReportLines.Add("<span class='blue'>  $adapterName</span>")
        Write-Host "  $adapterName" -ForegroundColor Blue
        Show-SubLine "" $adapter.MACAddress
    }
    Write-Host ""
    $script:ReportLines.Add("")

    # WINDOWS
    $version = $RegOS.DisplayVersion
    if (!$version) { $version = $RegOS.ReleaseId }
    $build = "$($RegOS.CurrentBuild).$($RegOS.UBR)"
    Show-Line "Windows" "$($RegOS.ProductName) | $version | $build"

    # USER
    Write-Host ""`n"Current User         >>> " -NoNewline
    Write-Host $currentUser -ForegroundColor Yellow
    $script:ReportLines.Add("")
    $htmlUserLabel = "{0,-$global:LabelWidth}" -f "Current User"
    $script:ReportLines.Add("<span class='green'>$htmlUserLabel   &gt;&gt;&gt; </span><span class='yellow'>$currentUser</span>")
    Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray
    
    # 🚩 EXPORT HTML
    $Serial = $BIOS.SerialNumber
    $CleanModel = ($CS.Model -replace '[\\/:*?"<>|]', '').Trim()
    $Content = $script:ReportLines -join "`r`n"
    $HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$Serial</title>
<style>
body { font-family: 'Consolas', 'Courier New', monospace; background-color: #0c0c0c; color: #cccccc; margin: 20px; line-height: 1.4; }
pre { font-size: 14px; white-space: pre-wrap; margin: 0; }
.green { color: #00ff00; font-weight: bold; }
.yellow { color: #ffff00; }
.blue { color: #3b8ec2; }
.cyan { color: #00ffff; font-weight: bold; }
</style>
</head>
<body><pre>$Content</pre></body>
</html>
"@

    $NetworkPath = "\\IT\Guest\Computer list"
    $ServerHost = "IT"
    
    $isOnline = $false
    try {
        if (Test-Connection -ComputerName $ServerHost -Count 1 -Quiet -Delay 0.1) { $isOnline = $true }
    } catch { $isOnline = $false }

    if ($isOnline) {
        try {
            if (-not (Test-Path $NetworkPath)) { New-Item -Path $NetworkPath -ItemType Directory -Force | Out-Null }
            $HtmlFile = Join-Path $NetworkPath ("{0}_{1}.html" -f $CleanModel, $Serial)
            $HtmlContent | Set-Content $HtmlFile -Encoding UTF8 -Force
        } catch { }
    } else {
        $LocalFolder = "C:\SW\Reports"
        if (-not (Test-Path $LocalFolder)) { New-Item -Path $LocalFolder -ItemType Directory -Force | Out-Null }
        $HtmlFile = Join-Path $LocalFolder ("{0}_{1}.html" -f $CleanModel, $Serial)
        $HtmlContent | Set-Content $HtmlFile -Encoding UTF8 -Force
        Write-Host "`n⚠️ Offline mode: Đã lưu báo cáo tại $LocalFolder" -ForegroundColor DarkGray
    }
    # 🏁 KẾT THÚC EXPORT

    # KIỂM TRA SHORTCUT
    Write-Host "Current 'SOFTWARE' path   >>> " -NoNewline -ForegroundColor Cyan
    Write-Host $SourceSW -ForegroundColor Yellow
    Write-Host "Current 'SOFTWARE2' path  >>> " -NoNewline -ForegroundColor Cyan
    if (Test-Path $SourceSW2) { Write-Host $SourceSW2 -ForegroundColor Yellow } else { Write-Host "Đường dẫn SOFTWARE2 không tồn tại" -ForegroundColor Red }
    Write-Host "Shortcut 'IT_Github.exe.lnk' exists in >>> " -NoNewline -ForegroundColor Cyan

    if (Test-Path $SystemDriveSWlnk) { Write-Host $SystemDriveSW -NoNewline -ForegroundColor Yellow } else { Write-Host $SystemDriveSW " (không tồn tại)" -NoNewline -ForegroundColor Red }
    Write-Host " & " -NoNewline -ForegroundColor Cyan

    if (Test-Path $ExpandedStartMenuLnk) { Write-Host $StartMenuShortPath -ForegroundColor Yellow } else { Write-Host $StartMenuShortPath " (không tồn tại)" -ForegroundColor Red }
    Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray

    # WINDOWS DEFENDER EXCLUSION
    Write-Host "<<< Current 'Windows Security\Exclusions' list >>>" -ForegroundColor Cyan
    $preferences = Get-MpPreference
    
    [string[]]$paths = if ($preferences.ExclusionPath) { $preferences.ExclusionPath } else { @("Không có") }
    [string[]]$proc  = if ($preferences.ExclusionProcess) { $preferences.ExclusionProcess } else { @("Không có") }
    [string[]]$ext   = if ($preferences.ExclusionExtension) { $preferences.ExclusionExtension } else { @("Không có") }

    $maxLen1 = ($paths | Measure-Object -Property Length -Maximum).Maximum
    $col1 = [Math]::Max($maxLen1, "ExclusionPath".Length) + 3

    $maxLen2 = ($proc | Measure-Object -Property Length -Maximum).Maximum
    $col2 = [Math]::Max($maxLen2, "ExclusionProcess".Length) + 3

    $maxLen3 = ($ext | Measure-Object -Property Length -Maximum).Maximum
    $col3 = [Math]::Max($maxLen3, "ExclusionExtension".Length) + 3

    $max = ($paths.Count,$proc.Count,$ext.Count | Measure-Object -Maximum).Maximum

    Write-Host ("{0,-$col1}{1,-$col2}{2}" -f "ExclusionPath","ExclusionProcess","ExclusionExtension")
    Write-Host ("{0,-$col1}{1,-$col2}{2}" -f ("-"*($col1-3)),("-"*($col2-3)),("-"*($col3-3)))
    
    for ($i=0; $i -lt $max; $i++) {
        $p1 = if ($i -lt $paths.Count) { $paths[$i] } else { "" }
        $p2 = if ($i -lt $proc.Count)  { $proc[$i] } else { "" }
        $p3 = if ($i -lt $ext.Count)   { $ext[$i] } else { "" }
        
        Write-Host ("{0,-$col1}{1,-$col2}{2}" -f $p1,$p2,$p3) -ForegroundColor Yellow
    }
    Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray

    Write-Host "User vui lòng nhập số " -NoNewline
    Write-Host "115" -ForegroundColor Yellow -NoNewline
    Write-Host " để được hỗ trợ: " -NoNewline

    $topMenu = Read-Host
    switch ($topMenu) {
        "111" { GoTo-IT-111 }
        "115" { GoTo-IT-115 }
        "113" { GoTo-IT-113 }
        default { return }
    }
}

function GoTo-IT-111 {
    Write-Host "`n→ Đang khởi động lại script..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$MainScript`""
    exit
}

function GoTo-IT-115 {
    Write-Host "`n→ Đang chuyển đến 'KHU VỰC NGƯỜI DÙNG'..." -ForegroundColor Cyan
    Run-IT-xxx "$IT115Script\IT-115.ps1" | Out-Null
    return
}

function GoTo-IT-113 {
    Write-Host "`n→ Đang chuyển đến 'KHU VỰC IT'..." -ForegroundColor Cyan
    Run-IT-xxx "$IT113Script\IT-113.ps1" | Out-Null
    return
}

# Vòng lặp chương trình chính
while ($true) {
    Show-Menu-IT
}
