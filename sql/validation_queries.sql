-- =====================================================
-- NYC Taxi Pipeline - Validation Queries
-- Stack Tecnologias - Desafio Técnico
-- =====================================================

-- =====================================================
-- 1. DATA INTEGRITY VALIDATION
-- =====================================================

-- 1.1 Record counts by layer
SELECT 
    'Data Volume Validation' as validation_type,
    'silver' as layer,
    COUNT(*) as record_count,
    MIN(pickup_datetime) as min_date,
    MAX(pickup_datetime) as max_date
FROM nyc_taxi_catalog.silver.nyc_taxi_trips

UNION ALL

SELECT 
    'Data Volume Validation' as validation_type,
    'gold_hourly' as layer,
    COUNT(*) as record_count,
    MIN(pickup_hour) as min_date,
    MAX(pickup_hour) as max_date
FROM nyc_taxi_catalog.gold.hourly_location_metrics

UNION ALL

SELECT 
    'Data Volume Validation' as validation_type,
    'gold_daily' as layer,
    COUNT(*) as record_count,
    MIN(report_date) as min_date,
    MAX(report_date) as max_date  
FROM nyc_taxi_catalog.gold.daily_revenue_metrics

UNION ALL

SELECT 
    'Data Volume Validation' as validation_type,
    'warehouse' as layer,
    COUNT(*) as record_count,
    MIN(pickup_datetime) as min_date,
    MAX(pickup_datetime) as max_date
FROM nyc_taxi_catalog.warehouse.fact_taxi_trips;

-- =====================================================
-- 2. DATA QUALITY VALIDATION  
-- =====================================================

-- 2.1 Quality flag distribution
SELECT 
    'Quality Distribution' as validation_type,
    quality_flag,
    COUNT(*) as record_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM nyc_taxi_catalog.silver.nyc_taxi_trips
GROUP BY quality_flag
ORDER BY record_count DESC;

-- 2.2 Null values analysis
SELECT 
    'Null Values Analysis' as validation_type,
    COUNT(*) as total_records,
    COUNT(pickup_datetime) as valid_pickup_datetime,
    COUNT(dropoff_datetime) as valid_dropoff_datetime,
    COUNT(total_amount) as valid_total_amount,
    COUNT(trip_distance) as valid_trip_distance,
    COUNT(passenger_count) as valid_passenger_count,
    ROUND((COUNT(*) - COUNT(pickup_datetime)) * 100.0 / COUNT(*), 2) as pickup_null_pct,
    ROUND((COUNT(*) - COUNT(total_amount)) * 100.0 / COUNT(*), 2) as amount_null_pct
FROM nyc_taxi_catalog.silver.nyc_taxi_trips;

-- 2.3 Value range validation
SELECT 
    'Value Range Validation' as validation_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN total_amount > 0 THEN 1 END) as positive_amounts,
    COUNT(CASE WHEN trip_distance >= 0 THEN 1 END) as valid_distances,
    COUNT(CASE WHEN passenger_count BETWEEN 1 AND 6 THEN 1 END) as valid_passenger_count,
    COUNT(CASE WHEN trip_duration_minutes > 0 AND trip_duration_minutes < 720 THEN 1 END) as valid_duration,
    ROUND(COUNT(CASE WHEN total_amount > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as positive_amount_pct,
    ROUND(COUNT(CASE WHEN passenger_count BETWEEN 1 AND 6 THEN 1 END) * 100.0 / COUNT(*), 2) as valid_passenger_pct
FROM nyc_taxi_catalog.silver.nyc_taxi_trips;

-- 2.4 Geographic validation (NYC coordinates)
SELECT 
    'Geographic Validation' as validation_type,
    COUNT(*) as total_records,
    COUNT(CASE 
        WHEN pickup_longitude BETWEEN -74.5 AND -73.5 
         AND pickup_latitude BETWEEN 40.5 AND 41.0 
        THEN 1 
    END) as valid_pickup_coords,
    COUNT(CASE 
        WHEN dropoff_longitude BETWEEN -74.5 AND -73.5 
         AND dropoff_latitude BETWEEN 40.5 AND 41.0 
        THEN 1 
    END) as valid_dropoff_coords,
    ROUND(COUNT(CASE 
        WHEN pickup_longitude BETWEEN -74.5 AND -73.5 
         AND pickup_latitude BETWEEN 40.5 AND 41.0 
        THEN 1 
    END) * 100.0 / COUNT(*), 2) as valid_pickup_pct
FROM nyc_taxi_catalog.silver.nyc_taxi_trips;

-- =====================================================
-- 3. BUSINESS LOGIC VALIDATION
-- =====================================================

-- 3.1 Revenue consistency validation
SELECT 
    'Revenue Consistency' as validation_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN total_amount >= fare_amount THEN 1 END) as consistent_totals,
    COUNT(CASE WHEN tip_amount >= 0 THEN 1 END) as valid_tips,
    COUNT(CASE WHEN extra >= 0 THEN 1 END) as valid_extras,
    ROUND(COUNT(CASE WHEN total_amount >= fare_amount THEN 1 END) * 100.0 / COUNT(*), 2) as consistency_pct,
    AVG(total_amount) as avg_total_amount,
    AVG(fare_amount) as avg_fare_amount
FROM nyc_taxi_catalog.silver.nyc_taxi_trips
WHERE total_amount > 0 AND fare_amount > 0;

-- 3.2 Temporal consistency validation  
SELECT 
    'Temporal Consistency' as validation_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN dropoff_datetime > pickup_datetime THEN 1 END) as valid_duration,
    COUNT(CASE WHEN trip_duration_minutes > 0 THEN 1 END) as positive_duration,
    COUNT(CASE WHEN trip_duration_minutes BETWEEN 1 AND 720 THEN 1 END) as reasonable_duration,
    ROUND(COUNT(CASE WHEN dropoff_datetime > pickup_datetime THEN 1 END) * 100.0 / COUNT(*), 2) as valid_duration_pct,
    AVG(trip_duration_minutes) as avg_duration_minutes,
    MAX(trip_duration_minutes) as max_duration_minutes
FROM nyc_taxi_catalog.silver.nyc_taxi_trips;

-- =====================================================
-- 4. AGGREGATION VALIDATION
-- =====================================================

-- 4.1 Daily metrics validation (compare Silver vs Gold)
WITH silver_daily AS (
    SELECT 
        DATE(pickup_datetime) as trip_date,
        COUNT(*) as silver_trip_count,
        SUM(total_amount) as silver_revenue,
        AVG(total_amount) as silver_avg_fare
    FROM nyc_taxi_catalog.silver.nyc_taxi_trips
    WHERE DATE(pickup_datetime) BETWEEN '2015-01-01' AND '2015-01-31'
    GROUP BY DATE(pickup_datetime)
),
gold_daily AS (
    SELECT 
        report_date as trip_date,
        total_trips as gold_trip_count,
        total_revenue as gold_revenue,
        avg_fare_amount as gold_avg_fare
    FROM nyc_taxi_catalog.gold.daily_revenue_metrics
    WHERE report_date BETWEEN '2015-01-01' AND '2015-01-31'
)
SELECT 
    'Daily Aggregation Validation' as validation_type,
    s.trip_date,
    s.silver_trip_count,
    g.gold_trip_count,
    ROUND(s.silver_revenue, 2) as silver_revenue,
    ROUND(g.gold_revenue, 2) as gold_revenue,
    CASE 
        WHEN ABS(s.silver_trip_count - g.gold_trip_count) = 0 THEN 'MATCH'
        WHEN ABS(s.silver_trip_count - g.gold_trip_count) <= 10 THEN 'CLOSE'
        ELSE 'MISMATCH'
    END as count_validation,
    CASE 
        WHEN ABS(s.silver_revenue - g.gold_revenue) < 100 THEN 'MATCH'
        WHEN ABS(s.silver_revenue - g.gold_revenue) < 1000 THEN 'CLOSE'  
        ELSE 'MISMATCH'
    END as revenue_validation
FROM silver_daily s
FULL OUTER JOIN gold_daily g ON s.trip_date = g.trip_date
ORDER BY s.trip_date
LIMIT 10;

-- 4.2 Hourly metrics validation
SELECT 
    'Hourly Aggregation Validation' as validation_type,
    pickup_hour,
    COUNT(*) as metric_count,
    SUM(trip_count) as total_trips,
    ROUND(SUM(total_revenue), 2) as total_revenue,
    ROUND(AVG(avg_trip_distance), 2) as avg_distance,
    COUNT(DISTINCT DATE(pickup_hour)) as days_covered
FROM nyc_taxi_catalog.gold.hourly_location_metrics
WHERE DATE(pickup_hour) = '2015-01-01'
GROUP BY pickup_hour
ORDER BY pickup_hour
LIMIT 24;

-- =====================================================
-- 5. PERFORMANCE VALIDATION
-- =====================================================

-- 5.1 Query performance test - Simple aggregation
SELECT 
    'Performance Test - Simple' as validation_type,
    payment_type_desc,
    COUNT(*) as trip_count,
    ROUND(AVG(total_amount), 2) as avg_fare,
    ROUND(SUM(total_amount), 2) as total_revenue
FROM nyc_taxi_catalog.silver.nyc_taxi_trips
WHERE DATE(pickup_datetime) BETWEEN '2015-01-01' AND '2015-01-07'
GROUP BY payment_type_desc
ORDER BY trip_count DESC;

-- 5.2 Query performance test - Complex join
SELECT 
    'Performance Test - Complex' as validation_type,
    YEAR(s.pickup_datetime) as year,
    MONTH(s.pickup_datetime) as month,
    s.payment_type_desc,
    COUNT(*) as trip_count,
    ROUND(AVG(s.total_amount), 2) as avg_fare,
    ROUND(SUM(s.total_amount), 2) as total_revenue,
    ROUND(AVG(s.trip_distance), 2) as avg_distance
FROM nyc_taxi_catalog.silver.nyc_taxi_trips s
WHERE s.pickup_datetime >= '2015-01-01'
  AND s.pickup_datetime < '2015-02-01'
  AND s.total_amount > 0
GROUP BY YEAR(s.pickup_datetime), MONTH(s.pickup_datetime), s.payment_type_desc
ORDER BY year, month, trip_count DESC;

-- =====================================================
-- 6. WAREHOUSE VALIDATION  
-- =====================================================

-- 6.1 Fact table validation
SELECT 
    'Warehouse Fact Table' as validation_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT trip_id) as unique_trips,
    COUNT(DISTINCT pickup_date_key) as unique_dates,
    COUNT(DISTINCT vendor_id) as unique_vendors,
    COUNT(DISTINCT payment_type) as unique_payment_types,
    MIN(pickup_datetime) as min_date,
    MAX(pickup_datetime) as max_date,
    ROUND(SUM(total_amount), 2) as total_revenue
FROM nyc_taxi_catalog.warehouse.fact_taxi_trips;

-- 6.2 Dimensional integrity validation
SELECT 
    'Dimension Integrity' as validation_type,
    'fact_vs_silver' as comparison,
    f.record_count as fact_count,
    s.record_count as silver_count,
    ROUND((f.record_count * 100.0 / s.record_count), 2) as retention_rate,
    CASE 
        WHEN ABS(f.record_count - s.record_count) / s.record_count < 0.01 THEN 'EXCELLENT'
        WHEN ABS(f.record_count - s.record_count) / s.record_count < 0.05 THEN 'GOOD'
        ELSE 'REVIEW_NEEDED'
    END as quality_assessment
FROM (
    SELECT COUNT(*) as record_count 
    FROM nyc_taxi_catalog.warehouse.fact_taxi_trips
) f
CROSS JOIN (
    SELECT COUNT(*) as record_count 
    FROM nyc_taxi_catalog.silver.nyc_taxi_trips
) s;

-- =====================================================
-- 7. FINAL VALIDATION SUMMARY
-- =====================================================

-- 7.1 Overall pipeline health check
SELECT 
    'Pipeline Health Summary' as validation_type,
    CURRENT_TIMESTAMP() as validation_timestamp,
    'SILVER' as layer,
    COUNT(*) as record_count,
    ROUND(COUNT(CASE WHEN quality_flag = 'valid' THEN 1 END) * 100.0 / COUNT(*), 2) as quality_score,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,
    COUNT(DISTINCT DATE(pickup_datetime)) as days_of_data
FROM nyc_taxi_catalog.silver.nyc_taxi_trips

UNION ALL

SELECT 
    'Pipeline Health Summary' as validation_type,
    CURRENT_TIMESTAMP() as validation_timestamp,
    'GOLD' as layer,
    COUNT(*) as record_count,
    100.0 as quality_score,
    ROUND(AVG(total_revenue), 2) as avg_transaction_value,
    COUNT(DISTINCT DATE(pickup_hour)) as days_of_data
FROM nyc_taxi_catalog.gold.hourly_location_metrics

UNION ALL

SELECT 
    'Pipeline Health Summary' as validation_type,
    CURRENT_TIMESTAMP() as validation_timestamp,
    'WAREHOUSE' as layer,
    COUNT(*) as record_count,
    ROUND(COUNT(CASE WHEN quality_flag = 'valid' THEN 1 END) * 100.0 / COUNT(*), 2) as quality_score,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,
    COUNT(DISTINCT pickup_date_key) as days_of_data
FROM nyc_taxi_catalog.warehouse.fact_taxi_trips;

-- =====================================================
-- 8. DATA LINEAGE VALIDATION
-- =====================================================

-- 8.1 End-to-end data flow validation
WITH pipeline_metrics AS (
    SELECT 
        'END_TO_END_VALIDATION' as validation_type,
        COUNT(*) as silver_records,
        SUM(total_amount) as silver_revenue
    FROM nyc_taxi_catalog.silver.nyc_taxi_trips
),
gold_metrics AS (
    SELECT 
        SUM(total_revenue) as gold_revenue,
        SUM(total_trips) as gold_trips
    FROM nyc_taxi_catalog.gold.daily_revenue_metrics
),
warehouse_metrics AS (
    SELECT 
        COUNT(*) as warehouse_records,
        SUM(total_amount) as warehouse_revenue
    FROM nyc_taxi_catalog.warehouse.fact_taxi_trips
)
SELECT 
    p.validation_type,
    p.silver_records,
    w.warehouse_records,
    g.gold_trips,
    ROUND(p.silver_revenue, 2) as silver_revenue,
    ROUND(g.gold_revenue, 2) as gold_revenue,
    ROUND(w.warehouse_revenue, 2) as warehouse_revenue,
    ROUND(ABS(p.silver_revenue - g.gold_revenue) / p.silver_revenue * 100, 2) as silver_gold_variance_pct,
    ROUND(ABS(p.silver_revenue - w.warehouse_revenue) / p.silver_revenue * 100, 2) as silver_warehouse_variance_pct,
    CASE 
        WHEN ABS(p.silver_revenue - g.gold_revenue) / p.silver_revenue < 0.01 THEN '✅ EXCELLENT'
        WHEN ABS(p.silver_revenue - g.gold_revenue) / p.silver_revenue < 0.05 THEN '✅ GOOD'
        ELSE '⚠️ REVIEW_NEEDED'
    END as data_consistency_status
FROM pipeline_metrics p
CROSS JOIN gold_metrics g  
CROSS JOIN warehouse_metrics w;