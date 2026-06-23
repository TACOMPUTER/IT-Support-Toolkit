# Setup.ps1 - Deploy bộ tool IT từ GitHub Private Repository
# Chạy với quyền Administrator

# 1. Ép hệ thống dùng TLS 1.2 để tránh lỗi kết nối GitHub trên máy cũ
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. KHAI BÁO TOKEN BẢO MẬT (Do Repo là Private)
# Bạn tạo 1 token Fine-grained hoặc Classic trên GitHub (quyền Read-only) rồi dán vào đây
$PATToken = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 

# 3. ĐƯỜNG DẪN ĐÍCH THEO YÊU CẦU CỦA BẠN
$TargetDir = "C:\SW\cmd-Powershell"

# Đảm bảo thư mục đích tồn tại sạch sẽ trước khi tải đè
if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

Write-Host "📥 Đang tải bộ công cụ IT Support từ GitHub..." -ForegroundColor Cyan

$zipUrl = "https://api.github.com/repos/TACOMPUTER/IT-Support-Toolkit/zipball/main"
$zipFile = "$env:TEMP\it_toolkit.zip"

# Gọi API kèm Token để tải kho riêng tư (Private)
$headers = @{
    Authorization = "Bearer $PATToken"
    Accept        = "application/vnd.github+json"
}

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -Headers $headers -ErrorAction Stop
} catch {
    Write-Host "❌ Lỗi: Không thể tải file từ GitHub. Kiểm tra lại PAT Token hoặc kết nối mạng!`n$($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "📦 Đang giải nén và cấu trúc lại thư mục..." -ForegroundColor Cyan
$ExtractPath = "$env:TEMP\it_extracted"
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

Expand-Archive -Path $zipFile -DestinationPath $ExtractPath -Force

# Tìm thư mục gốc do GitHub tự sinh ra khi giải nén (dạng TACOMPUTER-IT-Support-Toolkit-xxxx)
$RepoFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1

if ($RepoFolder) {
    # Đường dẫn nguồn chứa code bên trong gói giải nén dựa theo cấu trúc GitHub của bạn
    $SourcePath = Join-Path $RepoFolder.FullName "Software\OS Tools\cmd-Powershell"
    
    if (Test-Path $SourcePath) {
        # Copy toàn bộ nội dung bên trong cmd-Powershell về C:\SW\cmd-Powershell
        Copy-Item -Path "$SourcePath\*" -Destination $TargetDir -Recurse -Force
    } else {
        Write-Host "❌ Lỗi: Không tìm thấy cấu trúc 'Software\OS Tools\cmd-Powershell' trong gói tải về!" -ForegroundColor Red
        exit
    }
}

# Dọn dẹp file tạm sau khi cài đặt xong
Remove-Item $zipFile -Force
Remove-Item $ExtractPath -Recurse -Force

# 4. KHỞI CHẠY TOOL TẠI THƯ MỤC MỚI
if (Test-Path (Join-Path $TargetDir "IT.ps1")) {
    Write-Host "🚀 Khởi chạy Tool..." -ForegroundColor Green
    Set-Location $TargetDir
    & ".\IT.ps1"
} else {
    Write-Host "❌ Lỗi: Không tìm thấy file IT.ps1 tại $TargetDir" -ForegroundColor Red
}
