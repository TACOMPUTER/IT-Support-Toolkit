# 🚩 <<<--- THÔNG SỐ CỬA SỔ PS P.1 --->>>

param(
    [int]$PSWidth = 90,
    [int]$PSHeight = 58,
    [int]$PosX = -8,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

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

# 🏁 <<<--- END THÔNG SỐ CỬA SỔ PS P.1 --->>>




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

# 🏁 <<<--- END CHỈ CHO 1 SCRIPT CHẠY --->>>



# 🚩 <<<--- NÂNG QUYỀN ADMIN CHO SCRIPT ĐANG CHẠY --->>>

$script:MainScript = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipAdminCheck -and -not $IsAdmin) {
    Write-Host "⚠️ Đang nâng quyền Administrator..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$script:MainScript`"" -Verb RunAs
    exit
}

# 🏁 <<<--- END NÂNG QUYỀN ADMIN CHO SCRIPT ĐANG CHẠY --->>>



# 🚩 <<<--- THÔNG SỐ CỬA SỔ PS P.2 --->>>

# Title Window
$adminText = if ($IsAdmin) { "as Admin" } else { "as User" }
$host.UI.RawUI.WindowTitle = "Running '" + (Split-Path $script:MainScript -Leaf) + "' $adminText <<< IT_Github.ps1"

# Resize Window
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

# Move Window
$rect = New-Object WinAPI+RECT
[WinAPI]::GetWindowRect($handle, [ref]$rect)
$wPx = $rect.Right - $rect.Left
$hPx = $rect.Bottom - $rect.Top
[WinAPI]::MoveWindow($handle, $PosX, $PosY, $wPx, $hPx, $true) | Out-Null

# 🏁 <<<--- END THÔNG SỐ CỬA SỔ PS P.2 --->>>




# 🚩 <<<--- XÁC ĐỊNH VỊ TRÍ IT-113.ps1 --->>>

# Thứ tự ưu tiên như sau:
# 1. D:\~H:\OneDrive\TACOMPUTER\Software\OS Tools\cmd-Powershell\IT\IT-113
# 2. \\IT\Software\OS Tools\cmd-Powershell\IT\IT-113
# 3. \\IT-E580\Software\OS Tools\cmd-Powershell\IT\IT-113
# 4. Tất cả ổ USB (Flash/HDD/SSD)

$script:IT113Script = $null
$script:IT113Online = @()

$SearchList = @()

# ==========================================================
# ƯU TIÊN 1 : OneDrive (D: -> H:)
# ==========================================================
foreach ($drive in 'D','E','F','G','H') {

    $SearchList += "$($drive):\OneDrive\TACOMPUTER\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1"

}

# ==========================================================
# ƯU TIÊN 2 : Server IT
# ==========================================================
$SearchList += "\\IT\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1"

# ==========================================================
# ƯU TIÊN 3 : Server IT-E580
# ==========================================================
$SearchList += "\\IT-E580\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1"

# ==========================================================
# ƯU TIÊN 4 : USB (Flash + HDD + SSD)
# ==========================================================

$usbDrives = Get-CimInstance Win32_DiskDrive |
Where-Object InterfaceType -eq 'USB'

foreach ($disk in $usbDrives) {

    $partitions = Get-CimAssociatedInstance -InputObject $disk -Association Win32_DiskDriveToDiskPartition

    foreach ($partition in $partitions) {

        $logicalDisks = Get-CimAssociatedInstance -InputObject $partition -Association Win32_LogicalDiskToPartition

        foreach ($logicalDisk in $logicalDisks) {

            $SearchList += "$($logicalDisk.DeviceID)\Software\OS Tools\cmd-Powershell\IT\IT-113\IT-113.ps1"

        }
    }
}

# ==========================================================
# TÌM FILE ĐẦU TIÊN
# ==========================================================

foreach ($file in $SearchList) {

    if (Test-Path $file) {

        $folder = Split-Path $file -Parent

        # Chỉ lấy phần đầu để hiển thị
        if ($folder -match '^\\\\[^\\]+') {
            $short = $matches[0]
        }
        elseif ($folder -match '^[A-Za-z]:') {
            $short = $matches[0]
        }
        else {
            $short = "Unknown"
        }

        if ($script:IT113Online -notcontains $short) {
            $script:IT113Online += $short
        }

        # Chỉ gán location lần đầu (đúng thứ tự ưu tiên)
        if (-not $script:IT113Script) {
            $script:IT113Script = $folder
        }
    }
}

# 🏁 <<<--- END XÁC ĐỊNH VỊ TRÍ IT-113.ps1 --->>>



# 🚩 <<<--- FUNCTION CHO THÔNG SỐ CẤU HÌNH MÁY TÍNH --->>>

$script:ReportLines = @()
function Write-Log ($text, $color, $htmlClass = "") {
    if ($color) { Write-Host $text -ForegroundColor $color -NoNewline } else { Write-Host $text -NoNewline }
    $cleanText = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    if ($htmlClass) { $script:ReportLines += "<span class='$htmlClass'>$cleanText</span>" } else { $script:ReportLines += "$cleanText" }
}

$UI = @{
    LabelWidth = 20	# Đẩy mũi tên di chuyển

    Color1 = "Cyan"
    Color2 = "Green"
    Color3 = "Blue"

    ValueColor = "Yellow"
}

function Show-Item {

    param(
        [ValidateSet(1,2,3)]
        [int]$Level,

        [string]$Label,

        [string]$Value=""
    )

    switch($Level){

        1{
            Write-Log "$Label`n" $UI.Color1 "cyan"
        }

        2{
            $prefix = "└─ "
            $labelColor = $UI.Color2
            $htmlClass  = "green"
            $valueColor = $UI.ValueColor
            $valueClass = "yellow"
        }

        3{
            $prefix = "   └─ "
            $labelColor = $UI.Color3
            $htmlClass  = "blue"

            # Level 3: Value cùng màu với Label
            $valueColor = $UI.Color3
            $valueClass = "blue"
        }

    }

    if($Level -gt 1){

        $fmt = "{0,-$($UI.LabelWidth)}"
        $text = $fmt -f ($prefix + $Label)

        Write-Log ($text + " → ") $labelColor $htmlClass
        Write-Log "$Value`n" $valueColor $valueClass
    }

}

# 🏁 <<<--- END FUNCTION CHO THÔNG SỐ CẤU HÌNH MÁY TÍNH --->>>



# 🚩 <<<--- THU NHỎ CỬA SỔ HIỆN TẠI VÀ GỌI FILE .PS1 KHÁC --->>>

function Run-IT-xxx {
    param([string]$ScriptPath)
    [WinAPI]::ShowWindow($consoleHandle, 2) # Minimize
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Wait
    [WinAPI]::ShowWindow($consoleHandle, 9) # Restore
}

# 🏁 <<<--- END THU NHỎ CỬA SỔ HIỆN TẠI VÀ GỌI FILE .PS1 KHÁC --->>>

# 🚩 <<<--- FUNCTION HIỂN THỊ NỘI DUNG LÊN CONSOLE --->>>

function Show-Menu-IT {
    $script:ReportLines = @() # Reset báo cáo mỗi lần chạy

	Clear-Host

    # Trừ đi 1 để tránh việc bị rớt dòng (line-wrap) nếu Console xuất hiện thanh cuộn dọc
    $w = $host.UI.RawUI.WindowSize.Width - 1

    $m = " " # Margin lề trái cửa sổ 2 khoảng trắng

	# 🚩 <<<--- XUẤT THÔNG SỐ CẤU HÌNH MÁY TÍNH LÊN CONSOLE --->>>

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

    # Thêm Timestamp
	$RunTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss (dddd)"
	Write-Log "$m<<< $infoTitle >>>" "Cyan" "cyan"
	Write-Log "$mRun at: $RunTime" "DarkGray" "gray"
	Write-Log "`n"

	Write-Log "`n"

	# ===== MAINBOARD =====
    Show-Item 1 "MAINBOARD"
	Show-Item 2 "Brand (OEM)" $CS.Manufacturer
	Show-Item 2 "Manufacturer" $BB.Manufacturer
	Show-Item 2 "Product" $BB.Product
	Show-Item 2 "Model" $CS.Model
	Show-Item 2 "Serial" $BIOS.SerialNumber
	Show-Item 2 "BIOS ver" $BIOS.SMBIOSBIOSVersion

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

    Show-Item 1 "CPU"
	Show-Item 2 "Total CPU(s)" "$totalCPU"
	Show-Item 3 "Total RAM" "$totalRAM GB ($ramType)"

	Write-Log "`n"

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
            $label = if ($r.DeviceLocator) {

				($r.DeviceLocator -replace 'CPU\d+-','' -replace 'Node\d+-','' -replace 'DIMM','Slot' -replace ' ','')

			}
			else{

				"Slot$($trueUsedSlots+1)"

			}
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
        Show-Item 2 "CPU$cpuId" $cpuName
        Show-Item 3 "Total RAM$cpuId" "$cpuTotalGB GB | $cpuFreeSlots/$cpuTotalSlots Slots Free"

		foreach ($ro in $ramOutputLines) {
			Show-Item 3 $ro.Label $ro.Info
		}
        Write-Log "`n"

        $cpuIdx++ # Tăng tiến trình để đọc mảng Array tiếp theo cho CPU kế tiếp
    }

    # ===== STORAGE =====
	$disks = Get-CimInstance Win32_DiskDrive
	Show-Item 1 "STORAGE"

	$totalGB = [math]::Round(($disks | Measure-Object Size -Sum).Sum / 1GB)
	Show-Item 2 "Total Capacity" ("{0:N0} GB" -f $totalGB)

	$i = 1
	foreach ($d in $disks) {
		Show-Item 2 "Disk $i" "$($d.Model)"
		$i++
	}

	Write-Log "`n"

	# ===== DISPLAY ADAPTERS =====
	$GPU = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)

	Show-Item 1 "DISPLAY ADAPTERS"

	$i = 1
	foreach ($g in $GPU) {

		$name = $g.Name

		# VRAM
		$vram = if ($g.AdapterRAM -gt 0) {
			if ($g.AdapterRAM -ge 1GB) {
				"{0:N0} GB" -f ($g.AdapterRAM / 1GB)
			}
			else {
				"{0:N0} MB" -f ($g.AdapterRAM / 1MB)
			}
		}
		else {
			$null
		}

		# Resolution
		$res = if ($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution) {
			"$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution)"
		}

		if ($g.CurrentRefreshRate) {
			$res += " @$($g.CurrentRefreshRate)Hz"
		}

		# Ghép chuỗi
		$info = @($name)

		if ($vram) { $info += $vram }
		if ($res)  { $info += $res }

		$label = if ($GPU.Count -eq 1) { "Adapter" } else { "Adapter $i" }

		Show-Item 2 $label ($info -join " | ")

		$i++
	}

	Write-Log "`n"

	# ===== NETWORK ADAPTERS =====
	Show-Item 1 "NETWORK ADAPTERS"

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

		Show-Item 2 "$type Adapter" "$($n.InterfaceDescription) - $status | $speed"
		Show-Item 3 "MAC" $n.MacAddress
	}

	Write-Log "`n"

	# ===== CHECK LICENSED MICROSOFT =====
	
	# Truy vấn thông tin phần mềm Microsoft
	$RegOS = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
	
	$activeProduct = Get-CimInstance -Query @"
SELECT Name, Description, LicenseStatus,
GracePeriodRemaining, PartialProductKey
FROM SoftwareLicensingProduct
WHERE PartialProductKey IS NOT NULL
AND (Name LIKE 'Windows%' OR Name LIKE 'Office%')
"@
	
	# Phải khai $null thì mới trích 5 ký tự cuối key
	$partialKey = $null	
	
	# Lấy riêng Windows và Office
	$windows = $activeProduct | Where-Object {
		$_.Description -like "*Windows*"
	}

	$offices = $activeProduct | Where-Object {
		$_.Description -like "*Office*"
	}
		
	foreach ($product in $windows) {

		$partialKey = $product.PartialProductKey

		$statusText = switch ($product.LicenseStatus) {
			0 { "Unlicensed" }
			1 { "Licensed (Permanently Activated)" }
			2 { "OOB Grace Period" }
			3 { "OOT Grace Period" }
			4 { "Non-Genuine Grace Period" }
			5 { "Notification Mode" }
			6 { "Extended Grace Period" }
			default { "Unknown" }
		}

		$channel = switch -Regex ($product.Description) {
			'RETAIL'           { 'RETAIL'; break }
			'OEM'              { 'OEM'; break }
			'VOLUME_KMSCLIENT' { 'KMS'; break }
			'VOLUME_MAK'       { 'MAK'; break }
			default            { 'Unknown' }
		}

		Show-Item 1 "WINDOWS"
		Show-Item 2 "Edition" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | Build $($RegOS.CurrentBuild).$($RegOS.UBR)"
		Show-Item 2 "Status" "$channel | **** $partialKey | $statusText"
	}
	
	foreach ($product in $offices) {

		$partialKey = $product.PartialProductKey

		$statusText = switch ($product.LicenseStatus) {
			0 { "Unlicensed" }
			1 { "Licensed (Permanently Activated)" }
			2 { "OOB Grace Period" }
			3 { "OOT Grace Period" }
			4 { "Non-Genuine Grace Period" }
			5 { "Notification Mode" }
			6 { "Extended Grace Period" }
			default { "Unknown" }
		}

		$channel = ($product.Description -split ',\s*')[-1] -replace '\s+channel$',''

		Show-Item 1 "OFFICE"
		Show-Item 2 "Edition" $product.Name
		Show-Item 2 "Status" "$channel | **** $partialKey | $statusText"
	}
	
	
	
	
	
	
	
	
	
	
	
	
	
	# Show-Item 1 "WINDOWS"
	# Show-Item 2 "Edition" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | Build $($RegOS.CurrentBuild).$($RegOS.UBR)"
	# Show-Item 2 "Status" "$partialKey | $statusText"

	Write-Log "`n"

	# ===== COMPUTERNAME\USERNAME =====
    Show-Item 1 "COMPUTERNAME\USERNAME"

	Show-Item 2 "Current" "$env:COMPUTERNAME\$env:USERNAME"

    # ===== 113 LOCATION =====
    $loc113 = if ($script:IT113Script) {
        if ($script:IT113Script -match '^\\\\[^\\]+') { ($matches[0]) } # Lấy \\IT hoặc \\IT-E580
        elseif ($script:IT113Script -match '^[a-zA-Z]:') { ($matches[0]) } # Lấy DriverLetter:
        else { "Local/Unknown" }
    } else { "Offline" }

	Write-Log "`n"

	Show-Item 1 "113 LOCATION"

	if ($script:IT113Online.Count) {

		$online113 = $script:IT113Online | ForEach-Object {

			if ($_ -eq $loc113) {
				"$_ (in use)"
			}
			else {
				$_
			}

		}

		Show-Item 2 "Online" ($online113 -join " | ")

	}
	else {

		Show-Item 2 "Offline"

	}

	# 🏁 <<<--- END XUẤT THÔNG SỐ CẤU HÌNH MÁY TÍNH LÊN CONSOLE --->>>

	# 🚩 <<<--- XUẤT THÔNG SỐ CẤU HÌNH MÁY TÍNH RA HTML VÀO LOCAL và NETWORK --->>>

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
		margin: 0;
		padding: 8px;
		background: #0C0C0C;
		color: #CCCCCC;
		font-family: Consolas, "Lucida Console", monospace;
	}

	pre {
		margin: 0;
		white-space: pre;
		font-family: inherit;
		font-size: 13px;
		line-height: 1.15;
	}
    .green  { color:#16C60C; }
	.yellow { color:#F9F1A5; }
	.blue   { color:#3B78FF; }
	.cyan   { color:#61D6D6; }
	.gray   { color:#767676; }
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
# 🏁 <<<--- END XUẤT THÔNG SỐ CẤU HÌNH MÁY TÍNH RA HTML VÀO LOCAL và NETWORK --->>>

    Write-Host ("+" * $w) -ForegroundColor DarkGray
    Write-Host "$m" -NoNewline
    Write-Host "`nUser vui lòng nhập " -NoNewline;
    Write-Host "113" -ForegroundColor Yellow -NoNewline;
    Write-Host " để được hỗ trợ nhanh: " -NoNewline

	$topMenu = Read-Host

    switch ($topMenu) {
        "111" { GoTo-IT-111 }
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
