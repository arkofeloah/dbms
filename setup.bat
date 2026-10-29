@echo off
setlocal enabledelayedexpansion

echo ======================================================================
echo      Food Waste Redistribution Network — Windows Setup Script
echo ======================================================================
echo.

:: 1. Check Python installation
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python is not installed or not found in system PATH.
    echo Please install Python 3.10+ from https://python.org and ensure "Add to PATH" is checked.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do set PYTHON_VER=%%i
echo [INFO] Detected: %PYTHON_VER%

:: 2. Create virtual environment if not present
if not exist "venv\Scripts\activate.bat" (
    echo [INFO] Creating Python virtual environment in 'venv'...
    python -m venv venv
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo [SUCCESS] Virtual environment created successfully.
) else (
    echo [INFO] Existing virtual environment found in 'venv'.
)

:: 3. Upgrade pip and install dependencies
echo.
echo [INFO] Installing required dependencies...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
if exist "requirements.txt" (
    pip install -r requirements.txt
) else if exist "backend\requirements.txt" (
    pip install -r backend\requirements.txt
)

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Dependency installation encountered an issue.
    pause
    exit /b 1
)
echo [SUCCESS] All dependencies installed successfully.

:: 4. Prepare environment configuration
echo.
if not exist "backend\.env" (
    if exist "backend\.env.example" (
        echo [INFO] Creating backend\.env from template...
        copy "backend\.env.example" "backend\.env" >nul
        echo [IMPORTANT] Please open backend\.env and configure your MySQL password!
    )
) else (
    echo [INFO] Existing backend\.env detected.
)

echo.
echo ======================================================================
echo                     SETUP COMPLETED SUCCESSFULLY!
echo ======================================================================
echo.
echo Next Steps:
echo 1. Verify your MySQL server is running (e.g., MySQL80 service).
echo 2. If this is a fresh setup, import the schema:
echo       scripts\restore_db.bat (or see README.md for manual import)
echo 3. Configure your database password in backend\.env
echo 4. Launch the application:
echo       run.bat
echo.
pause
