\echo === rows per layer
SELECT 'silver_clean' AS layer, COUNT(*) FROM silver.trips_clean WHERE source_file = :'source_file'
UNION ALL SELECT 'silver_quarantine', COUNT(*) FROM silver.trips_quarantine WHERE source_file = :'source_file'
UNION ALL SELECT 'gold_fact', COUNT(*) FROM gold.fact_trips WHERE source_file = :'source_file';

\echo === orphan checks (all must be 0)
SELECT
 (SELECT COUNT(*) FROM gold.fact_trips f LEFT JOIN gold.dim_time d USING (time_key)
   WHERE d.time_key IS NULL AND f.source_file = :'source_file') AS orphan_time,
 (SELECT COUNT(*) FROM gold.fact_trips f LEFT JOIN gold.dim_zone z ON z.zone_key = f.pu_zone_key
   WHERE z.zone_key IS NULL AND f.source_file = :'source_file') AS orphan_pu_zone,
 (SELECT COUNT(*) FROM gold.fact_trips f LEFT JOIN gold.dim_zone z ON z.zone_key = f.do_zone_key
   WHERE z.zone_key IS NULL AND f.source_file = :'source_file') AS orphan_do_zone,
 (SELECT COUNT(*) FROM gold.fact_trips f LEFT JOIN gold.dim_company c USING (company_key)
   WHERE c.company_key IS NULL AND f.source_file = :'source_file') AS orphan_company;

\echo === smoke test: top 10 pickup zones
SELECT z.borough, z.zone_name, COUNT(*) AS trips
FROM gold.fact_trips f JOIN gold.dim_zone z ON z.zone_key = f.pu_zone_key
WHERE f.source_file = :'source_file'
GROUP BY 1,2 ORDER BY trips DESC LIMIT 10;