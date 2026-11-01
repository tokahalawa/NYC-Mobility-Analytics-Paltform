--------------------- Quality Rules ---------------

----- creating empty table to add rules -----

CREATE TABLE IF NOT EXISTS silver.quality_rules (
rule_id TEXT PRIMARY KEY , 
column_name TEXT ,
description TEXT ,
action TEXT
);
------- adding rules to created table -------

INSERT INTO silver.quality_rules VALUES 
 ('R01', 'pickup_datetime',      'Pickup time is empty',                         'QUARANTINE'),
 ('R02', 'dropoff_datetime',     'Dropoff time is empty',                        'QUARANTINE'),
 ('R03', 'dropoff_datetime',     'Dropoff is before or at the same time as pickup', 'QUARANTINE'),
 ('R04', 'trip_time',            'Trip time is empty, zero, or negative',        'QUARANTINE'),
 ('R05', 'trip_miles',           'Trip distance is empty, zero, or negative',    'QUARANTINE'),
 ('R06', 'base_passenger_fare',  'Base fare is empty or negative',               'QUARANTINE'),
 ('R07', 'fees',                 'Any fee is negative (tolls, bcf, sales_tax, congestion_surcharge, airport_fee, cbd_congestion_fee, tips)', 'QUARANTINE'),
 ('R08', 'driver_pay',           'Driver pay is empty or negative',              'QUARANTINE'),
 ('R09', 'hvfhs_license_num',    'License number is empty',                      'QUARANTINE'),
 ('R10', 'request_datetime',     'Request time is empty',                        'QUARANTINE'),
 ('R11', 'request_datetime',     'Request time is after pickup time',            'QUARANTINE')
ON CONFLICT (rule_id) DO NOTHING;

---------------- Quarntine --------
CREATE TABLE IF NOT EXISTS silver.trips_quarantine AS 
SELECT *,
''::VARCHAR AS reject_rule_id,
now() AS quarantine_time
FROM bronze.trips_raw 
WHERE false;


DELETE FROM silver.trips_quarantine
WHERE source_file = 'fhvhv_tripdata_2025-01.parquet'; ----- ensures Idempotency and safe reruns -------

---------- Inserting Into Quarntine -------

INSERT INTO silver.trips_quarantine
SELECT 
x.*,
now()
 FROM (
  SELECT 
      t.*,
      CASE
      WHEN pickup_datetime IS NULL                          THEN 'R01'
      WHEN dropoff_datetime IS NULL                         THEN 'R02'
      WHEN dropoff_datetime <= pickup_datetime                THEN 'R03'
      WHEN trip_time IS NULL OR trip_time <= 0                THEN 'R04'
      WHEN trip_miles IS NULL OR trip_miles <= 0              THEN 'R05'
      WHEN base_passenger_fare IS NULL OR base_passenger_fare < 0   THEN 'R06'
      WHEN tolls < 0 
        OR bcf < 0 
        OR sales_tax < 0 
        OR congestion_surcharge < 0 
        OR airport_fee < 0 
        OR cbd_congestion_fee < 0 
        OR tips < 0                                         THEN 'R07'    
      WHEN driver_pay IS NULL OR driver_pay < 0               THEN 'R08'
      WHEN hvfhs_license_num IS NULL                        THEN 'R09'
      WHEN request_datetime IS NULL                         THEN 'R10'
      WHEN request_datetime > pickup_datetime               THEN 'R11'
    END AS reject_rule_id
  FROM bronze.trips_raw  t
  WHERE source_file = 'fhvhv_tripdata_2025-01.parquet'
) x
WHERE x.reject_rule_id IS NOT NULL;
 -----------------------------------------------------------
--------------Clean Silver ---------
DELETE FROM silver.trips_clean
WHERE source_file = 'fhvhv_tripdata_2025-01.parquet' ;

CREATE TABLE silver.trips_clean AS
SELECT
  t.*,
  t.base_passenger_fare::NUMERIC(10,2),
  t.tolls::NUMERIC(10,2),
  t.bcf::NUMERIC(10,2),
  t.sales_tax::NUMERIC(10,2),
  t.congestion_surcharge::NUMERIC(10,2),
  t.airport_fee::NUMERIC(10,2),
  t.tips::NUMERIC(10,2),
  t.driver_pay::NUMERIC(10,2),
  t.cbd_congestion_fee::NUMERIC(10,2)
FROM bronze.trips_raw t
WHERE source_file = 'fhvhv_tripdata_2025-01.parquet'
  AND pickup_datetime IS NOT NULL
  AND dropoff_datetime IS NOT NULL
  AND dropoff_datetime > pickup_datetime
  AND trip_time IS NOT NULL AND trip_time > 0
  AND trip_miles IS NOT NULL AND trip_miles > 0
  AND base_passenger_fare IS NOT NULL AND base_passenger_fare >= 0
  AND (tolls IS NULL OR tolls >= 0)
  AND (bcf IS NULL OR bcf >= 0)
  AND (sales_tax IS NULL OR sales_tax >= 0)
  AND (congestion_surcharge IS NULL OR congestion_surcharge >= 0)
  AND (airport_fee IS NULL OR airport_fee >= 0)
  AND (cbd_congestion_fee IS NULL OR cbd_congestion_fee >= 0)
  AND (tips IS NULL OR tips >= 0)
  AND driver_pay IS NOT NULL AND driver_pay >= 0
  AND hvfhs_license_num IS NOT NULL
  AND request_datetime IS NOT NULL
  AND request_datetime <= pickup_datetime;
