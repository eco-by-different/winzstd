param([string]$WorkerConfigFile = '')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function P($X, $Y) { [System.Drawing.Point]::new($X, $Y) }
function S($W, $H) { [System.Drawing.Size]::new($W, $H) }
function N {
param([string]$Type, [hashtable]$Props)
$obj = New-Object "System.Windows.Forms.$Type"
foreach ($key in $Props.Keys) { $obj.$key = $Props[$key] }
$obj
}
function TB([string]$Text){[string]::IsNullOrWhiteSpace($Text)}
function ET($e){
if($null-eq$e){return'Unknown error.'}
$t=[string]$e.Exception.Message
if(TB $t){$t=[string]$e}
$t.Trim()
}
function G{[guid]::NewGuid().ToString('N')}
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }
if (TB $scriptDir) { $scriptDir = (Get-Location).Path }
$hostPath = [Environment]::GetCommandLineArgs()[0]
$isCompiledExe = ([IO.Path]::GetExtension($hostPath) -ieq '.exe') -and
([IO.Path]::GetFileName($hostPath) -notmatch '^(powershell|pwsh)(\.exe)?$')
$selfPath = if ($isCompiledExe) {
[IO.Path]::GetFullPath($hostPath)
} elseif ($PSCommandPath) {
$PSCommandPath
} else {
$MyInvocation.MyCommand.Path
}
if ($isCompiledExe) { $scriptDir = Split-Path -Parent $selfPath }
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$tarPath = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $tarPath)) {
$cmdTar = Get-Command 'tar.exe' -EA SilentlyContinue
if ($cmdTar -and $cmdTar.Source) { $tarPath = $cmdTar.Source }
}
function Write-WorkerResult {
param([string]$Path,$Data)
$Data | ConvertTo-Json -Compress | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Invoke-TarCapture {
param([string]$Exe,[object[]]$Arguments)
$output = & $Exe @Arguments 2>&1
[pscustomobject]@{
ExitCode = [int]$LASTEXITCODE
Output = (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}
}
if (-not (TB $WorkerConfigFile)) {
$cfg = $null
$tempDest = ''
try {
$cfg = Get-Content -LiteralPath $WorkerConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$resultPath = [string]$cfg.ResultPath
$sourceRequested = [IO.Path]::GetFullPath([string]$cfg.SourcePath)
$dest = [IO.Path]::GetFullPath([string]$cfg.DestinationPath)
$workerTar = [string]$cfg.TarPath
$level = [Math]::Max(0, [Math]::Min(22, [int]$cfg.CompressionLevel))
$threads = [Math]::Max(1, [int]$cfg.Threads)
$useZstd = ($level -gt 0)
$useTar = ($level -eq 0) -or [bool]$cfg.UseTar
if (-not (Test-Path -LiteralPath $workerTar -PathType Leaf)) { throw 'tar.exe was not found.' }
if (-not (Test-Path -LiteralPath $sourceRequested)) { throw 'Source path does not exist.' }
$sourceItem = Get-Item -LiteralPath $sourceRequested -Force -EA Stop
if (-not $useTar -and $sourceItem.PSIsContainer) { throw 'Direct ZSTD compression supports a single file only.' }
$source = [string]$sourceItem.FullName
$destDir = Split-Path -Parent $dest
if ((TB $destDir) -or -not (Test-Path -LiteralPath $destDir -PathType Container)) {
throw "Destination directory does not exist: $destDir"
}
if (-not $sourceItem.PSIsContainer -and $source.Equals($dest, [System.StringComparison]::OrdinalIgnoreCase)) {
throw 'Source and destination cannot be the same path.'
}
if ($sourceItem.PSIsContainer) {
$sourcePrefix = $source.TrimEnd([char]92,[char]47) + [IO.Path]::DirectorySeparatorChar
if ($dest.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
throw 'The destination archive cannot be created inside the folder being archived.'
}
}
$suffix = if ($level -eq 0) { '.tar' } elseif ($useTar) { '.tar.zst' } else { '.zst' }
$tempDest = Join-Path $destDir ('.winzstd_' + (G) + $suffix)
$sourceRoot = [IO.Path]::GetPathRoot($source)
$sourceKey = $source.TrimEnd([char]92,[char]47)
$rootKey = ([string]$sourceRoot).TrimEnd([char]92,[char]47)
$isDriveRoot = $sourceItem.PSIsContainer -and $sourceKey.Equals($rootKey,[System.StringComparison]::OrdinalIgnoreCase)
if ($isDriveRoot) {
$parent = ([string]$sourceRoot).Replace([char]92,[char]47)
$skip = @('System Volume Information','$RECYCLE.BIN','Recovery','Documents and Settings')
$members = @(
Get-ChildItem -LiteralPath $source -Force -EA Stop |
Where-Object { $skip -notcontains $_.Name } |
ForEach-Object { [string]$_.Name }
)
if ($members.Count -lt 1) { throw 'The selected drive root contains no archivable items.' }
}
elseif ($sourceItem.PSIsContainer) {
$parent = [string]$sourceItem.Parent.FullName
$members = @([string]$sourceItem.Name)
}
else {
$parent = [string]$sourceItem.DirectoryName
$members = @([string]$sourceItem.Name)
}
if (TB $parent) { throw 'Cannot determine the source parent directory.' }
foreach ($member in $members) {
if (TB $member) { throw 'The source member list contains an empty item.' }
if (-not (Test-Path -LiteralPath (Join-Path $parent $member))) {
throw "Resolved source member no longer exists: $member"
}
}
$usedThreads = if ($useZstd) { $threads } else { 1 }
$base = @()
if ($useZstd) {
$options = 'zstd:compression-level=' + $level
if ($threads -gt 1) { $options += ',zstd:threads=' + $threads }
$base = @($(if($useTar){'--format=pax'}else{'--format=raw'}),'--zstd','--options',$options)
}
$tarArguments = @($base) + @('-cf',$tempDest,'-C',$parent) + @($members)
$run = Invoke-TarCapture $workerTar $tarArguments
if ($run.ExitCode -ne 0) {
$detail = [string]$run.Output
if (TB $detail) { $detail = 'tar.exe returned no diagnostic text.' }
throw "tar.exe exited with code $($run.ExitCode).`n`n$detail"
}
if (-not (Test-Path -LiteralPath $tempDest -PathType Leaf)) { throw 'tar.exe reported success, but no archive was created.' }
$tempInfo = Get-Item -LiteralPath $tempDest -Force
if ($tempInfo.Length -le 0) { throw 'The created archive is empty.' }
if (Test-Path -LiteralPath $dest -PathType Leaf) {
$backup = Join-Path $destDir ('.winzstd_backup_' + (G) + '.tmp')
try {
[IO.File]::Replace($tempDest, $dest, $backup, $true)
Remove-Item -LiteralPath $backup -Force -EA SilentlyContinue
}
catch {
Remove-Item -LiteralPath $backup -Force -EA SilentlyContinue
throw "The new archive was created, but the existing destination could not be replaced safely.`n`n$(ET $_)"
}
}
else {
Move-Item -LiteralPath $tempDest -Destination $dest -Force -EA Stop
}
$tempDest = ''
$finalInfo = Get-Item -LiteralPath $dest -Force -EA Stop
Write-WorkerResult $resultPath ([ordered]@{
Success = $true
Message = 'Archive created successfully.'
ExitCode = 0
ArchiveBytes = [int64]$finalInfo.Length
ThreadsUsed = $usedThreads
})
exit 0
}
catch {
if (-not (TB $tempDest)) { Remove-Item -LiteralPath $tempDest -Force -EA SilentlyContinue }
$message = ET $_
if ($cfg -and -not (TB ([string]$cfg.ResultPath))) {
Write-WorkerResult ([string]$cfg.ResultPath) ([ordered]@{
Success = $false
Message = $message
ExitCode = 2
})
}
exit 2
}
}
if (-not ('EcoConsoleWindow' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class EcoConsoleWindow {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
}
$consolePtr = [EcoConsoleWindow]::GetConsoleWindow()
if ($consolePtr -ne [IntPtr]::Zero) { [EcoConsoleWindow]::ShowWindow($consolePtr, 0) >$null }
[System.Windows.Forms.Application]::EnableVisualStyles()
$cBg,$cSurface,$cInput,$cTxt,$cTxtMuted,$cTxtDisabled,$cButtonText,$cBorder,
$cRoyal,$cRoyalHover,$cRoyalActive,$cSuccess,$cSuccessHover,$cSuccessDown,
$cSuccessText,$cWarning,$cDanger,$cExtreme,$cStatusOk =
'191B20|242832|15171C|E3E6EB|A9B1BF|707986|F2F4F7|505968|4B6698|607DB0|38527E|477B5E|56896B|37664B|EEF7F1|D0A354|C65E62|9B70C8|72B88A'.Split('|') |
ForEach-Object { [System.Drawing.ColorTranslator]::FromHtml("#$_") }
$fNormal=[System.Drawing.Font]::new('Segoe UI',9); $fBold=[System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
$fItalic=[System.Drawing.Font]::new('Segoe UI',9,[System.Drawing.FontStyle]::Italic)
$script:selectedPath=''; $script:selectedType=''; $script:isBusy=$false
$script:currentProcess=$null; $script:currentWorkRoot=''; $script:currentResult=''
$script:pendingTarget=''
function L {
param([string]$Text,[int]$X,[int]$Y,[int]$W=470,[int]$H=20,[System.Drawing.Font]$Font=$fNormal,[System.Drawing.Color]$ForeColor=$cTxt)
N 'Label' @{Text=$Text;Location=P $X $Y;Size=S $W $H;Font=$Font;ForeColor=$ForeColor;BackColor=[System.Drawing.Color]::Transparent}
}
function B {
param([string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H,[System.Drawing.Font]$Font=$fNormal,[System.Drawing.Color]$BackColor=$cSurface,[System.Drawing.Color]$ForeColor=$cTxt)
$b=N 'Button' @{Text=$Text;Location=P $X $Y;Size=S $W $H;Font=$Font;BackColor=$BackColor;ForeColor=$ForeColor;UseVisualStyleBackColor=$false;FlatStyle=[System.Windows.Forms.FlatStyle]::Flat;Cursor=[System.Windows.Forms.Cursors]::Hand}
try{$b.FlatAppearance.BorderSize=1;$b.FlatAppearance.BorderColor=$cBorder;$b.FlatAppearance.MouseOverBackColor=$cRoyalHover;$b.FlatAppearance.MouseDownBackColor=$cRoyalActive}catch{}
$b
}
function C {
param([string]$Text,[int]$X,[int]$Y,[int]$W,[bool]$Checked=$true)
N 'CheckBox' @{Text=$Text;Location=P $X $Y;Size=S $W 22;Font=$fNormal;BackColor=$cBg;ForeColor=$cTxt;Checked=$Checked;UseVisualStyleBackColor=$false;Cursor=[System.Windows.Forms.Cursors]::Hand}
}
function Msg {
param([string]$Message,[string]$Title='WinZSTD 1.2.3 Royal Black Noir',[System.Windows.Forms.MessageBoxIcon]$Icon=[System.Windows.Forms.MessageBoxIcon]::Information,[System.Windows.Forms.MessageBoxButtons]$Buttons=[System.Windows.Forms.MessageBoxButtons]::OK)
[System.Windows.Forms.MessageBox]::Show($Message,$Title,$Buttons,$Icon)
}
function Err($m,$t){Msg $m $t ([System.Windows.Forms.MessageBoxIcon]::Error)>$null}
function Set-AppStatus { param([string]$Text,[System.Drawing.Color]$Color=$cTxtMuted) $lblStatus.Text=$Text;$lblStatus.ForeColor=$Color;$form.Refresh() }
function Format-Bytes { param([int64]$Bytes) if($Bytes-ge 1GB){'{0:N2} GB'-f($Bytes/1GB)}elseif($Bytes-ge 1MB){'{0:N2} MB'-f($Bytes/1MB)}elseif($Bytes-ge 1KB){'{0:N2} KB'-f($Bytes/1KB)}else{"$Bytes B"} }
function Get-CompressionProfile {
$level=[Math]::Max(0,[Math]::Min(22,[int]$trkCompression.Value))
$forceTar=($script:selectedType-eq'Folder'-or$level-eq 0)
$useTar=$forceTar-or[bool]$chkTarBeforeZstd.Checked
if($level-eq 0){return @{Level=0;ForceTar=$true;Text='STORE / TAR';Ext='.tar';Color=$cDanger;Filter='TAR Archive (*.tar)|*.tar';DefaultExt='tar'}}
$ext=if($useTar){'.tar.zst'}else{'.zst'}
@{Level=$level;ForceTar=$forceTar;Text=if($useTar){"TAR.ZST level $level"}else{"ZST level $level"};Ext=$ext;Color=if($level-ge18){$cExtreme}elseif($level-ge8){$cWarning}else{$cStatusOk};Filter=if($useTar){'TAR+ZSTD Archive (*.tar.zst)|*.tar.zst'}else{'ZSTD Archive (*.zst)|*.zst'};DefaultExt=$ext.TrimStart('.')}
}
$form=N 'Form' @{Text='WinZSTD 1.2.3 - powered by Windows TAR.exe';ClientSize=S 505 470;StartPosition='CenterScreen';BackColor=$cBg;ForeColor=$cTxt;FormBorderStyle='FixedSingle';MaximizeBox=$false;TopMost=$false}
$lblInput=L '1. Select what to archive:' 20 20 -Font $fBold
$btnFile=B 'Add FILE' 20 48 230 30; $btnFolder=B 'Add FOLDER' 255 48 230 30
$lblSelected=L 'Selected: none' 20 88 465 20 $fItalic $cTxtMuted; $lblSelected.AutoEllipsis=$true;$lblSelected.UseMnemonic=$false
$lblTarget=L '2. Destination archive path:' 20 125 -Font $fBold
$txtTarget=N 'TextBox' @{Location=P 20 153;Size=S 395 23;Font=$fNormal;ReadOnly=$true;BackColor=$cInput;ForeColor=$cTxt;BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;TabStop=$false;HideSelection=$true}
$btnTarget=B '...' 422 152 63 24
$grpCompression=N 'GroupBox' @{Text='3. Compression settings';Location=P 20 195;Size=S 465 120;Font=$fBold;ForeColor=$cTxt;BackColor=$cSurface}
$trkCompression=N 'TrackBar' @{Location=P 15 22;Size=S 435 45;Minimum=0;Maximum=22;Value=11;TickFrequency=1;SmallChange=1;LargeChange=3;BackColor=$cSurface;ForeColor=$cTxt}
$lblCompHint=L '0 = STORE / .tar    |    1-22 = .tar.zst compression' 18 68 425 20 $fItalic $cTxtMuted
$lblCompValue=L 'Selected: TAR.ZST level 11' 18 94 425 20 $fBold $cWarning
$grpCompression.Controls.AddRange([System.Windows.Forms.Control[]]@($trkCompression,$lblCompHint,$lblCompValue))
$btnCreate=B 'CREATE ARCHIVE' 20 330 465 38 $fBold $cSuccess $cSuccessText
try{$btnCreate.FlatAppearance.MouseOverBackColor=$cSuccessHover;$btnCreate.FlatAppearance.MouseDownBackColor=$cSuccessDown}catch{}
$chkTarBeforeZstd=C 'Create .tar before ZSTD' 20 383 210 $true
$chkOpenFolder=C 'Open output folder after success' 296 383 230 $true
$lblStatus=L 'Ready.' 20 417 465 20 $fItalic $cTxtMuted
$progressBar=N 'ProgressBar' @{Location=P 20 445;Size=S 465 8;Style=[System.Windows.Forms.ProgressBarStyle]::Marquee;MarqueeAnimationSpeed=0;Visible=$false}
$form.Controls.AddRange([System.Windows.Forms.Control[]]@($lblInput,$btnFile,$btnFolder,$lblSelected,$lblTarget,$txtTarget,$btnTarget,$grpCompression,$btnCreate,$chkTarBeforeZstd,$chkOpenFolder,$lblStatus,$progressBar))
function Remove-KnownArchiveExtension {
param([string]$Path)
$name=[IO.Path]::GetFileName($Path)
if(TB $name){return ''}
$name-replace'(?i)\.(tar\.zst|tzst|zst|tar)$',''
}
function Set-TargetExtension {
param([string]$Extension)
if(TB $script:selectedPath){return}
if(TB $txtTarget.Text){$txtTarget.Text="$script:selectedPath$Extension";return}
$current=$txtTarget.Text.Trim('"');$dir=[IO.Path]::GetDirectoryName($current);$base=Remove-KnownArchiveExtension $current
if(TB $dir){$dir=$scriptDir};if(TB $base){$base='WinZSTD_{0}'-f(Get-Date -Format 'yyyyMMdd_HHmmss')}
$txtTarget.Text=Join-Path $dir ($base+$Extension)
}
function Update-CompressionUi {
$profile=Get-CompressionProfile
if($profile.ForceTar){$chkTarBeforeZstd.Checked=$true}
$chkTarBeforeZstd.Enabled=(-not$profile.ForceTar)-and(-not$script:isBusy)
$chkTarBeforeZstd.ForeColor=if($chkTarBeforeZstd.Enabled){$cTxt}else{$cTxtDisabled}
$lblCompValue.Text="Selected: $($profile.Text)";$lblCompValue.ForeColor=$profile.Color
if(-not(TB $script:selectedPath)){Set-TargetExtension $profile.Ext}
}
function Set-SelectedPath {
param([string]$Path,[ValidateSet('File','Folder')][string]$Type)
$script:selectedPath=[IO.Path]::GetFullPath($Path);$script:selectedType=$Type;$lblSelected.Text="Selected: $script:selectedPath"
$btnFile.BackColor=if($Type-eq'File'){$cRoyal}else{$cSurface};$btnFolder.BackColor=if($Type-eq'Folder'){$cRoyal}else{$cSurface}
Update-CompressionUi;$profile=Get-CompressionProfile;$txtTarget.Text="$script:selectedPath$($profile.Ext)"
}
function Set-UiBusy {
param([bool]$Busy)
$script:isBusy=$Busy
foreach($c in @($btnFile,$btnFolder,$btnTarget,$btnCreate,$trkCompression,$chkOpenFolder)){$c.Enabled=-not$Busy}
if($Busy){$chkTarBeforeZstd.Enabled=$false;$btnCreate.Text='ARCHIVING...';$progressBar.Visible=$true;$progressBar.MarqueeAnimationSpeed=25}
else{$btnCreate.Text='CREATE ARCHIVE';$progressBar.MarqueeAnimationSpeed=0;$progressBar.Visible=$false;Update-CompressionUi}
}
function Remove-CurrentWork {
if((-not (TB $script:currentWorkRoot)) -and (Test-Path -LiteralPath $script:currentWorkRoot)){Remove-Item -LiteralPath $script:currentWorkRoot -Recurse -Force -EA SilentlyContinue}
}
function Clear-WorkerState {
try{if($script:currentProcess){$script:currentProcess.Dispose()}}catch{}
$script:currentProcess=$null;$script:currentWorkRoot='';$script:currentResult='';$script:pendingTarget=''
}
function Stop-WorkerTree {
if(-not$script:currentProcess){return}
try{if(-not$script:currentProcess.HasExited){& taskkill.exe /PID $script:currentProcess.Id /T /F 2>$null>$null}}catch{try{$script:currentProcess.Kill()}catch{}}
}
function Read-WorkerResult {
for($i=0;$i-lt20;$i++){
if(Test-Path -LiteralPath $script:currentResult){try{return Get-Content -LiteralPath $script:currentResult -Raw -Encoding UTF8|ConvertFrom-Json}catch{}}
Start-Sleep -Milliseconds 50
}
return $null
}
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=250
$timer.Add_Tick({
if(-not$script:currentProcess){return}
if(-not$script:currentProcess.HasExited){return}
$timer.Stop();$exitCode=$script:currentProcess.ExitCode;$result=Read-WorkerResult;$target=$script:pendingTarget
Set-UiBusy $false
if($result -and [bool]$result.Success -and $exitCode -eq 0){
$extra="Size: $(Format-Bytes ([int64]$result.ArchiveBytes)) | Threads: $($result.ThreadsUsed)"
Set-AppStatus "Operation successful. $extra" $cStatusOk
Remove-CurrentWork;Clear-WorkerState
if($chkOpenFolder.Checked -and (Test-Path -LiteralPath $target)){explorer.exe "/select,`"$target`""}
}else{
$message=if($result -and -not (TB ([string]$result.Message))){[string]$result.Message}else{"Worker ended without a valid result. Exit code: $exitCode"}
Set-AppStatus 'Operation failed or aborted.' $cDanger
Remove-CurrentWork;Clear-WorkerState
Err $message 'Archive Error'
}
})
function Start-ArchiveWorker {
param([string]$TargetPath,[int]$Level,[bool]$UseTar)
$root=Join-Path $env:TEMP ('winzstd_'+(G))
[IO.Directory]::CreateDirectory($root)>$null
$config=Join-Path $root 'config.json';$result=Join-Path $root 'result.json'
$threads=[Math]::Max(1,[Math]::Min(8,[Environment]::ProcessorCount))
[pscustomobject]@{TarPath=$tarPath;SourcePath=$script:selectedPath;DestinationPath=$TargetPath;CompressionLevel=$Level;Threads=$threads;UseTar=$UseTar;ResultPath=$result}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $config -Encoding UTF8
if(TB $selfPath){throw 'The application must be started from a saved .ps1 file.'}
$psi=New-Object System.Diagnostics.ProcessStartInfo
$psi.UseShellExecute= $false
$psi.CreateNoWindow= $true
$psi.WindowStyle= [System.Diagnostics.ProcessWindowStyle]::Hidden
$psi.WorkingDirectory= $scriptDir
if ($isCompiledExe) {
$psi.FileName= $selfPath
$psi.Arguments= '-WorkerConfigFile "{0}"' -f $config
} else {
$psi.FileName= $psExe
$psi.Arguments= '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -WorkerConfigFile "{1}"' -f $selfPath,$config
}
$proc=[System.Diagnostics.Process]::Start($psi)
if ($null -eq $proc) { throw 'Unable to start the archive worker.' }
$script:currentProcess=$proc;$script:currentWorkRoot=$root;$script:currentResult=$result;$script:pendingTarget=$TargetPath
Set-UiBusy $true;Set-AppStatus 'Starting archive worker...' $cWarning;$timer.Start()
}
function Execute-Archive {
if($script:isBusy){return}
if(-not(Test-Path -LiteralPath $tarPath -PathType Leaf)){Err 'tar.exe was not found.' 'Missing TAR Engine';return}
if((TB $script:selectedPath) -or (TB $txtTarget.Text)){Msg 'Please select input and destination paths.' 'Missing Parameters' ([System.Windows.Forms.MessageBoxIcon]::Warning)>$null;return}
if(-not(Test-Path -LiteralPath $script:selectedPath)){Err 'Selected input path does not exist.' 'Input Error';return}
Update-CompressionUi;$profile=Get-CompressionProfile;Set-TargetExtension $profile.Ext
try{$target=[IO.Path]::GetFullPath($txtTarget.Text.Trim('"'))}catch{Err (ET $_) 'Destination Error';return}
$targetDir=Split-Path -Parent $target
if((TB $targetDir) -or -not (Test-Path -LiteralPath $targetDir -PathType Container)){Err "Destination directory does not exist:`n$targetDir" 'Destination Error';return}
$source=[IO.Path]::GetFullPath($script:selectedPath)
if($source.Equals($target,[System.StringComparison]::OrdinalIgnoreCase)){Err 'Source and destination cannot be the same path.' 'Invalid Destination';return}
if($script:selectedType-eq'Folder'){$prefix=$source.TrimEnd([char]92,[char]47)+[IO.Path]::DirectorySeparatorChar;if($target.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)){Err 'The destination archive cannot be created inside the folder being archived.' 'Invalid Destination';return}}
if(Test-Path -LiteralPath $target){$answer=Msg 'Target archive already exists. Replace it after the new archive is created successfully?' 'Replace Archive' ([System.Windows.Forms.MessageBoxIcon]::Warning) ([System.Windows.Forms.MessageBoxButtons]::YesNo);if($answer-ne[System.Windows.Forms.DialogResult]::Yes){return}}
try{Start-ArchiveWorker $target $profile.Level ($profile.ForceTar-or[bool]$chkTarBeforeZstd.Checked)}catch{Remove-CurrentWork;Clear-WorkerState;Set-UiBusy $false;Err (ET $_) 'Worker Error'}
}
$btnFile.Add_Click({if($script:isBusy){return};$d=New-Object System.Windows.Forms.OpenFileDialog;$d.Title='Select file to archive';try{if($d.ShowDialog()-eq[System.Windows.Forms.DialogResult]::OK){Set-SelectedPath $d.FileName 'File'}}finally{$d.Dispose()}})
$btnFolder.Add_Click({if($script:isBusy){return};$d=New-Object System.Windows.Forms.FolderBrowserDialog;$d.Description='Select folder to archive';try{if($d.ShowDialog()-eq[System.Windows.Forms.DialogResult]::OK){Set-SelectedPath $d.SelectedPath 'Folder'}}finally{$d.Dispose()}})
$btnTarget.Add_Click({
if($script:isBusy){return};$profile=Get-CompressionProfile
$d=New-Object System.Windows.Forms.SaveFileDialog;$d.Title='Select destination archive';$d.OverwritePrompt=$true;$d.AddExtension=$true
$d.Filter=$profile.Filter;$d.DefaultExt=$profile.DefaultExt
try{if(-not(TB $txtTarget.Text)){$d.FileName=[IO.Path]::GetFileName($txtTarget.Text);$dir=[IO.Path]::GetDirectoryName($txtTarget.Text);if((-not (TB $dir)) -and (Test-Path -LiteralPath $dir)){$d.InitialDirectory=$dir}};if($d.ShowDialog()-eq[System.Windows.Forms.DialogResult]::OK){$txtTarget.Text=$d.FileName}}finally{$d.Dispose()}
})
$trkCompression.Add_ValueChanged({if(-not$script:isBusy){Update-CompressionUi}})
$chkTarBeforeZstd.Add_CheckedChanged({if(-not$script:isBusy){Update-CompressionUi}})
$btnCreate.Add_Click({Execute-Archive})
$form.Add_FormClosing({
param($sender,$e)
if($script:currentProcess -and -not $script:currentProcess.HasExited){
$answer=Msg 'An archive operation is still running. Stop it and close?' 'Operation Running' ([System.Windows.Forms.MessageBoxIcon]::Warning) ([System.Windows.Forms.MessageBoxButtons]::YesNo)
if($answer-ne[System.Windows.Forms.DialogResult]::Yes){$e.Cancel=$true;return}
$timer.Stop();Stop-WorkerTree;Remove-CurrentWork;Clear-WorkerState
}
})
$form.Add_FormClosed({$timer.Stop();$timer.Dispose();$fNormal.Dispose();$fBold.Dispose();$fItalic.Dispose()})
Update-CompressionUi
[System.Windows.Forms.Application]::Run($form)