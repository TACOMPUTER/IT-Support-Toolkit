# =========================
# IT TOOLKIT MAIN SCRIPT
# =========================

$ErrorActionPreference = "SilentlyContinue"

# =========================
# CONFIG
# =========================

$SystemDriveSW = "C:\SW"
$ExportLocal = "$SystemDriveSW\ExportHTML"

if (-not (Test-Path $ExportLocal)) {
    New-Item -Path $ExportLocal -ItemType Directory | Out-Null
}

# =========================
# UTIL
# =========================

function Show-Menu {
    Clear-Host
    Write-Host "================ IT TOOLKIT ================"
    Write-Host "1. Create Shortcut"
    Write-Host "2. Export Excel PrintArea to HTML (Local + \\IT\\Guest)"
    Write-Host "3. Resize PowerShell Window"
    Write-Host "4. Move PowerShell Window"
    Write-Host "0. Exit"
    Write-Host "==========================================="
}

# =========================
# SHORTCUT
# =========================

function Create-Shortcut {
    $target = "$SystemDriveSW\IT.ps1"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $link = Join-Path $desktop "IT Toolkit.lnk"

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($link)

    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-ExecutionPolicy Bypass -File `"$target`""
    $sc.WorkingDirectory = $SystemDriveSW
    $sc.Save()

    Write-Host "Shortcut created at Desktop"
    Start-Sleep -Seconds 2
}

# =========================
# EXPORT EXCEL PRINT AREA
# =========================

function Export-ExcelPrintAreaToHtml {
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false

        $file = (Get-FileName "Select Excel File")
        if (-not $file) { return }

        $wb = $excel.Workbooks.Open($file)
        $ws = $wb.ActiveSheet

        $range = $ws.Range($ws.PageSetup.PrintArea)

        if (-not $range) {
            $range = $ws.UsedRange
        }

        $htmlLocal = Join-Path $ExportLocal "export.html"

        $range.Copy()

        $wbWeb = $excel.Workbooks.Add()
        $wsWeb = $wbWeb.Worksheets.Item(1)

        $wsWeb.Paste()
        $wbWeb.SaveAs($htmlLocal, 44)

        # copy to network if exists
        $networkPath = "\\IT\Guest\export.html"
        Copy-Item $htmlLocal $networkPath -Force

        $wb.Close($false)
        $wbWeb.Close($false)
        $excel.Quit()

        Write-Host "Export done"
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Export failed"
        Start-Sleep -Seconds 2
    }
}

function Get-FileName($title) {
    Add-Type -AssemblyName System.Windows.Forms

    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = $title
    $dlg.Filter = "Excel Files|*.xlsx;*.xlsm;*.xls"

    if ($dlg.ShowDialog() -eq "OK") {
        return $dlg.FileName
    }

    return $null
}

# =========================
# RESIZE WINDOW
# =========================

function Resize-Window {
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(120, 35)
    Write-Host "Window resized"
    Start-Sleep -Seconds 1
}

# =========================
# MOVE WINDOW
# =========================

function Move-Window {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool R);
}
"@

    $hwnd = [Win32]::GetConsoleWindow()
    [Win32]::MoveWindow($hwnd, 200, 100, 900, 600, $true)

    Write-Host "Window moved"
    Start-Sleep -Seconds 1
}

# =========================
# MAIN LOOP
# =========================

while ($true) {
    Show-Menu
    $choice = Read-Host "Select"

    switch ($choice) {
        "1" { Create-Shortcut }
        "2" { Export-ExcelPrintAreaToHtml }
        "3" { Resize-Window }
        "4" { Move-Window }
        "0" { break }
        default {
            Write-Host "Invalid"
            Start-Sleep -Seconds 1
        }
    }
}
