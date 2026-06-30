param(
    [int]$PSWidth = 83,
    [int]$PSHeight = 58,
    [int]$PosX = -8,
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
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$consoleHandle = [WinAPI]::GetConsoleWindow()

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

try {
    # 1. Lấy giới hạn kích thước tối đa của màn hình hiện tại
    $maxSize = $host.UI.RawUI.MaxPhysicalWindowSize
    $safeWidth = [Math]::Min($PSWidth, $maxSize.Width)
    $safeHeight = [Math]::Min($PSHeight, $maxSize.Height)

    # 2. Đặt BufferSize TẠM (đảm bảo Width đủ rộng, không bị nhỏ hơn WindowSize hiện tại)
    $tempBufWidth = [Math]::Max($host.UI.RawUI.WindowSize.Width, $safeWidth)
    $newBufferHeight = [Math]::Max(1000, $safeHeight)
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($tempBufWidth, $newBufferHeight)

    # 3. Mới bắt đầu set WindowSize bằng kích thước an toàn
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($safeWidth, $safeHeight)

    # 4. Đặt lại BufferSize lần cuối để Width khít với Window (loại bỏ thanh cuộn ngang)
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($safeWidth, $newBufferHeight)

} catch {
    Write-Warning "Không thể thay đổi kích thước Window/Buffer. Đang dùng kích thước mặc định."
}

# 5. MoveWindow
$rect = New-Object WinAPI+RECT
[WinAPI]::GetWindowRect($handle, [ref]$rect)
$wPx = $rect.Right - $rect.Left
$hPx = $rect.Bottom - $rect.Top
[WinAPI]::MoveWindow($handle, $PosX, $PosY, $wPx, $hPx, $true) | Out-Null

# 5. KHỞI TẠO CÁC BIẾN & HÀM CẦN THIẾT
$script:IT113Script = $null
$possiblePaths = @("\\IT\Software\OS Tools\cmd-Powershell\IT\IT-113\", "\\IT-E580\Software\OS Tools\cmd-Powershell\IT\IT-113\")
$usbDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
foreach ($drive in $usbDrives) { $possiblePaths += "$($drive.DeviceID)\Software\OS Tools\cmd-Powershell\IT\IT-113\" }

foreach ($path in $possiblePaths) { if (Test-Path $path) { $script:IT113Script = $path; break } }

$script:ReportLines = @()
function Write-Log ($text, $color, $htmlClass = "") {
    if ($color) { Write-Host $text -ForegroundColor $color -NoNewline } else { Write-Host $text -NoNewline }
    $cleanText = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    if ($htmlClass) { $script:ReportLines += "<span class='$htmlClass'>$cleanText</span>" } else { $script:ReportLines += "$cleanText" }
}

function Run-IT-xxx {
    param([string]$ScriptPath)
    [WinAPI]::ShowWindow($consoleHandle, 2) # Minimize
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
    [WinAPI]::ShowWindow($consoleHandle, 9) # Restore
}

# ===== 3. HÀM HIỂN THỊ =====
function Show-Menu-IT {
    $script:ReportLines = @() # Reset báo cáo mỗi lần chạy
    Clear-Host
    
    # ---------------------------------------------------------
    # 🚩 SỬA TẠI ĐÂY: AUTO THEO BỀ RỘNG CỬA SỔ
    # Trừ đi 1 để tránh việc bị rớt dòng (line-wrap) nếu Console xuất hiện thanh cuộn dọc
    $w = $host.UI.RawUI.WindowSize.Width - 1
    
    # (Tùy chọn) Nếu bạn muốn ép cứng luôn bằng đúng tham số cấu hình ban đầu thì đổi thành:
    # $w = $PSWidth
    # ---------------------------------------------------------

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

    # Thêm Timestamp
	$RunTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss (dddd)"
	Write-Log "$m<<< $infoTitle >>>" "Cyan" "cyan"
	Write-Log "$mRun at: $RunTime" "DarkGray" "gray"
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
    
    # ===== CPU & RAM =====
    Write-Log "`n"
    
    $cpuList = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)
	$totalCPU = ($cpuList | Measure-Object).Count
    
    # Lấy thông tin RAM với cơ chế an toàn
    $RAM = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $memArrays = @(Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue)
    
    # Xác định loại RAM ECC hay Non-ECC công thức chính xác cho cả mảng
    $ramType = if ($memArrays | Where-Object { $_.MemoryErrorCorrection -in 5,6 }) { "ECC" } else { "Non-ECC" }
    $totalRAM = if ($RAM) { [math]::round(($RAM | Measure-Object Capacity -Sum).Sum / 1GB) } else { 0 }
    
    Show-Line "CPU" "$totalCPU CPU"
    Show-Line "RAM (TOTAL)" "$totalRAM GB ($ramType)"
    Write-Log "`n" "" ""

    $cpuIdx = 0
    foreach ($c in $cpuList) {
        $cpuId = $c.DeviceID -replace 'CPU',''
        $cpuName = $c.Name
        
        # Lọc RAM thuộc CPU hiện tại
        $cpuRAM = $RAM | Where-Object { 
            $_.DeviceLocator -match "CPU$cpuId|Node$cpuId" -or 
            ($cpuId -eq "0" -and $_.DeviceLocator -notmatch "CPU1|Node1")
        }
        
        # 1. BẮT ĐẦU ĐẾM THỦ CÔNG SỐ RAM ĐANG CẮM THỰC TẾ
        $trueUsedSlots = 0
        $ramOutputLines = @()
        
        foreach ($r in $cpuRAM) {
            $label = if ($r.DeviceLocator) { $r.DeviceLocator -replace "DIMM","Slot" -replace " ", "" } else { "Slot $($trueUsedSlots + 1)" }
            $size = [math]::round($r.Capacity/1GB)
            $manu = if ($r.Manufacturer) { $r.Manufacturer.Trim() } else { "Unknown" }
            $part = if ($r.PartNumber) { $r.PartNumber.Trim() } else { "Unknown" }
            
            # Lưu lại chuỗi thông tin để in ra sau
            $info = "$size GB | $($r.Speed) MHz | $manu | $part"
            $ramOutputLines += [PSCustomObject]@{ Label = $label; Info = $info }
            
            $trueUsedSlots++
        }
        
        # 2. XÁC ĐỊNH TỔNG SỐ KHE (SLOTS) THỰC TẾ CHO TỪNG CPU KHÁC NHAU
        $cpuTotalSlots = 4 # Mặc định dự phòng thấp nhất
        
        if ($totalCPU -eq 1) {
            # Máy 1 CPU (như Z420), lấy chuẩn số khe hệ thống khai báo
            if ($memArrays.Count -gt 0) { $cpuTotalSlots = $memArrays[0].MemoryDevices } else { $cpuTotalSlots = 8 }
        } else {
            # Máy nhiều CPU (như Z620)
            if ($memArrays.Count -gt $cpuIdx) {
                # Trường hợp WMI trả về nhiều Array độc lập (Mỗi CPU nắm 1 mảng khe riêng)
                $cpuTotalSlots = $memArrays[$cpuIdx].MemoryDevices
            } else {
                # Trường hợp WMI bị lỗi gom chung thành 1 Array tổng (ví dụ báo tổng máy có 12 khe)
                $totalDevicesAll = ($memArrays | Measure-Object MemoryDevices -Sum).Sum
                if ($totalDevicesAll -eq 12) {
                    # Fix cứng theo cấu trúc chuẩn của HP Z620: CPU0 = 8 slots, CPU1 = 4 slots
                    $cpuTotalSlots = if ($cpuIdx -eq 0) { 8 } else { 4 }
                } else {
                    # Cơ chế Fallback cuối cùng nếu không khớp form nào
                    $cpuTotalSlots = [math]::Max(4, $trueUsedSlots)
                }
            }
        }
        
        # Ép tổng số khe không được nhỏ hơn số thanh thực tế đang cắm
        if ($cpuTotalSlots -lt $trueUsedSlots) { $cpuTotalSlots = $trueUsedSlots }
        
        $cpuFreeSlots = $cpuTotalSlots - $trueUsedSlots
        if ($cpuFreeSlots -lt 0) { $cpuFreeSlots = 0 }

        # 3. TÍNH TỔNG GB RAM CỦA RIÊNG CPU NÀY
        $cpuTotalGB = if ($trueUsedSlots -gt 0) { 
            [math]::round(($cpuRAM | Measure-Object Capacity -Sum).Sum / 1GB) 
        } else { 0 }

        # 4. IN KẾT QUẢ RA CONSOLE
        Show-Line "  CPU$cpuId" $cpuName
        Show-Sub "└─ Total Memory" "$cpuTotalGB GB"
        
        foreach ($ro in $ramOutputLines) {
            Show-Sub "   └─ $($ro.Label)" $ro.Info
        }
        
        Show-Sub "   └─ Free/Total Slots" "$cpuFreeSlots / $cpuTotalSlots"
        Write-Log "`n" "" ""
        
        $cpuIdx++ # Tăng tiến trình để đọc mảng Array tiếp theo cho CPU kế tiếp
    }
    
	Write-Log "`n"
	
    $disks = Get-CimInstance Win32_DiskDrive
    Show-Line "STORAGE (TOTAL)" "$([math]::round(($disks | Measure-Object Size -Sum).Sum / 1GB)) GB"
    $i = 1; foreach ($d in $disks) { Show-Sub "Disk $i" "$($d.Model)  $([math]::round($d.Size/1GB)) GB"; $i++ }
    
	Write-Log "`n"
    
	$vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) {
        if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ }
    }
    Show-Line "GRAPHICS" ("{0} VGA / {1} GPU" -f $vgaCount, $gpuCount)
    foreach ($g in $GPU) {
        $label = if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { "VGA" } else { "GPU" }
        Show-Sub $label $g.Name
    }
	
	Write-Log "`n"
	Show-Line "NETWORK ADAPTER" ""

	$net = Get-NetAdapter -Physical | Sort-Object Name

	foreach ($n in $net) {
		# Xác định loại
		$type = switch -Regex ($n.Name) {
			'^Wi-Fi|^Wireless' { 'Wi-Fi' }
			'^Ethernet'        { 'Ethernet' }
			'Bluetooth'        { 'Bluetooth' }
			default            { 'LAN' }
		}

		$status = if ($n.Status -eq 'Up') { "√ Up" } else { "X Down" }
		$speed  = if ($n.LinkSpeed) { $n.LinkSpeed } else { "N/A" }

		Show-Sub "$type Adapter" "$($n.InterfaceDescription) - $status"
		Show-Sub "   └─ MAC " $n.MacAddress
		Show-Sub "   └─ Speed" $speed
	}
    
	Write-Log "`n"
    Show-Line "WINDOWS" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | $($RegOS.CurrentBuild).$($RegOS.UBR)"
	
	Write-Log "`n"   
    Show-Line "Current User" "$env:COMPUTERNAME\$env:USERNAME"
	
    # Xác định vị trí 113 để hiển thị
    $loc113 = if ($script:IT113Script) {
        if ($script:IT113Script -match '^\\\\[^\\]+') { ($matches[0]) } # Lấy \\IT hoặc \\IT-E580
        elseif ($script:IT113Script -match '^[a-zA-Z]:') { ($matches[0]) } # Lấy DriverLetter:
        else { "Local/Unknown" }
    } else { "Offline" }

	Write-Log "`n"   
    Show-Line "Current 113 location" "$loc113"
	
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
            Write-Host "`n[ONLINE] WARNING → Có mạng nhưng folder mạng đang chặn quyền ghi file!" -ForegroundColor Red
        }
    } else {
        Write-Host "`n[OFFLINE] Khong thay Server mang '$ServerHost'. Bo qua luu ban backup tren server." -ForegroundColor DarkGray
    }
# 🏁 KẾT THÚC EXPORT
    
    Write-Host ("+" * $w) -ForegroundColor DarkGray
    Write-Host "$m" -NoNewline    
    Write-Host "`nUser vui lòng nhập " -NoNewline; 
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
        # Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script:IT113Script\IT-113.ps1`""
		Run-IT-xxx "$script:IT113Script\IT-113.ps1" | Out-Null
    } else {
        Write-Host "`n→ Công cụ 113 hiện không khả dụng!" -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

while ($true) {
    Show-Menu-IT
}
