@echo off
setlocal

echo ======================================================================
echo      Food Waste Redistribution Network — Application Launcher
echo ======================================================================
echo.

:: 1. Verify virtual environment
if not exist "venv\Scripts\activate.bat" (
    echo [WARNING] Virtual environment 'venv' not detected!
    echo Running setup.bat first...
    call setup.bat
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Setup failed.
        pause
        exit /b 1
    )
)

:: 2. Verify backend/.env
if not exist "backend\.env" (
    echo [WARNING] backend\.env not found!
    if exist "backend\.env.example" (
        copy "backend\.env.example" "backend\.env" >nul
        echo [INFO] Created backend\.env from example template.
        echo [ACTION REQUIRED] Please edit backend\.env with your MySQL password before running.
        pause
        exit /b 1
    )
)

:: 3. Activate virtual environment and start application
call venv\Scripts\activate.bat

echo [INFO] Starting Flask web application on http://127.0.0.1:5000...
echo [INFO] Press Ctrl+C in this window to stop the server.
echo.

python backend\app.py

pause
