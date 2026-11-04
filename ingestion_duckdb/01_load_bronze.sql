INSTALL postgres;
LOAD postgres;

-- Attach PostgreSQL database via DuckDB (Ensure Docker container is running)
ATTACH IF NOT EXISTS 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres); 

-- 1. Create empty bronze table with identical column structure derived from Parquet file (using WHERE FALSE)
-- Note: 'PLACEHOLDER.parquet' serves as a parameter to be dynamically replaced during execution/looping
CREATE TABLE IF NOT EXISTS pg.bronze.trips_raw AS 
SELECT *, ''::VARCHAR AS source_file
FROM 'data/raw/PLACEHOLDER.parquet'
WHERE FALSE;

-- 2. Ensure idempotence: prevent duplicate records if the script is executed multiple times for the same file
DELETE FROM pg.bronze.trips_raw
WHERE source_file = 'PLACEHOLDER.parquet';

-- 3. Extract data from raw Parquet source and load into PostgreSQL bronze layer
-- Using 'BY NAME' ensures robust column mapping regardless of column ordering differences
INSERT INTO pg.bronze.trips_raw BY NAME
SELECT *, 'PLACEHOLDER.parquet' AS source_file 
FROM 'data/raw/PLACEHOLDER.parquet';

-- 4. Data validation step: verify complete extraction and load by comparing source vs target row counts
SELECT 
    (SELECT COUNT(*) FROM 'data/raw/PLACEHOLDER.parquet') AS SOURCE_ROWS,
    (SELECT COUNT(*) FROM pg.bronze.trips_raw WHERE source_file = 'PLACEHOLDER.parquet') AS BRONZE_ROWS;