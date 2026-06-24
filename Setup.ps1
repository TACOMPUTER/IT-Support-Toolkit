# Setup.ps1 - Deploy bộ tool IT từ GitHub Public Repository
# Chạy với quyền Administrator

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ĐƯỜNG DẪN ĐÍCH - Đưa thẳng ra C:\SW, không đẻ thêm thư mục con cmd-Powershell
$TargetDir = "C:\SW"

# Dọn dẹp an toàn (Tránh xóa các file quan trọng khác nếu có trong C:\SW, chỉ xóa các folder core của tool)
$CorePaths = @("IT", "Reports", "IT_Github.ps1", "variable_IT.ps1")
foreach ($cp in $CorePaths) {
    $FullPath = Join-Path $TargetDir $cp
    if (Test-Path $FullPath) { Remove-Item $FullPath -Recurse -Force -ErrorAction SilentlyContinue }
}
if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }

Write-Host "📥 Dang tai bo cong cu IT Support tu GitHub..." -ForegroundColor Cyan

$zipUrl = "https://github.com/TACOMPUTER/IT-Support-Toolkit/archive/refs/heads/main.zip"
$zipFile = Join-Path $env:TEMP "it_toolkit.zip"

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -ErrorAction Stop
} catch {
    Write-Host "❌ Loi: Khong the tai file tu GitHub. Kiem tra lai ket noi mang!`n$($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "📦 Dang giai nen va cau truc lai thu muc..." -ForegroundColor Cyan
$ExtractPath = Join-Path $env:TEMP "it_extracted"
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

Expand-Archive -Path $zipFile -DestinationPath $ExtractPath -Force

$RepoFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1

if ($RepoFolder) {
    # Lấy nội dung bên trong thư mục 'cmd-Powershell' từ gói giải nén
    $SourcePath = Join-Path $RepoFolder.FullName "cmd-Powershell"
    if (Test-Path $SourcePath) {
        # Copy TOÀN BỘ file và folder con thẳng vào C:\SW
        Copy-Item -Path "$SourcePath\*" -Destination $TargetDir -Recurse -Force
    } else {
        Write-Host "❌ Loi: Khong tim thay thu muc 'cmd-Powershell' trong package GitHub!" -ForegroundColor Red
        exit
    }
}

# Dọn dẹp sạch sẽ file tạm
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

# KHỞI CHẠY TOOL CHÍNH TẠI GỐC C:\SW
$LaunchFile = Join-Path $TargetDir "IT_Github.ps1"
if (Test-Path $LaunchFile) {
    Write-Host "🚀 Khoi chay Tool..." -ForegroundColor Green
    Set-Location $TargetDir
    & ".\IT_Github.ps1"
} else {
    Write-Host "❌ Loi: Khong tim thay file IT_Github.ps1 tai $TargetDir" -ForegroundColor Red
}
