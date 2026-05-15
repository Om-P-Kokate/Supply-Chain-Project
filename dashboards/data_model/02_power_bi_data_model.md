# Power BI Data Model Documentation
# Automotive Supply Chain Analytics

**File:** `02_power_bi_data_model.md`
**Project:** Automotive Supply Chain Analytics
**Last Updated:** 2026-05-15
**Power BI Desktop Version:** 2.x (December 2025+)

---

## Table of Contents

1. [Data Model Overview](#1-data-model-overview)
2. [Fact Tables](#2-fact-tables)
3. [Dimension Tables](#3-dimension-tables)
4. [Relationships](#4-relationships)
5. [Calculated Columns vs Measures](#5-calculated-columns-vs-measures)
6. [Power BI Best Practices Applied](#6-power-bi-best-practices-applied)

---

## 1. Data Model Overview

### 1.1 Schema Type: Star Schema

This data model uses a **Star Schema** design: a single layer of fact tables at the center, each directly connected to denormalized dimension tables at the perimeter. There is no intermediate/bridge dimension layer (which would make it a snowflake schema).

```
                        ┌─────────────────┐
                        │   dim_date      │
                        │  (Date Dim)     │
                        └────────┬────────┘
                                 │ 1
                 ┌───────────────┼───────────────────┐
                 │               │                   │
                 │ *             │ *                 │ *
        ┌────────┴───────┐ ┌────┴──────────┐ ┌─────┴──────────┐
        │ fact_shipments │ │  fact_sales   │ │fact_production │
        └────────┬───────┘ └────┬──────────┘ └─────┬──────────┘
                 │ *            │ *                 │ *
                 │              │                   │
        ┌────────┴──────────────┼───────────────────┘
        │                      │
        │ *                    │ *
┌───────┴────────┐   ┌─────────┴──────┐   ┌────────────────┐
│  dim_supplier  │   │  dim_vehicle   │   │  dim_warehouse │
└────────────────┘   └────────────────┘   └────────────────┘

        ┌────────────────┐   ┌────────────────┐
        │   dim_region   │   │   dim_plant    │
        └────────────────┘   └────────────────┘

                    ┌──────────────────────────┐
                    │      fact_inventory      │
                    │  (warehouse-product-date)│
                    └──────────────────────────┘
```

*Note: Each `*` end of a line represents the "many" side of a one-to-many relationship.*

### 1.2 Why Star Schema Is Used in Power BI

| Reason | Explanation |
|--------|-------------|
| **DAX Performance** | DAX filter propagation is optimized for one-to-many relationships from dimension to fact. Star schema maximizes this. |
| **VertiPaq Compression** | The Power BI in-memory engine (VertiPaq) compresses dimension columns far more efficiently when they are denormalized. |
| **Simpler DAX** | With direct fact-to-dimension joins, measures like `CALCULATE(..., dim_supplier[country] = "Germany")` work without complex path traversal. |
| **Relationship Clarity** | A single relationship layer avoids ambiguous filter paths that cause incorrect DAX results in snowflake designs. |
| **Report Author Friendliness** | Business users building their own visuals face a simpler field list with one hop from dimension to fact. |

### 1.3 How Star Schema Optimizes DAX Calculations

DAX filter context flows from the **one** side (dimensions) to the **many** side (facts) through relationships. In a star schema:

- Slicers on `dim_supplier[country]` automatically filter `fact_shipments` with zero extra DAX code.
- `CALCULATE` can modify the filter context on any single dimension, and it propagates cleanly to all related facts.
- `USERELATIONSHIP` can activate role-playing dimension relationships (e.g., using `dim_date` for both order date and delivery date) without schema changes.
- Cross-highlighting between visuals works reliably because every visual ultimately resolves to the same fact table rows.

---

## 2. Fact Tables

### 2.1 fact_shipments

**Purpose:** Records every individual shipment of parts or finished vehicles from a supplier or plant to a warehouse or customer.

**Grain:** One row per shipment (unique `shipment_id`). A shipment may contain multiple line items of the same product on the same truck/vessel.

**Estimated Row Count:** 2-5 million rows per year (high-volume automotive).

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `shipment_id` | Text (PK) | Unique shipment identifier | SHP-2025-089341 |
| `supplier_id` | Text (FK) | Links to dim_supplier | SUP-DE-012 |
| `warehouse_id` | Text (FK) | Destination warehouse | WH-US-DETROIT-01 |
| `vehicle_id` | Text (FK) | Vehicle/part being shipped | VEH-F150-2025 |
| `region_id` | Text (FK) | Origin/destination region | REG-MIDWEST |
| `order_date_key` | Integer (FK) | Links to dim_date (order placed) | 20250315 |
| `delivery_date_key` | Integer (FK) | Links to dim_date (actual delivery) | 20250319 |
| `scheduled_delivery_date_key` | Integer (FK) | Links to dim_date (planned) | 20250318 |
| `units_ordered` | Integer | Number of units requested | 500 |
| `units_delivered` | Integer | Number of units actually received | 498 |
| `defect_units` | Integer | Units failing incoming inspection | 2 |
| `lead_time_days` | Integer | Days from order to delivery | 4 |
| `delay_days` | Integer | Actual - Scheduled (negative = early) | 1 |
| `transportation_cost` | Decimal | Cost in USD for this shipment | 4250.00 |
| `transport_mode` | Text | Road / Rail / Air / Sea | Road |
| `carrier_name` | Text | Logistics provider name | DHL Supply Chain |
| `shipment_weight_kg` | Decimal | Total shipment weight | 8500 |
| `load_date` | DateTime | ETL load timestamp | 2025-03-20 02:15:00 |

**Key Relationships:**
- `supplier_id` → `dim_supplier[supplier_id]` (many-to-one)
- `warehouse_id` → `dim_warehouse[warehouse_id]` (many-to-one)
- `vehicle_id` → `dim_vehicle[vehicle_id]` (many-to-one)
- `region_id` → `dim_region[region_id]` (many-to-one)
- `order_date_key` → `dim_date[date_key]` (many-to-one, **active**)
- `delivery_date_key` → `dim_date[date_key]` (many-to-one, **inactive** - use USERELATIONSHIP)
- `scheduled_delivery_date_key` → `dim_date[date_key]` (many-to-one, **inactive**)

---

### 2.2 fact_inventory

**Purpose:** Captures a daily snapshot of inventory levels at every warehouse for every product/part. Used for inventory valuation, turnover calculation, and stockout detection.

**Grain:** One row per warehouse × product × date (daily snapshot). This is a **periodic snapshot fact table**.

**Estimated Row Count:** ~500 warehouses × 2,000 SKUs × 365 days = ~365 million rows/year. Consider partitioning by year.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `inventory_snapshot_id` | Integer (PK) | Surrogate key | 8847392 |
| `warehouse_id` | Text (FK) | Links to dim_warehouse | WH-US-DETROIT-01 |
| `vehicle_id` | Text (FK) | Part or vehicle SKU | VEH-ENGINE-V8 |
| `date_key` | Integer (FK) | Snapshot date | 20250315 |
| `quantity_on_hand` | Integer | Units in stock at end of day | 1250 |
| `safety_stock_level` | Integer | Minimum required stock | 500 |
| `reorder_point` | Integer | Trigger level for replenishment | 750 |
| `max_stock_level` | Integer | Maximum storage capacity | 3000 |
| `inventory_value` | Decimal | qty_on_hand × unit_cost | 312500.00 |
| `average_daily_demand` | Decimal | Rolling 30-day average demand | 125.5 |
| `days_of_supply` | Decimal | qty_on_hand / avg_daily_demand | 9.96 |
| `receipt_units` | Integer | Units received on this day | 200 |
| `issue_units` | Integer | Units consumed/shipped on this day | 175 |
| `adjustment_units` | Integer | Cycle count adjustments | -3 |
| `load_date` | DateTime | ETL load timestamp | 2025-03-16 01:00:00 |

**Key Relationships:**
- `warehouse_id` → `dim_warehouse[warehouse_id]` (many-to-one)
- `vehicle_id` → `dim_vehicle[vehicle_id]` (many-to-one)
- `date_key` → `dim_date[date_key]` (many-to-one)

---

### 2.3 fact_sales

**Purpose:** Records completed sales transactions for finished vehicles and replacement parts. Combines actuals with forecast figures for accuracy analysis.

**Grain:** One row per sales order line (unique combination of `sales_order_id` + `line_item`).

**Estimated Row Count:** 500,000 - 2 million rows per year.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `sales_order_id` | Text (PK) | Unique order identifier | ORD-2025-041293 |
| `line_item` | Integer (PK) | Line number within order | 1 |
| `vehicle_id` | Text (FK) | Vehicle model sold | VEH-F150-2025 |
| `region_id` | Text (FK) | Sales region | REG-SOUTHEAST |
| `date_key` | Integer (FK) | Order/sale date | 20250315 |
| `units_sold` | Integer | Actual units sold | 12 |
| `units_forecasted` | Integer | Forecast for this period | 10 |
| `revenue` | Decimal | Total revenue (USD) | 528000.00 |
| `cogs` | Decimal | Cost of goods sold | 396000.00 |
| `gross_profit` | Decimal | revenue - cogs | 132000.00 |
| `discount_amount` | Decimal | Discounts applied | 15000.00 |
| `channel` | Text | Dealer / Fleet / Direct | Dealer |
| `customer_segment` | Text | Consumer / Commercial / Government | Commercial |
| `load_date` | DateTime | ETL load timestamp | 2025-03-16 03:00:00 |

**Key Relationships:**
- `vehicle_id` → `dim_vehicle[vehicle_id]` (many-to-one)
- `region_id` → `dim_region[region_id]` (many-to-one)
- `date_key` → `dim_date[date_key]` (many-to-one)

---

### 2.4 fact_production

**Purpose:** Records daily production output, quality results, and equipment performance data at each manufacturing plant.

**Grain:** One row per plant × shift × date × production line.

**Estimated Row Count:** ~50 plants × 3 shifts × 365 days × 5 lines = ~27 million rows/year.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `production_id` | Integer (PK) | Surrogate key | 7719284 |
| `plant_id` | Text (FK) | Links to dim_plant | PLT-DETROIT-01 |
| `vehicle_id` | Text (FK) | Vehicle model produced | VEH-F150-2025 |
| `date_key` | Integer (FK) | Production date | 20250315 |
| `shift` | Text | Morning / Afternoon / Night | Morning |
| `production_line` | Text | Line identifier | LINE-A3 |
| `planned_units` | Integer | Scheduled production target | 240 |
| `actual_units_produced` | Integer | Units actually completed | 228 |
| `defect_units` | Integer | Units failing final QC | 4 |
| `scrap_units` | Integer | Unrecoverable defects | 1 |
| `rework_units` | Integer | Units requiring rework | 3 |
| `available_hours` | Decimal | Scheduled production hours | 8.0 |
| `downtime_hours` | Decimal | Unplanned downtime hours | 0.75 |
| `planned_downtime_hours` | Decimal | Maintenance windows | 0.25 |
| `raw_material_cost` | Decimal | Material cost for this run | 45600.00 |
| `labor_cost` | Decimal | Direct labor cost | 9120.00 |
| `energy_cost` | Decimal | Energy consumed cost | 2280.00 |
| `downtime_reason` | Text | Equipment / Material / Staffing | Equipment |
| `load_date` | DateTime | ETL load timestamp | 2025-03-16 04:00:00 |

**Key Relationships:**
- `plant_id` → `dim_plant[plant_id]` (many-to-one)
- `vehicle_id` → `dim_vehicle[vehicle_id]` (many-to-one)
- `date_key` → `dim_date[date_key]` (many-to-one)

---

## 3. Dimension Tables

### 3.1 dim_supplier

**Purpose:** Master reference for all suppliers. Provides attributes for filtering, grouping, and scoring supplier performance.

**Row Count:** 200-500 suppliers typical for Tier 1 automotive OEM.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `supplier_id` | Text (PK) | Unique supplier identifier | SUP-DE-012 |
| `supplier_name` | Text | Legal entity name | Bosch Automotive |
| `supplier_code` | Text | Short internal code | BOSCH-DE |
| `country` | Text | Country of HQ | Germany |
| `region_id` | Text (FK) | Supplier's geographic region | REG-EUROPE-WEST |
| `tier` | Integer | Supply tier (1, 2, or 3) | 1 |
| `category` | Text | Part category supplied | Electrical Systems |
| `contract_start_date` | Date | Contract effective date | 2022-01-01 |
| `contract_end_date` | Date | Contract expiry date | 2026-12-31 |
| `sla_lead_time_days` | Integer | Contracted lead time | 5 |
| `reliability_score` | Decimal | Composite reliability (0-100) | 88.5 |
| `financial_risk_score` | Decimal | Financial stability risk (0-100) | 15.0 |
| `geopolitical_risk_score` | Decimal | Geopolitical exposure risk (0-100) | 42.0 |
| `quality_risk_score` | Decimal | Historical quality risk (0-100) | 12.0 |
| `lead_time_risk_score` | Decimal | Lead time variability risk (0-100) | 20.0 |
| `is_single_source` | Boolean | Only supplier for a part | TRUE |
| `certification` | Text | ISO/IATF certification level | IATF 16949 |
| `primary_contact` | Text | Account manager name | Hans Mueller |
| `is_active` | Boolean | Active supplier flag | TRUE |

**Key Attributes for Analysis:**
- `tier` enables Tier 1 vs Tier 2 vs Tier 3 supply risk analysis
- `is_single_source` is critical for risk reporting — single-source suppliers warrant red-flag treatment
- The four risk scores feed `[SC] Supplier Risk Index` with weighted aggregation
- `sla_lead_time_days` provides the benchmark for comparing against `[SC] Average Lead Time`

---

### 3.2 dim_date

**Purpose:** A complete date dimension spanning all dates in the data range (minimum: 5 years history + 2 years forecast). This is the single most important dimension in any Power BI model.

**Row Count:** ~2,555 rows for a 7-year span (2022-2028).

**Setup Requirement:** This table MUST be marked as a "Date Table" in Power BI (right-click table → Mark as date table → select `date` column). Without this, DATESYTD, DATESMTD, and SAMEPERIODLASTYEAR will not work correctly.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `date_key` | Integer (PK) | YYYYMMDD integer key | 20250315 |
| `date` | Date (marked as date column) | Calendar date | 2025-03-15 |
| `year` | Integer | Calendar year | 2025 |
| `quarter_number` | Integer | Quarter (1-4) | 1 |
| `quarter_label` | Text | Display label | Q1 2025 |
| `month_number` | Integer | Month (1-12) | 3 |
| `month_name` | Text | Full month name | March |
| `month_name_short` | Text | 3-letter abbreviation | Mar |
| `month_year_label` | Text | Display label | Mar 2025 |
| `week_number` | Integer | ISO week number | 11 |
| `week_start_date` | Date | Monday of this week | 2025-03-10 |
| `day_of_week_number` | Integer | 1=Monday, 7=Sunday | 6 |
| `day_of_week_name` | Text | Full day name | Saturday |
| `day_of_week_short` | Text | 3-letter abbreviation | Sat |
| `is_weekday` | Boolean | TRUE if Mon-Fri | FALSE |
| `is_weekend` | Boolean | TRUE if Sat-Sun | TRUE |
| `is_holiday` | Boolean | Public holiday flag | FALSE |
| `holiday_name` | Text | Holiday description (if applicable) | NULL |
| `fiscal_year` | Integer | Fiscal year (if different from calendar) | FY2025 |
| `fiscal_quarter` | Integer | Fiscal quarter | FQ4 |
| `fiscal_month` | Integer | Fiscal month number | 9 |
| `is_current_month` | Boolean | TRUE if current calendar month | TRUE |
| `is_current_year` | Boolean | TRUE if current calendar year | TRUE |
| `days_in_month` | Integer | Total days in this month | 31 |
| `day_of_month` | Integer | Day number within month | 15 |
| `day_of_year` | Integer | Day number within year (1-366) | 74 |
| `month_sort_order` | Integer | Sort key for chronological ordering | 20250300 |

**Why dim_date Is Critical in Power BI:**
1. **Time Intelligence Functions:** DATESYTD, DATESMTD, SAMEPERIODLASTYEAR, and DATEADD all require a properly configured date dimension marked as a Date Table.
2. **Role-Playing:** A single dim_date table serves multiple roles (order date, delivery date, snapshot date) through inactive relationships activated with USERELATIONSHIP in DAX measures.
3. **Fiscal Calendar Support:** Automotive companies often close books on non-calendar fiscal years. The `fiscal_*` columns enable correct fiscal period reporting without changing the base date.
4. **Weekend/Holiday Filtering:** Supply chain lead times are in business days. The `is_weekday` and `is_holiday` flags enable accurate business-day lead time calculations.
5. **Sort Order:** Power BI sorts text columns alphabetically by default. `month_sort_order` provides the correct chronological sort for month labels on charts.

---

### 3.3 dim_region

**Purpose:** Geographic hierarchy for supply chain origin and destination analysis. Supports regional performance comparison and logistics optimization.

**Hierarchy:** Region → Country → State/Province → City

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `region_id` | Text (PK) | Unique region identifier | REG-MIDWEST |
| `region_name` | Text | Top-level region name | Midwest |
| `macro_region` | Text | Continent-level grouping | North America |
| `country_code` | Text | ISO 3166-1 alpha-2 | US |
| `country_name` | Text | Full country name | United States |
| `state_province` | Text | State or province | Michigan |
| `state_code` | Text | State/province abbreviation | MI |
| `city` | Text | City name | Detroit |
| `city_tier` | Text | Metro classification (Tier 1/2/3) | Tier 1 |
| `latitude` | Decimal | City centroid latitude | 42.3314 |
| `longitude` | Decimal | City centroid longitude | -83.0458 |
| `time_zone` | Text | IANA time zone identifier | America/Detroit |
| `is_port_city` | Boolean | Has sea/air port access | TRUE |
| `logistics_hub_score` | Integer | Infrastructure quality (1-10) | 9 |

**Hierarchy Definition for Power BI:**
In the Power BI data model, define a hierarchy on dim_region:
- Level 1: `macro_region`
- Level 2: `country_name`
- Level 3: `state_province`
- Level 4: `city`

This enables drill-down from world region to individual city on map and bar chart visuals.

---

### 3.4 dim_vehicle

**Purpose:** Master reference for all vehicle models and parts. Provides product hierarchy for demand analysis, production planning, and inventory management.

**Hierarchy:** Vehicle Family → Model → Variant → Part

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `vehicle_id` | Text (PK) | Unique vehicle/part identifier | VEH-F150-2025-SPORT |
| `vehicle_code` | Text | Short product code | F150-25-SP |
| `vehicle_name` | Text | Full product name | F-150 Sport 2025 |
| `model_family` | Text | Parent model family | F-Series |
| `model` | Text | Specific model | F-150 |
| `variant` | Text | Trim/configuration | Sport |
| `model_year` | Integer | Model year | 2025 |
| `body_style` | Text | Pickup / SUV / Sedan / EV | Pickup |
| `drive_train` | Text | ICE / Hybrid / EV / PHEV | ICE |
| `engine_type` | Text | Engine configuration | V8 3.5L EcoBoost |
| `unit_cost` | Decimal | Standard cost per unit (USD) | 35000.00 |
| `list_price` | Decimal | MSRP / list price (USD) | 44000.00 |
| `weight_kg` | Decimal | Vehicle weight | 2100 |
| `category` | Text | Finished Vehicle / Component / Raw Material | Finished Vehicle |
| `sub_category` | Text | Part category if component | Electrical |
| `lifecycle_stage` | Text | Launch / Mature / End-of-Life | Mature |
| `launch_date` | Date | Model year production start | 2024-09-01 |
| `end_of_life_date` | Date | Last planned production date | 2026-08-31 |
| `is_active` | Boolean | Currently in production | TRUE |

**Hierarchy Definition for Power BI:**
- Level 1: `model_family`
- Level 2: `model`
- Level 3: `variant`
- Level 4: `model_year`

---

### 3.5 dim_warehouse

**Purpose:** Defines all storage and distribution locations in the supply chain network. Used for inventory analysis, capacity management, and stockout detection.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `warehouse_id` | Text (PK) | Unique warehouse identifier | WH-US-DETROIT-01 |
| `warehouse_name` | Text | Descriptive name | Detroit Central Distribution |
| `warehouse_code` | Text | Short operational code | DTW-01 |
| `region_id` | Text (FK) | Links to dim_region | REG-MIDWEST |
| `warehouse_type` | Text | Raw Material / WIP / Finished Goods / 3PL | Finished Goods |
| `owned_or_leased` | Text | Owned / Leased / 3PL Managed | Owned |
| `total_capacity_units` | Integer | Maximum storage capacity in units | 50000 |
| `total_area_sqm` | Decimal | Floor area in square meters | 25000 |
| `latitude` | Decimal | Warehouse GPS latitude | 42.3314 |
| `longitude` | Decimal | Warehouse GPS longitude | -83.0458 |
| `is_cross_dock` | Boolean | Cross-docking capability | FALSE |
| `is_refrigerated` | Boolean | Temperature-controlled | FALSE |
| `automation_level` | Text | Manual / Semi-Auto / Fully Automated | Semi-Auto |
| `manager_name` | Text | Warehouse manager | John Smith |
| `operating_hours` | Text | Operational schedule | 24/7 |
| `is_active` | Boolean | Currently operational | TRUE |

---

### 3.6 dim_plant

**Purpose:** Defines all manufacturing plant locations. Used for production performance analysis, OEE benchmarking, and capacity planning.

| Column Name | Data Type | Description | Example |
|---|---|---|---|
| `plant_id` | Text (PK) | Unique plant identifier | PLT-DETROIT-01 |
| `plant_name` | Text | Official plant name | Detroit Assembly Complex |
| `plant_code` | Text | Short operational code | DAC-01 |
| `region_id` | Text (FK) | Links to dim_region | REG-MIDWEST |
| `plant_type` | Text | Assembly / Stamping / Powertrain / Paint | Assembly |
| `capacity_units_per_day` | Integer | Daily nameplate capacity | 1000 |
| `number_of_shifts` | Integer | Operating shifts per day | 3 |
| `number_of_lines` | Integer | Production lines count | 5 |
| `total_area_sqm` | Decimal | Plant floor area | 185000 |
| `latitude` | Decimal | Plant GPS latitude | 42.2776 |
| `longitude` | Decimal | Plant GPS longitude | -83.1409 |
| `commissioning_date` | Date | Plant operational start date | 1995-03-01 |
| `oee_target` | Decimal | Plant OEE target % | 85.0 |
| `utilization_target` | Decimal | Plant utilization target % | 90.0 |
| `manager_name` | Text | Plant manager | Sarah Johnson |
| `union_represented` | Boolean | UAW/union represented | TRUE |
| `is_active` | Boolean | Currently operational | TRUE |

---

## 4. Relationships

The following table documents every relationship in the data model. All relationships follow the **one-to-many** pattern (dimension to fact), with filter direction from the one side (dimension) to the many side (fact).

### 4.1 Complete Relationship Matrix

| # | From Table (One Side) | From Column | To Table (Many Side) | To Column | Cardinality | Filter Direction | Active | Purpose |
|---|---|---|---|---|---|---|---|---|
| 1 | dim_supplier | supplier_id | fact_shipments | supplier_id | One-to-Many | Single (dim → fact) | YES | Filter shipments by supplier attributes |
| 2 | dim_date | date_key | fact_shipments | order_date_key | One-to-Many | Single (dim → fact) | YES | Default date filter on order date |
| 3 | dim_date | date_key | fact_shipments | delivery_date_key | One-to-Many | Single (dim → fact) | NO | Activated via USERELATIONSHIP for delivery date analysis |
| 4 | dim_date | date_key | fact_shipments | scheduled_delivery_date_key | One-to-Many | Single (dim → fact) | NO | Activated via USERELATIONSHIP for schedule analysis |
| 5 | dim_warehouse | warehouse_id | fact_shipments | warehouse_id | One-to-Many | Single (dim → fact) | YES | Filter shipments by destination warehouse |
| 6 | dim_vehicle | vehicle_id | fact_shipments | vehicle_id | One-to-Many | Single (dim → fact) | YES | Filter shipments by product |
| 7 | dim_region | region_id | fact_shipments | region_id | One-to-Many | Single (dim → fact) | YES | Filter shipments by geographic region |
| 8 | dim_warehouse | warehouse_id | fact_inventory | warehouse_id | One-to-Many | Single (dim → fact) | YES | Filter inventory by warehouse |
| 9 | dim_vehicle | vehicle_id | fact_inventory | vehicle_id | One-to-Many | Single (dim → fact) | YES | Filter inventory by product/part |
| 10 | dim_date | date_key | fact_inventory | date_key | One-to-Many | Single (dim → fact) | YES | Filter inventory snapshot by date |
| 11 | dim_vehicle | vehicle_id | fact_sales | vehicle_id | One-to-Many | Single (dim → fact) | YES | Filter sales by vehicle model |
| 12 | dim_region | region_id | fact_sales | region_id | One-to-Many | Single (dim → fact) | YES | Filter sales by customer region |
| 13 | dim_date | date_key | fact_sales | date_key | One-to-Many | Single (dim → fact) | YES | Filter sales by transaction date |
| 14 | dim_plant | plant_id | fact_production | plant_id | One-to-Many | Single (dim → fact) | YES | Filter production by plant |
| 15 | dim_vehicle | vehicle_id | fact_production | vehicle_id | One-to-Many | Single (dim → fact) | YES | Filter production by vehicle model |
| 16 | dim_date | date_key | fact_production | date_key | One-to-Many | Single (dim → fact) | YES | Filter production by date |
| 17 | dim_region | region_id | dim_supplier | region_id | One-to-Many | Single (dim → dim) | YES | Allows geographic filtering of suppliers |
| 18 | dim_region | region_id | dim_warehouse | region_id | One-to-Many | Single (dim → dim) | YES | Allows geographic filtering of warehouses |
| 19 | dim_region | region_id | dim_plant | region_id | One-to-Many | Single (dim → dim) | YES | Allows geographic filtering of plants |

### 4.2 Relationship Details and Rationale

**Relationships 2, 3, 4 — Role-Playing dim_date on fact_shipments:**
The same dim_date table serves three different date roles. Only relationship 2 (order date) is active by default. Relationships 3 and 4 are inactive and must be activated explicitly in DAX measures using USERELATIONSHIP. This avoids ambiguity and allows a single date slicer to work consistently. See Section 6.3 for role-playing dimension patterns.

**Relationships 17, 18, 19 — Dimension-to-Dimension:**
These allow filtering fact tables by region when the region is an attribute of a dimension (e.g., filtering shipments by supplier country). These relationships use single-direction filter propagation to prevent circular dependency issues. In practice, this means slicing by `dim_region[country_name]` will filter `dim_supplier` rows, which will then filter `fact_shipments` rows automatically.

---

## 5. Calculated Columns vs Measures

### 5.1 Core Principle

| Aspect | Calculated Column | Measure |
|---|---|---|
| **Computed at** | Model refresh time | Query time (when visual renders) |
| **Stored in** | VertiPaq compressed in-memory | Not stored — computed on demand |
| **Filter context** | Row-level (within a single row) | Evaluation context (from visuals and slicers) |
| **Use when** | Value is constant per row, needed for filtering/slicing/sorting | Value changes based on slicer/filter selections |
| **Performance** | Uses RAM; large columns hurt model size | No storage cost; complex measures can be slow |
| **Best for** | Category labels, date parts, flag columns, text concatenation | Aggregations, ratios, time intelligence, conditional logic |

**Golden Rule:** If a business user could filter/slice by the value, it should be a **calculated column**. If it summarizes data across rows, it should be a **measure**.

### 5.2 Fields That Should Be Calculated Columns

The following fields should be implemented as calculated columns rather than measures:

| Table | Column Name | DAX Formula | Reason |
|---|---|---|---|
| fact_shipments | `delay_days` | `fact_shipments[actual_delivery_date] - fact_shipments[scheduled_delivery_date_key]` | Used as a filter criterion in OTD measure; must be a column for row-level evaluation |
| fact_shipments | `is_on_time` | `IF(fact_shipments[delay_days] <= 0, "On Time", "Late")` | Used as a slicer for filtering on-time vs late shipments |
| fact_shipments | `days_of_supply_category` | `SWITCH(TRUE(), [days_of_supply] <= 3, "Critical", ...)` | Used as a slicer filter on inventory visuals |
| dim_supplier | `risk_tier` | `SWITCH(TRUE(), [reliability_score] >= 85, "Preferred", ...)` | Sliced on supplier visuals; static per supplier |
| dim_vehicle | `margin_pct` | `DIVIDE([list_price] - [unit_cost], [list_price])` | Static per vehicle model; used for color coding in product tables |
| dim_date | `quarter_year_sort` | `dim_date[year] * 10 + dim_date[quarter_number]` | Sort column for quarter labels |
| fact_shipments | `is_perfect_order` | `IF([delay_days] <= 0 && [defect_units] = 0 && [units_delivered] = [units_ordered], 1, 0)` | Used in perfect order rate measure as a pre-computed flag |

### 5.3 Fields That Must Be Measures

All KPIs defined in `01_supply_chain_kpi_measures.dax` must be measures because they aggregate across rows and respond to slicer/filter context. Never create the following as calculated columns:

- Any percentage (OTD %, Fill Rate %, Defect Rate %, etc.)
- Any average (Average Lead Time, etc.)
- Any sum that varies by filter (Revenue, Units Delivered, etc.)
- Any time intelligence calculation (MTD, YTD, YoY, etc.)
- Any DIVIDE() expression used for ratios

---

## 6. Power BI Best Practices Applied

### 6.1 Why Star Schema Over Snowflake

A snowflake schema normalizes dimension tables by splitting them into sub-dimensions (e.g., dim_region → dim_country → dim_continent). While this reduces storage redundancy, it creates significant problems in Power BI:

| Problem | Impact |
|---|---|
| Additional relationship hops | DAX filter context must traverse more relationships, increasing query complexity and potential for incorrect results |
| Bidirectional filter risk | Multi-hop chains often require bidirectional filters, which cause unpredictable cross-filtering behavior |
| Report author confusion | Users building self-service reports must understand which dimension level to use for each attribute |
| VertiPaq inefficiency | Power BI's column-store engine compresses text columns extremely efficiently; denormalization rarely increases model size meaningfully |

**Decision:** All dimension hierarchies (Region > State > City, Family > Model > Variant) are stored as columns within a single denormalized dimension table.

### 6.2 Handling Many-to-Many Relationships

This model avoids true many-to-many relationships between fact tables by using shared dimension keys. However, two scenarios require special handling:

**Scenario A — Supplier provides multiple part types, part sourced from multiple suppliers:**
Use a bridge table `bridge_supplier_vehicle` with columns (`supplier_id`, `vehicle_id`, `is_primary_supplier`). Connect both dim_supplier and dim_vehicle to this bridge with single-direction filters. Use TREATAS in DAX measures to pass filter context through bridge tables when needed.

**Scenario B — Shipment routing through multiple warehouses:**
Avoid storing this as separate rows per warehouse hop. Instead, record the origin warehouse and destination warehouse as separate foreign keys on fact_shipments (`origin_warehouse_id`, `destination_warehouse_id`), each connecting to dim_warehouse through separate relationships (one active, one inactive).

### 6.3 Role-Playing Dimensions

The most important role-playing dimension in this model is `dim_date`, used for:
- Order Date (active relationship from fact_shipments)
- Delivery Date (inactive — use USERELATIONSHIP)
- Scheduled Delivery Date (inactive — use USERELATIONSHIP)

**Pattern for inactive relationship activation:**

```dax
// Example: Calculate OTD % based on delivery date instead of order date
[SC] On-Time Delivery % by Delivery Date =
CALCULATE(
    [SC] On-Time Delivery %,
    USERELATIONSHIP( fact_shipments[delivery_date_key], dim_date[date_key] )
)
```

**Important:** Never use both the active and inactive relationship to the same dimension in the same measure — Power BI will raise an error. Always use USERELATIONSHIP within a CALCULATE block.

### 6.4 Performance Optimization Tips

**Model Design:**
- Set all key columns (IDs, date keys) to Integer data type where possible; integers compress far better than text in VertiPaq.
- Avoid high-cardinality text columns in fact tables (e.g., do not store free-text notes in fact tables — move them to a separate lookup).
- Remove unused columns from fact tables before import; every column uses RAM.
- Use query folding in Power Query wherever possible so transformations execute in the source database, not in Power BI memory.

**DAX Optimization:**
- Use variables (VAR / RETURN) to avoid re-evaluating the same expression multiple times within a measure.
- Avoid iterator functions (SUMX, AVERAGEX, MAXX) on large fact tables where a simple SUM/AVERAGE on a pre-computed column will suffice.
- Use DIVIDE() instead of `/` to handle zero-division without error and avoid exceptions from blank denominators.
- Use ISBLANK() checks before time intelligence calculations to prevent BLANK propagation errors.
- Avoid using COUNTROWS on filtered tables when a pre-computed flag column (e.g., `is_on_time`) can be summed with SUM instead.

**Incremental Refresh:**
- Configure incremental refresh on all fact tables. Define `RangeStart` and `RangeEnd` Power Query parameters.
- Keep historical data (e.g., 3+ years) in the model but only refresh the rolling 12-month window incrementally.
- This reduces refresh time from hours to minutes for large supply chain fact tables.

**Aggregations:**
- For `fact_inventory` (potentially 300M+ rows), create an aggregation table `agg_inventory_monthly` pre-aggregated to warehouse × product × month. Power BI will automatically use the aggregation for summary-level visuals and fall through to the detail table only when needed.

**Report Layer:**
- Limit visuals per page to 8-10 maximum; more visuals = more DAX queries per page render.
- Use bookmarks to simulate page navigation rather than adding more report pages with duplicate visuals.
- Disable "Auto date/time" in Power BI options (File → Options → Data Load) — this creates hidden auto-date tables that double the date tables in memory.
- Use field parameters for dynamic axis/measure switching rather than embedding the logic in complex DAX measures.
