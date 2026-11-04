\timing on
DROP INDEX IF EXISTS gold.ix_fact_time;
DROP INDEX IF EXISTS gold.ix_fact_pu_zone;
ANALYZE gold.fact_trips;

\echo === 1) BEFORE index: one day of trips by borough
EXPLAIN (ANALYZE, BUFFERS)
SELECT z.borough, COUNT(*) FROM gold.fact_trips f
JOIN gold.dim_zone z ON z.zone_key = f.pu_zone_key
WHERE f.time_key IN (
    SELECT time_key FROM gold.fact_trips ORDER BY time_key DESC LIMIT 24
) 
GROUP BY 1;

CREATE INDEX ix_fact_time    ON gold.fact_trips (time_key);
CREATE INDEX ix_fact_pu_zone ON gold.fact_trips (pu_zone_key);
ANALYZE gold.fact_trips;

\echo === 1) AFTER index (same query)
EXPLAIN (ANALYZE, BUFFERS)
SELECT z.borough, COUNT(*) FROM gold.fact_trips f
JOIN gold.dim_zone z ON z.zone_key = f.pu_zone_key
WHERE f.time_key IN (
    SELECT time_key FROM gold.fact_trips ORDER BY time_key DESC LIMIT 24
) 
GROUP BY 1;

CREATE TABLE IF NOT EXISTS gold.agg_hourly_zone (
  time_key INT, pu_zone_key INT, company_key INT,
  trips BIGINT, total_miles NUMERIC, total_seconds BIGINT, total_fare NUMERIC,
  total_paid NUMERIC, total_tips NUMERIC, total_wait_seconds BIGINT,
  PRIMARY KEY (time_key, pu_zone_key, company_key));
TRUNCATE gold.agg_hourly_zone;
INSERT INTO gold.agg_hourly_zone
SELECT time_key, pu_zone_key, company_key, COUNT(*), SUM(trip_miles), SUM(trip_seconds),
       SUM(base_passenger_fare), SUM(total_paid), SUM(tips), SUM(wait_seconds)
FROM gold.fact_trips GROUP BY 1,2,3;
ANALYZE gold.agg_hourly_zone;

\echo === 2) BEFORE aggregate: demand by hour from the fact
EXPLAIN (ANALYZE, BUFFERS)
SELECT d.hour, COUNT(*) FROM gold.fact_trips f JOIN gold.dim_time d USING (time_key) GROUP BY 1 ORDER BY 1;

\echo === 2) AFTER aggregate: same answer from the aggregate
EXPLAIN (ANALYZE, BUFFERS)
SELECT d.hour, SUM(a.trips) FROM gold.agg_hourly_zone a JOIN gold.dim_time d USING (time_key) GROUP BY 1 ORDER BY 1;