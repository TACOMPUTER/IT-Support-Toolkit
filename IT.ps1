# ================================
# IT SUPPORT TOOLKIT - CLEAN
# RUN DIRECT FROM GITHUB
# ================================

$ErrorActionPreference = "SilentlyContinue"

# ================================
# WIN API (MOVE WINDOW)
# ================================
if (-not ("WinAPI" -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WinAPI {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);
}
"@
}

$console = [WinAPI]::GetConsoleWindow()

# ================================
# CONFIG
# ================================
$PSWidth  = 110
$PSHeight = 45
$PosX     = 200
$PosY     = 100

# ================================
# RESIZE + MOVE WINDOW
# ================================
try {
    $host.UI.RawUI.BufferWidth  = $PSWidth
    $host.UI.RawUI.BufferHeight = 300
    $host.UI.RawUI.WindowWidth  = $PSWidth
    $host.UI.RawUI.WindowHeight = $PSHeight
} catch {}

[WinAPI]::MoveWindow($console, $PosX, $PosY, 900, 600, $true) | Out-Null

# ================================
# SINGLE INSTANCE
# ================================
$current = $PID
Get-Process powershell | Where-Object {
    $_.Id -ne $current -and $_.MainWindowTitle -like "*IT SUPPORT*"
} | Stop-Process -Force

# ================================
# ADMIN CHECK
# ================================
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Start-Process powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/IT.ps1 | iex" `
        -Verb RunAs
    exit
}

# ================================
# SHORTCUTS
# ================================
$sw = "C:\SW"
$lnk1 = "$sw\IT.lnk"

if (-not (Test-Path $sw)) {
    New-Item $sw -ItemType Directory | Out-Null
}

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($lnk1)
$sc.TargetPath = "powershell.exe"
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/IT.ps1 | iex"
$sc.Save()

# ================================
# SYSTEM INFO (GET ONCE)
# ================================
$CS   = Get-CimInstance Win32_ComputerSystem
$BB   = Get-CimInstance Win32_BaseBoard
$BIOS = Get-CimInstance Win32_BIOS
$CPU  = Get-CimInstance Win32_Processor
$RAM  = Get-CimInstance Win32_PhysicalMemory
$DISK = Get-CimInstance Win32_DiskDrive
$GPU  = Get-CimInstance Win32_VideoController
$OS   = Get-CimInstance Win32_OperatingSystem
$REG  = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$NET  = Get-CimInstance Win32_NetworkAdapter | Where-Object {$_.MACAddress}

# ================================
# HELPERS
# ================================
function L($k,$v){
    "{0,-18} >>> {1}" -f $k,$v
}

function S($k,$v){
    "  {0,-16}-> {1}" -f $k,$v
}

Clear-Host

# ================================
# HEADER
# ================================
$line = "+" * 90
Write-Host $line
Write-Host " IT SUPPORT TOOLKIT - TACOMPUTER / GPT " -ForegroundColor Cyan
Write-Host $line

# ================================
# BASIC INFO
# ================================
Write-Host "`n<<< PC INFORMATION >>>`n" -ForegroundColor Cyan

Write-Host (L "Brand" $CS.Manufacturer)
Write-Host (L "Mainboard" $BB.Manufacturer)
Write-Host (L "Model" $CS.Model)
Write-Host (L "Serial" $BIOS.SerialNumber)
Write-Host (L "BIOS" $BIOS.SMBIOSBIOSVersion)

Write-Host ""

# CPU
Write-Host (L "CPU" $CPU.Name)

# RAM
$totalRam = "{0:N0}" -f ((($RAM | Measure-Object Capacity -Sum).Sum)/1GB)
Write-Host (L "RAM Total" "$totalRam GB")

foreach ($r in $RAM) {
    S $r.DeviceLocator "$([math]::Round($r.Capacity/1GB)) GB $($r.Speed) MHz"
}

# DISK
$totalDisk = "{0:N0}" -f ((($DISK | Measure-Object Size -Sum).Sum)/1GB)
Write-Host (L "Storage" "$totalDisk GB")

foreach ($d in $DISK) {
    S "Disk" "$($d.Model) $([math]::Round($d.Size/1GB)) GB"
}

# GPU
foreach ($g in $GPU) {
    S "GPU" $g.Name
}

# MAC
Write-Host "`nMAC Address"
foreach ($n in $NET) {
    S $n.Name $n.MACAddress
}

# WINDOWS
Write-Host "`n" + (L "Windows" "$($REG.ProductName) $($REG.DisplayVersion)")

# USER
Write-Host (L "User" "$env:COMPUTERNAME\$env:USERNAME")

Write-Host $line

# ================================
# EXPORT HTML
# ================================
$report = "C:\SW\Reports"
if (-not (Test-Path $report)) { New-Item $report -ItemType Directory | Out-Null }

$file = "$($CS.Model)_$($BIOS.SerialNumber).html"

$html = @"
<html>
<body style="font-family:Consolas;background:#111;color:#0f0">
<pre>
IT SUPPORT REPORT

$($CS.Manufacturer) - $($CS.Model)
CPU: $($CPU.Name)
RAM: $totalRam GB
DISK: $totalDisk GB
USER: $env:COMPUTERNAME\$env:USERNAME
</pre>
</body>
</html>
"@

$localFile = Join-Path $report $file
$html | Out-File $localFile -Encoding UTF8

# SERVER BACKUP
$server = "\\IT\Guest\Computer list"
if (Test-Path "\\IT\Guest") {
    try {
        $html | Out-File (Join-Path $server $file) -Encoding UTF8
    } catch {}
}

# ================================
# MENU
# ================================
Write-Host "`nUser nhập 115 để tiếp tục: " -NoNewline
$opt = Read-Host

switch ($opt) {
    "115" {
        irm "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/IT/IT-115/IT-115.ps1" | iex
    }
    default {
        Write-Host "Exit"
    }
}
