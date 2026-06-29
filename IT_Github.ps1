# ===== 1. TỐI ƯU CỬA SỔ & TIÊU ĐỀ =====
$fileName = Split-Path $MyInvocation.MyCommand.Path -Leaf
$folderPath = "Github\IT-Support-Toolkit"
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running '$fileName' $adminText <<< $folderPath"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
}
"@

$handle = [WinAPI]::GetConsoleWindow()
# Dùng MoveWindow để định hình kích thước cửa sổ thay vì ép thuộc tính [Console] trực tiếp
# W=640 (tương ứng chiều ngang 80 ký tự), H=850
[WinAPI]::MoveWindow($handle, 0, 0, 597, 850, $true)

# ===== 2. CHỈ CHO 1 SCRIPT CHẠY DUY NHẤT =====
$currentPID = $PID
Get-CimInstance Win32_Process | Where-Object {
    $_.ProcessId -ne $currentPID -and $_.CommandLine -match [regex]::Escape($fileName)
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# ===== 3. HÀM HIỂN THỊ =====
function Show-Menu-IT {
    Clear-Host
    $w = 80
    $m = " " # Margin 2 khoảng trắng
    
    # In tiêu đề
    Write-Host ("+" * $w) -ForegroundColor DarkGray
    $text = " IT support, Scripted by TACOMPUTER & GPT, 0933.848.990 "
    $pad = [Math]::Max(0, $w - $text.Length)
    Write-Host ("+" * [Math]::Floor($pad / 2)) -ForegroundColor DarkGray -NoNewline
    Write-Host $text -NoNewline
    Write-Host ("+" * ([Math]::Ceiling($pad / 2))) -ForegroundColor DarkGray
    Write-Host ("+" * $w) -ForegroundColor DarkGray

    $CS = Get-CimInstance Win32_ComputerSystem; $BB = Get-CimInstance Win32_BaseBoard
    $CPU = Get-CimInstance Win32_Processor; $RAM = Get-CimInstance Win32_PhysicalMemory
    $BIOS = Get-CimInstance Win32_BIOS; $GPU = Get-CimInstance Win32_VideoController
    $RegOS = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

    Write-Host "$m<<< PC Information >>>" -ForegroundColor Cyan
    
    function Show-Line ($l, $v) { 
        Write-Host ($m + "{0,-20} >>> " -f $l) -NoNewline -ForegroundColor Green
        Write-Host $v -ForegroundColor Yellow 
    }
    function Show-Sub ($l, $v) { 
        Write-Host ($m + "  {0,-16}-> " -f $l) -NoNewline -ForegroundColor Blue
        Write-Host $v -ForegroundColor Blue 
    }

    Show-Line "Brand (OEM)" $CS.Manufacturer
    Show-Line "Mainboard" $BB.Manufacturer
    Show-Line "Product" $BB.Product
    Show-Line "Model" $CS.Model
    Show-Line "Serial" $BIOS.SerialNumber
    Show-Line "BIOS ver" $BIOS.SMBIOSBIOSVersion
    Write-Host ""

    if ($CPU.Count -gt 1) { 
        Write-Host ("{0,-20} >>> " -f "CPU") -NoNewline -ForegroundColor Green; Write-Host ""
        $i = 1; foreach ($c in $CPU) { Show-Sub "CPU $i" $c.Name; $i++ }
    } else { Show-Line "CPU" $CPU.Name }

    $ramType = if ((Get-CimInstance Win32_PhysicalMemoryArray).MemoryErrorCorrection -in 5,6) { "ECC" } else { "Non-ECC" }
    Show-Line "RAM (Total)" "$([math]::round(($RAM | Measure-Object Capacity -Sum).Sum / 1GB)) GB ($ramType)"
    $i = 1; foreach ($r in $RAM) { Show-Sub ($r.DeviceLocator -replace "DIMM","CPU0-DIMM") "$([math]::round($r.Capacity/1GB)) GB  $($r.Speed) MHz  |  $($r.Manufacturer.Trim())  |  $($r.PartNumber.Trim())"; $i++ }
    Show-Sub "Available Slots" "$((Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices - $RAM.Count)/$((Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices)"
    
    $disks = Get-CimInstance Win32_DiskDrive
    Show-Line "Storage (Total)" "$([math]::round(($disks | Measure-Object Size -Sum).Sum / 1GB)) GB"
    $i = 1; foreach ($d in $disks) { Show-Sub "Disk $i" "$($d.Model)  $([math]::round($d.Size/1GB)) GB"; $i++ }
    
    $vgaCount = ($GPU | Where-Object { $_.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX" }).Count
    Show-Line "Graphics" ("{0} VGA / {1} GPU" -f $vgaCount, ($GPU.Count - $vgaCount))
    foreach ($g in $GPU) { 
        $label = if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { "VGA" } else { "GPU" }
        Show-Sub $label $g.Name 
    }
    Write-Host ""
    
    Write-Host ""
    Write-Host "$m" -NoNewline
    Write-Host "MAC Address          >>>" -ForegroundColor Green
    foreach ($a in (Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -and $_.PhysicalAdapter })) {
        $type = if ($a.Name -match "Bluetooth") { "Bluetooth" } elseif ($a.Name -match "Wi-Fi|WLAN") { "WiFi" } else { "LAN" }
        Write-Host "$m  $type - $($a.Name)" -ForegroundColor Blue
        Write-Host "$m                  -> " -NoNewline -ForegroundColor Blue
        Write-Host $a.MACAddress -ForegroundColor Blue
    }
    Write-Host ""
    Show-Line "Windows" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | $($RegOS.CurrentBuild).$($RegOS.UBR)"
    
    Write-Host "`n$m" -NoNewline
    Write-Host "Current User         >>> " -NoNewline -ForegroundColor Green
    Write-Host "$env:COMPUTERNAME\$env:USERNAME" -ForegroundColor Yellow
    
    Write-Host ("+" * $w) -ForegroundColor DarkGray
    Write-Host "$m" -NoNewline
    Write-Host "User vui lòng nhập số " -NoNewline; Write-Host "115" -ForegroundColor Yellow -NoNewline; Write-Host " để được hỗ trợ: " -NoNewline
    Read-Host
}

while ($true) { Show-Menu-IT }
