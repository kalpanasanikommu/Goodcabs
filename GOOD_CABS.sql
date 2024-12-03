USE trips_db;
----------------------------------------------------------------------------------------------------------------------
/*1.CITY LEVEL FARE AND TRIP SUMMARY*/

SELECT city_name,COUNT(trip_id) as Total_trips, ROUND((SUM(fare_amount) /SUM(distance_travelled_km)),2) as Avg_fare_per_km ,
ROUND((SUM(fare_amount)/COUNT(trip_id)),2) as Avg_fare_per_trip ,
ROUND(((COUNT(C1.trip_id) / (SELECT COUNT(trip_id) FROM fact_trips)) * 100),2) AS City_perc_contribution
FROM trips_db.fact_trips C1
INNER JOIN
trips_db.dim_city C2
ON C1.city_id = C2.city_id
GROUP BY C2.city_name


------------------------------------------------------------------------------------------------------------
/*2. MONTHLY CITY LEVEL TRIPS TERGET PERFORMANCE REPORT*/

WITH Actual_trips AS (
       SELECT
        c.city_name,
        d.month_name,
        COUNT(f.trip_id) AS actual_trips                 
    FROM trips_db.fact_trips f
    JOIN trips_db.dim_city c ON f.city_id = c.city_id 
    JOIN trips_db.dim_date d ON d.date = f.date   
    GROUP BY c.city_name, d.month_name
),
Target_trips AS (
       SELECT
        c.city_name,
        d.month_name,
        SUM(total_target_trips) AS target_trips                
    FROM targets_db.monthly_target_trips mt
    JOIN trips_db.dim_city c ON mt.city_id = c.city_id
    JOIN trips_db.dim_date d ON d.date = mt.month   
    GROUP BY c.city_name, d.month_name)

-- Final selection of the report
SELECT 
    a.city_name,
    a.month_name,
    a.actual_trips,
    t.target_trips,
    CASE 
        WHEN t.target_trips = 0 THEN NULL  -- Prevent division by zero
		ELSE ROUND(((actual_trips - target_trips) / NULLIF(target_trips, 0)) * 100,2)
        END AS percentage_difference,
        
    CASE 
		WHEN actual_trips > target_trips THEN 'Above Target'
		ELSE 'Below Target'
        END AS performance_status
FROM Actual_trips a
JOIN Target_trips t
ON a.city_name = t.city_name AND a.month_name = t.month_name
ORDER BY a.city_name, a.month_name;

----------------------------------------------------------------------------------------------
/*3.CITY LEVEL REPORT PASSENGER TRIP FREQUENCY REPORT*/

SELECT city_name,trip_count,sum(repeat_passenger_count)/sum(total_passengers)*100 as repeat_passenger_pct
FROM trips_db.dim_city C
JOIN trips_db.dim_repeat_trip_distribution R
ON C.city_id = R.city_id
JOIN trips_db.fact_passenger_summary P
ON R.city_id = P.city_id
GROUP BY city_name,trip_count;




------------------------------------------
-------------------------------------------

SELECT
c.city_name,
ROUND(
(SUM(CASE WHEN R.trip_count = 2 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "2-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 3 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count))*100, 2) AS "3-Trips", 
ROUND(
(SUM(CASE WHEN R.trip_count = 4 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count))*100, 2) AS "4-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count =  5 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "5-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 6 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "6-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 7 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "7-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 8 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "8-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 9 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "9-Trips",
ROUND(
(SUM(CASE WHEN R.trip_count = 10 THEN R.repeat_passenger_count ELSE 0 END)/SUM(R.repeat_passenger_count)) * 100, 2) AS "10-Trips"
FROM
dim_city c
JOIN
dim_repeat_trip_distribution R ON R.city_id = c.city_id
GROUP BY c.city_name;
------------------------------------------------------------------------------
/*4.IDENTIFY CITIES WITH HIGHEST AND LOWEST TOTAL NEW PASSENGERS*/

WITH city_info AS (SELECT city_name,SUM(new_passengers) as Total_new_passengers,
				RANK() OVER (order by SUM(new_passengers) desc) AS City_rank
FROM trips_db.fact_passenger_summary p
JOIN trips_db.dim_city c
ON p.city_id = c.city_id
GROUP BY city_name)

SELECT city_name,Total_new_passengers,
CASE WHEN city_rank <= 3 THEN 'Top 3'
WHEN  city_rank > 7 THEN 'Bottom 3' 
END City_category
FROM city_info
WHERE city_rank <=3 OR city_rank>7


------------------------------------------------------------------------
/*5.IDENTIFY MONTH WITH HIGHEST REVENUE FOR EACH CITY-completed*/
------------------------------------------------------------------------

WITH MonthlyRevenue AS (
    -- Calculate the total revenue for each city by month
    SELECT 
        c.city_name,
        m.month_name,
        SUM(s.fare_amount) AS revenue
    FROM trips_db.fact_trips s
    JOIN trips_db.dim_date m ON s.date = m.date
    JOIN trips_db.dim_city c ON s.city_id = c.city_id
    GROUP BY c.city_name, m.month_name
),
TotalRevenue AS (
    -- Calculate the total revenue for each city
    SELECT 
        c.city_name,
        SUM(s.fare_amount) AS total_revenue
    FROM trips_db.fact_trips s
    JOIN trips_db.dim_city c ON s.city_id = c.city_id
    GROUP BY c.city_name
),
MaxRevenueMonth AS (
    -- Identify the month with the highest revenue for each city using ROW_NUMBER()
    SELECT 
        r.city_name,
        r.month_name AS highest_revenue_month,
        r.revenue,
        ROW_NUMBER() OVER (PARTITION BY r.city_name ORDER BY r.revenue DESC) AS rank_
    FROM MonthlyRevenue r
)
    

-- Final query to calculate percentage contribution
SELECT 
    m.city_name,
    m.highest_revenue_month,
    m.revenue,
    ROUND((m.revenue / t.total_revenue) * 100,2) AS percentage_contribution
FROM MaxRevenueMonth m
JOIN TotalRevenue t ON m.city_name = t.city_name
where m.rank_ = 1
ORDER BY m.city_name;

------------------------------------------------------------------------------------
/*6.REPEAT PASSENGER RATE ANALYSIS -COMPLETED*/

use trips_db

WITH MonthlyRepeatRate AS (
        SELECT
        c.city_name,
        d.month_name AS month,
        SUM(f.total_passengers) AS total_passengers,
        SUM(f.repeat_passengers) AS repeat_passengers,
       ROUND((SUM(f.repeat_passengers) / NULLIF(SUM(f.total_passengers), 0)) * 100,2) AS monthly_repeat_passenger_rate
    FROM fact_passenger_summary f
    JOIN dim_city c ON f.city_id = c.city_id
    JOIN dim_date d ON f.month = d.date
    GROUP BY c.city_name, d.month_name
),
CityWideRepeatRate AS (
        SELECT
        c.city_name,
        SUM(f.total_passengers) AS total_passengers_across_months,
        SUM(f.repeat_passengers) AS total_repeat_passengers,
		ROUND((SUM(f.repeat_passengers) / NULLIF(SUM(f.total_passengers), 0)) * 100,2) AS city_repeat_passenger_rate
    FROM fact_passenger_summary f
    JOIN dim_city c ON f.city_id = c.city_id
    GROUP BY c.city_name
)
-- Combine the results from both CTEs
SELECT
    m.city_name,
    m.month,
    m.total_passengers,
    m.repeat_passengers,
    m.monthly_repeat_passenger_rate,
    c.city_repeat_passenger_rate
FROM MonthlyRepeatRate m
JOIN CityWideRepeatRate c ON m.city_name = c.city_name
ORDER BY m.city_name, m.month;
 