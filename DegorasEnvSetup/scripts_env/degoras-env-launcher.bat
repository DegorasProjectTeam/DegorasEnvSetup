@echo off
chcp 65001 >nul
setlocal ENABLEDELAYEDEXPANSION

REM ===================================================================
REM DEGORAS-PROJECT ENVIRONMENT STARTER FOR MSYS2/UCRT64
REM Launches bash in a new window with environment preloaded
REM Author: Ángel Vera Herrera
REM Version: 251026
REM ===================================================================

REM Detect script directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Path to .env file and bootstrap script
set "ENV_FILE=%SCRIPT_DIR%\degoras-env-variables.env"
set "BOOTSTRAP_SCRIPT=%SCRIPT_DIR%\degoras-env-bootstrap.sh"

REM Extract MSYS2_BASH from .env file
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    set "k=%%A"
    set "v=%%B"
    setlocal ENABLEDELAYEDEXPANSION
    if /i "!k!"=="MSYS2_BASH" (
        endlocal & set "MSYS2_BASH=%%B"
    ) else (
        endlocal
    )
)

REM Validate
if not defined MSYS2_BASH (
    echo [ERROR] MSYS2_BASH not defined in env file.
    exit /b 1
)

if not exist "%MSYS2_BASH%" (
    echo [ERROR] bash.exe not found at: %MSYS2_BASH%
    exit /b 1
)

echo [INFO] Launching DEGORAS-PROJECT MSYS2 Environment...
echo [INFO] Using bash at: %MSYS2_BASH%
echo [INFO] Bootstrap script: %BOOTSTRAP_SCRIPT%
echo.

REM Launch MSYS2 Bash in a new window with custom title
start "DEGORAS ENV" "%MSYS2_BASH%" --login -i -c "source \"$(cygpath -u \"%BOOTSTRAP_SCRIPT%\")\" && exec bash"

exit /b 0
