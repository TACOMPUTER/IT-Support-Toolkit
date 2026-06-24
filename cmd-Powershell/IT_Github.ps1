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
        $RamDetails = "-> $size GB  $($ram.Speed) MHz  |  $manufacturer  |  $partNumber"
        Show-SubLine $slot $RamDetails
        $i++; $trueUsedSlots++
    }
    $TotalSlots = if ($arrays) { @($arrays)[0].MemoryDevices } else { 2 }
    Show-SubLine "Used Slots" "-> $trueUsedSlots/$TotalSlots"

    # --- PHẦN Ổ CỨNG ---
    $disks = Get-CimInstance Win32_DiskDrive
    $totalDisk = "{0:N0}" -f (($disks | Measure-Object Size -Sum).Sum / 1GB)
    Show-Line "Storage (Total)" "$totalDisk GB"
    $i = 1; foreach ($disk in $disks) { Show-SubLine "Disk $i" ("-> {0} | {1:N0} GB" -f $disk.Model, ($disk.Size / 1GB)); $i++ }

    # --- PHẦN ĐỒ HỌA ---
    $vgaCount = 0; $gpuCount = 0
    foreach ($g in $GPU) { if ($g.Name -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX") { $vgaCount++ } else { $gpuCount++ } }
    Show-Line "Graphics" ("$vgaCount VGA / $gpuCount GPU")
    foreach ($g in $GPU) { Show-SubLine "GPU_Info" ("-> " + $g.Name) }
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
    if (Test-Path $HtmlFile) { 
        Remove-Item -Path $HtmlFile -Force -ErrorAction SilentlyContinue 
    }
    $HtmlContent | Set-Content $HtmlFile -Force

    $ServerHost = "IT"
    $NetworkFolder = "\\$ServerHost\Guest\Computer list"

    if (Test-Connection -ComputerName $ServerHost -Count 1 -Quiet) {
        try {
            if (-not (Test-Path $NetworkFolder)) { 
                New-Item -Path $NetworkFolder -ItemType Directory -Force | Out-Null 
            }
            $NetworkFile = Join-Path $NetworkFolder $FileNameReport
            if (Test-Path $NetworkFile) { 
                Remove-Item -Path $NetworkFile -Force -ErrorAction SilentlyContinue 
            }
            $HtmlContent | Set-Content $NetworkFile -Force
            Write-Host "🚀 Online mode: Da xoa file cu va cap nhat bao cao moi len Server ($ServerHost)" -ForegroundColor Cyan
        } catch {
            Write-Host "⚠️ Offline mode: Ket noi Server OK nhung folder mang chan quyen ghi/xoa!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️ Offline mode: Khong thay Server '$ServerHost', da cap nhat bao cao tai local C:\SW\Reports" -ForegroundColor DarkGray
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
