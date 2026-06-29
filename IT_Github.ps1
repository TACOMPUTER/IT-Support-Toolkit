param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 52,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

# 1. Khai báo WINAPI sớm
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

# 🚩 <<<--- CHỈ CHO 1 SCRIPT CHẠY --->>>

$currentPID = $PID
$scriptName = [System.IO.Path]::GetFileName($PSCommandPath)

Get-Process powershell | Where-Object {
    $_.Id -ne $currentPID -and
    $_.Path -ne $null
} | ForEach-Object {

    try {
        # Lấy command line an toàn hơn
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine

        if ($cmd -and $cmd -match [regex]::Escape($scriptName)) {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # bỏ qua lỗi SID mapping
    }
}

# 🏁 <<<--- END --->>>

# 2. XÁC ĐỊNH PATH & ADMIN
$script:MainScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Đang nâng quyền Administrator..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$script:MainScript`"" -Verb RunAs
    exit
}

# 3. SET WINDOW TITLE (Sửa cú pháp tại đây)
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running '" + (Split-Path $script:MainScript -Leaf) + "' $adminText <<< IT_Github.ps1"

# 4. RESIZE & MOVE
$handle = [WinAPI]::GetConsoleWindow()

# Lấy kích thước hiện tại của màn hình console
$currentWindow = $host.UI.RawUI.WindowSize
$currentBuffer = $host.UI.RawUI.BufferSize

# 1. Đặt WindowSize trước (nếu WindowSize mới lớn hơn hiện tại)
try {
    $newWindowSize = New-Object System.Management.Automation.Host.Size($PSWidth, $PSHeight)
    $host.UI.RawUI.WindowSize = $newWindowSize
} catch {
    Write-Warning "Không thể thay đổi kích thước WindowSize."
}

# 2. Đặt BufferSize: Phải luôn >= WindowSize
# Chúng ta lấy giá trị lớn hơn hoặc bằng chiều cao của Window mới
$newBufferHeight = [Math]::Max(1000, $PSHeight)
$host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($PSWidth, $newBufferHeight)

# 3. MoveWindow
$rect = New-Object WinAPI+RECT
[WinAPI]::GetWindowRect($handle, [ref]$rect)
$wPx = $rect.Right - $rect.Left
$hPx = $rect.Bottom - $rect.Top
[WinAPI]::MoveWindow($handle, $PosX, $PosY, $wPx, $hPx, $true) | Out-Null

# 5. KHỞI TẠO CÁC BIẾN & HÀM CẦN THIẾT
$script:IT113Script = $null
$possiblePaths = @("\\IT\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1", "\\IT-E580\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1")
$usbDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
foreach ($drive in $usbDrives) { $possiblePaths += "$($drive.DeviceID)\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1" }

foreach ($path in $possiblePaths) { if (Test-Path $path) { $script:IT113Script = $path; break } }

$script:ReportLines = @()
function Write-Log ($text, $color, $htmlClass = "") {
    if ($color) { Write-Host $text -ForegroundColor $color -NoNewline } else { Write-Host $text -NoNewline }
    $cleanText = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    if ($htmlClass) { $script:ReportLines += "<span class='$htmlClass'>$cleanText</span>" } else { $script:ReportLines += "$cleanText" }
}



# ===== 3. HÀM HIỂN THỊ =====
function Show-Menu-IT {
    $script:ReportLines = @() # Reset báo cáo mỗi lần chạy
	Clear-Host
    $w = 80
    $m = " " # Margin 2 khoảng trắng
    
    # Nhận dạng Laptop/PC
    $IsLaptop = (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) -ne $null
    $infoTitle = if ($IsLaptop) { "Laptop Information" } else { "PC Information" }
	
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

    Write-Log "$m<<< $infoTitle >>>" "Cyan" "cyan"
    Write-Log "`n" "" ""
    
    function Show-Line ($l, $v) { 
        Write-Log ($m + "{0,-22} : " -f $l) "Green" "green"
        Write-Log "$v`n" "Yellow" "yellow"
    }
    function Show-Sub ($l, $v) { 
        Write-Log ($m + "  {0,-20} → " -f $l) "Blue" "blue"
        Write-Log "$v`n" "Blue" "blue"
    }
	
	Write-Log "`n"

    Show-Line "MAINBOARD" ""
	Show-Sub "Brand (OEM)" $CS.Manufacturer
	Show-Sub "Manufacturer" $BB.Manufacturer
	Show-Sub "Product" $BB.Product
	Show-Sub "Model" $CS.Model
	Show-Sub "Serial" $BIOS.SerialNumber
	Show-Sub "BIOS ver" $BIOS.SMBIOSBIOSVersion
    
    # ===== CPU & RAM Phân tách theo Socket =====
    $cpuList = @($CPU)
    Write-Log "`n"
    Show-Line "CPU" ""
    
    foreach ($c in $cpuList) { 
        # Hiển thị CPU theo ID (CPU 0, CPU 1...)
        Show-Sub "CPU $($c.DeviceID -replace 'CPU','')" $c.Name
    }

    Write-Log "`n" "" ""
    $memArray = Get-CimInstance Win32_PhysicalMemoryArray
    
    # Hiển thị RAM theo nhóm CPU (Sử dụng Group-Object)
    # Các máy Z620 thường trả về Node hoặc DeviceLocator chứa thông tin CPU
    $ramGroups = $RAM | Group-Object -Property { 
        if ($_.DeviceLocator -match "CPU1") { "CPU 1" } else { "CPU 0" } 
    } | Sort-Object Name

    foreach ($group in $ramGroups) {
        Show-Line "RAM - $($group.Name)" ""
        foreach ($r in $group.Group) {
            $label = $r.DeviceLocator -replace "DIMM","Slot"
            $info = "$([math]::round($r.Capacity/1GB)) GB | $($r.Speed) MHz | $($r.Manufacturer.Trim())"
            Show-Sub $label $info
        }
    }

    # Tổng kết slot
    # 1. Lấy tất cả mảng MemoryArray
    $memArrays = Get-CimInstance Win32_PhysicalMemoryArray
    
    # 2. Tính tổng số khe cắm (MemoryDevices) từ tất cả các mảng (phòng trường hợp máy có nhiều Memory Controller)
    $totalSlots = ($memArrays | Measure-Object MemoryDevices -Sum).Sum
    
    # 3. Tính số slot trống
    $freeSlots = $totalSlots - $RAM.Count
    
    # 4. Hiển thị
    Show-Sub "Available Slots" "$freeSlots / $totalSlots"
    
	Write-Log "`n"
	
    $disks = Get-CimInstance Win32_DiskDrive
    Show-Line "Storage (Total)" "$([math]::round(($disks | Measure-Object Size -Sum).Sum / 1GB)) GB"
    $i = 1; foreach ($d in $disks) { Show-Sub "Disk $i" "$($d.Model)  $([math]::round($d.Size/1GB)) GB"; $i++ }
    
	Write-Log "`n"
    
	$vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) {
        if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ }
    }
    Show-Line "Graphics" ("{0} VGA / {1} GPU" -f $vgaCount, $gpuCount)
    foreach ($g in $GPU) {
        $label = if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { "VGA" } else { "GPU" }
        Show-Sub $label $g.Name
    }
	
	Write-Log "`n"
	
    Show-Line "MAC ADDRESS" ""

	$net = Get-NetAdapter -Physical

	foreach ($n in $net) {

		switch -Regex ($n.Name) {
			'^Wi-Fi$|^WiFi$' {
				$type = 'WiFi'
				break
			}

			'^Bluetooth' {
				$type = 'Bluetooth'
				break
			}

			default {
				$type = 'LAN'
			}
		}

		Show-Sub "$type Adapter" $n.InterfaceDescription
		Show-Sub "$type MAC" $n.MacAddress
	}
    
	Write-Log "`n"
    Show-Line "Windows" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | $($RegOS.CurrentBuild).$($RegOS.UBR)"
   
    Write-Log "`n$m" "" ""
    Write-Log "Current User         >>> " "Green" "green"
    Write-Log "$env:COMPUTERNAME\$env:USERNAME`n" "Yellow" "yellow"

    # Xác định vị trí 113 để hiển thị
    $loc113 = if ($script:IT113Script) {
        if ($script:IT113Script -match '^\\\\[^\\]+') { ($matches[0]) } # Lấy \\IT hoặc \\IT-E580
        elseif ($script:IT113Script -match '^[a-zA-Z]:') { ($matches[0]) } # Lấy DriverLetter:
        else { "Local/Unknown" }
    } else { "Offline" }

	Write-Host ""
    Write-Host "$m" -NoNewline
    Write-Host "Current 113 location >>> " -NoNewline -ForegroundColor Green
    Write-Host $loc113 -ForegroundColor Yellow
	
	# 🚩 EXPORT HTML (TỐI ƯU: LUÔN LUÔN GHI LOCAL + TỰ ĐỘNG ĐẨY SERVER NẾU ONLINE)
    $Serial = $BIOS.SerialNumber
    $CleanModel = ($CS.Model -replace '[\\/:*?"<>|]', '').Trim()
    $Content = $script:ReportLines -join ""
    $FileName = "{0}_{1}.html" -f $CleanModel, $Serial
    $HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
    body { 
        font-family: 'Consolas', 'Lucida Console', monospace; 
        background-color: #0c0c0c; 
        color: #cccccc; 
        padding: 20px; 
    }
    pre { 
        white-space: pre; 
        font-size: 14px;       /* Tăng cỡ chữ */
        line-height: 1.5;      /* Tăng giãn dòng để thoáng hơn */
    }
    .green { color: #00ff00; } 
    .yellow { color: #ffff00; }
    .blue { color: #3b8ec2; } 
    .cyan { color: #00ffff; }
</style>
</head>
<body><pre>$Content</pre></body>
</html>
"@

    # --- 1. LUÔN LUÔN GHI BẢN LOCAL TRƯỚC ---
    $LocalFolder = "C:\SW\Reports"
    try {
        if (-not (Test-Path $LocalFolder)) { 
            New-Item -Path $LocalFolder -ItemType Directory -Force | Out-Null 
        }
        $LocalFile = Join-Path $LocalFolder $FileName
        $HtmlContent | Set-Content $LocalFile -Encoding UTF8 -Force
    } catch {
        Write-Host "[LOCAL] WARNING → Khong the tao folder hoac ghi file tai o C!" -ForegroundColor Yellow
    }

    # --- 2. KIỂM TRA MẠNG VÀ ĐẨY TIẾP BẢN BACKUP LÊN SERVER ---
    $ServerHost = "IT" 
    $NetworkPath = "\\$ServerHost\Guest\Computer list"
    
    $isOnline = $false
    try {
        if (Test-Connection -ComputerName $ServerHost -Count 1 -Quiet) {
            $isOnline = $true
        }
    } catch { $isOnline = $false }

    if ($isOnline -and (Test-Path "\\$ServerHost\Guest")) {
        try {
            if (-not (Test-Path $NetworkPath)) { 
                New-Item -Path $NetworkPath -ItemType Directory -Force | Out-Null 
            }
            $NetworkFile = Join-Path $NetworkPath $FileName
            $HtmlContent | Set-Content $NetworkFile -Encoding UTF8 -Force
        } catch { 
            Write-Host "[ONLINE] WARNING → Có mạng nhưng folder mạng đang chặn quyền ghi file!" -ForegroundColor Red
        }
    } else {
        Write-Host "[OFFLINE] Khong thay Server mang '$ServerHost'. Bo qua luu ban backup tren server." -ForegroundColor DarkGray
    }
# 🏁 KẾT THÚC EXPORT
    
    Write-Host ("+" * $w) -ForegroundColor DarkGray
    Write-Host "$m" -NoNewline    
    Write-Host "User vui lòng nhập " -NoNewline; 
    Write-Host "115" -ForegroundColor Yellow -NoNewline; 
    Write-Host " để được hỗ trợ nhanh: " -NoNewline
	
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
	Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script:MainScript`"" -WorkingDirectory (Split-Path $script:MainScript)
    exit
}

function GoTo-IT-113 {
    if ($script:IT113Script) {
        Write-Host "`n→ Đang mở công cụ IT-113..." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script:IT113Script`""
    } else {
        Write-Host "`n→ Công cụ 113 hiện không khả dụng!" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

while ($true) {
    Show-Menu-IT
}
