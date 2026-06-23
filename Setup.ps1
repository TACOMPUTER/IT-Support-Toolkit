# Setup.ps1 - Deploy bộ tool IT từ GitHub Public Repository
# Chạy với quyền Administrator

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ĐƯỜNG DẪN ĐÍCH
$TargetDir = "C:\SW\cmd-Powershell"

if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

Write-Host "📥 Dang tai bo cong cu IT Support tu GitHub..." -ForegroundColor Cyan

# Link tải zip công khai không cần token
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
    $SourcePath = Join-Path $RepoFolder.FullName "cmd-Powershell"
    if (Test-Path $SourcePath) {
        Copy-Item -Path "$SourcePath\*" -Destination $TargetDir -Recurse -Force
    } else {
        Write-Host "❌ Loi: Khong tim thay thu mục 'cmd-Powershell' trong goi giai nen!" -ForegroundColor Red
        exit
    }
}

# Dọn dẹp sạch sẽ file tạm
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

# KHỞI CHẠY TOOL CHÍNH
$LaunchFile = Join-Path $TargetDir "IT_Github.ps1"
if (Test-Path $LaunchFile) {
    Write-Host "🚀 Khoi chay Tool..." -ForegroundColor Green
    Set-Location $TargetDir
    & ".\IT_Github.ps1"
} else {
    Write-Host "❌ Loi: Khong tim thay file IT_Github.ps1 tai $TargetDir" -ForegroundColor Red
}
