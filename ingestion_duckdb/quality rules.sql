----- creating empty table to add rules -----

CREATE TABLE IF NOT EXISTS silver_quality_rules (
rule_id TEXT PRIMARY KEY , 
column_name TEXT ,
description TEXT ,
action TEXT
)

------- adding rules to created table -------

INSERT INTO silver_quality_rules VALUES 
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


