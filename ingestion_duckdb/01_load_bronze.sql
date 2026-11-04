INSTALL postgres ; ------ duckdb cant use postgres sql so it needs extension to be laoded ----
LOAD postgres ;
ATTACH IF NOT EXISTS 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres); 
------- CREATING EMPTY TABLE WITH SAME COLUMNS AS PARQUET FILES-----
CREATE TABLE IF NOT EXISTS pg.bronze.trips_raw AS 
SELECT 
* ,
''::VARCHAR AS source_file
FROM 'data/raw/fhvhv_tripdata_2025-01.parquet'
WHERE FALSE ;
 ---------- TO BE IDEOMPOTENT IF LOADED AGAIN DONT REPEAT ----
DELETE FROM pg.bronze.trips_raw
WHERE source_file = 'fhvhv_tripdata_2025-01.parquet' ;


---------------Extarcting data from source and load it to bronze table ------
INSERT INTO pg.bronze.trips_raw BY NAME ----- TO AVOID DIFFRENT ORDERS OF COLUMNS LATER -----
SELECT *, 'fhvhv_tripdata_2025-01.parquet' AS source_file 
FROM 'data/raw/fhvhv_tripdata_2025-01.parquet' ;

-------CHECKING THEY ARE LOADED AND EXTRACTED COMPLETLY -------

SELECT 
(SELECT COUNT(*)FROM'data/raw/fhvhv_tripdata_2025-01.parquet') AS SOURCE_ROWS ,
(SELECT COUNT(*)FROM pg.bronze.trips_raw WHERE source_file = 'fhvhv_tripdata_2025-01.parquet' ) AS BRONZE_ROWS ;



