# ====================================================================
# DEGORAS-PROJECT VCPKG DEPS SETUP SCRIPT
# --------------------------------------------------------------------
# Author: Angel Vera Herrera
# Updated: 26/10/2025
# Version: 251026
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

# PARAMETERS
# --------------------------------------------------------------------

param
(
    [string]$devDrive = "D",
	[string]$msys64BinPath = "D:\msys64\usr\bin"
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

# Prepare logging.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logsDir = Join-Path $scriptDir "INSTALL_LOGS"
if (-not (Test-Path $logsDir)){New-Item -ItemType Directory -Path $logsDir | Out-Null}
$globalLogFile = Join-Path $logsDir "${timestamp}_vcpkg-deps-setup.log"
$globalLogFileUnix = $globalLogFile -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# SCRIPT STARTUP HEADER
# --------------------------------------------------------------------

# Clear and initial logs.
Clear-Host
$originalTitle = $host.UI.RawUI.WindowTitle
$host.UI.RawUI.WindowTitle = "DEGORAS VCPKG Deps Setup"
Write-NoFormat "================================================================="
Write-NoFormat "  DEGORAS-PROJECT VCPKG DEPS SETUP SCRIPT"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "  Author:  Angel Vera Herrera"
Write-NoFormat "  Updated: 26/10/2025"
Write-NoFormat "  Version: 251026"
Write-NoFormat "================================================================="
Write-NoFormat "Parameters:"
Write-NoFormat "-----------------------------------------------------------------"
Write-NoFormat "Install Drive    = $devDrive"
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

Write-Info "Checking if msys2 bash exists..."
if (-not (Test-Path $msys64BashPath)) 
{
    Write-Error "Bash not found at expected MSYS2 path: $msys64BashPath"
    Abort-WithError
}

Write-Info "STEP 1: OK"

# STEP 2: Install example lib fmt (basic test)
# --------------------------------------------------------------------

Write-Info "STEP 2: Install example lib 'fmt' with triplet 'x64-mingw-dynamic-degoras'"

$installRoot = "${devDrive}\vcpkg"
$vcpkgCache = "${devDrive}\packages\vcpkg"

# Ruta MSYS-compatible a vcpkg para usar en bash
$installRootUnix = $installRoot -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$vcpkgCacheUnix = $vcpkgCache -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Script bash para entorno mingw64
$bashScript = @"
source shell ucrt64
cd $installRootUnix
export VCPKG_ROOT="$installRootUnix" 
export VCPKG_DEFAULT_BINARY_CACHE="$vcpkgCacheUnix" 
export VCPKG_DEFAULT_TRIPLET="x64-mingw-dynamic-degoras"
export VCPKG_DEFAULT_HOST_TRIPLET="x64-mingw-dynamic-degoras"
./vcpkg install fmt
"@

# Guardar script temporal
$tempBashScript = Join-Path $env:TEMP "install_fmt.sh"
Set-Content -Path $tempBashScript -Encoding ASCII -Value $bashScript

# Convertir a formato MSYS
$bashScriptUnix = $tempBashScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Ejecutar
$proc = Start-Process -FilePath $msys64BashPath `
    -ArgumentList "-l", "-c", "`"bash '$bashScriptUnix' 2>&1 | tee -a '$globalLogFileUnix'`"" `
    -Wait -PassThru -NoNewWindow

# Limpiar script temporal
Remove-Item $tempBashScript -Force

if ($proc.ExitCode -ne 0) 
{
    Write-Error "Installation of 'fmt' failed (ExitCode=$($proc.ExitCode))."
    Abort-WithError
}

# Get fmt installed version
$fmtVersionScript = @"
source /etc/profile
source shell ucrt64
cd $installRootUnix
./vcpkg list | grep '^fmt:x64-mingw-dynamic-degoras'
"@

$tempVersionScript = Join-Path $env:TEMP "vcpkg_check_fmt.sh"
Set-Content -Path $tempVersionScript -Encoding ASCII -Value $fmtVersionScript

$versionScriptUnix = $tempVersionScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$versionOutput = & "$msys64BashPath" -l -c "bash '$versionScriptUnix' 2>&1 | tee -a '$globalLogFile'"

Remove-Item $tempVersionScript -Force

foreach ($line in $versionOutput) 
{
    if ($line -match '^fmt:x64-mingw-dynamic-degoras\s+([\d\.#]+)') {
        Write-Info "Installed fmt version: $($matches[1])"
    }
}

Write-Info "STEP 2: OK"

# STEP 3: Install core libraries
# --------------------------------------------------------------------

Write-Info "STEP 3: Install required packages with triplet 'x64-mingw-dynamic-degoras'"

# FULL PACKAGES FOR DEGORAS (TODO)
# protobuf ?? FOR FUTURE?
# grpc     ?? FOR FUTURE?

$packages = 
@(
	"fmt",
	"pkgconf",
    "nlohmann-json",
	"libbson",
	"openssl",
	"spdlog",
	"zlib",
	"curl",
    "mongo-c-driver",
	"xerces-c",
	"zeromq",
	"cppzmq"
)

$targetPackages = 
@(
	"fmt",
	"pkgconf",
    "nlohmann-json",
	"openssl",
	"spdlog",
	"zlib",
	"curl",
	"xerces-c",
	"zeromq",
	"cppzmq",
	"libbson",
    "mongo-c-driver"
)

foreach ($pkg in $packages) 
{
    Write-Info "Installing '$pkg'..."

    $bashScript = @"
source shell ucrt64
cd $installRootUnix
export VCPKG_ROOT="$installRootUnix" 
export VCPKG_DEFAULT_BINARY_CACHE="$vcpkgCacheUnix" 
export VCPKG_DEFAULT_TRIPLET="x64-mingw-dynamic-degoras"
export VCPKG_DEFAULT_HOST_TRIPLET="x64-mingw-dynamic-degoras"
./vcpkg install $pkg
"@

    $tempBashScript = Join-Path $env:TEMP "install_$($pkg.Replace('[','_').Replace(']','').Replace(',','_')).sh"
    Set-Content -Path $tempBashScript -Encoding ASCII -Value $bashScript

    $bashScriptUnix = $tempBashScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

	$proc = Start-Process -FilePath $msys64BashPath `
    -ArgumentList "-l", "-c", "`"bash '$bashScriptUnix' 2>&1 | tee -a '$globalLogFile'`"" `
    -Wait -PassThru -NoNewWindow

    Remove-Item $tempBashScript -Force

    if ($proc.ExitCode -ne 0) 
	{
        Write-Error "Installation of '$pkg' failed (ExitCode=$($proc.ExitCode))."
        Abort-WithError
    }

    Write-Info "'$pkg' installed successfully."
}

Write-Info "STEP 3: OK"

# STEP 4: List installed versions
# --------------------------------------------------------------------

Write-Info "STEP 4: Retrieve versions of installed packages"

$versionScript = @"
source shell ucrt64
cd $installRootUnix
./vcpkg list | grep ':x64-mingw-dynamic-degoras'
"@

$tempVersionScript = Join-Path $env:TEMP "vcpkg_check_versions.sh"
Set-Content -Path $tempVersionScript -Encoding ASCII -Value $versionScript
$versionScriptUnix = $tempVersionScript -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
$versionOutput = & "$msys64BashPath" -l -c "bash $versionScriptUnix"
Remove-Item $tempVersionScript -Force

foreach ($line in $versionOutput) 
{
    if ($line -match '^([\w\-\+]+):x64-mingw-dynamic-degoras\s+([\d\.#]+)') {
        $pkg = $matches[1]
        $ver = $matches[2]
        if ($targetPackages -contains $pkg) {
            Write-Info "Installed: $pkg version $ver"
        }
    }
}

Write-Info "STEP 4: OK"

# FINALIZATION
# --------------------------------------------------------------------

# Compute elapsed time
$scriptEnd = Get-Date
$elapsed = $scriptEnd - $scriptStart
$elapsedStr = ("{0:hh\:mm\:ss}" -f $elapsed)

# Final logs.
Write-Info "DEGORAS-PROJECT VCPKG deps setup completed successfully."
Write-Info "TOTAL EXECUTION TIME: $($elapsed.TotalSeconds) seconds  ($elapsedStr)"

# Exit
Write-Host ""
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
$host.UI.RawUI.WindowTitle = $originalTitle

# --------------------------------------------------------------------