\timing on

-- ========================================================
-- 1) Create Dimensions & Fact Tables (If not exists)
-- ========================================================

-- A) dim_time
CREATE TABLE IF NOT EXISTS gold.dim_time (
  time_key    INT PRIMARY KEY,
  hour_start  TIMESTAMP NOT NULL,
  date        DATE      NOT NULL,
  year        INT       NOT NULL,
  month       INT       NOT NULL,
  month_name  TEXT      NOT NULL,
  day_of_week INT       NOT NULL,
  day_name    TEXT      NOT NULL,
  hour        INT       NOT NULL,
  is_weekend  BOOLEAN   NOT NULL
);

INSERT INTO gold.dim_time
SELECT to_char(ts,'YYYYMMDDHH24')::int, ts, ts::date, 
       EXTRACT(YEAR FROM ts)::int, EXTRACT(MONTH FROM ts)::int, trim(to_char(ts,'Month')), 
       EXTRACT(ISODOW FROM ts)::int, trim(to_char(ts,'Day')), 
       EXTRACT(HOUR FROM ts)::int, EXTRACT(ISODOW FROM ts) IN (6,7)
FROM generate_series('2017-01-01'::timestamp, '2030-12-31 23:00'::timestamp, interval '1 hour') ts
ON CONFLICT (time_key) DO NOTHING;

-- B) dim_company
CREATE TABLE IF NOT EXISTS gold.dim_company (
  company_key  INT PRIMARY KEY,
  license_code TEXT NOT NULL UNIQUE,
  company_name TEXT NOT NULL
);

INSERT INTO gold.dim_company VALUES
 (0,'UNKNOWN','Unknown'),
 (1,'HV0002','Juno'),
 (2,'HV0003','Uber'),
 (3,'HV0004','Via'),
 (4,'HV0005','Lyft')
ON CONFLICT DO NOTHING;

-- C) dim_zone
CREATE TABLE IF NOT EXISTS gold.dim_zone (
  zone_key     INT PRIMARY KEY,
  borough      TEXT NOT NULL,
  zone_name    TEXT NOT NULL,
  service_zone TEXT
);

INSERT INTO gold.dim_zone VALUES (0,'Unknown','Unknown','Unknown') ON CONFLICT DO NOTHING;


CREATE TABLE IF NOT EXISTS bronze.zones_raw (
  "LocationID" INT,
  "Borough" TEXT,
  "Zone" TEXT,
  "service_zone" TEXT
);
TRUNCATE bronze.zones_raw;
COPY bronze.zones_raw FROM '/docker-entrypoint-initdb.d/taxi_zone_lookup.csv' DELIMITER ',' CSV HEADER;

INSERT INTO gold.dim_zone
SELECT "LocationID"::int, COALESCE("Borough",'Unknown'), COALESCE("Zone",'Unknown'), "service_zone"
FROM bronze.zones_raw
ON CONFLICT (zone_key) DO NOTHING;

-- D) fact_trips
CREATE TABLE IF NOT EXISTS gold.fact_trips (
  trip_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  time_key              INT NOT NULL,
  company_key           INT NOT NULL,
  pu_zone_key           INT NOT NULL,
  do_zone_key           INT NOT NULL,
  request_datetime      TIMESTAMP NOT NULL,
  pickup_datetime       TIMESTAMP NOT NULL,
  dropoff_datetime      TIMESTAMP NOT NULL,
  trip_miles            NUMERIC(8,2)  NOT NULL,
  trip_seconds          INT           NOT NULL,
  base_passenger_fare   NUMERIC(10,2) NOT NULL,
  tolls                 NUMERIC(10,2) NOT NULL,
  bcf                   NUMERIC(10,2) NOT NULL,
  sales_tax             NUMERIC(10,2) NOT NULL,
  congestion_surcharge  NUMERIC(10,2) NOT NULL,
  airport_fee           NUMERIC(10,2) NOT NULL,
  cbd_congestion_fee    NUMERIC(10,2) NOT NULL,
  tips                  NUMERIC(10,2) NOT NULL,
  driver_pay            NUMERIC(10,2) NOT NULL,
  wait_seconds          INT           NOT NULL,
  total_paid            NUMERIC(10,2) NOT NULL,
  shared_request        BOOLEAN,
  shared_match          BOOLEAN,
  access_a_ride         BOOLEAN,
  wav_request           BOOLEAN,
  wav_match             BOOLEAN,
  is_outlier            BOOLEAN NOT NULL,
  is_driver_pay_suspect BOOLEAN NOT NULL,
  source_file           TEXT NOT NULL
);

-- ========================================================
-- 2) Load Data into Fact Table
-- ========================================================

-- Safe rerun
DELETE FROM gold.fact_trips WHERE source_file = :'source_file';

INSERT INTO gold.fact_trips (
  time_key, company_key, pu_zone_key, do_zone_key,
  request_datetime, pickup_datetime, dropoff_datetime, 
  trip_miles, trip_seconds, base_passenger_fare, 
  tolls, bcf, sales_tax, congestion_surcharge, 
  airport_fee, cbd_congestion_fee, tips, driver_pay, 
  wait_seconds, total_paid,
  shared_request, shared_match, access_a_ride, 
  wav_request, wav_match,
  is_outlier, is_driver_pay_suspect, source_file
)
SELECT
  to_char(date_trunc('hour', c.pickup_datetime),'YYYYMMDDHH24')::int,
  dc.company_key,
  c.pu_location_id,
  c.do_location_id,
  c.request_datetime, 
  c.pickup_datetime, 
  c.dropoff_datetime, 
  c.trip_miles, 
  c.trip_seconds,
  c.base_passenger_fare, 
  c.tolls, 
  c.bcf, 
  c.sales_tax, 
  c.congestion_surcharge, 
  c.airport_fee,
  c.cbd_congestion_fee, 
  c.tips, 
  c.driver_pay, 
  c.wait_seconds, 
  c.total_paid,
  c.shared_request, 
  c.shared_match, 
  c.access_a_ride, 
  c.wav_request, 
  c.wav_match,
  c.is_outlier, 
  c.is_driver_pay_suspect, 
  c.source_file
FROM silver.trips_clean c
JOIN gold.dim_company dc ON dc.license_code = c.hvfhs_license_num
WHERE c.source_file = :'source_file';

-- ========================================================
-- 3) Reconciliation Check
-- ========================================================

SELECT 
  (SELECT COUNT(*) FROM silver.trips_clean WHERE source_file = :'source_file') AS silver_rows,
  (SELECT COUNT(*) FROM gold.fact_trips    WHERE source_file = :'source_file') AS fact_rows;

SELECT ((SELECT COUNT(*) FROM silver.trips_clean WHERE source_file = :'source_file')
      = (SELECT COUNT(*) FROM gold.fact_trips    WHERE source_file = :'source_file')) AS gold_ok \gset

\if :gold_ok
\else
  SELECT 1/0 AS gold_reconciliation_failed;
\endif