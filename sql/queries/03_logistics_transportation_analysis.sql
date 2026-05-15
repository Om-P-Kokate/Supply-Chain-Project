-- =============================================================================
-- FILE: 03_logistics_transportation_analysis.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Transportation cost, carrier performance, and delay analysis
--
-- BUSINESS CONTEXT:
--   Transportation is typically 5-8% of total supply chain cost in automotive.
--   This rises sharply when expedited (air) freight is used to cover for late
--   supplier deliveries or inventory shortages. A single expedited air shipment
--   can cost 8-10x the equivalent sea/road freight.
--
--   These queries support the Logistics team's carrier negotiations, route
--   optimization initiatives, and the weekly freight cost review. They also
--   feed the Supply Chain Risk Dashboard monitored by the VP of Operations.
--
-- KEY METRICS:
--   - Transportation Cost Ratio: Freight cost as % of shipped goods value
--   - On-Time Delivery %: Carrier reliability metric
--   - Cost per Unit Shipped: Efficiency across carriers/modes/routes
--   - Delay Frequency & Duration: Root cause for corrective action
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: GETDATE() -> CURRENT_DATE, ISNULL() -> COALESCE(),
--                 TOP N -> LIMIT N
-- =============================================================================


-- =============================================================================
-- QUERY 1: Transportation Cost by Route and Carrier
-- =============================================================================
-- BUSINESS PURPOSE:
--   Identifies the most expensive routes and carriers to prioritize in freight
--   contract renegotiations. Highlights where mode shift (e.g., road to rail)
--   could generate savings. Carriers with high cost AND low OTD are candidates
--   for replacement.
--
--   Route defined as: Origin Region -> Destination Region + Transport Mode
-- =============================================================================

SELECT
    -- Route definition
    ISNULL(orig_r.region_name, 'Direct from Supplier')             AS origin_region,
    ISNULL(orig_r.country, s.country)                              AS origin_country,
    ISNULL(dest_r.region_name, 'Unknown')                          AS destination_region,
    f.transport_mode,
    f.carrier_name,
    f.service_level,

    -- Volume
    COUNT(f.shipment_id)                                            AS shipment_count,
    SUM(f.quantity_shipped)                                         AS total_units_shipped,
    ROUND(SUM(ISNULL(f.gross_weight_kg, 0)), 1)                     AS total_weight_kg,
    ROUND(SUM(ISNULL(f.volume_m3, 0)), 2)                           AS total_volume_m3,

    -- Cost breakdown
    ROUND(SUM(ISNULL(f.freight_cost_usd, 0)), 2)                    AS total_freight_cost_usd,
    ROUND(SUM(ISNULL(f.fuel_surcharge_usd, 0)), 2)                  AS total_fuel_surcharge_usd,
    ROUND(SUM(ISNULL(f.handling_cost_usd, 0)), 2)                   AS total_handling_cost_usd,
    ROUND(SUM(ISNULL(f.customs_duty_usd, 0)), 2)                    AS total_customs_duty_usd,
    ROUND(SUM(ISNULL(f.total_logistics_cost_usd, 0)), 2)            AS total_logistics_cost_usd,

    -- Unit cost efficiency metrics
    ROUND(
        SUM(ISNULL(f.total_logistics_cost_usd, 0))
        / NULLIF(COUNT(f.shipment_id), 0),
        2
    )                                                               AS avg_cost_per_shipment_usd,
    ROUND(
        SUM(ISNULL(f.total_logistics_cost_usd, 0))
        / NULLIF(SUM(f.quantity_shipped), 0),
        4
    )                                                               AS avg_cost_per_unit_usd,
    ROUND(
        SUM(ISNULL(f.total_logistics_cost_usd, 0))
        / NULLIF(SUM(ISNULL(f.gross_weight_kg, 0)), 0),
        4
    )                                                               AS avg_cost_per_kg_usd,

    -- Fuel surcharge as % of freight (high % = fuel price exposure)
    ROUND(
        100.0 * SUM(ISNULL(f.fuel_surcharge_usd, 0))
              / NULLIF(SUM(ISNULL(f.freight_cost_usd, 0)), 0),
        1
    )                                                               AS fuel_surcharge_pct_of_freight,

    -- Delivery performance on this route
    ROUND(
        100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0),
        1
    )                                                               AS otd_rate_pct,
    ROUND(AVG(CAST(f.actual_transit_days AS FLOAT)), 1)             AS avg_transit_days,

    -- Transit time reliability (low std dev = consistent carrier)
    ROUND(STDEV(CAST(f.actual_transit_days AS FLOAT)), 1)           AS transit_time_std_dev,

    -- Cost efficiency vs mode benchmark (higher = more expensive than mode average)
    -- This will be enhanced in the view layer with a cross-join to mode averages
    ROUND(
        100.0 * SUM(ISNULL(f.total_logistics_cost_usd, 0))
              / NULLIF(SUM(ISNULL(f.total_logistics_cost_usd, 0))
                       OVER (PARTITION BY f.transport_mode), 0),
        1
    )                                                               AS pct_of_mode_total_spend

FROM fact_shipments     f
JOIN dim_supplier       s ON f.supplier_key = s.supplier_key
LEFT JOIN dim_region    orig_r ON f.origin_region_key = orig_r.region_key
LEFT JOIN dim_region    dest_r ON f.dest_region_key   = dest_r.region_key
JOIN dim_date           d ON f.ship_date_key = d.date_key

WHERE
    d.year_number = YEAR(GETDATE())   -- Current year
    AND f.shipment_status IN ('Delivered', 'In Transit')

GROUP BY
    orig_r.region_name, orig_r.country, s.country,
    dest_r.region_name,
    f.transport_mode, f.carrier_name, f.service_level

HAVING COUNT(f.shipment_id) >= 5

ORDER BY total_logistics_cost_usd DESC;


-- =============================================================================
-- QUERY 2: Delay Analysis by Reason and Supplier
-- =============================================================================
-- BUSINESS PURPOSE:
--   Root cause analysis on delivery delays to direct corrective actions.
--   Weather and traffic delays are typically uncontrollable; supplier-caused
--   delays (wrong documents, late handover) and carrier failures are actionable.
--
--   Used to populate the monthly Supply Chain Disruption Report and determine
--   whether delay patterns warrant formal corrective action requests.
-- =============================================================================

SELECT
    -- Delay reason hierarchy
    f.delay_reason_code,
    ISNULL(f.delay_reason_desc,
        CASE f.delay_reason_code
            WHEN 'WX'  THEN 'Weather Related'
            WHEN 'TRF' THEN 'Traffic / Congestion'
            WHEN 'CUS' THEN 'Customs / Border Delay'
            WHEN 'DOC' THEN 'Documentation Error'
            WHEN 'SUP' THEN 'Supplier Late Handover'
            WHEN 'CAR' THEN 'Carrier Failure'
            WHEN 'OPS' THEN 'Operational / Warehouse Delay'
            WHEN 'DEM' THEN 'Port Congestion / Demurrage'
            ELSE 'Other / Unclassified'
        END
    )                                                               AS delay_reason_category,

    s.supplier_id,
    s.supplier_name,
    s.country                                                       AS supplier_country,
    f.transport_mode,
    f.carrier_name,

    -- Delay frequency
    COUNT(f.shipment_id)                                            AS delayed_shipments,
    ROUND(
        100.0 * COUNT(f.shipment_id)
              / SUM(COUNT(f.shipment_id)) OVER (PARTITION BY f.delay_reason_code),
        1
    )                                                               AS pct_of_reason_category,

    -- Delay duration
    ROUND(AVG(CAST(f.delay_days AS FLOAT)), 1)                      AS avg_delay_days,
    MIN(f.delay_days)                                               AS min_delay_days,
    MAX(f.delay_days)                                               AS max_delay_days,
    SUM(f.delay_days)                                               AS total_delay_days,

    -- Cost impact
    ROUND(SUM(ISNULL(f.total_logistics_cost_usd, 0)), 2)            AS freight_cost_on_delayed_shipments,
    ROUND(AVG(ISNULL(f.cost_per_unit_usd, 0)), 4)                   AS avg_unit_freight_cost,

    -- Controllability classification
    CASE f.delay_reason_code
        WHEN 'WX'  THEN 'External - Uncontrollable'
        WHEN 'TRF' THEN 'External - Partially Controllable (routing)'
        WHEN 'CUS' THEN 'Partially Controllable (documentation)'
        WHEN 'DOC' THEN 'Internal/Supplier - Controllable'
        WHEN 'SUP' THEN 'Supplier - Controllable (SCA required)'
        WHEN 'CAR' THEN 'Carrier - Controllable (penalty clause)'
        WHEN 'OPS' THEN 'Internal - Controllable'
        ELSE 'Unknown - Classify for Action'
    END                                                             AS controllability

FROM fact_shipments     f
JOIN dim_supplier       s ON f.supplier_key = s.supplier_key
JOIN dim_date           d ON f.ship_date_key = d.date_key

WHERE
    f.is_on_time = 0
    AND f.delay_days > 0
    AND d.year_number = YEAR(GETDATE())
    AND f.actual_delivery_date_key IS NOT NULL

GROUP BY
    f.delay_reason_code, f.delay_reason_desc,
    s.supplier_id, s.supplier_name, s.country,
    f.transport_mode, f.carrier_name

ORDER BY delayed_shipments DESC, avg_delay_days DESC;


-- =============================================================================
-- QUERY 3: On-Time Delivery % by Region and Month
-- =============================================================================
-- BUSINESS PURPOSE:
--   Trend analysis of delivery performance by geographic region over time.
--   Used to identify seasonal patterns (e.g., holiday periods, weather seasons)
--   and regional degradation that may indicate carrier capacity constraints
--   or infrastructure issues in specific corridors.
-- =============================================================================

SELECT
    dest_r.region_name                                              AS destination_region,
    dest_r.country                                                  AS destination_country,
    orig_r.continent                                                AS origin_continent,
    d.year_number,
    d.month_number,
    d.month_name_short,
    d.year_month,
    f.transport_mode,

    -- Volume
    COUNT(f.shipment_id)                                            AS total_shipments,
    COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END) AS delivered_shipments,
    COUNT(CASE WHEN f.shipment_status = 'In Transit' THEN 1 END)   AS in_transit_shipments,

    -- OTD calculation (excludes in-transit shipments)
    ROUND(
        100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0),
        1
    )                                                               AS otd_rate_pct,

    -- Early vs on-time vs late breakdown
    SUM(CASE WHEN f.delay_days < 0  THEN 1 ELSE 0 END)             AS early_deliveries,
    SUM(CASE WHEN f.delay_days = 0  THEN 1 ELSE 0 END)             AS exact_on_time,
    SUM(CASE WHEN f.delay_days BETWEEN 1 AND 2 THEN 1 ELSE 0 END)  AS late_1_2_days,
    SUM(CASE WHEN f.delay_days BETWEEN 3 AND 7 THEN 1 ELSE 0 END)  AS late_3_7_days,
    SUM(CASE WHEN f.delay_days > 7  THEN 1 ELSE 0 END)             AS late_over_7_days,

    -- Average delay for late shipments
    ROUND(AVG(CASE WHEN f.delay_days > 0 THEN CAST(f.delay_days AS FLOAT) END), 1) AS avg_days_late,

    -- Month-over-month OTD change (window function)
    ROUND(
        100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0)
        -
        LAG(
            100.0 * SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 END), 0)
        ) OVER (
            PARTITION BY dest_r.region_name, dest_r.country, f.transport_mode
            ORDER BY d.year_number, d.month_number
        ),
        1
    )                                                               AS mom_otd_change_ppts   -- Points change vs prior month

FROM fact_shipments     f
JOIN dim_date           d     ON f.ship_date_key       = d.date_key
LEFT JOIN dim_region    dest_r ON f.dest_region_key   = dest_r.region_key
LEFT JOIN dim_region    orig_r ON f.origin_region_key = orig_r.region_key

WHERE
    d.year_number >= YEAR(GETDATE()) - 1   -- 2-year rolling trend
    AND f.shipment_status IN ('Delivered', 'In Transit')

GROUP BY
    dest_r.region_name, dest_r.country, orig_r.continent,
    d.year_number, d.month_number, d.month_name_short, d.year_month,
    f.transport_mode

HAVING COUNT(f.shipment_id) >= 3

ORDER BY
    d.year_number, d.month_number,
    dest_r.region_name;


-- =============================================================================
-- QUERY 4: Fuel Cost Trends
-- =============================================================================
-- BUSINESS PURPOSE:
--   Fuel surcharges are a major variable component of freight cost, typically
--   indexed to diesel or jet fuel prices. This analysis tracks fuel cost trends
--   to forecast future logistics spend and assess whether carriers' surcharge
--   rates are aligned with market fuel indices.
--
--   High fuel surcharge % may indicate an opportunity to renegotiate fuel
--   surcharge tables or lock in rates via fixed-rate contracts.
-- =============================================================================

SELECT
    d.year_number,
    d.month_number,
    d.month_name_short,
    d.year_month,
    f.transport_mode,

    -- Shipment volumes
    COUNT(f.shipment_id)                                            AS shipment_count,
    ROUND(SUM(ISNULL(f.gross_weight_kg, 0)) / 1000, 1)             AS total_weight_tonnes,

    -- Cost components
    ROUND(SUM(ISNULL(f.freight_cost_usd, 0)), 0)                    AS base_freight_cost_usd,
    ROUND(SUM(ISNULL(f.fuel_surcharge_usd, 0)), 0)                  AS fuel_surcharge_usd,
    ROUND(SUM(ISNULL(f.total_logistics_cost_usd, 0)), 0)            AS total_logistics_cost_usd,

    -- Fuel surcharge rates
    ROUND(
        100.0 * SUM(ISNULL(f.fuel_surcharge_usd, 0))
              / NULLIF(SUM(ISNULL(f.freight_cost_usd, 0)), 0),
        2
    )                                                               AS fuel_surcharge_pct,

    ROUND(
        SUM(ISNULL(f.fuel_surcharge_usd, 0))
        / NULLIF(SUM(ISNULL(f.gross_weight_kg, 0)), 0) * 1000,
        4
    )                                                               AS fuel_cost_per_tonne_usd,

    -- Month-over-month fuel surcharge % change
    ROUND(
        100.0 * SUM(ISNULL(f.fuel_surcharge_usd, 0))
              / NULLIF(SUM(ISNULL(f.freight_cost_usd, 0)), 0)
        - LAG(
            100.0 * SUM(ISNULL(f.fuel_surcharge_usd, 0))
                  / NULLIF(SUM(ISNULL(f.freight_cost_usd, 0)), 0)
          ) OVER (PARTITION BY f.transport_mode ORDER BY d.year_number, d.month_number),
        2
    )                                                               AS mom_surcharge_pct_change,

    -- Year-over-year fuel cost comparison
    ROUND(
        SUM(ISNULL(f.fuel_surcharge_usd, 0))
        - LAG(SUM(ISNULL(f.fuel_surcharge_usd, 0)), 12)
          OVER (PARTITION BY f.transport_mode ORDER BY d.year_number, d.month_number),
        0
    )                                                               AS yoy_fuel_cost_change_usd

FROM fact_shipments     f
JOIN dim_date           d ON f.ship_date_key = d.date_key

WHERE
    d.year_number >= YEAR(GETDATE()) - 2   -- 3-year trend for seasonality
    AND f.shipment_status IN ('Delivered', 'In Transit')
    AND f.freight_cost_usd IS NOT NULL

GROUP BY
    d.year_number, d.month_number, d.month_name_short, d.year_month,
    f.transport_mode

ORDER BY
    f.transport_mode, d.year_number, d.month_number;


-- =============================================================================
-- QUERY 5: Most Delayed Routes
-- =============================================================================
-- BUSINESS PURPOSE:
--   Identifies the specific origin-destination route and carrier combinations
--   with the worst on-time performance. Enables surgical intervention:
--   route redesign, carrier switch, or buffer stock increase for specific lanes.
--
--   "Problem lanes" are defined as routes with >= 10 shipments and OTD < 85%.
-- =============================================================================

WITH route_performance AS (
    SELECT
        ISNULL(orig_r.region_name, 'Direct')                        AS origin_region,
        ISNULL(orig_r.country, s.country)                           AS origin_country,
        ISNULL(dest_r.region_name, 'Unknown')                       AS dest_region,
        ISNULL(dest_r.country, 'Unknown')                           AS dest_country,
        f.transport_mode,
        f.carrier_name,
        f.service_level,

        COUNT(f.shipment_id)                                        AS total_shipments,
        SUM(CASE WHEN f.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END) AS delivered_count,
        SUM(CASE WHEN f.is_on_time = 1 THEN 1 ELSE 0 END)          AS on_time_count,
        SUM(CASE WHEN f.is_on_time = 0 AND f.actual_delivery_date_key IS NOT NULL THEN 1 ELSE 0 END) AS late_count,

        ROUND(AVG(CAST(f.delay_days AS FLOAT)), 1)                  AS avg_delay_days_all,
        ROUND(AVG(CASE WHEN f.delay_days > 0 THEN CAST(f.delay_days AS FLOAT) END), 1) AS avg_delay_days_when_late,
        MAX(f.delay_days)                                           AS worst_delay_days,
        SUM(CASE WHEN f.delay_days > 7 THEN 1 ELSE 0 END)          AS severe_delays_over_7d,

        ROUND(AVG(CAST(f.actual_transit_days AS FLOAT)), 1)         AS avg_transit_days,
        ROUND(AVG(CAST(f.planned_transit_days AS FLOAT)), 1)        AS avg_planned_transit_days,
        ROUND(SUM(ISNULL(f.total_logistics_cost_usd, 0)), 0)        AS total_freight_spend_usd

    FROM fact_shipments     f
    JOIN dim_supplier       s     ON f.supplier_key        = s.supplier_key
    LEFT JOIN dim_region    orig_r ON f.origin_region_key = orig_r.region_key
    LEFT JOIN dim_region    dest_r ON f.dest_region_key   = dest_r.region_key
    JOIN dim_date           d      ON f.ship_date_key     = d.date_key
    WHERE
        d.year_number = YEAR(GETDATE())
        AND f.shipment_status IN ('Delivered', 'In Transit')
    GROUP BY
        orig_r.region_name, orig_r.country, s.country,
        dest_r.region_name, dest_r.country,
        f.transport_mode, f.carrier_name, f.service_level
    HAVING COUNT(f.shipment_id) >= 10
)
SELECT
    rp.*,

    -- OTD rate for this lane
    ROUND(
        100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0),
        1
    )                                                               AS otd_rate_pct,

    -- Delay rate
    ROUND(
        100.0 * rp.late_count / NULLIF(rp.delivered_count, 0),
        1
    )                                                               AS delay_rate_pct,

    -- Rank within transport mode (1 = worst OTD)
    RANK() OVER (
        PARTITION BY rp.transport_mode
        ORDER BY ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) ASC
    )                                                               AS mode_delay_rank,

    -- Problem lane flag
    CASE
        WHEN ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) < 70
        THEN 'CRITICAL LANE - Immediate Intervention'
        WHEN ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) < 85
        THEN 'PROBLEM LANE - Corrective Action'
        WHEN ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) < 95
        THEN 'WATCH LANE - Monitor Closely'
        ELSE 'PERFORMING - Standard Monitoring'
    END                                                             AS lane_status

FROM route_performance rp

WHERE
    ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) < 95   -- Focus on underperforming lanes

ORDER BY
    ROUND(100.0 * rp.on_time_count / NULLIF(rp.delivered_count, 0), 1) ASC,
    rp.total_freight_spend_usd DESC;


-- =============================================================================
-- END OF FILE: 03_logistics_transportation_analysis.sql
-- =============================================================================
