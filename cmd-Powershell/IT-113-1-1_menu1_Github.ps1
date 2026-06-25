# Bắt buộc load Assembly này trước khi sử dụng các thành phần UI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

param($LibScript, $consoleHandle)

function Show-SetupWindowsMenu {
    # 🚩 Setup Form
    $formText     = "Vừa cài đặt xong Windows"
    $formWidth    = 600
    
    # Kiểm tra xem Form đã được load chưa, nếu chưa thì load Assembly
    if (-not ([System.Windows.Forms.Form])) { Add-Type -AssemblyName System.Windows.Forms }
    
    $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height
    $formHeight   = $screenHeight - 50

    # Load template UI
    $templatePath = Join-Path $LibScript "Form-TableLayout.ps1"
    if (Test-Path $templatePath) {
        . $templatePath
    } else {
        Write-Error "Không tìm thấy file template tại: $templatePath"
        return
    }

    $row1 = Add-Row 1
    $row2 = Add-Row 2
    $row3 = Add-Row 3
    $row4 = Add-Row 4

    # --- BUTTONS ---
    Add-ButtonToRow "1.1. Xoá/Tạo/Pass tài khoản local >>> Restart" $row1 {
        Reset-Console
        $currentUser = $env:USERNAME
        Write-Info "Tài khoản hiện tại là '$currentUser'`nTiến hành xử lý thông qua 'Local_user_credentials.ps1'`n"
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$LibScript\Local_user_credentials.ps1`""
    }

    Add-ButtonToRow "1.2. Xoá 'User profile'" $row1 {
        Reset-Console
        Write-Info "'Danh sách thư mục trong C:\Users'"
        $folders = Get-ChildItem -Path "C:\Users" -Directory
        $index = 1
        $folderList = @{}
        foreach ($folder in $folders) {
            Write-Info "$index. $($folder.Name)" -NoTimestamp
            $folderList[$index] = $folder.FullName
            $index++
        }
        
        Write-Input "`nNhập số thứ tự thư mục muốn xóa (ESC để thoát):`n" -NoTimestamp
        $global:keyinput = $null
        Enable-Input
        
        while ($true) {
            Start-Sleep -Milliseconds 50
            [System.Windows.Forms.Application]::DoEvents()
            if ($global:keyinput) {
                $key = $global:keyinput
                if ($key -eq 'ESC') { Disable-Input; return }
                if ($key -match '^\d+$' -and $folderList.ContainsKey([int]$key)) {
                    try {
                        Remove-Item -Path $folderList[[int]$key] -Recurse -Force -ErrorAction Stop
                        Write-Info "Đã xóa thành công!" -NoTimestamp
                        break
                    } catch { Write-Err "Lỗi: $_" -NoTimestamp }
                }
                $global:keyinput = $null # Reset input sau khi xử lý
            }
        }
        Disable-Input
    }

    Add-ButtonToRow "1.3. Thêm 'Guest' >>> Restart" $row1 {
        Reset-Console
        $servers = @("IT", "IT-E580", "172.16.8.8")
        foreach ($server in $servers) {
            cmdkey /add:$server /user:"Guest" /pass:"0933848990"
            Write-Info "Đã cấu hình $server"
        }
    }

    # (Các button 2, 3, 4, 5 giữ nguyên logic của bạn...)
    Add-ButtonToRow "5. Restart computer" $row4 { Restart-Computer -Force }

    [void]$global:form.ShowDialog()
    [WinAPI]::ShowWindow($consoleHandle, 9)
}
