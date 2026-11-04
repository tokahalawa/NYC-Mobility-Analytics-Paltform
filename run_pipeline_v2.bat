@echo off
setlocal
if not exist logs mkdir logs

:: ==========================================
:: 1. Define Variables & Defaults
:: ==========================================
set FILE=%~1
if "%FILE%"=="" set FILE=fhvhv_tripdata_2025-02.parquet
set SRC=%~2
if "%SRC%"=="" set SRC=bronze.trips_raw

echo ===================================================
echo   STARTING PIPELINE FOR: %FILE%
echo ===================================================
echo [%date% %time%] START %FILE% >> logs\pipeline.log

:: ==========================================
:: 2. Step 1: Silver Transformation (DuckDB)
:: ==========================================
echo.
echo [1/4] Transforming Data (Silver) in DuckDB...

data\duckdb.exe -c "SET VARIABLE source_file = '%FILE%';" -c ".read sql/silver/02_build_silver_duckdb.sql" > logs\1_silver.log 2>&1
type logs\1_silver.log

:: Check if DuckDB failed (using findstr to check for 'Error')
findstr /I /C:"Error" logs\1_silver.log >nul
if %errorlevel% equ 0 (
    echo [%date% %time%] FAILED at Silver >> logs\pipeline.log
    echo ERROR: Silver Transformation failed! Check logs\1_silver.log
    pause
    exit /b 1
)
echo [%date% %time%] 1_silver OK >> logs\pipeline.log

:: ==========================================
:: 3. Step 2: Load to Gold (PostgreSQL)
:: ==========================================
echo.
echo [2/4] Loading to Gold Layer (PostgreSQL)...
docker exec -i nyc_postgres psql -U admin -d nyc_dwh -v ON_ERROR_STOP=1 -v source_file=%FILE% < sql\gold\02_load_gold.sql > logs\2_gold.log 2>&1
if %errorlevel% neq 0 (
    echo [%date% %time%] FAILED at Gold >> logs\pipeline.log
    echo ERROR: Gold Load failed! Check logs\2_gold.log
    pause
    exit /b 1
)
echo [%date% %time%] 2_gold OK >> logs\pipeline.log

:: ==========================================
:: 4. Step 3: Data Validation
:: ==========================================
echo.
echo [3/4] Validating Data...
docker exec -i nyc_postgres psql -U admin -d nyc_dwh -v ON_ERROR_STOP=1 -v source_file=%FILE% < sql\quality\99_validate.sql > logs\3_validate.log 2>&1
if %errorlevel% neq 0 (
    echo [%date% %time%] FAILED at Validation >> logs\pipeline.log
    echo ERROR: Validation failed! Check logs\3_validate.log
    pause
    exit /b 1
)
echo [%date% %time%] 3_validate OK >> logs\pipeline.log

:: ==========================================
:: 5. Step 4: Performance Optimization
:: ==========================================
echo.
echo [4/4] Running Performance Optimizations...
docker exec -i nyc_postgres psql -U admin -d nyc_dwh -v ON_ERROR_STOP=1 < sql\gold\03_performance.sql > logs\4_performance.log 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Performance script failed! (Optional step)
)

:: ==========================================
:: 6. Pipeline Completed Successfully
:: ==========================================
echo.
echo ===================================================
echo   PIPELINE COMPLETED SUCCESSFULLY!
echo ===================================================
echo [%date% %time%] PIPELINE OK >> logs\pipeline.log
pause