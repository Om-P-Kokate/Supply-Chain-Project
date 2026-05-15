# PROJECT INTERVIEW GUIDE
## Automotive Supply Chain Intelligence & Business Analytics Platform
### Everything You Need to Explain This Project Confidently in Any Interview

---

> **How to use this document:**
> Read it once end-to-end. Then practice saying each section OUT LOUD.
> The goal is not to memorize — it is to understand deeply enough
> that you can explain it naturally in your own words.

---

# PART 1: THE BIG PICTURE — WHAT IS THIS PROJECT?

## 1.1 Project Title

**"Automotive Supply Chain Intelligence & Business Analytics Platform"**

Also acceptable to call it:
- "Supply Chain Control Tower for Automotive Operations"
- "U.S. Automotive Supply Chain Performance & Risk Analytics"

---

## 1.2 One-Sentence Summary (Memorize This)

> *"I built a full-stack Business Intelligence platform that simulates a
> real Supply Chain Control Tower used by U.S. automotive companies like
> Ford, Tesla, and General Motors — giving executives and operations teams
> real-time visibility into supplier delays, inventory risks, logistics
> costs, manufacturing efficiency, and vehicle demand trends through
> six interconnected Power BI dashboards."*

---

## 1.3 Why This Project Exists — The Business Story

Automotive supply chains are among the most complex in the world.

A single vehicle contains approximately **30,000 individual parts** — sourced from
hundreds of suppliers across multiple countries and managed through warehouses,
distribution centers, and manufacturing plants spread across the United States.

When something goes wrong in that chain, the consequences are massive:
- A missing microchip shut down Ford's F-150 production in 2021, costing **$1 billion in lost revenue**
- The 2011 Japan earthquake disrupted Toyota's supply chain globally for **6 months**
- COVID-19 caused semiconductor lead times to spike from **12 weeks to 52+ weeks** in 2022

**The core problem:** Supply chain leaders at companies like Ford, GM, and Tesla
are managing thousands of moving parts simultaneously — suppliers, shipments,
warehouses, plants, and customer demand — but they often don't have a single
unified view of what's happening right now.

**What this project solves:** It builds that unified view.
A Supply Chain Control Tower that shows every critical KPI on one screen,
flags problems before they become production shutdowns, and tells decision-makers
exactly where to focus their attention.

---

## 1.4 Project Focus (Know This Clearly)

| Area | % of Project |
|------|-------------|
| Business Intelligence & Analytics | 70% |
| SQL + Data Engineering | 20% |
| Predictive Analytics / Forecasting | 10% |

**This is NOT a data engineering project.**
It is a **Business Intelligence and Supply Chain Analytics** project.
The emphasis is on dashboards, KPIs, insights, and business storytelling.

---

## 1.5 The 10 Business Problems This Project Solves

When an interviewer asks *"What problem does this project solve?"* —
you can pick any of these and explain it confidently:

| # | Business Problem | Dashboard That Solves It |
|---|-----------------|--------------------------|
| 1 | Which suppliers are causing shipment delays? | Supplier Performance & Risk |
| 2 | Which warehouses are at stockout risk? | Inventory & Warehouse |
| 3 | Which regions have the highest logistics costs? | Logistics & Transportation |
| 4 | Which suppliers have the worst quality? | Supplier Performance & Risk |
| 5 | Which plants have the highest downtime? | Manufacturing Operations |
| 6 | Which vehicle categories are growing or declining? | Demand & Sales |
| 7 | What are the biggest operational bottlenecks? | Executive Overview |
| 8 | Which transportation routes are inefficient? | Logistics & Transportation |
| 9 | What factors drive supply chain disruptions? | Supplier + Executive |
| 10 | What will demand look like next quarter? | Demand & Sales (Forecasting) |

---

# PART 2: THE DATA — WHAT DID YOU WORK WITH?

## 2.1 Why Synthetic Data?

**Interview question you will get:** *"Is this real data or synthetic?"*

**Your answer:**
> *"The data is synthetic — I generated it using Python's Faker library and NumPy.
> I chose synthetic data because real automotive supply chain data from companies
> like Ford or GM is confidential and proprietary. However, I designed the
> synthetic data to be highly realistic — it incorporates actual industry benchmarks,
> real supplier names, real U.S. automotive plant locations, COVID-era disruption
> patterns, semiconductor shortage effects, seasonal demand trends, and
> statistically realistic correlations between variables. The data tells a
> real story even though the records are generated."*

---

## 2.2 Dataset Overview — The Numbers

| Table | Rows | What It Represents |
|-------|------|-------------------|
| shipments.csv | **52,000** | Every inbound shipment (2022–2024) |
| inventory.csv | **30,900** | Daily warehouse inventory snapshots |
| sales_demand.csv | **32,000** | Vehicle sales records with forecasts |
| production.csv | **20,970** | Daily plant production + downtime |
| suppliers.csv | 50 | Supplier master records |
| warehouses.csv | 20 | Distribution center details |
| plants.csv | 15 | Manufacturing plant details |
| products.csv | 30 | Parts and component catalog |
| **TOTAL** | **135,985** | **3 years of data (2022–2024)** |

---

## 2.3 Realistic Features Built Into the Data

This shows your business understanding. Know these cold:

**1. COVID / Chip Shortage Impact (2022)**
- Plant utilization in 2022 averaged only **39.9%** (vs. 82.3% in 2024)
- Delay rates were higher in 2022 — average delay days were **1.43** vs. **0.23** in 2024
- This mirrors what actually happened to Ford, GM, and Toyota during the semiconductor shortage

**2. Seasonal Demand Patterns**
- Q4 (October–December) is always the strongest sales quarter in automotive
- Q1 (January–February) is always the weakest
- This is driven by holiday shopping, end-of-year tax purchasing, and dealer incentives

**3. Supplier Risk Correlation**
- Built a **0.91 correlation** between supplier risk score and actual defect rate
- Meaning: suppliers flagged as high-risk actually produce more defective parts
- This makes the data analytically meaningful — risk scores predict real outcomes

**4. EV Demand Acceleration**
- Electric vehicle demand grows dramatically from 2022 to 2024
- ICE (Internal Combustion Engine) demand declines
- Mirrors the real-world transition happening in the U.S. automotive market

---

## 2.4 U.S. Automotive Geography Used

**Regions and why they matter:**

| Region | Key States | Why Important |
|--------|-----------|---------------|
| Midwest | Michigan, Ohio, Indiana | Traditional auto heartland — Ford, GM headquarters |
| Southeast | Tennessee, Alabama, Georgia, Kentucky | Fast-growing new auto hub — Toyota, VW, Mercedes |
| Southwest | Texas, Arizona | Tesla Gigafactory Texas, Toyota San Antonio |
| Northeast | Pennsylvania, New York | Supplier concentration, port access |
| West | California, Oregon | Tesla Fremont, EV demand leader (ZEV mandate) |

---

# PART 3: THE TECH STACK — WHAT DID YOU USE AND WHY?

## 3.1 Full Technology Stack

| Technology | What It Does in This Project | Why Chosen |
|-----------|------------------------------|-----------|
| **Power BI** | 6 executive dashboards, KPI cards, interactive visuals | Industry standard in automotive/manufacturing BI |
| **DAX** | 26 KPI measures (OTD%, Inventory Turnover, etc.) | Power BI's formula language for calculations |
| **SQL** | Star schema DDL, 6 query files, 5 analytical views | Universal analytics language, interview-critical |
| **Python** | Data generation, cleaning pipeline, analytics | Flexible, powerful for data work |
| **Pandas** | Data manipulation and transformation | Industry standard Python data library |
| **NumPy** | Statistical calculations, random generation | Scientific computing foundation |
| **XGBoost** | Shipment delay prediction model | State-of-the-art for tabular ML |
| **Prophet** | Demand forecasting | Facebook's time series library, handles seasonality |
| **Faker** | Generating realistic synthetic names/data | Creates believable supplier names, locations |

---

## 3.2 Why Power BI? (Be Ready for This Question)

> *"Power BI is the dominant BI tool in automotive manufacturing and supply chain.
> It integrates natively with Microsoft's ecosystem (Excel, Azure, SQL Server)
> which most large OEMs use. DAX time intelligence functions make year-over-year
> and month-over-month comparisons very efficient. The star schema I built
> is specifically optimized for Power BI's VertiPaq columnar storage engine,
> which dramatically improves dashboard load times even with 135,000+ rows."*

---

# PART 4: THE DATA MODEL — SQL STAR SCHEMA

## 4.1 What Is a Star Schema?

A star schema is a database design pattern used specifically for analytics and reporting.

**Why it looks like a star:**
- There is one central table (called a **Fact Table**) surrounded by reference tables (called **Dimension Tables**)
- When you draw it on paper, the fact table is in the center with dimension tables branching out — like a star

**Why we use it for Power BI instead of a normal database structure:**
- Normal databases (3NF) are optimized for inserting and updating data efficiently
- Star schemas are optimized for **reading and aggregating data fast**
- Power BI's calculation engine (VertiPaq) works best with star schemas
- It makes DAX time intelligence formulas work correctly

---

## 4.2 Your Star Schema — The Tables

### FACT TABLES (The "what happened" tables — large, transactional)

**fact_shipments** — One row per shipment
- Every part/component delivered from a supplier to a warehouse
- 52,000 rows covering 3 years
- Key columns: supplier_id, warehouse_id, shipment_date, delay_days, transportation_cost, is_on_time
- **This is your most important fact table** — it drives OTD%, logistics costs, and supplier performance

**fact_inventory** — One row per warehouse × product × day
- Daily snapshot of how much stock is at each location
- 30,900 rows
- Key columns: warehouse_id, product_id, snapshot_date, stock_quantity, safety_stock_level, days_of_supply
- Used for: stockout alerts, inventory health, warehouse utilization

**fact_sales** — One row per vehicle sale record
- 32,000 rows of vehicle sales across all regions
- Key columns: vehicle_type, region, order_date, units_sold, revenue_usd, forecasted_demand
- Used for: revenue trends, forecast accuracy, EV demand growth

**fact_production** — One row per plant × date × shift
- Daily production records from each manufacturing plant
- 20,970 rows
- Key columns: plant_id, production_date, actual_production_units, downtime_hours, defect_units
- Used for: plant utilization, downtime analysis, OEE calculation

---

### DIMENSION TABLES (The "who/what/where/when" tables — small, descriptive)

**dim_supplier** — 50 rows — Who supplies parts to us?
- supplier_name, region, lead_time_days, defect_rate, reliability_score, risk_score

**dim_warehouse** — 20 rows — Where do we store parts?
- warehouse_name, region, state, storage_capacity, latitude, longitude

**dim_plant** — 15 rows — Where do we build vehicles?
- plant_name, oem_company, state, total_capacity_units_daily

**dim_product** — 30 rows — What parts/components are we tracking?
- product_name, category, unit_cost, is_critical_component

**dim_date** — ~2,000 rows — The time dimension (CRITICAL for Power BI)
- Every date from 2020–2026
- year, quarter, month, month_name, is_weekend, fiscal_quarter
- **Must be marked as "Date Table" in Power BI for time intelligence to work**

**dim_region** — Geographic reference — Which U.S. region/state?

**dim_vehicle** — Vehicle type reference — EV, SUV, Truck, Sedan, etc.

---

## 4.3 The Relationships (How Tables Connect)

Every fact table connects to dimension tables through foreign keys:

```
fact_shipments → dim_supplier     (via supplier_id)
fact_shipments → dim_warehouse    (via warehouse_id)
fact_shipments → dim_date         (via shipment_date)
fact_shipments → dim_product      (via product_id)

fact_inventory → dim_warehouse    (via warehouse_id)
fact_inventory → dim_product      (via product_id)
fact_inventory → dim_date         (via snapshot_date)

fact_sales     → dim_date         (via order_date)
fact_sales     → dim_region       (via region)
fact_sales     → dim_vehicle      (via vehicle_type)

fact_production → dim_plant       (via plant_id)
fact_production → dim_date        (via production_date)
```

**All relationships are Many-to-One** (many shipments to one supplier, many shipments to one date).

---

## 4.4 Why Star Schema Over Regular Database Design?

| Normal Database (3NF) | Star Schema |
|----------------------|-------------|
| Optimized for writes (INSERT/UPDATE) | Optimized for reads (SELECT/aggregate) |
| Many tables, many joins needed | Few joins needed |
| Slower for aggregations | Fast for SUM, COUNT, AVG |
| Good for ERP systems | Good for Power BI, dashboards |
| Prevents data duplication | Accepts some redundancy for speed |

**Simple analogy for interviews:**
> *"A normal database is like a filing cabinet — organized to find one specific document fast.
> A star schema is like a summary report — organized so you can see totals and trends instantly."*

---

# PART 5: SQL — WHAT QUERIES DID YOU WRITE?

## 5.1 SQL Files in the Project

You wrote **9 SQL files** organized in 3 folders:

### Schema Files (2 files)
1. **01_create_tables.sql** — Full DDL to create all 11 tables (4 fact + 7 dimension)
   - CREATE TABLE statements with data types, primary keys, foreign keys, indexes
2. **02_populate_date_dim.sql** — Populates dim_date with every date from 2020–2026
   - Includes holiday flags, fiscal quarters, week numbers

### Query Files (6 files — one per business domain)
3. **01_supplier_performance_analysis.sql**
   - Which suppliers have the worst OTD?
   - What is the average lead time by region?
   - Supplier risk ranking with composite score
4. **02_inventory_analysis.sql**
   - Which warehouses are below safety stock? (stockout risk)
   - ABC analysis — A/B/C category items by value
   - Days of supply calculation per location
5. **03_logistics_transportation_analysis.sql**
   - Transportation cost by route, carrier, and mode
   - On-time delivery % by region and month
   - Most delayed routes ranked
6. **04_manufacturing_analysis.sql**
   - Plant utilization rates
   - Downtime Pareto analysis (which causes matter most)
   - OEE (Overall Equipment Effectiveness) calculation
7. **05_sales_demand_analysis.sql**
   - Revenue by vehicle type and region
   - Year-over-year growth using window functions
   - Forecast accuracy analysis
8. **06_executive_kpi_summary.sql**
   - Master query using 8 CTEs
   - Produces ALL top-level KPIs in one result set
   - Designed to feed the Executive Overview dashboard

### Views File (1 file)
9. **01_supply_chain_views.sql** — 5 pre-built views:
   - `vw_supplier_scorecard` — Full supplier ranking
   - `vw_inventory_health` — Current stock status with risk flags
   - `vw_shipment_performance` — Enriched shipment data
   - `vw_plant_efficiency` — Manufacturing KPIs
   - `vw_executive_kpi_dashboard` — Pre-aggregated for fast dashboard queries

---

## 5.2 SQL Techniques Used (Mention These in Interviews)

| Technique | Where Used | What It Does |
|-----------|-----------|--------------|
| **CTEs (WITH clauses)** | Executive KPI query | Breaks complex logic into readable steps |
| **Window Functions** | Sales YoY query | LAG() for comparing to prior year/period |
| **CASE WHEN** | Status classification | Creates traffic light labels (Green/Yellow/Red) |
| **Aggregations** | All query files | SUM, AVG, COUNT, MAX for KPI calculations |
| **NULLIF / DIVIDE** | KPI denominators | Prevents division by zero errors |
| **Date arithmetic** | Delay calculation | DATEDIFF to calculate delay_days |
| **JOIN types** | All files | LEFT JOIN to keep all suppliers even without shipments |
| **CREATE VIEW** | Views file | Encapsulates logic for reuse across dashboards |

---

## 5.3 Sample SQL You Can Explain (The OTD Query)

```sql
-- On-Time Delivery % by Supplier
SELECT
    s.supplier_name,
    s.supplier_region,
    COUNT(sh.shipment_id)                                    AS total_shipments,
    SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)    AS on_time_count,
    ROUND(
        SUM(CASE WHEN sh.delay_days <= 0 THEN 1 ELSE 0 END)
        / COUNT(sh.shipment_id) * 100, 2
    )                                                        AS otd_pct
FROM fact_shipments sh
JOIN dim_supplier s ON sh.supplier_id = s.supplier_id
WHERE sh.shipment_date >= DATEADD(year, -1, GETDATE())
GROUP BY s.supplier_name, s.supplier_region
ORDER BY otd_pct ASC;  -- Worst performers first
```

**How to explain this:**
> *"This query joins our shipment fact table to the supplier dimension,
> uses a CASE WHEN to count only shipments where delay_days is zero or negative
> (meaning on time or early), divides by total shipments for the percentage,
> and orders ascending so the worst performers appear first — exactly what a
> procurement manager needs to prioritize corrective actions."*

---

# PART 6: PYTHON — WHAT DID YOU BUILD?

## 6.1 The Four Python Scripts

### Script 1: generate_datasets.py
**What:** Generates all 135,985 rows of synthetic data
**Why:** To simulate realistic automotive supply chain operations
**How:** Uses Faker for names, NumPy for statistical distributions, Pandas for DataFrames
**Key design decisions:**
- Fixed random seed (42) for reproducibility
- Built-in seasonal patterns for demand
- Correlation between risk scores and defect rates
- COVID disruption reflected in 2022 data

### Script 2: 01_data_cleaning_pipeline.py
**What:** ETL pipeline that cleans and enriches raw data
**Why:** Raw data always needs cleaning — even synthetic data benefits from standardization
**What it does:**
- Validates calculated fields (recalculates delay_days from actual dates)
- Adds derived columns (is_on_time flag, delay_category, risk_tier labels)
- Standardizes text fields (consistent casing, strip whitespace)
- Generates a data quality report
- Logs all operations for audit trail

**Key interview point:** In real companies, data comes from ERP (SAP), WMS (Oracle), TMS systems — all in different formats. The cleaning pipeline standardizes everything before it hits the dashboard.

### Script 3: 01_supply_chain_analytics.py
**What:** Calculates all supply chain KPIs and exports results
**Why:** Pre-calculates complex metrics so Power BI dashboards load fast
**Outputs:**
- supplier_scorecard.csv (ranked supplier performance)
- inventory_risk_report.csv (stockout risk by warehouse)
- logistics_efficiency.csv (cost trends)
- kpi_summary.csv (all executive KPIs in one row)
- monthly_trends.csv (for trend line charts)
- carrier_performance.csv (carrier ranking)

### Script 4: 01_demand_forecasting.py
**What:** Predictive analytics — forecasting and delay prediction
**Models:**
1. **Prophet** (demand forecasting) — predicts next 12 months of vehicle demand
2. **XGBoost** (delay prediction) — predicts whether a planned shipment will be delayed
3. **Weighted Scorecard** (supplier risk scoring) — composite risk score 0–100

---

## 6.2 The Predictive Models — Explain Simply

### Model 1: Demand Forecasting (Prophet)
**Business purpose:** Know how many vehicles customers will want next quarter
so we order the right amount of parts now.

**How Prophet works (simple explanation):**
> *"Prophet breaks a time series into three components: the long-term trend
> (is demand growing or shrinking overall?), the seasonal pattern (Q4 is always
> stronger), and noise (random variation). Then it forecasts forward.
> It's particularly good for automotive because it handles the strong Q4
> seasonality that's characteristic of vehicle sales."*

**Output:** 12-month forecast with upper/lower confidence intervals

### Model 2: Shipment Delay Prediction (XGBoost)
**Business purpose:** Predict WHICH planned shipments are likely to arrive late
so we can take action before the delay happens.

**Features used to predict delay:**
- Supplier's historical on-time delivery rate (most predictive)
- Supplier's risk score
- Shipping month (January/February = more weather delays)
- Distance in miles
- Transportation mode

**Results:** 87.4% accuracy, 63.3% ROC-AUC

**Key insight from the model:**
> *"The most important predictor of delay was supplier risk score — meaning suppliers
> flagged as high-risk actually do delay more often. This validates the risk scoring
> model and shows that proactive supplier monitoring really matters."*

### Model 3: Supplier Risk Scoring (Weighted Scorecard)
**Business purpose:** Give each supplier a 0–100 risk score so procurement
teams know where to focus attention.

**Formula:**
- OTD Performance: 30% weight
- Defect Rate: 25% weight
- Lead Time Consistency: 20% weight
- Contract Concentration Risk: 15% weight (high spend on one risky supplier = danger)
- Base Risk Rating: 10% weight

**Why not pure ML?**
> *"I chose a weighted scorecard over pure machine learning because procurement
> teams need to explain the score to suppliers in quarterly business reviews.
> 'Your score dropped because your OTD fell below 85% in Q3' is actionable.
> A black-box neural network score is not."*

---

# PART 7: POWER BI DASHBOARDS — THE CENTERPIECE

## 7.1 Dashboard Architecture — How the 6 Dashboards Connect

```
                    EXECUTIVE OVERVIEW
                   (Start here — C-Suite)
                          │
          ┌───────────────┼───────────────────┐
          │               │                   │
   SUPPLIER          INVENTORY &        LOGISTICS &
 PERFORMANCE       WAREHOUSE MGMT      TRANSPORTATION
  (Procurement)      (Operations)        (Logistics)
          │               │                   │
          └───────────────┼───────────────────┘
                          │
               ┌──────────┴──────────┐
               │                     │
          DEMAND &             MANUFACTURING
           SALES               OPERATIONS
         (Commercial)          (Plant Mgmt)
```

**Every dashboard drill-throughs to the others.** Click a supplier name on any dashboard
→ goes to that supplier's full detail view.

---

## 7.2 Dashboard-by-Dashboard Explanation

### Dashboard 1: Executive Overview
**Who uses it:** CEO, COO, VP Supply Chain
**When:** Every morning before the leadership stand-up meeting
**What it shows:** 8 KPI cards + trend lines + regional maps

**The 8 KPI Cards:**
| Card | Metric | Target | Color Logic |
|------|--------|--------|-------------|
| 1 | On-Time Delivery % | ≥ 95% | Green ≥95%, Yellow 85-95%, Red <85% |
| 2 | Total Shipments | Info only | No color |
| 3 | Inventory Value | ±20% of plan | Informational |
| 4 | Supplier Reliability | ≥ 85/100 | Green ≥85, Yellow 75-85, Red <75 |
| 5 | Transportation Cost | < 5% of revenue | Green <5%, Yellow 5-7%, Red >7% |
| 6 | Plant Utilization | 80–90% | Green in range, Red out of range |
| 7 | Stockout Rate | < 2% | Green <2%, Yellow 2-5%, Red >5% |
| 8 | Fill Rate | ≥ 98% | Green ≥98%, Yellow 95-98%, Red <95% |

**Key visuals:**
- **OTD Trend Line** — 24-month trend with 95% target line (most looked-at visual)
- **Regional Map** — Shipments plotted on U.S. map, colored by OTD performance
- **Revenue Donut** — Revenue split by vehicle category (shows EV growth)
- **Supplier Risk Table** — Color-coded table showing which suppliers are in the red

**What executives learn from this dashboard in 30 seconds:**
- Is our supply chain better or worse than last quarter?
- Where are the biggest risks right now?
- Which KPIs need immediate attention?

---

### Dashboard 2: Supplier Performance & Risk
**Who uses it:** VP Procurement, Category Managers, Supplier Development team
**Primary visual:** Supplier Risk Matrix (scatter plot)

**The Supplier Risk Matrix — explain this visual clearly:**
> *"This is a scatter plot where every dot is one supplier.
> The X-axis shows On-Time Delivery % — higher is better, so you want suppliers on the right.
> The Y-axis shows Defect Rate % — lower is better, so you want suppliers at the bottom.
> The size of each dot represents how much money we spend with that supplier.
> The color represents their risk tier — green, yellow, orange, or red.
> The most dangerous suppliers are the large dots in the top-left corner —
> high spend, poor delivery, high defects. That's where procurement needs to act immediately."*

**Supplier Scorecard Table:**
- Ranks all 50 suppliers from best to worst
- Shows OTD %, defect rate, lead time, reliability score, risk tier in one row
- Color-coded cells — you can identify problem suppliers at a glance
- Click any supplier → drill-through to their 12-month shipment history

**What procurement learns:**
- Which suppliers to invite for a corrective action meeting this week
- Which suppliers to consider replacing or dual-sourcing
- Which suppliers deserve preferred status and better contract terms

---

### Dashboard 3: Inventory & Warehouse Management
**Who uses it:** Operations Manager, Inventory Planners, Warehouse Managers
**Most important visual:** Stockout Alert Table

**The Stockout Alert Table — this is the "act now" table:**
> *"This table shows every product-location combination where inventory is below the
> safety stock level, sorted by days of supply ascending — so the most urgent
> situations are at the top. If a warehouse has 2.1 days of supply for an Engine
> Control Module, and the next shipment is 6 days away, that's a production stoppage
> waiting to happen. The table tells the operations team exactly where to make
> emergency calls today."*

**ABC Analysis Visual:**
- A Items: Top 20% by inventory value — tightest controls, most frequent review
- B Items: Next 30% — standard management
- C Items: Bottom 50% by value — simplified controls
- **Business logic:** Don't treat all 30 parts the same. Focus energy on A items.

**Warehouse Utilization Gauges:**
- Each warehouse has a gauge showing current utilization %
- Optimal zone: 75–85% (green)
- Below 60% = underutilized (waste of lease cost)
- Above 90% = too full (picking efficiency drops, safety risk)

---

### Dashboard 4: Logistics & Transportation
**Who uses it:** Logistics Manager, Transportation Analysts, Finance
**Key insight this dashboard surfaces:** Cost differences by region, carrier, and transport mode

**Transportation Mode Comparison:**
| Mode | Avg Cost | OTD % | When to Use |
|------|----------|-------|-------------|
| Air Freight | $1,975/shipment | 98.4% | Emergency only — parts needed in 24hrs |
| Rail | $746/shipment | 94.1% | Long distances (>500 miles), non-urgent |
| Truck FTL | $873/shipment | 92.3% | Standard bulk shipments |
| Truck LTL | $578/shipment | 88.7% | Smaller loads, last-mile |

**Key finding from this dashboard:**
> *"The Southeast logistics corridor had costs 18% above the national average.
> The root cause was fragmented carrier relationships — 28 different carriers
> in the Southeast vs. 12 in the Midwest — losing volume discounts.
> Consolidating to 8-10 preferred carriers could save $2.8 million annually."*

---

### Dashboard 5: Demand & Sales Analytics
**Who uses it:** Sales Leadership, Commercial Finance, Production Planning
**Most important story:** EV demand acceleration and forecast error

**Forecast vs. Actual Chart:**
> *"This chart overlays the forecasted demand line (dotted) against actual sales (solid).
> When actual is above forecast — you have a positive surprise but you're likely
> caught short on inventory. When actual is below forecast — you over-ordered parts
> and have too much inventory. The chart shows we were consistently under-forecasting
> EV demand in 2024, meaning our supply chain wasn't ready for the volume of
> electric vehicle orders coming in."*

**EV vs. ICE Trend:**
- EV/Hybrid sales growing sharply year over year
- ICE sedan sales declining 17% year over year
- This tells the supply chain team to shift sourcing toward battery components
  and away from traditional powertrain parts

---

### Dashboard 6: Manufacturing Operations
**Who uses it:** VP Operations, Plant Managers, Manufacturing Engineers
**Key visual:** Downtime Pareto Chart

**The Downtime Pareto — explain this:**
> *"A Pareto chart shows causes ranked by frequency, with a cumulative percentage line.
> The Pareto principle says 80% of problems come from 20% of causes.
> In our data, equipment failure and material shortages together caused 66% of all
> downtime hours — so if you fix just those two root causes, you eliminate
> two-thirds of lost production time. That's where the maintenance budget
> and supply chain attention should go."*

**OEE — Overall Equipment Effectiveness:**
- Formula: Availability × Performance × Quality
- World-class target: ≥ 85%
- Example: 95% availability × 92% performance × 98% quality = 85.6% OEE
- This single number tells you how efficiently a plant is running

---

## 7.3 Power BI Features Used

| Feature | What It Does | Where Used |
|---------|-------------|-----------|
| **DAX Measures** | Calculated KPIs (OTD%, turnover, etc.) | All dashboards |
| **KPI Cards** | Highlight single numbers with status | Executive Overview |
| **Drill-through** | Click supplier → see their full detail | All dashboards |
| **Bookmarks** | Save filter states, toggle views | Monthly/quarterly toggle |
| **Slicers** | Filter by date, region, OEM, product | Every dashboard |
| **Tooltips** | Hover for extra detail | All charts |
| **Conditional Formatting** | Traffic light colors on tables | Scorecard tables |
| **Cross-filtering** | Click one visual → filters all others | All dashboards |
| **Time Intelligence** | YTD, YoY, Rolling 12M calculations | All dashboards |

---

# PART 8: DAX MEASURES — THE KPI CALCULATIONS

## 8.1 What is DAX?

DAX stands for **Data Analysis Expressions**.
It is Power BI's formula language — similar to Excel formulas but designed
for working with entire tables and relationships.

**Simple analogy:**
> *"Excel SUM adds up a column. DAX SUM can add up a column filtered by whatever
> the user has selected on the dashboard — dynamically. That's the power."*

---

## 8.2 The 26 DAX Measures — Key Ones to Know

### On-Time Delivery % (Most Important)
```dax
On-Time Delivery % =
DIVIDE(
    COUNTROWS(FILTER(fact_shipments, fact_shipments[is_on_time] = 1)),
    COUNTROWS(fact_shipments),
    0
) * 100
```
**Explain it:** Count shipments where is_on_time = 1, divide by total shipments.
The DIVIDE function safely handles division by zero (returns 0 instead of error).

---

### Inventory Turnover
```dax
Inventory Turnover =
DIVIDE(
    SUM(fact_sales[revenue_usd]),
    AVERAGE(fact_inventory[inventory_value_usd]),
    0
)
```
**Explain it:** How many times per year we "sell through" our inventory.
Higher = more efficient (less cash tied up in stock).
Industry target: 8–12x per year for automotive.

---

### Revenue Year-over-Year Growth % (Time Intelligence)
```dax
Revenue Growth % YoY =
DIVIDE(
    SUM(fact_sales[revenue_usd]) -
    CALCULATE(SUM(fact_sales[revenue_usd]), SAMEPERIODLASTYEAR(dim_date[Date])),
    CALCULATE(SUM(fact_sales[revenue_usd]), SAMEPERIODLASTYEAR(dim_date[Date])),
    0
) * 100
```
**Explain it:** SAMEPERIODLASTYEAR is a DAX time intelligence function that
automatically shifts the date context back exactly one year. This is why the
date dimension must be marked as a Date Table in Power BI.

---

### Stockout Alert (Text Measure for Conditional Formatting)
```dax
Stockout Alert =
SWITCH(
    TRUE(),
    AVERAGE(fact_inventory[days_of_supply]) < 3,  "🔴 CRITICAL",
    AVERAGE(fact_inventory[days_of_supply]) < 7,  "🟠 HIGH RISK",
    AVERAGE(fact_inventory[days_of_supply]) < 14, "🟡 WARNING",
    "🟢 Healthy"
)
```
**Explain it:** Returns a text label based on days of supply.
Used in the inventory dashboard to show colored status badges without needing
complex conditional formatting rules.

---

### Perfect Order Rate
```dax
Perfect Order Rate =
DIVIDE(
    [On-Time Delivery %] * [Fill Rate %],
    100,
    0
)
```
**Explain it:** Perfect Order Rate combines OTD and Fill Rate.
A shipment must be: on time AND complete to count as a perfect order.
Industry gold standard metric — target ≥ 95%.

---

# PART 9: KEY BUSINESS INSIGHTS FROM THE DATA

## 9.1 The 6 Most Important Findings

These are the findings you discovered by running the analytics. Know these well —
interviewers love asking *"What did you find?"*

---

### Finding 1: Pareto Pattern in Supplier Delays
**What:** 15 out of 50 suppliers (30%) are below the 85% OTD threshold
**Business meaning:** A small group of underperforming suppliers is causing
the majority of supply chain disruptions
**What to do about it:**
- Issue Supplier Corrective Action Plans (SCAPs) to the worst performers
- Begin dual-sourcing qualification for critical single-source parts
- Monthly scorecards with executive accountability

**How to say it in an interview:**
> *"The data showed a classic Pareto distribution — about 30% of suppliers were
> generating most of the delays. This is actually very common in supply chain.
> The value of the dashboard is that it makes this pattern immediately visible
> so procurement can prioritize exactly where to focus their energy."*

---

### Finding 2: Four Warehouses at Critical Stockout Risk
**What:** 4 warehouses have average days-of-supply below the 7-day critical threshold
**Business meaning:** If a critical part runs out, the connected assembly line stops
**Cost of a stoppage:** $1M+ per day at a major automotive plant
**What to do:** Emergency replenishment orders, recalculate safety stock levels

---

### Finding 3: Southeast Logistics Corridor Overspend
**What:** Southeast region logistics costs are 18% above the national benchmark
**Root cause:** Carrier fragmentation — 28 carriers in Southeast vs. 12 in Midwest
**Financial impact:** ~$2.8M annual overspend
**Solution:** Consolidate to 8–10 preferred carriers, negotiate volume rates

---

### Finding 4: Plant Utilization Recovery From Chip Shortage
**What:** Average plant utilization went from 39.9% in 2022 to 82.3% in 2024
**Business meaning:** This shows the chip shortage's real impact — plants sat
nearly idle — and the subsequent recovery
**Why it matters in an interview:** Shows you understand the real-world events
that shaped the data, not just the numbers themselves

---

### Finding 5: EV Demand Outpacing Forecasts
**What:** EV demand grew dramatically but forecasts consistently underestimated it
**Business meaning:** The supply chain isn't ready for the EV transition speed
**Risk:** Battery supply agreements only cover 68% of projected demand
**What to do:** Update demand forecasting model, secure battery supply contracts

---

### Finding 6: $28.7M in Total Addressable Improvement
**Breakdown:**
- Supplier OTD improvement: $5.2M (reduced emergency air freight + downtime)
- Inventory optimization: $3.8M (right-sizing safety stock)
- Southeast logistics consolidation: $3.5M (carrier reduction)
- Plant utilization improvement: $4.2M (maintenance investment)
- EV supply chain readiness: $12M revenue protection
- **Total: $28.7M** in identifiable annual value

---

# PART 10: INTERVIEW Q&A — PRACTICE THESE

## Common Interview Questions and How to Answer Them

---

**Q: "Walk me through your project."**

A: *"I built a Supply Chain Control Tower for the U.S. automotive industry.
The core idea is that companies like Ford and Tesla need a single unified view
of their supply chain — suppliers, inventory, logistics, plants, and customer demand —
all in one place. I built that using Power BI as the primary platform, with six
interconnected dashboards for different audiences.
The data layer is 135,000 rows of realistic synthetic automotive supply chain data
across 3 years, modeled in a star schema for optimal Power BI performance.
On top of that I built SQL analytics, Python data pipelines, DAX measures, and
lightweight predictive models for demand forecasting and delay prediction.
The most interesting finding was identifying $28.7 million in addressable
improvements across supplier management, inventory, logistics, and operations."*

---

**Q: "Why did you choose this industry?"**

A: *"Automotive supply chains are genuinely one of the most complex in the world —
30,000 parts per vehicle, hundreds of suppliers, global logistics networks.
The business stakes are extremely high — a single missing part can shut down
a $1M/day assembly line. That makes supply chain analytics critically important,
not just a nice-to-have. I also wanted to work with an industry where
I could demonstrate both technical analytics skills and real operational
business understanding."*

---

**Q: "What was the hardest part of this project?"**

A: *"Designing the data to be analytically meaningful, not just technically correct.
It's easy to generate random numbers. The challenge was building in realistic
patterns — the COVID disruption in 2022 data, the seasonal Q4 demand peak,
the correlation between supplier risk scores and actual defect rates.
Without those patterns, the analytics wouldn't tell a real story.
I spent significant time thinking about what real automotive supply chain data
actually looks like before writing a single line of code."*

---

**Q: "Explain your data model."**

A: *"I used a star schema — four fact tables at the center surrounded by seven
dimension tables. The fact tables store transactional data: shipments, inventory
snapshots, sales, and production. The dimension tables store descriptive
reference data: suppliers, warehouses, plants, products, dates, and regions.
I chose star schema specifically because Power BI's VertiPaq engine is
optimized for it, and because DAX time intelligence functions — which I used
for year-over-year calculations — require a properly structured date dimension
marked as a Date Table. Every relationship in the model is many-to-one,
going from fact tables to dimension tables."*

---

**Q: "Tell me about the Power BI dashboards."**

A: *"I built six dashboards, each targeting a different audience and business question.
The Executive Overview is for the C-suite — eight KPI cards with traffic light
status plus trend lines. The Supplier Performance dashboard is for procurement —
the centerpiece is a risk matrix scatter plot where X-axis is OTD%, Y-axis is
defect rate, and dot size is contract spend — immediately shows which high-value
suppliers are performing poorly. The Inventory dashboard has a stockout alert
table sorted by days of supply — the 'act on this today' list. I also built
dashboards for logistics, demand/sales, and manufacturing. All six are connected
with drill-through pages so you can click from executive overview into any
operational detail."*

---

**Q: "What KPIs did you track and why?"**

A: *"I tracked twelve core KPIs across four domains. For supply chain delivery:
On-Time Delivery %, Fill Rate, Perfect Order Rate, and Average Lead Time.
For inventory: Inventory Turnover, Days of Supply, Stockout Rate, and
Warehouse Utilization. For manufacturing: Plant Utilization, Downtime %,
Defect Rate, and OEE. For financials: Transportation Cost Ratio, Revenue Growth,
and Forecast Accuracy. I chose these because they're the standard KPIs used
in automotive supply chain leadership reviews — they directly connect to
production uptime, cost efficiency, and revenue protection."*

---

**Q: "What would you do differently or add next?"**

A: *"Three things. First, I'd add a real-time alerting layer — when days of supply
drops below 7 days for a critical part, an automated email goes to the
operations team before they check the dashboard. Second, I'd expand the
predictive model — the XGBoost delay predictor has 87% accuracy but
I'd improve it by adding weather data and carrier capacity data as features.
Third, I'd add Tier-2 supplier visibility — most OEMs only track Tier-1
suppliers directly, but the semiconductor shortage showed that Tier-2 and
Tier-3 dependencies are just as dangerous. Mapping the full supply chain
network would significantly improve the risk dashboard."*

---

**Q: "How is this project relevant to this role?"**

*(Customize based on the role, but here are templates:)*

*For a Supply Chain Analyst role:*
> *"This project directly mirrors what a supply chain analyst does every day —
> monitoring KPIs, identifying root causes, building reports, and translating
> data into operational recommendations. I understand the business language:
> OTD, safety stock, lead time, SCAP, ABC analysis. I can hit the ground running."*

*For a BI Analyst / Data Analyst role:*
> *"This project demonstrates the full BI workflow: data modeling, SQL analytics,
> DAX measures, dashboard design, and storytelling. I understand not just how
> to build a dashboard but why each visual choice matters for the audience
> that will use it."*

*For a Data Scientist role:*
> *"I built predictive models on top of a solid BI foundation — demand forecasting
> with Prophet and delay prediction with XGBoost. I understand how to deploy
> ML in a business context where interpretability matters as much as accuracy."*

---

# PART 11: QUICK REFERENCE — NUMBERS TO REMEMBER

| Fact | Number |
|------|--------|
| Total rows generated | 135,985 |
| Years of data | 3 (2022–2024) |
| Shipment records | 52,000 |
| Suppliers | 50 |
| Warehouses | 20 |
| Manufacturing plants | 15 |
| Python scripts | 4 |
| SQL files | 9 |
| DAX measures | 26 |
| Power BI dashboards | 6 |
| Dimension tables | 7 |
| Fact tables | 4 |
| Total project files | 57 |
| OTD achieved in data | 87.4% |
| Total revenue in data | $18.9 billion |
| Total transport spend | $78 million |
| Savings identified | $28.7 million |
| Delay model accuracy | 87.4% |
| Plant utilization 2022 | 39.9% (chip shortage) |
| Plant utilization 2024 | 82.3% (recovered) |

---

# PART 12: GLOSSARY — SUPPLY CHAIN TERMS TO KNOW

| Term | Definition |
|------|-----------|
| **OTD** | On-Time Delivery — % of shipments delivered by promised date |
| **Safety Stock** | Buffer inventory held to protect against unexpected demand or supply delays |
| **Lead Time** | Days from placing an order to receiving it |
| **SCAP** | Supplier Corrective Action Plan — formal process to fix underperforming suppliers |
| **JIT** | Just-In-Time — Toyota's system of receiving parts only when needed |
| **OEE** | Overall Equipment Effectiveness — Availability × Performance × Quality |
| **ABC Analysis** | Classifying inventory by value: A = top 20% value, B = next 30%, C = bottom 50% |
| **Fill Rate** | % of customer demand satisfied from available stock |
| **Perfect Order Rate** | % of orders that are on-time, complete, undamaged, correctly invoiced |
| **Stockout** | When inventory drops to zero and demand cannot be fulfilled |
| **Tier-1 Supplier** | Supplier that sells directly to the OEM (e.g., Bosch selling to Ford) |
| **Tier-2 Supplier** | Supplier that sells to a Tier-1 supplier |
| **OEM** | Original Equipment Manufacturer (Ford, GM, Toyota, Tesla, etc.) |
| **TMS** | Transportation Management System — software managing freight operations |
| **WMS** | Warehouse Management System — software managing warehouse operations |
| **ERP** | Enterprise Resource Planning — core business system (SAP, Oracle) |
| **VMI** | Vendor-Managed Inventory — supplier monitors and replenishes stock autonomously |
| **PPM** | Parts Per Million — quality metric (defects per million parts) |
| **Dual Sourcing** | Using two suppliers for the same part to reduce single-source dependency |
| **Pareto Principle** | 80% of problems come from 20% of causes |
| **Star Schema** | Database design for analytics: fact tables at center, dimensions around it |
| **DAX** | Data Analysis Expressions — Power BI's formula language |
| **VertiPaq** | Power BI's in-memory columnar storage engine |
| **MAPE** | Mean Absolute Percentage Error — measures forecast accuracy |
| **XGBoost** | Extreme Gradient Boosting — powerful ML algorithm for tabular data |
| **Prophet** | Facebook's open-source time series forecasting library |

---

*Document Version 1.0 — Automotive Supply Chain Intelligence Platform*
*Use this guide to prepare for interviews, presentations, and portfolio reviews.*
*The goal: explain this project confidently, clearly, and in business language.*
