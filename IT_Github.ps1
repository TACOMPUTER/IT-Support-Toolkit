# File này dùng để test, chạy ok thì copy nội dung vào 'IT_Github.ps1' trên GitHub

# Trước tiên nó sẽ tự chép file 'IT_Github-call.exe' trên Github 'IT-Support-Toolkit/Launcher' vào 'C:\SW' và tạo shortcut trong Start

# Nếu PC chạy mà không thấy '\\IT' thì dùng VPN để lấy phần mềm



# 🚩 <<<--- THÔNG SỐ CỬA SỔ PS P.1 --->>>

param(
    [int]$PSWidth = 93,
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

$host.UI.RawUI.WindowTitle = "Running 'IT_Github.ps1' $adminText from 'Github'"

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



# 🚩 <<<--- KIỂM TRA / TẠO IT_Github-call.exe + SHORTCUT --->>>

$LauncherDir = "C:\SW"
$LauncherExe = Join-Path $LauncherDir "IT_Github-call.exe"

$LauncherURL = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/refs/heads/main/Launcher/IT_Github-call.exe"


# ==========================================================
# 1. Tạo C:\SW nếu chưa có
# ==========================================================

if (-not (Test-Path $LauncherDir)) {

    New-Item `
        -Path $LauncherDir `
        -ItemType Directory `
        -Force |
        Out-Null
}


# ==========================================================
# 2. Kiểm tra IT_Github-call.exe
#
# Có rồi  -> bỏ qua
# Chưa có -> tải từ GitHub
# ==========================================================

if (-not (Test-Path $LauncherExe)) {

    try {

        Invoke-WebRequest `
            -Uri $LauncherURL `
            -OutFile $LauncherExe `
            -UseBasicParsing `
            -ErrorAction Stop

    }
    catch {

        Write-Host ""
        Write-Host "Không thể tải IT_Github-call.exe từ GitHub." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


# ==========================================================
# 3. Xác định Start Menu
# ==========================================================

$StartMenuDir = Join-Path `
    $env:APPDATA `
    "Microsoft\Windows\Start Menu\Programs"


if (-not (Test-Path $StartMenuDir)) {

    New-Item `
        -Path $StartMenuDir `
        -ItemType Directory `
        -Force |
        Out-Null
}


# ==========================================================
# 4. Xóa tất cả Shortcut IT_Github-call*.lnk
# ==========================================================

$OldShortcuts = Get-ChildItem `
    -Path $StartMenuDir `
    -Filter "IT_Github-call*.lnk" `
    -File `
    -ErrorAction SilentlyContinue


foreach ($Shortcut in $OldShortcuts) {

    Remove-Item `
        -Path $Shortcut.FullName `
        -Force `
        -ErrorAction SilentlyContinue
}


# ==========================================================
# 5. Tạo lại Shortcut IT_Github-call.lnk
# ==========================================================

if (Test-Path $LauncherExe) {

    $ShortcutPath = Join-Path `
        $StartMenuDir `
        "IT_Github-call.lnk"


    $WshShell = New-Object -ComObject WScript.Shell

    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    $Shortcut.TargetPath       = $LauncherExe
    $Shortcut.IconLocation     = "$LauncherExe,0"
    $Shortcut.WorkingDirectory = $LauncherDir

    $Shortcut.Save()
}


# 🏁 <<<--- END KIỂM TRA / TẠO IT_Github-call.exe + SHORTCUT --->>>



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

	Write-Log "`n"

	# ===== COMPUTERNAME\USERNAME =====
    Show-Item 1 "COMPUTERNAME\USERNAME"

	Show-Item 2 "Current" "$env:COMPUTERNAME\$env:USERNAME"

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

    $Serial = if ($BIOS.SerialNumber) { $BIOS.SerialNumber } else { "NoSerial" }

	$CleanModel  = ($CS.Model -replace '[\\/:*?"<>|]', '').Trim()
	$CleanSerial = ($Serial -replace '[\\/:*?"<>|]', '').Trim()

	if ([string]::IsNullOrWhiteSpace($CleanModel))  { $CleanModel = "UnknownModel" }
	if ([string]::IsNullOrWhiteSpace($CleanSerial)) { $CleanSerial = "NoSerial" }

	$Content = $script:ReportLines -join ""
	$FileName = "{0}_{1}.html" -f $CleanModel, $CleanSerial
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
		if (-not (Test-Path -Path $LocalFolder -ErrorAction SilentlyContinue)) {
			New-Item -Path $LocalFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
		}

		$LocalFile = Join-Path $LocalFolder $FileName
		$HtmlContent | Set-Content -Path $LocalFile -Encoding UTF8 -Force -ErrorAction Stop

		Write-Host "`n[LOCAL] Da luu report tai: $LocalFile" -ForegroundColor DarkGray
	}
	catch {
		Write-Host "`n[LOCAL] WARNING → Khong the tao folder hoac ghi file tai C:\SW\Reports!" -ForegroundColor Yellow
		Write-Host "Chi tiet loi: $($_.Exception.Message)" -ForegroundColor DarkYellow
	}


	# --- 2. KIỂM TRA MẠNG VÀ ĐẨY TIẾP BẢN BACKUP LÊN SERVER ---
	$ServerHost  = "IT"
	$ShareRoot   = "\\$ServerHost\Guest"
	$NetworkPath = Join-Path $ShareRoot "Computer list"

	function Test-SmbPort {
		param(
			[string]$ComputerName,
			[int]$Port = 445,
			[int]$TimeoutMs = 1200
		)

		try {
			$client = New-Object System.Net.Sockets.TcpClient
			$async = $client.BeginConnect($ComputerName, $Port, $null, $null)
			$ok = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

			if (-not $ok) {
				$client.Close()
				return $false
			}

			$client.EndConnect($async)
			$client.Close()
			return $true
		}
		catch {
			return $false
		}
	}

	$isSmbOnline = Test-SmbPort -ComputerName $ServerHost

	if ($isSmbOnline) {
		try {
			if (-not (Test-Path -Path $ShareRoot -ErrorAction Stop)) {
				throw "Khong truy cap duoc share $ShareRoot"
			}

			if (-not (Test-Path -Path $NetworkPath -ErrorAction SilentlyContinue)) {
				New-Item -Path $NetworkPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
			}

			$NetworkFile = Join-Path $NetworkPath $FileName
			$HtmlContent | Set-Content -Path $NetworkFile -Encoding UTF8 -Force -ErrorAction Stop

			Write-Host "`n[ONLINE] Da luu them ban backup len server: $NetworkFile" -ForegroundColor Green
		}
		catch {
			Write-Host "`n[ONLINE] WARNING → Co thay server '$ServerHost' nhung folder/share dang chan quyen ghi file!" -ForegroundColor Red
			Write-Host "Chi tiet loi: $($_.Exception.Message)" -ForegroundColor DarkRed
		}
	}
	else {
		Write-Host "`n[OFFLINE] Khong thay SMB server '$ServerHost'. Bo qua luu ban backup tren server." -ForegroundColor DarkGray
		Write-Host "[HINT] Neu dang o ngoai mang cong ty, nhap VPN de ket noi roi chay lai 111." -ForegroundColor DarkGray
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
		"VPN" { GoTo-IT-VPN }
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

function GoTo-IT-VPN {
    # Load WinForms Assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # 2. Cấu hình Registry L2TP UDP Encapsulation (Nếu chưa có)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\PolicyAgent"
    try {
        $currentVal = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).AssumeUDPEncapsulationContextOnSendRule
        if ($currentVal -ne 2) {
            New-ItemProperty -Path $regPath -Name "AssumeUDPEncapsulationContextOnSendRule" -PropertyType DWORD -Value 2 -Force | Out-Null
        }
    } catch {}

    # 3. Khởi tạo Form chính (Tối ưu độ cao cho màn hình Laptop)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "TẠO / QUẢN LÝ VPN L2TP OVER IPSEC by TACOMPUTER"
    $form.Size = New-Object System.Drawing.Size(520, 650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedSingle"
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

    # Tiêu đề Form
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "TẠO / QUẢN LÝ VPN L2TP/IPsec DrayTek"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $lblTitle.Size = New-Object System.Drawing.Size(480, 25)
    $lblTitle.Location = New-Object System.Drawing.Point(10, 10)
    $lblTitle.TextAlign = "MiddleCenter"
    $form.Controls.Add($lblTitle)

    # Group: Nhập thông tin (Thu gọn khoảng cách)
    $grpInput = New-Object System.Windows.Forms.GroupBox
    $grpInput.Text = " Thông tin cấu hình "
    $grpInput.Location = New-Object System.Drawing.Point(15, 38)
    $grpInput.Size = New-Object System.Drawing.Size(475, 192)
    $form.Controls.Add($grpInput)

    # Các Field Nhập liệu cơ bản (Tất cả để trống mặc định)
    function Create-LabelInput ($parent, $text, $yPos, $isPass = $false) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $text
        $lbl.Location = New-Object System.Drawing.Point(15, $yPos)
        $lbl.Size = New-Object System.Drawing.Size(120, 23)
        $lbl.TextAlign = "MiddleLeft"
        $parent.Controls.Add($lbl)

        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Text = ""
        $txt.Location = New-Object System.Drawing.Point(140, $yPos)
        $txt.Size = New-Object System.Drawing.Size(315, 25)
        if ($isPass) { $txt.PasswordChar = '*' }
        $parent.Controls.Add($txt)
        return $txt
    }

    # 1. Tên VPN (Để trống)
    $txtVPNName = Create-LabelInput $grpInput "Tên VPN:" 22

    # 2. Máy chủ VPN (Tách 2 phần: TextBox bên trái + Dropdown đuôi tên miền bên phải)
    $lblServer = New-Object System.Windows.Forms.Label
    $lblServer.Text = "Máy chủ VPN:"
    $lblServer.Location = New-Object System.Drawing.Point(15, 55)
    $lblServer.Size = New-Object System.Drawing.Size(120, 23)
    $lblServer.TextAlign = "MiddleLeft"
    $grpInput.Controls.Add($lblServer)

    # TextBox nhập tên máy chủ
    $txtServer = New-Object System.Windows.Forms.TextBox
    $txtServer.Text = ""
    $txtServer.Location = New-Object System.Drawing.Point(140, 55)
    $txtServer.Size = New-Object System.Drawing.Size(190, 25)
    $grpInput.Controls.Add($txtServer)

    # Dropdown đuôi tên miền (Chừa vừa đủ cho đuôi tên miền)
    $cmbServerSuffix = New-Object System.Windows.Forms.ComboBox
    $cmbServerSuffix.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbServerSuffix.Location = New-Object System.Drawing.Point(335, 55)
    $cmbServerSuffix.Size = New-Object System.Drawing.Size(120, 25)
    [void]$cmbServerSuffix.Items.Add("")
    [void]$cmbServerSuffix.Items.Add(".ddns.net")
    [void]$cmbServerSuffix.Items.Add(".synology.me")
    [void]$cmbServerSuffix.Items.Add(".drayddns.com")
    $cmbServerSuffix.SelectedIndex = 0  # Mặc định dòng trống
    $grpInput.Controls.Add($cmbServerSuffix)

    # 3, 4, 5. Tài khoản, Mật khẩu, PSK (Tất cả để trống)
    $txtUser = Create-LabelInput $grpInput "Tài khoản VPN:" 88
    $txtPass = Create-LabelInput $grpInput "Mật khẩu:" 121 $true
    $txtPSK  = Create-LabelInput $grpInput "Pre Shared Key:" 154 $true

    # Nút Thao tác Cấu hình
    $btnCreate = New-Object System.Windows.Forms.Button
    $btnCreate.Text = "Tạo VPN"
    $btnCreate.Location = New-Object System.Drawing.Point(15, 238)
    $btnCreate.Size = New-Object System.Drawing.Size(105, 32)
    $btnCreate.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $btnCreate.ForeColor = [System.Drawing.Color]::White
    $btnCreate.FlatStyle = "Flat"
    $form.Controls.Add($btnCreate)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refresh VPN"
    $btnRefresh.Location = New-Object System.Drawing.Point(130, 238)
    $btnRefresh.Size = New-Object System.Drawing.Size(105, 32)
    $form.Controls.Add($btnRefresh)

    $btnOpenSettings = New-Object System.Windows.Forms.Button
    $btnOpenSettings.Text = "Mở Settings VPN"
    $btnOpenSettings.Location = New-Object System.Drawing.Point(245, 238)
    $btnOpenSettings.Size = New-Object System.Drawing.Size(125, 32)
    $form.Controls.Add($btnOpenSettings)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Xóa VPN"
    $btnDelete.Location = New-Object System.Drawing.Point(380, 238)
    $btnDelete.Size = New-Object System.Drawing.Size(110, 32)
    $btnDelete.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $form.Controls.Add($btnDelete)

    # Group: Quản lý VPN hiện có
    $grpManage = New-Object System.Windows.Forms.GroupBox
    $grpManage.Text = " Danh sách & Trạng thái VPN "
    $grpManage.Location = New-Object System.Drawing.Point(15, 278)
    $grpManage.Size = New-Object System.Drawing.Size(475, 210)
    $form.Controls.Add($grpManage)

    $lblCombo = New-Object System.Windows.Forms.Label
    $lblCombo.Text = "Danh sách VPN hiện có:"
    $lblCombo.Location = New-Object System.Drawing.Point(15, 22)
    $lblCombo.Size = New-Object System.Drawing.Size(200, 20)
    $grpManage.Controls.Add($lblCombo)

    $cmbVPNList = New-Object System.Windows.Forms.ComboBox
    $cmbVPNList.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbVPNList.Location = New-Object System.Drawing.Point(15, 43)
    $cmbVPNList.Size = New-Object System.Drawing.Size(440, 25)
    $grpManage.Controls.Add($cmbVPNList)

    # Labels Thông tin chi tiết
    $lblStatusTitle = New-Object System.Windows.Forms.Label
    $lblStatusTitle.Text = "Trạng thái:"
    $lblStatusTitle.Location = New-Object System.Drawing.Point(15, 78)
    $lblStatusTitle.Size = New-Object System.Drawing.Size(80, 20)
    $grpManage.Controls.Add($lblStatusTitle)

    $lblStatusValue = New-Object System.Windows.Forms.Label
    $lblStatusValue.Text = "Chưa rõ"
    $lblStatusValue.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblStatusValue.ForeColor = [System.Drawing.Color]::Gray
    $lblStatusValue.Location = New-Object System.Drawing.Point(100, 78)
    $lblStatusValue.Size = New-Object System.Drawing.Size(350, 20)
    $grpManage.Controls.Add($lblStatusValue)

    $lblServerTitle = New-Object System.Windows.Forms.Label
    $lblServerTitle.Text = "Máy chủ:"
    $lblServerTitle.Location = New-Object System.Drawing.Point(15, 100)
    $lblServerTitle.Size = New-Object System.Drawing.Size(80, 20)
    $grpManage.Controls.Add($lblServerTitle)

    $lblServerValue = New-Object System.Windows.Forms.Label
    $lblServerValue.Text = "---"
    $lblServerValue.Location = New-Object System.Drawing.Point(100, 100)
    $lblServerValue.Size = New-Object System.Drawing.Size(350, 20)
    $grpManage.Controls.Add($lblServerValue)

    $lblTypeTitle = New-Object System.Windows.Forms.Label
    $lblTypeTitle.Text = "Loại:"
    $lblTypeTitle.Location = New-Object System.Drawing.Point(15, 122)
    $lblTypeTitle.Size = New-Object System.Drawing.Size(80, 20)
    $grpManage.Controls.Add($lblTypeTitle)

    $lblTypeValue = New-Object System.Windows.Forms.Label
    $lblTypeValue.Text = "L2TP/IPsec"
    $lblTypeValue.Location = New-Object System.Drawing.Point(100, 122)
    $lblTypeValue.Size = New-Object System.Drawing.Size(350, 20)
    $grpManage.Controls.Add($lblTypeValue)

    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Text = "Kết nối VPN"
    $btnConnect.Location = New-Object System.Drawing.Point(15, 155)
    $btnConnect.Size = New-Object System.Drawing.Size(440, 36)
    $btnConnect.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    $btnConnect.ForeColor = [System.Drawing.Color]::White
    $btnConnect.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnConnect.FlatStyle = "Flat"
    $grpManage.Controls.Add($btnConnect)

    # Group: Nhật ký (Thu gọn khoảng 5 dòng + Thanh cuộn ScrollBar)
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Text = "Nhật ký:"
    $lblLog.Location = New-Object System.Drawing.Point(15, 496)
    $lblLog.Size = New-Object System.Drawing.Size(100, 18)
    $form.Controls.Add($lblLog)

    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Location = New-Object System.Drawing.Point(15, 516)
    $txtLog.Size = New-Object System.Drawing.Size(475, 80) # Khoảng 5 dòng
    $txtLog.ReadOnly = $true
    $txtLog.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::ForcedVertical
    $txtLog.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $txtLog.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
    $form.Controls.Add($txtLog)

    # -------------------------------------------------------------------
    # LOGIC VÀ XỬ LÝ SỰ KIỆN
    # -------------------------------------------------------------------

    function Write-VPNLog ($message) {
        $time = Get-Date -Format "HH:mm:ss"
        $txtLog.AppendText("[$time] $message`n")
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }

    function Refresh-VPNList ($selectName = $null) {
        $cmbVPNList.Items.Clear()
        $vpns = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
    
        if ($vpns) {
            foreach ($v in $vpns) {
                [void]$cmbVPNList.Items.Add($v.Name)
            }
            if ($selectName -and $cmbVPNList.Items.Contains($selectName)) {
                $cmbVPNList.SelectedItem = $selectName
            } else {
                $cmbVPNList.SelectedIndex = 0
            }
        } else {
            $lblStatusValue.Text = "Không có VPN"
            $lblStatusValue.ForeColor = [System.Drawing.Color]::Gray
            $lblServerValue.Text = "---"
            $btnConnect.Text = "Kết nối VPN"
            $btnConnect.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
        }
    }

    function Update-SelectedVPNInfo {
        $selected = $cmbVPNList.SelectedItem
        if (-not $selected) { return }

        $vpn = Get-VpnConnection -Name $selected -AllUserConnection -ErrorAction SilentlyContinue
        if ($vpn) {
            $lblServerValue.Text = $vpn.ServerAddress
            $lblTypeValue.Text = "$($vpn.TunnelType) (PSK)"

            if ($vpn.ConnectionStatus -eq "Connected") {
                $lblStatusValue.Text = "Connected"
                $lblStatusValue.ForeColor = [System.Drawing.Color]::Green
                $btnConnect.Text = "Ngắt kết nối VPN"
                $btnConnect.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
            } else {
                $lblStatusValue.Text = "Disconnected"
                $lblStatusValue.ForeColor = [System.Drawing.Color]::Red
                $btnConnect.Text = "Kết nối VPN"
                $btnConnect.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
            }
        }
    }

    # Sự kiện khi thay đổi VPN trong Dropdown
    $cmbVPNList.Add_SelectedIndexChanged({
        Update-SelectedVPNInfo
    })

    # Nút Refresh VPN
    $btnRefresh.Add_Click({
        Refresh-VPNList $cmbVPNList.SelectedItem
        Write-VPNLog "Đã cập nhật danh sách VPN."
    })

    # Nút Mở Settings VPN
    $btnOpenSettings.Add_Click({
        Start-Process "ms-settings:network-vpn"
        Write-VPNLog "Đã mở Settings > VPN."
    })

    # Nút Tạo VPN
    $btnCreate.Add_Click({
        $name = $txtVPNName.Text.Trim()
        $serverInput = $txtServer.Text.Trim()
        $suffix = $cmbServerSuffix.SelectedItem
        $server = "$serverInput$suffix"

        $user = $txtUser.Text.Trim()
        $pass = $txtPass.Text
        $psk = $txtPSK.Text

        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($serverInput) -or [string]::IsNullOrWhiteSpace($psk)) {
            [System.Windows.Forms.MessageBox]::Show("Vui lòng nhập đầy đủ Tên VPN, Máy chủ VPN và Pre Shared Key!", "Thiếu thông tin", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        Write-VPNLog "Đang tạo VPN '$name' ($server)..."

        # Xóa VPN cũ nếu trùng tên
        Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $name } | ForEach-Object {
            Remove-VpnConnection -Name $_.Name -AllUserConnection -Force -ErrorAction SilentlyContinue
        }

        try {
            # Tạo kết nối VPN
            Add-VpnConnection -Name $name `
                              -ServerAddress $server `
                              -TunnelType L2tp `
                              -L2tpPsk $psk `
                              -AuthenticationMethod MSChapv2 `
                              -EncryptionLevel Optional `
                              -SplitTunneling:$false `
                              -RememberCredential `
                              -AllUserConnection `
                              -Force -ErrorAction Stop

            # Lưu tài khoản đăng nhập vào Windows Credential
            if (-not [string]::IsNullOrWhiteSpace($user) -and -not [string]::IsNullOrWhiteSpace($pass)) {
                cmdkey /generic:"$server" /user:"$user" /pass:"$pass" | Out-Null
            }

            Write-VPNLog "Đã tạo VPN $name thành công."
            Refresh-VPNList $name
            [System.Windows.Forms.MessageBox]::Show("Tạo VPN '$name' thành công!", "Thông báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            Write-VPNLog "Lỗi tạo VPN: $_"
            [System.Windows.Forms.MessageBox]::Show("Có lỗi xảy ra khi tạo VPN: $_", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    # Nút Xóa VPN
    $btnDelete.Add_Click({
        $selected = $cmbVPNList.SelectedItem
        if (-not $selected) {
            [System.Windows.Forms.MessageBox]::Show("Vui lòng chọn VPN cần xóa từ danh sách!", "Thông báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show("Bạn có chắc chắn muốn xóa VPN '$selected'?", "Xác nhận xóa", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-VPNLog "Đang xóa VPN '$selected'..."

            # Ngắt kết nối nếu đang kết nối
            rasdial /disconnect | Out-Null

            # Lấy server để xóa cmdkey
            $vpn = Get-VpnConnection -Name $selected -AllUserConnection -ErrorAction SilentlyContinue
            if ($vpn) {
                cmdkey /delete:"$($vpn.ServerAddress)" 2>$null | Out-Null
            }

            # Xóa VPN
            Remove-VpnConnection -Name $selected -AllUserConnection -Force -ErrorAction SilentlyContinue
        
            Write-VPNLog "Đã xóa VPN '$selected'."
            Refresh-VPNList
        }
    })

    # Nút Kết nối / Ngắt kết nối VPN
    $btnConnect.Add_Click({
        $selected = $cmbVPNList.SelectedItem
        if (-not $selected) { return }

        $vpn = Get-VpnConnection -Name $selected -AllUserConnection -ErrorAction SilentlyContinue
        if (-not $vpn) { return }

        if ($vpn.ConnectionStatus -eq "Connected") {
            Write-VPNLog "Đang ngắt kết nối VPN '$selected'..."
            rasdial "$selected" /disconnect | Out-Null
            Start-Sleep -Seconds 1
            Update-SelectedVPNInfo
            Write-VPNLog "Đã ngắt kết nối."
		
    		Write-VPNLog "Đang kiểm tra kết nối tới 172.16.8.8..."

    		if (Test-Connection -ComputerName "172.16.8.8" -Count 1 -Quiet)
    		{
    			Write-VPNLog "Ping 172.16.8.8 : Thành công"
    		}
    		else
    		{
    			Write-VPNLog "Ping 172.16.8.8 : Không phản hồi"
    		}
        } else {
            Write-VPNLog "Đang kết nối tới VPN '$selected'..."
        
            # Lấy thông tin user/pass từ input nếu trùng tên VPN, hoặc gọi rasdial dùng Saved Credential
            $user = $txtUser.Text.Trim()
            $pass = $txtPass.Text

            if ($txtVPNName.Text.Trim() -eq $selected -and -not [string]::IsNullOrWhiteSpace($user) -and -not [string]::IsNullOrWhiteSpace($pass)) {
                $res = rasdial "$selected" "$user" "$pass"
            } else {
                $res = rasdial "$selected"
            }

            if ($LASTEXITCODE -eq 0) {
                Write-VPNLog "Kết nối thành công!"
                Update-SelectedVPNInfo
			
    			Write-VPNLog "Đang kiểm tra kết nối tới 172.16.8.8..."

    			if (Test-Connection -ComputerName "172.16.8.8" -Count 1 -Quiet)
    			{
    				Write-VPNLog "Ping 172.16.8.8 : Thành công"
    			}
    			else
    			{
    				Write-VPNLog "Ping 172.16.8.8 : Không phản hồi"
    			}
            } else {
                Write-VPNLog "Kết nối thất bại!"
                [System.Windows.Forms.MessageBox]::Show("Kết nối VPN thất bại. Vui lòng kiểm tra lại tài khoản/mật khẩu hoặc kết nối mạng!", "Lỗi kết nối", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })

    # Khởi tạo giao diện lần đầu
    $form.Add_Shown({
        Write-VPNLog "Sẵn sàng"
        Refresh-VPNList
    })

    # Hiển thị Form
    [void]$form.ShowDialog()
}

while ($true) {
    Show-Menu-IT
}
