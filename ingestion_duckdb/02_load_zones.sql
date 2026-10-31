INSTALL postgres; LOAD postgres;
ATTACH IF NOT EXISTS 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres);
CREATE OR REPLACE TABLE pg.bronze.zones_raw AS
SELECT * FROM read_csv('data/raw/taxi_zone_lookup.csv');
