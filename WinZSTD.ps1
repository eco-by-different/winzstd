# =================================================================
# WinZSTD 1.2 compact-clean - powered by Windows TAR.exe
# Native TAR/ZSTD GUI using Windows tar.exe
# STORE=.tar | ZSTD=.tar.zst levels 1-22
# Compression timeline: 0 STORE ... 22 EXTREME
# Progress bar at bottom
# =================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- HIDE STARTUP POWERSHELL CONSOLE WINDOW ---
if (-not ("EcoConsoleWindow" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class EcoConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
}
$consolePtr = [EcoConsoleWindow]::GetConsoleWindow()
if ($consolePtr -ne [IntPtr]::Zero) { [EcoConsoleWindow]::ShowWindow($consolePtr, 0) | Out-Null }

[System.Windows.Forms.Application]::EnableVisualStyles()

# --- SHORT HELPERS ---
function P($X, $Y) { [System.Drawing.Point]::new($X, $Y) }
function S($W, $H) { [System.Drawing.Size]::new($W, $H) }
function N {
    param([string]$Type, [hashtable]$Props)
    $obj = New-Object $Type
    foreach ($key in $Props.Keys) { $obj.$key = $Props[$key] }
    $obj
}

# --- CONSTANTS ---
$cBg     = [System.Drawing.Color]::White
$cTxt    = [System.Drawing.ColorTranslator]::FromHtml("#2F4F4F")
$cGray   = [System.Drawing.Color]::LightGray
$fNormal = [System.Drawing.Font]::new("Segoe UI", 9)
$fBold   = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fItalic = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)

# --- PATHS ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }

$psExe   = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$tarPath = Join-Path $env:SystemRoot "System32\tar.exe"

if (-not (Test-Path -LiteralPath $tarPath)) {
    $cmdTar = Get-Command "tar.exe" -ErrorAction SilentlyContinue
    if ($cmdTar -and $cmdTar.Source) { $tarPath = $cmdTar.Source }
}

$script:selectedPath = ""
$script:selectedType = ""

# --- UI HELPERS ---
function New-EcoLabel {
    param(
        [string]$Text, [int]$X, [int]$Y, [int]$W = 470, [int]$H = 20,
        [System.Drawing.Font]$Font = $fNormal,
        [System.Drawing.Color]$ForeColor = $cTxt
    )
    N "System.Windows.Forms.Label" @{
        Text = $Text; Location = P $X $Y; Size = S $W $H
        Font = $Font; ForeColor = $ForeColor; BackColor = $cBg
    }
}

function New-EcoButton {
    param(
        [string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H,
        [System.Drawing.Font]$Font = $fNormal,
        [System.Drawing.Color]$BackColor = $cBg,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black
    )
    $button = N "System.Windows.Forms.Button" @{
        Text = $Text; Location = P $X $Y; Size = S $W $H
        Font = $Font; BackColor = $BackColor; ForeColor = $ForeColor
        UseVisualStyleBackColor = $false
    }
    try {
        $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $button.FlatAppearance.BorderSize = 1
        $button.FlatAppearance.BorderColor = $cGray
    } catch {}
    $button
}

function New-EcoCheck {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [bool]$Checked = $true)
    N "System.Windows.Forms.CheckBox" @{
        Text = $Text; Location = P $X $Y; Size = S $W 22
        Font = $fNormal; BackColor = $cBg; ForeColor = $cTxt
        Checked = $Checked
    }
}

function Msg {
    param(
        [string]$Message,
        [string]$Title = "WinZSTD 1.2",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK
    )
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

function Set-AppStatus {
    param([string]$Text, [System.Drawing.Color]$Color = [System.Drawing.Color]::DimGray)
    $lblStatus.Text = $Text
    $lblStatus.ForeColor = $Color
    $form.Refresh()
}

# --- COMPRESSION PROFILE ---
function Get-CompressionProfile {
    param([int]$Level, [bool]$TarBeforeZstd)

    $Level = [Math]::Max(0, [Math]::Min(22, $Level))
    if ($Level -eq 0) { return @{ Text = "STORE / TAR"; Ext = ".tar"; Args = @() } }

    $ext  = if ($TarBeforeZstd) { ".tar.zst" } else { ".zst" }
    $text = if ($TarBeforeZstd) { "TAR.ZST level $Level" } else { "ZST level $Level" }

    @{ Text = $text; Ext = $ext; Args = @("-a", "--options", "zstd:compression-level=$Level") }
}

# --- MAIN FORM ---
$form = N "System.Windows.Forms.Form" @{
    Text = "WinZSTD 1.2 - powered by Windows TAR.exe"
    ClientSize = S 505 470
    StartPosition = "CenterScreen"
    BackColor = $cBg
    FormBorderStyle = "FixedSingle"
    MaximizeBox = $false
    TopMost = $false
}

# --- MAIN GUI ---
$lblInput    = New-EcoLabel "1. Select what to archive:" 20 20 -Font $fBold
$btnFile     = New-EcoButton "Add FILE" 20 48 230 30
$btnFolder   = New-EcoButton "Add FOLDER" 255 48 230 30
$lblSelected = New-EcoLabel "Selected: none" 20 88 465 20 $fItalic ([System.Drawing.Color]::DimGray)
$lblTarget   = New-EcoLabel "2. Destination archive path:" 20 125 -Font $fBold

$txtTarget = N "System.Windows.Forms.TextBox" @{
    Location = P 20 153; Size = S 395 23
    Font = $fNormal; ReadOnly = $true; BackColor = $cBg
}
$btnTarget = New-EcoButton "..." 422 152 63 24

$grpCompression = N "System.Windows.Forms.GroupBox" @{
    Text = "3. Compression settings"
    Location = P 20 195; Size = S 465 120
    Font = $fBold; ForeColor = $cTxt; BackColor = $cBg
}

$trkCompression = N "System.Windows.Forms.TrackBar" @{
    Location = P 15 22; Size = S 435 45
    Minimum = 0; Maximum = 22; Value = 11
    TickFrequency = 1; SmallChange = 1; LargeChange = 3
    BackColor = $cBg
}

$lblCompHint  = New-EcoLabel "0 = STORE / .tar    |    1-22 = .tar.zst compression" 18 68 425 20 $fItalic ([System.Drawing.Color]::DimGray)
$lblCompValue = New-EcoLabel "Selected: TAR.ZST level 11" 18 94 425 20 $fBold ([System.Drawing.Color]::DarkOrange)

$grpCompression.Controls.AddRange([System.Windows.Forms.Control[]]@(
    $trkCompression, $lblCompHint, $lblCompValue
))

$btnCreate = New-EcoButton "CREATE ARCHIVE" 20 330 465 38 $fBold ([System.Drawing.Color]::SeaGreen) ([System.Drawing.Color]::White)
$chkTarBeforeZstd = New-EcoCheck "Create .tar before ZSTD" 20 383 210 $true
$chkOpenFolder    = New-EcoCheck "Open output folder after success" 255 383 230 $true
$lblStatus        = New-EcoLabel "Ready." 20 417 465 20 $fItalic ([System.Drawing.Color]::DimGray)

$progressBar = N "System.Windows.Forms.ProgressBar" @{
    Location = P 20 445; Size = S 465 8
    Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    MarqueeAnimationSpeed = 25
    Visible = $false
}

$form.Controls.AddRange([System.Windows.Forms.Control[]]@(
    $lblInput, $btnFile, $btnFolder, $lblSelected,
    $lblTarget, $txtTarget, $btnTarget,
    $grpCompression, $btnCreate,
    $chkTarBeforeZstd, $chkOpenFolder,
    $lblStatus, $progressBar
))

# --- PATH HELPERS ---
function Remove-KnownArchiveExtension {
    param([string]$Path)

    $fileName = [System.IO.Path]::GetFileName($Path)
    if ([string]::IsNullOrWhiteSpace($fileName)) { return "" }

    if ($fileName -match '(?i)\.(tar\.zst|tzst|zst|tar)$') {
        return ($fileName -replace '(?i)\.(tar\.zst|tzst|zst|tar)$', '')
    }

    [System.IO.Path]::GetFileNameWithoutExtension($fileName)
}

function Set-TargetExtension {
    param([string]$Extension)

    if ([string]::IsNullOrWhiteSpace($script:selectedPath)) { return }

    if ([string]::IsNullOrWhiteSpace($txtTarget.Text)) {
        $txtTarget.Text = "$script:selectedPath$Extension"
        return
    }

    $current  = $txtTarget.Text.Trim('"')
    $dir      = [System.IO.Path]::GetDirectoryName($current)
    $baseName = Remove-KnownArchiveExtension $current

    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = $scriptDir }
    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = "WinZSTD_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    }

    $txtTarget.Text = Join-Path $dir ($baseName + $Extension)
}

# --- UI STATE ---
function Update-CompressionUi {
    $level = [int]$trkCompression.Value
    $forceTar = ($script:selectedType -eq "Folder" -or $level -eq 0)

    if ($forceTar) { $chkTarBeforeZstd.Checked = $true }
    $chkTarBeforeZstd.Enabled = -not $forceTar

    $profile = Get-CompressionProfile $level ([bool]$chkTarBeforeZstd.Checked)
    $lblCompValue.Text = "Selected: $($profile.Text)"

    $lblCompValue.ForeColor = if ($level -eq 0) {
        [System.Drawing.Color]::Firebrick
    } elseif ($level -ge 18) {
        [System.Drawing.Color]::DarkViolet
    } elseif ($level -ge 8) {
        [System.Drawing.Color]::DarkOrange
    } else {
        [System.Drawing.Color]::SeaGreen
    }

    if (-not [string]::IsNullOrWhiteSpace($script:selectedPath)) {
        Set-TargetExtension $profile.Ext
    }
}

function Set-SelectedPath {
    param([string]$Path, [ValidateSet("File", "Folder")] [string]$Type)

    $script:selectedPath = $Path
    $script:selectedType = $Type
    $lblSelected.Text = "Selected: $script:selectedPath"

    $btnFile.BackColor   = if ($Type -eq "File") { [System.Drawing.Color]::LightBlue } else { $cBg }
    $btnFolder.BackColor = if ($Type -eq "Folder") { [System.Drawing.Color]::LightBlue } else { $cBg }

    Update-CompressionUi

    $profile = Get-CompressionProfile ([int]$trkCompression.Value) ([bool]$chkTarBeforeZstd.Checked)
    $txtTarget.Text = "$script:selectedPath$($profile.Ext)"
}

# --- WORKER SCRIPT ---
function New-WorkerScript {
    param([string]$WorkerPath)

@'
param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $tarPath = [string]$config.TarPath
    $source  = [string]$config.SourcePath
    $dest    = [string]$config.DestinationPath
    $extra   = @($config.TarArgsExtra) | Where-Object { $_ }

    if (-not (Test-Path -LiteralPath $tarPath)) { throw "tar.exe was not found." }
    if (-not (Test-Path -LiteralPath $source)) { throw "Source path does not exist." }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }

    $parent = Split-Path -Parent $source
    $leaf   = Split-Path -Leaf $source

    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }

    $tarArgs = @($extra) + @("-cf", $dest, "-C", $parent, $leaf)
    & $tarPath @tarArgs 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) { throw "tar.exe exited with code $LASTEXITCODE" }
    exit 0
}
catch {
    exit 2
}
'@ | Set-Content -LiteralPath $WorkerPath -Encoding UTF8
}

# --- EVENTS ---
$btnFile.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select file to archive"
    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Set-SelectedPath $dialog.FileName "File"
        }
    } finally { $dialog.Dispose() }
})

$btnFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select folder to archive"
    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Set-SelectedPath $dialog.SelectedPath "Folder"
        }
    } finally { $dialog.Dispose() }
})

$btnTarget.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = "Select destination archive"
    $dialog.Filter = "TAR+ZSTD Archive (*.tar.zst)|*.tar.zst|TAR Archive (*.tar)|*.tar|ZSTD Archive (*.zst)|*.zst|All files (*.*)|*.*"
    $dialog.DefaultExt = "tar.zst"
    $dialog.AddExtension = $true
    $dialog.OverwritePrompt = $true

    try {
        if (-not [string]::IsNullOrWhiteSpace($txtTarget.Text)) {
            $dialog.FileName = [System.IO.Path]::GetFileName($txtTarget.Text)
            $initialDir = [System.IO.Path]::GetDirectoryName($txtTarget.Text)

            if (-not [string]::IsNullOrWhiteSpace($initialDir) -and (Test-Path -LiteralPath $initialDir)) {
                $dialog.InitialDirectory = $initialDir
            }
        }

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtTarget.Text = $dialog.FileName
        }
    } finally { $dialog.Dispose() }
})

$trkCompression.Add_ValueChanged({ Update-CompressionUi })
$chkTarBeforeZstd.Add_CheckedChanged({ Update-CompressionUi })

# --- EXECUTION ENGINE ---
function Execute-Archive {
    if (-not (Test-Path -LiteralPath $tarPath)) {
        Msg "tar.exe was not found." "Missing TAR Engine" ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($script:selectedPath) -or [string]::IsNullOrWhiteSpace($txtTarget.Text)) {
        Msg "Please select input and destination paths." "Missing Parameters" ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $script:selectedPath)) {
        Msg "Selected input path does not exist." "Input Error" ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    Update-CompressionUi

    $level = [int]$trkCompression.Value
    $modeData = Get-CompressionProfile $level ([bool]$chkTarBeforeZstd.Checked)
    Set-TargetExtension $modeData.Ext

    $targetPath = $txtTarget.Text.Trim('"')
    $targetDir  = [System.IO.Path]::GetDirectoryName($targetPath)

    if ([string]::IsNullOrWhiteSpace($targetDir)) {
        $targetDir = $scriptDir
        $targetPath = Join-Path $targetDir ([System.IO.Path]::GetFileName($targetPath))
        $txtTarget.Text = $targetPath
    }

    if (-not (Test-Path -LiteralPath $targetDir)) {
        Msg "Destination directory does not exist:`n$targetDir" "Destination Error" ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    if (Test-Path -LiteralPath $targetPath) {
        $confirm = Msg `
            "Target archive already exists. Overwrite it?" `
            "Overwrite Archive" `
            ([System.Windows.Forms.MessageBoxIcon]::Warning) `
            ([System.Windows.Forms.MessageBoxButtons]::YesNo)

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    Set-AppStatus "In progress..." ([System.Drawing.Color]::DarkOrange)
    $progressBar.Visible = $true
    $progressBar.MarqueeAnimationSpeed = 25
    $form.Refresh()

    $guid = [guid]::NewGuid().ToString("N")
    $workerScript = Join-Path $env:TEMP "winzstd_worker_$guid.ps1"
    $configPath   = Join-Path $env:TEMP "winzstd_config_$guid.json"

    New-WorkerScript $workerScript

    [PSCustomObject]@{
        TarPath          = $tarPath
        SourcePath       = $script:selectedPath
        DestinationPath  = $targetPath
        CompressionLevel = $level
        TarBeforeZstd    = [bool]$chkTarBeforeZstd.Checked
        ModeText         = $modeData.Text
        TarArgsExtra     = @($modeData.Args)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

    $success = $false
    $errorMessage = $null
    $proc = $null

    try {
        $procInfo = N "System.Diagnostics.ProcessStartInfo" @{
            FileName = $psExe
            Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ConfigPath "{1}"' -f $workerScript, $configPath
            WorkingDirectory = $scriptDir
            UseShellExecute = $false
            CreateNoWindow = $true
            WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        }

        $proc = [System.Diagnostics.Process]::Start($procInfo)

        while (-not $proc.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        $success = ($proc.ExitCode -eq 0)
    }
    catch {
        $errorMessage = $_.Exception.Message
    }
    finally {
        $progressBar.MarqueeAnimationSpeed = 0
        $progressBar.Visible = $false
        $form.Refresh()

        if ($proc) { $proc.Dispose() }

        foreach ($file in @($workerScript, $configPath)) {
            if (Test-Path -LiteralPath $file) {
                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($success) {
        Set-AppStatus "Operation successful." ([System.Drawing.Color]::Green)
        if ($chkOpenFolder.Checked) { explorer.exe "/select,`"$targetPath`"" }
        return
    }

    Set-AppStatus "Operation failed or aborted." ([System.Drawing.Color]::Red)

    $message = "Operation failed or aborted."
    if ($errorMessage) { $message += "`n`n$errorMessage" }

    Msg $message "Archive Error" ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

# --- BUTTON ACTION ---
$btnCreate.Add_Click({ Execute-Archive })

# --- INITIAL UI STATE ---
Update-CompressionUi

# --- CLEANUP ---
$form.Add_FormClosing({
    $fNormal.Dispose()
    $fBold.Dispose()
    $fItalic.Dispose()
})

[System.Windows.Forms.Application]::Run($form)