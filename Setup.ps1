# Setup.ps1 - Kích hoạt bộ tool IT chạy trực tiếp trên RAM từ GitHub
# Chạy với quyền Administrator

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "📥 Đang nạp bộ công cụ IT Support vào RAM..." -ForegroundColor Cyan

# Link RAW trực tiếp đến file All-In-One duy nhất trên GitHub
$url = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/cmd-Powershell/IT_Github.ps1"
$headers = @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }

try {
    $scriptCode = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
    # Thực thi trực tiếp trên RAM
    Invoke-Expression $scriptCode
} catch {
    Write-Host "❌ Lỗi: Không thể tải bộ công cụ từ GitHub. Kiểm tra lại mạng!`n$($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Bấm Enter để thoát..."
}
