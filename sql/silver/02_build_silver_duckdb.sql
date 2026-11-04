-- =========================================================================
-- DuckDB Silver Transformation (Reading directly from Parquet)
-- =========================================================================

-- 0) Connect to PostgreSQL
INSTALL postgres;
LOAD postgres;
ATTACH IF NOT EXISTS 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres);

-- 1) rules
CREATE TABLE IF NOT EXISTS pg.silver.quality_rules (
  rule_id TEXT PRIMARY KEY, column_name TEXT, description TEXT, action TEXT);
INSERT INTO pg.silver.quality_rules VALUES
 ('R01','pickup_datetime','Pickup time is empty','QUARANTINE'),
 ('R02','dropoff_datetime','Dropoff time is empty','QUARANTINE'),
 ('R03','dropoff_datetime','Dropoff is before or at pickup','QUARANTINE'),
 ('R04','trip_time','Trip time is empty, zero, or negative','QUARANTINE'),
 ('R05','trip_miles','Trip distance is empty, zero, or negative','QUARANTINE'),
 ('R06','base_passenger_fare','Base fare is empty or negative','QUARANTINE'),
 ('R07','fees','Any fee is negative','QUARANTINE'),
 ('R08','driver_pay','Driver pay is empty or negative','QUARANTINE'),
 ('R09','hvfhs_license_num','License number is empty','QUARANTINE'),
 ('R10','request_datetime','Request time is empty','QUARANTINE'),
 ('R11','request_datetime','Request time is after pickup time','QUARANTINE'),
 ('R12','pickup_datetime','Pickup is outside the file''s month','QUARANTINE')
ON CONFLICT (rule_id) DO NOTHING;

-- 2) tables (created once) in PG
CREATE TABLE IF NOT EXISTS pg.silver.trips_quarantine AS
SELECT *, ''::VARCHAR AS reject_rule_id, now() AS quarantine_time
FROM pg.bronze.trips_raw WHERE false;

CREATE TABLE IF NOT EXISTS pg.silver.trips_clean (
  hvfhs_license_num TEXT NOT NULL, dispatching_base_num TEXT, originating_base_num TEXT,
  request_datetime TIMESTAMP NOT NULL, on_scene_datetime TIMESTAMP,
  pickup_datetime TIMESTAMP NOT NULL, dropoff_datetime TIMESTAMP NOT NULL,
  pu_location_id INTEGER NOT NULL, do_location_id INTEGER NOT NULL,
  trip_miles NUMERIC(8,2) NOT NULL, trip_seconds INTEGER NOT NULL,
  base_passenger_fare NUMERIC(10,2) NOT NULL, tolls NUMERIC(10,2) NOT NULL,
  bcf NUMERIC(10,2) NOT NULL, sales_tax NUMERIC(10,2) NOT NULL,
  congestion_surcharge NUMERIC(10,2) NOT NULL, airport_fee NUMERIC(10,2) NOT NULL,
  cbd_congestion_fee NUMERIC(10,2) NOT NULL, tips NUMERIC(10,2) NOT NULL,
  driver_pay NUMERIC(10,2) NOT NULL,
  shared_request BOOLEAN, shared_match BOOLEAN, access_a_ride BOOLEAN,
  wav_request BOOLEAN, wav_match BOOLEAN,
  wait_seconds INTEGER NOT NULL, total_paid NUMERIC(10,2) NOT NULL,
  is_outlier BOOLEAN NOT NULL, is_driver_pay_suspect BOOLEAN NOT NULL,
  source_file TEXT NOT NULL);

-- 3) stage: Read directly from Parquet
DROP TABLE IF EXISTS staged;
CREATE TEMP TABLE staged AS
SELECT t.*, getvariable('source_file') AS source_file,
CASE
  WHEN pickup_datetime IS NULL THEN 'R01'
  WHEN dropoff_datetime IS NULL THEN 'R02'
  WHEN dropoff_datetime <= pickup_datetime THEN 'R03'
  WHEN trip_time IS NULL OR trip_time <= 0 THEN 'R04'
  WHEN trip_miles IS NULL OR trip_miles <= 0 THEN 'R05'
  WHEN base_passenger_fare IS NULL OR base_passenger_fare < 0 THEN 'R06'
  WHEN tolls < 0 OR bcf < 0 OR sales_tax < 0 OR congestion_surcharge < 0
    OR airport_fee < 0 OR cbd_congestion_fee < 0 OR tips < 0 THEN 'R07'
  WHEN driver_pay IS NULL OR driver_pay < 0 THEN 'R08'
  WHEN hvfhs_license_num IS NULL THEN 'R09'
  WHEN request_datetime IS NULL THEN 'R10'
  WHEN request_datetime > pickup_datetime THEN 'R11'
  -- R12 FIXED FOR DUCKDB:
  WHEN pickup_datetime <  CAST(regexp_extract(getvariable('source_file'), '[0-9]{4}-[0-9]{2}') || '-01' AS DATE)
    OR pickup_datetime >= CAST(regexp_extract(getvariable('source_file'), '[0-9]{4}-[0-9]{2}') || '-01' AS DATE) + INTERVAL '1 month'
    THEN 'R12'
END AS reject_rule_id
FROM read_parquet('data/raw/' || getvariable('source_file')) t;



-- 4) safe rerun (Delete from PG)
DELETE FROM pg.silver.trips_quarantine WHERE source_file = getvariable('source_file');
DELETE FROM pg.silver.trips_clean      WHERE source_file = getvariable('source_file');

-- =========================================================
-- =========================================================
ALTER TABLE pg.silver.trips_quarantine SET UNLOGGED;
ALTER TABLE pg.silver.trips_clean SET UNLOGGED;

-- 5) rejected rows (Insert to PG)
INSERT INTO pg.silver.trips_quarantine
SELECT s.*, now() FROM staged s WHERE s.reject_rule_id IS NOT NULL;

-- 6) clean rows + transformations (Insert to PG)
INSERT INTO pg.silver.trips_clean
WITH prep AS (
  SELECT
    CASE WHEN upper(trim(s.hvfhs_license_num)) IN ('HV0002','HV0003','HV0004','HV0005')
         THEN upper(trim(s.hvfhs_license_num)) ELSE 'UNKNOWN' END AS hvfhs_license_num,
    upper(trim(s.dispatching_base_num)) AS dispatching_base_num,
    upper(trim(s.originating_base_num)) AS originating_base_num,
    s.request_datetime, s.on_scene_datetime, s.pickup_datetime, s.dropoff_datetime,
    COALESCE(pu."LocationID",0)::INTEGER AS pu_location_id,
    COALESCE(dz."LocationID",0)::INTEGER AS do_location_id,
    s.trip_miles::NUMERIC(8,2) AS trip_miles, s.trip_time::INTEGER AS trip_seconds,
    s.base_passenger_fare::NUMERIC(10,2) AS base_passenger_fare,
    COALESCE(s.tolls,0)::NUMERIC(10,2) AS tolls, COALESCE(s.bcf,0)::NUMERIC(10,2) AS bcf,
    COALESCE(s.sales_tax,0)::NUMERIC(10,2) AS sales_tax,
    COALESCE(s.congestion_surcharge,0)::NUMERIC(10,2) AS congestion_surcharge,
    COALESCE(s.airport_fee,0)::NUMERIC(10,2) AS airport_fee,
    COALESCE(s.cbd_congestion_fee,0)::NUMERIC(10,2) AS cbd_congestion_fee,
    COALESCE(s.tips,0)::NUMERIC(10,2) AS tips, s.driver_pay::NUMERIC(10,2) AS driver_pay,
    CASE upper(trim(s.shared_request_flag)) WHEN 'Y' THEN TRUE WHEN 'N' THEN FALSE END AS shared_request,
    CASE upper(trim(s.shared_match_flag))   WHEN 'Y' THEN TRUE WHEN 'N' THEN FALSE END AS shared_match,
    CASE upper(trim(s.access_a_ride_flag))  WHEN 'Y' THEN TRUE WHEN 'N' THEN FALSE END AS access_a_ride,
    CASE upper(trim(s.wav_request_flag))    WHEN 'Y' THEN TRUE WHEN 'N' THEN FALSE END AS wav_request,
    CASE upper(trim(s.wav_match_flag))      WHEN 'Y' THEN TRUE WHEN 'N' THEN FALSE END AS wav_match,
    s.source_file
  FROM staged s
  LEFT JOIN pg.bronze.zones_raw pu ON pu."LocationID" = s."PULocationID"
  LEFT JOIN pg.bronze.zones_raw dz ON dz."LocationID" = s."DOLocationID"
  WHERE s.reject_rule_id IS NULL)
SELECT hvfhs_license_num, dispatching_base_num, originating_base_num,
  request_datetime, on_scene_datetime, pickup_datetime, dropoff_datetime,
  pu_location_id, do_location_id, trip_miles, trip_seconds,
  base_passenger_fare, tolls, bcf, sales_tax, congestion_surcharge,
  airport_fee, cbd_congestion_fee, tips, driver_pay,
  shared_request, shared_match, access_a_ride, wav_request, wav_match,
  EXTRACT(EPOCH FROM (pickup_datetime - request_datetime))::INTEGER,
  base_passenger_fare + tolls + bcf + sales_tax + congestion_surcharge + airport_fee + cbd_congestion_fee + tips,
  (trip_miles > 200 OR trip_seconds >= 86400),
  (driver_pay > base_passenger_fare),
  source_file
FROM prep;

-- =========================================================
-- for data to be safe
-- =========================================================
ALTER TABLE pg.silver.trips_quarantine SET LOGGED;
ALTER TABLE pg.silver.trips_clean SET LOGGED;


-- 7) reconciliation
SELECT
  (SELECT COUNT(*) FROM staged) AS source_rows,
  (SELECT COUNT(*) FROM pg.silver.trips_clean WHERE source_file = getvariable('source_file')) AS clean_rows,
  (SELECT COUNT(*) FROM pg.silver.trips_quarantine WHERE source_file = getvariable('source_file')) AS quarantine_rows;

SELECT CASE 
  WHEN (SELECT COUNT(*) FROM pg.silver.trips_clean WHERE source_file = getvariable('source_file')) + 
       (SELECT COUNT(*) FROM pg.silver.trips_quarantine WHERE source_file = getvariable('source_file')) 
       = (SELECT COUNT(*) FROM staged) 
  THEN 'Reconciliation Passed' 
  ELSE 1/0 
END AS reconciliation_check;

-- 8) quality report
SELECT q.reject_rule_id, r.description, COUNT(*) AS rows_quarantined
FROM pg.silver.trips_quarantine q JOIN pg.silver.quality_rules r ON r.rule_id = q.reject_rule_id
WHERE q.source_file = getvariable('source_file')
GROUP BY 1,2 ORDER BY 3 DESC;