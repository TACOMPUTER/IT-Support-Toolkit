# 🚩 <<<--- 'VARIABLE_IT.PS1' --->>>

$SystemDriveSW = "C:\SW"
. "$SystemDriveSW\variable_IT.ps1"

# 🏁 <<<--- 'VARIABLE_IT.PS1' --->>>

# 🚩 <<<--- 'HEADER_FOR_IT-XXX.PS1' --->>>

. "$LibScript\Header_for_IT-xxx.ps1" `
    -PSWidth 100 `
    -PSHeight 16 `
    -PosX 0 `
    -PosY 60

# 🏁 <<<--- 'HEADER_FOR_IT-XXX.PS1' --->>>

# 🚩 <<<--- 'FORM-NOTIACT.PS1' --->>>

. "$LibScript\Form-NotiAct.ps1"

# 🏁 <<<--- 'FORM-NOTIACT.PS1' --->>>



# 🚩 <<<--- LIST MENU --->>>

function Show-Menu-IT-113-1 {
	Clear-Host

    # 🚩 <<<--- LOGO IT --->>>

	Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray

		# text nhiều dòng, các dòng txt ko cần sát lề trái
	$textLines = @(
	" Ghim mạng; Boot USB: USx3 & Phân vùng ổ C: (232.9GB=101770; 119.2GB=77559), còn lại 3.5G cuối cùng "
	" Vào Win; Rút USB; Chạy 'IT.ps1' trong '\\IT' để xóa tài khoản thường và kích hoạt 'Administrator' "
	)
	$width = $Host.UI.RawUI.WindowSize.Width
	foreach ($text in $textLines) {
		$pad = [Math]::Max(0, $width - $text.Length)
		$left  = [Math]::Floor($pad / 2)
		Write-Host (" " * $left) -NoNewline
		Write-Host $text
	}

	Write-Host ("+" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor DarkGray

	# 🏁 <<<--- LOGO IT --->>>

	Write-Host "<<< Danh sách MENU >>>"	-ForegroundColor Cyan
	Write-Host ""
	Write-Host "1. Vừa cài đặt xong Windows" -ForegroundColor Yellow
	Write-Host "2. MS Office và các phần mềm cơ bản" -ForegroundColor Magenta
	Write-Host "3. Phần mềm SW2: Patched - CAD2007 - LT2018 - SKU2021" -ForegroundColor Yellow
	Write-Host "4. Update các máy Deployment" -ForegroundColor Magenta
	Write-Host "5. Máy thực tế: Triển khai lên máy thực tế cấp cho người dùng" -ForegroundColor Yellow
	Write-Host ""
	Write-Host "Vui lòng nhập số " -NoNewline
    Write-Host "(1-5)" -ForegroundColor Yellow -NoNewline
    Write-Host " để tiến hành" -NoNewline
    Write-Host ": " -NoNewline

    $choice = Read-Host

	switch ($choice) {

		'1' {
			Write-Host "`n→ Đang chuyển đến: 1. Vừa cài đặt xong Windows..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-1.ps1" | Out-Null

			return
		}
		'2' {
			Write-Host "`n→ Đang chuyển đến: 2. MS Office và các phần mềm cơ bản..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-2.ps1" | Out-Null

			return
		}
		'3' {
			Write-Host "`n→ Đang chuyển đến: 3. PDF, Misa hoặc Import cấu hình FreeAll..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-3.ps1" | Out-Null

			return
		}
		'4' {
			Write-Host "`n→ Đang chuyển đến: 4. Phần mềm SW2: Patched - CAD2007 - LT2018 - SKU2021..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-4.ps1" | Out-Null

			return
		}
		'5' {
			Write-Host "`n→ Đang chuyển đến: 5. Update các máy Deployment..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-5.ps1" | Out-Null

			return
		}
		'6' {
			Write-Host "`n→ Đang chuyển đến: 6. Máy thực tế: Triển khai lên máy thực tế cấp cho người dùng..." -ForegroundColor Cyan
			Run-IT-xxx "$IT113Script\IT-113-1-6.ps1" | Out-Null

			return
		}

		'111' {
			Write-Host "`n→ Đang khởi động lại script..." -ForegroundColor Cyan
			Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

			exit
		}

		default { return }

	}
}

# 🏁 <<<--- LIST MENU --->>>
