-- =========================================================
-- 1. CREATE DATABASE
-- =========================================================

CREATE DATABASE IF NOT EXISTS HOTEL_DB;

USE DATABASE HOTEL_DB;

USE SCHEMA PUBLIC;


-- =========================================================
-- 2. CREATE FILE FORMAT
-- =========================================================

CREATE OR REPLACE FILE FORMAT FF_CSV
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '');


-- =========================================================
-- 3. CREATE STAGE
-- =========================================================

CREATE OR REPLACE STAGE STG_HOTEL_BOOKINGS
    FILE_FORMAT = FF_CSV;


-- =========================================================
-- 4. BRONZE TABLE
-- =========================================================

CREATE OR REPLACE TABLE BRONZE_HOTEL_BOOKING (
    booking_id STRING,
    hotel_id STRING,
    hotel_city STRING,
    customer_id STRING,
    customer_name STRING,
    customer_email STRING,
    check_in_date STRING,
    check_out_date STRING,
    room_type STRING,
    num_guests STRING,
    total_amount STRING,
    currency STRING,
    booking_status STRING
);


-- =========================================================
-- 5. LOAD DATA FROM STAGE TO BRONZE
-- =========================================================

COPY INTO BRONZE_HOTEL_BOOKING
FROM @STG_HOTEL_BOOKINGS
FILE_FORMAT = (FORMAT_NAME = FF_CSV)
ON_ERROR = 'CONTINUE';


-- Check Bronze data

SELECT *
FROM BRONZE_HOTEL_BOOKING
LIMIT 50;


-- =========================================================
-- 6. CREATE SILVER TABLE
-- =========================================================

CREATE OR REPLACE TABLE SILVER_HOTEL_BOOKING (
    booking_id VARCHAR,
    hotel_id VARCHAR,
    hotel_city VARCHAR,
    customer_id VARCHAR,
    customer_name VARCHAR,
    customer_email VARCHAR,
    check_in_date DATE,
    check_out_date DATE,
    room_type VARCHAR,
    num_guests INTEGER,
    total_amount FLOAT,
    currency VARCHAR,
    booking_status VARCHAR
);


-- =========================================================
-- 7. DATA QUALITY CHECKS
-- =========================================================

-- Invalid email

SELECT customer_email
FROM BRONZE_HOTEL_BOOKING
WHERE NOT (customer_email LIKE '%@%.%')
   OR customer_email IS NULL;


-- Negative amount

SELECT total_amount
FROM BRONZE_HOTEL_BOOKING
WHERE TRY_TO_NUMBER(total_amount) < 0;


-- Invalid dates

SELECT
    check_in_date,
    check_out_date
FROM BRONZE_HOTEL_BOOKING
WHERE TRY_TO_DATE(check_out_date)
      < TRY_TO_DATE(check_in_date);


-- Booking statuses

SELECT DISTINCT booking_status
FROM BRONZE_HOTEL_BOOKING;


-- =========================================================
-- 8. INSERT CLEAN DATA INTO SILVER
-- =========================================================

INSERT INTO SILVER_HOTEL_BOOKING
SELECT
    booking_id,

    hotel_id,

    INITCAP(TRIM(hotel_city)) AS hotel_city,

    customer_id,

    INITCAP(TRIM(customer_name)) AS customer_name,

    CASE
        WHEN customer_email LIKE '%@%.%'
        THEN LOWER(TRIM(customer_email))
        ELSE NULL
    END AS customer_email,

    TRY_TO_DATE(NULLIF(check_in_date, ''))
        AS check_in_date,

    TRY_TO_DATE(NULLIF(check_out_date, ''))
        AS check_out_date,

    TRIM(room_type) AS room_type,

    TRY_TO_NUMBER(num_guests)
        AS num_guests,

    ABS(TRY_TO_NUMBER(total_amount))
        AS total_amount,

    UPPER(TRIM(currency))
        AS currency,

    CASE
        WHEN LOWER(TRIM(booking_status))
             IN ('confirmeeed', 'confirmd')
        THEN 'Confirmed'

        ELSE INITCAP(TRIM(booking_status))
    END AS booking_status

FROM BRONZE_HOTEL_BOOKING

WHERE
    TRY_TO_DATE(check_in_date) IS NOT NULL

    AND TRY_TO_DATE(check_out_date) IS NOT NULL

    AND TRY_TO_DATE(check_out_date)
        >= TRY_TO_DATE(check_in_date);


-- Check Silver data

SELECT *
FROM SILVER_HOTEL_BOOKING
LIMIT 30;


-- =========================================================
-- 9. GOLD TABLE - CLEAN BOOKING DATA
-- =========================================================

CREATE OR REPLACE TABLE GOLD_BOOKING_CLEAN AS

SELECT
    booking_id,
    hotel_id,
    hotel_city,
    customer_id,
    customer_name,
    customer_email,
    check_in_date,
    check_out_date,
    room_type,
    num_guests,
    total_amount,
    currency,
    booking_status

FROM SILVER_HOTEL_BOOKING;


-- =========================================================
-- 10. GOLD TABLE - DAILY BOOKINGS
-- =========================================================

CREATE OR REPLACE TABLE GOLD_AGG_DAILY_BOOKING AS

SELECT
    check_in_date AS date,

    COUNT(*) AS total_booking,

    SUM(total_amount) AS total_revenue

FROM SILVER_HOTEL_BOOKING

GROUP BY check_in_date

ORDER BY date;


-- =========================================================
-- 11. GOLD TABLE - REVENUE BY CITY
-- =========================================================

CREATE OR REPLACE TABLE GOLD_AGG_HOTEL_CITY AS

SELECT
    hotel_city,

    SUM(total_amount) AS total_revenue

FROM SILVER_HOTEL_BOOKING

GROUP BY hotel_city

ORDER BY total_revenue DESC;


-- =========================================================
-- 12. GOLD TABLE - MONTHLY BOOKINGS & REVENUE
-- =========================================================

CREATE OR REPLACE TABLE GOLD_AGG_MONTHLY_BOOKING AS

SELECT
    DATE_TRUNC('MONTH', check_in_date) AS month,

    COUNT(*) AS total_booking,

    SUM(total_amount) AS total_revenue

FROM GOLD_BOOKING_CLEAN

GROUP BY DATE_TRUNC('MONTH', check_in_date)

ORDER BY month;


-- =========================================================
-- 13. CHECK GOLD TABLES
-- =========================================================

SELECT *
FROM GOLD_BOOKING_CLEAN
LIMIT 30;


SELECT *
FROM GOLD_AGG_DAILY_BOOKING
LIMIT 30;


SELECT *
FROM GOLD_AGG_HOTEL_CITY
LIMIT 30;


SELECT *
FROM GOLD_AGG_MONTHLY_BOOKING
LIMIT 30;