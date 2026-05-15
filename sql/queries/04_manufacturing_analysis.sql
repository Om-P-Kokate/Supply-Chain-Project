-- =============================================================================
-- FILE: 04_manufacturing_analysis.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Manufacturing plant efficiency, OEE, downtime, and quality analysis
--
-- BUSINESS CONTEXT:
--   Manufacturing efficiency directly drives unit cost, delivery schedules, and
--   product quality. In automotive assembly, an unplanned stoppage of even one
--   hour can cost $15,000-$50,000 in lost production, idle labor, and expedite
--   costs. Every percentage point improvement in OEE translates to additional
--   vehicle throughput without capital investment.
--
--   These queries support the Daily Manufacturing Review, weekly Plant Manager
--   meetings, and monthly Operations Performance Reporting to the C-suite.
--
-- KEY METRICS:
--   OEE (Overall Equipment Effectiveness) = Availability x Performance x Quality
--     - Availability: % of planned time the line was actually running
--     - Performance:  Actual output vs. theoretical maximum at ideal cycle rate
--     - Quality:      % of output meeting spec on first pass (FPY)
--   World-class OEE benchmark: >= 85%
--   Automotive industry average: ~60-65%
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   [PostgreSQL]: GETDATE() -> CURRENT_DATE, ISNULL() -> COALESCE(),
--                 TOP N -> LIMIT N
-- =============================================================================


-- =============================================================================
-- QUERY 1: Plant Utilization Rates
-- =============================================================================
-- BUSINESS PURPOSE:
--   Plant utilization measures how much of the available (planned) production
--   capacity is being actively used. Low utilization may signal demand weakness
--   or scheduling inefficiency. High utilization (>95%) risks quality issues
--   and leaves no capacity buffer for unplanned demand spikes.
--
--   Formula: Utilization = (Actual Production Time / Planned Production Time) * 100
--   This differs from OEE by focusing purely on time use, not performance/quality.
-- =============================================================================

SELECT
    pl.plant_id,
    pl.plant_name,
    pl.plant_type,
    pl.country,
    pl.region,
    pl.annual_capacity_units,
    pl.num_shifts,
    pl.num_production_lines,

    -- Date range for context
    MIN(d.full_date)                                                AS analysis_start_date,
    MAX(d.full_date)                                                AS analysis_end_date,
    COUNT(DISTINCT d.full_date)                                     AS production_days,

    -- Time measures (hours for readability)
    ROUND(SUM(fp.planned_production_time_min) / 60.0, 1)           AS total_planned_hours,
    ROUND(SUM(fp.actual_production_time_min)  / 60.0, 1)           AS total_actual_production_hours,
    ROUND(SUM(fp.downtime_total_min)          / 60.0, 1)           AS total_downtime_hours,
    ROUND(SUM(fp.downtime_planned_min)        / 60.0, 1)           AS planned_downtime_hours,
    ROUND(SUM(fp.downtime_unplanned_min)      / 60.0, 1)           AS unplanned_downtime_hours,
    ROUND(SUM(fp.setup_time_min)              / 60.0, 1)           AS total_setup_hours,

    -- Utilization rate
    ROUND(
        100.0 * SUM(fp.actual_production_time_min)
              / NULLIF(SUM(fp.planned_production_time_min), 0),
        1
    )                                                               AS utilization_rate_pct,

    -- Unplanned downtime %
    ROUND(
        100.0 * SUM(fp.downtime_unplanned_min)
              / NULLIF(SUM(fp.planned_production_time_min), 0),
        1
    )                                                               AS unplanned_downtime_pct,

    -- Output metrics
    SUM(fp.planned_output_units)                                    AS total_planned_units,
    SUM(fp.actual_output_units)                                     AS total_actual_units,
    SUM(fp.good_units)                                              AS total_good_units,
    SUM(fp.defective_units)                                         AS total_defective_units,
    SUM(fp.scrap_units)                                             AS total_scrap_units,

    -- Volume achievement rate
    ROUND(
        100.0 * SUM(fp.actual_output_units)
              / NULLIF(SUM(fp.planned_output_units), 0),
        1
    )                                                               AS volume_achievement_pct,

    -- Utilization performance band
    CASE
        WHEN 100.0 * SUM(fp.actual_production_time_min)
                   / NULLIF(SUM(fp.planned_production_time_min), 0) >= 95
        THEN 'High Utilization - Monitor for quality risk'
        WHEN 100.0 * SUM(fp.actual_production_time_min)
                   / NULLIF(SUM(fp.planned_production_time_min), 0) >= 80
        THEN 'Good Utilization'
        WHEN 100.0 * SUM(fp.actual_production_time_min)
                   / NULLIF(SUM(fp.planned_production_time_min), 0) >= 65
        THEN 'Moderate - Review scheduling efficiency'
        ELSE 'Low Utilization - Investigate demand/scheduling'
    END                                                             AS utilization_band,

    -- Energy metrics (cost per produced unit)
    ROUND(SUM(ISNULL(fp.energy_consumption_kwh, 0)), 0)             AS total_energy_kwh,
    ROUND(
        SUM(ISNULL(fp.energy_cost_usd, 0))
        / NULLIF(SUM(fp.good_units), 0),
        4
    )                                                               AS energy_cost_per_good_unit_usd

FROM fact_production    fp
JOIN dim_plant          pl ON fp.plant_key = pl.plant_key
JOIN dim_date           d  ON fp.production_date_key = d.date_key

WHERE
    d.year_number = YEAR(GETDATE())
    AND pl.is_active = 1

GROUP BY
    pl.plant_id, pl.plant_name, pl.plant_type,
    pl.country, pl.region, pl.annual_capacity_units,
    pl.num_shifts, pl.num_production_lines

ORDER BY utilization_rate_pct DESC;


-- =============================================================================
-- QUERY 2: Downtime Analysis by Reason and Plant
-- =============================================================================
-- BUSINESS PURPOSE:
--   Pareto analysis of downtime causes to direct maintenance investment.
--   Unplanned downtime is the highest-priority target for the Lean/CI team.
--   The 80/20 rule typically applies: ~20% of failure causes account for ~80%
--   of total downtime. Fixing the top 3-4 causes yields the most improvement.
--
--   Output feeds the CAPA (Corrective and Preventive Action) log and drives
--   predictive maintenance investment decisions.
-- =============================================================================

WITH plant_downtime_detail AS (
    SELECT
        fp.plant_key,
        fp.downtime_reason_code,
        fp.downtime_reason_desc,
        d.year_number,
        d.month_number,
        d.year_month,
        SUM(fp.downtime_unplanned_min)                              AS unplanned_downtime_min,
        SUM(fp.downtime_planned_min)                                AS planned_downtime_min,
        SUM(fp.downtime_total_min)                                  AS total_downtime_min,
        COUNT(fp.production_id)                                     AS incident_count,
        -- Approximate production value lost (good units * cost per unit)
        SUM(
            (fp.planned_output_units - fp.actual_output_units)
            * ISNULL(fp.cost_per_unit_usd, 0)
        )                                                           AS estimated_lost_production_value_usd
    FROM fact_production fp
    JOIN dim_date        d ON fp.production_date_key = d.date_key
    WHERE d.year_number = YEAR(GETDATE())
    GROUP BY
        fp.plant_key, fp.downtime_reason_code, fp.downtime_reason_desc,
        d.year_number, d.month_number, d.year_month
),
plant_totals AS (
    SELECT
        plant_key,
        SUM(unplanned_downtime_min)                                 AS plant_total_unplanned_min
    FROM plant_downtime_detail
    GROUP BY plant_key
)
SELECT
    pl.plant_id,
    pl.plant_name,
    pl.plant_type,
    pl.country,

    dd.downtime_reason_code,
    ISNULL(dd.downtime_reason_desc,
        CASE dd.downtime_reason_code
            WHEN 'MAINT'   THEN 'Mechanical / Equipment Failure'
            WHEN 'SUPPLY'  THEN 'Material / Parts Shortage'
            WHEN 'QUALITY' THEN 'Quality Hold / Rework'
            WHEN 'UTIL'    THEN 'Utility Failure (Power/Water/Air)'
            WHEN 'LABOR'   THEN 'Labor Shortage / Absenteeism'
            WHEN 'CHANGE'  THEN 'Model/Tool Changeover Overrun'
            WHEN 'SAFETY'  THEN 'Safety Incident / Near Miss'
            WHEN 'IT'      THEN 'IT / System Downtime'
            ELSE 'Other / Uncategorized'
        END
    )                                                               AS downtime_reason,

    -- Downtime volumes
    ROUND(SUM(dd.unplanned_downtime_min) / 60.0, 1)                AS total_unplanned_hours,
    ROUND(SUM(dd.planned_downtime_min)   / 60.0, 1)                AS total_planned_hours,
    SUM(dd.incident_count)                                          AS total_incidents,
    ROUND(AVG(CAST(dd.unplanned_downtime_min AS FLOAT)) / 60.0, 2) AS avg_hours_per_incident,
    ROUND(MAX(dd.unplanned_downtime_min) / 60.0, 1)                AS worst_single_incident_hours,

    -- Pareto % (% of plant's total unplanned downtime)
    ROUND(
        100.0 * SUM(dd.unplanned_downtime_min)
              / NULLIF(MAX(pt.plant_total_unplanned_min), 0),
        1
    )                                                               AS pct_of_plant_downtime,

    -- Cumulative % (for Pareto chart)
    ROUND(
        SUM(SUM(dd.unplanned_downtime_min)) OVER (
            PARTITION BY dd.plant_key
            ORDER BY SUM(dd.unplanned_downtime_min) DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / NULLIF(MAX(pt.plant_total_unplanned_min), 0),
        1
    )                                                               AS cumulative_pct_of_plant_downtime,

    -- Financial impact
    ROUND(SUM(dd.estimated_lost_production_value_usd), 0)          AS estimated_lost_value_usd,

    -- Monthly trend: hours in most recent full month
    ROUND(
        SUM(CASE WHEN dd.month_number = MONTH(GETDATE()) - 1
                 THEN dd.unplanned_downtime_min ELSE 0 END) / 60.0,
        1
    )                                                               AS prior_month_hours

FROM plant_downtime_detail  dd
JOIN plant_totals            pt ON dd.plant_key = pt.plant_key
JOIN dim_plant               pl ON dd.plant_key = pl.plant_key

WHERE dd.unplanned_downtime_min > 0

GROUP BY
    pl.plant_id, pl.plant_name, pl.plant_type, pl.country,
    dd.downtime_reason_code, dd.downtime_reason_desc, dd.plant_key

ORDER BY
    pl.plant_id,
    SUM(dd.unplanned_downtime_min) DESC;


-- =============================================================================
-- QUERY 3: Defect Rate Trends (First Pass Yield)
-- =============================================================================
-- BUSINESS PURPOSE:
--   First Pass Yield (FPY) measures the percentage of units produced correctly
--   without any rework or scrap. Low FPY increases true unit cost significantly
--   because rework consumes labor, materials, and time.
--
--   True Cost = (direct material + labor + overhead) / FPY
--   Example: If FPY = 90%, a $100 standard cost part actually costs $111 to produce.
--
--   Monthly trend used in the Quality Review Board meeting and to set
--   corrective action priorities with the engineering team.
-- =============================================================================

SELECT
    pl.plant_id,
    pl.plant_name,
    pl.plant_type,
    d.year_number,
    d.month_number,
    d.month_name_short,
    d.year_month,
    p.product_category,

    -- Output volumes
    SUM(fp.actual_output_units)                                     AS total_output_units,
    SUM(fp.good_units)                                              AS good_units,
    SUM(fp.defective_units)                                         AS defective_units,
    SUM(fp.rework_units)                                            AS rework_units,
    SUM(fp.scrap_units)                                             AS scrap_units,

    -- First Pass Yield (FPY) = good units / total output (excludes rework success)
    ROUND(
        100.0 * SUM(fp.good_units)
              / NULLIF(SUM(fp.actual_output_units), 0),
        2
    )                                                               AS first_pass_yield_pct,

    -- Defect rate
    ROUND(
        100.0 * SUM(fp.defective_units)
              / NULLIF(SUM(fp.actual_output_units), 0),
        2
    )                                                               AS defect_rate_pct,

    -- Scrap rate (unrecoverable)
    ROUND(
        100.0 * SUM(fp.scrap_units)
              / NULLIF(SUM(fp.actual_output_units), 0),
        2
    )                                                               AS scrap_rate_pct,

    -- Financial cost of quality
    ROUND(SUM(fp.scrap_units * ISNULL(fp.cost_per_unit_usd, 0)), 0) AS scrap_cost_usd,
    ROUND(
        SUM(fp.rework_units * ISNULL(fp.cost_per_unit_usd, 0)) * 0.15,
        0
    )                                                               AS estimated_rework_cost_usd,  -- 15% of unit cost estimate

    -- Month-over-month FPY change (window function)
    ROUND(
        100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0)
        - LAG(
            100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0)
          ) OVER (
            PARTITION BY pl.plant_id, p.product_category
            ORDER BY d.year_number, d.month_number
          ),
        2
    )                                                               AS mom_fpy_change_ppts,

    -- Quality performance classification
    CASE
        WHEN 100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0) >= 99
        THEN 'Excellent (>=99% FPY)'
        WHEN 100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0) >= 97
        THEN 'Good (97-99% FPY)'
        WHEN 100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0) >= 95
        THEN 'Acceptable (95-97% FPY)'
        WHEN 100.0 * SUM(fp.good_units) / NULLIF(SUM(fp.actual_output_units), 0) >= 90
        THEN 'Below Target (<95% FPY) - Action Required'
        ELSE 'Critical (<90% FPY) - Immediate Containment'
    END                                                             AS quality_classification

FROM fact_production    fp
JOIN dim_plant          pl ON fp.plant_key   = pl.plant_key
JOIN dim_product        p  ON fp.product_key = p.product_key
JOIN dim_date           d  ON fp.production_date_key = d.date_key

WHERE
    d.year_number >= YEAR(GETDATE()) - 1   -- Rolling 2-year trend

GROUP BY
    pl.plant_id, pl.plant_name, pl.plant_type,
    d.year_number, d.month_number, d.month_name_short, d.year_month,
    p.product_category

HAVING SUM(fp.actual_output_units) > 0

ORDER BY
    pl.plant_id, d.year_number, d.month_number, p.product_category;


-- =============================================================================
-- QUERY 4: Production Efficiency Comparison (Plant vs Plant)
-- =============================================================================
-- BUSINESS PURPOSE:
--   Benchmarks production efficiency across plants producing similar products.
--   Best-practice sharing: underperforming plants adopt methods from leaders.
--   Also used to determine optimal production allocation when demand shifts.
-- =============================================================================

SELECT
    pl.plant_id,
    pl.plant_name,
    pl.plant_type,
    pl.country,
    pl.region,
    pl.num_shifts,
    pl.num_production_lines,
    pl.annual_capacity_units,

    -- Production volume metrics
    SUM(fp.good_units)                                              AS ytd_good_units,
    ROUND(SUM(fp.good_units) / NULLIF(pl.annual_capacity_units, 0) * 100, 1) AS capacity_utilization_pct,

    -- Efficiency: good units per planned hour
    ROUND(
        SUM(fp.good_units)
        / NULLIF(SUM(fp.planned_production_time_min) / 60.0, 0),
        2
    )                                                               AS good_units_per_planned_hour,

    -- Same metric normalized by number of lines (apples-to-apples comparison)
    ROUND(
        SUM(fp.good_units)
        / NULLIF(SUM(fp.planned_production_time_min) / 60.0, 0)
        / NULLIF(pl.num_production_lines, 0),
        2
    )                                                               AS good_units_per_line_per_hour,

    -- OEE components (production-weighted average)
    ROUND(AVG(ISNULL(fp.availability_rate, 0)) * 100, 1)           AS avg_availability_pct,
    ROUND(AVG(ISNULL(fp.performance_rate, 0))  * 100, 1)           AS avg_performance_pct,
    ROUND(AVG(ISNULL(fp.quality_rate, 0))      * 100, 1)           AS avg_quality_pct,
    ROUND(AVG(ISNULL(fp.oee_rate, 0))          * 100, 1)           AS avg_oee_pct,

    -- Unit cost efficiency
    ROUND(AVG(ISNULL(fp.cost_per_unit_usd, 0)), 4)                  AS avg_cost_per_unit_usd,
    ROUND(
        AVG(ISNULL(fp.cost_per_unit_usd, 0))
        / NULLIF(
            AVG(AVG(ISNULL(fp.cost_per_unit_usd, 0))) OVER (), 0
          ) * 100,
        1
    )                                                               AS cost_index_vs_fleet_avg,   -- 100 = average; <100 = below avg cost = good

    -- Downtime
    ROUND(SUM(fp.downtime_unplanned_min) / 60.0, 0)                AS ytd_unplanned_downtime_hours,
    ROUND(
        100.0 * SUM(fp.downtime_unplanned_min)
              / NULLIF(SUM(fp.planned_production_time_min), 0),
        1
    )                                                               AS unplanned_downtime_pct,

    -- Rank plants by OEE (1 = best)
    RANK() OVER (ORDER BY AVG(ISNULL(fp.oee_rate, 0)) DESC)        AS oee_rank,
    RANK() OVER (ORDER BY AVG(ISNULL(fp.cost_per_unit_usd, 0)) ASC) AS cost_efficiency_rank

FROM fact_production    fp
JOIN dim_plant          pl ON fp.plant_key = pl.plant_key
JOIN dim_date           d  ON fp.production_date_key = d.date_key

WHERE
    d.year_number = YEAR(GETDATE())
    AND pl.is_active = 1

GROUP BY
    pl.plant_id, pl.plant_name, pl.plant_type,
    pl.country, pl.region, pl.num_shifts,
    pl.num_production_lines, pl.annual_capacity_units

ORDER BY avg_oee_pct DESC;


-- =============================================================================
-- QUERY 5: OEE (Overall Equipment Effectiveness) Calculation
-- =============================================================================
-- BUSINESS PURPOSE:
--   OEE is the gold standard metric for manufacturing productivity.
--   It combines three dimensions into a single measure:
--
--   AVAILABILITY = (Planned Time - Unplanned Downtime) / Planned Time
--     "Was the machine running when it should be?"
--
--   PERFORMANCE = Actual Output / (Running Time * Ideal Cycle Rate)
--     "When running, was it running at the right speed?"
--
--   QUALITY = Good Units / Total Units Produced
--     "When producing, was it producing good parts?"
--
--   OEE = Availability * Performance * Quality
--     World class: 85%+  |  Industry average: 60-65%
--
--   This detailed query shows daily OEE trends and all three components
--   for root cause analysis and target setting.
-- =============================================================================

WITH oee_calc AS (
    SELECT
        fp.plant_key,
        fp.production_line_id,
        fp.shift_number,
        fp.production_date_key,
        d.year_month,
        d.year_number,
        d.month_number,
        d.week_of_year,
        d.full_date,

        -- Raw time inputs (minutes)
        fp.planned_production_time_min,
        fp.downtime_unplanned_min,
        fp.actual_production_time_min,
        fp.ideal_cycle_time_sec,

        -- AVAILABILITY: time the line was available vs planned
        CASE
            WHEN fp.planned_production_time_min > 0
            THEN CAST(fp.planned_production_time_min - fp.downtime_unplanned_min AS FLOAT)
                 / fp.planned_production_time_min
            ELSE NULL
        END                                                         AS availability,

        -- PERFORMANCE: actual vs maximum theoretical output
        -- Max theoretical output = running time / ideal cycle time
        CASE
            WHEN fp.actual_production_time_min > 0
                 AND fp.ideal_cycle_time_sec > 0
            THEN CAST(fp.actual_output_units AS FLOAT)
                 / ((fp.actual_production_time_min * 60.0) / fp.ideal_cycle_time_sec)
            ELSE fp.performance_rate   -- Fall back to pre-calculated if inputs not available
        END                                                         AS performance,

        -- QUALITY: good units as fraction of all units produced
        CASE
            WHEN fp.actual_output_units > 0
            THEN CAST(fp.good_units AS FLOAT) / fp.actual_output_units
            ELSE NULL
        END                                                         AS quality,

        -- Pre-calculated OEE from ETL (for comparison / fallback)
        fp.oee_rate                                                 AS oee_precalc,
        fp.availability_rate,
        fp.performance_rate,
        fp.quality_rate,

        fp.planned_output_units,
        fp.actual_output_units,
        fp.good_units,
        fp.defective_units,
        fp.scrap_units,
        fp.downtime_reason_code,
        fp.total_production_cost_usd,
        fp.cost_per_unit_usd

    FROM fact_production fp
    JOIN dim_date d ON fp.production_date_key = d.date_key
    WHERE d.year_number >= YEAR(GETDATE()) - 1
)
SELECT
    pl.plant_id,
    pl.plant_name,
    pl.plant_type,
    oc.production_line_id,
    oc.shift_number,
    oc.full_date                                                    AS production_date,
    oc.year_month,
    oc.week_of_year,

    -- OEE components (calculated in this query)
    ROUND(ISNULL(oc.availability, oc.availability_rate) * 100, 2)  AS availability_pct,
    ROUND(
        LEAST(1.0, ISNULL(oc.performance, oc.performance_rate)) * 100,  -- Cap at 100%
        2
    )                                                               AS performance_pct,
    ROUND(ISNULL(oc.quality, oc.quality_rate) * 100, 2)            AS quality_pct,

    -- OEE = A * P * Q (computed; capped at 100%)
    ROUND(
        LEAST(1.0,
            ISNULL(oc.availability, oc.availability_rate)
            * LEAST(1.0, ISNULL(oc.performance, oc.performance_rate))
            * ISNULL(oc.quality, oc.quality_rate)
        ) * 100,
        2
    )                                                               AS oee_pct,

    -- OEE benchmark gap
    ROUND(
        85.0 - LEAST(1.0,
            ISNULL(oc.availability, oc.availability_rate)
            * LEAST(1.0, ISNULL(oc.performance, oc.performance_rate))
            * ISNULL(oc.quality, oc.quality_rate)
        ) * 100,
        2
    )                                                               AS oee_gap_to_world_class,  -- Negative = already world class

    -- Which OEE component is the biggest drag?
    CASE
        WHEN ISNULL(oc.availability, oc.availability_rate)
             <= LEAST(ISNULL(oc.performance, oc.performance_rate),
                      ISNULL(oc.quality, oc.quality_rate))
        THEN 'Availability is biggest OEE drag - focus on unplanned downtime'
        WHEN ISNULL(oc.performance, oc.performance_rate)
             <= LEAST(ISNULL(oc.availability, oc.availability_rate),
                      ISNULL(oc.quality, oc.quality_rate))
        THEN 'Performance is biggest OEE drag - focus on cycle time and speed losses'
        ELSE 'Quality is biggest OEE drag - focus on defect root causes'
    END                                                             AS primary_oee_constraint,

    -- Output and cost
    oc.planned_output_units,
    oc.actual_output_units,
    oc.good_units,
    oc.defective_units,
    oc.scrap_units,
    ROUND(oc.cost_per_unit_usd, 4)                                  AS cost_per_good_unit_usd,

    -- Rolling 30-day average OEE for trend context
    ROUND(
        AVG(
            LEAST(1.0,
                ISNULL(oc.availability, oc.availability_rate)
                * LEAST(1.0, ISNULL(oc.performance, oc.performance_rate))
                * ISNULL(oc.quality, oc.quality_rate)
            )
        ) OVER (
            PARTITION BY pl.plant_id, oc.production_line_id
            ORDER BY oc.full_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) * 100,
        2
    )                                                               AS rolling_30d_avg_oee_pct

FROM oee_calc       oc
JOIN dim_plant      pl ON oc.plant_key = pl.plant_key

ORDER BY
    pl.plant_id, oc.production_line_id, oc.full_date, oc.shift_number;


-- =============================================================================
-- QUERY 5b: OEE Monthly Summary by Plant
-- =============================================================================

SELECT
    pl.plant_id,
    pl.plant_name,
    d.year_month,
    ROUND(AVG(ISNULL(fp.availability_rate, 0)) * 100, 1)           AS avg_availability_pct,
    ROUND(AVG(LEAST(1.0, ISNULL(fp.performance_rate, 0))) * 100, 1) AS avg_performance_pct,
    ROUND(AVG(ISNULL(fp.quality_rate, 0)) * 100, 1)                AS avg_quality_pct,
    ROUND(AVG(ISNULL(fp.oee_rate, 0)) * 100, 1)                    AS avg_oee_pct,
    SUM(fp.good_units)                                              AS total_good_units,
    SUM(fp.scrap_units)                                             AS total_scrap_units,
    ROUND(SUM(fp.downtime_unplanned_min) / 60.0, 1)                AS total_unplanned_downtime_hrs,
    -- OEE gap from 85% world-class benchmark
    ROUND(85.0 - AVG(ISNULL(fp.oee_rate, 0)) * 100, 1)             AS oee_gap_ppts

FROM fact_production    fp
JOIN dim_plant          pl ON fp.plant_key = pl.plant_key
JOIN dim_date           d  ON fp.production_date_key = d.date_key
WHERE d.year_number >= YEAR(GETDATE()) - 1
GROUP BY pl.plant_id, pl.plant_name, d.year_month
ORDER BY pl.plant_id, d.year_month;


-- =============================================================================
-- END OF FILE: 04_manufacturing_analysis.sql
-- =============================================================================
