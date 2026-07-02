param(
    [int]$PSWidth = 90,
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



# 🚩 <<<--- KHU VỰC KHAI BÁO BIẾN SỬ DỤNG TOÀN BỘ SCRIPT ---->>>
# 1. Xác định vị trí gốc của file đang chạy (IT-113.ps1)
# $PSScriptRoot là biến tự động của PowerShell chứa đường dẫn thư mục chứa file đang chạy
$IT113Script = $PSScriptRoot 

# 2. $LibScript: Thoát ra 1 cấp folder (IT-113) và vào 'Library'
# Split-Path -Parent sẽ lấy thư mục cha của IT-113
$LibScript = Join-Path (Split-Path $IT113Script -Parent) "Library"

# 3. $ITScriptRoot: Vị trí folder 'cmd-Powershell' (Thoát ra 2 cấp: IT-113 -> IT -> cmd-Powershell)
$ITScriptRoot = Split-Path (Split-Path $IT113Script -Parent) -Parent

# 4. $IT115Script: Folder 'IT-115' (cùng cấp với IT-113)
$IT115Script = Join-Path (Split-Path $IT113Script -Parent) "IT-115"




	# thư mục software: thư mục gốc chứa file IT.ps1 (có thể là 'local' hoặc 'unc: \\server\share')
if ($PSScriptRoot) {
    $BasePath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
else {
    # chạy từ GitHub → fallback về local runtime
    $BasePath = "C:\SW"
}

$SourceSW = $BasePath

	# thư mục software2
		# 1. nếu nằm trong onedrive\tacomputer\software
if ($SourceSW -match "OneDrive\\TACOMPUTER\\Software$") {
    $drive = ([System.IO.Path]::GetPathRoot($SourceSW))
    $SourceSW2 = Join-Path $drive "Software2"
}
		# 2. nếu là driveletter:\software
elseif ($SourceSW -match "^[A-Z]:\\Software$") {
    $SourceSW2 = $SourceSW + "2"
}
		# 3. nếu là \\network\software
elseif ($SourceSW -match "^\\\\.*\\Software$") {
    $SourceSW2 = $SourceSW + "2"
}

	# thư mục dùng để lưu shortcut và file cấu hình
$SystemDriveSW = "C:\SW"

	# file thực thi chính dùng để chạy tool
$ExePath = Join-Path $ITScriptRoot "IT.exe"

	# shortcut đặt tại c:\sw
$SystemDriveSWlnk = "$SystemDriveSW\IT.exe.lnk"

	# lấy computername\username của user đang đăng nhập
$currentUser = "$env:COMPUTERNAME\$env:USERNAME"

	# đường dẫn start menu (dùng biến môi trường để tránh lỗi profile)
$StartMenuProgramsPath = [Environment]::GetFolderPath("Programs")
$StartMenuShortPath = $StartMenuProgramsPath.Substring(
    $StartMenuProgramsPath.IndexOf("\Start Menu")
)

	# shortcut đặt trong start menu
$StartMenuProgramslnk = "$StartMenuProgramsPath\IT.exe.lnk"

	# expand đường dẫn thật từ %appdata%
$ExpandedStartMenuPath = [Environment]::ExpandEnvironmentVariables($StartMenuProgramsPath)

	# expand đường dẫn shortcut start menu
$ExpandedStartMenuLnk = [Environment]::ExpandEnvironmentVariables($StartMenuProgramslnk)

	# file export chứa các biến path dùng cho script khác
$exportvariablePath = "$SystemDriveSW\variable_IT.ps1"

# 🏁 <<<--- KẾT THÚC KHU VỰC KHAI BÁO BIẾN ---->>>



# 🚩 <<<--- XUẤT CÁC BIẾN RA FILE 'VARIABLE_IT.PS1' --->>>

	# xóa file cũ nếu có
if (Test-Path $exportvariablePath) {
    Remove-Item $exportvariablePath -Force
    Write-Host "Đã xóa file cũ: $exportvariablePath`n" -ForegroundColor Yellow
}
	# hàm kiểm tra chuỗi giống đường dẫn
function Is-PathLike($str) {
    return ($str -is [string]) -and (
        $str -match '^[a-zA-Z]:\\' -or
        $str -match '^\\\\' -or
        $str -match '\\.+\\' -or
        $str -match '\\$'
    )
}
	# danh sách biến hệ thống cần loại trừ
$excludedNames = @(
    'HOME', 'PSHOME', 'PROFILE', 'PID', 'ExecutionContext', 'Host', 'ShellId',
    'env', 'args', 'Error', 'MyInvocation', 'PSBoundParameters', 'PSCommandPath',
    'PSCulture', 'PSEdition', 'PSScriptRoot', 'PSUICulture', 'PSVersionTable',
    'input', 'output', 'null'
)
	# lấy các biến hợp lệ
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
	# ghi ra file mới
# Tạo thư mục nếu chưa có
if (-not (Test-Path $SystemDriveSW)) {
    New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null
}

# Sau đó ghi file
$lines | Set-Content $exportvariablePath

# 🏁 <<<--- XUẤT CÁC BIẾN RA FILE 'VARIABLE_IT.PS1' --->>>

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

# ==========================================================
# XÁC ĐỊNH VỊ TRÍ IT-113.ps1 (THEO THỨ TỰ ƯU TIÊN)
#
# 1. D:\~H:\OneDrive\TACOMPUTER\Software\OS Tools\cmd-Powershell\IT\IT-113
# 2. \\IT\Software\OS Tools\cmd-Powershell\IT\IT-113
# 3. \\IT-E580\Software\OS Tools\cmd-Powershell\IT\IT-113
# 4. Tất cả ổ USB (Flash/HDD/SSD)
# ==========================================================

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

$script:ReportLines = @()
function Write-Log ($text, $color, $htmlClass = "") {
    if ($color) { Write-Host $text -ForegroundColor $color -NoNewline } else { Write-Host $text -NoNewline }
    $cleanText = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    if ($htmlClass) { $script:ReportLines += "<span class='$htmlClass'>$cleanText</span>" } else { $script:ReportLines += "$cleanText" }
}

$UI = @{
    LabelWidth = 22	# Đẩy mũi tên di chuyển

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
	Write-Log "`n"

	Write-Log "`n"

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
    Show-Item 1 "WINDOWS"

	# Show-Item 2 "Edition" "$($RegOS.ProductName) | $($RegOS.DisplayVersion)"
	# Show-Item 2 "Build" "$($RegOS.CurrentBuild).$($RegOS.UBR)"
	
	Show-Item 2 "Edition" "$($RegOS.ProductName) | $($RegOS.DisplayVersion) | Build $($RegOS.CurrentBuild).$($RegOS.UBR)"

	Write-Log "`n"
    Show-Item 1 "COMPUTERNAME\USERNAME"

	Show-Item 2 "Current" "$env:COMPUTERNAME\$env:USERNAME"

    # Xác định vị trí 113 để hiển thị
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
