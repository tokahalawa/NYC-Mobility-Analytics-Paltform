@echo off
setlocal
if not exist logs mkdir logs
set FILE=%1
if "%FILE%"=="" set FILE=fhvhv_tripdata_2025-01.parquet
set SRC=%2
if "%SRC%"=="" set SRC=bronze.trips_raw

echo [%date% %time%] START %FILE% from %SRC% >> logs\pipeline.log
call :run 1_create_gold   sql\gold\01_create_gold.sql   || exit /b 1
call :run 2_silver        sql\silver\01_build_silver.sql || exit /b 1
call :run 3_load_gold     sql\gold\02_load_gold.sql      || exit /b 1
call :run 4_validate      sql\quality\99_validate.sql    || exit /b 1
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
docker exec -i nyc_postgres psql -U admin -d nyc_dwh -v ON_ERROR_STOP=1 -v source_file=%FILE% -v src_table=%SRC% < %SQLFILE% > logs\%STEP%.log 2>&1
if errorlevel 1 (
  echo [%date% %time%] %STEP% FAILED attempt %TRIES% >> logs\pipeline.log
  if %TRIES% LSS 2 ( timeout /t 20 >nul & goto again )
  echo [%date% %time%] PIPELINE FAILED at %STEP% >> logs\pipeline.log
  exit /b 1
)
echo [%date% %time%] %STEP% OK >> logs\pipeline.log
exit /b 0