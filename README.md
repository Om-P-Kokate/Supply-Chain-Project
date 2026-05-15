# Automotive Supply Chain Intelligence & Business Analytics Platform

> **Enterprise-grade Supply Chain Control Tower built to solve
> real operational challenges faced by U.S. automotive manufacturers
> including Ford, Tesla, General Motors, Toyota, Rivian, and BMW.**

---

## PROJECT OVERVIEW

This project is a **full-stack Business Intelligence and Supply Chain Analytics platform**
that simulates a real Supply Chain Control Tower used by automotive companies for
operational and executive decision-making.

It demonstrates strong skills in:
- **Supply Chain Analytics** — KPI design, trend analysis, root cause analysis
- **Business Intelligence** — Power BI dashboards, DAX measures, data storytelling
- **Data Engineering (lightweight)** — synthetic data generation, ETL pipeline, SQL schema
- **Predictive Analytics** — demand forecasting, delay prediction, risk scoring
- **Executive Communication** — KPI definitions, business insights, executive reports

---

## THE BUSINESS PROBLEMS THIS SOLVES

This platform is designed to answer the critical questions automotive supply chain
leadership asks every day:

| Business Question | Dashboard | KPI |
|------------------|-----------|-----|
| Which suppliers are causing delays? | Supplier Performance | On-Time Delivery % |
| Which warehouses are at stockout risk? | Inventory & Warehouse | Days of Supply |
| Which regions have the highest logistics costs? | Logistics & Transportation | Cost per Mile |
| Which suppliers have quality problems? | Supplier Performance | Defect Rate % |
| Which plants have the most downtime? | Manufacturing Operations | Downtime % |
| Which vehicle categories are growing? | Demand & Sales | Revenue Growth % |
| What are the biggest operational bottlenecks? | Executive Overview | Perfect Order Rate |
| Which routes are inefficient? | Logistics & Transportation | Transportation Cost Ratio |
| What is the overall supply chain health? | Executive Overview | All KPIs |
| What will demand look like next year? | Demand & Sales | Demand Forecast |

---

## PROJECT STRUCTURE

```
automotive-supply-chain-analytics/
│
├── data/
│   ├── raw/                    ← Generated synthetic datasets (135,985 rows)
│   │   ├── suppliers.csv       ← 50 U.S. automotive suppliers
│   │   ├── warehouses.csv      ← 20 distribution centers across 5 U.S. regions
│   │   ├── plants.csv          ← 15 manufacturing plants (Ford, GM, Tesla, Toyota...)
│   │   ├── products.csv        ← 30 automotive components & parts
│   │   ├── shipments.csv       ← 52,000 shipment records (2022-2024)
│   │   ├── inventory.csv       ← 30,900 inventory snapshots
│   │   ├── sales_demand.csv    ← 32,000 vehicle sales records
│   │   └── production.csv      ← 20,970 daily production records
│   │
│   ├── processed/              ← Cleaned, enriched data (Power BI ready)
│   └── exports/                ← Analytics outputs & KPI summaries
│
├── sql/
│   ├── schema/
│   │   ├── 01_create_tables.sql         ← Full star schema DDL
│   │   └── 02_populate_date_dim.sql     ← Date dimension population
│   ├── queries/
│   │   ├── 01_supplier_performance_analysis.sql
│   │   ├── 02_inventory_analysis.sql
│   │   ├── 03_logistics_transportation_analysis.sql
│   │   ├── 04_manufacturing_analysis.sql
│   │   ├── 05_sales_demand_analysis.sql
│   │   └── 06_executive_kpi_summary.sql
│   └── views/
│       └── 01_supply_chain_views.sql    ← 5 analytical views
│
├── notebooks/                  ← Jupyter notebooks for exploration
│
├── dashboards/
│   ├── dax_measures/
│   │   └── 01_supply_chain_kpi_measures.dax   ← 26 DAX measures
│   ├── data_model/
│   │   └── 02_power_bi_data_model.md          ← Star schema specification
│   └── wireframes/
│       └── 03_dashboard_wireframes.md          ← 6 dashboard wireframes
│
├── scripts/
│   ├── data_generation/
│   │   └── generate_datasets.py        ← Generates all synthetic data
│   ├── data_cleaning/
│   │   └── 01_data_cleaning_pipeline.py ← Full ETL cleaning pipeline
│   ├── analytics/
│   │   └── 01_supply_chain_analytics.py ← KPI calculations & analytics
│   └── forecasting/
│       └── 01_demand_forecasting.py     ← Prophet + XGBoost models
│
├── reports/
│   └── executive/
│       └── 01_executive_summary_report.md  ← Q4 2024 executive report
│
├── docs/
│   ├── kpi_definitions/
│   │   └── 01_supply_chain_kpi_definitions.md  ← 20+ KPI definitions
│   ├── data_dictionary/
│   │   └── 01_data_dictionary.md               ← Full data dictionary
│   ├── dashboard_docs/
│   │   └── 01_power_bi_dashboard_guide.md      ← Power BI build guide
│   └── business_insights/
│       └── 01_executive_business_insights.md   ← Analytics findings
│
├── README.md
└── requirements.txt
```

---

## DATASET OVERVIEW

**Total data generated: 135,985 rows across 8 tables, 3 years (2022-2024)**

| Table | Rows | Description |
|-------|------|-------------|
| suppliers.csv | 50 | U.S. automotive suppliers (Bosch, Denso, Magna, etc.) |
| warehouses.csv | 20 | Regional distribution centers across U.S. |
| plants.csv | 15 | Manufacturing plants (Ford, GM, Tesla, Toyota, Rivian) |
| products.csv | 30 | Components (ECUs, battery packs, body panels, etc.) |
| shipments.csv | 52,000 | Every inbound shipment with delay tracking |
| inventory.csv | 30,900 | Daily inventory snapshots by warehouse and product |
| sales_demand.csv | 32,000 | Vehicle sales with forecast vs actual |
| production.csv | 20,970 | Daily production records with downtime tracking |

**Realistic data features:**
- COVID-era supply disruptions visible in 2022 data (lower utilization, longer delays)
- Semiconductor shortage impact (extended lead times, higher delay rates)
- Seasonal demand patterns (Q4 peak, Q1 trough)
- Strong correlation between supplier risk scores and actual defect rates
- EV demand growth acceleration 2022 → 2024
- Regional cost differences (Southeast logistics corridor higher cost)

---

## KEY KPIs TRACKED

### Supply Chain KPIs
| KPI | Definition | Target | Dashboard |
|-----|------------|--------|-----------|
| On-Time Delivery % | % shipments delivered on or before promised date | ≥ 95% | Executive, Supplier, Logistics |
| Inventory Turnover | Cost of goods / Average inventory value | 8-12x | Inventory |
| Fill Rate % | Units delivered / Units ordered × 100 | ≥ 98% | Executive, Inventory |
| Stockout Rate % | % of SKU-locations below safety stock | < 2% | Inventory |
| Perfect Order Rate | On-time + complete + undamaged + correct docs | ≥ 95% | Executive |
| Supplier Reliability | Composite supplier performance score (0-100) | ≥ 85 | Supplier |
| Transportation Cost Ratio | Freight cost / Revenue × 100 | < 5% | Logistics |
| Average Lead Time | Average days from order to delivery | Varies | Supplier |

### Manufacturing KPIs
| KPI | Definition | Target |
|-----|------------|--------|
| Plant Utilization % | Actual production / Planned capacity × 100 | 80-90% |
| Downtime % | Unplanned downtime hours / Scheduled hours × 100 | < 5% |
| Defect Rate % | Defective units / Total units × 100 | < 1% |
| OEE | Availability × Performance × Quality | ≥ 85% |

### Sales KPIs
| KPI | Definition | Target |
|-----|------------|--------|
| Forecast Accuracy % | 1 - MAPE × 100 | ≥ 90% |
| Revenue Growth % YoY | (Current - Prior) / Prior × 100 | > 0% |
| EV Revenue Mix % | EV Revenue / Total Revenue × 100 | Tracking |

---

## POWER BI DASHBOARDS

### Dashboard Architecture
The project includes 6 interconnected Power BI dashboards built on a clean star schema.

```
Executive Overview Dashboard
        │
        ├─→ Supplier Performance & Risk Dashboard
        ├─→ Inventory & Warehouse Management Dashboard
        ├─→ Logistics & Transportation Dashboard
        ├─→ Demand & Sales Analytics Dashboard
        └─→ Manufacturing Operations Dashboard
```

### Dashboard 1: Executive Overview
**Audience:** CEO, COO, VP Supply Chain
**Purpose:** Real-time supply chain health monitoring

KPI Cards: OTD%, Total Shipments, Inventory Value, Supplier Reliability, Transportation Cost, Plant Utilization, Stockout Rate, Fill Rate

Visuals: OTD trend line (24 months), Shipments by Region map, Revenue by vehicle category donut, Supplier risk heat table, Plant utilization bars

### Dashboard 2: Supplier Performance & Risk
**Audience:** VP Procurement, Category Managers
**Purpose:** Supplier evaluation and corrective action prioritization

Key Visual: Supplier Risk Matrix (scatter: OTD% vs Defect Rate, size = contract value, color = risk tier) — immediately shows which suppliers are high-value AND high-risk.

### Dashboard 3: Inventory & Warehouse Management
**Audience:** Operations, Warehouse Managers, Inventory Planners
**Purpose:** Real-time stockout risk monitoring and warehouse efficiency

Action Table: Items below safety stock sorted by days of supply — the "act on this today" list.

### Dashboard 4: Logistics & Transportation
**Audience:** Logistics Manager, Transportation Analysts
**Purpose:** Freight cost optimization and carrier management

Key Insight: Southeast logistics corridor 18% above benchmark — quantified cost reduction opportunity.

### Dashboard 5: Demand & Sales Analytics
**Audience:** Sales Leadership, Commercial Finance, Production Planning
**Purpose:** Revenue performance and demand forecasting

Key Insight: EV demand growing 67% YoY, systematically outpacing forecasts — action required on planning model.

### Dashboard 6: Manufacturing Operations
**Audience:** VP Operations, Plant Managers
**Purpose:** Plant efficiency and downtime root cause analysis

Key Visual: Downtime Pareto Chart — shows which causes to fix first for maximum impact.

---

## PREDICTIVE ANALYTICS

### 1. Demand Forecasting (Prophet / Trend-based)
- **12-month vehicle demand forecast** by category
- Incorporates automotive seasonality (Q4 peak, Q1 trough)
- Provides confidence intervals for inventory planning
- Output: `data/exports/demand_forecast_2025.csv`

### 2. Shipment Delay Prediction (XGBoost)
- **Binary classifier**: Will this shipment be delayed?
- Model accuracy: ~87.4%, ROC-AUC: ~63%
- Top predictors: Supplier risk score, delivery performance history, shipping month
- Business use: Proactive alerts to operations before delays happen
- Output: `data/exports/delay_prediction_feature_importance.csv`

### 3. Supplier Risk Scoring (Weighted Scorecard Model)
- **Composite risk score (0-100)** for all 50 suppliers
- Components: OTD performance (30%), defect rate (25%), lead time (20%), contract concentration (15%), base risk (10%)
- Output: `data/exports/supplier_risk_scores_ml.csv`

---

## SQL ANALYTICS LAYER

### Star Schema Design
```
                    dim_date
                       │
dim_supplier ──── fact_shipments ──── dim_warehouse
                       │
dim_product ────────────────────────── dim_plant

                    dim_date
                       │
dim_warehouse ── fact_inventory ──── dim_product

                    dim_date
                       │
dim_vehicle ───── fact_sales ──────── dim_region

                    dim_date
                       │
dim_plant ────── fact_production
```

**Why Star Schema?**
- Optimized for Power BI's VertiPaq columnar engine
- Enables all DAX time intelligence functions
- Simpler queries with fewer joins
- Faster dashboard performance than normalized schema

### Key SQL Queries Included
1. Supplier performance scorecard with OTD%, defect rates, lead times
2. Inventory ABC analysis and stockout risk identification
3. Transportation cost by route, carrier, and mode comparison
4. Manufacturing downtime Pareto analysis
5. YoY revenue and demand trend analysis
6. Master executive KPI summary (single query, all KPIs)

---

## HOW TO RUN THIS PROJECT

### Prerequisites
```bash
pip install -r requirements.txt
```

### Step 1: Generate Data
```bash
python scripts/data_generation/generate_datasets.py
```
This creates 135,985 rows of realistic synthetic automotive supply chain data in `data/raw/`.

### Step 2: Clean & Process Data
```bash
python scripts/data_cleaning/01_data_cleaning_pipeline.py
```
This validates, enriches, and saves analysis-ready data to `data/processed/`.
Also generates `docs/data_quality_report.txt`.

### Step 3: Run Analytics
```bash
python scripts/analytics/01_supply_chain_analytics.py
```
Calculates all KPIs and exports summaries to `data/exports/`.

### Step 4: Run Forecasting
```bash
pip install prophet  # optional — falls back to trend model if not installed
python scripts/forecasting/01_demand_forecasting.py
```
Generates 12-month demand forecast and delay prediction model.

### Step 5: Build Power BI Dashboards
1. Open Power BI Desktop
2. Import all files from `data/processed/`
3. Follow the guide in `docs/dashboard_docs/01_power_bi_dashboard_guide.md`
4. Copy DAX measures from `dashboards/dax_measures/01_supply_chain_kpi_measures.dax`
5. Build visuals per wireframes in `dashboards/wireframes/03_dashboard_wireframes.md`

---

## KEY BUSINESS INSIGHTS GENERATED

From the 2022-2024 analysis, this platform identified:

1. **$28.7M in addressable improvement opportunities** across supplier management,
   inventory optimization, logistics consolidation, and plant efficiency

2. **8 suppliers below 85% OTD** responsible for 68% of all delivery delays
   — classic 80/20 Pareto pattern, immediately actionable

3. **4 warehouses at CRITICAL stockout risk** with days-of-supply below 7 days
   — requires emergency replenishment action

4. **Southeast logistics corridor 18% above benchmark** — carrier consolidation
   and intermodal conversion can deliver $2.8M annual savings

5. **EV demand growing 67% YoY** and systematically outpacing forecasts by 5-7%
   — forecast model needs recalibration; battery supply at risk

6. **3 plants below 75% utilization** absorbing fixed costs inefficiently
   — equipment investment and product mix shift recommended

---

## SKILLS DEMONSTRATED

| Skill Area | Evidence |
|-----------|----------|
| **Supply Chain Domain Knowledge** | KPI definitions, benchmark targets, business recommendations, industry context throughout |
| **Business Intelligence** | 6-dashboard Power BI architecture, DAX measures, storytelling strategy |
| **SQL / Data Modeling** | Star schema DDL, complex analytical queries, 5 views, KPI calculations |
| **Python / Pandas** | Data generation, cleaning pipeline, analytics engine, forecasting |
| **Machine Learning** | XGBoost delay predictor, demand forecasting, supplier risk scoring |
| **Executive Communication** | KPI definitions, executive reports, business insights, recommendations |
| **Data Governance** | Data dictionary, quality report, data quality checks throughout |

---

## TECH STACK

| Technology | Purpose | Where Used |
|-----------|---------|-----------|
| **Power BI Desktop** | Dashboard development | 6 executive dashboards |
| **DAX** | KPI measures and calculations | 26 measures |
| **SQL** | Data model, queries, analytics | Schema, 6 query files, 5 views |
| **Python** | Data generation, cleaning, analytics | 4 scripts |
| **Pandas** | Data manipulation and analysis | All Python scripts |
| **NumPy** | Statistical calculations | Analytics and generation |
| **XGBoost** | Shipment delay prediction | Forecasting script |
| **Prophet** | Demand forecasting | Forecasting script |


---

*This project simulates a real Supply Chain Control Tower. The goal is to demonstrate
how data analytics drives better supply chain decisions in the automotive industry.*
