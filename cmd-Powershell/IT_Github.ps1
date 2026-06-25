param(
    [int]$PSWidth = 80,
    [int]$PSHeight = 55,
    [int]$PosX = 0,
    [int]$PosY = 0,
    [bool]$SkipAdminCheck = $false
)

# --- KHỞI TẠO CẤU HÌNH ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$SystemDriveSW   = "C:\SW"
$LocalScriptPath = Join-Path $SystemDriveSW "IT_Github-call.ps1"
$DestExePath     = Join-Path $SystemDriveSW "IT_Github.exe"
$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExeSourcePath   = Join-Path $ScriptDir "IT_Github.exe"

# 1. QUY TẮC 3 FILE: TỰ SAO CHÉP VÀO C:\SW
if ($MyInvocation.MyCommand.Path -notlike "$SystemDriveSW\*") {
    if (-not (Test-Path $SystemDriveSW)) { New-Item -Path $SystemDriveSW -ItemType Directory -Force | Out-Null }
    $SourceCallScript = Join-Path $ScriptDir "IT_Github-call.ps1"
    if (Test-Path $SourceCallScript) { Copy-Item $SourceCallScript $LocalScriptPath -Force }
    if (Test-Path $ExeSourcePath) { Copy-Item $ExeSourcePath $DestExePath -Force }
    Write-Host "[SYSTEM] Đã sao chép file vào $SystemDriveSW. Khởi động lại..." -ForegroundColor Green
    Start-Process -FilePath $DestExePath
    exit
}

# --- CÁC HÀM MENU CON (IT-113) ---
function Show-SubSubMenu-WindowsSetup {
    $subSubChoice = ""
    while ($subSubChoice -ne "0") {
        Clear-Host
        Write-Host "=== CÀI ĐẶT WINDOWS (LOCAL MANAGER) ===" -ForegroundColor Cyan
        Write-Host "1. Account Local Manager - Add 'Guest', Move Users" -ForegroundColor Yellow
        Write-Host "2. Windows Firewall Control" -ForegroundColor Magenta
        Write-Host "3. Check Activation status" -ForegroundColor Yellow
        Write-Host "4. Change Account Picture & Lock Screen" -ForegroundColor Magenta
        Write-Host "5. Windows update - Mic & Location" -ForegroundColor Yellow
        Write-Host "6. Clipboard History, Hosts" -ForegroundColor Magenta
        Write-Host "7. BIOS, Drivers update" -ForegroundColor Yellow
        Write-Host "8. Power, Network, Volume" -ForegroundColor Magenta
        Write-Host "0. Quay lại Menu Deployment" -ForegroundColor Gray
        $subSubChoice = Read-Host "`nNhập lựa chọn (1-8 hoặc 0)"
        switch ($subSubChoice) {
            '1' { Write-Host "Đang chạy Account Manager..." -ForegroundColor Green; Start-Sleep 1 }
            '0' { return }
            default { Write-Host "Lựa chọn không hợp lệ!" -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}

function Show-Deployment-Menu {
    $subChoice = ""
    while ($subChoice -ne "0") {
        Clear-Host
        Write-Host "=== TRIỂN KHAI WINDOWS (DEPLOYMENT) ===" -ForegroundColor Cyan
        Write-Host "1. Vừa cài đặt xong Windows" -ForegroundColor Yellow
        Write-Host "2. MS Office và phần mềm cơ bản" -ForegroundColor Magenta
        Write-Host "3. Phần mềm SW2" -ForegroundColor Yellow
        Write-Host "4. Update các máy Deployment" -ForegroundColor Magenta
        Write-Host "0. Quay lại Menu trước" -ForegroundColor Gray
        $subChoice = Read-Host "`nNhập lựa chọn (1-4 hoặc 0)"
        switch ($subChoice) {
            '1' { Show-SubSubMenu-WindowsSetup }
            '0' { return }
            default { Write-Host "Lựa chọn không hợp lệ!" -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}

# --- MENU CHÍNH ---
function Show-Menu-IT {
    Clear-Host
    Write-Host "=== KHU VỰC IT-113 (RAM MODE) ===" -ForegroundColor Cyan
    Write-Host "1. Triển khai 'Windows Deployment'" -ForegroundColor Yellow
    Write-Host "2. Network, Firmware" -ForegroundColor Magenta
    Write-Host "3. Tiện ích SW2" -ForegroundColor Yellow
    Write-Host "111. Khởi động lại hệ thống" -ForegroundColor Gray
    Write-Host "0. Thoát" -ForegroundColor Gray
    
    $choice = Read-Host "`nNhập lựa chọn"
    switch ($choice) {
        '1' { Show-Deployment-Menu }
        '111' { 
            Write-Host "Đang khởi động lại..." -ForegroundColor Cyan
            # Lấy đường dẫn exe cha để khởi động lại
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $PID" | Get-CimAssociatedInstance -Association Win32_ProcessParent
            if ($parent.ExecutablePath) { Start-Process -FilePath $parent.ExecutablePath }
            exit 
        }
        '0' { exit }
    }
}

# --- VÒNG LẶP CHÍNH ---
while ($true) { Show-Menu-IT }
