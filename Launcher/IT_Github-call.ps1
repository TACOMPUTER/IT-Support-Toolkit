# File này để gọi 'IT_Github.ps1' trên Github, và file này phải dùng '1.1. Loader-PS1.ps1' để chuyển sang .exe, thành 'IT_Github-call.exe' để chạy cho nhanh
# Các máy tính chỉ cần 1 file 'C:\SW\IT_Github-call.exe' và shortcut trong Start là đủ
# File 'IT_Github-call.exe' sau khi chuyển sẽ up lên Github 'IT-Support-Toolkit/Launcher', khi chạy file này bất kỳ đâu, nó sẽ gọi 'IT_Github.ps1' và tự chép vào 'C:\SW' & tạo shortcut trong Start

$GitHubURL = "https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/IT_Github.ps1"

Invoke-RestMethod $GitHubURL | Invoke-Expression