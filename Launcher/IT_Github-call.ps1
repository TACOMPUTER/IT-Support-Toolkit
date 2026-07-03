# Đây là file dùng để gọi file '.ps1' trên Github. Chạy file này thấy ổn thì xuất ra '.exe' thông qua file '2.1. Run_Invoke-PS2EX.ps1'
# LƯU Ý: Path và Filename trong đây chỉ phù hợp gọi file trên Github



# 1. Tạo Shortcut và Copy file trước (để đảm bảo xong xuôi việc "cài đặt")
$InstallDir = "C:\SW"
if (-not (Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null }

# 2. Vị trí chạy file này '...\cmd-Powershell\Build PS2EXE\', mà cần up ra '...\cmd-Powershell' để thấy được 2 file 'IT_Github-call'
$SourcePath = Split-Path $MyInvocation.MyCommand.Path -Parent
$ExeName = "IT_Github-call.exe"
$Ps1CallName = "IT_Github-call.ps1"

# 3. Dùng copy thay vì Copy-Item để tránh lỗi "File in use"
cmd /c "copy /Y `"$SourcePath\$ExeName`" `"$InstallDir\$ExeName`" >nul 2>&1"
cmd /c "copy /Y `"$SourcePath\$Ps1CallName`" `"$InstallDir\$Ps1CallName`" >nul 2>&1"

# 4. Tạo Shortcut (làm xong luôn để người dùng có cái dùng ngay)
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\IT_Github-call.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "$InstallDir\$ExeName"
$Shortcut.IconLocation = "$InstallDir\$ExeName"
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Save()

# 5. Cuối cùng mới gọi file 'IT_Github.ps1' trên GitHub
irm https://raw.githubusercontent.com/TACOMPUTER/IT-Support-Toolkit/main/IT_Github.ps1 | iex