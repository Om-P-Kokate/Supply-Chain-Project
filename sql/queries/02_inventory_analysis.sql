-- =============================================================================
-- FILE: 02_inventory_analysis.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Inventory health, risk, and optimization analysis
--
-- BUSINESS CONTEXT:
--   Inventory management in automotive manufacturing requires balancing two
--   competing risks: stockout (line stoppage = ~$15K-$50K/minute in a typical
--   assembly plant) vs. overstock (carrying cost ~25-30% of inventory value
--   per year including capital, storage, and obsolescence).
--
--   These queries support the daily S&OP (Sales & Operations Planning) process,
--   weekly inventory review meetings, and the annual working capital targets.
--
-- KEY METRICS:
--   - Days of Supply (DOS): How many days of production the current stock can cover
--   - Inventory Turnover: COGS / Average Inventory Value (higher = leaner)
--   - Fill Rate: % of demand met from available stock
--   - ABC Classification: Focus on the 20% of SKUs driving 80% of inventory value
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: Replace GETDATE() -> CURRENT_DATE, ISNULL() -> COALESCE(),
--                 TOP N -> LIMIT N, DATEADD() -> date + INTERVAL
-- =============================================================================


-- =============================================================================
-- QUERY 1: Warehouses at Stockout Risk
-- =============================================================================
-- BUSINESS PURPOSE:
--   Daily alert report identifying products below safety stock level at each
--   warehouse. Results feed an automated email alert to Planners and Buyers.
--   Safety stock is the minimum buffer designed to cover demand variability
--   and lead time uncertainty. Dropping below it puts production at risk.
--
-- ACTION: Planners should review each alert and either issue an expedite PO,
--         initiate an inter-warehouse transfer, or escalate to manufacturing
--         to resequence production.
-- =============================================================================

SELECT
    w.warehouse_id,
    w.warehouse_name,
    w.warehouse_type,
    w.region                                            AS warehouse_region,
    w.city                                              AS warehouse_city,

    p.product_id,
    p.product_name,
    p.product_category,
    p.unit_of_measure,

    -- Current inventory position
    i.closing_stock_qty,
    i.reserved_qty,
    i.available_qty,                                    -- What can actually be used
    i.in_transit_qty,                                   -- Expected incoming stock
    i.safety_stock_qty,
    i.reorder_point_qty,

    -- Risk quantification
    i.closing_stock_qty - i.safety_stock_qty            AS stock_vs_safety_stock,   -- Negative = below target
    i.days_of_supply                                    AS estimated_days_of_supply,

    -- Value at risk
    ROUND(i.safety_stock_qty * ISNULL(p.standard_cost_usd, 0), 2) AS safety_stock_value_usd,
    ROUND(i.closing_stock_qty * ISNULL(p.standard_cost_usd, 0), 2) AS current_stock_value_usd,

    -- Stockout severity
    CASE
        WHEN i.closing_stock_qty <= 0                  THEN 'STOCKOUT - Line at Risk'
        WHEN i.available_qty <= 0                      THEN 'EFFECTIVE STOCKOUT - All Reserved'
        WHEN i.days_of_supply IS NOT NULL
             AND i.days_of_supply <= 1                 THEN 'CRITICAL - <1 Day Supply'
        WHEN i.days_of_supply IS NOT NULL
             AND i.days_of_supply <= 3                 THEN 'HIGH - <3 Days Supply'
        WHEN i.closing_stock_qty < i.safety_stock_qty  THEN 'ELEVATED - Below Safety Stock'
        ELSE 'AT REORDER POINT'
    END                                                 AS stockout_risk_level,

    -- Recommended action
    CASE
        WHEN i.closing_stock_qty <= 0
        THEN 'IMMEDIATE: Source from alternate warehouse or supplier. Notify production.'
        WHEN i.days_of_supply IS NOT NULL AND i.days_of_supply <= 1
        THEN 'URGENT: Issue expedite PO. Expected lead time vs DOS gap = CRITICAL.'
        WHEN i.closing_stock_qty < i.safety_stock_qty
        THEN 'ACTION: Issue replenishment PO immediately. Monitor daily.'
        ELSE 'ACTION: Issue standard replenishment PO per normal cycle.'
    END                                                 AS recommended_action,

    -- Primary supplier for reorder
    s.supplier_name                                     AS preferred_supplier,
    p.lead_time_days                                    AS supplier_lead_time_days,

    i.snapshot_date_key                                 AS data_as_of_date_key

FROM fact_inventory     i
JOIN dim_warehouse      w ON i.warehouse_key    = w.warehouse_key
JOIN dim_product        p ON i.product_key      = p.product_key
LEFT JOIN dim_supplier  s ON p.primary_supplier_key = s.supplier_key
JOIN dim_date           d ON i.snapshot_date_key = d.date_key

WHERE
    -- Most recent snapshot only
    d.is_current_day = 1
    AND (i.stockout_risk_flag = 1 OR i.closing_stock_qty <= i.reorder_point_qty)
    AND w.is_active = 1
    AND p.is_active = 1

ORDER BY
    -- Sort by severity: stockouts first, then by days of supply ascending
    CASE
        WHEN i.closing_stock_qty <= 0 THEN 0
        WHEN i.available_qty <= 0     THEN 1
        WHEN i.days_of_supply <= 1    THEN 2
        WHEN i.days_of_supply <= 3    THEN 3
        ELSE 4
    END,
    i.days_of_supply ASC NULLS LAST;  -- [SQL Server: use ISNULL(days_of_supply, 9999)]


-- =============================================================================
-- QUERY 2: Inventory Turnover by Warehouse
-- =============================================================================
-- BUSINESS PURPOSE:
--   Inventory turnover measures how efficiently each warehouse converts
--   inventory into production or sales. Low turnover = excess capital tied up.
--   High turnover = lean and responsive but higher stockout risk.
--   Target: 12-15x annual turns for production parts; 8-10x for MRO/slow-movers.
--
--   Formula: Turnover = Annual COGS (issues * cost) / Average Stock Value
--   Days of Inventory Outstanding (DIO) = 365 / Turnover
-- =============================================================================

WITH monthly_inventory AS (
    -- Aggregate inventory value by warehouse and month
    SELECT
        i.warehouse_key,
        d.year_number,
        d.month_number,
        d.year_month,
        SUM(i.closing_stock_qty * ISNULL(i.unit_cost_usd, 0))  AS month_end_stock_value,
        SUM(i.issues_qty * ISNULL(i.unit_cost_usd, 0))         AS monthly_cogs,   -- Proxy for COGS
        SUM(i.receipts_qty * ISNULL(i.unit_cost_usd, 0))       AS monthly_receipts_value
    FROM fact_inventory i
    JOIN dim_date d ON i.snapshot_date_key = d.date_key
    WHERE d.is_current_year = 1
      AND d.day_of_month = d.day_of_month   -- All days (monthly average via AVG below)
    GROUP BY i.warehouse_key, d.year_number, d.month_number, d.year_month
)
SELECT
    w.warehouse_id,
    w.warehouse_name,
    w.warehouse_type,
    w.region,
    w.city,
    w.max_pallet_positions,

    -- Annual COGS (issues)
    ROUND(SUM(mi.monthly_cogs), 2)                              AS annual_cogs_usd,

    -- Average inventory value (simple average of month-end values)
    ROUND(AVG(mi.month_end_stock_value), 2)                     AS avg_inventory_value_usd,
    ROUND(MIN(mi.month_end_stock_value), 2)                     AS min_inventory_value_usd,
    ROUND(MAX(mi.month_end_stock_value), 2)                     AS max_inventory_value_usd,

    -- Inventory Turnover = Annual COGS / Average Inventory
    ROUND(
        SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0),
        2
    )                                                           AS inventory_turns,

    -- Days of Inventory Outstanding = 365 / Turns
    ROUND(
        365.0 / NULLIF(
            SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0),
            0
        ),
        1
    )                                                           AS days_inventory_outstanding,

    -- Turnover performance band
    CASE
        WHEN SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0) >= 15 THEN 'Excellent - Very Lean'
        WHEN SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0) >= 12 THEN 'Good - On Target'
        WHEN SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0) >= 8  THEN 'Fair - Improvement Needed'
        WHEN SUM(mi.monthly_cogs) / NULLIF(AVG(mi.month_end_stock_value), 0) >= 4  THEN 'Poor - Excess Stock'
        ELSE 'Critical - Very Slow Moving'
    END                                                         AS turnover_band,

    COUNT(mi.year_month)                                        AS months_of_data

FROM monthly_inventory  mi
JOIN dim_warehouse      w ON mi.warehouse_key = w.warehouse_key

WHERE w.is_active = 1

GROUP BY
    w.warehouse_id, w.warehouse_name, w.warehouse_type,
    w.region, w.city, w.max_pallet_positions

ORDER BY inventory_turns DESC;


-- =============================================================================
-- QUERY 3: ABC Analysis (Inventory Value Classification)
-- =============================================================================
-- BUSINESS PURPOSE:
--   ABC analysis focuses management attention where it matters most.
--   Class A items (top 20% by value) require tight control, frequent cycle
--   counts, and dedicated buyer attention. Class C items can use simpler
--   min-max replenishment with less oversight.
--
--   Classic Pareto principle: ~20% of SKUs = ~80% of inventory value.
--
--   Output used to:
--     1. Set cycle count frequencies (A=monthly, B=quarterly, C=annually)
--     2. Assign buyer workloads
--     3. Set safety stock policies (A=lean, C=generous buffer)
--     4. Target SKU rationalization opportunities
-- =============================================================================

WITH product_inventory_value AS (
    -- Current on-hand value per product across all warehouses
    SELECT
        i.product_key,
        SUM(i.closing_stock_qty * ISNULL(i.unit_cost_usd, p.standard_cost_usd)) AS total_inventory_value_usd,
        SUM(i.closing_stock_qty)                                                  AS total_qty_on_hand,
        SUM(i.issues_qty)                                                         AS total_annual_usage,   -- Proxy for annual consumption
        AVG(ISNULL(i.unit_cost_usd, p.standard_cost_usd))                        AS avg_unit_cost
    FROM fact_inventory i
    JOIN dim_product    p ON i.product_key = p.product_key
    JOIN dim_date       d ON i.snapshot_date_key = d.date_key
    WHERE d.is_current_day = 1
      AND p.is_active = 1
    GROUP BY i.product_key
),
ranked AS (
    SELECT
        piv.*,
        -- Cumulative value percentage (rank from highest value to lowest)
        SUM(piv.total_inventory_value_usd)
            OVER (ORDER BY piv.total_inventory_value_usd DESC
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)             AS cumulative_value,
        SUM(piv.total_inventory_value_usd) OVER ()                              AS grand_total_value,
        COUNT(*) OVER ()                                                        AS total_sku_count,
        ROW_NUMBER() OVER (ORDER BY piv.total_inventory_value_usd DESC)         AS value_rank
    FROM product_inventory_value piv
)
SELECT
    r.value_rank,
    p.product_id,
    p.product_name,
    p.product_category,
    p.product_subcategory,
    p.product_type,
    p.unit_of_measure,

    -- Value metrics
    ROUND(r.total_inventory_value_usd, 2)                       AS inventory_value_usd,
    ROUND(r.avg_unit_cost, 4)                                   AS unit_cost_usd,
    ROUND(r.total_qty_on_hand, 2)                               AS qty_on_hand,
    ROUND(r.total_annual_usage, 2)                              AS annual_usage_qty,

    -- Cumulative analysis
    ROUND(100.0 * r.cumulative_value / NULLIF(r.grand_total_value, 0), 2)  AS cumulative_value_pct,
    ROUND(100.0 * r.value_rank / NULLIF(r.total_sku_count, 0), 2)           AS cumulative_sku_pct,
    ROUND(100.0 * r.total_inventory_value_usd / NULLIF(r.grand_total_value, 0), 4) AS pct_of_total_value,

    -- ABC classification
    -- A: Top 80% of value (typically ~20% of SKUs)
    -- B: Next 15% of value (typically ~30% of SKUs)
    -- C: Bottom 5% of value (typically ~50% of SKUs)
    CASE
        WHEN 100.0 * r.cumulative_value / NULLIF(r.grand_total_value, 0) <= 80 THEN 'A'
        WHEN 100.0 * r.cumulative_value / NULLIF(r.grand_total_value, 0) <= 95 THEN 'B'
        ELSE 'C'
    END                                                         AS abc_class,

    -- Management policy recommendations
    CASE
        WHEN 100.0 * r.cumulative_value / NULLIF(r.grand_total_value, 0) <= 80
        THEN 'Tight control: Monthly cycle count, dedicated buyer, lean safety stock, EOQ ordering'
        WHEN 100.0 * r.cumulative_value / NULLIF(r.grand_total_value, 0) <= 95
        THEN 'Moderate control: Quarterly cycle count, team buyer, moderate safety stock'
        ELSE 'Relaxed control: Annual count, min-max replenishment, generous safety stock'
    END                                                         AS management_policy

FROM ranked        r
JOIN dim_product   p ON r.product_key = p.product_key

ORDER BY r.value_rank;


-- =============================================================================
-- QUERY 3b: ABC Analysis Summary
-- =============================================================================
-- Quick summary showing the value distribution across ABC classes

WITH product_inventory_value AS (
    SELECT
        i.product_key,
        SUM(i.closing_stock_qty * ISNULL(i.unit_cost_usd, p.standard_cost_usd)) AS total_inventory_value_usd
    FROM fact_inventory i
    JOIN dim_product    p ON i.product_key = p.product_key
    JOIN dim_date       d ON i.snapshot_date_key = d.date_key
    WHERE d.is_current_day = 1 AND p.is_active = 1
    GROUP BY i.product_key
),
ranked AS (
    SELECT *,
        SUM(total_inventory_value_usd) OVER (ORDER BY total_inventory_value_usd DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_value,
        SUM(total_inventory_value_usd) OVER ()                AS grand_total
    FROM product_inventory_value
),
classified AS (
    SELECT *,
        CASE WHEN 100.0*cumulative_value/grand_total <= 80 THEN 'A'
             WHEN 100.0*cumulative_value/grand_total <= 95 THEN 'B'
             ELSE 'C' END AS abc_class
    FROM ranked
)
SELECT
    abc_class,
    COUNT(*)                                                    AS sku_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_skus,
    ROUND(SUM(total_inventory_value_usd), 0)                   AS total_value_usd,
    ROUND(100.0 * SUM(total_inventory_value_usd)
               / NULLIF(MAX(grand_total), 0), 1)               AS pct_of_total_value,
    ROUND(AVG(total_inventory_value_usd), 0)                   AS avg_value_per_sku_usd
FROM classified
GROUP BY abc_class
ORDER BY abc_class;


-- =============================================================================
-- QUERY 4: Overstock Alerts
-- =============================================================================
-- BUSINESS PURPOSE:
--   Overstock ties up working capital and risks obsolescence. In automotive,
--   parts become obsolete when a vehicle model changes or production ends.
--   This query identifies items exceeding 120% of maximum planned stock,
--   enabling buyers to reduce future PO quantities or find alternative demand.
--
--   Annual carrying cost assumed at 25% of inventory value.
-- =============================================================================

SELECT
    w.warehouse_id,
    w.warehouse_name,
    w.region,

    p.product_id,
    p.product_name,
    p.product_category,

    -- Current stock vs targets
    i.closing_stock_qty,
    i.max_stock_qty,
    i.safety_stock_qty,
    i.reorder_point_qty,
    i.days_of_supply,

    -- Excess calculation
    CASE
        WHEN i.max_stock_qty > 0
        THEN i.closing_stock_qty - i.max_stock_qty
        ELSE i.closing_stock_qty - (i.safety_stock_qty * 3)   -- If max not set, flag at 3x safety stock
    END                                                         AS excess_qty,

    -- Excess value
    ROUND(
        CASE
            WHEN i.max_stock_qty > 0
            THEN (i.closing_stock_qty - i.max_stock_qty) * ISNULL(i.unit_cost_usd, p.standard_cost_usd)
            ELSE (i.closing_stock_qty - i.safety_stock_qty * 3) * ISNULL(i.unit_cost_usd, p.standard_cost_usd)
        END,
        2
    )                                                           AS excess_inventory_value_usd,

    -- Annual carrying cost of excess
    ROUND(
        0.25 * CASE
            WHEN i.max_stock_qty > 0
            THEN GREATEST(0, i.closing_stock_qty - i.max_stock_qty)   -- [SQL Server: use CASE WHEN > 0]
                 * ISNULL(i.unit_cost_usd, p.standard_cost_usd)
            ELSE GREATEST(0, i.closing_stock_qty - i.safety_stock_qty * 3)
                 * ISNULL(i.unit_cost_usd, p.standard_cost_usd)
        END,
        2
    )                                                           AS annual_carrying_cost_usd,

    -- Overstock severity
    CASE
        WHEN i.max_stock_qty > 0
             AND i.closing_stock_qty >= i.max_stock_qty * 2.0   THEN 'SEVERE (>200% of max)'
        WHEN i.max_stock_qty > 0
             AND i.closing_stock_qty >= i.max_stock_qty * 1.5   THEN 'HIGH (150-200% of max)'
        WHEN i.max_stock_qty > 0
             AND i.closing_stock_qty >= i.max_stock_qty * 1.2   THEN 'MODERATE (120-150% of max)'
        ELSE 'MILD (above safety*3)'
    END                                                         AS overstock_severity,

    -- Recommended action
    CASE
        WHEN i.days_of_supply > 90  THEN 'Review: >90 days supply. Assess obsolescence risk. Reduce POs.'
        WHEN i.days_of_supply > 60  THEN 'Action: >60 days supply. Cancel/defer open POs.'
        WHEN i.days_of_supply > 30  THEN 'Monitor: >30 days supply. Reduce next PO quantity.'
        ELSE 'Note: Above max but <30 days. Monitor and slow replenishment.'
    END                                                         AS recommended_action

FROM fact_inventory     i
JOIN dim_warehouse      w ON i.warehouse_key = w.warehouse_key
JOIN dim_product        p ON i.product_key   = p.product_key
JOIN dim_date           d ON i.snapshot_date_key = d.date_key

WHERE
    d.is_current_day = 1
    AND i.overstock_flag = 1
    AND w.is_active = 1
    AND p.is_active = 1

ORDER BY excess_inventory_value_usd DESC;


-- =============================================================================
-- QUERY 5: Days of Supply by Product and Warehouse
-- =============================================================================
-- BUSINESS PURPOSE:
--   Days of Supply (DOS) is the primary planning metric for production
--   continuity. It answers: "If no new stock arrives, how many days can we
--   run at current consumption rates?"
--
--   Formula: DOS = Closing Stock Qty / Average Daily Usage
--   Average Daily Usage = Issues over last 30 days / 30
--
--   This report is reviewed every morning in the Daily Production Meeting.
-- =============================================================================

WITH avg_daily_usage AS (
    -- Calculate average daily consumption over the past 30 days
    SELECT
        i.product_key,
        i.warehouse_key,
        SUM(i.issues_qty)                                       AS total_issues_30d,
        COUNT(DISTINCT d.full_date)                             AS active_days,
        ROUND(SUM(i.issues_qty) / NULLIF(COUNT(DISTINCT d.full_date), 0), 4) AS avg_daily_usage
    FROM fact_inventory i
    JOIN dim_date d ON i.snapshot_date_key = d.date_key
    WHERE d.full_date >= CAST(GETDATE() AS DATE) - 30   -- [PostgreSQL: CURRENT_DATE - 30]
      AND d.full_date <  CAST(GETDATE() AS DATE)
    GROUP BY i.product_key, i.warehouse_key
),
current_stock AS (
    -- Most recent snapshot
    SELECT i.*
    FROM fact_inventory i
    JOIN dim_date d ON i.snapshot_date_key = d.date_key
    WHERE d.is_current_day = 1
)
SELECT
    w.warehouse_id,
    w.warehouse_name,
    w.region,
    p.product_id,
    p.product_name,
    p.product_category,
    p.unit_of_measure,
    p.lead_time_days                                            AS supplier_lead_time_days,

    -- Stock position
    cs.closing_stock_qty,
    cs.available_qty,
    cs.in_transit_qty,
    cs.safety_stock_qty,

    -- Consumption
    ROUND(adu.avg_daily_usage, 2)                               AS avg_daily_usage_last_30d,
    ROUND(adu.total_issues_30d, 2)                              AS total_issues_last_30d,

    -- Days of Supply calculations
    ROUND(cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0), 1)     AS dos_on_hand,
    ROUND(cs.available_qty     / NULLIF(adu.avg_daily_usage, 0), 1)     AS dos_available,
    -- Including in-transit (projected DOS if all ordered stock arrives on time)
    ROUND((cs.closing_stock_qty + cs.in_transit_qty)
          / NULLIF(adu.avg_daily_usage, 0), 1)                          AS dos_projected,

    -- Coverage vs lead time (is DOS > lead time? If not, we may stock out before replenishment arrives)
    ROUND(cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0), 1)
        - ISNULL(p.lead_time_days, 0)                                   AS dos_buffer_beyond_lead_time,

    -- Traffic light status
    CASE
        WHEN adu.avg_daily_usage IS NULL OR adu.avg_daily_usage = 0
        THEN 'NO RECENT USAGE - Check if obsolete'
        WHEN cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= 0
        THEN 'RED - STOCKOUT'
        WHEN cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= 1
        THEN 'RED - <1 Day'
        WHEN cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= ISNULL(p.lead_time_days, 5)
        THEN 'AMBER - Less than Lead Time'
        WHEN cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= ISNULL(p.lead_time_days, 5) * 1.5
        THEN 'YELLOW - Approaching Lead Time Threshold'
        WHEN cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) > 60
        THEN 'BLUE - Potential Overstock (>60 days)'
        ELSE 'GREEN - Adequate Supply'
    END                                                         AS supply_status

FROM current_stock      cs
JOIN dim_warehouse      w   ON cs.warehouse_key = w.warehouse_key
JOIN dim_product        p   ON cs.product_key   = p.product_key
LEFT JOIN avg_daily_usage adu ON cs.product_key = adu.product_key
                              AND cs.warehouse_key = adu.warehouse_key

WHERE
    w.is_active = 1
    AND p.is_active = 1

ORDER BY
    -- Prioritize critical items at the top
    CASE
        WHEN adu.avg_daily_usage > 0
             AND cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= 0 THEN 0
        WHEN adu.avg_daily_usage > 0
             AND cs.closing_stock_qty / NULLIF(adu.avg_daily_usage, 0) <= 1 THEN 1
        ELSE 2
    END,
    dos_on_hand ASC NULLS LAST;  -- [SQL Server: ISNULL(dos_on_hand, 9999)]


-- =============================================================================
-- END OF FILE: 02_inventory_analysis.sql
-- =============================================================================
