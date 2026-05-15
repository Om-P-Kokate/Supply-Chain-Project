-- =============================================================================
-- FILE: 02_populate_date_dim.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Populate dim_date for calendar years 2020 through 2026
--
-- FISCAL YEAR ASSUMPTION: Fiscal year starts October 1.
--   Example: FY2025 = October 1, 2024 through September 30, 2025
--   Adjust the fiscal offset logic if your fiscal year differs.
--
-- US HOLIDAYS: Major US public holidays are flagged. Add/remove as needed
--   for other countries or regions.
--
-- ROLLING WINDOW FLAGS: is_current_*, is_prior_year are set at population
--   time as approximations. In production, run a nightly maintenance script
--   (see UPDATE block at the bottom) to refresh these flags.
--
-- COMPATIBILITY:
--   SQL Server: This script uses a WHILE loop + DATEADD/DATENAME functions.
--   PostgreSQL: Replace the WHILE loop with a generate_series() CTE.
--               See the PostgreSQL equivalent at the bottom of this file.
-- =============================================================================


-- =============================================================================
-- SQL SERVER VERSION
-- =============================================================================

DECLARE @StartDate  DATE = '2020-01-01';
DECLARE @EndDate    DATE = '2026-12-31';
DECLARE @CurrentDate DATE = @StartDate;

-- Truncate and reload (idempotent)
TRUNCATE TABLE dim_date;

WHILE @CurrentDate <= @EndDate
BEGIN

    DECLARE @DateKey        INT           = CONVERT(INT, FORMAT(@CurrentDate, 'yyyyMMdd'));
    DECLARE @DayOfWeek      TINYINT       = DATEPART(WEEKDAY, @CurrentDate);   -- 1=Sun, 7=Sat (SQL Server default)
    DECLARE @DayName        NVARCHAR(10)  = DATENAME(WEEKDAY, @CurrentDate);
    DECLARE @DayOfMonth     TINYINT       = DAY(@CurrentDate);
    DECLARE @DayOfYear      SMALLINT      = DATEPART(DAYOFYEAR, @CurrentDate);
    DECLARE @WeekOfYear     TINYINT       = DATEPART(ISO_WEEK, @CurrentDate);  -- ISO 8601 week
    DECLARE @MonthNumber    TINYINT       = MONTH(@CurrentDate);
    DECLARE @MonthName      NVARCHAR(10)  = DATENAME(MONTH, @CurrentDate);
    DECLARE @QuarterNumber  TINYINT       = DATEPART(QUARTER, @CurrentDate);
    DECLARE @YearNumber     SMALLINT      = YEAR(@CurrentDate);

    -- Month start / end dates
    DECLARE @MonthStart DATE = DATEFROMPARTS(@YearNumber, @MonthNumber, 1);
    DECLARE @MonthEnd   DATE = EOMONTH(@CurrentDate);

    -- Quarter start / end dates
    DECLARE @QuarterStartMonth TINYINT = (@QuarterNumber - 1) * 3 + 1;
    DECLARE @QuarterStart DATE = DATEFROMPARTS(@YearNumber, @QuarterStartMonth, 1);
    DECLARE @QuarterEnd   DATE = EOMONTH(DATEFROMPARTS(@YearNumber, @QuarterStartMonth + 2, 1));

    -- Weekend / weekday flags (1=Sunday, 7=Saturday)
    DECLARE @IsWeekend BIT = CASE WHEN @DayOfWeek IN (1, 7) THEN 1 ELSE 0 END;
    DECLARE @IsWeekday BIT = CASE WHEN @DayOfWeek IN (1, 7) THEN 0 ELSE 1 END;

    -- Week of month (approximate: ceiling of day / 7)
    DECLARE @WeekOfMonth TINYINT = CEILING(@DayOfMonth / 7.0);

    -- Day of quarter
    DECLARE @DayOfQuarter SMALLINT = DATEDIFF(DAY, @QuarterStart, @CurrentDate) + 1;

    -- ----------------------------------------------------------------------------
    -- US Holiday detection
    -- Fixed-date holidays
    -- ----------------------------------------------------------------------------
    DECLARE @IsHoliday  BIT = 0;
    DECLARE @HolidayName NVARCHAR(100) = NULL;

    -- New Year's Day (Jan 1)
    IF @MonthNumber = 1  AND @DayOfMonth = 1  BEGIN SET @IsHoliday = 1; SET @HolidayName = 'New Year''s Day'; END
    -- Independence Day (Jul 4)
    IF @MonthNumber = 7  AND @DayOfMonth = 4  BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Independence Day'; END
    -- Veterans Day (Nov 11)
    IF @MonthNumber = 11 AND @DayOfMonth = 11 BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Veterans Day'; END
    -- Christmas Day (Dec 25)
    IF @MonthNumber = 12 AND @DayOfMonth = 25 BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Christmas Day'; END
    -- Christmas Eve (Dec 24) - often observed as company holiday
    IF @MonthNumber = 12 AND @DayOfMonth = 24 BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Christmas Eve'; END
    -- New Year's Eve (Dec 31)
    IF @MonthNumber = 12 AND @DayOfMonth = 31 BEGIN SET @IsHoliday = 1; SET @HolidayName = 'New Year''s Eve'; END

    -- Floating holidays (nth weekday of month)
    -- MLK Day: 3rd Monday of January
    IF @MonthNumber = 1 AND @DayOfWeek = 2
       AND @DayOfMonth BETWEEN 15 AND 21
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Martin Luther King Jr. Day'; END

    -- Presidents Day: 3rd Monday of February
    IF @MonthNumber = 2 AND @DayOfWeek = 2
       AND @DayOfMonth BETWEEN 15 AND 21
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Presidents Day'; END

    -- Memorial Day: Last Monday of May
    IF @MonthNumber = 5 AND @DayOfWeek = 2
       AND @DayOfMonth BETWEEN 25 AND 31
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Memorial Day'; END

    -- Labor Day: 1st Monday of September
    IF @MonthNumber = 9 AND @DayOfWeek = 2
       AND @DayOfMonth BETWEEN 1 AND 7
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Labor Day'; END

    -- Columbus Day: 2nd Monday of October
    IF @MonthNumber = 10 AND @DayOfWeek = 2
       AND @DayOfMonth BETWEEN 8 AND 14
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Columbus Day'; END

    -- Thanksgiving: 4th Thursday of November
    IF @MonthNumber = 11 AND @DayOfWeek = 5
       AND @DayOfMonth BETWEEN 22 AND 28
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Thanksgiving Day'; END

    -- Day after Thanksgiving (Black Friday - common plant shutdown)
    IF @MonthNumber = 11 AND @DayOfWeek = 6
       AND @DayOfMonth BETWEEN 23 AND 29
    BEGIN SET @IsHoliday = 1; SET @HolidayName = 'Day After Thanksgiving'; END

    -- Business day = weekday AND not a holiday
    DECLARE @IsBusinessDay BIT = CASE WHEN @IsWeekday = 1 AND @IsHoliday = 0 THEN 1 ELSE 0 END;

    -- ----------------------------------------------------------------------------
    -- Fiscal year calculation (fiscal year starts October 1)
    -- ----------------------------------------------------------------------------
    DECLARE @FiscalYear    SMALLINT;
    DECLARE @FiscalMonth   TINYINT;
    DECLARE @FiscalQuarter TINYINT;

    -- If month >= October, fiscal year = calendar year + 1; fiscal month = month - 9
    -- If month < October,  fiscal year = calendar year;     fiscal month = month + 3
    IF @MonthNumber >= 10
    BEGIN
        SET @FiscalYear  = @YearNumber + 1;
        SET @FiscalMonth = @MonthNumber - 9;
    END
    ELSE
    BEGIN
        SET @FiscalYear  = @YearNumber;
        SET @FiscalMonth = @MonthNumber + 3;
    END

    SET @FiscalQuarter = CEILING(@FiscalMonth / 3.0);

    -- Rolling window flags (approximate; refresh nightly in production)
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @IsCurrentDay     BIT = CASE WHEN @CurrentDate = @Today THEN 1 ELSE 0 END;
    DECLARE @IsCurrentWeek    BIT = CASE WHEN DATEPART(ISO_WEEK, @CurrentDate) = DATEPART(ISO_WEEK, @Today)
                                              AND YEAR(@CurrentDate) = YEAR(@Today) THEN 1 ELSE 0 END;
    DECLARE @IsCurrentMonth   BIT = CASE WHEN @MonthNumber = MONTH(@Today)
                                              AND @YearNumber = YEAR(@Today) THEN 1 ELSE 0 END;
    DECLARE @IsCurrentQuarter BIT = CASE WHEN @QuarterNumber = DATEPART(QUARTER, @Today)
                                              AND @YearNumber = YEAR(@Today) THEN 1 ELSE 0 END;
    DECLARE @IsCurrentYear    BIT = CASE WHEN @YearNumber = YEAR(@Today) THEN 1 ELSE 0 END;
    DECLARE @IsPriorYear      BIT = CASE WHEN @YearNumber = YEAR(@Today) - 1 THEN 1 ELSE 0 END;

    -- ----------------------------------------------------------------------------
    -- Insert row
    -- ----------------------------------------------------------------------------
    INSERT INTO dim_date (
        date_key, full_date,
        day_of_week, day_name, day_name_short,
        day_of_month, day_of_quarter, day_of_year,
        week_of_year, week_of_month,
        month_number, month_name, month_name_short,
        month_start_date, month_end_date,
        quarter_number, quarter_name, quarter_start_date, quarter_end_date,
        year_number, year_month, year_quarter,
        is_weekend, is_weekday, is_holiday, holiday_name, is_business_day,
        fiscal_year, fiscal_quarter, fiscal_month, fiscal_year_quarter,
        is_current_day, is_current_week, is_current_month,
        is_current_quarter, is_current_year, is_prior_year
    )
    VALUES (
        @DateKey, @CurrentDate,
        @DayOfWeek, @DayName, LEFT(@DayName, 3),
        @DayOfMonth, @DayOfQuarter, @DayOfYear,
        @WeekOfYear, @WeekOfMonth,
        @MonthNumber, @MonthName, LEFT(@MonthName, 3),
        @MonthStart, @MonthEnd,
        @QuarterNumber, CONCAT('Q', @QuarterNumber), @QuarterStart, @QuarterEnd,
        @YearNumber,
        FORMAT(@CurrentDate, 'yyyy-MM'),
        CONCAT(@YearNumber, '-Q', @QuarterNumber),
        @IsWeekend, @IsWeekday, @IsHoliday, @HolidayName, @IsBusinessDay,
        @FiscalYear, @FiscalQuarter, @FiscalMonth,
        CONCAT('FY', @FiscalYear, 'Q', @FiscalQuarter),
        @IsCurrentDay, @IsCurrentWeek, @IsCurrentMonth,
        @IsCurrentQuarter, @IsCurrentYear, @IsPriorYear
    );

    SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
END;

-- Verify load
SELECT
    MIN(full_date)      AS first_date,
    MAX(full_date)      AS last_date,
    COUNT(*)            AS total_rows,
    SUM(is_holiday)     AS holiday_days,
    SUM(is_weekend)     AS weekend_days,
    SUM(is_business_day) AS business_days
FROM dim_date;


-- =============================================================================
-- NIGHTLY MAINTENANCE: Refresh rolling window flags
-- Run this as a scheduled job each night after midnight
-- =============================================================================

/*
UPDATE dim_date SET
    is_current_day     = CASE WHEN full_date = CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END,
    is_current_week    = CASE WHEN DATEPART(ISO_WEEK, full_date) = DATEPART(ISO_WEEK, GETDATE())
                                   AND year_number = YEAR(GETDATE()) THEN 1 ELSE 0 END,
    is_current_month   = CASE WHEN month_number = MONTH(GETDATE())
                                   AND year_number = YEAR(GETDATE()) THEN 1 ELSE 0 END,
    is_current_quarter = CASE WHEN quarter_number = DATEPART(QUARTER, GETDATE())
                                   AND year_number = YEAR(GETDATE()) THEN 1 ELSE 0 END,
    is_current_year    = CASE WHEN year_number = YEAR(GETDATE()) THEN 1 ELSE 0 END,
    is_prior_year      = CASE WHEN year_number = YEAR(GETDATE()) - 1 THEN 1 ELSE 0 END;
*/


-- =============================================================================
-- POSTGRESQL EQUIVALENT
-- Replace the WHILE loop above with this generate_series() approach
-- =============================================================================

/*
-- PostgreSQL version

TRUNCATE TABLE dim_date;

INSERT INTO dim_date (
    date_key, full_date,
    day_of_week, day_name, day_name_short,
    day_of_month, day_of_quarter, day_of_year,
    week_of_year, week_of_month,
    month_number, month_name, month_name_short,
    month_start_date, month_end_date,
    quarter_number, quarter_name, quarter_start_date, quarter_end_date,
    year_number, year_month, year_quarter,
    is_weekend, is_weekday, is_holiday, holiday_name, is_business_day,
    fiscal_year, fiscal_quarter, fiscal_month, fiscal_year_quarter,
    is_current_day, is_current_week, is_current_month,
    is_current_quarter, is_current_year, is_prior_year
)
WITH date_series AS (
    SELECT generate_series(
        '2020-01-01'::date,
        '2026-12-31'::date,
        '1 day'::interval
    )::date AS d
),
base AS (
    SELECT
        d,
        TO_CHAR(d, 'YYYYMMDD')::INT                 AS date_key,
        EXTRACT(ISODOW FROM d)::SMALLINT             AS dow_iso,       -- 1=Mon, 7=Sun
        TO_CHAR(d, 'Day')                            AS day_name_full,
        TO_CHAR(d, 'Dy')                             AS day_name_short,
        EXTRACT(DAY   FROM d)::SMALLINT              AS day_of_month,
        EXTRACT(DOY   FROM d)::SMALLINT              AS day_of_year,
        EXTRACT(WEEK  FROM d)::SMALLINT              AS week_of_year,
        EXTRACT(MONTH FROM d)::SMALLINT              AS month_num,
        TO_CHAR(d, 'Month')                          AS month_name_full,
        TO_CHAR(d, 'Mon')                            AS month_name_short,
        EXTRACT(QUARTER FROM d)::SMALLINT            AS quarter_num,
        EXTRACT(YEAR  FROM d)::SMALLINT              AS year_num,
        DATE_TRUNC('month',   d)::date               AS month_start,
        (DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day')::date AS month_end,
        DATE_TRUNC('quarter', d)::date               AS quarter_start,
        (DATE_TRUNC('quarter',d) + INTERVAL '3 months - 1 day')::date AS quarter_end
    FROM date_series
),
fiscal AS (
    SELECT
        *,
        CASE WHEN month_num >= 10 THEN year_num + 1 ELSE year_num END  AS fiscal_year,
        CASE WHEN month_num >= 10 THEN month_num - 9 ELSE month_num + 3 END AS fiscal_month_num
    FROM base
)
SELECT
    date_key,
    d                                                               AS full_date,
    -- PostgreSQL ISODOW: 1=Mon ... 7=Sun; convert to 1=Sun...7=Sat for consistency
    CASE WHEN dow_iso = 7 THEN 1 ELSE dow_iso + 1 END              AS day_of_week,
    TRIM(day_name_full)                                             AS day_name,
    day_name_short                                                  AS day_name_short,
    day_of_month,
    (d - quarter_start + 1)::SMALLINT                              AS day_of_quarter,
    day_of_year,
    week_of_year,
    CEIL(day_of_month / 7.0)::SMALLINT                             AS week_of_month,
    month_num                                                       AS month_number,
    TRIM(month_name_full)                                           AS month_name,
    month_name_short,
    month_start                                                     AS month_start_date,
    month_end                                                       AS month_end_date,
    quarter_num                                                     AS quarter_number,
    'Q' || quarter_num                                             AS quarter_name,
    quarter_start                                                   AS quarter_start_date,
    quarter_end                                                     AS quarter_end_date,
    year_num                                                        AS year_number,
    TO_CHAR(d, 'YYYY-MM')                                          AS year_month,
    year_num || '-Q' || quarter_num                                AS year_quarter,
    -- Weekend: ISO 6=Sat, 7=Sun
    CASE WHEN dow_iso IN (6,7) THEN TRUE ELSE FALSE END            AS is_weekend,
    CASE WHEN dow_iso IN (6,7) THEN FALSE ELSE TRUE END            AS is_weekday,
    FALSE                                                           AS is_holiday,   -- update separately
    NULL                                                            AS holiday_name,
    CASE WHEN dow_iso NOT IN (6,7) THEN TRUE ELSE FALSE END        AS is_business_day,
    fiscal_year,
    CEIL(fiscal_month_num / 3.0)::SMALLINT                         AS fiscal_quarter,
    fiscal_month_num                                                AS fiscal_month,
    'FY' || fiscal_year || 'Q' || CEIL(fiscal_month_num / 3.0)    AS fiscal_year_quarter,
    d = CURRENT_DATE                                               AS is_current_day,
    EXTRACT(WEEK FROM d) = EXTRACT(WEEK FROM CURRENT_DATE)
        AND year_num = EXTRACT(YEAR FROM CURRENT_DATE)             AS is_current_week,
    month_num = EXTRACT(MONTH FROM CURRENT_DATE)
        AND year_num = EXTRACT(YEAR FROM CURRENT_DATE)             AS is_current_month,
    quarter_num = EXTRACT(QUARTER FROM CURRENT_DATE)
        AND year_num = EXTRACT(YEAR FROM CURRENT_DATE)             AS is_current_quarter,
    year_num = EXTRACT(YEAR FROM CURRENT_DATE)                     AS is_current_year,
    year_num = EXTRACT(YEAR FROM CURRENT_DATE) - 1                 AS is_prior_year
FROM fiscal;

-- Verification
SELECT
    MIN(full_date) AS first_date,
    MAX(full_date) AS last_date,
    COUNT(*)       AS total_rows,
    SUM(CASE WHEN is_weekend  THEN 1 ELSE 0 END) AS weekend_days,
    SUM(CASE WHEN is_business_day THEN 1 ELSE 0 END) AS business_days
FROM dim_date;
*/


-- =============================================================================
-- END OF FILE: 02_populate_date_dim.sql
-- =============================================================================
