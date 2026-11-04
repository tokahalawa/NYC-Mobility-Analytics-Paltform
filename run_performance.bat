@echo off
echo Running Performance Script...
docker exec -i nyc_postgres psql -U admin -d nyc_dwh < sql\gold\03_performance.sql > logs\performance.log 2>&1
if %errorlevel% neq 0 (
    echo Performance script failed! Check logs\performance.log
    pause
    exit /b 1
)
echo Performance script completed successfully! Check logs\performance.log
pause