# ====================================================================
# DEGORAS-PROJECT DEVELOPMENT DRIVE SETUP SCRIPT
# --------------------------------------------------------------------
# Author: Ángel Vera Herrera
# Updated: 14/11/2025
# Version: 0.9.2
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

# PARAMETERS
# WARNINGS: - Set the letter in all scripts.
#           - Minimum size is 40GB but 50GB recommended.
# --------------------------------------------------------------------

param 
(
    [string]$driveLabel  = "DEGORAS_DEV",
    [string]$driveLetter = "E",
    [int]   $sizeGB      = 50,
    [string]$vhdPath     = "C:\DevDrives"
)

# FUNCTIONS
# --------------------------------------------------------------------

function Write-NoFormat
{
    param ($msg)
    Write-Host $msg
    if ($globalLogFile) {Add-Content -Path $globalLogFile -Value $msg}
}

function Write-Info
{
    param ($msg)
    $ts   = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts][INFO][$msg]"
    Write-Host $line
    if ($globalLogFile) {Add-Content -Path $globalLogFile -Value $line}
}

function Write-Error 
{
    param ($msg)
    $ts   = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts][ERROR][$msg]"
    Write-Host $line
    if ($globalLogFile){Add-Content -Path $globalLogFile -Value $line}
}

function Abort-WithError 
{
    $ts   = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts][ERROR][Setup failed!]"
    Write-Host $line
    if ($globalLogFile){Add-Content -Path $globalLogFile -Value $line}
    Write-Host ""
    Write-Host "Press any key to exit..."
    [void][System.Console]::ReadKey($true)
    $host.UI.RawUI.WindowTitle = $originalTitle
    exit 1
}

function Test-IsAdministrator 
{
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ScriptDirectory 
{
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } else {
        return Split-Path -Parent (Convert-Path -LiteralPath ([System.Environment]::GetCommandLineArgs()[0]))
    }
}

function Disable-HWDetection 
{
    Write-Info "Stopping ShellHWDetection service (to avoid format popup)..."
    try {
        Stop-Service -Name ShellHWDetection -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Could not stop ShellHWDetection: $_"
    }
}

function Enable-HWDetection 
{
    Write-Info "Restarting ShellHWDetection service..."
    try {
        Start-Service -Name ShellHWDetection -ErrorAction Stop
    }
    catch {
        Write-Error "Could not start ShellHWDetection: $_"
    }
}

# INITIAL PREPARATION
# --------------------------------------------------------------------

$scriptStart = Get-Date

$scriptDir          = Get-ScriptDirectory
$vhdFilePath        = Join-Path $vhdPath "${driveLabel}.vhdx"
$vhdRoot            = [System.IO.Path]::GetPathRoot($vhdPath)
$testHelloWorldsDir = Join-Path $scriptDir "code_examples/hello_worlds"
$setupScriptsDir    = Join-Path $scriptDir "scripts_env"

$timestamp       = Get-Date -Format "yyyyMMdd_HHmmss"
$logsDir         = Join-Path $scriptDir "install_logs"
if (-not (Test-Path $logsDir)){New-Item -ItemType Directory -Path $logsDir | Out-Null}
$globalLogFile   = Join-Path $logsDir "${timestamp}_devdrive-setup.log"
$globalLogFileUnix = $globalLogFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

Clear-Host
$originalTitle = $host.UI.RawUI.WindowTitle
$host.UI.RawUI.WindowTitle = "DEGORAS DevDrive Setup"

Write-NoFormat "==========================================================="
Write-NoFormat "  DEGORAS-PROJECT DEVELOPMENT DRIVE SETUP SCRIPT"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "  Author:  Angel Vera Herrera"
Write-NoFormat "  Updated: 14/11/2025"
Write-NoFormat "  Version: 0.9.2"
Write-NoFormat "================================================================="
Write-NoFormat "Parameters:"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "Drive Label        = $driveLabel"
Write-NoFormat "Drive Letter       = $driveLetter"
Write-NoFormat "Size (GB)          = $sizeGB"
Write-NoFormat "VHDX Root          = $vhdRoot"
Write-NoFormat "VHDX Path          = $vhdPath"
Write-NoFormat "VHDX Filepath      = $vhdFilePath"
Write-NoFormat "Current Path       = $scriptDir"
Write-NoFormat "Test Examples Path = $testHelloWorldsDir"
Write-NoFormat "Setup Scripts Path = $setupScriptsDir"
Write-NoFormat "================================================================="

# STEP 1: Initial checks and preparations.
# --------------------------------------------------------------------

Write-Info "STEP 1: Initial checks and preparations."

Write-Info "Checking permissions..."
if (-not (Test-IsAdministrator)) {
    Write-Error "This script must be run as Administrator."
    Abort-WithError
}

Write-Info "Checking Hyper-V PowerShell module (New-VHD)..."
try {
    $hvCmd = Get-Command New-VHD -ErrorAction SilentlyContinue
    if (-not $hvCmd) {
        Write-Error "Hyper-V PowerShell module not found. Cmdlets like New-VHD/Mount-VHD are unavailable."
        Write-Error "Please enable Hyper-V Management Tools:"
        Write-Error "  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All"
        Abort-WithError
    }
    Write-Info "Hyper-V PowerShell module available."
}
catch {
    Write-Error "Error checking Hyper-V module."
    Abort-WithError
}

Write-Info "Checking OS compatibility..."
$useDevDrive = $false
try {
    $osInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber
    Write-Info "Detected OS: $($osInfo.WindowsProductName) | Version: $($osInfo.WindowsVersion) | Build: $($osInfo.OsBuildNumber)"

    $osName  = $osInfo.WindowsProductName
    $osBuild = [int]$osInfo.OsBuildNumber
    $isWin11 = $osName -match "Windows 11"

    if ($isWin11 -and $osBuild -ge 22000) {
        $useDevDrive = $true
        Write-Info "Windows 11 detected; DevDrive features will be used."
    } else {
        $useDevDrive = $false
        Write-Info "Non-Windows 11 or old build; using NTFS VHDX mode."
    }
}
catch {
    Write-Error "Could not determine OS version."
    Abort-WithError
}

Write-Info "Checking letter format..."
if ($driveLetter -notmatch '^[A-Z]$') {
    Write-Error "Invalid drive letter format: $driveLetter"
    Abort-WithError
}

Write-Info "Checking if VHD already exists..."
if (Test-Path $vhdFilePath) {
    Write-Error "VHD already exists: $vhdFilePath"
    Abort-WithError
}

Write-Info "Checking if drive letter is in use..."
if (Get-Volume -driveLetter $driveLetter -ErrorAction SilentlyContinue) {
    Write-Error "Drive letter $driveLetter is already in use."
    Abort-WithError
}

Write-Info "Checking disk space..."
try {
    $requiredBytes = $sizeGB * 1GB
    $rootDrive     = ($vhdRoot -split ':')[0]
    $volume        = Get-Volume -DriveLetter $rootDrive -ErrorAction Stop
    $freeBytes     = $volume.SizeRemaining
    Write-Info "Available Space = $freeBytes bytes"
    Write-Info "Required Space  = $requiredBytes bytes"
    if ($freeBytes -lt $requiredBytes) {
        Write-Error "Not enough free space on drive $rootDrive"
        Abort-WithError
    }
}
catch {
    Write-Error "Could not determine free space on drive..."
    Abort-WithError
}

Write-Info "Checking VHD folder..."
if (!(Test-Path $vhdPath)) {
    Write-Info "Creating folder: $vhdPath"
    New-Item -ItemType Directory -Path $vhdPath | Out-Null
}

Write-Info "Checking examples folder..."
if (-not (Test-Path $testHelloWorldsDir)) {
    Write-Error "Examples folder not found at: $testHelloWorldsDir"
    Abort-WithError
}

Write-Info "Checking setup scripts folder..."
if (-not (Test-Path $setupScriptsDir)) {
    Write-Error "Setup scripts folder not found at: $setupScriptsDir"
    Abort-WithError
}

Write-Info "STEP 1: OK"

# STEP 2: Disable AutoplayHandlers to avoid Windows popup
# --------------------------------------------------------------------

Write-Info "STEP 2: Disable AutoplayHandlers to avoid Windows popup."
Write-Info "Disabling AutoplayHandlers temporarily..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" `
                 -Name "DisableAutoplay" -Value 1
Write-Info "STEP 2: OK"

# STEP 3: Create and Attach the VHD (New-VHD / Mount-VHD)
# --------------------------------------------------------------------

Write-Info "STEP 3: Create and Attach the VHD."

Disable-HWDetection

try {
    Write-Info "Creating dynamic VHDX at $vhdFilePath (Size = ${sizeGB}GB)..."
    New-VHD -Path $vhdFilePath -SizeBytes ($sizeGB * 1GB) -Dynamic | Out-Null
}
catch {
    Write-Error "New-VHD failed: $_"
    Abort-WithError
}

try {
    Write-Info "Mounting VHDX..."
    Mount-VHD -Path $vhdFilePath | Out-Null
}
catch {
    Write-Error "Mount-VHD failed: $_"
    Abort-WithError
}

Start-Sleep -Milliseconds 500

# Tomamos el disco RAW recién creado
$disk = Get-Disk | Where-Object PartitionStyle -Eq 'RAW' | Sort-Object Number | Select-Object -Last 1
if (-not $disk) {
    Write-Error "Could not find RAW disk for the new VHDX."
    Abort-WithError
}

Write-Info "Using Disk Number: $($disk.Number) for initialization."
Write-Info "STEP 3: OK"

# STEP 4: Initialize disk, partition and format
# --------------------------------------------------------------------

if ($useDevDrive) {
    Write-Info "STEP 4: Initialize disk and format as DevDrive (Windows 11)."

    try {
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru | `
            New-Partition -DriveLetter $driveLetter -UseMaximumSize | `
            Format-Volume -DevDrive -NewFileSystemLabel $driveLabel -Confirm:$false -Force *> $null
    }
    catch {
        Write-Error "Disk initialization/partition/format failed (DevDrive): $_"
        Abort-WithError
    }

    Start-Sleep -Milliseconds 500

    Write-Info "Trusting volume as Dev Drive..."
    fsutil devdrv trust "$driveLetter`:" *> $null

    Write-Info "Disabling antivirus for Dev Drive..."
    fsutil devdrv enable /disallowAv *> $null
}
else {
    Write-Info "STEP 4: Initialize disk and format as NTFS (Windows 10 / non-DevDrive)."

    try {
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -PassThru | `
            New-Partition -DriveLetter $driveLetter -UseMaximumSize | `
            Format-Volume -FileSystem NTFS -NewFileSystemLabel $driveLabel -Confirm:$false -Force *> $null
    }
    catch {
        Write-Error "Disk initialization/partition/format failed (NTFS): $_"
        Abort-WithError
    }

    Start-Sleep -Milliseconds 500

    try {
        if (Get-Command Add-MpPreference -ErrorAction SilentlyContinue) {
            Write-Info "Adding Microsoft Defender exclusion for ${driveLetter}:\ ..."
            Add-MpPreference -ExclusionPath "$driveLetter`:\" 2>$null
        }
        else {
            Write-Info "Microsoft Defender cmdlets not found; skipping AV exclusion."
        }
    }
    catch {
        Write-Error "Could not add Defender exclusion: $_"
    }
}

Write-Info "STEP 4: OK"

Enable-HWDetection

# STEP 5: Reattach (solo DevDrive)
# --------------------------------------------------------------------

if ($useDevDrive) {
    Write-Info "STEP 5: Dismount and Reattach DevDrive to apply policies."

    try {
        Write-Info "Dismounting VHDX..."
        Dismount-VHD -Path $vhdFilePath -ErrorAction Stop
        Start-Sleep -Seconds 1

        Write-Info "Re-mounting VHDX..."
        Mount-VHD -Path $vhdFilePath -ErrorAction Stop
    }
    catch {
        Write-Error "Error during Dismount-VHD / Mount-VHD: $_"
        Abort-WithError
    }

    $maxWait = 10
    $tries   = 0
    do {
        Start-Sleep -Milliseconds 500
        $volume = Get-Volume -driveLetter $driveLetter -ErrorAction SilentlyContinue
        $tries++
    } while (-not $volume -and $tries -lt $maxWait)

    if ($volume) {
        Write-Info "Dev Drive is re-mounted and ready at ${driveLetter}:"
    } else {
        Write-Error "Dev Drive did not reappear after remounting."
        Abort-WithError
    }

    Start-Sleep -Milliseconds 200
    Write-Info "STEP 5: OK"
} else {
    Write-Info "STEP 5: Skipped (standard NTFS VHDX - no DevDrive reattach needed)."
}

# STEP 6: Create Workspace Folder Structure
# --------------------------------------------------------------------

Write-Info "STEP 6: Create Workspace Folder Structure."

Write-Info "Creating workspace folder tree inside drive $driveLetter..."

$folders = 
@(
    "${driveLetter}:\deploys",
    "${driveLetter}:\buildtrees",
    "${driveLetter}:\logs\env",
    "${driveLetter}:\packages\vcpkg",
    "${driveLetter}:\overlays\triplets",
    "${driveLetter}:\overlays\ports",
    "${driveLetter}:\workspace\HelloWorlds"
)

foreach ($f in $folders) {
    if (-Not (Test-Path $f)) {
        New-Item -ItemType Directory -Path $f | Out-Null
        Write-Info "Created folder: $f"
    }
}

Write-Info "Copying bash scripts..."

$targetDir   = "${driveLetter}:"
$scriptFiles = Get-ChildItem -Path $setupScriptsDir -Filter "*.sh" -File
foreach ($script in $scriptFiles) {
    try {
        $destPath = Join-Path $targetDir $script.Name
        Copy-Item -Path $script.FullName -Destination $destPath -Force
        Write-Info "Copied: $($script.Name)"
    }
    catch {
        Write-Error "Failed to copy $($script.Name): $_"
        Abort-WithError
    }
}

Write-Info "Copying bat scripts..."

$scriptFiles = Get-ChildItem -Path $setupScriptsDir -Filter "*.bat" -File
foreach ($script in $scriptFiles) 
{
    try {
        $destPath = Join-Path $targetDir $script.Name
        Copy-Item -Path $script.FullName -Destination $destPath -Force
        Write-Info "Copied: $($script.Name)"
    }
    catch {
        Write-Error "Failed to copy $($script.Name): $_"
        Abort-WithError
    }
}

Write-Info "Copying hello worlds examples..."

$targetDir = "${driveLetter}:\workspace\HelloWorlds"
$srcDirs   = Get-ChildItem -Path $testHelloWorldsDir -Directory

foreach ($dir in $srcDirs) {
    $srcPath = $dir.FullName
    $dstPath = Join-Path $targetDir $dir.Name

    Write-Info "Copying test example: $($dir.Name) → $dstPath"
    try {
        if (Test-Path $dstPath) {
            Remove-Item -Path $dstPath -Recurse -Force
        }
        Copy-Item -Path $srcPath -Destination $dstPath -Recurse -Force
        Write-Info "Copied: $($dir.Name)"
    }
    catch {
        Write-Error "Failed to copy $($dir.Name): $_"
        Abort-WithError
    }
}

Write-Info "STEP 6: OK"

# STEP 7: Restore AutoplayHandlers 
# --------------------------------------------------------------------

Write-Info "STEP 7: Restore AutoplayHandlers."
Write-Info "Re-enabling AutoplayHandlers..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" `
                 -Name "DisableAutoplay" -Value 0
Write-Info "STEP 7: OK"

# STEP 8: Setup environment variables and shortcut
# --------------------------------------------------------------------

Write-Info "STEP 8: Setup environment variables and shortcut."

$envFilePath  = Join-Path "$driveLetter`:" "degoras-env-variables.env"
$deploysDir   = "${driveLetter}:/deploys"
$vcpkgCacheDir= "${driveLetter}:/packages/vcpkg"
$workspaceDir = "${driveLetter}:/workspace"
$buildtreesDir= "${driveLetter}:/buildtrees"

Write-Info "DEGORAS_DEVDRIVE   = ${driveLetter}:"
Write-Info "DEGORAS_DEPLOYS    = $deploysDir"
Write-Info "DEGORAS_WORKSPACE  = $workspaceDir"
Write-Info "DEGORAS_BUILDTREES = $buildtreesDir"

if (-not (Test-Path $envFilePath)) {
    New-Item -Path $envFilePath -ItemType File -Force | Out-Null
}

$envLines = @(
    "DEGORAS_DEVDRIVE=${driveLetter}:",
    "DEGORAS_DEPLOYS=$deploysDir",
    "DEGORAS_WORKSPACE=$workspaceDir",
    "DEGORAS_BUILDTREES=$buildtreesDir"
)

Write-Info "Appending environment variables to $envFilePath"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stream    = [System.IO.StreamWriter]::new($envFilePath, $true, $utf8NoBom)  
foreach ($line in $envLines) { $stream.WriteLine($line) }
$stream.Close()

Write-Info "Creating shortcut to Dev Drive on desktop..."

try {
    $volumeLabel = (Get-Volume -DriveLetter $driveLetter).FileSystemLabel
    if (-not $volumeLabel) { $volumeLabel = "DEGORAS_DEV_IMAGE" }
} catch {
    $volumeLabel = "DEGORAS_DEV_IMAGE"
}

$WshShell     = New-Object -ComObject WScript.Shell
$desktopPath  = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath ("$volumeLabel.lnk")
$shortcut     = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath   = $vhdFilePath
$shortcut.WindowStyle  = 1
$shortcut.IconLocation = "shell32.dll,8"
$shortcut.Description  = "Shortcut to VHDX image for $volumeLabel"
$shortcut.Save()

Write-Info "Shortcut created: $shortcutPath"
Write-Info "STEP 8: OK"

Start-Sleep -Milliseconds 200

# STEP 9: Configure automatic mount at startup
# --------------------------------------------------------------------

Write-Info "STEP 9: Configure automatic mount at startup."

$taskName   = $volumeLabel
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Info "Scheduled task '$taskName' already exists. Replacing..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -Command `"Mount-VHD -Path '$vhdFilePath' -ErrorAction SilentlyContinue`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Automatically mounts the DEGORAS-PROJECT development VHDX at startup." `
    -Force *> $null

Write-Info "STEP 9: OK"

# FINALIZATION
# --------------------------------------------------------------------

$scriptEnd  = Get-Date
$elapsed    = $scriptEnd - $scriptStart
$elapsedStr = ("{0:hh\:mm\:ss}" -f $elapsed)

Write-Info "DEGORAS-PROJECT Dev Drive created successfully at ${driveLetter}:"
Write-Info "TOTAL EXECUTION TIME: $($elapsed.TotalSeconds) seconds  ($elapsedStr)"

Write-Host ""
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
$host.UI.RawUI.WindowTitle = $originalTitle
