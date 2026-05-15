# Power BI Dashboard Implementation Guide
## Automotive Supply Chain Intelligence Platform

---

## HOW TO USE THIS GUIDE

This guide explains how to BUILD each Power BI dashboard from scratch.
It is written for someone with intermediate Power BI knowledge.
Each section covers:
- What to build and why
- Exact visual configurations
- DAX measures to create
- Interaction settings
- Design specifications

---

## POWER BI SETUP CHECKLIST

Before building dashboards, complete these setup steps:

### Step 1: Import Data
1. Open Power BI Desktop
2. Home → Get Data → Text/CSV
3. Import these files from `data/processed/`:
   - suppliers_clean.csv → rename to `dim_supplier`
   - warehouses_clean.csv → rename to `dim_warehouse`
   - plants_clean.csv → rename to `dim_plant`
   - products_clean.csv → rename to `dim_product`
   - shipments_clean.csv → rename to `fact_shipments`
   - inventory_clean.csv → rename to `fact_inventory`
   - sales_clean.csv → rename to `fact_sales`
   - production_clean.csv → rename to `fact_production`

### Step 2: Create Date Dimension
In Power Query or DAX, create dim_date:
```
dim_date = 
CALENDAR(DATE(2022,1,1), DATE(2025,12,31))
```
Then add columns:
```dax
Year = YEAR([Date])
Month = MONTH([Date])
MonthName = FORMAT([Date], "MMM")
Quarter = QUARTER([Date])
QuarterLabel = "Q" & FORMAT(QUARTER([Date]),"0") & " " & FORMAT(YEAR([Date]),"0000")
DayOfWeek = WEEKDAY([Date])
IsWeekend = IF(WEEKDAY([Date]) IN {1,7}, TRUE, FALSE)
```

### Step 3: Build the Star Schema
Go to Model View and create these relationships:

| From (Many side) | → | To (One side) | Cardinality |
|-----------------|---|---------------|-------------|
| fact_shipments[supplier_id] | → | dim_supplier[supplier_id] | Many-to-One |
| fact_shipments[warehouse_id] | → | dim_warehouse[warehouse_id] | Many-to-One |
| fact_shipments[shipment_date] | → | dim_date[Date] | Many-to-One |
| fact_inventory[warehouse_id] | → | dim_warehouse[warehouse_id] | Many-to-One |
| fact_inventory[snapshot_date] | → | dim_date[Date] | Many-to-One |
| fact_sales[order_date] | → | dim_date[Date] | Many-to-One |
| fact_production[plant_id] | → | dim_plant[plant_id] | Many-to-One |
| fact_production[production_date] | → | dim_date[Date] | Many-to-One |

**IMPORTANT:** Right-click dim_date → "Mark as Date Table" → select the Date column.
This enables all DAX time intelligence functions.

### Step 4: Set Up Color Theme
Create a custom theme JSON file with these colors:
```json
{
  "name": "Automotive Supply Chain",
  "dataColors": ["#1F3864","#C9A84C","#107C10","#FF8C00","#D13438","#605E5C"],
  "background": "#FFFFFF",
  "foreground": "#252423",
  "tableAccent": "#1F3864"
}
```
Apply via: View → Themes → Browse for themes → select your JSON

---

## DASHBOARD 1: EXECUTIVE OVERVIEW

**Purpose:** Single-screen health check for C-suite. Answers "Is our supply chain OK today?"
**Audience:** CEO, COO, VP Supply Chain
**Refresh:** Daily at 7:00 AM EST (before morning stand-up)
**Target load time:** < 3 seconds

### Page Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  HEADER: "Supply Chain Executive Dashboard" | Date Slicer | YTD/QTD │
├────────┬────────┬────────┬────────┬────────┬────────┬────────┬──────┤
│  OTD % │ Total  │ Inv    │ Supplt │ Trans  │  Plant │Stockout│ Fill │
│  91.4% │ Ships  │ Value  │ Reliab │  Cost  │  Util  │  Rate  │ Rate │
│ 🟡+4.1%│51,820  │$192.4M │  83.2  │ $42.8M │ 82.4%  │  4.2%  │96.8% │
├────────┴────────┴────────┴────────┴────────┴────────┴────────┴──────┤
│                    OTD % Trend (Line Chart - 24 months)              │
│                                                              [95% target line] │
├──────────────────────────────┬──────────────────────────────────────┤
│   Shipments by Region (Map)  │  Revenue by Vehicle Category (Donut) │
│   [Bubble size = volume]     │  [EV highlighted]                    │
├──────────────────────────────┼──────────────────────────────────────┤
│  Supplier Risk Heat Table    │  Plant Utilization Bar Chart         │
│  [Red/Yellow/Green cells]    │  [With 80% target line]              │
└──────────────────────────────┴──────────────────────────────────────┘
```

### KPI Cards (Row 1) — 8 cards

**Card 1: On-Time Delivery %**
- Measure: `[On-Time Delivery %]`
- Value format: `0.0%`
- KPI comparison: vs. 95% target
- Conditional formatting: Green ≥ 95%, Yellow 85-95%, Red < 85%
- Show trend arrow vs prior quarter

**Card 2: Total Shipments**
- Measure: `[Total Shipments]`
- Format: `#,##0`
- No target (informational)

**Card 3: Total Inventory Value**
- Measure: `[Total Inventory Value]`
- Format: `$#,##0.0,,M` (shows in millions)
- Target: Monitor for ±20% vs plan

**Card 4: Supplier Reliability Score**
- Measure: `[Avg Supplier Reliability Score]`
- Format: `0.0`
- Target: ≥ 85
- Conditional formatting: Green ≥ 85, Yellow 75-85, Red < 75

**Card 5: Transportation Cost**
- Measure: `[Total Transportation Cost]`
- Format: `$#,##0.0,,M`
- Comparison: vs. prior year

**Card 6: Plant Utilization %**
- Measure: `[Avg Plant Utilization %]`
- Format: `0.0%`
- Target: 80-90% (both above and below need attention)

**Card 7: Stockout Rate %**
- Measure: `[Stockout Rate %]`
- Format: `0.0%`
- Conditional formatting: Green < 2%, Yellow 2-5%, Red > 5%
- Lower is better (reverse color logic)

**Card 8: Fill Rate %**
- Measure: `[Fill Rate %]`
- Format: `0.0%`
- Target: ≥ 98%

### Visual 1: OTD % Trend Line

**Chart type:** Line chart
**X-axis:** dim_date[QuarterLabel] (or MonthName for monthly view)
**Y-axis:** [On-Time Delivery %]
**Second line:** Constant line at 95% (Target)
**Colors:** Primary line = #1F3864, Target line = #D13438 (dashed)
**Tooltip:** Show: Period, OTD%, # of Delayed Shipments, Top Delay Reason
**Bookmark:** Toggle between Monthly and Quarterly view

**DAX for this visual:**
```dax
On-Time Delivery % = 
DIVIDE(
    COUNTROWS(FILTER(fact_shipments, fact_shipments[is_on_time] = 1)),
    COUNTROWS(fact_shipments),
    0
) * 100
```

### Visual 2: Shipments by Region Map

**Chart type:** Filled Map (or ArcGIS Map if available)
**Location field:** dim_warehouse[state]
**Color saturation:** [Total Shipments] or [On-Time Delivery %]
**Tooltip:** State, Shipment count, OTD%, Avg Transport Cost
**Color scheme:** Dark blue (high volume) to light blue (low volume)

### Visual 3: Revenue by Vehicle Category Donut

**Chart type:** Donut chart
**Legend:** dim_vehicle[vehicle_category]
**Values:** [Total Revenue USD]
**Colors:** EV = #107C10 (green), Hybrid = #C9A84C (gold), ICE = #605E5C (gray)
**Center label:** Total Revenue (use text box)
**Tooltip:** Category, Revenue, Units, YoY Growth

### Visual 4: Supplier Risk Heat Table

**Chart type:** Matrix visual
**Rows:** dim_supplier[supplier_name]
**Columns:** dim_supplier[risk_tier]
**Values:** [OTD %], [Defect Rate %], [Supplier Reliability Score]
**Conditional formatting on OTD %:**
- Background color rules: ≥ 95% → green, 85-95% → yellow, < 85% → red
**Sorting:** By Reliability Score ascending (worst first)
**Max rows shown:** 15 (scroll for more)

### Visual 5: Plant Utilization Bar Chart

**Chart type:** Horizontal bar chart
**Y-axis:** dim_plant[plant_name]
**X-axis:** [Plant Utilization %]
**Color:** Conditional — red < 70%, yellow 70-80%, green 80-90%, orange > 95%
**Reference line:** Vertical line at 80% (lower target) and 90% (upper target)
**Data labels:** Show percentage on bars

### Slicers (Filters)
- Date range slicer (dim_date[Date]) — between style
- OEM Company slicer (dim_plant[oem_company]) — dropdown
- Region slicer (dim_warehouse[region]) — list style

---

## DASHBOARD 2: SUPPLIER PERFORMANCE & RISK

**Purpose:** Procurement's daily tool for managing supplier relationships
**Audience:** VP Procurement, Category Managers, Procurement Analysts
**Key Questions Answered:**
- Which suppliers are underperforming?
- Which suppliers are highest risk?
- How are suppliers trending over time?
- Which suppliers need corrective action?

### Page Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  HEADER: "Supplier Performance & Risk Dashboard" | Region | OEM | Date│
├────────────┬────────────┬────────────┬────────────┬──────────────────┤
│  Avg OTD % │ Avg Lead   │ High Risk  │ Avg Defect │  Suppliers on    │
│   91.4%    │  12.3 days │  Suppliers │   1.8%     │  SCAP: 4         │
├────────────┴────────────┴────────────┴────────────┴──────────────────┤
│    Supplier Scorecard Table (Ranked by Performance)                  │
│    Rank | Supplier | Region | OTD% | Defect% | Lead Time | Score | Tier│
├────────────────────────────┬─────────────────────────────────────────┤
│  OTD % by Supplier (Bar)   │  Supplier Risk Matrix (Scatter Plot)    │
│  [Color by risk tier]      │  X=OTD%, Y=Defect Rate, Size=Contract $ │
├────────────────────────────┼─────────────────────────────────────────┤
│  Lead Time Trend (Line)    │  Delay Reason Breakdown (Treemap)       │
│  [By supplier region]      │  [Size=frequency, Color=category]       │
└────────────────────────────┴─────────────────────────────────────────┘
```

### Visual: Supplier Scorecard Table

This is the CENTERPIECE of the dashboard.

**Chart type:** Table or Matrix visual
**Columns:**
1. Rank (calculated column)
2. Supplier Name (with drill-through to Supplier Detail page)
3. Region
4. Primary Component
5. OTD % (conditional format — traffic light colors)
6. Defect Rate % (conditional format — lower is better)
7. Lead Time (days)
8. Reliability Score (progress bar style)
9. Risk Tier (colored badge using conditional formatting)
10. Performance Tier

**Drill-through setup:**
- Right-click a supplier row → "Drill through" → Supplier Detail page
- Supplier Detail page shows: shipment history, defect trends, cost analysis for that one supplier

### Visual: Supplier Risk Matrix (Scatter Plot)

**Chart type:** Scatter chart
**X-axis:** [OTD %] (higher = better — want right side)
**Y-axis:** [Defect Rate %] (lower = better — want bottom)
**Size:** dim_supplier[annual_contract_value_usd]
**Color/Legend:** dim_supplier[risk_tier]
**Colors:** Low Risk = green, Medium = yellow, High = orange, Critical = red
**Quadrant lines:** Add constant lines: X=90% (OTD target), Y=1% (defect target)

**How to read this chart:**
- Bottom-right quadrant = BEST (high OTD, low defects)
- Top-left quadrant = WORST (low OTD, high defects)
- Large circles in top-left = HIGHEST PRIORITY (high-value, poor performance)

### Visual: Delay Reason Treemap

**Chart type:** Treemap
**Category:** fact_shipments[delay_reason]
**Values:** COUNTROWS of delayed shipments
**Colors:** Weather = blue, Supplier = orange, Carrier = purple, Quality = red
**Tooltip:** Reason, Count, % of Total Delays, Avg Delay Days

---

## DASHBOARD 3: INVENTORY & WAREHOUSE MANAGEMENT

**Purpose:** Operations tool for monitoring inventory health and warehouse efficiency
**Audience:** Supply Chain Operations, Warehouse Managers, Inventory Planners
**Key Questions Answered:**
- Which warehouses are at stockout risk?
- What products need immediate reorder?
- Which warehouses are over or under utilized?
- What is the inventory investment by category?

### Key Visuals

**1. Inventory Health Status Map**
- Warehouse locations plotted on US map
- Color: Green = Healthy, Yellow = Warning, Red = Critical
- Size of bubble = inventory value
- Click a bubble → drill to warehouse detail

**2. Stockout Risk Table**
- Filtered to only show items within 10 days of stockout
- Columns: Warehouse, Product, Stock Qty, Safety Stock, Days of Supply, Status
- Sorted by Days of Supply ascending (most urgent first)
- Auto-refreshes — this is the "action table"

**3. Warehouse Utilization Gauge Charts**
- One gauge per warehouse (or use a bar chart if too many)
- Green zone: 75-85%, Yellow: 60-75% and 85-95%, Red: <60% or >95%
- Target: 80%

**4. ABC Analysis Pie/Donut**
- A Items: 20% of SKUs = 70% of value (typically)
- B Items: 30% of SKUs = 20% of value
- C Items: 50% of SKUs = 10% of value
- Action: Focus tight controls on A items

**5. Inventory Value Trend (Line)**
- Monthly inventory value over time
- Show seasonality (Q4 build-up before peak demand)
- Compare current year vs prior year

### Critical DAX Measures for Dashboard 3:

```dax
-- Items Below Safety Stock (stockout risk count)
Items Below Safety Stock = 
COUNTROWS(
    FILTER(
        fact_inventory,
        fact_inventory[stock_quantity] < fact_inventory[safety_stock_level]
    )
)

-- Stockout Rate %
Stockout Rate % = 
DIVIDE([Items Below Safety Stock], COUNTROWS(fact_inventory), 0) * 100

-- Average Days of Supply
Avg Days of Supply = 
AVERAGE(fact_inventory[days_of_supply])

-- Warehouse Utilization %
Warehouse Utilization % = 
AVERAGE(dim_warehouse[current_utilization_pct])
```

---

## DASHBOARD 4: LOGISTICS & TRANSPORTATION

**Purpose:** Logistics cost management and carrier performance analysis
**Audience:** Logistics Manager, Transportation Analysts, Finance
**Key Questions:**
- Which routes are most expensive?
- Which carriers are underperforming?
- Where are transportation costs rising?
- How can we reduce freight spend?

### Key Visuals

**1. Transportation Cost by Mode (Bar Chart)**
- X: Transportation Mode (Truck FTL, Truck LTL, Rail, Air)
- Y: Total Cost OR Cost per Shipment
- Include OTD % as a second axis (line)
- Insight: Shows cost vs reliability trade-off

**2. Route Performance Table**
- Columns: Route, Mode, Carrier, Avg Cost, Avg Cost/Mile, OTD%, Delay Reason
- Sorted by: Total Cost descending
- Highlight: Routes > $5K avg cost AND < 90% OTD

**3. Monthly Transportation Cost Trend**
- Line chart showing cost trend over 24 months
- Add fuel cost overlay
- Highlight: COVID disruption period (2022), recovery

**4. Carrier Ranking Table**
- Carrier, Total Shipments, OTD%, Avg Cost, Total Spend, Rating
- Conditional format OTD column
- Use this for carrier contract negotiations

**5. Delay Reason Waterfall (or Bar)**
- Show % of delays by reason
- Prioritize which reasons to attack first

**6. Regional Cost Heatmap**
- US map colored by avg cost per mile
- Immediately shows Southeast as high-cost region

---

## DASHBOARD 5: DEMAND & SALES ANALYTICS

**Purpose:** Commercial planning tool for demand visibility and forecast management
**Audience:** Sales Leadership, Commercial Finance, Production Planning
**Key Questions:**
- Which vehicle categories are growing?
- How accurate are our forecasts?
- Which regions are growing fastest?
- What is the EV demand trajectory?

### Key Visuals

**1. Revenue by Category Waterfall Chart**
- Shows contribution to total revenue change YoY
- Green bars = categories growing, Red = declining
- Immediately shows EV growth vs ICE decline

**2. Forecast vs Actual Line Chart**
- Monthly: Forecasted demand (dotted line) vs Actual units sold (solid line)
- Shaded area = forecast error
- Shows systematic under-forecast starting Q2 2024 (EV surge)

**3. Regional Sales Map**
- US filled map, color = revenue
- Size/shade proportional to growth rate
- Click region → drill to vehicle mix for that region

**4. EV Penetration Trend**
- Area chart showing EV % of total units over time
- Show separately: Tesla, Ford EV, GM EV, Rivian
- Target: Show trajectory toward EV tipping point

**5. Top 10 Vehicle Models Table**
- Model, Category, Units, Revenue, Avg Price, YoY Growth
- Sort by Revenue descending
- Conditional format Growth column

### Time Intelligence in This Dashboard:

```dax
-- Revenue Year-to-Date
Revenue YTD = 
TOTALYTD(SUM(fact_sales[revenue_usd]), dim_date[Date])

-- Revenue Same Period Last Year
Revenue SPLY = 
CALCULATE(
    SUM(fact_sales[revenue_usd]),
    SAMEPERIODLASTYEAR(dim_date[Date])
)

-- Revenue Growth %
Revenue Growth % = 
DIVIDE([Revenue MTD] - [Revenue MTD SPLY], [Revenue MTD SPLY], 0) * 100

-- Forecast Accuracy
Forecast Accuracy % = 
1 - DIVIDE(
    SUMX(fact_sales, ABS(fact_sales[units_sold] - fact_sales[forecasted_demand])),
    SUM(fact_sales[units_sold]),
    0
)
```

---

## DASHBOARD 6: MANUFACTURING OPERATIONS

**Purpose:** Plant-level production monitoring and efficiency analysis
**Audience:** VP Operations, Plant Managers, Manufacturing Engineers
**Key Questions:**
- Which plants are underperforming?
- What is causing downtime?
- How is defect rate trending?
- Are we meeting production targets?

### Key Visuals

**1. Plant Utilization Bullet Chart**
- For each plant: Actual utilization vs target range (80-90%)
- Bullets show: Poor (<70%), OK (70-80%), Good (80-90%), Excellent (>90%)
- Native Power BI: Use bar chart with reference lines as substitute

**2. Downtime Pareto Chart**
- X: Downtime reason (sorted by frequency)
- Y: Hours of downtime
- Second axis: Cumulative % (Pareto principle)
- Focus attention on top 2-3 reasons = 80% of total downtime

**3. Production Actual vs Planned (Area/Line)**
- Monthly: Planned production (dotted) vs Actual (solid) vs Good Units (shaded)
- Shows production gaps and trend

**4. OEE Gauge or Card Visual**
- Single number: OEE = Availability × Performance × Quality
- Target: ≥ 85% (world-class)
- Color coded: < 65% Red, 65-85% Yellow, ≥ 85% Green

**5. Defect Rate by Plant (Bar)**
- Horizontal bars sorted by defect rate
- Reference line at 1% target
- Color: > 2% = red, 1-2% = yellow, < 1% = green

**6. Downtime Hours by Month and Plant (Stacked Bar)**
- Each bar = one month
- Stacked segments = different plants
- Color = downtime reason category

---

## BOOKMARKS & NAVIGATION SETUP

Create these bookmarks for easy navigation:
1. "Executive Overview" (default landing page)
2. "Supplier Detail View" (drill-through from supplier name)
3. "Warehouse Detail View" (drill-through from warehouse)
4. "YTD View" (all dashboards filtered to current year)
5. "Prior Year Comparison" (show YoY comparison overlays)

**Navigation Buttons:**
Place a button row at the top of each page:
[Executive] [Supplier] [Inventory] [Logistics] [Sales] [Manufacturing]

Style: Custom buttons with page icons, hover highlight

---

## POWER BI PERFORMANCE TIPS

1. **Aggregations:** Pre-aggregate large tables in Power Query
   - fact_shipments: Create a monthly summary table
   - fact_inventory: Keep only latest snapshot per warehouse/product for "current" dashboard

2. **Import vs DirectQuery:** Use Import mode for all tables in this project
   - Import = faster visuals but data refreshes on schedule
   - DirectQuery = always live but slower (not needed for daily reporting)

3. **Reduce columns:** Remove columns not used in visuals from the data model
   - This reduces model size and speeds up all visuals

4. **Avoid calculated columns:** Use measures instead wherever possible
   - Measures are calculated on the fly (use filter context)
   - Calculated columns are stored in the model (increase size)

5. **Date table:** Always have a dedicated date dimension marked as date table
   - Never use dates directly from fact tables for time intelligence

---

*Power BI Dashboard Guide v1.0 — Automotive Supply Chain Intelligence Platform*
