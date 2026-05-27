# =================================================================
# WinZSTD 1.0 - powered by Windows TAR.exe
# Windows native TAR/TAR.ZST GUI - eco-by-different with AI GPT
# STORE=.tar | NORMAL=.tar.zst | EXTREME=.tar.zst level 22
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
if ($consolePtr -ne [IntPtr]::Zero) {
    [EcoConsoleWindow]::ShowWindow($consolePtr, 0) | Out-Null
}

[System.Windows.Forms.Application]::EnableVisualStyles()

# --- SHORT HELPERS ---
function P($X, $Y) { [System.Drawing.Point]::new($X, $Y) }
function S($W, $H) { [System.Drawing.Size]::new($W, $H) }

function N {
    param(
        [string]$Type,
        [hashtable]$Props
    )

    $obj = New-Object $Type

    foreach ($key in $Props.Keys) {
        $obj.$key = $Props[$key]
    }

    return $obj
}

# --- CONSTANTS ---
$cBg     = [System.Drawing.Color]::White
$cTxt    = [System.Drawing.ColorTranslator]::FromHtml("#2F4F4F")
$cGray   = [System.Drawing.Color]::LightGray
$fNormal = [System.Drawing.Font]::new("Segoe UI", 9)
$fBold   = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fItalic = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)

# --- PATHS ---
$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

$psExe   = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$tarPath = Join-Path $env:SystemRoot "System32\tar.exe"

if (-not (Test-Path -LiteralPath $tarPath)) {
    $cmdTar = Get-Command "tar.exe" -ErrorAction SilentlyContinue
    if ($cmdTar -and $cmdTar.Source) {
        $tarPath = $cmdTar.Source
    }
}

$script:selectedPath = ""

# --- MODES ---
$modes = @{
    Store = @{
        Text = "STORE / TAR"
        Ext  = ".tar"
        Args = @()
    }
    Normal = @{
        Text = "NORMAL / TAR.ZST"
        Ext  = ".tar.zst"
        Args = @("-a")
    }
    Extreme = @{
        Text = "EXTREME / TAR.ZST level 22"
        Ext  = ".tar.zst"
        Args = @("-a", "--options", "zstd:compression-level=22")
    }
}

# --- UI HELPERS ---
function New-EcoLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W = 470,
        [int]$H = 20,
        [System.Drawing.Font]$Font = $fNormal,
        [System.Drawing.Color]$ForeColor = $cTxt
    )

    N "System.Windows.Forms.Label" @{
        Text      = $Text
        Location  = P $X $Y
        Size      = S $W $H
        Font      = $Font
        ForeColor = $ForeColor
    }
}

function New-EcoButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [System.Drawing.Font]$Font = $fNormal,
        [System.Drawing.Color]$BackColor = $cBg,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::Black
    )

    $button = N "System.Windows.Forms.Button" @{
        Text                    = $Text
        Location                = P $X $Y
        Size                    = S $W $H
        Font                    = $Font
        BackColor               = $BackColor
        ForeColor               = $ForeColor
        UseVisualStyleBackColor = $false
    }

    try {
        $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $button.FlatAppearance.BorderSize = 1
        $button.FlatAppearance.BorderColor = $cGray
    }
    catch {}

    return $button
}

function Msg {
    param(
        [string]$Message,
        [string]$Title = "ZSTD 1.0",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK
    )

    [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

function Set-AppStatus {
    param(
        [string]$Text,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::DimGray
    )

    $lblStatus.Text = $Text
    $lblStatus.ForeColor = $Color
    $form.Refresh()
}

# --- MAIN FORM ---
$form = N "System.Windows.Forms.Form" @{
    Text            = "WinZSTD 1.0 - powered by Windows TAR.exe"
    Size            = S 520 405
    StartPosition   = "CenterScreen"
    BackColor       = $cBg
    FormBorderStyle = "FixedSingle"
    MaximizeBox     = $false
    TopMost         = $false
}

# --- GUI ELEMENTS ---
$lblInput    = New-EcoLabel "1. Select what to archive:" 20 20 -Font $fBold
$btnFile     = New-EcoButton "Add FILE" 20 45 230 30
$btnFolder   = New-EcoButton "Add FOLDER" 255 45 230 30
$lblSelected = New-EcoLabel "Selected: none" 20 82 465 20 $fItalic ([System.Drawing.Color]::DimGray)

$lblTarget = New-EcoLabel "2. Destination archive path:" 20 112 -Font $fBold

$txtTarget = N "System.Windows.Forms.TextBox" @{
    Location  = P 20 137
    Size      = S 395 23
    Font      = $fNormal
    ReadOnly  = $true
    BackColor = $cBg
}

$btnTarget = New-EcoButton "..." 422 136 63 24

$lblComp = New-EcoLabel "3. Choose native TAR/ZSTD profile:" 20 188 -Font $fBold

$btnStore = New-EcoButton `
    "STORE" 20 213 150 42 $fBold `
    ([System.Drawing.Color]::Firebrick) `
    ([System.Drawing.Color]::White)

$btnNormal = New-EcoButton `
    "NORMAL" 180 213 150 42 $fBold `
    ([System.Drawing.Color]::DarkOrange) `
    ([System.Drawing.Color]::White)

$btnExtreme = New-EcoButton `
    "EXTREME" 340 213 145 42 $fBold `
    ([System.Drawing.Color]::DarkViolet) `
    ([System.Drawing.Color]::White)

$chkOpenFolder = N "System.Windows.Forms.CheckBox" @{
    Text      = "Open output folder after success"
    Location  = P 20 280
    Size      = S 300 22
    Font      = $fNormal
    BackColor = $cBg
    ForeColor = $cTxt
    Checked   = $true
}

$lblStatus = New-EcoLabel "Ready." 20 325 465 20 $fItalic ([System.Drawing.Color]::DimGray)

$form.Controls.AddRange([System.Windows.Forms.Control[]]@(
    $lblInput,
    $btnFile,
    $btnFolder,
    $lblSelected,
    $lblTarget,
    $txtTarget,
    $btnTarget,
    $lblComp,
    $btnStore,
    $btnNormal,
    $btnExtreme,
    $chkOpenFolder,
    $lblStatus
))

# --- PATH HELPERS ---
function Remove-KnownArchiveExtension {
    param([string]$Path)

    $fileName = [System.IO.Path]::GetFileName($Path)

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        return ""
    }

    if ($fileName -match '(?i)\.(tar\.zst|tzst|tar)$') {
        return ($fileName -replace '(?i)\.(tar\.zst|tzst|tar)$', '')
    }

    return [System.IO.Path]::GetFileNameWithoutExtension($fileName)
}

function Get-DefaultTargetPath {
    param(
        [string]$SourcePath,
        [string]$Extension
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        return ""
    }

    return "$SourcePath$Extension"
}

function Set-TargetExtension {
    param(
        [ValidateSet("Store", "Normal", "Extreme")]
        [string]$Mode
    )

    if ([string]::IsNullOrWhiteSpace($script:selectedPath)) {
        return
    }

    $extension = $modes[$Mode].Ext

    if ([string]::IsNullOrWhiteSpace($txtTarget.Text)) {
        $txtTarget.Text = Get-DefaultTargetPath $script:selectedPath $extension
        return
    }

    $current = $txtTarget.Text.Trim('"')
    $dir = [System.IO.Path]::GetDirectoryName($current)

    if ([string]::IsNullOrWhiteSpace($dir)) {
        $dir = $scriptDir
    }

    $baseName = Remove-KnownArchiveExtension $current

    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = "ZSTD_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    }

    $txtTarget.Text = Join-Path $dir ($baseName + $extension)
}

function Set-SelectedPath {
    param(
        [string]$Path,
        [ValidateSet("File", "Folder")]
        [string]$Type
    )

    $script:selectedPath = $Path
    $lblSelected.Text = "Selected: $script:selectedPath"

    $btnFile.BackColor = if ($Type -eq "File") {
        [System.Drawing.Color]::LightBlue
    }
    else {
        $cBg
    }

    $btnFolder.BackColor = if ($Type -eq "Folder") {
        [System.Drawing.Color]::LightBlue
    }
    else {
        $cBg
    }

    $txtTarget.Text = Get-DefaultTargetPath $script:selectedPath ".tar.zst"
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

    $tarPath  = [string]$config.TarPath
    $source   = [string]$config.SourcePath
    $dest     = [string]$config.DestinationPath
    $extra    = @($config.TarArgsExtra) | Where-Object { $_ }

    if (-not (Test-Path -LiteralPath $tarPath)) {
        throw "tar.exe was not found."
    }

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source path does not exist."
    }

    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Force
    }

    $parent = Split-Path -Parent $source
    $leaf   = Split-Path -Leaf $source

    if ([string]::IsNullOrWhiteSpace($parent)) {
        $parent = (Get-Location).Path
    }

    $tarArgs = @($extra) + @("-cf", $dest, "-C", $parent, $leaf)

    & $tarPath @tarArgs 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe exited with code $LASTEXITCODE"
    }

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
    }
    finally {
        $dialog.Dispose()
    }
})

$btnFolder.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select folder to archive"

    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Set-SelectedPath $dialog.SelectedPath "Folder"
        }
    }
    finally {
        $dialog.Dispose()
    }
})

$btnTarget.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = "Select destination archive"
    $dialog.Filter = "TAR+ZSTD Archive (*.tar.zst)|*.tar.zst|TAR Archive (*.tar)|*.tar|All files (*.*)|*.*"
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
    }
    finally {
        $dialog.Dispose()
    }
})

# --- EXECUTION ENGINE ---
function Execute-Archive {
    param(
        [ValidateSet("Store", "Normal", "Extreme")]
        [string]$Mode
    )

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

    Set-TargetExtension $Mode

    $modeData   = $modes[$Mode]
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

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    Set-AppStatus "In progress..." ([System.Drawing.Color]::DarkOrange)

    $guid = [guid]::NewGuid().ToString("N")
    $workerScript = Join-Path $env:TEMP "zstd_worker_$guid.ps1"
    $configPath   = Join-Path $env:TEMP "zstd_config_$guid.json"

    New-WorkerScript $workerScript

    [PSCustomObject]@{
        TarPath         = $tarPath
        SourcePath      = $script:selectedPath
        DestinationPath = $targetPath
        Mode            = $Mode
        ModeText        = $modeData.Text
        TarArgsExtra    = @($modeData.Args)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

    $success = $false
    $errorMessage = $null
    $proc = $null

    try {
        $procInfo = N "System.Diagnostics.ProcessStartInfo" @{
            FileName         = $psExe
            Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ConfigPath "{1}"' -f $workerScript, $configPath
            WorkingDirectory = $scriptDir
            UseShellExecute  = $false
            CreateNoWindow   = $true
            WindowStyle      = [System.Diagnostics.ProcessWindowStyle]::Hidden
        }

        $proc = [System.Diagnostics.Process]::Start($procInfo)
        $proc.WaitForExit()

        $success = ($proc.ExitCode -eq 0)
    }
    catch {
        $errorMessage = $_.Exception.Message
    }
    finally {
        if ($proc) {
            $proc.Dispose()
        }

        foreach ($file in @($workerScript, $configPath)) {
            if (Test-Path -LiteralPath $file) {
                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($success) {
        Set-AppStatus "Operation successful." ([System.Drawing.Color]::Green)

        if ($chkOpenFolder.Checked) {
            explorer.exe "/select,`"$targetPath`""
        }

        return
    }

    Set-AppStatus "Operation failed or aborted." ([System.Drawing.Color]::Red)

    $message = "Operation failed or aborted."

    if ($errorMessage) {
        $message += "`n`n$errorMessage"
    }

    Msg $message "Archive Error" ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

# --- BUTTON ACTIONS ---
$btnStore.Add_Click({
    Execute-Archive "Store"
})

$btnNormal.Add_Click({
    Execute-Archive "Normal"
})

$btnExtreme.Add_Click({
    Execute-Archive "Extreme"
})

# --- CLEANUP ---
$form.Add_FormClosing({
    $fNormal.Dispose()
    $fBold.Dispose()
    $fItalic.Dispose()
})

[System.Windows.Forms.Application]::Run($form)