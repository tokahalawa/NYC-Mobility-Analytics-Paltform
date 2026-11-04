
INSTALL postgres;
LOAD postgres;
ATTACH 'host=localhost port=5432 dbname=nyc_dwh user=admin password=admin123' AS pg (TYPE postgres);

-- Query 1: Trip Demand by Hour
SELECT EXTRACT(HOUR FROM pickup_datetime) AS hour_of_day, COUNT(*) AS total_trips FROM pg.gold.fact_trips GROUP BY 1 ORDER BY 1;

-- Query 2: Demand by Day of Week
SELECT CASE EXTRACT(ISODOW FROM pickup_datetime) WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday' WHEN 7 THEN 'Sunday' END AS day_name, COUNT(*) AS total_trips FROM pg.gold.fact_trips GROUP BY 1 ORDER BY 2 DESC;

-- Query 3: Top 10 Pickup Zones
SELECT z.zone_name, z.borough, COUNT(*) AS total_trips FROM pg.gold.fact_trips f JOIN pg.gold.dim_zone z ON f.pu_zone_key = z.zone_key GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 10;

-- Query 4: Revenue by Company
SELECT c.company_name, COUNT(*) AS total_trips, ROUND(SUM(f.total_paid)::numeric, 2) AS total_revenue FROM pg.gold.fact_trips f JOIN pg.gold.dim_company c ON f.company_key = c.company_key GROUP BY 1 ORDER BY 3 DESC;

-- Query 5: Average Trip Distance and Duration
SELECT c.company_name, ROUND(AVG(f.trip_miles)::numeric, 2) AS avg_miles, ROUND(AVG(f.trip_seconds)::numeric / 60.0, 2) AS avg_minutes FROM pg.gold.fact_trips f JOIN pg.gold.dim_company c ON f.company_key = c.company_key GROUP BY 1;

-- Query 6: Shared vs Non-Shared Trips
SELECT shared_match AS is_shared, COUNT(*) AS total_trips, ROUND(AVG(trip_seconds)::numeric / 60.0, 2) AS avg_duration_minutes FROM pg.gold.fact_trips GROUP BY 1;

-- Query 7: Tip Percentage by Borough
SELECT z.borough, ROUND(SUM(f.tips)::numeric / NULLIF(SUM(f.total_paid - f.tips), 0) * 100, 2) AS tip_percentage FROM pg.gold.fact_trips f JOIN pg.gold.dim_zone z ON f.pu_zone_key = z.zone_key GROUP BY 1 ORDER BY 2 DESC;

-- Query 8: Airport Trips Trend by Hour
SELECT EXTRACT(HOUR FROM pickup_datetime) AS hour_of_day, COUNT(*) AS airport_trips FROM pg.gold.fact_trips f JOIN pg.gold.dim_zone z ON f.pu_zone_key = z.zone_key WHERE z.zone_name IN ('JFK Airport', 'LaGuardia Airport', 'Newark Airport') GROUP BY 1 ORDER BY 1;