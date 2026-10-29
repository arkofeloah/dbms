@echo off
setlocal enabledelayedexpansion

echo ======================================================================
echo      Food Waste Redistribution Network — Safe Database Backup
echo ======================================================================
echo.

:: 1. Locate mysqldump binary
set "MYSQLDUMP_BIN="
where mysqldump >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "MYSQLDUMP_BIN=mysqldump"
) else if exist "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe" (
    set "MYSQLDUMP_BIN=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe"
) else (
    echo [ERROR] mysqldump.exe was not found in PATH or standard MySQL directory.
    echo Please install MySQL Server 8.0 or add its bin directory to PATH.
    pause
    exit /b 1
)

:: 2. Create backups folder if needed
if not exist "backups" mkdir backups

:: 3. Generate timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set LDT=%%I
set TIMESTAMP=%LDT:~0,4%-%LDT:~4,2%-%LDT:~6,2%_%LDT:~8,2%-%LDT:~10,2%-%LDT:~12,2%
set "BACKUP_FILE=backups\food_waste_db_backup_%TIMESTAMP%.sql"

echo [INFO] Target backup file: %BACKUP_FILE%
echo.

set /p DB_USER=Enter MySQL username [default: root]: 
if "%DB_USER%"=="" set DB_USER=root

set /p DB_HOST=Enter MySQL host [default: 127.0.0.1]: 
if "%DB_HOST%"=="" set DB_HOST=127.0.0.1

set /p DB_PORT=Enter MySQL port [default: 3306]: 
if "%DB_PORT%"=="" set DB_PORT=3306

echo.
echo [INFO] Running mysqldump with routines and triggers...
"%MYSQLDUMP_BIN%" -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p --routines --triggers --single-transaction --databases food_waste_db > "%BACKUP_FILE%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ======================================================================
    echo [SUCCESS] Backup created successfully:
    echo           %BACKUP_FILE%
    echo ======================================================================
) else (
    echo.
    echo [ERROR] Backup failed. Please verify your credentials and server status.
    if exist "%BACKUP_FILE%" del "%BACKUP_FILE%"
)

pause
