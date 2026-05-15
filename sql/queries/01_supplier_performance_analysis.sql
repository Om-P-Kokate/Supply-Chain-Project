-- =============================================================================
-- FILE: 01_supplier_performance_analysis.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Supplier performance analysis queries for procurement and
--          supply chain risk management
--
-- BUSINESS CONTEXT:
--   Supplier performance directly impacts production continuity, product quality,
--   and total cost of ownership. These queries support the Supplier Performance
--   Review (SPR) process and feed the Supplier Scorecard dashboard. Results
--   are reviewed monthly by the Procurement team and quarterly by leadership.
--
-- KEY METRICS:
--   - On-Time Delivery Rate (OTD): % of shipments arriving on or before
--     the committed delivery date. World-class target: >= 95%
--   - Defect Rate (PPM): Parts Per Million defective at incoming inspection.
--     IATF 16949 target: <= 500 PPM (0.05%)
--   - Lead Time: Average calendar days from PO issue to goods receipt.
--   - Supplier Risk Score: Composite index (0-100) factoring OTD, defect
--     rate, financial risk rating, and geographic concentration.
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: Replace GETDATE() with CURRENT_TIMESTAMP, ISNULL() with COALESCE()
-- =============================================================================


-- =============================================================================
-- QUERY 1: Worst On-Time Delivery Rate by Supplier
-- =============================================================================
-- BUSINESS PURPOSE:
--   Identifies suppliers most frequently delivering late. Late deliveries trigger
--   production line stoppages, expedite freight costs, and may require buffer
--   stock increases. Used to initiate supplier corrective action (SCA) processes.
--
-- THRESHOLD: Suppliers below 90% OTD are flagged for corrective action.
--            Suppliers below 80% are escalated to executive review.
-- =============================================================================

SELECT
    s.supplier_id,
    s.supplier_name,
    s.tier_level,
    s.country,
    s.region                                                    AS supplier_region,
    s.risk_rating,
    s.is_preferred,

    -- Volume metrics
    COUNT(f.shipment_id)                                        AS total_shipments,
    SUM(f.quantity_shipped)                                     AS total_units_shipped,

    -- On-time delivery metrics
    SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)          AS on_time_shipments,
    SUM(CASE WHEN f.is_on_time = 0 THEN 1 ELSE 0 END)          AS late_shipments,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(f.shipment_id), 0),
        2
    )                                                           AS otd_rate_pct,

    -- Delay severity
    AVG(CASE WHEN f.delay_days > 0 THEN f.delay_days END)       AS avg_delay_days_when_late,
    MAX(f.delay_days)                                           AS max_delay_days,

    -- Performance classification
    CASE
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(f.shipment_id), 0), 2) >= 95 THEN 'World Class'
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(f.shipment_id), 0), 2) >= 90 THEN 'Acceptable'
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(f.shipment_id), 0), 2) >= 80 THEN 'Corrective Action Required'
        ELSE 'Executive Escalation'
    END                                                         AS performance_band,

    -- Cost impact of late deliveries
    SUM(CASE WHEN f.is_on_time = 0 THEN f.total_logistics_cost_usd ELSE 0 END) AS late_shipment_freight_cost_usd

FROM fact_shipments f
JOIN dim_supplier   s ON f.supplier_key = s.supplier_key
JOIN dim_date       d ON f.ship_date_key = d.date_key

WHERE
    f.shipment_status IN ('Delivered', 'In Transit')
    AND d.year_number = YEAR(GETDATE())   -- [PostgreSQL: EXTRACT(YEAR FROM CURRENT_DATE)]
    AND f.actual_delivery_date_key IS NOT NULL   -- Exclude in-transit shipments from OTD calc

GROUP BY
    s.supplier_id, s.supplier_name, s.tier_level,
    s.country, s.region, s.risk_rating, s.is_preferred

HAVING COUNT(f.shipment_id) >= 10   -- Minimum 10 shipments for statistical relevance

ORDER BY otd_rate_pct ASC;   -- Worst performers first


-- =============================================================================
-- QUERY 2: Highest Defect Rates by Supplier
-- =============================================================================
-- BUSINESS PURPOSE:
--   High defect rates at incoming inspection cause line stoppages, rework costs,
--   and warranty risk downstream. This query drives the quality alert process
--   and informs whether a supplier's parts require 100% inspection (vs. sampling).
--
-- METRIC: Defect rate expressed in PPM (parts per million) for easy comparison
--         against IATF 16949 quality targets.
-- =============================================================================

SELECT
    s.supplier_id,
    s.supplier_name,
    s.supplier_type,
    s.country,
    s.certification_iatf,                          -- IATF 16949 flag - certified suppliers should perform better
    s.certification_iso,

    -- Inspection volumes
    SUM(f.quantity_received)                        AS total_units_received,
    SUM(ISNULL(f.quantity_rejected, 0))             AS total_units_rejected,  -- [PostgreSQL: COALESCE()]

    -- Defect rate calculations
    ROUND(
        1000000.0 * SUM(ISNULL(f.quantity_rejected, 0))
                  / NULLIF(SUM(f.quantity_received), 0),
        0
    )                                               AS defect_rate_ppm,

    ROUND(
        100.0 * SUM(ISNULL(f.quantity_rejected, 0))
              / NULLIF(SUM(f.quantity_received), 0),
        4
    )                                               AS defect_rate_pct,

    -- Top rejection reason (requires correlated subquery or window function)
    -- Most frequent rejection reason from this supplier
    (
        SELECT TOP 1 f2.rejection_reason           -- [PostgreSQL: LIMIT 1 in subquery]
        FROM fact_shipments f2
        WHERE f2.supplier_key = s.supplier_key
          AND f2.quantity_rejected > 0
          AND f2.rejection_reason IS NOT NULL
        GROUP BY f2.rejection_reason
        ORDER BY COUNT(*) DESC
    )                                               AS top_rejection_reason,

    -- Trend: defect rate this quarter vs last quarter
    ROUND(
        1000000.0 * SUM(
            CASE WHEN d.quarter_number = DATEPART(QUARTER, GETDATE())
                      AND d.year_number = YEAR(GETDATE())
                 THEN ISNULL(f.quantity_rejected, 0) ELSE 0 END
        ) / NULLIF(SUM(
            CASE WHEN d.quarter_number = DATEPART(QUARTER, GETDATE())
                      AND d.year_number = YEAR(GETDATE())
                 THEN f.quantity_received ELSE 0 END
        ), 0), 0
    )                                               AS current_qtr_ppm,

    ROUND(
        1000000.0 * SUM(
            CASE WHEN d.quarter_number = DATEPART(QUARTER, GETDATE()) - 1
                      OR (DATEPART(QUARTER, GETDATE()) = 1
                          AND d.quarter_number = 4
                          AND d.year_number = YEAR(GETDATE()) - 1)
                 THEN ISNULL(f.quantity_rejected, 0) ELSE 0 END
        ) / NULLIF(SUM(
            CASE WHEN d.quarter_number = DATEPART(QUARTER, GETDATE()) - 1
                      OR (DATEPART(QUARTER, GETDATE()) = 1
                          AND d.quarter_number = 4
                          AND d.year_number = YEAR(GETDATE()) - 1)
                 THEN f.quantity_received ELSE 0 END
        ), 0), 0
    )                                               AS prior_qtr_ppm,

    -- Quality alert threshold
    CASE
        WHEN 1000000.0 * SUM(ISNULL(f.quantity_rejected,0))
                       / NULLIF(SUM(f.quantity_received),0) > 5000 THEN 'CRITICAL - Containment Required'
        WHEN 1000000.0 * SUM(ISNULL(f.quantity_rejected,0))
                       / NULLIF(SUM(f.quantity_received),0) > 1000 THEN 'HIGH - 8D Required'
        WHEN 1000000.0 * SUM(ISNULL(f.quantity_rejected,0))
                       / NULLIF(SUM(f.quantity_received),0) > 500  THEN 'ELEVATED - Monitor'
        ELSE 'ACCEPTABLE'
    END                                             AS quality_alert_level

FROM fact_shipments f
JOIN dim_supplier   s ON f.supplier_key = s.supplier_key
JOIN dim_date       d ON f.ship_date_key = d.date_key

WHERE
    f.quantity_received IS NOT NULL
    AND d.year_number = YEAR(GETDATE())

GROUP BY
    s.supplier_id, s.supplier_name, s.supplier_type,
    s.country, s.certification_iatf, s.certification_iso,
    s.supplier_key

HAVING SUM(f.quantity_received) >= 100   -- Minimum volume threshold

ORDER BY defect_rate_ppm DESC;


-- =============================================================================
-- QUERY 3: Average Lead Time by Supplier Region
-- =============================================================================
-- BUSINESS PURPOSE:
--   Lead time drives safety stock requirements and production planning horizons.
--   Regional analysis reveals geographic risk concentration and helps
--   justify near-shoring or dual-sourcing decisions.
-- =============================================================================

SELECT
    s.region                                        AS supplier_region,
    s.country                                       AS supplier_country,
    s.tier_level,

    COUNT(DISTINCT s.supplier_id)                   AS supplier_count,
    COUNT(f.shipment_id)                            AS shipment_count,

    -- Lead time statistics
    ROUND(AVG(CAST(f.actual_transit_days AS FLOAT)), 1) AS avg_lead_time_days,
    ROUND(AVG(CAST(f.planned_transit_days AS FLOAT)), 1) AS avg_planned_lead_time_days,
    MIN(f.actual_transit_days)                      AS min_lead_time_days,
    MAX(f.actual_transit_days)                      AS max_lead_time_days,

    -- Lead time variability (std dev approximated using variance formula)
    -- High variability forces higher safety stock regardless of average lead time
    ROUND(
        STDEV(CAST(f.actual_transit_days AS FLOAT)),
        2
    )                                               AS lead_time_std_dev,

    -- Lead time vs plan
    ROUND(
        AVG(CAST(f.actual_transit_days - f.planned_transit_days AS FLOAT)),
        1
    )                                               AS avg_lead_time_variance_days,   -- positive = slower than planned

    -- % of shipments meeting planned lead time
    ROUND(
        100.0 * SUM(CASE WHEN f.actual_transit_days <= f.planned_transit_days THEN 1 ELSE 0 END)
              / NULLIF(COUNT(f.shipment_id), 0),
        1
    )                                               AS pct_met_planned_lead_time,

    -- Transport mode mix (affects lead time expectations)
    SUM(CASE WHEN f.transport_mode = 'Air'  THEN 1 ELSE 0 END)  AS air_shipments,
    SUM(CASE WHEN f.transport_mode = 'Sea'  THEN 1 ELSE 0 END)  AS sea_shipments,
    SUM(CASE WHEN f.transport_mode = 'Road' THEN 1 ELSE 0 END)  AS road_shipments,
    SUM(CASE WHEN f.transport_mode = 'Rail' THEN 1 ELSE 0 END)  AS rail_shipments

FROM fact_shipments f
JOIN dim_supplier   s ON f.supplier_key = s.supplier_key
JOIN dim_date       d ON f.ship_date_key = d.date_key

WHERE
    f.actual_transit_days IS NOT NULL
    AND f.shipment_status = 'Delivered'
    AND d.year_number >= YEAR(GETDATE()) - 1   -- Rolling 2-year window for trend

GROUP BY
    s.region, s.country, s.tier_level

ORDER BY
    s.region, s.country, s.tier_level;


-- =============================================================================
-- QUERY 4: Supplier Risk Ranking
-- =============================================================================
-- BUSINESS PURPOSE:
--   Composite risk ranking used by Procurement to prioritize supplier development
--   investments and build contingency sourcing plans. Factors in performance
--   (OTD, quality), strategic exposure (spend concentration), and inherent
--   risk (geographic location, financial stability rating).
--
-- SCORING METHOD: Weighted composite score 0-100 (higher = more at-risk)
--   - OTD component    (30%): Scaled from 0 (100% OTD) to 30 (0% OTD)
--   - Quality component(25%): Scaled from 0 (<100 PPM) to 25 (>5000 PPM)
--   - Spend exposure   (20%): Single-source risk; high share of category spend
--   - Risk rating      (15%): From dim_supplier.risk_rating
--   - Lead time var.   (10%): High variability = supply uncertainty
-- =============================================================================

WITH supplier_metrics AS (
    SELECT
        s.supplier_key,
        s.supplier_id,
        s.supplier_name,
        s.tier_level,
        s.country,
        s.region,
        s.risk_rating,
        s.annual_spend_usd,
        s.is_preferred,

        COUNT(f.shipment_id)                                        AS total_shipments,
        SUM(f.total_logistics_cost_usd)                             AS total_freight_spend,

        -- OTD score component (0 = perfect, 100 = all late)
        ROUND(
            100.0 * SUM(CASE WHEN f.is_on_time = 0 THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(f.shipment_id), 0),
            2
        )                                                           AS late_pct,

        -- PPM defect rate
        ROUND(
            1000000.0 * SUM(ISNULL(f.quantity_rejected, 0))
                      / NULLIF(SUM(f.quantity_received), 0),
            0
        )                                                           AS defect_ppm,

        -- Lead time variability
        ROUND(STDEV(CAST(f.actual_transit_days AS FLOAT)), 2)       AS lead_time_std_dev

    FROM fact_shipments f
    JOIN dim_supplier   s ON f.supplier_key = s.supplier_key
    JOIN dim_date       d ON f.ship_date_key = d.date_key
    WHERE d.year_number = YEAR(GETDATE())
    GROUP BY
        s.supplier_key, s.supplier_id, s.supplier_name, s.tier_level,
        s.country, s.region, s.risk_rating, s.annual_spend_usd, s.is_preferred
    HAVING COUNT(f.shipment_id) >= 5
),
total_spend AS (
    SELECT SUM(annual_spend_usd) AS company_total_spend FROM dim_supplier WHERE is_active = 1
),
risk_scores AS (
    SELECT
        sm.*,
        ts.company_total_spend,

        -- Component: OTD risk (0-30 points; 30 = all shipments late)
        ROUND(LEAST(sm.late_pct, 100) * 0.30, 2)                   AS otd_risk_score,

        -- Component: Quality risk (0-25 points)
        ROUND(LEAST(sm.defect_ppm / 5000.0, 1) * 25, 2)            AS quality_risk_score,

        -- Component: Spend concentration risk (0-20 points)
        -- High share of total company spend in a single supplier = high financial exposure
        ROUND(
            LEAST(100.0 * sm.annual_spend_usd / NULLIF(ts.company_total_spend, 0), 100) * 0.20,
            2
        )                                                           AS spend_risk_score,

        -- Component: Inherent risk rating (0-15 points)
        CASE sm.risk_rating
            WHEN 'Critical' THEN 15
            WHEN 'High'     THEN 11
            WHEN 'Medium'   THEN 6
            WHEN 'Low'      THEN 2
            ELSE 6
        END                                                         AS rating_risk_score,

        -- Component: Lead time variability (0-10 points)
        ROUND(LEAST(ISNULL(sm.lead_time_std_dev, 0) / 10.0, 1) * 10, 2) AS variability_risk_score

    FROM supplier_metrics sm
    CROSS JOIN total_spend ts
)
SELECT
    rs.supplier_id,
    rs.supplier_name,
    rs.tier_level,
    rs.country,
    rs.region,
    rs.risk_rating,
    rs.is_preferred,
    rs.annual_spend_usd,
    rs.total_shipments,
    ROUND(100 - rs.late_pct, 1)                                     AS otd_rate_pct,
    rs.defect_ppm,
    rs.lead_time_std_dev,

    -- Component scores
    rs.otd_risk_score,
    rs.quality_risk_score,
    rs.spend_risk_score,
    rs.rating_risk_score,
    rs.variability_risk_score,

    -- Composite risk score (0-100; higher = more at-risk)
    ROUND(
        rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
        + rs.rating_risk_score + rs.variability_risk_score,
        1
    )                                                               AS composite_risk_score,

    -- Risk tier based on composite score
    CASE
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 60 THEN 'CRITICAL RISK'
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 40 THEN 'HIGH RISK'
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 20 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END                                                             AS risk_tier,

    -- Recommended action
    CASE
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 60
        THEN 'Immediate: Qualify alternative supplier; escalate to CPO'
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 40
        THEN 'Urgent: Issue supplier corrective action; monthly review'
        WHEN rs.otd_risk_score + rs.quality_risk_score + rs.spend_risk_score
             + rs.rating_risk_score + rs.variability_risk_score >= 20
        THEN 'Monitor: Quarterly business review; request improvement plan'
        ELSE 'Maintain: Standard monitoring cadence'
    END                                                             AS recommended_action

FROM risk_scores rs

ORDER BY composite_risk_score DESC;


-- =============================================================================
-- QUERY 5: Supplier Performance Scorecard (Rolling 12 Months)
-- =============================================================================
-- BUSINESS PURPOSE:
--   Monthly Supplier Scorecard used in Quarterly Business Reviews (QBRs).
--   Provides a single-page summary of performance across all key dimensions.
--   Distributed to suppliers as part of the supplier development program.
-- =============================================================================

WITH rolling_12m AS (
    -- Establish the 12-month window relative to current date
    SELECT
        DATEADD(MONTH, -12, CAST(GETDATE() AS DATE)) AS window_start,  -- [PostgreSQL: CURRENT_DATE - INTERVAL '12 months']
        CAST(GETDATE() AS DATE)                       AS window_end
),
monthly_otd AS (
    -- Monthly OTD trend for sparkline visualization
    SELECT
        f.supplier_key,
        d.year_month,
        COUNT(f.shipment_id)                                        AS shipments,
        ROUND(
            100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(f.shipment_id), 0), 1
        )                                                           AS monthly_otd_pct
    FROM fact_shipments f
    JOIN dim_date d ON f.ship_date_key = d.date_key
    CROSS JOIN rolling_12m r
    WHERE f.actual_delivery_date_key IS NOT NULL
      AND d.full_date BETWEEN r.window_start AND r.window_end
    GROUP BY f.supplier_key, d.year_month
)
SELECT
    s.supplier_id,
    s.supplier_name,
    s.tier_level,
    s.supplier_type,
    s.country,
    s.region,
    s.risk_rating,
    s.certification_iatf,
    s.annual_spend_usd,

    -- Volume
    COUNT(DISTINCT d.year_month)                                    AS active_months,
    COUNT(f.shipment_id)                                            AS total_shipments,
    SUM(f.quantity_shipped)                                         AS total_units_shipped,

    -- On-Time Delivery
    ROUND(
        100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0),
        1
    )                                                               AS otd_rate_pct,
    ROUND(AVG(CASE WHEN f.delay_days > 0 THEN CAST(f.delay_days AS FLOAT) END), 1) AS avg_days_late,

    -- Quality
    ROUND(
        1000000.0 * SUM(ISNULL(f.quantity_rejected, 0))
                  / NULLIF(SUM(f.quantity_received), 0), 0
    )                                                               AS defect_ppm,

    -- Lead Time
    ROUND(AVG(CAST(f.actual_transit_days AS FLOAT)), 1)             AS avg_lead_time_days,
    ROUND(STDEV(CAST(f.actual_transit_days AS FLOAT)), 1)           AS lead_time_variability,

    -- Cost
    SUM(f.total_logistics_cost_usd)                                 AS total_freight_cost_usd,
    ROUND(AVG(f.cost_per_unit_usd), 4)                              AS avg_cost_per_unit_usd,

    -- Scorecard Grade (A/B/C/D/F)
    CASE
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0), 1) >= 95
             AND ROUND(1000000.0 * SUM(ISNULL(f.quantity_rejected,0)) / NULLIF(SUM(f.quantity_received),0), 0) <= 500
        THEN 'A - Excellent'
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0), 1) >= 90
             AND ROUND(1000000.0 * SUM(ISNULL(f.quantity_rejected,0)) / NULLIF(SUM(f.quantity_received),0), 0) <= 1000
        THEN 'B - Good'
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0), 1) >= 80
        THEN 'C - Needs Improvement'
        WHEN ROUND(100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                         / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0), 1) >= 70
        THEN 'D - Poor - Under Watch'
        ELSE 'F - Failing - Corrective Action'
    END                                                             AS scorecard_grade

FROM fact_shipments     f
JOIN dim_supplier       s ON f.supplier_key = s.supplier_key
JOIN dim_date           d ON f.ship_date_key = d.date_key
CROSS JOIN rolling_12m  r

WHERE
    d.full_date BETWEEN r.window_start AND r.window_end
    AND f.shipment_status IN ('Delivered', 'In Transit')

GROUP BY
    s.supplier_id, s.supplier_name, s.tier_level, s.supplier_type,
    s.country, s.region, s.risk_rating, s.certification_iatf, s.annual_spend_usd

HAVING COUNT(f.shipment_id) >= 5

ORDER BY otd_rate_pct ASC, defect_ppm DESC;


-- =============================================================================
-- END OF FILE: 01_supplier_performance_analysis.sql
-- =============================================================================
