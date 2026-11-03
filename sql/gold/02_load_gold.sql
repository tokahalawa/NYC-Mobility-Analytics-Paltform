-- safe rerun -------------
DELETE FROM gold.fact_trips WHERE source_file = 'fhvhv_tripdata_2025-01.parquet';

INSERT INTO gold.fact_trips (
  time_key, company_key, pu_zone_key, do_zone_key,
  request_datetime, pickup_datetime, dropoff_datetime,
  trip_miles, trip_seconds, base_passenger_fare, tolls, bcf, sales_tax,
  congestion_surcharge, airport_fee, cbd_congestion_fee, tips, driver_pay,
  wait_seconds, total_paid,
  shared_request, shared_match, access_a_ride, wav_request, wav_match,
  is_outlier, is_driver_pay_suspect, source_file)
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
WHERE c.source_file = 'fhvhv_tripdata_2025-01.parquet';

--------------------- Verifying --------------------

SELECT
 (SELECT COUNT(*) FROM silver.trips_clean WHERE source_file='{{ params.source_file }}') AS silver_rows,
 (SELECT COUNT(*) FROM gold.fact_trips    WHERE source_file='{{ params.source_file }}') AS fact_rows;


--------------------------- End to end test-----------------
SELECT z.borough, z.zone_name, COUNT(*) AS trips
FROM gold.fact_trips f
JOIN gold.dim_zone z ON z.zone_key = f.pu_zone_key
GROUP BY 1, 2 ORDER BY trips DESC LIMIT 10;