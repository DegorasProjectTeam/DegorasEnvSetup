# ====================================================================
# DEGORAS-PROJECT DEVELOPMENT DRIVE SETUP SCRIPT
# --------------------------------------------------------------------
# Author: Ángel Vera Herrera
# Updated: 08/11/2025
# Version: 0.9.0
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

# PARAMETERS
# WARNINGS: - Set the letter in all scripts.
#           - Minimum size is 40GB but 50GB recommended.
# --------------------------------------------------------------------

param 
(
    [string]$driveLabel = "DEGORAS_TEST",
    [string]$driveLetter = "T",
    [int]   $sizeGB = 40,
    [string]$vhdPath = "H:\DevDrives"
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
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts][INFO][$msg]"
    Write-Host $line
	if ($globalLogFile) {Add-Content -Path $globalLogFile -Value $line}
}

function Write-Error 
{
    param ($msg)
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts][ERROR][$msg]"
    Write-Host $line
	if ($globalLogFile){Add-Content -Path $globalLogFile -Value $line}
}

function Abort-WithError 
{
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
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
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ScriptDirectory 
{
    if ($PSScriptRoot) 
	{
        return $PSScriptRoot
    } 
	else 
	{
        return Split-Path -Parent (Convert-Path -LiteralPath ([System.Environment]::GetCommandLineArgs()[0]))
    }
}

# INITIAL PREPARATION
# --------------------------------------------------------------------

# Timing start
$scriptStart = Get-Date

# Prepare variables.
$scriptDir = Get-ScriptDirectory
$vhdFilePath = Join-Path $vhdPath "${driveLabel}.vhdx"
$vhdRoot = [System.IO.Path]::GetPathRoot($vhdPath)
$testHelloWorldsDir = Join-Path $scriptDir "code_examples/hello_worlds"
$setupScriptsDir = Join-Path $scriptDir "scripts_env"

# Prepare logging.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logsDir = Join-Path $scriptDir "install_logs"
if (-not (Test-Path $logsDir)){New-Item -ItemType Directory -Path $logsDir | Out-Null}
$globalLogFile = Join-Path $logsDir "${timestamp}_devdrive-setup.log"
$globalLogFileUnix = $globalLogFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# SCRIPT STARTUP HEADER
# --------------------------------------------------------------------

# Clear and initial logs.
Clear-Host
$originalTitle = $host.UI.RawUI.WindowTitle
$host.UI.RawUI.WindowTitle = "DEGORAS DevDrive Setup"
Write-NoFormat "==========================================================="
Write-NoFormat "  DEGORAS-PROJECT DEVELOPMENT DRIVE SETUP SCRIPT"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "  Author:  Angel Vera Herrera"
Write-NoFormat "  Updated: 08/11/2025"
Write-NoFormat "  Version: 0.9.0"
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

# Check permissions.
Write-Info "Checking permissions..."
if (-not (Test-IsAdministrator)) 
{
    Write-Error "This script must be run as Administrator."
    Abort-WithError
}

# Check drive letter format.
Write-Info "Checking letter format..."
if ($driveLetter -notmatch '^[A-Z]$') 
{
    Write-Error "Invalid drive letter format: $driveLetter"
    Abort-WithError
}

# Abort if VHD already exists.
Write-Info "Checking if VHD already exists..."
if (Test-Path $vhdFilePath) 
{
    Write-Error "VHD already exists: $vhdFilePath"
    Abort-WithError
}

# Abort if the drive letter is already in use.
Write-Info "Checking if drive letter is in use..."
if (Get-Volume -driveLetter $driveLetter -ErrorAction SilentlyContinue) 
{
    Write-Error "Drive letter $driveLetter is already in use."
    Abort-WithError
}

# Validate that the drive has enough free space
Write-Info "Checking disk space..."
try 
{
    $requiredBytes = $sizeGB * 1GB
    $rootDrive = ($vhdRoot -split ':')[0]
    $volume = Get-Volume -DriveLetter $rootDrive -ErrorAction Stop
    $freeBytes = $volume.SizeRemaining
    Write-Info "Available Space = $freeBytes bytes"
    Write-Info "Required Space  = $requiredBytes bytes"
    if ($freeBytes -lt $requiredBytes) 
	{
        Write-Error "Not enough free space on drive $rootDrive"
        Abort-WithError
    }
} 
catch 
{
    Write-Error "Could not determine free space on drive..."
    Abort-WithError
}

# Create containing folder for the VHDX if missing.
Write-Info "Checking VHD folder..."
if (!(Test-Path $vhdPath)) 
{
    Write-Info "Creating folder: $vhdPath"
    New-Item -ItemType Directory -Path $vhdPath | Out-Null
}

# Checking examples dir.
Write-Info "Checking examples folder..."
if (-not (Test-Path $testHelloWorldsDir)) 
{
    Write-Error "Examples folder not found at: $testHelloWorldsDir"
    Abort-WithError
}

# Checking examples dir.
Write-Info "Checking setup scrips folder..."
if (-not (Test-Path $setupScriptsDir)) 
{
    Write-Error "Setup scripts folder not found at: $setupScriptsDir"
    Abort-WithError
}

Write-Info "STEP 1: OK"

# STEP 2: Disable AutoplayHandlers to avoid Windows popup
# --------------------------------------------------------------------

Write-Info "STEP 2: Disable AutoplayHandlers to avoid Windows popup."

# Temporarily disable AutoPlay to avoid popup from Windows
Write-Info "Disabling AutoplayHandlers temporarily..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" `
                 -Name "DisableAutoplay" -Value 1

Write-Info "STEP 2: OK"

# STEP 3: Create and Attach the VHD using DiskPart
# --------------------------------------------------------------------

Write-Info "STEP 3: Create and Attach the VHD."

# Create and attach the VHD using DiskPart
Write-Info "Creating and attaching VHD at $vhdFilePath..."

$diskpartScript = @"
create vdisk file="$vhdFilePath" type=expandable maximum=$($sizeGB * 1024)
select vdisk file="$vhdFilePath"
attach vdisk
convert mbr
create partition primary
assign letter=$driveLetter
exit
"@
$tmp = "$env:TEMP\devdisk.txt"
$diskpartScript | Set-Content -Encoding ASCII -Path $tmp
diskpart /s $tmp | Out-Null
Remove-Item $tmp

Write-Info "STEP 3: OK"

# STEP 4: Format Partition and Register as Dev Drive
# --------------------------------------------------------------------

Write-Info "STEP 4: Format Partition and Register as Dev Drive."

$partition = Get-Partition -driveLetter $driveLetter -ErrorAction SilentlyContinue
if (-not $partition) 
{
    Write-Error "Failed to detect partition on drive $driveLetter"
    Abort-WithError
}

Start-Sleep -Milliseconds 200

Write-Info "Formatting partition as DevDrive..."
Format-Volume -driveLetter $driveLetter -DevDrive -NewFileSystemLabel $driveLabel -Confirm:$false -Force *> $null
Start-Sleep -Milliseconds 200

# Register it as a Dev Drive and disable antivirus scanning
Write-Info "Trusting volume as Dev Drive..."
fsutil devdrv trust "$driveLetter`:" *> $null

Write-Info "Disabling antivirus for Dev Drive..."
fsutil devdrv enable /disallowAv *> $null

Start-Sleep -Milliseconds 200

Write-Info "STEP 4: OK"

# STEP 5: Unmount and Reattach to Apply Policies
# --------------------------------------------------------------------

Write-Info "STEP 5: Unmount and Reattach to Apply Policies."

Write-Info "Unmounting Dev Drive temporarily to apply antivirus exclusion..."

$unmountScript = @"
select vdisk file="$vhdFilePath"
detach vdisk
exit
"@
$tmpDetach = "$env:TEMP\detach_dev.txt"
$unmountScript | Set-Content -Encoding ASCII -Path $tmpDetach
diskpart /s $tmpDetach | Out-Null
Remove-Item $tmpDetach
Start-Sleep -Seconds 1

Write-Info "Mounting Dev Drive again..."

$mountScript = @"
select vdisk file="$vhdFilePath"
attach vdisk
exit
"@
$tmpAttach = "$env:TEMP\attach_dev.txt"
$mountScript | Set-Content -Encoding ASCII -Path $tmpAttach
diskpart /s $tmpAttach | Out-Null
Remove-Item $tmpAttach

# Wait to the unit.
$maxWait = 10
$tries = 0
do 
{
    Start-Sleep -Milliseconds 500
    $volume = Get-Volume -driveLetter $driveLetter -ErrorAction SilentlyContinue
    $tries++
} while (-not $volume -and $tries -lt $maxWait)

if ($volume) 
{
    Write-Info "Dev Drive is re-mounted and ready at ${driveLetter}:"
}
else 
{
    Write-Error "Dev Drive did not reappear after remounting"
    Abort-WithError
}

Start-Sleep -Milliseconds 200

Write-Info "STEP 5: OK"

# STEP 6: Create Workspace Folder Structure
# --------------------------------------------------------------------

Write-Info "STEP 6: Create Workspace Folder Structure."

# --

Write-Info "Creating workspace folder tree inside drive $driveLetter..."

$folders = 
@(
    "${driveLetter}:\deploys",
	"${driveLetter}:\builds",
	"${driveLetter}:\logs\env",
    "${driveLetter}:\packages\vcpkg",
	"${driveLetter}:\overlays\triplets",
	"${driveLetter}:\overlays\ports",
    "${driveLetter}:\workspace",
	"${driveLetter}:\workspace\HelloWorlds"
)

foreach ($f in $folders) 
{
    if (-Not (Test-Path $f)) 
	{
        New-Item -ItemType Directory -Path $f | Out-Null
        Write-Info "Created folder: $f"
    }
}

# --

Write-Info "Copying bash scripts..."

$targetDir = "${driveLetter}:"
$scriptFiles = Get-ChildItem -Path $setupScriptsDir -Filter "*.sh" -File
foreach ($script in $scriptFiles) 
{
    try 
    {
        $destPath = Join-Path $targetDir $script.Name
        Copy-Item -Path $script.FullName -Destination $destPath -Force
        Write-Info "Copied: $($script.Name)"
    }
    catch 
    {
        Write-Error "Failed to copy $($script.Name): $_"
        Abort-WithError
    }
}

# --

Write-Info "Copying bat scripts..."

$targetDir = "${driveLetter}:"
$scriptFiles = Get-ChildItem -Path $setupScriptsDir -Filter "*.bat" -File
foreach ($script in $scriptFiles) 
{
    try 
    {
        $destPath = Join-Path $targetDir $script.Name
        Copy-Item -Path $script.FullName -Destination $destPath -Force
        Write-Info "Copied: $($script.Name)"
    }
    catch 
    {
        Write-Error "Failed to copy $($script.Name): $_"
        Abort-WithError
    }
}

# --

Write-Info "Copying hello worlds examples..."

$targetDir = "${driveLetter}:\workspace\HelloWorlds"
$srcDirs = Get-ChildItem -Path $testHelloWorldsDir -Directory

foreach ($dir in $srcDirs) 
{
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

# --

Write-Info "STEP 6: OK"

# STEP 7: Restore AutoplayHandlers 
# --------------------------------------------------------------------

Write-Info "STEP 7: Restore AutoplayHandlers."

Write-Info "Re-enabling AutoplayHandlers..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" `
                 -Name "DisableAutoplay" -Value 0

Write-Info "STEP 7: OK"

# STEP 8: Setup environment variables and shorcout
# --------------------------------------------------------------------

Write-Info "STEP 8: Setup environment variables and shortcout."

$envFilePath = Join-Path "$driveLetter`:" "degoras-env-variables.env"

$deploysDir = "${driveLetter}:/deploys"
$vcpkgCacheDir = "${driveLetter}:/packages/vcpkg"
$workspaceDir = "${driveLetter}:/workspace"

Write-Info "DEGORAS_DEVDRIVE = ${driveLetter}:"
Write-Info "DEGORAS_DEPLOYS = $deploysDir"
Write-Info "DEGORAS_WORKSPACE = $workspaceDir"
# COMPLETE IN FINAL SCRIPT (LIKE 5-DEGORAS-DEPS_INstallation.ps1 or somethink)
#Write-Info "DEGORASBASE_ROOT = "
#Write-Info "DEGORASSLR_ROOT = "

# Prepare environment variable export file
if (-not (Test-Path $envFilePath)) 
{
    New-Item -Path $envFilePath -ItemType File -Force | Out-Null
}

# Write all environment variables to a file for later use
$envLines = @(
	"DEGORAS_DEVDRIVE=${driveLetter}:"
	"DEGORAS_DEPLOYS=$deploysDir"
	"DEGORAS_WORKSPACE=$workspaceDir"
)

Write-Info "Appending environment variables to $envFilePath"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stream = [System.IO.StreamWriter]::new($envFilePath, $true, $utf8NoBom)  
foreach ($line in $envLines) {$stream.WriteLine($line)}
$stream.Close()
	
Write-Info "Creating shortcut to Dev Drive on desktop..."

# Create shortcut to the .vhdx file on desktop using the volume label
try {
    $volumeLabel = (Get-Volume -DriveLetter $driveLetter).FileSystemLabel
    if (-not $volumeLabel) { $volumeLabel = "DEGORAS_DEV_IMAGE" }
} catch {
    $volumeLabel = "DEGORAS_DEV_IMAGE"
}

$WshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath ("$volumeLabel.lnk")
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $vhdFilePath
$shortcut.WindowStyle = 1
$shortcut.IconLocation = "shell32.dll,8"
$shortcut.Description = "Shortcut to VHDX image for $volumeLabel"
$shortcut.Save()

Write-Info "Shortcut created: $shortcutPath"

Write-Info "STEP 8: OK"

Start-Sleep -Milliseconds 200

# STEP 9: Configure automatic mount at startup
# --------------------------------------------------------------------

Write-Info "STEP 9: Configure automatic mount at startup."

$taskName = $volumeLabel
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) 
{
    Write-Info "Scheduled task '$taskName' already exists. Replacing..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Define the scheduled task components
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -Command `"Mount-DiskImage -ImagePath '$vhdFilePath' -ErrorAction SilentlyContinue`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Automatically mounts te DEGORAS-PROJECT development VHD drive at startup." `
    -Force *> $null
	
Write-Info "STEP 9: OK"

# FINALIZATION
# --------------------------------------------------------------------

# Compute elapsed time
$scriptEnd = Get-Date
$elapsed = $scriptEnd - $scriptStart
$elapsedStr = ("{0:hh\:mm\:ss}" -f $elapsed)

# Final logs.
Write-Info "DEGORAS-PROJECT Dev Drive created successfully at ${driveLetter}:"
Write-Info "TOTAL EXECUTION TIME: $($elapsed.TotalSeconds) seconds  ($elapsedStr)"

# Exit
Write-Host ""
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
$host.UI.RawUI.WindowTitle = $originalTitle

# --------------------------------------------------------------------