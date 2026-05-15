-- =============================================================================
-- FILE: 06_executive_kpi_summary.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Master executive KPI dashboard query - single result set with all
--          top-level supply chain performance indicators
--
-- BUSINESS CONTEXT:
--   This query produces the single-page Supply Chain Scorecard presented to
--   the CEO, CFO, and VP Operations each Monday morning. It aggregates the
--   full supply chain into 8 key performance indicators spanning procurement,
--   inventory, logistics, manufacturing, and commercial performance.
--
--   All KPIs include:
--     1. Current period value
--     2. Prior period value (for trend arrow)
--     3. Target / benchmark
--     4. RAG status (Red/Amber/Green)
--
-- KPI DEFINITIONS:
--   1. On-Time Delivery %      - % of shipments delivered on/before commit date
--   2. Inventory Turnover      - Annual COGS / Average Inventory Value
--   3. Fill Rate %             - % of customer demand fulfilled from stock
--   4. Supplier Reliability    - Composite supplier performance score (0-100)
--   5. Transportation Cost %   - Freight cost as % of goods value shipped
--   6. Perfect Order Rate %    - Orders complete, on-time, damage-free, correct docs
--   7. Plant Utilization %     - Actual vs planned production time
--   8. Forecast Accuracy %     - 100 - MAPE (mean absolute percentage error)
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: GETDATE() -> CURRENT_DATE, ISNULL() -> COALESCE(),
--                 DATEADD -> date + INTERVAL, STDEV -> STDDEV
-- =============================================================================


-- =============================================================================
-- SECTION 1: Individual KPI CTEs
-- Each CTE calculates one KPI for current month, prior month, and current YTD
-- =============================================================================

WITH

-- Date reference: current and prior month boundaries
date_refs AS (
    SELECT
        -- Current month window
        DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)         AS curr_month_start,
        EOMONTH(GETDATE())                                          AS curr_month_end,

        -- Prior month window
        DATEFROMPARTS(YEAR(DATEADD(MONTH,-1,GETDATE())),
                      MONTH(DATEADD(MONTH,-1,GETDATE())), 1)        AS prior_month_start,
        EOMONTH(DATEADD(MONTH, -1, GETDATE()))                      AS prior_month_end,

        -- YTD window (Jan 1 to today)
        DATEFROMPARTS(YEAR(GETDATE()), 1, 1)                        AS ytd_start,
        CAST(GETDATE() AS DATE)                                     AS today,

        -- Prior YTD (same calendar period last year)
        DATEFROMPARTS(YEAR(GETDATE()) - 1, 1, 1)                   AS prior_ytd_start,
        DATEFROMPARTS(YEAR(GETDATE()) - 1,
                      MONTH(GETDATE()),
                      DAY(GETDATE()))                               AS prior_ytd_end

        -- [PostgreSQL]:
        -- DATE_TRUNC('month', CURRENT_DATE)                       AS curr_month_start,
        -- (DATE_TRUNC('month', CURRENT_DATE) + '1 month - 1 day'::interval)::date AS curr_month_end,
        -- DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')  AS prior_month_start,
        -- etc.
),

-- ============================================================
-- KPI 1: ON-TIME DELIVERY (OTD) %
-- Target: >= 95%  |  Amber: 90-94%  |  Red: < 90%
-- ============================================================
kpi_otd AS (
    SELECT
        -- Current month OTD
        ROUND(
            100.0 * SUM(CASE WHEN fs.is_on_time = 1
                              AND d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                     AND fs.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS curr_month_otd_pct,

        -- Prior month OTD
        ROUND(
            100.0 * SUM(CASE WHEN fs.is_on_time = 1
                              AND d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                     AND fs.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS prior_month_otd_pct,

        -- YTD OTD
        ROUND(
            100.0 * SUM(CASE WHEN fs.is_on_time = 1
                              AND d.full_date BETWEEN dr.ytd_start AND dr.today
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                                     AND fs.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS ytd_otd_pct

    FROM fact_shipments fs
    JOIN dim_date d ON fs.ship_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.shipment_status IN ('Delivered', 'In Transit')
),

-- ============================================================
-- KPI 2: INVENTORY TURNOVER
-- Target: >= 12x  |  Amber: 8-11x  |  Red: < 8x
-- ============================================================
kpi_inventory_turns AS (
    SELECT
        -- YTD annualized turnover
        ROUND(
            -- Annualize YTD COGS: (YTD COGS / elapsed months) * 12
            (SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                      THEN fi.issues_qty * ISNULL(fi.unit_cost_usd, 0) ELSE 0 END)
             / NULLIF(MONTH(GETDATE()), 0) * 12.0)
            -- Divide by average inventory value (use current month closing as proxy)
            / NULLIF(
                AVG(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                         THEN fi.total_stock_value_usd ELSE NULL END),
                0
            ),
            2
        )                                                           AS ytd_annualized_turns,

        -- Prior year comparison (full year turns for prior year)
        ROUND(
            SUM(CASE WHEN d.year_number = YEAR(GETDATE()) - 1
                     THEN fi.issues_qty * ISNULL(fi.unit_cost_usd, 0) ELSE 0 END)
            / NULLIF(
                AVG(CASE WHEN d.year_number = YEAR(GETDATE()) - 1
                         THEN fi.total_stock_value_usd ELSE NULL END),
                0
            ),
            2
        )                                                           AS prior_yr_turns

    FROM fact_inventory fi
    JOIN dim_date d ON fi.snapshot_date_key = d.date_key
    CROSS JOIN date_refs dr
),

-- ============================================================
-- KPI 3: FILL RATE %
-- % of customer demand (sales orders) fulfilled from stock
-- Target: >= 98%  |  Amber: 95-97%  |  Red: < 95%
-- ============================================================
kpi_fill_rate AS (
    SELECT
        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                             THEN ISNULL(fs.quantity_fulfilled, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                    THEN fs.quantity_ordered ELSE 0 END), 0),
            1
        )                                                           AS curr_month_fill_rate_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                             THEN ISNULL(fs.quantity_fulfilled, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                    THEN fs.quantity_ordered ELSE 0 END), 0),
            1
        )                                                           AS prior_month_fill_rate_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                             THEN ISNULL(fs.quantity_fulfilled, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                                    THEN fs.quantity_ordered ELSE 0 END), 0),
            1
        )                                                           AS ytd_fill_rate_pct

    FROM fact_sales fs
    JOIN dim_date d ON fs.order_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.order_status NOT IN ('Cancelled')
),

-- ============================================================
-- KPI 4: SUPPLIER RELIABILITY SCORE (0-100)
-- Composite: 50% OTD + 30% Quality (1-PPM/10000) + 20% Lead Time adherence
-- Target: >= 85  |  Amber: 70-84  |  Red: < 70
-- ============================================================
kpi_supplier_reliability AS (
    SELECT
        -- Current month supplier reliability score
        ROUND(
            -- 50% OTD component
            0.50 * (
                100.0 * SUM(CASE WHEN fs.is_on_time = 1
                                  AND d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                             THEN 1 ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                         AND fs.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END), 0)
            )
            -- 30% quality component (100 - PPM/100, capped 0-100)
            + 0.30 * LEAST(100, GREATEST(0,
                100 - (
                    1000000.0 * SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                         THEN ISNULL(fs.quantity_rejected, 0) ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                     THEN fs.quantity_received ELSE 0 END), 0)
                ) / 100
            ))
            -- 20% lead time adherence
            + 0.20 * (
                100.0 * SUM(CASE WHEN fs.actual_transit_days <= fs.planned_transit_days
                                  AND d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                             THEN 1 ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                         AND fs.actual_transit_days IS NOT NULL THEN 1 ELSE 0 END), 0)
            ),
            1
        )                                                           AS curr_month_reliability_score,

        -- Prior month
        ROUND(
            0.50 * (
                100.0 * SUM(CASE WHEN fs.is_on_time = 1
                                  AND d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                             THEN 1 ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                         AND fs.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END), 0)
            )
            + 0.30 * LEAST(100, GREATEST(0,
                100 - (
                    1000000.0 * SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                         THEN ISNULL(fs.quantity_rejected, 0) ELSE 0 END)
                    / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                     THEN fs.quantity_received ELSE 0 END), 0)
                ) / 100
            ))
            + 0.20 * (
                100.0 * SUM(CASE WHEN fs.actual_transit_days <= fs.planned_transit_days
                                  AND d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                             THEN 1 ELSE 0 END)
                      / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                         AND fs.actual_transit_days IS NOT NULL THEN 1 ELSE 0 END), 0)
            ),
            1
        )                                                           AS prior_month_reliability_score

    FROM fact_shipments fs
    JOIN dim_date d ON fs.ship_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.shipment_status IN ('Delivered', 'In Transit')
),

-- ============================================================
-- KPI 5: TRANSPORTATION COST RATIO %
-- Freight cost as % of the value of goods shipped
-- Target: <= 5%  |  Amber: 5-8%  |  Red: > 8%
-- Note: Lower is better for this KPI (inverted RAG)
-- ============================================================
kpi_transport_cost AS (
    SELECT
        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                             THEN ISNULL(fs.total_logistics_cost_usd, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                    THEN ISNULL(fs.quantity_shipped, 0)
                                         * ISNULL(fs.cost_per_unit_usd, 0) ELSE 0 END), 0),
            2
        )                                                           AS curr_month_transport_cost_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                             THEN ISNULL(fs.total_logistics_cost_usd, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                    THEN ISNULL(fs.quantity_shipped, 0)
                                         * ISNULL(fs.cost_per_unit_usd, 0) ELSE 0 END), 0),
            2
        )                                                           AS prior_month_transport_cost_pct,

        -- YTD total freight spend for context
        ROUND(
            SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                     THEN ISNULL(fs.total_logistics_cost_usd, 0) ELSE 0 END),
            0
        )                                                           AS ytd_freight_cost_usd

    FROM fact_shipments fs
    JOIN dim_date d ON fs.ship_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.shipment_status IN ('Delivered', 'In Transit')
),

-- ============================================================
-- KPI 6: PERFECT ORDER RATE %
-- An order is "perfect" when it is:
--   (a) complete (full quantity fulfilled)
--   (b) on-time
--   (c) damage-free (no rejection at receipt)
--   (d) correctly documented (no invoice disputes)
-- All four conditions must be met. This is the strictest customer service KPI.
-- Target: >= 95%  |  Amber: 90-94%  |  Red: < 90%
-- ============================================================
kpi_perfect_order AS (
    SELECT
        ROUND(
            -- Perfect order: fulfilled, on-time, no defects
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                              AND ISNULL(fs.fill_rate_pct, 0)   >= 100   -- Fully fulfilled
                              AND fs.is_fulfilled_on_time = 1            -- On time
                              AND ISNULL(fs.quantity_fulfilled, 0) > 0   -- Not zero
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                    THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS curr_month_perfect_order_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                              AND ISNULL(fs.fill_rate_pct, 0)   >= 100
                              AND fs.is_fulfilled_on_time = 1
                              AND ISNULL(fs.quantity_fulfilled, 0) > 0
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                    THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS prior_month_perfect_order_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                              AND ISNULL(fs.fill_rate_pct, 0)   >= 100
                              AND fs.is_fulfilled_on_time = 1
                              AND ISNULL(fs.quantity_fulfilled, 0) > 0
                         THEN 1 ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                                    THEN 1 ELSE 0 END), 0),
            1
        )                                                           AS ytd_perfect_order_pct

    FROM fact_sales fs
    JOIN dim_date d ON fs.order_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.order_status NOT IN ('Cancelled')
),

-- ============================================================
-- KPI 7: PLANT UTILIZATION %
-- Actual production time as % of planned production time
-- Target: 80-95%  |  Amber: 70-79% or >95%  |  Red: < 70%
-- Note: both very low AND very high utilization are flagged
-- ============================================================
kpi_plant_utilization AS (
    SELECT
        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                             THEN ISNULL(fp.actual_production_time_min, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                                    THEN fp.planned_production_time_min ELSE 0 END), 0),
            1
        )                                                           AS curr_month_utilization_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                             THEN ISNULL(fp.actual_production_time_min, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                                    THEN fp.planned_production_time_min ELSE 0 END), 0),
            1
        )                                                           AS prior_month_utilization_pct,

        ROUND(
            100.0 * SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                             THEN ISNULL(fp.actual_production_time_min, 0) ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                                    THEN fp.planned_production_time_min ELSE 0 END), 0),
            1
        )                                                           AS ytd_utilization_pct,

        -- Also capture OEE for context
        ROUND(AVG(CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                       THEN ISNULL(fp.oee_rate, 0) END) * 100, 1) AS curr_month_avg_oee_pct

    FROM fact_production fp
    JOIN dim_date d ON fp.production_date_key = d.date_key
    CROSS JOIN date_refs dr
),

-- ============================================================
-- KPI 8: FORECAST ACCURACY %
-- 100% - MAPE (Mean Absolute Percentage Error)
-- Target: >= 90%  |  Amber: 80-89%  |  Red: < 80%
-- ============================================================
kpi_forecast_accuracy AS (
    SELECT
        ROUND(
            100.0 - AVG(
                CASE WHEN d.full_date BETWEEN dr.curr_month_start AND dr.curr_month_end
                          AND fs.forecasted_quantity IS NOT NULL
                          AND fs.quantity_fulfilled IS NOT NULL
                          AND ABS(fs.quantity_fulfilled) > 0
                     THEN ABS(fs.quantity_fulfilled - fs.forecasted_quantity)
                          / ABS(fs.quantity_fulfilled) * 100
                     ELSE NULL END
            ),
            1
        )                                                           AS curr_month_forecast_accuracy_pct,

        ROUND(
            100.0 - AVG(
                CASE WHEN d.full_date BETWEEN dr.prior_month_start AND dr.prior_month_end
                          AND fs.forecasted_quantity IS NOT NULL
                          AND fs.quantity_fulfilled IS NOT NULL
                          AND ABS(fs.quantity_fulfilled) > 0
                     THEN ABS(fs.quantity_fulfilled - fs.forecasted_quantity)
                          / ABS(fs.quantity_fulfilled) * 100
                     ELSE NULL END
            ),
            1
        )                                                           AS prior_month_forecast_accuracy_pct,

        ROUND(
            100.0 - AVG(
                CASE WHEN d.full_date BETWEEN dr.ytd_start AND dr.today
                          AND fs.forecasted_quantity IS NOT NULL
                          AND fs.quantity_fulfilled IS NOT NULL
                          AND ABS(fs.quantity_fulfilled) > 0
                     THEN ABS(fs.quantity_fulfilled - fs.forecasted_quantity)
                          / ABS(fs.quantity_fulfilled) * 100
                     ELSE NULL END
            ),
            1
        )                                                           AS ytd_forecast_accuracy_pct

    FROM fact_sales fs
    JOIN dim_date d ON fs.order_date_key = d.date_key
    CROSS JOIN date_refs dr
    WHERE fs.order_status NOT IN ('Cancelled')
)


-- =============================================================================
-- SECTION 2: MASTER KPI SUMMARY - Final Output
-- Produces one row per KPI in a structured format for dashboard consumption
-- =============================================================================

SELECT
    kpi_name,
    kpi_category,
    curr_month_value,
    prior_month_value,
    ytd_value,
    target_value,
    target_direction,           -- 'Higher' or 'Lower' - which direction is better
    green_threshold,
    amber_threshold,
    unit_label,

    -- Month-over-month change
    ROUND(curr_month_value - prior_month_value, 1)                  AS mom_change,
    CASE
        WHEN prior_month_value = 0 THEN NULL
        ELSE ROUND((curr_month_value - prior_month_value) / ABS(prior_month_value) * 100, 1)
    END                                                             AS mom_change_pct,

    -- RAG status (Red / Amber / Green)
    CASE target_direction
        WHEN 'Higher' THEN
            CASE
                WHEN curr_month_value >= green_threshold  THEN 'GREEN'
                WHEN curr_month_value >= amber_threshold  THEN 'AMBER'
                ELSE 'RED'
            END
        WHEN 'Lower' THEN
            CASE
                WHEN curr_month_value <= green_threshold  THEN 'GREEN'
                WHEN curr_month_value <= amber_threshold  THEN 'AMBER'
                ELSE 'RED'
            END
        ELSE 'GREY'
    END                                                             AS rag_status,

    -- Trend vs prior month
    CASE target_direction
        WHEN 'Higher' THEN
            CASE
                WHEN curr_month_value > prior_month_value  THEN 'IMPROVING'
                WHEN curr_month_value = prior_month_value  THEN 'FLAT'
                ELSE 'DECLINING'
            END
        WHEN 'Lower' THEN
            CASE
                WHEN curr_month_value < prior_month_value  THEN 'IMPROVING'
                WHEN curr_month_value = prior_month_value  THEN 'FLAT'
                ELSE 'DECLINING'
            END
        ELSE 'UNKNOWN'
    END                                                             AS trend_vs_prior_month,

    sort_order

FROM (

    -- KPI 1: On-Time Delivery
    SELECT
        'On-Time Delivery %'                                        AS kpi_name,
        'Logistics'                                                 AS kpi_category,
        kpi.curr_month_otd_pct                                     AS curr_month_value,
        kpi.prior_month_otd_pct                                    AS prior_month_value,
        kpi.ytd_otd_pct                                            AS ytd_value,
        95.0                                                        AS target_value,
        'Higher'                                                    AS target_direction,
        95.0                                                        AS green_threshold,
        90.0                                                        AS amber_threshold,
        '%'                                                         AS unit_label,
        1                                                           AS sort_order
    FROM kpi_otd kpi

    UNION ALL

    -- KPI 2: Inventory Turnover
    SELECT
        'Inventory Turnover',
        'Inventory',
        kpi.ytd_annualized_turns,
        kpi.prior_yr_turns,
        kpi.ytd_annualized_turns,
        12.0,
        'Higher',
        12.0,
        8.0,
        'x (turns)',
        2
    FROM kpi_inventory_turns kpi

    UNION ALL

    -- KPI 3: Fill Rate
    SELECT
        'Fill Rate %',
        'Customer Service',
        kpi.curr_month_fill_rate_pct,
        kpi.prior_month_fill_rate_pct,
        kpi.ytd_fill_rate_pct,
        98.0,
        'Higher',
        98.0,
        95.0,
        '%',
        3
    FROM kpi_fill_rate kpi

    UNION ALL

    -- KPI 4: Supplier Reliability Score
    SELECT
        'Supplier Reliability Score',
        'Procurement',
        kpi.curr_month_reliability_score,
        kpi.prior_month_reliability_score,
        kpi.curr_month_reliability_score,   -- No separate YTD for score
        85.0,
        'Higher',
        85.0,
        70.0,
        'Score (0-100)',
        4
    FROM kpi_supplier_reliability kpi

    UNION ALL

    -- KPI 5: Transportation Cost Ratio
    SELECT
        'Transportation Cost %',
        'Logistics',
        kpi.curr_month_transport_cost_pct,
        kpi.prior_month_transport_cost_pct,
        kpi.curr_month_transport_cost_pct,
        5.0,
        'Lower',        -- Lower is better for cost ratio
        5.0,            -- Green if <= 5%
        8.0,            -- Amber if <= 8% (Red if > 8%)
        '% of goods value',
        5
    FROM kpi_transport_cost kpi

    UNION ALL

    -- KPI 6: Perfect Order Rate
    SELECT
        'Perfect Order Rate %',
        'Customer Service',
        kpi.curr_month_perfect_order_pct,
        kpi.prior_month_perfect_order_pct,
        kpi.ytd_perfect_order_pct,
        95.0,
        'Higher',
        95.0,
        90.0,
        '%',
        6
    FROM kpi_perfect_order kpi

    UNION ALL

    -- KPI 7: Plant Utilization
    SELECT
        'Plant Utilization %',
        'Manufacturing',
        kpi.curr_month_utilization_pct,
        kpi.prior_month_utilization_pct,
        kpi.ytd_utilization_pct,
        85.0,
        'Higher',
        80.0,           -- Green: 80-95% (handled with special note for >95%)
        70.0,
        '%',
        7
    FROM kpi_plant_utilization kpi

    UNION ALL

    -- KPI 8: Forecast Accuracy
    SELECT
        'Forecast Accuracy %',
        'Planning',
        kpi.curr_month_forecast_accuracy_pct,
        kpi.prior_month_forecast_accuracy_pct,
        kpi.ytd_forecast_accuracy_pct,
        90.0,
        'Higher',
        90.0,
        80.0,
        '%',
        8
    FROM kpi_forecast_accuracy kpi

) kpi_summary

ORDER BY sort_order;


-- =============================================================================
-- SECTION 3: SUPPLEMENTARY - KPI Context Details
-- Additional supporting metrics shown below the headline table
-- =============================================================================

SELECT
    'Reporting Period'          AS metric_label,
    FORMAT(GETDATE(), 'MMMM yyyy') AS current_value,   -- [PostgreSQL: TO_CHAR(CURRENT_DATE, 'Month YYYY')]
    NULL                        AS prior_value,
    NULL                        AS target,
    'Reference'                 AS category

UNION ALL

SELECT
    'Active Suppliers',
    CAST(COUNT(*) AS NVARCHAR(20)),
    NULL, NULL, 'Procurement'
FROM dim_supplier WHERE is_active = 1

UNION ALL

SELECT
    'Active Warehouses',
    CAST(COUNT(*) AS NVARCHAR(20)),
    NULL, NULL, 'Inventory'
FROM dim_warehouse WHERE is_active = 1

UNION ALL

SELECT
    'Active Plants',
    CAST(COUNT(*) AS NVARCHAR(20)),
    NULL, NULL, 'Manufacturing'
FROM dim_plant WHERE is_active = 1

UNION ALL

SELECT
    'SKUs Under Management',
    CAST(COUNT(*) AS NVARCHAR(20)),
    NULL, NULL, 'Inventory'
FROM dim_product WHERE is_active = 1

UNION ALL

-- Current stockout count
SELECT
    'Products at Stockout Risk (Today)',
    CAST(SUM(CASE WHEN fi.stockout_risk_flag = 1 THEN 1 ELSE 0 END) AS NVARCHAR(20)),
    NULL, '0', 'Inventory'
FROM fact_inventory fi
JOIN dim_date d ON fi.snapshot_date_key = d.date_key
WHERE d.is_current_day = 1;


-- =============================================================================
-- END OF FILE: 06_executive_kpi_summary.sql
-- =============================================================================
