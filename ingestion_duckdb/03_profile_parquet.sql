
----------PROFILNG DATA -------------
SUMMARIZE SELECT * FROM 'data/raw/fhvhv_tripdata_2025-01.parquet' ;
------ to show neagtive values in paid money-----

SELECT 
COUNT(*) FILTER (WHERE tolls < 0 ) AS neg_tolls , 
COUNT(*) FILTER (WHERE base_passenger_fare < 0 ) AS neg_base_fare , 
COUNT(*) FILTER (WHERE bcf < 0 ) AS neg_bcf , 
COUNT(*) FILTER (WHERE sales_tax < 0 ) AS neg_tax , 
COUNT(*) FILTER (WHERE congestion_surcharge < 0 ) AS neg_congestion_surcharge , 
COUNT(*) FILTER (WHERE airport_fee < 0 ) AS neg_airport_fee , 
COUNT(*) FILTER (WHERE tips < 0 ) AS neg_tips , 
COUNT(*) FILTER (WHERE driver_pay < 0 ) AS neg_driver_pay ,
COUNT(*) FILTER (WHERE cbd_congestion_fee < 0 ) AS neg_cbd_congestion_fee 
FROM 'data/raw/fhvhv_tripdata_2025-01.parquet';

--------- Answer ---------
/*           neg_tolls = 0
           neg_base_fare = 2427
                 neg_bcf = 0
                 neg_tax = 0
neg_congestion_surcharge = 0
         neg_airport_fee = 0
                neg_tips = 0
          neg_driver_pay = 313
  neg_cbd_congestion_fee = 0 */   


---- Invalid timestamps ----------
 
SELECT 
COUNT (*) FILTER (WHERE request_datetime > pickup_datetime) AS invalid_timestamp ,

FROM 'data/raw/fhvhv_tripdata_2025-01.parquet';
---- invalid_timestamp = 199788--------

------------- Duplicates------------


