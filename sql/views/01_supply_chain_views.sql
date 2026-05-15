-- ============================================================
-- Supply Chain Analytical Views
-- Automotive Supply Chain Intelligence Platform
-- ============================================================
--
-- PURPOSE:
--   Pre-built SQL views that simplify Power BI queries and
--   ad-hoc analyst reporting. Views encapsulate complex joins
--   so analysts write simple SELECT statements instead.
--
-- COMPATIBLE WITH: PostgreSQL, SQL Server (syntax noted inline)
-- ============================================================


-- ============================================================
-- VIEW 1: vw_supplier_scorecard
-- Complete supplier performance summary in one query
-- Used by: Supplier Performance Dashboard, Procurement team
-- ============================================================
CREATE OR REPLACE VIEW vw_supplier_scorecard AS
SELECT
    s.supplier_id,
    s.supplier_name,
    s.supplier_region,
    s.primary_component,
    s.certification_status,
    s.annual_contract_value_usd,
    s.lead_time_days                               AS contracted_lead_time_days,
    s.defect_rate_pct                              AS supplier_reported_defect_rate,
    s.reliability_score,
    s.delivery_performance_pct                     AS contracted_otd_pct,
    s.supplier_risk_score,

    -- Calculated from actual shipments
    COUNT(sh.shipment_id)                          AS total_shipments,
    SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END) AS on_time_shipments,
    ROUND(
        SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(sh.shipment_id), 0) * 100, 2
    )                                              AS actual_otd_pct,
    ROUND(AVG(CASE WHEN sh.delay_days > 0 THEN sh.delay_days END), 2)
                                                   AS avg_delay_days_when_late,
    ROUND(SUM(sh.transportation_cost_usd), 2)      AS total_transport_cost,
    ROUND(AVG(sh.transportation_cost_usd), 2)      AS avg_transport_cost_per_shipment,

    -- Composite performance score (matches dashboard KPI)
    -- Formula: OTD 50% + Quality 30% + Reliability 20%
    ROUND(
        (SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
         / NULLIF(COUNT(sh.shipment_id), 0) * 100) * 0.50
        + (100 - COALESCE(s.defect_rate_pct, 5)) * 0.30
        + COALESCE(s.reliability_score, 70) * 0.20,
        2
    )                                              AS composite_performance_score,

    -- Risk classification
    CASE
        WHEN s.supplier_risk_score <= 3 THEN 'Low Risk'
        WHEN s.supplier_risk_score <= 6 THEN 'Medium Risk'
        ELSE 'High Risk'
    END                                            AS risk_tier,

    -- Performance tier (for supplier categorization)
    CASE
        WHEN ROUND(
            (SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
             / NULLIF(COUNT(sh.shipment_id), 0) * 100) * 0.50
            + (100 - COALESCE(s.defect_rate_pct, 5)) * 0.30
            + COALESCE(s.reliability_score, 70) * 0.20, 2) >= 90 THEN 'Preferred'
        WHEN ROUND(
            (SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
             / NULLIF(COUNT(sh.shipment_id), 0) * 100) * 0.50
            + (100 - COALESCE(s.defect_rate_pct, 5)) * 0.30
            + COALESCE(s.reliability_score, 70) * 0.20, 2) >= 80 THEN 'Approved'
        WHEN ROUND(
            (SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
             / NULLIF(COUNT(sh.shipment_id), 0) * 100) * 0.50
            + (100 - COALESCE(s.defect_rate_pct, 5)) * 0.30
            + COALESCE(s.reliability_score, 70) * 0.20, 2) >= 70 THEN 'Conditional'
        ELSE 'Probationary'
    END                                            AS performance_tier

FROM dim_supplier s
LEFT JOIN fact_shipments sh ON s.supplier_id = sh.supplier_id
GROUP BY
    s.supplier_id, s.supplier_name, s.supplier_region, s.primary_component,
    s.certification_status, s.annual_contract_value_usd, s.lead_time_days,
    s.defect_rate_pct, s.reliability_score, s.delivery_performance_pct,
    s.supplier_risk_score;


-- ============================================================
-- VIEW 2: vw_inventory_health
-- Current inventory status with risk classification
-- Used by: Inventory & Warehouse Dashboard, Operations team
-- ============================================================
CREATE OR REPLACE VIEW vw_inventory_health AS
WITH latest_snapshot AS (
    -- Get only the most recent inventory snapshot for each location
    SELECT
        warehouse_id,
        product_id,
        MAX(snapshot_date) AS latest_date
    FROM fact_inventory
    GROUP BY warehouse_id, product_id
)
SELECT
    fi.warehouse_id,
    fi.product_id,
    fi.snapshot_date,
    fi.stock_quantity,
    fi.reorder_level,
    fi.safety_stock_level,
    fi.inventory_value_usd,
    fi.days_of_supply,
    fi.abc_category,
    fi.stockout_risk_score,
    fi.last_replenishment_date,

    -- Dimension data
    w.warehouse_name,
    w.region,
    w.state,
    w.warehouse_type,
    w.storage_capacity_units,
    w.current_utilization_pct,

    p.product_name,
    p.product_category,
    p.unit_cost_usd,
    p.is_critical_component,

    -- Risk flags
    CASE WHEN fi.stock_quantity < fi.safety_stock_level THEN 1 ELSE 0 END
        AS is_below_safety_stock,
    CASE WHEN fi.stock_quantity < fi.reorder_level THEN 1 ELSE 0 END
        AS is_below_reorder_point,

    -- Inventory health status (used for Power BI traffic lights)
    CASE
        WHEN fi.stock_quantity < fi.safety_stock_level THEN 'CRITICAL'
        WHEN fi.stock_quantity < fi.reorder_level THEN 'REORDER'
        WHEN fi.days_of_supply > 60 THEN 'OVERSTOCK'
        ELSE 'HEALTHY'
    END AS inventory_status,

    -- Priority score for analysts (lower = needs attention sooner)
    ROUND(fi.days_of_supply, 1) AS days_until_stockout,

    -- Overstock indicator (inventory value above 60 days of supply)
    CASE WHEN fi.days_of_supply > 60 THEN 1 ELSE 0 END AS is_overstock

FROM fact_inventory fi
JOIN latest_snapshot ls
    ON fi.warehouse_id = ls.warehouse_id
    AND fi.product_id = ls.product_id
    AND fi.snapshot_date = ls.latest_date
LEFT JOIN dim_warehouse w ON fi.warehouse_id = w.warehouse_id
LEFT JOIN dim_product p ON fi.product_id = p.product_id;


-- ============================================================
-- VIEW 3: vw_shipment_performance
-- Enriched shipment view with supplier and warehouse details
-- Used by: Logistics Dashboard, Supplier Performance Dashboard
-- ============================================================
CREATE OR REPLACE VIEW vw_shipment_performance AS
SELECT
    sh.shipment_id,
    sh.shipment_date,
    sh.expected_delivery_date,
    sh.actual_delivery_date,
    sh.delay_days,
    sh.is_on_time,
    sh.delay_category,
    sh.delay_reason,
    sh.quantity_shipped,
    sh.transportation_cost_usd,
    sh.fuel_cost_usd,
    sh.total_shipment_value_usd,
    sh.transportation_mode,
    sh.carrier_name,
    sh.route_name,
    sh.distance_miles,
    sh.cost_per_mile_usd,
    sh.shipment_weight_lbs,
    sh.shipment_status,

    -- Supplier details
    s.supplier_name,
    s.supplier_region,
    s.primary_component,
    s.supplier_risk_score,
    s.risk_tier,

    -- Warehouse details
    w.warehouse_name,
    w.region            AS destination_region,
    w.state             AS destination_state,

    -- Product details
    p.product_name,
    p.product_category,
    p.is_critical_component,

    -- Time dimensions for slicing
    sh.shipment_year,
    sh.shipment_month,
    sh.shipment_quarter,
    sh.shipment_quarter_label,

    -- Cost efficiency metric
    CASE
        WHEN sh.transportation_mode = 'Air' THEN 'Premium (Air)'
        WHEN sh.cost_per_mile_usd > 3.0 THEN 'Above Average Cost'
        WHEN sh.cost_per_mile_usd > 2.0 THEN 'Average Cost'
        ELSE 'Below Average Cost'
    END AS cost_efficiency_tier

FROM fact_shipments sh
LEFT JOIN dim_supplier s ON sh.supplier_id = s.supplier_id
LEFT JOIN dim_warehouse w ON sh.warehouse_id = w.warehouse_id
LEFT JOIN dim_product p ON sh.product_id = p.product_id;


-- ============================================================
-- VIEW 4: vw_plant_efficiency
-- Manufacturing plant performance summary
-- Used by: Manufacturing Operations Dashboard
-- ============================================================
CREATE OR REPLACE VIEW vw_plant_efficiency AS
SELECT
    fp.plant_id,
    fp.production_date,
    fp.shift,
    fp.vehicle_type,
    fp.planned_production_units,
    fp.actual_production_units,
    fp.defect_units,
    fp.good_units,
    fp.downtime_hours,
    fp.downtime_reason,
    fp.downtime_category,
    fp.has_downtime,
    fp.utilization_rate_pct,
    fp.defect_rate_pct,
    fp.energy_consumption_kwh,

    -- Plant dimension details
    pl.plant_name,
    pl.oem_company,
    pl.state             AS plant_state,
    pl.city              AS plant_city,
    pl.plant_type,
    pl.total_capacity_units_daily,
    pl.workforce_size,

    -- Time dimensions
    fp.production_year,
    fp.production_month,
    fp.production_quarter,

    -- OEE Components (simplified)
    -- Availability = 1 - (downtime / total scheduled hours)
    ROUND(
        CASE WHEN (fp.actual_production_units * 0.0083 + fp.downtime_hours) > 0
        THEN 1.0 - (fp.downtime_hours / (fp.actual_production_units * 0.0083 + fp.downtime_hours))
        ELSE 1.0 END * 100, 2
    )                    AS availability_pct,

    -- Performance = actual vs planned rate
    ROUND(
        fp.actual_production_units::NUMERIC / NULLIF(fp.planned_production_units, 0) * 100,
        2
    )                    AS performance_pct,

    -- Quality = good units / total units
    ROUND(
        fp.good_units::NUMERIC / NULLIF(fp.actual_production_units, 0) * 100,
        2
    )                    AS quality_pct,

    -- Efficiency classification
    CASE
        WHEN fp.utilization_rate_pct >= 90 THEN 'Excellent'
        WHEN fp.utilization_rate_pct >= 80 THEN 'Good'
        WHEN fp.utilization_rate_pct >= 70 THEN 'Fair'
        ELSE 'Poor'
    END                  AS utilization_tier

FROM fact_production fp
LEFT JOIN dim_plant pl ON fp.plant_id = pl.plant_id;


-- ============================================================
-- VIEW 5: vw_executive_kpi_dashboard
-- Rolling 12-month summary for executive dashboard
-- This view is queried directly by the Power BI Executive page
-- Refreshed daily via scheduled job
-- ============================================================
CREATE OR REPLACE VIEW vw_executive_kpi_dashboard AS
SELECT
    -- On-Time Delivery
    ROUND(
        SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(sh.shipment_id), 0) * 100, 2
    )                                AS otd_pct,

    -- Delayed shipments
    SUM(CASE WHEN sh.delay_days > 0 THEN 1 ELSE 0 END)
                                     AS total_delayed_shipments,

    -- Total shipments
    COUNT(sh.shipment_id)            AS total_shipments,

    -- Transportation spend
    ROUND(SUM(sh.transportation_cost_usd), 0)
                                     AS total_transport_cost,

    -- Avg cost per shipment
    ROUND(AVG(sh.transportation_cost_usd), 0)
                                     AS avg_cost_per_shipment

FROM fact_shipments sh
WHERE sh.shipment_date >= CURRENT_DATE - INTERVAL '12 months';
