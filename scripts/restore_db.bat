@echo off
setlocal enabledelayedexpansion

echo ======================================================================
echo      Food Waste Redistribution Network — Safe Database Restore
echo ======================================================================
echo.

:: 1. Locate mysql binary
set "MYSQL_BIN="
where mysql >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "MYSQL_BIN=mysql"
) else if exist "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" (
    set "MYSQL_BIN=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
) else (
    echo [ERROR] mysql.exe was not found in PATH or standard MySQL directory.
    echo Please install MySQL Server 8.0 or add its bin directory to PATH.
    pause
    exit /b 1
)

echo Select Restore Action:
echo   [1] Initialize fresh database from sql\ scripts (Schema + Seed Data + Triggers/Procedures)
echo   [2] Restore from a specific backup dump file (.sql)
echo   [3] Cancel and exit
echo.
set /p CHOICE=Enter choice (1, 2, or 3): 

if "%CHOICE%"=="3" (
    echo [INFO] Operation cancelled by user.
    exit /b 0
)

set /p DB_USER=Enter MySQL username [default: root]: 
if "%DB_USER%"=="" set DB_USER=root

set /p DB_HOST=Enter MySQL host [default: 127.0.0.1]: 
if "%DB_HOST%"=="" set DB_HOST=127.0.0.1

set /p DB_PORT=Enter MySQL port [default: 3306]: 
if "%DB_PORT%"=="" set DB_PORT=3306

if "%CHOICE%"=="1" (
    echo.
    echo **********************************************************************
    echo [WARNING] Initializing fresh database will DROP and RECREATE 'food_waste_db'!
    echo Any existing data in 'food_waste_db' will be permanently replaced.
    echo **********************************************************************
    echo.
    set /p CONFIRM=Type YES (in capital letters) to confirm: 
    if not "!CONFIRM!"=="YES" (
        echo [INFO] Confirmation failed. Aborting database initialization.
        pause
        exit /b 0
    )

    echo.
    echo [1/3] Applying schema (tables and constraints)...
    "%MYSQL_BIN%" -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p < "sql\food_network_schema.sql"
    if %ERRORLEVEL% neq 0 goto ERROR_HANDLER

    echo [2/3] Inserting sample seed data...
    "%MYSQL_BIN%" -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p food_waste_db < "sql\sample_data.sql"
    if %ERRORLEVEL% neq 0 goto ERROR_HANDLER

    echo [3/3] Creating stored procedures and triggers...
    "%MYSQL_BIN%" -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p food_waste_db < "sql\procedures_triggers.sql"
    if %ERRORLEVEL% neq 0 goto ERROR_HANDLER

    echo.
    echo [SUCCESS] Fresh database initialized successfully!
    pause
    exit /b 0
)

if "%CHOICE%"=="2" (
    echo.
    set /p DUMP_PATH=Enter relative or absolute path to backup file: 
    if not exist "!DUMP_PATH!" (
        echo [ERROR] Backup file not found at: !DUMP_PATH!
        pause
        exit /b 1
    )

    echo.
    echo [INFO] Restoring from !DUMP_PATH!...
    "%MYSQL_BIN%" -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p < "!DUMP_PATH!"
    if %ERRORLEVEL% neq 0 goto ERROR_HANDLER

    echo.
    echo [SUCCESS] Database restored successfully from !DUMP_PATH!
    pause
    exit /b 0
)

:ERROR_HANDLER
echo.
echo [ERROR] Restore operation failed. Please check your credentials and MySQL status.
pause
exit /b 1
