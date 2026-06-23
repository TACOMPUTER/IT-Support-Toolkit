# Setup.ps1 - Deploy bộ tool IT từ GitHub Private Repository (Cấu trúc phẳng mới)
# Chạy với quyền Administrator

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# KHAI BÁO TOKEN BẢO MẬT (Do Repo là Private)
$PATToken = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 

# ĐƯỜNG DẪN ĐÍCH
$TargetDir = "C:\SW\cmd-Powershell"

if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

Write-Host "📥 Đang tải bộ công cụ IT Support từ GitHub..." -ForegroundColor Cyan

$zipUrl = "https://api.github.com/repos/TACOMPUTER/IT-Support-Toolkit/zipball/main"
$zipFile = "$env:TEMP\it_toolkit.zip"

$headers = @{
    Authorization = "Bearer $PATToken"
    Accept        = "application/vnd.github+json"
}

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -Headers $headers -ErrorAction Stop
} catch {
    Write-Host "❌ Lỗi: Không thể tải file từ GitHub. Kiểm tra lại PAT Token!`n$($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "📦 Đang giải nén và cấu trúc lại thư mục..." -ForegroundColor Cyan
$ExtractPath = "$env:TEMP\it_extracted"
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

Expand-Archive -Path $zipFile -DestinationPath $ExtractPath -Force

# Tìm thư mục gốc do GitHub tự sinh ra khi giải nén
$RepoFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1

if ($RepoFolder) {
    # Đường dẫn nguồn hiện tại đã bỏ Software/OS Tools, chỉ còn đi thẳng vào cmd-Powershell
    $SourcePath = Join-Path $RepoFolder.FullName "cmd-Powershell"
    
    if (Test-Path $SourcePath) {
        # Copy toàn bộ nội dung bên trong cmd-Powershell về C:\SW\cmd-Powershell
        Copy-Item -Path "$SourcePath\*" -Destination $TargetDir -Recurse -Force
    } else {
        Write-Host "❌ Lỗi: Không tìm thấy thư mục 'cmd-Powershell' trong gói tải về!" -ForegroundColor Red
        exit
    }
}

Remove-Item $zipFile -Force
Remove-Item $ExtractPath -Recurse -Force

# KHỞI CHẠY KHÔNG SỢ SAI ĐƯỜNG DẪN (Đã cập nhật sang IT_Github.ps1)
$LaunchFile = Join-Path $TargetDir "IT_Github.ps1"
if (Test-Path $LaunchFile) {
    Write-Host "🚀 Khởi chạy Tool..." -ForegroundColor Green
    Set-Location $TargetDir
    & ".\IT_Github.ps1"
} else {
    Write-Host "❌ Lỗi: Không tìm thấy file IT_Github.ps1 tại $TargetDir" -ForegroundColor Red
}
