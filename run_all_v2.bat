@echo off
setlocal

if "%~1"=="" (
    echo.
    echo Usage: run_all_v2.bat [parquet_file_name]
    echo Example: run_all_v2.bat fhvhv_tripdata_2025-02.parquet
    echo.
    pause
    exit /b 1
)

set FILE=%~1
echo ========================================
echo   Full Pipeline Starting
echo   File: %FILE%
echo ========================================

echo.
echo [1/3] Loading Zones (Lookup Table)...
"C:\Users\Toka\AppData\Local\duckdb\cli\2.0.0\duckdb.exe" < ingestion_duckdb\02_load_zones.sql
if %errorlevel% neq 0 (
    echo ERROR: Loading zones failed!
    pause
    exit /b 1
)

echo.
echo [2/3] Loading Bronze (Trips)...
powershell -Command "(Get-Content 'ingestion_duckdb\01_load_bronze.sql') -replace 'PLACEHOLDER', '%FILE:~0,-8%' | Set-Content 'ingestion_duckdb\temp_load_bronze.sql'"
"C:\Users\Toka\AppData\Local\duckdb\cli\2.0.0\duckdb.exe" < ingestion_duckdb\temp_load_bronze.sql
if %errorlevel% neq 0 (
    echo ERROR: Loading bronze failed!
    del ingestion_duckdb\temp_load_bronze.sql 2>nul
    pause
    exit /b 1
)
del ingestion_duckdb\temp_load_bronze.sql 2>nul

echo.
echo [3/3] Running Transformation (Silver + Gold)...
call run_pipeline_v2.bat %FILE%
if %errorlevel% neq 0 (
    echo ERROR: Transformation failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Pipeline Completed Successfully
echo ========================================
pause