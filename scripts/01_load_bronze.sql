INSTALL postgres ; ------ duckdb cant use postgres sql so it needs extension to be laoded ----
LOAD postgres ;
ATTACH IF NOT EXISTS 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres); -------
CREATE  OR REPLACE TABLE pg.bronze.trips_raw AS 
SELECT 
* ,
'fhvhv_tripdata_2025-01.parquet'AS source_file
FROM 'data/raw/fhvhv_tripdata_2025-01.parquet';
SELECT COUNT (*) 
FROM pg.bronze.trips_raw ;
------------- adding lookup 
 create or replace table pg.bronze.zones_raw as
         select * from read_csv('data/raw/taxi_zone_lookup');

