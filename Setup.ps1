# Setup.ps1 - Deploy bộ tool IT từ GitHub Public Repository
# Chạy với quyền Administrator

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ĐƯỜNG DẪN ĐÍCH
$TargetDir = "C:\SW\cmd-Powershell"

if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

Write-Host "📥 Đang tải bộ công cụ IT Support từ GitHub..." -ForegroundColor Cyan

# Link tải zip công khai sạch, không cần token lằng nhằng
$zipUrl = "https://github.com/TACOMPUTER/IT-Support-Toolkit/archive/refs/heads/main.zip"
$zipFile = Join-Path $env:TEMP "it_toolkit.zip"

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -ErrorAction Stop
} catch {
    Write-Host "❌ Lỗi: Không thể tải file từ GitHub. Kiểm tra lại kết nối mạng!`n$($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "📦 Đang giải nén và cấu trúc lại thư mục..." -ForegroundColor Cyan
$ExtractPath = Join-Path $env:TEMP "it_extracted"
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

Expand-Archive -Path $zipFile -DestinationPath $ExtractPath -Force

$RepoFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1

if ($RepoFolder) {
    $SourcePath = Join-Path $RepoFolder.FullName "cmd-Powershell"
    if (Test-Path $SourcePath) {
        Copy-Item -Path "$SourcePath\*" -Destination $TargetDir -Recurse -Force
    } else {
        Write-Host "❌ Lỗi: Không tìm thấy thư mục 'cmd-Powershell' trong gói giải nén!" -ForegroundColor Red
        exit
    }
}

# Dọn dẹp sạch sẽ file tạm
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

# KHỞI CHẠY TOOL CHÍNH
$LaunchFile = Join-Path $TargetDir "IT_Github.ps1"
if (Test-Path $LaunchFile) {
    Write-Host "🚀 Khởi chạy Tool..." -ForegroundColor Green
    Set-Location $TargetDir
    & ".\IT_Github.ps1"
} else {
    Write-Host "❌ Lỗi: Không tìm thấy file IT_Github.ps1 tại $TargetDir" -ForegroundColor Red
}
