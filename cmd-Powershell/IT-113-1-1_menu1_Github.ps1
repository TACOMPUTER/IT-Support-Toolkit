# Nhận các biến cần thiết từ script chính (nếu có)
param($LibScript, $consoleHandle)

function Show-SetupWindowsMenu {
    # 🚩 Setup Form
    $formText     = "Vừa cài đặt xong Windows"
    $formWidth    = 600
    Add-Type -AssemblyName System.Windows.Forms
    $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height
    $formHeight   = $screenHeight - 50

    # Load template
    . "$LibScript\Form-TableLayout.ps1"

    $row1 = Add-Row 1
    $row2 = Add-Row 2
    $row3 = Add-Row 3
    $row4 = Add-Row 4

    # --- Các hàm xử lý button của bạn ở đây ---
    Add-ButtonToRow "1.1. Xoá/Tạo/Pass tài khoản local >>> Restart" $row1 {

		Reset-Console

		Write-Info "Tài khoản hiện tại là '$currentUser'`nTiến hành xử lý thông qua 'Local_user_credentials.ps1'`n"
		Write-Info "Xoá tài khoản không dùng`nKích hoạt tài khoản xong thì Đổi mật khẩu cho nó`n" -NoTimestamp

		Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$LibScript\Local_user_credentials.ps1`""

	}

	Add-ButtonToRow "1.2. Xoá 'User profile'" $row1 {

		Reset-Console

		# Phần 1: Liệt kê thư mục trong C:\Users và cho phép người dùng chọn để xóa
		Write-Info "'Danh sách thư mục trong C:\Users'"

		$folders    = Get-ChildItem -Path "C:\Users" -Directory
		$index      = 1
		$folderList = @{}

		foreach ($folder in $folders) {

			Write-Info "$index. $($folder.Name)" -NoTimestamp
			$folderList[$index] = $folder.FullName
			$index++

		}

		Write-Input "`nNhập số thứ tự thư mục muốn xóa:`n(ENTER để bỏ qua hoặc ESC để kết thúc`n& chuyển qua 'Thêm Guest')`n" -NoTimestamp

		# lấy phím nhập vào và xuất ra biến $keyinput (vẫn sử dụng 'form-tablelayout.ps1')
		$global:keyinput = $null
		Enable-Input # Mở txtbox

		while ($true) {

			$global:keyinput = $null

			while ($global:keyinput -eq $null) {

				Start-Sleep -Milliseconds 50
				[System.Windows.Forms.Application]::DoEvents()

			}

			$keyinput = $global:keyinput

			# 🔥 FIX DELAY
			[System.Windows.Forms.Application]::DoEvents()

			Write-Console "input → $keyinput" ([System.Drawing.Color]::Yellow) -NoTimestamp

			if ($keyinput -eq 'ESC') {

				Write-Info "→ Huỷ lệnh`n" -NoTimestamp
				Disable-Input
				return # Kết thúc nút, nhảy xuống Khoá txtbox ở dưới

			}
			elseif ($keyinput -match '^\d+$') {

				if ($keyinput -and $folderList.ContainsKey([int]$keyinput)) {

					$folderToDelete = $folderList[[int]$keyinput]

					try {

						Remove-Item -Path $folderToDelete -Recurse -Force -ErrorAction Stop
						Write-Info "Đã xóa thư mục $folderToDelete thành công!`n" -NoTimestamp
						Write-Console "→ Click '5. Reboot computer'" -NoTimestamp
						break

					}
					catch {

						Write-Err "Lỗi khi xóa thư mục: $_`n" -NoTimestamp

					}

				}
				else {

					Write-Warn "→ Nhập sai! Chỉ nhập theo danh sách có sẵn (1 → $($index-1))`n" -NoTimestamp

				}

			}
			else {

				Write-Warn "→ Nhập sai! Chỉ nhập theo danh sách có sẵn (1 → $($index-1))`n" -NoTimestamp
				continue # Chỉ bỏ qua vòng if này, Form vẫn treo trong loop

			}

		}

		Disable-Input # Khoá txtbox

	}

	Add-ButtonToRow "1.3. Thêm 'Guest' >>> Restart" $row1 {

		Reset-Console

		$username = "Guest"
		$password = "0933848990"
		$servers  = @("IT", "IT-E580", "172.16.8.8")

		foreach ($server in $servers) {

			try {

				cmdkey /add:$server /user:$username /pass:$password
				Write-Info "Đã thêm thông tin đăng nhập vào $server thành công!`n"

			}
			catch {

				Write-Err "Lỗi khi thêm thông tin đăng nhập vào $server!`n"

			}

		}

	}

	Add-ButtonToRow "2. Tạo 'D:' | Đặt Drives label | Tạo CuuHo-PC | Sắp xếp Drives letter" $row2 {

		Reset-Console

		Write-Info "Tiến hành xử lý thông qua 'Drive_partition_letter.ps1'`n"
		Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$LibScript\Drive_partition_letter.ps1`""

	}

	Add-ButtonToRow "3. Chuyển 'USERPROFILE' sang 'D:'" $row3 {

		Reset-Console

		Write-Info "Tiến hành xử lý thông qua 'Move_Users_to_D.ps1'`n"
		Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$LibScript\Move_Users_to_D.ps1`""

	}

	Add-ButtonToRow "4. Chuyển 'OneDrive' sang ổ khác" $row3 {

		Reset-Console

		# 1. User + default path
		$Username    = $env:USERNAME
		$DefaultPath = "C:\Users\$Username\OneDrive"

		Write-Console "OneDrive mặc định (chưa sử dụng lần nào):`n'$DefaultPath'`n"

		# 2. Registry check
		$RegPath     = "HKCU:\Software\Microsoft\OneDrive"
		$currentPath = $null

		if (Test-Path $RegPath) {

			$currentPath = (
				Get-ItemProperty -Path $RegPath -Name "UserFolder" -ErrorAction SilentlyContinue
			).UserFolder

		}

		if ($currentPath) {

			Write-Info "OneDrive đã được cấu hình tại:`n'$currentPath'`n"

		}
		else {

			Write-Warn "Chưa có cấu hình OneDrive (first setup mode)."

		}

		# 3. Detect drives (simple safe version)
		$drives = Get-CimInstance Win32_LogicalDisk |
			Where-Object { $_.DriveType -eq 3 -and $_.DeviceID }

		$driveOptions = @()
		$i = 1

		foreach ($d in $drives) {

			$path = "$($d.DeviceID)\OneDrive"

			$driveOptions += [PSCustomObject]@{
				Index = $i
				Drive = $d.DeviceID
				Path  = $path
			}

			$i++

		}

		# 4. UI
		Write-Input "Chọn vị trí mới cho OneDrive:`n"

		foreach ($opt in $driveOptions) {

			Write-Info (" {0}. {1}" -f $opt.Index, $opt.Path) -NoTimestamp

		}

		Write-Info " Hoặc nhập đường dẫn tùy chỉnh (vd D:\Cloud, OneDrive sẽ tự thêm phía sau)" -NoTimestamp

		Write-Input "`nNhập lựa chọn (ENTER = bỏ qua, ESC = thoát):`n" -NoTimestamp

		Enable-Input
		$NewPath = $null

		while ($true) {

			$global:keyinput = $null

			while ($global:keyinput -eq $null) {

				Start-Sleep -Milliseconds 50
				[System.Windows.Forms.Application]::DoEvents()

			}

			$keyinput = $global:keyinput
			[System.Windows.Forms.Application]::DoEvents()

			if ($keyinput -eq "ESC") {

				Write-Info "Đã hủy thao tác." -NoTimestamp
				Disable-Input
				return

			}
			elseif ($keyinput -eq "ENTER") {

				Write-Warn "Không chọn thay đổi." -NoTimestamp
				Disable-Input
				return

			}
			elseif ($keyinput -match "^\d+$") {

				$selected = $driveOptions | Where-Object {
					$_.Index -eq [int]$keyinput
				}

				if ($selected) {

					$NewPath = $selected.Path
					break

				}
				else {

					Write-Warn "Lựa chọn không hợp lệ." -NoTimestamp

				}

			}
			else {

				if ($keyinput -match "^[A-Za-z]:\\") {

					$base    = $keyinput.TrimEnd("\")
					$base    = $base -replace "\\OneDrive$", ""
					$NewPath = Join-Path $base "OneDrive"

					break

				}
				else {

					Write-Warn "Đường dẫn không hợp lệ." -NoTimestamp

				}

			}

		}

		Disable-Input

		# 5. Stop OneDrive
		Write-Console "Stopping OneDrive..." -NoTimestamp
		Stop-Process -Name OneDrive -ErrorAction SilentlyContinue

		# 6. Ensure folder exists
		if (!(Test-Path $NewPath)) {

			New-Item -ItemType Directory -Path $NewPath | Out-Null

		}

		# 7. IMPORTANT: set registry FIRST (first-run behavior)
		if (-not (Test-Path $RegPath)) {

			New-Item -Path $RegPath -Force | Out-Null

		}

		Set-ItemProperty -Path $RegPath -Name "UserFolder" -Value $NewPath

		# 1. OneDrive real path
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" `
			-Name "UserFolder" `
			-Value $NewPath

		# 2. Environment Variables (UI sync)
		[Environment]::SetEnvironmentVariable(
			"OneDrive",
			$NewPath,
			[EnvironmentVariableTarget]::User
		)

		Write-Info "Đã cấu hình OneDrive location:`n'$NewPath'`n"

		# 8. Restart OneDrive
		$OneDriveExe = @(
			"$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
			"$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
			"$env:ProgramFiles(x86)\Microsoft OneDrive\OneDrive.exe"
		) | Where-Object { Test-Path $_ } | Select-Object -First 1

		if ($OneDriveExe) {

			Write-Console "Starting OneDrive..." -NoTimestamp
			Start-Process $OneDriveExe

		}
		else {

			Write-Warn "Không tìm thấy OneDrive.exe"

		}

		Write-Info "Hoàn tất cấu hình OneDrive lần đầu." -NoTimestamp

	}

	Add-ButtonToRow "5. Restart computer" $row4 {

		Restart-Computer

	}

    [void]$global:form.ShowDialog()
    [WinAPI]::ShowWindow($consoleHandle, 9)
}