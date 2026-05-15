# Data Dictionary
## Automotive Supply Chain Intelligence & Business Analytics Platform

---

## PURPOSE OF THIS DOCUMENT

A data dictionary is the "Rosetta Stone" of any analytics project.
It defines EXACTLY what every table, column, and value means in business terms.
Without this, different people interpret data differently — leading to inconsistent reports.

In a real automotive company, the data dictionary is maintained by the Data Governance team
and is referenced by BI analysts, data engineers, and business stakeholders.

---

## TABLE OF CONTENTS

1. [dim_supplier](#dim_supplier)
2. [dim_warehouse](#dim_warehouse)
3. [dim_plant](#dim_plant)
4. [dim_product](#dim_product)
5. [dim_date](#dim_date)
6. [dim_region](#dim_region)
7. [dim_vehicle](#dim_vehicle)
8. [fact_shipments](#fact_shipments)
9. [fact_inventory](#fact_inventory)
10. [fact_sales](#fact_sales)
11. [fact_production](#fact_production)

---

## dim_supplier

**Business Purpose:** Master record for all suppliers providing parts and materials to automotive OEMs.
One row per supplier. This is the "who we buy from" table.

**Source System:** Supplier Relationship Management (SRM) system / Procurement ERP

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| supplier_id | VARCHAR(10) | Unique identifier for each supplier | SUP-001 | Primary Key |
| supplier_name | VARCHAR(100) | Official company name of the supplier | Bosch Automotive | As per contract |
| supplier_region | VARCHAR(50) | Geographic region of supplier headquarters | Midwest | Midwest, Southeast, Southwest, Northeast, West |
| supplier_country | VARCHAR(50) | Country where supplier is based | United States | Mostly US, some Mexico/Canada |
| supplier_type | VARCHAR(50) | Category of component supplied | Tier-1 Electronics | Tier-1, Tier-2, Raw Materials |
| lead_time_days | INTEGER | Average days from order to delivery | 14 | Contracted lead time |
| defect_rate_pct | DECIMAL(5,2) | % of received units that fail QC inspection | 1.25 | Lower is better |
| reliability_score | DECIMAL(5,2) | Composite reliability score (0-100) | 87.5 | Higher is better |
| delivery_performance_pct | DECIMAL(5,2) | % of deliveries made on time | 94.2 | Higher is better |
| supplier_risk_score | DECIMAL(5,2) | Risk rating (1-10, higher = more risk) | 3.5 | Used for risk dashboard |
| annual_contract_value_usd | DECIMAL(15,2) | Annual value of supply contract in USD | 15000000.00 | Used for spend analysis |
| primary_component | VARCHAR(100) | Main part/material supplied | Semiconductors | Category of parts |
| years_in_contract | INTEGER | How many years this supplier has been contracted | 8 | Longer = more established |
| certification_status | VARCHAR(30) | Quality certifications held | ISO/TS 16949 | IATF 16949, ISO 9001, etc. |
| contact_email | VARCHAR(100) | Primary contact email | supplier@bosch.com | Procurement contact |

**Business Notes:**
- Tier-1 suppliers sell directly to OEMs (like Ford, GM)
- Tier-2 suppliers sell to Tier-1 suppliers
- IATF 16949 is the automotive quality management standard (required by most OEMs)
- Supplier risk score incorporates: financial health, single-source dependency, geopolitical risk, quality history

---

## dim_warehouse

**Business Purpose:** Master record for all distribution centers and warehouses in the supply chain network.
Parts move from suppliers → warehouses → manufacturing plants.

**Source System:** Warehouse Management System (WMS)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| warehouse_id | VARCHAR(10) | Unique warehouse identifier | WH-001 | Primary Key |
| warehouse_name | VARCHAR(100) | Name/code of the warehouse | Detroit Regional DC | DC = Distribution Center |
| region | VARCHAR(50) | Geographic region | Midwest | Matches dim_region |
| state | VARCHAR(50) | U.S. state | Michigan | Full state name |
| city | VARCHAR(50) | City location | Detroit | |
| storage_capacity_units | INTEGER | Maximum units that can be stored | 50000 | Total pallet positions or unit count |
| current_utilization_pct | DECIMAL(5,2) | % of capacity currently used | 78.5 | Updated daily |
| warehouse_type | VARCHAR(50) | Type of facility | Regional Distribution Center | Cross-Dock, Consolidation Hub, etc. |
| manager_name | VARCHAR(100) | Name of warehouse manager | John Smith | |
| operating_cost_monthly_usd | DECIMAL(12,2) | Monthly operating cost | 450000.00 | Lease + labor + utilities |
| latitude | DECIMAL(9,6) | GPS latitude for map visualization | 42.331429 | Used in Power BI maps |
| longitude | DECIMAL(9,6) | GPS longitude for map visualization | -83.045753 | Used in Power BI maps |

---

## dim_plant

**Business Purpose:** Master record for all automotive manufacturing plants.
This is where vehicles are assembled using parts sourced from suppliers via warehouses.

**Source System:** Manufacturing Execution System (MES)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| plant_id | VARCHAR(10) | Unique plant identifier | PLT-001 | Primary Key |
| plant_name | VARCHAR(100) | Official plant name | Ford River Rouge Complex | |
| state | VARCHAR(50) | U.S. state | Michigan | |
| city | VARCHAR(50) | City | Dearborn | |
| oem_company | VARCHAR(50) | Which OEM owns/operates plant | Ford | Ford, GM, Toyota, Tesla, etc. |
| plant_type | VARCHAR(50) | What the plant produces | Assembly | Assembly, Stamping, Powertrain, Battery |
| total_capacity_units_daily | INTEGER | Max vehicles/units per day | 1200 | At 100% utilization |
| workforce_size | INTEGER | Number of employees | 5800 | Direct labor + indirect |
| year_established | INTEGER | Year plant opened | 1982 | |
| latitude | DECIMAL(9,6) | GPS latitude | 42.272778 | |
| longitude | DECIMAL(9,6) | GPS longitude | -83.175556 | |

---

## dim_product

**Business Purpose:** Master record for all parts, components, and materials tracked in the supply chain.

**Source System:** Product Lifecycle Management (PLM) / ERP Item Master

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| product_id | VARCHAR(10) | Unique part/product identifier | PRD-001 | Primary Key |
| product_name | VARCHAR(100) | Name of the part/component | Engine Control Module | |
| product_category | VARCHAR(50) | Category of part | Electronics | Electronics, Powertrain, Body, Interior, Safety |
| unit_cost_usd | DECIMAL(10,2) | Cost per unit | 450.00 | Standard cost |
| vehicle_compatibility | VARCHAR(200) | Which vehicle types use this part | EV, Hybrid | Comma-separated |
| weight_lbs | DECIMAL(8,2) | Weight per unit in pounds | 2.5 | Used for freight cost calculation |
| is_critical_component | BOOLEAN | Whether shortage causes line stoppage | TRUE | Critical = single point of failure |

---

## dim_date

**Business Purpose:** Standard date dimension for all time-based analysis in Power BI.
ALL date joins go through this table. This is CRITICAL for Power BI time intelligence functions.

**Why a Separate Date Table?**
Power BI's DAX time intelligence functions (SAMEPERIODLASTYEAR, TOTALYTD, etc.)
REQUIRE a dedicated date table marked as such. Joining directly to raw dates
prevents these functions from working correctly.

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| date_key | DATE | The actual date (Primary Key) | 2024-01-15 |
| year | INTEGER | Calendar year | 2024 |
| quarter | INTEGER | Calendar quarter (1-4) | 1 |
| quarter_name | VARCHAR(10) | Quarter label | Q1 2024 |
| month | INTEGER | Month number (1-12) | 1 |
| month_name | VARCHAR(20) | Month name | January |
| month_short | VARCHAR(5) | Abbreviated month | Jan |
| week_number | INTEGER | ISO week number | 3 |
| day_of_month | INTEGER | Day within the month | 15 |
| day_of_week | INTEGER | Day of week (1=Monday) | 2 |
| day_name | VARCHAR(15) | Day name | Tuesday |
| is_weekend | BOOLEAN | True if Saturday or Sunday | FALSE |
| fiscal_year | INTEGER | Fiscal year (Jan-Dec for automotive) | 2024 |
| fiscal_quarter | VARCHAR(10) | Fiscal quarter label | FQ1-2024 |
| is_holiday | BOOLEAN | U.S. federal holiday | FALSE |
| season | VARCHAR(20) | Season name | Winter |

---

## dim_region

**Business Purpose:** Geographic dimension for regional analysis of sales, logistics, and operations.

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| region_id | VARCHAR(10) | Unique region identifier | REG-001 |
| region_name | VARCHAR(50) | Region name | Midwest |
| state | VARCHAR(50) | U.S. state | Michigan |
| state_code | VARCHAR(5) | Two-letter state code | MI |
| city | VARCHAR(50) | City name | Detroit |
| timezone | VARCHAR(50) | Time zone | Eastern |

**U.S. Regions Used:**
- **Midwest:** Michigan, Ohio, Indiana, Illinois, Missouri (auto manufacturing heartland)
- **Southeast:** Tennessee, Alabama, Georgia, South Carolina, Kentucky (growing auto hub)
- **Southwest:** Texas, Arizona (Tesla Gigafactory Texas, Toyota Texas plant)
- **Northeast:** Pennsylvania, New York, New Jersey
- **West:** California, Oregon, Washington (Tesla Fremont, Rivian planned)

---

## dim_vehicle

**Business Purpose:** Vehicle type and category dimension for demand and sales analysis.

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| vehicle_id | VARCHAR(10) | Unique vehicle type identifier | VEH-001 |
| vehicle_type | VARCHAR(50) | Specific vehicle model/type | F-150 Lightning |
| vehicle_category | VARCHAR(50) | Broad category | Electric Truck |
| powertrain | VARCHAR(30) | ICE, EV, Hybrid, PHEV | EV |
| oem_company | VARCHAR(50) | Manufacturer | Ford |
| vehicle_segment | VARCHAR(30) | Market segment | Full-Size Truck |
| base_price_usd | DECIMAL(10,2) | Base MSRP | 49,995.00 |

**Vehicle Categories Tracked:**
- Electric Vehicle (EV)
- Hybrid / PHEV
- Internal Combustion Engine (ICE)
- Truck (Full-Size)
- SUV / Crossover
- Sedan
- Van / Commercial

---

## fact_shipments

**Business Purpose:** Records every individual shipment from supplier to warehouse or plant.
This is the PRIMARY fact table for supply chain performance analysis.
**Grain:** One row per shipment (one shipment = one delivery of parts from one supplier)

**Source System:** Transportation Management System (TMS)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| shipment_id | VARCHAR(15) | Unique shipment identifier | SHP-000001 | Primary Key |
| supplier_id | VARCHAR(10) | FK to dim_supplier | SUP-012 | Foreign Key |
| warehouse_id | VARCHAR(10) | FK to dim_warehouse | WH-003 | Foreign Key (destination) |
| plant_id | VARCHAR(10) | FK to dim_plant | PLT-005 | FK (may be null if to warehouse) |
| product_id | VARCHAR(10) | FK to dim_product | PRD-008 | Foreign Key |
| shipment_date | DATE | Date shipment left supplier | 2024-01-15 | FK to dim_date |
| expected_delivery_date | DATE | Promised delivery date | 2024-01-20 | Based on contract lead time |
| actual_delivery_date | DATE | Actual delivery date | 2024-01-22 | Recorded by WMS on receipt |
| delay_days | INTEGER | Days late (negative = early) | 2 | actual - expected |
| quantity_shipped | INTEGER | Units in this shipment | 500 | |
| unit_cost_usd | DECIMAL(10,2) | Cost per unit | 150.00 | |
| transportation_cost_usd | DECIMAL(12,2) | Total freight cost | 1250.00 | Paid to carrier |
| fuel_cost_usd | DECIMAL(12,2) | Fuel surcharge portion | 180.00 | Subset of transport cost |
| shipment_status | VARCHAR(30) | Current status | Delivered | On Time / Delayed / In Transit |
| transportation_mode | VARCHAR(30) | How it was shipped | Truck | Truck, Rail, Air, Ocean |
| carrier_name | VARCHAR(100) | Trucking/logistics company | J.B. Hunt | |
| route_name | VARCHAR(100) | Named trade lane/route | Detroit-Chicago Corridor | |
| distance_miles | DECIMAL(8,2) | Shipping distance | 285.5 | |
| shipment_weight_lbs | DECIMAL(10,2) | Total weight of shipment | 2450.0 | |
| delay_reason | VARCHAR(100) | Root cause if delayed | Weather - Winter Storm | Categorical for analysis |

**Delay Reason Categories:**
- Weather Event
- Carrier Capacity
- Customs/Documentation
- Supplier Production Delay
- Quality Hold
- Equipment Failure (truck breakdown)
- Port Congestion
- Driver Shortage
- On Time (no delay)

---

## fact_inventory

**Business Purpose:** Daily snapshot of inventory levels at every warehouse for every product.
**Grain:** One row per (warehouse × product × date) — daily inventory position

**Source System:** Warehouse Management System (WMS)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| inventory_id | BIGINT | Surrogate key | 1000001 | Primary Key |
| warehouse_id | VARCHAR(10) | FK to dim_warehouse | WH-003 | Foreign Key |
| product_id | VARCHAR(10) | FK to dim_product | PRD-008 | Foreign Key |
| snapshot_date | DATE | Date of inventory snapshot | 2024-01-15 | FK to dim_date |
| stock_quantity | INTEGER | Units currently in stock | 1250 | As of snapshot date |
| reorder_level | INTEGER | Order more when stock falls to this level | 500 | Triggers purchase order |
| safety_stock_level | INTEGER | Minimum buffer stock | 300 | If below this → stockout risk |
| inventory_value_usd | DECIMAL(15,2) | Total value of stock (qty × unit_cost) | 187500.00 | |
| stockout_risk_score | DECIMAL(5,2) | Risk score 0-100 | 25.0 | 100 = certain stockout |
| days_of_supply | DECIMAL(8,2) | Days until stockout at current demand | 18.5 | stock_qty / avg_daily_demand |
| last_replenishment_date | DATE | When inventory was last restocked | 2024-01-10 | |
| abc_category | VARCHAR(5) | ABC classification | A | A=High Value, B=Medium, C=Low |

**ABC Classification Logic:**
- **A items:** Top 20% by inventory value — require tight control and frequent review
- **B items:** Next 30% by value — standard management procedures
- **C items:** Bottom 50% by value — simplified controls, bulk ordering

---

## fact_sales

**Business Purpose:** Records vehicle sales and demand by region, vehicle type, and time period.
**Grain:** One row per (vehicle_type × region × month) — aggregated monthly sales

**Source System:** Sales and Dealer Management System (DMS)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| sale_id | VARCHAR(15) | Unique sale record identifier | SAL-000001 | Primary Key |
| vehicle_type | VARCHAR(50) | FK to dim_vehicle | F-150 Lightning | Foreign Key |
| vehicle_category | VARCHAR(50) | Category (EV, SUV, etc.) | Electric Truck | |
| oem_company | VARCHAR(50) | Manufacturer | Ford | |
| region | VARCHAR(50) | FK to dim_region | Midwest | Foreign Key |
| state | VARCHAR(50) | U.S. state | Michigan | |
| order_date | DATE | Date order was placed | 2024-01-05 | FK to dim_date |
| delivery_date | DATE | Date vehicle delivered to customer | 2024-01-28 | FK to dim_date |
| units_sold | INTEGER | Number of vehicles sold | 1250 | |
| unit_price_usd | DECIMAL(10,2) | Sale price per vehicle | 52000.00 | |
| revenue_usd | DECIMAL(15,2) | Total revenue (units × price) | 65000000.00 | |
| forecasted_demand | INTEGER | Demand forecast for that period | 1180 | From planning system |
| forecast_accuracy_pct | DECIMAL(5,2) | How accurate the forecast was | 94.1 | |
| sales_channel | VARCHAR(30) | How sold | Dealership | Dealership, Direct (Tesla), Fleet |
| customer_segment | VARCHAR(30) | Type of customer | Consumer | Consumer, Fleet, Government |

---

## fact_production

**Business Purpose:** Daily production records from each manufacturing plant.
**Grain:** One row per (plant × production_date × shift)

**Source System:** Manufacturing Execution System (MES)

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| production_id | VARCHAR(15) | Unique production record | PRN-000001 | Primary Key |
| plant_id | VARCHAR(10) | FK to dim_plant | PLT-003 | Foreign Key |
| production_date | DATE | Date of production | 2024-01-15 | FK to dim_date |
| shift | VARCHAR(20) | Production shift | Day Shift | Day, Evening, Night |
| vehicle_type | VARCHAR(50) | Vehicle type being produced | Silverado 1500 | |
| planned_production_units | INTEGER | Target units for this shift | 400 | From production schedule |
| actual_production_units | INTEGER | Actual units produced | 382 | Recorded by MES |
| defect_units | INTEGER | Units failing quality check | 8 | Scrapped or reworked |
| downtime_hours | DECIMAL(5,2) | Hours of unplanned downtime | 1.5 | |
| downtime_reason | VARCHAR(100) | Root cause of downtime | Equipment Failure - Robot Arm | |
| utilization_rate_pct | DECIMAL(5,2) | Actual/Planned × 100 | 95.5 | |
| line_efficiency_pct | DECIMAL(5,2) | OEE metric | 87.2 | |
| energy_consumption_kwh | DECIMAL(10,2) | Energy used this shift | 45000.00 | For sustainability reporting |

---

## APPENDIX: COMMON JOINS & RELATIONSHIPS

```sql
-- Most common join pattern in this data model:
SELECT 
    s.supplier_name,
    sh.shipment_date,
    sh.delay_days,
    sh.transportation_cost_usd,
    w.warehouse_name,
    p.product_name
FROM fact_shipments sh
JOIN dim_supplier s ON sh.supplier_id = s.supplier_id
JOIN dim_warehouse w ON sh.warehouse_id = w.warehouse_id
JOIN dim_product p ON sh.product_id = p.product_id
JOIN dim_date d ON sh.shipment_date = d.date_key
WHERE d.year = 2024;
```

---

## APPENDIX: DATA QUALITY RULES

| Table | Rule | Action if Violated |
|-------|------|-------------------|
| fact_shipments | delay_days = actual_delivery_date - expected_delivery_date | Recalculate if mismatch |
| fact_inventory | stock_quantity ≥ 0 | Flag for investigation |
| fact_sales | revenue_usd = units_sold × unit_price_usd | Recalculate |
| fact_production | actual_production_units ≤ planned × 1.1 | Flag >10% overproduction |
| All fact tables | No null foreign keys | Reject record |

---

*Data Dictionary Version 1.0 | Automotive Supply Chain Intelligence Platform*
