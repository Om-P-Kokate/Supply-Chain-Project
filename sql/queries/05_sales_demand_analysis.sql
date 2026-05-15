-- =============================================================================
-- FILE: 05_sales_demand_analysis.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Sales revenue, demand patterns, and forecast accuracy analysis
--
-- BUSINESS CONTEXT:
--   Accurate demand forecasting is the cornerstone of supply chain planning.
--   Forecast error drives excess inventory (overstock) when demand is
--   over-predicted, and stockouts/production stoppages when under-predicted.
--   A 10% improvement in forecast accuracy typically reduces inventory by
--   5-8% while simultaneously improving service levels.
--
--   These queries support the monthly S&OP (Sales & Operations Planning)
--   process, quarterly business planning, and executive reporting on
--   commercial performance.
--
-- KEY METRICS:
--   - Revenue by Segment: Tracks vehicle mix and pricing trends
--   - Forecast Accuracy: MAPE (Mean Absolute Percentage Error) - target <10%
--   - Year-over-Year (YoY) Growth: Comparable period revenue comparison
--   - Seasonal Index: Demand relative to annual average by month
--   - Fill Rate: % of customer demand fulfilled from stock (target >98%)
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: GETDATE() -> CURRENT_DATE, ISNULL() -> COALESCE(),
--                 TOP N -> LIMIT N
-- =============================================================================


-- =============================================================================
-- QUERY 1: Revenue by Vehicle Type and Region
-- =============================================================================
-- BUSINESS PURPOSE:
--   Revenue breakdown by vehicle segment and customer region reveals which
--   combinations are most profitable and where growth is occurring. Used in
--   product portfolio decisions (what to build more/less of) and regional
--   sales force allocation.
--
--   Vehicle segments: Truck, SUV, Sedan, EV, Van
--   Metric: Net revenue, gross margin, and average transaction value
-- =============================================================================

SELECT
    v.vehicle_segment,
    v.powertrain_type,
    v.brand,
    r.continent,
    r.region_name                                                   AS customer_region,
    r.country                                                       AS customer_country,
    d.year_number,
    d.quarter_name,
    d.year_quarter,

    -- Volume
    COUNT(DISTINCT fs.order_number)                                 AS order_count,
    SUM(fs.quantity_ordered)                                        AS units_ordered,
    SUM(fs.quantity_fulfilled)                                      AS units_fulfilled,

    -- Revenue metrics
    ROUND(SUM(fs.gross_revenue_usd), 0)                             AS gross_revenue_usd,
    ROUND(SUM(fs.discount_amount_usd), 0)                           AS total_discounts_usd,
    ROUND(SUM(fs.net_revenue_usd), 0)                               AS net_revenue_usd,
    ROUND(SUM(fs.cogs_usd), 0)                                      AS total_cogs_usd,
    ROUND(SUM(fs.gross_margin_usd), 0)                              AS gross_margin_usd,

    -- Unit economics
    ROUND(AVG(fs.unit_price_usd), 2)                                AS avg_transaction_price_usd,
    ROUND(SUM(fs.net_revenue_usd) / NULLIF(SUM(fs.quantity_ordered), 0), 2) AS net_revenue_per_unit_usd,
    ROUND(
        100.0 * SUM(fs.gross_margin_usd) / NULLIF(SUM(fs.net_revenue_usd), 0),
        1
    )                                                               AS gross_margin_pct,
    ROUND(
        100.0 * SUM(fs.discount_amount_usd) / NULLIF(SUM(fs.gross_revenue_usd), 0),
        1
    )                                                               AS avg_discount_pct,

    -- Fill rate (fulfillment quality)
    ROUND(
        100.0 * SUM(fs.quantity_fulfilled) / NULLIF(SUM(fs.quantity_ordered), 0),
        1
    )                                                               AS fill_rate_pct,

    -- Revenue share within segment (window function)
    ROUND(
        100.0 * SUM(fs.net_revenue_usd)
              / SUM(SUM(fs.net_revenue_usd)) OVER (PARTITION BY v.vehicle_segment, d.year_number),
        1
    )                                                               AS pct_of_segment_revenue,

    -- Revenue share overall in year
    ROUND(
        100.0 * SUM(fs.net_revenue_usd)
              / SUM(SUM(fs.net_revenue_usd)) OVER (PARTITION BY d.year_number),
        2
    )                                                               AS pct_of_annual_revenue

FROM fact_sales         fs
JOIN dim_vehicle        v  ON fs.vehicle_key           = v.vehicle_key
JOIN dim_region         r  ON fs.customer_region_key   = r.region_key
JOIN dim_date           d  ON fs.order_date_key         = d.date_key

WHERE
    d.year_number >= YEAR(GETDATE()) - 2   -- 3-year trend
    AND fs.order_status NOT IN ('Cancelled')
    AND fs.vehicle_key IS NOT NULL         -- Vehicle sales only

GROUP BY
    v.vehicle_segment, v.powertrain_type, v.brand,
    r.continent, r.region_name, r.country,
    d.year_number, d.quarter_name, d.year_quarter

ORDER BY
    d.year_quarter,
    net_revenue_usd DESC;


-- =============================================================================
-- QUERY 2: Forecast Accuracy Analysis (MAPE)
-- =============================================================================
-- BUSINESS PURPOSE:
--   Measures forecast accuracy using MAPE (Mean Absolute Percentage Error).
--   MAPE = Average of |Actual - Forecast| / Actual * 100
--   Lower is better. Industry target for automotive: MAPE < 10%.
--
--   Broken down by vehicle segment, region, and time period to identify:
--   - Which segments are hardest to forecast (highest MAPE)
--   - Whether forecast accuracy improves closer to the production date
--   - Seasonal periods with consistently high error (need model adjustment)
-- =============================================================================

SELECT
    v.vehicle_segment,
    r.region_name                                                   AS customer_region,
    d.year_number,
    d.month_number,
    d.month_name_short,
    d.year_month,

    -- Actuals vs forecast
    ROUND(SUM(fs.quantity_fulfilled), 0)                            AS actual_units,
    ROUND(SUM(ISNULL(fs.forecasted_quantity, 0)), 0)                AS forecast_units,
    ROUND(SUM(fs.quantity_fulfilled) - SUM(ISNULL(fs.forecasted_quantity, 0)), 0) AS forecast_error_units,

    -- Bias: positive = over-forecast (produced more than sold), negative = under-forecast
    ROUND(
        SUM(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0))
        / NULLIF(SUM(ISNULL(fs.forecasted_quantity, 0)), 0) * 100,
        1
    )                                                               AS forecast_bias_pct,

    -- MAPE (mean absolute percentage error)
    ROUND(
        AVG(
            ABS(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0))
            / NULLIF(ABS(fs.quantity_fulfilled), 0) * 100
        ),
        1
    )                                                               AS mape_pct,

    -- Weighted MAPE (weights by actual volume - less influenced by small-volume lines)
    ROUND(
        SUM(ABS(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0)))
        / NULLIF(SUM(ABS(fs.quantity_fulfilled)), 0) * 100,
        1
    )                                                               AS weighted_mape_pct,

    -- Count of order lines with forecasts
    COUNT(CASE WHEN fs.forecasted_quantity IS NOT NULL THEN 1 END)  AS lines_with_forecast,
    COUNT(fs.sales_id)                                              AS total_order_lines,

    -- Accuracy classification
    CASE
        WHEN AVG(
            ABS(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0))
            / NULLIF(ABS(fs.quantity_fulfilled), 0) * 100
        ) <= 5  THEN 'Excellent (<5% MAPE)'
        WHEN AVG(
            ABS(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0))
            / NULLIF(ABS(fs.quantity_fulfilled), 0) * 100
        ) <= 10 THEN 'Good (5-10% MAPE)'
        WHEN AVG(
            ABS(fs.quantity_fulfilled - ISNULL(fs.forecasted_quantity, 0))
            / NULLIF(ABS(fs.quantity_fulfilled), 0) * 100
        ) <= 20 THEN 'Acceptable (10-20% MAPE)'
        ELSE 'Poor (>20% MAPE) - Review forecasting model'
    END                                                             AS accuracy_classification

FROM fact_sales         fs
JOIN dim_vehicle        v ON fs.vehicle_key         = v.vehicle_key
JOIN dim_region         r ON fs.customer_region_key = r.region_key
JOIN dim_date           d ON fs.order_date_key      = d.date_key

WHERE
    d.year_number >= YEAR(GETDATE()) - 1
    AND fs.quantity_fulfilled IS NOT NULL
    AND fs.forecasted_quantity IS NOT NULL
    AND fs.order_status NOT IN ('Cancelled')

GROUP BY
    v.vehicle_segment, r.region_name,
    d.year_number, d.month_number, d.month_name_short, d.year_month

HAVING COUNT(fs.sales_id) >= 5

ORDER BY
    d.year_month, v.vehicle_segment, weighted_mape_pct DESC;


-- =============================================================================
-- QUERY 3: Year-over-Year Revenue Growth Analysis
-- =============================================================================
-- BUSINESS PURPOSE:
--   Comparable period revenue analysis is the primary commercial KPI.
--   YoY growth controls for seasonality (e.g., Q4 is typically strong
--   for trucks/SUVs due to year-end fleet purchases).
--   Used in quarterly earnings reporting and investor communications.
-- =============================================================================

WITH annual_revenue AS (
    SELECT
        v.vehicle_segment,
        v.powertrain_type,
        r.continent,
        r.region_name                                               AS customer_region,
        d.year_number,
        d.month_number,
        d.year_month,

        SUM(fs.net_revenue_usd)                                     AS net_revenue_usd,
        SUM(fs.gross_margin_usd)                                    AS gross_margin_usd,
        SUM(fs.quantity_fulfilled)                                   AS units_sold

    FROM fact_sales     fs
    JOIN dim_vehicle    v ON fs.vehicle_key         = v.vehicle_key
    JOIN dim_region     r ON fs.customer_region_key = r.region_key
    JOIN dim_date       d ON fs.order_date_key      = d.date_key
    WHERE
        d.year_number >= YEAR(GETDATE()) - 2
        AND fs.order_status NOT IN ('Cancelled')
    GROUP BY
        v.vehicle_segment, v.powertrain_type,
        r.continent, r.region_name,
        d.year_number, d.month_number, d.year_month
)
SELECT
    ar.vehicle_segment,
    ar.powertrain_type,
    ar.continent,
    ar.customer_region,
    ar.year_number,
    ar.month_number,
    ar.year_month,

    -- Current period
    ROUND(ar.net_revenue_usd, 0)                                    AS net_revenue_usd,
    ROUND(ar.units_sold, 0)                                         AS units_sold,
    ROUND(ar.gross_margin_usd, 0)                                   AS gross_margin_usd,
    ROUND(100.0 * ar.gross_margin_usd / NULLIF(ar.net_revenue_usd, 0), 1) AS gross_margin_pct,

    -- Prior year same period
    ROUND(
        LAG(ar.net_revenue_usd, 12) OVER (
            PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                         ar.continent, ar.customer_region
            ORDER BY ar.year_number, ar.month_number
        ), 0
    )                                                               AS py_net_revenue_usd,

    ROUND(
        LAG(ar.units_sold, 12) OVER (
            PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                         ar.continent, ar.customer_region
            ORDER BY ar.year_number, ar.month_number
        ), 0
    )                                                               AS py_units_sold,

    -- YoY growth calculations
    ROUND(
        ar.net_revenue_usd
        - LAG(ar.net_revenue_usd, 12) OVER (
            PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                         ar.continent, ar.customer_region
            ORDER BY ar.year_number, ar.month_number
          ),
        0
    )                                                               AS yoy_revenue_change_usd,

    ROUND(
        100.0 * (
            ar.net_revenue_usd
            - LAG(ar.net_revenue_usd, 12) OVER (
                PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                             ar.continent, ar.customer_region
                ORDER BY ar.year_number, ar.month_number
              )
        ) / NULLIF(
            LAG(ar.net_revenue_usd, 12) OVER (
                PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                             ar.continent, ar.customer_region
                ORDER BY ar.year_number, ar.month_number
            ), 0
        ),
        1
    )                                                               AS yoy_revenue_growth_pct,

    -- Unit growth
    ROUND(
        100.0 * (
            ar.units_sold
            - LAG(ar.units_sold, 12) OVER (
                PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                             ar.continent, ar.customer_region
                ORDER BY ar.year_number, ar.month_number
              )
        ) / NULLIF(
            LAG(ar.units_sold, 12) OVER (
                PARTITION BY ar.vehicle_segment, ar.powertrain_type,
                             ar.continent, ar.customer_region
                ORDER BY ar.year_number, ar.month_number
            ), 0
        ),
        1
    )                                                               AS yoy_unit_growth_pct

FROM annual_revenue ar

ORDER BY
    ar.vehicle_segment, ar.customer_region,
    ar.year_number, ar.month_number;


-- =============================================================================
-- QUERY 4: Seasonal Demand Patterns
-- =============================================================================
-- BUSINESS PURPOSE:
--   Seasonal index quantifies how much demand in a given month deviates
--   from the annual average. Used to adjust production schedules, pre-build
--   inventory before peak periods, and plan supplier capacity agreements.
--
--   Seasonal Index = Month Average / Overall Monthly Average
--   Index > 1.0 = above-average demand month (ramp up production)
--   Index < 1.0 = below-average demand month (consider maintenance shutdowns)
-- =============================================================================

WITH monthly_sales AS (
    -- Monthly units sold over multiple years
    SELECT
        v.vehicle_segment,
        d.year_number,
        d.month_number,
        d.month_name,
        d.month_name_short,
        SUM(fs.quantity_fulfilled)                                  AS units_sold
    FROM fact_sales     fs
    JOIN dim_vehicle    v ON fs.vehicle_key    = v.vehicle_key
    JOIN dim_date       d ON fs.order_date_key = d.date_key
    WHERE
        d.year_number BETWEEN YEAR(GETDATE()) - 3 AND YEAR(GETDATE()) - 1  -- Use complete prior years only
        AND fs.order_status NOT IN ('Cancelled')
    GROUP BY
        v.vehicle_segment, d.year_number, d.month_number, d.month_name, d.month_name_short
),
month_avg AS (
    -- Average monthly sales across all years (by segment + month)
    SELECT
        vehicle_segment,
        month_number,
        month_name,
        month_name_short,
        AVG(CAST(units_sold AS FLOAT))                              AS avg_monthly_units
    FROM monthly_sales
    GROUP BY vehicle_segment, month_number, month_name, month_name_short
),
overall_avg AS (
    -- Overall average monthly volume per segment (grand mean)
    SELECT
        vehicle_segment,
        AVG(CAST(units_sold AS FLOAT))                              AS overall_monthly_avg
    FROM monthly_sales
    GROUP BY vehicle_segment
)
SELECT
    ma.vehicle_segment,
    ma.month_number,
    ma.month_name_short,
    ma.month_name,
    ROUND(ma.avg_monthly_units, 0)                                  AS avg_monthly_units,
    ROUND(oa.overall_monthly_avg, 0)                                AS overall_monthly_avg,

    -- Seasonal index: 1.0 = average month; 1.2 = 20% above average
    ROUND(ma.avg_monthly_units / NULLIF(oa.overall_monthly_avg, 0), 3) AS seasonal_index,

    -- Deviation from average
    ROUND(ma.avg_monthly_units - oa.overall_monthly_avg, 0)        AS deviation_from_avg_units,
    ROUND(
        100.0 * (ma.avg_monthly_units - oa.overall_monthly_avg)
              / NULLIF(oa.overall_monthly_avg, 0),
        1
    )                                                               AS deviation_pct,

    -- Production planning recommendation
    CASE
        WHEN ma.avg_monthly_units / NULLIF(oa.overall_monthly_avg, 0) >= 1.25
        THEN 'PEAK SEASON: Pre-build and add production shifts'
        WHEN ma.avg_monthly_units / NULLIF(oa.overall_monthly_avg, 0) >= 1.10
        THEN 'HIGH SEASON: Review capacity and supplier commitments'
        WHEN ma.avg_monthly_units / NULLIF(oa.overall_monthly_avg, 0) >= 0.90
        THEN 'NORMAL SEASON: Standard production plan'
        WHEN ma.avg_monthly_units / NULLIF(oa.overall_monthly_avg, 0) >= 0.75
        THEN 'LOW SEASON: Schedule maintenance; consider planned downtime'
        ELSE 'TROUGH SEASON: Shutdown window; reduce supplier releases'
    END                                                             AS planning_guidance

FROM month_avg      ma
JOIN overall_avg    oa ON ma.vehicle_segment = oa.vehicle_segment

ORDER BY ma.vehicle_segment, ma.month_number;


-- =============================================================================
-- QUERY 5: Top Performing Regions
-- =============================================================================
-- BUSINESS PURPOSE:
--   Identifies regional winners and laggards for commercial resource allocation.
--   High-growth, high-margin regions attract additional marketing investment.
--   Low-growth regions may need pricing, product mix, or channel adjustments.
--
--   Ranking considers both absolute revenue contribution and growth trajectory.
-- =============================================================================

WITH region_current_yr AS (
    SELECT
        fs.customer_region_key,
        SUM(fs.net_revenue_usd)                                     AS current_yr_revenue,
        SUM(fs.gross_margin_usd)                                    AS current_yr_margin,
        SUM(fs.quantity_fulfilled)                                   AS current_yr_units,
        COUNT(DISTINCT fs.order_number)                             AS current_yr_orders,
        ROUND(100.0 * SUM(CASE WHEN fs.is_fulfilled_on_time = 1 THEN 1 ELSE 0 END)
                    / NULLIF(COUNT(fs.sales_id), 0), 1)             AS fill_rate_pct,
        ROUND(AVG(ISNULL(fs.forecast_accuracy_pct, 0)), 1)          AS avg_forecast_accuracy_pct
    FROM fact_sales fs
    JOIN dim_date   d ON fs.order_date_key = d.date_key
    WHERE d.year_number = YEAR(GETDATE())
      AND fs.order_status NOT IN ('Cancelled')
    GROUP BY fs.customer_region_key
),
region_prior_yr AS (
    SELECT
        fs.customer_region_key,
        SUM(fs.net_revenue_usd)                                     AS prior_yr_revenue,
        SUM(fs.quantity_fulfilled)                                   AS prior_yr_units
    FROM fact_sales fs
    JOIN dim_date   d ON fs.order_date_key = d.date_key
    WHERE d.year_number = YEAR(GETDATE()) - 1
      AND fs.order_status NOT IN ('Cancelled')
    GROUP BY fs.customer_region_key
),
company_totals AS (
    SELECT
        SUM(current_yr_revenue) AS total_company_revenue,
        SUM(current_yr_margin)  AS total_company_margin
    FROM region_current_yr
)
SELECT
    r.region_name                                                   AS customer_region,
    r.country,
    r.continent,

    -- Current year performance
    ROUND(cy.current_yr_revenue, 0)                                 AS ytd_net_revenue_usd,
    ROUND(cy.current_yr_margin, 0)                                  AS ytd_gross_margin_usd,
    ROUND(100.0 * cy.current_yr_margin / NULLIF(cy.current_yr_revenue, 0), 1) AS gross_margin_pct,
    cy.current_yr_units                                             AS ytd_units_sold,
    cy.current_yr_orders                                            AS ytd_orders,
    ROUND(cy.current_yr_revenue / NULLIF(cy.current_yr_units, 0), 0) AS avg_revenue_per_unit_usd,

    -- Revenue share
    ROUND(100.0 * cy.current_yr_revenue / NULLIF(ct.total_company_revenue, 0), 1) AS revenue_share_pct,

    -- YoY growth
    ROUND(py.prior_yr_revenue, 0)                                   AS prior_yr_revenue_usd,
    ROUND(cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0), 0) AS revenue_growth_usd,
    ROUND(
        100.0 * (cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0))
              / NULLIF(py.prior_yr_revenue, 0),
        1
    )                                                               AS yoy_revenue_growth_pct,
    ROUND(
        100.0 * (cy.current_yr_units - ISNULL(py.prior_yr_units, 0))
              / NULLIF(py.prior_yr_units, 0),
        1
    )                                                               AS yoy_unit_growth_pct,

    -- Service quality
    cy.fill_rate_pct,
    cy.avg_forecast_accuracy_pct,

    -- Regional ranking
    RANK() OVER (ORDER BY cy.current_yr_revenue DESC)               AS revenue_rank,
    RANK() OVER (ORDER BY
        100.0 * (cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0))
              / NULLIF(py.prior_yr_revenue, 0) DESC
    )                                                               AS growth_rank,
    RANK() OVER (ORDER BY
        100.0 * cy.current_yr_margin / NULLIF(cy.current_yr_revenue, 0) DESC
    )                                                               AS margin_rank,

    -- Composite performance label
    CASE
        WHEN RANK() OVER (ORDER BY cy.current_yr_revenue DESC) <= 3
             AND 100.0 * (cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0))
                       / NULLIF(py.prior_yr_revenue, 0) > 10
        THEN 'Star Region - High Revenue & Growth'
        WHEN RANK() OVER (ORDER BY cy.current_yr_revenue DESC) <= 5
        THEN 'Key Region - High Revenue'
        WHEN 100.0 * (cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0))
                   / NULLIF(py.prior_yr_revenue, 0) > 20
        THEN 'Rising Region - High Growth'
        WHEN 100.0 * (cy.current_yr_revenue - ISNULL(py.prior_yr_revenue, 0))
                   / NULLIF(py.prior_yr_revenue, 0) < -10
        THEN 'Declining Region - Needs Strategy Review'
        ELSE 'Stable Region'
    END                                                             AS region_performance_label

FROM region_current_yr  cy
JOIN dim_region          r  ON cy.customer_region_key = r.region_key
LEFT JOIN region_prior_yr py ON cy.customer_region_key = py.customer_region_key
CROSS JOIN company_totals  ct

ORDER BY ytd_net_revenue_usd DESC;


-- =============================================================================
-- END OF FILE: 05_sales_demand_analysis.sql
-- =============================================================================
