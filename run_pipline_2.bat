@echo off
setlocal
if not exist logs mkdir logs

:: 1. Set Variables
set FILE=%1
if "%FILE%"=="" set FILE=fhvhv_tripdata_2025-01.parquet
set SRC=%2
if "%SRC%"=="" set SRC=bronze.trips_raw

echo [%date% %time%] START %FILE% from %SRC% >> logs\pipeline.log

:: 2. Execute Pipeline Steps (Silver now uses DuckDB)
call :run 1_create_gold   sql\gold\01_create_gold.sql   || exit /b 1
call :run 2_silver_duckdb sql\silver\02_build_silver_duckdb.sql || exit /b 1
call :run 3_load_gold     sql\gold\02_load_gold.sql      || exit /b 1
call :run 4_validate      sql\quality\99_validate.sql    || exit /b 1
call :run 5_performance   sql\gold\03_performance.sql    || exit /b 1

echo [%date% %time%] PIPELINE OK %FILE% >> logs\pipeline.log
echo DONE. See logs\pipeline.log and logs\4_validate.log
exit /b 0

:run
set STEP=%1
set SQLFILE=%2
set TRIES=0
:again
set /a TRIES+=1
echo [%date% %time%] %STEP% attempt %TRIES% >> logs\pipeline.log

:: 3. Execute based on tool type
if "%STEP%"=="2_silver_duckdb" (
    :: Execute via DuckDB
    duckdb -c ".read %SQLFILE%" -c "SET VARIABLE source_file = '%FILE%';" > logs\%STEP%.log 2>&1
) else (
    :: Execute via PostgreSQL in Docker
    docker exec -i nyc_postgres psql -U admin -d nyc_dwh -v ON_ERROR_STOP=1 -v source_file=%FILE% -v src_table=%SRC% < %SQLFILE% > logs\%STEP%.log 2>&1
)

:: 4. Error Handling and Retries
if errorlevel 1 (
  echo [%date% %time%] %STEP% FAILED attempt %TRIES% >> logs\pipeline.log
  if %TRIES% LSS 2 ( 
      echo Waiting 20 seconds before retry...
      timeout /t 20 >nul 
      goto again 
  )
  echo [%date% %time%] PIPELINE FAILED at %STEP% >> logs\pipeline.log
  exit /b 1
)
echo [%date% %time%] %STEP% OK >> logs\pipeline.log
exit /b 0