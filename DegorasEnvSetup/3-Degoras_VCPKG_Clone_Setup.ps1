# ====================================================================
# DEGORAS-PROJECT VCPKG CLONE SETUP SCRIPT
# --------------------------------------------------------------------
# Author: Angel Vera Herrera
# Updated: 08/11/2025
# Version: 0.9.0
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

# ====================================================================
# VCPKG Baseline Datetime: 2025-11-04 10:47:08 -0800
# Baseline HEAD: 446682c6c338d68ed986972ffc3529f7d63c1555
# ====================================================================

# PARAMETERS
# --------------------------------------------------------------------

param
(
	[string]$vcpkgGitUrl = "https://github.com/microsoft/vcpkg.git",
	[string]$vcpkgBaseline = "446682c6c338d68ed986972ffc3529f7d63c1555",
    [string]$devDrive = "E",
	[string]$msys64BinPath = "E:\msys64\usr\bin"
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

function Get-FileNameFromUrl($url) 
{
    return [System.IO.Path]::GetFileName($url)
}

function Convert-ToMSYSPath($winPath) 
{
    return $winPath -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
}

# INITIAL PREPARATION
# --------------------------------------------------------------------

# Timing start
$scriptStart = Get-Date

# Prepare variables.
$scriptDir = Get-ScriptDirectory
$msys64BashPath = Join-Path $msys64BinPath "bash.exe"
$msys64GitPath  = Join-Path $msys64BinPath "git.exe"

# Prepare logging.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logsDir = Join-Path $scriptDir "install_logs"
if (-not (Test-Path $logsDir)){New-Item -ItemType Directory -Path $logsDir | Out-Null}
$globalLogFile = Join-Path $logsDir "${timestamp}_vcpkg-clone-setup.log"
$globalLogFileUnix = $globalLogFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# SCRIPT STARTUP HEADER
# --------------------------------------------------------------------

# Clear and initial logs.
Clear-Host
$originalTitle = $host.UI.RawUI.WindowTitle
$host.UI.RawUI.WindowTitle = "DEGORAS-PROJECT VCPKG Clone Setup"
Write-NoFormat "================================================================="
Write-NoFormat "  DEGORAS-PROJECT VCPKG CLONE SETUP SCRIPT"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "  Author:  Angel Vera Herrera"
Write-NoFormat "  Updated: 08/11/2025"
Write-NoFormat "  Version: 0.9.0"
Write-NoFormat "================================================================="
Write-NoFormat "Parameters:"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "Install Drive    = $devDrive"
Write-NoFormat "VCPKG Repository = $vcpkgGitUrl"
Write-NoFormat "VCPKG Baseline   = $vcpkgBaseline"
Write-NoFormat "MSYS2 bin path   = $msys64BinPath"
Write-NoFormat "-----------------------------------------------------------------"

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

# Ensure devDrive is defined and valid.
Write-Info "Checking letter format..."
if ($devDrive -notmatch '^[A-Z]$') 
{
    Write-Error "Invalid drive letter format: $driveLetter"
    Abort-WithError
}

# Normalize format to end with colon and backslash (e.g. V:\)
$driveLetterOnly = $devDrive.ToUpper()
$devDriveOnly = $devDrive
$devDrive = "$driveLetterOnly`:\"

# Check Dev Drive exists and is mounted
Write-Info "Checking if Dev Drive exists..."
try 
{
    $volume = Get-Volume -DriveLetter $driveLetterOnly -ErrorAction Stop
    Write-Info "Dev Drive detected at $devDrive"
} 
catch 
{
    Write-Error "Dev Drive '$devDrive' is not available or not mounted."
    Abort-WithError
}

Write-Info "Checking if git tool exists..."

if (-not (Test-Path $msys64GitPath)) 
{
    Write-Error "Git not found at expected MSYS2 path: $msys64GitPath"
    Abort-WithError
}

Write-Info "Checking if msys2 bash exists..."

if (-not (Test-Path $msys64BashPath)) 
{
    Write-Error "Bash not found at expected MSYS2 path: $msys64BashPath"
    Abort-WithError
}

Write-Info "STEP 1: OK"

# STEP 2: Clone vcpkg repository
# --------------------------------------------------------------------

Write-Info "STEP 2: Clone vcpkg repository."

$installRoot = "${devDrive}vcpkg"

if (Test-Path $installRoot) 
{
    Write-Info "vcpkg already exists. Skipping."
}
else
{
	# Clone the repo.
	$installRootUnix = $installRoot -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
	$bashGitCloneCmd = "git clone $vcpkgGitUrl $installRootUnix"
	$proc = Start-Process -FilePath "$msys64BashPath" `
						  -ArgumentList "-l", "-c", "`"$bashGitCloneCmd`"" `
						  -Wait -PassThru

	if ($proc.ExitCode -ne 0) 
	{
		Write-Error "Failed to clone vcpkg repository (ExitCode=$($proc.ExitCode))."
		Abort-WithError
	}

	# Ensure the repository is in a valid state
	if (-not (Test-Path "$installRoot\.git")) 
	{
		Write-Error "The vcpkg repository was not properly cloned (missing .git directory)."
		Abort-WithError
	}
}

Write-Info "Checking out baseline commit $vcpkgBaseline"
$installRootUnix = $installRoot -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$checkoutCmd = "cd $installRootUnix && git checkout $vcpkgBaseline"
$proc = Start-Process -FilePath "$msys64BashPath" `
                      -ArgumentList "-l", "-c", "`"$checkoutCmd`"" `
                      -Wait -PassThru

if ($proc.ExitCode -ne 0) 
{
    Write-Error "Failed to checkout vcpkg commit $vcpkgBaseline (ExitCode=$($proc.ExitCode))."
    Abort-WithError
}

Write-Info "vcpkg checked out to baseline $vcpkgBaseline"

Write-Info "STEP 2: OK"

# STEP 3: Bootstrap vcpkg
# --------------------------------------------------------------------

Write-Info "STEP 3: Bootstrap vcpkg."

$vcpkgPath = "${devDrive}vcpkg\vcpkg.exe"

if (Test-Path (Join-Path $installRoot "vcpkg.exe")) 
{
    Write-Info "Already bootstrapped. Skipping."
}
else 
{
	  
	# MSYS-compatible path to vcpkg directory
	$bootstrapScript = "$installRootUnix/bootstrap-vcpkg.sh"
	$bashBootstrapCmd = "cd $installRootUnix && bash $bootstrapScript"

    $bootstrapBat = Join-Path $installRoot "bootstrap-vcpkg.bat"
    $proc = Start-Process -FilePath $bootstrapBat `
                          -ArgumentList "-disableMetrics","-debug" `
                          -WorkingDirectory $installRoot `
                          -Wait -PassThru


	if ($proc.ExitCode -ne 0) 
	{
		Write-Error "vcpkg bootstrap process failed (ExitCode=$($proc.ExitCode))."
		Abort-WithError
	}

	# Verify executable
	$vcpkgExe = Join-Path $installRoot "vcpkg.exe"
	if (-not (Test-Path $vcpkgExe)) 
	{
		Write-Error "vcpkg.exe was not found after bootstrapping."
		Abort-WithError
	}

	Write-Info "Bootstrap completed. vcpkg.exe located at: $vcpkgExe"

	# Show vcpkg version and baseline info
	Write-Info "Querying vcpkg version and baseline..."

	# Get vcpkg path
	if (-not (Test-Path $vcpkgPath)) 
	{
		Write-Error "vcpkg.exe not found at $vcpkgPath"
		Abort-WithError
	}
}

# Display vcpkg version using Start-Process
$tempVersionFile = "$env:TEMP\vcpkg_version.txt"
Start-Process -FilePath $vcpkgPath `
              -ArgumentList "version" `
              -RedirectStandardOutput $tempVersionFile `
              -Wait

# Output non-empty version lines
if (Test-Path $tempVersionFile) 
{
    $lines = Get-Content $tempVersionFile | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) 
	{
        Write-Info $line
    }
    Remove-Item $tempVersionFile -Force
} 
else 
{
    Write-Error "Failed to retrieve vcpkg version."
}

Write-Info "STEP 3: OK"

# STEP 4: Setup environment variables
# --------------------------------------------------------------------------

Write-Info "STEP 4: Setup environment variables."

$envFilePath = Join-Path "${devDriveOnly}:" "degoras-env-variables.env"

# Usa forward slashes explícitos
$vcpkgCacheDir = "${devDriveOnly}:/packages/vcpkg"
$vcpkgRoot     = "${devDriveOnly}:/vcpkg"
$vcpkgPorts    = "${devDriveOnly}:/overlays/ports"
$vcpkgTriplets = "${devDriveOnly}:/overlays/triplets"
$vcpkgBinPath  = "${vcpkgRoot}/installed/x64-mingw-dynamic-degoras/bin"

Write-Info "VCPKG_ROOT=$vcpkgRoot"
Write-Info "VCPKG_DEFAULT_BINARY_CACHE=$vcpkgCacheDir"
Write-Info "VCPKG_DEFAULT_TRIPLET=x64-mingw-dynamic-degoras"
Write-Info "VCPKG_DEFAULT_HOST_TRIPLET=x64-mingw-dynamic-degoras"
Write-Info "VCPKG_OVERLAY_PORTS=$vcpkgPorts"
Write-Info "VCPKG_OVERLAY_TRIPLETS=$vcpkgTriplets"
Write-Info "PATH=${vcpkgBinPath}:`$PATH"

# Write all environment variables to a file for later use
$envLines = @(
    "VCPKG_ROOT=$vcpkgRoot"
    "VCPKG_DEFAULT_BINARY_CACHE=$vcpkgCacheDir"
    "VCPKG_DEFAULT_TRIPLET=x64-mingw-dynamic-degoras"
    "VCPKG_DEFAULT_HOST_TRIPLET=x64-mingw-dynamic-degoras"
    "VCPKG_OVERLAY_PORTS=$vcpkgPorts"
    "VCPKG_OVERLAY_TRIPLETS=$vcpkgTriplets"
)

Write-Info "Appending environment variables to $envFilePath"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stream = [System.IO.StreamWriter]::new($envFilePath, $true, $utf8NoBom)  
foreach ($line in $envLines) {$stream.WriteLine($line)}
$stream.Close()

Write-Info "STEP 4: OK"

# STEP 5: Install controlled DEGORAS triplet from folder
# --------------------------------------------------------------------------

Write-Info "STEP 5: Installing controlled triplet 'x64-mingw-dynamic-degoras'..."

# Sources in script folder
$tripletSourcePath = Join-Path $scriptDir "vcpkg_triplets\x64-mingw-dynamic-degoras.cmake"
$tripletShaPath    = Join-Path $scriptDir "vcpkg_triplets\x64-mingw-dynamic-degoras.sha256"

# Destination in overlay-triplets (already-existing folder)
$overlayTripletsRoot = "${devDrive}overlays\triplets"
$tripletDestPath     = Join-Path $overlayTripletsRoot "x64-mingw-dynamic-degoras.cmake"

# Guards
if (-not (Test-Path $tripletSourcePath)) { Write-Error "Controlled triplet not found: $tripletSourcePath"; Abort-WithError }
if (-not (Test-Path $tripletShaPath))    { Write-Error "Triplet SHA256 file not found: $tripletShaPath";  Abort-WithError }

# Ensure destination folder exists
if (-not (Test-Path $overlayTripletsRoot)) 
{
    New-Item -ItemType Directory -Path $overlayTripletsRoot -Force | Out-Null
    Write-Info "Created overlay triplets directory: $overlayTripletsRoot"
}

# Compare SHA256 to decide copy
$shouldCopy = $true
if (Test-Path $tripletDestPath) 
{
    $actualHash   = (Get-FileHash -Path $tripletDestPath -Algorithm SHA256).Hash
    $expectedHash = (Get-Content $tripletShaPath -Raw).Trim()
    if ($actualHash -eq $expectedHash) {
        Write-Info "Triplet already up-to-date in overlay. Skipping copy."
        $shouldCopy = $false
    } else {
        Write-Info "Triplet hash mismatch in overlay. Overwriting..."
    }
}

if ($shouldCopy) 
{
    Copy-Item -Path $tripletSourcePath -Destination $tripletDestPath -Force
    Write-Info "Triplet copied to overlay: $tripletDestPath"
}

Write-Info "STEP 5: OK"

# STEP 6: Install controlled overlay ports from folder
# --------------------------------------------------------------------------

Write-Info "STEP 6: Installing controlled overlay ports..."

# Source: script folder
$overlayPortsSrc = Join-Path $scriptDir "vcpkg_overlays"

# Destination: env overlays
$overlayPortsDst = "${devDrive}overlays\ports"

# Guards
if (-not (Test-Path $overlayPortsSrc)) 
{
    Write-Error "Overlay ports source not found: $overlayPortsSrc"
    Abort-WithError
}

# Ensure destination folder exists
if (-not (Test-Path $overlayPortsDst)) 
{
    New-Item -ItemType Directory -Path $overlayPortsDst -Force | Out-Null
    Write-Info "Created overlay ports directory: $overlayPortsDst"
}

# Copy each port folder recursively
$srcPortDirs = Get-ChildItem -Path $overlayPortsSrc -Directory
foreach ($dir in $srcPortDirs) 
{
    $srcPath = $dir.FullName
    $dstPath = Join-Path $overlayPortsDst $dir.Name

    Write-Info "Installing overlay port: $($dir.Name) → $dstPath"
    try 
	{
        if (Test-Path $dstPath) 
		{
            Remove-Item -Path $dstPath -Recurse -Force
        }
        Copy-Item -Path $srcPath -Destination $dstPath -Recurse -Force
        Write-Info "Overlay port installed: $($dir.Name)"
    }
    catch 
	{
        Write-Error "Failed to install overlay port $($dir.Name): $_"
        Abort-WithError
    }
}

Write-Info "STEP 6: OK"

# FINALIZATION
# --------------------------------------------------------------------

# Compute elapsed time
$scriptEnd = Get-Date
$elapsed = $scriptEnd - $scriptStart
$elapsedStr = ("{0:hh\:mm\:ss}" -f $elapsed)

# Final logs.
Write-Info "DEGORAS-PROJECT VCPKG clone setup completed successfully."
Write-Info "TOTAL EXECUTION TIME: $($elapsed.TotalSeconds) seconds  ($elapsedStr)"

# Exit
Write-Host ""
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
$host.UI.RawUI.WindowTitle = $originalTitle

# --------------------------------------------------------------------