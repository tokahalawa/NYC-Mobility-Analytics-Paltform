-- ===== dim_time =====
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
FROM generate_series('2024-12-01'::timestamp, '2026-12-31 23:00'::timestamp, interval '1 hour') ts
ON CONFLICT (time_key) DO NOTHING;


-- ===== dim_company =====
CREATE TABLE IF NOT EXISTS gold.dim_company (
  company_key  INT PRIMARY KEY,
  license_code TEXT NOT NULL UNIQUE,
  company_name TEXT NOT NULL
);
INSERT INTO gold.dim_company VALUES
 (0,'UNKNOWN','Unknown'),(1,'HV0002','Juno'),(2,'HV0003','Uber'),(3,'HV0004','Via'),(4,'HV0005','Lyft')
ON CONFLICT DO NOTHING;

-- ===== dim_zone =====
CREATE TABLE IF NOT EXISTS gold.dim_zone (
  zone_key     INT PRIMARY KEY,
  borough      TEXT NOT NULL,
  zone_name    TEXT NOT NULL,
  service_zone TEXT
);
INSERT INTO gold.dim_zone VALUES (0,'Unknown','Unknown','Unknown') ON CONFLICT DO NOTHING;
INSERT INTO gold.dim_zone
SELECT "LocationID"::int, COALESCE("Borough",'Unknown'), COALESCE("Zone",'Unknown'), "service_zone"
FROM bronze.zones_raw
ON CONFLICT (zone_key) DO NOTHING;


-- ===== fact_trips =====
CREATE TABLE IF NOT EXISTS gold.fact_trips (
  trip_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  time_key              INT NOT NULL REFERENCES gold.dim_time(time_key),
  company_key           INT NOT NULL REFERENCES gold.dim_company(company_key),
  pu_zone_key           INT NOT NULL REFERENCES gold.dim_zone(zone_key),
  do_zone_key           INT NOT NULL REFERENCES gold.dim_zone(zone_key),
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
  shared_request BOOLEAN, shared_match BOOLEAN, access_a_ride BOOLEAN,
  wav_request BOOLEAN, wav_match BOOLEAN,
  is_outlier            BOOLEAN NOT NULL,
  is_driver_pay_suspect BOOLEAN NOT NULL,
  source_file           TEXT NOT NULL
);
