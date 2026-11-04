@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo   STARTING BATCH INGESTION FOR 2025 (FROM MARCH)
echo ===================================================

for %%f in (data\raw\fhvhv_tripdata_2025-*.parquet) do (
    
    set "FILENAME=%%~nxf"
    set "SKIP=0"

    if "!FILENAME!"=="fhvhv_tripdata_2025-01.parquet" set "SKIP=1"
    if "!FILENAME!"=="fhvhv_tripdata_2025-02.parquet" set "SKIP=1"

    if !SKIP!==0 (
        echo.
        echo ---------------------------------------------------
        echo PROCESSING FILE: !FILENAME!
        echo ---------------------------------------------------
        
        call run_pipeline_v2.bat !FILENAME!
        
        if !errorlevel! neq 0 (
            echo ERROR OCCURRED IN !FILENAME!. STOPPING.
            pause
            exit /b 1
        )
    )
)

echo.
echo ===================================================
echo   ALL REMAINING 2025 FILES PROCESSED SUCCESSFULLY!
echo ===================================================
pause