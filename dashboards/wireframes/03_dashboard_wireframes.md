# Power BI Dashboard Wireframe Specifications
# Automotive Supply Chain Analytics

**File:** `03_dashboard_wireframes.md`
**Project:** Automotive Supply Chain Analytics
**Last Updated:** 2026-05-15
**Total Dashboards:** 6
**Target Platform:** Power BI Desktop / Power BI Service (Desktop Layout: 1366×768 default)

---

## Global Design System

### Color Palette

| Role | Color Name | Hex Code | Usage |
|---|---|---|---|
| **Primary Background** | Dark Navy | `#1F3864` | Page background, header bars, navigation |
| **Accent / Highlight** | Automotive Gold | `#C9A84C` | KPI card borders, active state, premium metrics |
| **Success / On Track** | Microsoft Green | `#107C10` | Positive values, on-track status, good performance |
| **Warning / At Risk** | Amber Orange | `#FF8C00` | Warning states, approaching threshold, medium risk |
| **Danger / Critical** | Alert Red | `#D13438` | Critical alerts, off-track, high risk, negative trend |
| **Neutral / Informational** | Slate Gray | `#605E5C` | Secondary text, gridlines, inactive elements |
| **Card Background** | Off White | `#F3F2F1` | KPI card fill, table row alternation |
| **Chart Series 1** | Steel Blue | `#2E74B5` | Primary chart series |
| **Chart Series 2** | Teal | `#00B0F0` | Secondary chart series |
| **Chart Series 3** | Light Gold | `#FFD966` | Third chart series |
| **Page Background** | Light Gray | `#E8E8E8` | Canvas background (outside cards) |

### Typography

| Element | Font | Size | Weight |
|---|---|---|---|
| Page Title | Segoe UI | 20pt | Bold |
| Section Header | Segoe UI | 14pt | Semibold |
| KPI Value | Segoe UI | 28pt | Bold |
| KPI Label | Segoe UI | 10pt | Regular |
| Body Text | Segoe UI | 11pt | Regular |
| Tooltip | Segoe UI | 10pt | Regular |

### Navigation Bar (All Dashboards)

A persistent left-side navigation panel (60px wide, dark navy `#1F3864`) contains icon buttons linking to all 6 dashboards. The active dashboard icon is highlighted with gold `#C9A84C`. Clicking an icon uses Power BI bookmarks to navigate between report pages.

Navigation icons (top to bottom):
1. Executive Overview (house icon)
2. Supplier Performance (handshake icon)
3. Inventory & Warehouse (box/warehouse icon)
4. Logistics & Transportation (truck icon)
5. Demand & Sales (chart-up icon)
6. Manufacturing Operations (gear/factory icon)

### Standard Filter Panel (All Dashboards)

A collapsible right-side filter panel (200px wide when open) contains global filters that persist across all pages via Power BI sync slicers:
- **Date Range** — Between slicer using `dim_date[date]`
- **Region** — Dropdown on `dim_region[country_name]`
- **Vehicle Family** — Dropdown on `dim_vehicle[model_family]`
- **Reset Filters** — Bookmark button clearing all slicers to default

### Standard Page Layout Template

```
┌─────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  PAGE HEADER (Dark Navy bar, full width, 50px tall)             │
│       │  Title text (left) | Last Refresh timestamp (right)             │
├───────┼─────────────────────────────────────────────────────────────────┤
│  NAV  │  KPI ROW (4-6 KPI cards, equal width, 120px tall)               │
│  BAR  ├─────────────────────────────────────────────────────────────────┤
│  60px │  MAIN CHART AREA (2-3 charts, varies per dashboard, ~400px)     │
│       │                                                                 │
│       ├─────────────────────────────────────────────────────────────────┤
│       │  DETAIL TABLE / BOTTOM CHARTS (100-150px)                       │
└───────┴─────────────────────────────────────────────────────────────────┘
```

---

## Dashboard 1: Executive Overview

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Executive Overview |
| **Page Name in Power BI** | Executive_Overview |
| **Purpose** | Single-pane-of-glass view of the entire automotive supply chain for C-suite and senior management |
| **Target Audience** | CEO, COO, CFO, VP Supply Chain, Board Members |
| **Refresh Frequency** | Daily (automated at 06:00 AM local time) |
| **Default Date Filter** | Current calendar year (YTD) |
| **Layout Dimensions** | 1366 × 768px (16:9) |

### Business Questions Answered

1. Is the overall supply chain performing on target this month/year?
2. What is revenue performance vs prior year and vs budget?
3. Are there any critical supplier, inventory, or delivery issues requiring executive attention?
4. What is the perfect order rate and which component is failing most?
5. Is manufacturing keeping pace with sales demand?
6. Which regions are growing and which are declining?

### Recommended Executive Actions Based on Insights

- If Perfect Order Rate < 85%: Schedule cross-functional root cause review with Supply Chain, Quality, and Logistics VPs.
- If Revenue YTD < 95% of budget: Trigger demand acceleration or supply chain cost reduction program.
- If Supplier Risk Index average > 60: Initiate dual-sourcing RFQ process.
- If On-Time Delivery % < 90%: Escalate to Tier 1 supplier leadership meetings.
- If Inventory Turnover < 8x annualized: Review slow-moving SKUs for write-off or reorder point adjustment.

---

### Layout: Executive Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │  AUTOMOTIVE SUPPLY CHAIN — EXECUTIVE OVERVIEW      Last Refresh: Today 06:00│
├────────┼─────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────┤
│        │ (A) │     (B)      │     (C)      │     (D)      │     (E)      │   (F)    │
│        │ Rev │   Revenue    │  On-Time     │  Perfect     │  Inventory   │ Supplier │
│  NAV   │ YTD │  Growth %    │ Delivery %   │ Order Rate   │  Turnover    │  Risk    │
│  BAR   │ KPI │    YoY KPI   │    KPI       │    KPI       │    KPI       │  Index   │
│        ├─────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────┤
│        │         (G) Revenue Trend                │  (H) Regional Performance Map    │
│        │    Area chart: Monthly Revenue           │  Filled map: Revenue by region   │
│        │    Current Year vs Prior Year            │  Color: Revenue Growth % YoY     │
│        │                                          │                                  │
│        ├──────────────────────────────────────────┴──────────────────────────────────┤
│        │  (I) Perfect Order Waterfall  │  (J) Supply Chain  │  (K) Top 5 Alerts     │
│        │  Decomposition chart          │  Scorecard Table   │  Text card list        │
└────────┴───────────────────────────────┴────────────────────┴────────────────────────┘
```

---

### KPI Cards — Executive Overview

#### Card A: Revenue YTD

| Property | Value |
|---|---|
| **Measure** | `[TI] Revenue YTD` |
| **Display Format** | $###.#M (millions) |
| **Subtitle** | "vs $[Budget YTD] Target" |
| **Comparison** | Budget attainment % shown as small text below |
| **Color Logic** | Green `#107C10` if >= 100% of budget; Amber `#FF8C00` if 95-99%; Red `#D13438` if < 95% |
| **Icon** | Up/down arrow based on YoY direction |
| **Tooltip** | Full dollar value, budget amount, variance amount, prior year YTD |

#### Card B: Revenue Growth % YoY

| Property | Value |
|---|---|
| **Measure** | `[SLS] Revenue Growth % YoY` |
| **Display Format** | +##.#% or -##.#% |
| **Subtitle** | "vs Prior Year Same Period" |
| **Color Logic** | Green if positive; Red if negative; threshold: ±5% for amber zone |
| **Icon** | Trend arrow (up green, down red, flat amber) |
| **Tooltip** | Current period revenue, prior year revenue, absolute variance |

#### Card C: On-Time Delivery %

| Property | Value |
|---|---|
| **Measure** | `[SC] On-Time Delivery %` |
| **Display Format** | ##.#% |
| **Subtitle** | "Target: 95.0%" |
| **Status Label** | `[ALT] Delivery Performance Status` — shown as colored badge |
| **Color Logic** | Green >= 95%; Amber 90-94%; Red < 90% |
| **Tooltip** | On-time shipment count, total shipments, late shipment count, rolling 12M trend |

#### Card D: Perfect Order Rate

| Property | Value |
|---|---|
| **Measure** | `[SC] Perfect Order Rate` |
| **Display Format** | ##.#% |
| **Subtitle** | "Target: 90.0%" |
| **Color Logic** | Green >= 90%; Amber 80-89%; Red < 80% |
| **Tooltip** | Perfect order count, total orders, breakdown by failure type (late / defective / short) |

#### Card E: Inventory Turnover

| Property | Value |
|---|---|
| **Measure** | `[SC] Inventory Turnover` |
| **Display Format** | ##.#x |
| **Subtitle** | "Annualized · Target: 15x" |
| **Secondary Metric** | `[SC] Days Inventory Outstanding` shown below in smaller text |
| **Color Logic** | Green 12-20x; Amber 8-11x or 20-25x; Red < 8x or > 25x |
| **Tooltip** | COGS, average inventory value, DIO, prior year turnover |

#### Card F: Supplier Risk Index

| Property | Value |
|---|---|
| **Measure** | `[SC] Supplier Risk Index` |
| **Display Format** | ##.# |
| **Subtitle** | "Avg Across All Suppliers" |
| **Status Badge** | `[ALT] Supplier Risk Status` |
| **Color Logic** | Green <= 30; Amber 31-60; Red > 60 |
| **Tooltip** | Supplier count by risk tier, highest-risk supplier name, risk score breakdown |

---

### Chart Visuals — Executive Overview

#### Visual G: Revenue Trend (Area Chart)

| Property | Value |
|---|---|
| **Visual Type** | Area chart |
| **X-Axis** | `dim_date[month_year_label]` — sorted by `dim_date[month_sort_order]` |
| **Y-Axis** | `SUM(fact_sales[revenue])` in millions |
| **Series 1** | Current Year Revenue — Steel Blue `#2E74B5` solid line with shading |
| **Series 2** | Prior Year Revenue — Slate Gray `#605E5C` dashed line (DATEADD measure) |
| **Reference Line** | Monthly Budget target — Gold `#C9A84C` dotted line |
| **Data Labels** | Off (too cluttered); enable in tooltip only |
| **Tooltip** | Month, current revenue, prior year revenue, variance amount, variance % |
| **Drill-Down** | Year → Quarter → Month via date hierarchy |
| **Cross-Filter** | Filters all other visuals on page when a month is clicked |
| **Title** | "Monthly Revenue: Current Year vs Prior Year" |

#### Visual H: Regional Performance Map (Filled Map)

| Property | Value |
|---|---|
| **Visual Type** | Azure Maps filled map (choropleth) |
| **Location** | `dim_region[country_name]` or `dim_region[state_province]` |
| **Color Saturation** | `[SLS] Regional Demand Growth % YoY` |
| **Color Scale** | Red (-20%) → White (0%) → Green (+20%) diverging scale |
| **Tooltip** | Region name, revenue YTD, units sold, demand growth %, OTD % |
| **Drill-Down** | Country → State/Province → City |
| **Interaction** | Clicking a region cross-filters all other visuals on page |
| **Title** | "Regional Revenue Growth (YoY)" |

#### Visual I: Perfect Order Waterfall

| Property | Value |
|---|---|
| **Visual Type** | Waterfall chart (or stacked bar decomposition) |
| **Purpose** | Show what % of orders fail each perfect order criterion |
| **Categories** | "Total Orders", "Late Deliveries", "Defective Units", "Quantity Shortfall", "Perfect Orders" |
| **Values** | Percentage or count of orders removed at each stage |
| **Colors** | Gray (total), Red (failures), Gold `#C9A84C` (perfect) |
| **Data Labels** | On — show count and % for each bar |
| **Tooltip** | Category description, count, percentage of total |
| **Title** | "Perfect Order Rate Decomposition" |
| **Business Use** | Instantly reveals which failure mode (late / defective / short) is the largest drag |

#### Visual J: Supply Chain Scorecard Table

| Property | Value |
|---|---|
| **Visual Type** | Table (formatted matrix) |
| **Rows** | Key KPIs (OTD, Fill Rate, Perfect Order, Defect Rate, Turnover, Transportation Cost Ratio) |
| **Columns** | KPI Name | Current Value | Target | Variance | Status |
| **Status Column** | Conditional formatting with colored icons (checkmark / warning / X) |
| **Row Colors** | Alternate white and `#F3F2F1` |
| **Conditional Formatting** | Apply background color to "Variance" column (green/amber/red based on sign and threshold) |
| **Tooltip** | Definition of each KPI and business interpretation |
| **Title** | "Supply Chain KPI Scorecard" |

#### Visual K: Top 5 Alerts (Card List)

| Property | Value |
|---|---|
| **Visual Type** | Multi-row card or text card (Power BI custom visual: HTML Content or Smart Narratives) |
| **Purpose** | Surface the top 5 actionable issues requiring executive attention |
| **Content Logic** | Uses DAX measures to identify: highest-risk supplier, most critical stockout location, most delayed carrier, lowest OTD region, largest budget miss |
| **Format** | Numbered list with color-coded severity dots (Red / Amber / Green) |
| **Interaction** | Each alert item navigates to the relevant detail dashboard via bookmark button |
| **Title** | "Action Required — Top Alerts" |

---

### Slicers and Filters — Executive Overview

| Slicer | Field | Type | Default | Synced to Other Pages |
|---|---|---|---|---|
| Date Range | `dim_date[date]` | Between (date picker) | Jan 1 current year to today | Yes — all pages |
| Region | `dim_region[macro_region]` | Dropdown | All | Yes |
| Vehicle Family | `dim_vehicle[model_family]` | Dropdown | All | Yes |

### Bookmarks — Executive Overview

| Bookmark Name | Purpose |
|---|---|
| `EXE_Default` | Resets all slicers and returns to YTD view |
| `EXE_QTD_View` | Switches date slicer to current quarter |
| `EXE_YoY_Comparison` | Activates prior year overlay on revenue chart |

---

## Dashboard 2: Supplier Performance & Risk

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Supplier Performance & Risk |
| **Page Name** | Supplier_Performance |
| **Purpose** | Deep-dive analysis of supplier reliability, risk exposure, and contract compliance |
| **Target Audience** | VP Procurement, Supplier Quality Engineers, Category Managers, Risk Officers |
| **Refresh Frequency** | Daily |
| **Default Date Filter** | Rolling 12 months |

### Business Questions Answered

1. Which suppliers have the lowest on-time delivery performance?
2. Which suppliers represent the highest risk (financial, geopolitical, quality)?
3. How do supplier lead times compare to contracted SLA levels?
4. Are single-source suppliers performing reliably?
5. Which supplier tier (1/2/3) is the weakest link?
6. Which suppliers have deteriorating performance trends that warrant contract review?

### Recommended Actions Based on Insights

- Suppliers with Risk Index > 60 AND single-source flag: Initiate dual-sourcing RFQ within 30 days.
- Suppliers with OTD < 85% over rolling 12 months: Escalate to supplier improvement program (SIP).
- Suppliers with actual lead time > 120% of SLA lead time: Issue formal corrective action request.
- Suppliers approaching contract expiry (< 90 days) with Risk Index > 40: Prioritize contract renewal negotiation.

---

### Layout: Supplier Performance & Risk

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  SUPPLIER PERFORMANCE & RISK                  Last Refresh: Today 06:00│
├───────┼──────┬──────────────┬──────────────┬──────────────┬───────────────────┤
│       │ (A)  │     (B)      │     (C)      │     (D)      │       (E)         │
│       │ Supp │  Avg OTD %   │  Avg Lead    │  Avg Risk    │  Single Source    │
│  NAV  │ Count│  (12M)       │  Time        │  Index       │  Supplier Count   │
│  BAR  ├──────┴──────────────┴──────────────┴──────────────┴───────────────────┤
│       │  (F) Supplier Risk Matrix                │  (G) OTD Trend by Supplier │
│       │  Bubble/Scatter: X=Risk, Y=Reliability   │  Line chart: Rolling 12M   │
│       │  Bubble size = Spend, Color = Tier       │  Top 10 suppliers selected │
│       ├──────────────────────────────────────────┴────────────────────────────┤
│       │  (H) Supplier Scorecard Table (all suppliers, sortable)               │
│       │  Name | Tier | Country | OTD% | Lead Time | Risk | Status | Action   │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

---

### KPI Cards — Supplier Performance

#### Card A: Active Supplier Count

| Property | Value |
|---|---|
| **Measure** | `CALCULATE(COUNTROWS(dim_supplier), dim_supplier[is_active] = TRUE())` |
| **Display Format** | ### |
| **Subtitle** | "Active Suppliers" |
| **Secondary** | "###  Single Source" in red if count > 10 |
| **Tooltip** | Breakdown by tier (Tier 1/2/3), by country, by category |

#### Card B: Average On-Time Delivery % (12M)

| Property | Value |
|---|---|
| **Measure** | `[TI] On-Time Delivery % Rolling 12M` |
| **Display Format** | ##.#% |
| **Subtitle** | "Rolling 12-Month Average" |
| **Color Logic** | Green >= 95%; Amber 90-94%; Red < 90% |
| **Tooltip** | # of on-time shipments, # late shipments, rolling trend chart (mini sparkline) |

#### Card C: Average Lead Time

| Property | Value |
|---|---|
| **Measure** | `[SC] Average Lead Time` |
| **Display Format** | ##.# days |
| **Subtitle** | "vs SLA Target" |
| **Comparison** | Show SLA lead time from dim_supplier alongside actual |
| **Color Logic** | Green if actual <= SLA; Amber 100-120% of SLA; Red > 120% of SLA |

#### Card D: Average Supplier Risk Index

| Property | Value |
|---|---|
| **Measure** | `[SC] Supplier Risk Index` |
| **Display Format** | ##.# |
| **Subtitle** | "Weighted Composite Score" |
| **Badge** | `[ALT] Supplier Risk Status` |
| **Color Logic** | Green <= 30; Amber 31-60; Red > 60 |

#### Card E: Single-Source Supplier Count

| Property | Value |
|---|---|
| **Measure** | `CALCULATE(COUNTROWS(dim_supplier), dim_supplier[is_single_source] = TRUE(), dim_supplier[is_active] = TRUE())` |
| **Display Format** | ### |
| **Subtitle** | "Single-Source Dependencies" |
| **Color Logic** | Always Amber/Red — highlights risk regardless of count |
| **Tooltip** | List of single-source supplier names and their risk scores |

---

### Chart Visuals — Supplier Performance

#### Visual F: Supplier Risk Matrix (Bubble Chart / Scatter Plot)

| Property | Value |
|---|---|
| **Visual Type** | Scatter chart |
| **X-Axis** | `[SC] Supplier Risk Index` (0-100, higher = riskier) |
| **Y-Axis** | `[SC] Supplier Reliability Score` (0-100, higher = better) |
| **Bubble Size** | Annual spend (`SUM(fact_shipments[transportation_cost])` as proxy, or actual spend if available) |
| **Bubble Color** | `dim_supplier[tier]`: Tier 1 = Blue, Tier 2 = Teal, Tier 3 = Gray |
| **Labels** | `dim_supplier[supplier_code]` (abbreviated name) on each bubble |
| **Reference Lines** | Vertical at X=60 (high risk threshold); Horizontal at Y=70 (low reliability threshold) |
| **Quadrant Shading** | Top-left (Low Risk, High Reliability) = light green; Bottom-right (High Risk, Low Reliability) = light red |
| **Single-Source Icon** | Exclamation mark overlay on single-source supplier bubbles |
| **Tooltip** | Supplier name, tier, country, OTD %, lead time, risk score breakdown, contract expiry |
| **Cross-Filter** | Clicking a bubble filters all other visuals to that supplier |
| **Title** | "Supplier Risk vs Reliability Matrix (Bubble Size = Spend)" |

#### Visual G: On-Time Delivery % Trend by Supplier (Line Chart)

| Property | Value |
|---|---|
| **Visual Type** | Line chart |
| **X-Axis** | `dim_date[month_year_label]` (rolling 12 months) |
| **Y-Axis** | `[SC] On-Time Delivery %` |
| **Series** | Top 10 suppliers by shipment volume (each a separate line) |
| **Reference Line** | 95% target — Gold `#C9A84C` dashed |
| **Color Palette** | Each supplier gets a distinct color from a 10-color palette |
| **Legend** | Right side, scrollable if > 10 suppliers |
| **Tooltip** | Supplier name, month, OTD %, shipment count, # late, # on-time |
| **Slicer Interaction** | Filtered by supplier selection in Visual F (scatter plot) |
| **Title** | "On-Time Delivery Trend — Rolling 12 Months" |

#### Visual H: Supplier Scorecard Table

| Property | Value |
|---|---|
| **Visual Type** | Table with conditional formatting |
| **Columns** | Supplier Name, Tier, Country, OTD %, Avg Lead Time, Lead Time vs SLA, Risk Index, Risk Status, Reliability Score, Is Single Source, Contract Expiry |
| **Sort Default** | Risk Index descending (highest risk at top) |
| **Row Count** | Show all active suppliers; paginate at 25 rows |
| **Conditional Formatting — OTD %** | Green fill >= 95%; Amber 90-94%; Red < 90% |
| **Conditional Formatting — Risk Index** | Red fill > 60; Amber 31-60; Green <= 30 |
| **Conditional Formatting — Lead Time vs SLA** | Red if > 120% of SLA; Amber 100-120%; Green <= 100% |
| **Is Single Source** | Red "YES" badge or Gray "NO" text |
| **Contract Expiry** | Red if < 90 days; Amber 90-180 days; Gray otherwise |
| **Drill-Through** | Right-click any row → "View Supplier Detail" page (separate detail report page) |
| **Export** | Enable Excel export for procurement review meetings |
| **Title** | "Supplier Performance Scorecard — All Active Suppliers" |

---

### Slicers and Filters — Supplier Performance

| Slicer | Field | Type | Default | Position |
|---|---|---|---|---|
| Date Range | `dim_date[date]` | Between | Rolling 12 months | Top filter bar |
| Supplier Tier | `dim_supplier[tier]` | Button row (1, 2, 3, All) | All | Top filter bar |
| Country | `dim_supplier[country]` | Dropdown | All | Top filter bar |
| Risk Status | `[ALT] Supplier Risk Status` | Button row | All | Top filter bar |
| Single Source Only | `dim_supplier[is_single_source]` | Toggle button | OFF | Top filter bar |
| Category | `dim_supplier[category]` | Dropdown | All | Top filter bar |

### Bookmarks — Supplier Performance

| Bookmark | Purpose |
|---|---|
| `SUP_AllSuppliers` | Default — all suppliers visible |
| `SUP_HighRiskOnly` | Filter to Risk Index > 60 |
| `SUP_SingleSourceOnly` | Filter to single-source suppliers |
| `SUP_ContractExpiring` | Filter to suppliers with contract expiry < 90 days |

---

## Dashboard 3: Inventory & Warehouse Management

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Inventory & Warehouse Management |
| **Page Name** | Inventory_Warehouse |
| **Purpose** | Real-time visibility into inventory levels, stockout risk, and warehouse utilization across the network |
| **Target Audience** | Warehouse Managers, Inventory Planners, Materials Managers, Operations VPs |
| **Refresh Frequency** | Daily (or near-real-time via DirectQuery mode if ERP system supports it) |
| **Default Date Filter** | Current month |

### Business Questions Answered

1. Which warehouses and SKUs are at risk of stockout in the next 7 days?
2. What is the current inventory value and how has it changed month-over-month?
3. Are any warehouses over capacity or approaching maximum storage limits?
4. What is the fill rate by warehouse and product category?
5. Which SKUs are slow-moving (high DIO) and should be reviewed for reorder point adjustment?
6. How does inventory turnover vary by warehouse location and product type?

### Recommended Actions Based on Insights

- CRITICAL stockout alerts (< 3 days supply): Initiate emergency procurement / inter-warehouse transfer immediately.
- WARNING stockout alerts (< 7 days supply): Expedite open purchase orders; contact supplier for early delivery.
- Warehouses > 90% capacity: Arrange overflow storage or accelerate outbound shipments.
- SKUs with DIO > 60 days: Review reorder points and safety stock levels; consider promotional push to reduce inventory.

---

### Layout: Inventory & Warehouse Management

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  INVENTORY & WAREHOUSE MANAGEMENT              Last Refresh: Today 06:00│
├───────┼──────┬──────────────┬──────────────┬──────────────┬───────────────────┤
│       │ (A)  │     (B)      │     (C)      │     (D)      │       (E)         │
│       │Total │  Inventory   │  Stockout    │  Fill Rate   │   DIO             │
│  NAV  │ Inv  │  Turnover    │  Rate %      │  %           │   (Days)          │
│  BAR  ├──────┴──────────────┴──────────────┴──────────────┴───────────────────┤
│       │  (F) Stockout Alert Map           │  (G) Inventory Value Trend        │
│       │  Geo map: warehouse locations     │  Area chart: Daily inventory value │
│       │  Color = alert status             │  with MoM change annotation        │
│       ├───────────────────────────────────┴────────────────────────────────────┤
│       │  (H) Inventory by Category (Bar)  │  (I) Warehouse Utilization Grid   │
│       │  Stacked bar: value by category   │  Matrix: warehouse vs utilization% │
│       ├───────────────────────────────────┴────────────────────────────────────┤
│       │  (J) Critical SKU Alert Table (CRITICAL and WARNING items only)        │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

---

### KPI Cards — Inventory

#### Card A: Total Inventory Value

| Property | Value |
|---|---|
| **Measure** | `SUM(fact_inventory[inventory_value])` |
| **Display Format** | $###.#M |
| **Subtitle** | "As of [latest date]" |
| **Secondary** | `[TI] Inventory Value MoM Change` with up/down arrow |
| **Color Logic** | Change arrow: Green if decreasing (good — lean inventory); Amber/Red if increasing sharply |
| **Tooltip** | Value by warehouse type (Raw / WIP / Finished Goods), MoM and YoY comparison |

#### Card B: Inventory Turnover

| Property | Value |
|---|---|
| **Measure** | `[SC] Inventory Turnover` |
| **Display Format** | ##.#x |
| **Color Logic** | Green 12-20x; Amber outside range; Red if severe |

#### Card C: Stockout Rate %

| Property | Value |
|---|---|
| **Measure** | `[SC] Stockout Rate` |
| **Display Format** | ##.#% |
| **Subtitle** | "Warehouses Below Safety Stock" |
| **Color Logic** | Green = 0%; Amber 1-3%; Red > 3% |
| **Alert Badge** | Red "CRITICAL" badge if any location has < 3 days supply |

#### Card D: Fill Rate %

| Property | Value |
|---|---|
| **Measure** | `[SC] Fill Rate %` |
| **Display Format** | ##.#% |
| **Color Logic** | Green >= 98%; Amber 95-97%; Red < 95% |

#### Card E: Days Inventory Outstanding

| Property | Value |
|---|---|
| **Measure** | `[SC] Days Inventory Outstanding` |
| **Display Format** | ## days |
| **Color Logic** | Green 20-45 days; Amber outside range; Red if extreme |

---

### Chart Visuals — Inventory

#### Visual F: Stockout Alert Geographic Map

| Property | Value |
|---|---|
| **Visual Type** | Azure Maps bubble map |
| **Location** | `dim_warehouse[latitude]`, `dim_warehouse[longitude]` |
| **Bubble Size** | `SUM(fact_inventory[quantity_on_hand])` — larger = more stock |
| **Bubble Color** | `[ALT] Stockout Alert`: CRITICAL = Red `#D13438`; WARNING = Amber `#FF8C00`; OK = Green `#107C10` |
| **Labels** | `dim_warehouse[warehouse_code]` on hover |
| **Tooltip** | Warehouse name, location, quantity on hand, safety stock level, days of supply, alert status, top 3 at-risk SKUs |
| **Cross-Filter** | Clicking a warehouse filters Visual J (alert table) to that warehouse |
| **Title** | "Warehouse Stockout Alert Status" |

#### Visual G: Inventory Value Trend (Area Chart)

| Property | Value |
|---|---|
| **Visual Type** | Area chart |
| **X-Axis** | `dim_date[date]` (daily, last 90 days default) |
| **Y-Axis** | `SUM(fact_inventory[inventory_value])` |
| **Series** | Total Inventory Value — Steel Blue |
| **Reference Line** | Target inventory value range (min/max lines in gold) |
| **Annotations** | MoM change amount displayed at each month boundary |
| **Tooltip** | Date, total inventory value, MoM change, MoM change %, YoY comparison |
| **Title** | "Total Inventory Value Trend" |

#### Visual H: Inventory Value by Category (Stacked Bar Chart)

| Property | Value |
|---|---|
| **Visual Type** | Stacked bar chart |
| **X-Axis** | `dim_date[month_year_label]` (last 12 months) |
| **Y-Axis** | `SUM(fact_inventory[inventory_value])` |
| **Legend / Stack** | `dim_vehicle[category]` (Raw Material / WIP / Finished Goods) |
| **Colors** | Raw Material = Blue; WIP = Teal; Finished Goods = Gold |
| **Drill-Down** | Category → Sub-category → Individual SKU |
| **Tooltip** | Month, category, value, % of total, MoM change |
| **Title** | "Inventory Value by Category — Monthly" |

#### Visual I: Warehouse Utilization Matrix

| Property | Value |
|---|---|
| **Visual Type** | Matrix (pivot table) |
| **Rows** | `dim_warehouse[warehouse_name]` |
| **Columns** | `dim_vehicle[category]` |
| **Values** | Utilization % = `SUM(fact_inventory[quantity_on_hand]) / MAX(dim_warehouse[total_capacity_units])` |
| **Conditional Formatting** | Background: Green < 70%; Amber 70-89%; Red >= 90% |
| **Row Totals** | Overall warehouse utilization % |
| **Title** | "Warehouse Capacity Utilization %" |

#### Visual J: Critical SKU Alert Table

| Property | Value |
|---|---|
| **Visual Type** | Table, pre-filtered to show only CRITICAL and WARNING items |
| **Filter** | `[ALT] Stockout Alert` IN {"CRITICAL", "WARNING"} |
| **Columns** | Alert Status (colored badge), Warehouse, SKU Name, Qty on Hand, Safety Stock, Days of Supply, Avg Daily Demand, Next Scheduled Receipt Date, Action Required |
| **Sort** | Days of Supply ascending (most urgent at top) |
| **Color** | CRITICAL rows — light red background; WARNING rows — light amber |
| **Conditional Formatting** | Days of Supply: Red <= 3; Amber 4-7 |
| **Export** | Enable Excel export for daily materials team review |
| **Title** | "Stockout Alert — Items Requiring Immediate Action" |

---

### Slicers — Inventory

| Slicer | Field | Type |
|---|---|---|
| Date | `dim_date[date]` | Single date picker (snapshot date) |
| Warehouse | `dim_warehouse[warehouse_name]` | Multi-select list |
| Warehouse Type | `dim_warehouse[warehouse_type]` | Button row |
| Product Category | `dim_vehicle[category]` | Dropdown |
| Alert Status | `[ALT] Stockout Alert` | Button row (CRITICAL / WARNING / OK / All) |
| Region | `dim_region[country_name]` | Dropdown |

---

## Dashboard 4: Logistics & Transportation

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Logistics & Transportation |
| **Page Name** | Logistics_Transport |
| **Purpose** | Analysis of transportation costs, carrier performance, routing efficiency, and delivery punctuality |
| **Target Audience** | Logistics Managers, Transportation Analysts, Operations Directors, Finance (freight budget) |
| **Refresh Frequency** | Daily |

### Business Questions Answered

1. What is the total transportation cost and how does it compare to budget and prior year?
2. Which carriers have the worst on-time delivery performance?
3. What is the optimal modal mix (road/rail/air/sea) and are we over-using premium air freight?
4. Which routes or lanes have the highest cost per unit shipped?
5. How does average lead time vary by transport mode and carrier?
6. Are there any shipments severely delayed that will impact production schedules?

### Recommended Actions Based on Insights

- Air freight > 15% of total shipments: Review emergency procurement processes; increase safety stock to reduce expediting.
- Carrier OTD < 85%: Issue carrier performance review; trigger penalty clause if applicable.
- Transportation cost ratio > 8%: Initiate carrier rate renegotiation or mode optimization study.
- Routes with cost per kg > 2x average: Consolidate shipments or switch to bulk carrier.

---

### Layout: Logistics & Transportation

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  LOGISTICS & TRANSPORTATION                    Last Refresh: Today 06:00│
├───────┼──────┬──────────────┬──────────────┬──────────────┬───────────────────┤
│       │ (A)  │     (B)      │     (C)      │     (D)      │       (E)         │
│       │Total │  Transport   │  Carrier OTD │  Avg Lead    │  Air Freight      │
│  NAV  │Trans │  Cost Ratio  │  %           │  Time        │  % of Shipments   │
│  BAR  ├──────┴──────────────┴──────────────┴──────────────┴───────────────────┤
│       │  (F) Shipment Flow Map                │  (G) Cost by Transport Mode   │
│       │  Origin-destination arc map           │  Donut chart: road/rail/air   │
│       │                                       │                               │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (H) Carrier Performance Ranking      │  (I) Lead Time by Mode        │
│       │  Horizontal bar: OTD % by carrier     │  Box plot or bar chart        │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (J) Transportation Cost Trend (Line chart: monthly cost by mode)     │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

---

### KPI Cards — Logistics

#### Card A: Total Transportation Cost

| Property | Value |
|---|---|
| **Measure** | `SUM(fact_shipments[transportation_cost])` |
| **Display Format** | $##.#M |
| **Secondary** | vs Budget; vs Prior Year |
| **Color Logic** | Green if under budget; Red if > 105% of budget |

#### Card B: Transportation Cost Ratio

| Property | Value |
|---|---|
| **Measure** | `[SC] Transportation Cost Ratio` |
| **Display Format** | ##.#% |
| **Subtitle** | "% of Revenue" |
| **Color Logic** | Green < 5%; Amber 5-8%; Red > 8% |

#### Card C: Carrier On-Time Delivery %

| Property | Value |
|---|---|
| **Measure** | `[SC] On-Time Delivery %` (in carrier context) |
| **Display Format** | ##.#% |
| **Subtitle** | "Across All Carriers" |
| **Color Logic** | Standard OTD color rules |

#### Card D: Average Lead Time

| Property | Value |
|---|---|
| **Measure** | `[SC] Average Lead Time` |
| **Display Format** | ##.# days |
| **Secondary** | Prior month comparison |

#### Card E: Air Freight % of Shipments

| Property | Value |
|---|---|
| **Measure** | `DIVIDE(CALCULATE(COUNTROWS(fact_shipments), fact_shipments[transport_mode] = "Air"), COUNTROWS(fact_shipments), 0) * 100` |
| **Display Format** | ##.#% |
| **Subtitle** | "Emergency / Premium Freight Usage" |
| **Color Logic** | Green < 5%; Amber 5-15%; Red > 15% (air is typically 10-15x road cost) |
| **Tooltip** | Air freight cost vs road freight cost comparison |

---

### Chart Visuals — Logistics

#### Visual F: Shipment Flow Map (Arc / Flow Map)

| Property | Value |
|---|---|
| **Visual Type** | Custom visual: "Flow Map" or Azure Maps with lines (route visualization) |
| **Origin** | `dim_supplier[latitude/longitude]` or origin warehouse coordinates |
| **Destination** | `dim_warehouse[latitude/longitude]` |
| **Line Thickness** | Proportional to shipment volume or cost |
| **Line Color** | By transport mode: Road = Blue; Rail = Teal; Air = Red; Sea = Navy |
| **Tooltip** | Origin, destination, shipment count, total cost, OTD %, avg lead time |
| **Click** | Filter all page visuals to selected lane |
| **Title** | "Shipment Flow Map by Transport Mode" |

#### Visual G: Transportation Cost by Mode (Donut Chart)

| Property | Value |
|---|---|
| **Visual Type** | Donut chart |
| **Legend** | `fact_shipments[transport_mode]` |
| **Values** | `SUM(fact_shipments[transportation_cost])` |
| **Colors** | Road = Blue; Rail = Teal; Air = Red; Sea = Navy |
| **Data Labels** | Both % and $ amount |
| **Inner Label** | Total transportation cost |
| **Tooltip** | Mode, cost, % of total, shipment count, avg cost per kg |
| **Title** | "Transportation Cost by Mode" |

#### Visual H: Carrier Performance Ranking (Horizontal Bar Chart)

| Property | Value |
|---|---|
| **Visual Type** | Horizontal bar chart |
| **Y-Axis** | `fact_shipments[carrier_name]` (top 15 by volume) |
| **X-Axis** | `[SC] On-Time Delivery %` |
| **Color** | Gradient: Green (100%) → Red (0%), conditional |
| **Reference Line** | Vertical line at 95% target |
| **Data Labels** | OTD % value on each bar |
| **Secondary Value** | Small text showing shipment count |
| **Sort** | Ascending OTD % (worst performers at top) |
| **Tooltip** | Carrier, OTD %, late count, on-time count, avg delay days, total cost |
| **Title** | "Carrier On-Time Delivery Performance Ranking" |

#### Visual I: Lead Time by Transport Mode (Bar Chart with Error Bars)

| Property | Value |
|---|---|
| **Visual Type** | Clustered bar chart |
| **X-Axis** | `fact_shipments[transport_mode]` |
| **Y-Axis** | `[SC] Average Lead Time` |
| **Color** | By transport mode (same palette as donut chart) |
| **Error Bars** | Min / Max lead time per mode (shows variability) |
| **Reference Line** | SLA target lead time |
| **Tooltip** | Mode, avg lead time, min, max, SLA target, variance |
| **Title** | "Average Lead Time by Transport Mode" |

#### Visual J: Transportation Cost Trend (Line Chart)

| Property | Value |
|---|---|
| **Visual Type** | Line chart |
| **X-Axis** | `dim_date[month_year_label]` (12 months) |
| **Y-Axis** | `SUM(fact_shipments[transportation_cost])` |
| **Series** | One line per transport mode (Road, Rail, Air, Sea) |
| **Colors** | Same as donut chart |
| **Reference Line** | Monthly budget line in Gold |
| **Annotations** | Flag months with major cost spikes for root cause |
| **Tooltip** | Month, cost per mode, total cost, vs budget, vs prior year |
| **Title** | "Monthly Transportation Cost by Mode — 12 Month Trend" |

---

### Slicers — Logistics

| Slicer | Field | Type |
|---|---|---|
| Date Range | `dim_date[date]` | Between |
| Transport Mode | `fact_shipments[transport_mode]` | Button row |
| Carrier | `fact_shipments[carrier_name]` | Dropdown |
| Supplier | `dim_supplier[supplier_name]` | Dropdown |
| Destination Region | `dim_region[macro_region]` | Dropdown |
| Delay Status | `fact_shipments[is_on_time]` | Button row (On Time / Late) |

---

## Dashboard 5: Demand & Sales Analytics

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Demand & Sales Analytics |
| **Page Name** | Demand_Sales |
| **Purpose** | Analysis of revenue performance, demand forecasting accuracy, and sales trends by region and vehicle model |
| **Target Audience** | Sales Directors, Demand Planners, Finance, Marketing VPs |
| **Refresh Frequency** | Daily |

### Business Questions Answered

1. What is actual revenue vs forecast this month and year?
2. Which vehicle models are over/under-performing against forecast?
3. Which regions show the strongest and weakest demand growth?
4. Is forecast accuracy improving or deteriorating over time?
5. What is the revenue per unit trend by vehicle segment?
6. What is the channel mix (Dealer vs Fleet vs Direct) and how is it shifting?

### Recommended Actions Based on Insights

- Forecast accuracy < 80% for a specific model: Revisit demand sensing inputs; engage sales team for channel inventory insights.
- Region demand growth > 20% YoY: Accelerate safety stock build; review distribution center capacity.
- Revenue per unit declining > 5%: Investigate discount structure and mix shift toward lower-margin variants.
- Fleet channel revenue growing: Ensure production scheduling reflects fleet-specific configurations.

---

### Layout: Demand & Sales Analytics

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  DEMAND & SALES ANALYTICS                      Last Refresh: Today 06:00│
├───────┼──────┬──────────────┬──────────────┬──────────────┬───────────────────┤
│       │ (A)  │     (B)      │     (C)      │     (D)      │       (E)         │
│       │ Rev  │  Revenue     │  Forecast    │  Regional    │  Revenue          │
│  NAV  │ YTD  │  Growth %    │  Accuracy %  │  Growth %    │  per Unit         │
│  BAR  ├──────┴──────────────┴──────────────┴──────────────┴───────────────────┤
│       │  (F) Actual vs Forecast by Month      │  (G) Revenue by Region (Map)  │
│       │  Clustered bar + line combo chart     │  Filled map: revenue by state │
│       │                                       │                               │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (H) Revenue by Vehicle Model         │  (I) Channel Mix Trend        │
│       │  Waterfall or ranked bar              │  Stacked area by channel      │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (J) Forecast Accuracy Trend (Line chart: monthly accuracy %)         │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

---

### KPI Cards — Demand & Sales

#### Card A: Revenue YTD

Same as Executive Overview Card A, contextualized here by vehicle model and region slicers.

#### Card B: Revenue Growth % YoY

| Property | Value |
|---|---|
| **Measure** | `[SLS] Revenue Growth % YoY` |
| **Display Format** | +##.#% or -##.#% |
| **Color Logic** | Green positive; Red negative |

#### Card C: Forecast Accuracy %

| Property | Value |
|---|---|
| **Measure** | `[SLS] Forecast Accuracy %` |
| **Display Format** | ##.#% |
| **Subtitle** | "Demand Planning Accuracy" |
| **Color Logic** | Green >= 90%; Amber 80-89%; Red < 80% |
| **Tooltip** | Actual units, forecasted units, MAPE, best and worst performing models |

#### Card D: Regional Demand Growth %

| Property | Value |
|---|---|
| **Measure** | `[SLS] Regional Demand Growth % YoY` |
| **Display Format** | +##.#% |
| **Subtitle** | "Units Sold — YoY Change" |
| **Context Note** | Shows for region in current filter context; "All Regions" aggregate if no region selected |

#### Card E: Revenue per Unit

| Property | Value |
|---|---|
| **Measure** | `[SLS] Revenue per Unit` |
| **Display Format** | $##,###  |
| **Subtitle** | "Average Selling Price" |
| **Secondary** | Prior year comparison with variance arrow |

---

### Chart Visuals — Demand & Sales

#### Visual F: Actual vs Forecast by Month (Combo Chart)

| Property | Value |
|---|---|
| **Visual Type** | Clustered column + line combo chart |
| **X-Axis** | `dim_date[month_year_label]` (current year by default) |
| **Column (Bar) Series** | Actual Units Sold — Steel Blue `#2E74B5` |
| **Column (Bar) Series 2** | Forecasted Units — Light Blue outline/hatch pattern |
| **Line** | `[SLS] Forecast Accuracy %` on secondary Y-axis |
| **Reference Line** | Annual unit target (horizontal line on bar axis) |
| **Data Labels** | On bars: actual unit count; on line: accuracy % |
| **Tooltip** | Month, actual units, forecast units, variance, accuracy %, revenue |
| **Drill-Down** | Year → Quarter → Month |
| **Title** | "Actual Sales vs Forecast — Monthly Comparison" |

#### Visual G: Revenue by Region (Filled Map)

| Property | Value |
|---|---|
| **Visual Type** | Azure Maps choropleth |
| **Location** | `dim_region[state_province]` (US state level default) |
| **Color** | `SUM(fact_sales[revenue])` — light to dark blue scale |
| **Tooltip** | State, revenue, units sold, revenue growth %, forecast accuracy %, OTD % |
| **Drill-Down** | Country → State → City |
| **Title** | "Revenue by Region" |

#### Visual H: Revenue by Vehicle Model (Horizontal Bar)

| Property | Value |
|---|---|
| **Visual Type** | Horizontal bar chart |
| **Y-Axis** | `dim_vehicle[model]` |
| **X-Axis** | `SUM(fact_sales[revenue])` |
| **Color** | By `dim_vehicle[drive_train]` (ICE = Blue, EV = Green, Hybrid = Teal) |
| **Secondary Label** | `[SLS] Revenue Growth % YoY` shown as small text on each bar |
| **Sort** | Revenue descending |
| **Drill-Down** | Model Family → Model → Variant |
| **Tooltip** | Model, revenue, units sold, revenue per unit, YoY growth, forecast accuracy |
| **Title** | "Revenue by Vehicle Model" |

#### Visual I: Channel Mix Trend (Stacked Area)

| Property | Value |
|---|---|
| **Visual Type** | 100% stacked area chart |
| **X-Axis** | `dim_date[month_year_label]` (12 months) |
| **Y-Axis** | % of total revenue |
| **Series** | `fact_sales[channel]`: Dealer, Fleet, Direct |
| **Colors** | Dealer = Blue; Fleet = Teal; Direct = Gold |
| **Tooltip** | Month, channel, revenue, % of total, YoY change in channel % |
| **Title** | "Sales Channel Mix — Monthly Trend" |

#### Visual J: Forecast Accuracy Trend (Line Chart)

| Property | Value |
|---|---|
| **Visual Type** | Line chart |
| **X-Axis** | `dim_date[month_year_label]` (24 months for trend visibility) |
| **Y-Axis** | `[SLS] Forecast Accuracy %` |
| **Series** | One line per top 5 vehicle models |
| **Reference Line** | 90% target in Gold |
| **Shading** | Below 80% zone shaded in light red |
| **Tooltip** | Month, model, accuracy %, actual units, forecast units, absolute error |
| **Title** | "Forecast Accuracy Trend by Vehicle Model" |

---

### Slicers — Demand & Sales

| Slicer | Field | Type |
|---|---|---|
| Date Range | `dim_date[date]` | Between |
| Vehicle Family | `dim_vehicle[model_family]` | Dropdown |
| Model | `dim_vehicle[model]` | Dropdown (dependent on family) |
| Drive Train | `dim_vehicle[drive_train]` | Button row (ICE / EV / Hybrid / PHEV) |
| Sales Channel | `fact_sales[channel]` | Button row |
| Region | `dim_region[macro_region]` | Dropdown |
| Customer Segment | `fact_sales[customer_segment]` | Button row |

---

## Dashboard 6: Manufacturing Operations

### Dashboard Metadata

| Property | Value |
|---|---|
| **Dashboard Name** | Manufacturing Operations |
| **Page Name** | Manufacturing_Ops |
| **Purpose** | Plant-level production performance, quality metrics, OEE tracking, and downtime analysis |
| **Target Audience** | Plant Managers, Production Supervisors, Quality Engineers, Operations VPs, Maintenance Teams |
| **Refresh Frequency** | Daily (shift-level data; near-real-time if MES integration is available) |

### Business Questions Answered

1. Which plants are meeting their production targets and which are behind?
2. What is the OEE by plant and how does it break down into Availability, Performance, and Quality?
3. Which production lines have the highest downtime and what are the root causes?
4. How does defect rate vary by plant, model, and shift?
5. Is plant utilization too high (quality risk) or too low (cost efficiency issue)?
6. What is the production cost per unit by plant and how does it compare to standard cost?

### Recommended Actions Based on Insights

- Plant OEE < 65%: Initiate Total Productive Maintenance (TPM) program review immediately.
- Downtime % > 5% on any single line: Schedule preventive maintenance during next planned shutdown.
- Defect Rate > 0.5% sustained: Trigger 8D problem-solving process; check incoming material quality from suppliers.
- Plant utilization > 95%: Alert capacity planning team; evaluate overtime scheduling or shift addition.
- Plant utilization < 70%: Review demand forecast alignment; consider production consolidation.

---

### Layout: Manufacturing Operations

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [NAV] │  MANUFACTURING OPERATIONS                      Last Refresh: Today 06:00│
├───────┼──────┬──────────────┬──────────────┬──────────────┬───────────────────┤
│       │ (A)  │     (B)      │     (C)      │     (D)      │       (E)         │
│  NAV  │ OEE  │  Plant Util  │  Downtime %  │  Defect Rate │  Total Units      │
│  BAR  │  %   │    %         │              │     %        │   Produced        │
│       ├──────┴──────────────┴──────────────┴──────────────┴───────────────────┤
│       │  (F) OEE by Plant (Gauge/Bar)         │  (G) OEE Decomposition Chart  │
│       │  Horizontal bar: OEE % per plant      │  Waterfall: Avail/Perf/Quality │
│       │                                       │                               │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (H) Downtime Pareto by Reason        │  (I) Defect Rate by Line/Shift │
│       │  Pareto chart with cumulative %       │  Heat map: line vs shift       │
│       ├───────────────────────────────────────┴───────────────────────────────┤
│       │  (J) Production vs Plan Trend (Line chart: daily output vs target)    │
└───────┴───────────────────────────────────────────────────────────────────────┘
```

---

### KPI Cards — Manufacturing

#### Card A: OEE %

| Property | Value |
|---|---|
| **Measure** | `[MFG] OEE %` |
| **Display Format** | ##.#% |
| **Subtitle** | "Overall Equipment Effectiveness" |
| **Target Badge** | "World Class: 85%" shown as reference |
| **Color Logic** | Green >= 85%; Amber 65-84%; Red < 65% |
| **Tooltip** | OEE decomposition: Availability %, Performance %, Quality %, and each component's contribution to loss |

#### Card B: Plant Utilization %

| Property | Value |
|---|---|
| **Measure** | `[MFG] Plant Utilization %` |
| **Display Format** | ##.#% |
| **Subtitle** | "Actual vs Planned Production" |
| **Color Logic** | Amber < 70%; Green 70-95%; Amber > 95% (both extremes are concerns) |

#### Card C: Downtime %

| Property | Value |
|---|---|
| **Measure** | `[MFG] Downtime %` |
| **Display Format** | ##.#% |
| **Subtitle** | "Unplanned Downtime / Available Hours" |
| **Color Logic** | Green < 2%; Amber 2-5%; Red > 5% |
| **Tooltip** | Total downtime hours, available hours, planned downtime %, top downtime reason |

#### Card D: Defect Rate %

| Property | Value |
|---|---|
| **Measure** | `[MFG] Defect Rate %` |
| **Display Format** | ##.##% (two decimal places given small values) |
| **Subtitle** | "Defective Units / Total Produced" |
| **PPM Display** | Also show as PPM (× 10,000) for quality teams |
| **Color Logic** | Green < 0.1%; Amber 0.1-0.5%; Red > 0.5% |

#### Card E: Total Units Produced

| Property | Value |
|---|---|
| **Measure** | `SUM(fact_production[actual_units_produced])` |
| **Display Format** | ###,### |
| **Subtitle** | "This Month" |
| **Secondary** | vs `SUM(fact_production[planned_units])` showing plan attainment % |
| **Color Logic** | Green if >= 100% of plan; Amber 95-99%; Red < 95% |

---

### Chart Visuals — Manufacturing

#### Visual F: OEE by Plant (Horizontal Bar Chart)

| Property | Value |
|---|---|
| **Visual Type** | Horizontal bar chart |
| **Y-Axis** | `dim_plant[plant_name]` |
| **X-Axis** | `[MFG] OEE %` |
| **Color** | Green >= 85%; Amber 65-84%; Red < 65% (conditional formatting on bars) |
| **Reference Line** | Vertical line at 85% (world class) in Gold |
| **Data Labels** | OEE % value on each bar |
| **Secondary Column** | Small text showing `dim_plant[oee_target]` (plant-specific target) |
| **Sort** | OEE % ascending (worst performers at top) |
| **Tooltip** | Plant name, OEE %, Availability %, Performance %, Quality %, capacity, location |
| **Cross-Filter** | Clicking a plant filters Visual G, H, I, J to that plant |
| **Title** | "OEE by Manufacturing Plant" |

#### Visual G: OEE Decomposition Waterfall

| Property | Value |
|---|---|
| **Visual Type** | Waterfall chart |
| **Categories** | "100% Theoretical" → "Availability Loss" → "Performance Loss" → "Quality Loss" → "Actual OEE" |
| **Values** | Percentage points lost at each stage |
| **Colors** | 100% bar = Gold; Loss bars = Red; Final OEE bar = Green (if >= 85%) or Amber/Red |
| **Data Labels** | Both % points lost and cumulative OEE at each step |
| **Context** | Filtered by plant selection from Visual F |
| **Tooltip** | Loss category, % loss, hours lost, cost impact estimate |
| **Title** | "OEE Loss Decomposition — Availability / Performance / Quality" |
| **Business Value** | Immediately reveals whether plant underperformance is an availability problem (maintenance), performance problem (speed loss), or quality problem (defects) — each requiring a different corrective action |

#### Visual H: Downtime Pareto by Reason

| Property | Value |
|---|---|
| **Visual Type** | Pareto chart (combined bar + cumulative % line) |
| **X-Axis** | `fact_production[downtime_reason]` (sorted by frequency descending) |
| **Y-Axis (Left)** | `SUM(fact_production[downtime_hours])` |
| **Y-Axis (Right)** | Cumulative % line (secondary axis, 0-100%) |
| **Bar Colors** | First bar (largest) = Red; subsequent bars = Blue gradient |
| **Reference Line** | 80% line on cumulative axis (Pareto 80/20 rule) |
| **Data Labels** | Hours on bars; % on cumulative line points |
| **Tooltip** | Reason, total hours, % of total downtime, affected plants, affected lines |
| **Title** | "Downtime Pareto Analysis — Root Cause Distribution" |
| **Business Value** | Identifies the vital few downtime causes that account for 80% of losses, directing maintenance investment |

#### Visual I: Defect Rate Heatmap (Matrix)

| Property | Value |
|---|---|
| **Visual Type** | Matrix with conditional formatting (color heatmap) |
| **Rows** | `fact_production[production_line]` |
| **Columns** | `fact_production[shift]` (Morning / Afternoon / Night) |
| **Values** | `[MFG] Defect Rate %` |
| **Conditional Formatting** | Background gradient: Green (0%) → Amber (0.25%) → Red (0.5%+) |
| **Row Totals** | Defect rate across all shifts per line |
| **Column Totals** | Defect rate across all lines per shift |
| **Tooltip** | Line, shift, defect rate, defect count, total produced, most common defect type |
| **Business Value** | Quickly reveals whether quality issues are line-specific (equipment or tooling), shift-specific (operator skill or fatigue), or systemic (material/design) |
| **Title** | "Defect Rate Heatmap — Production Line vs Shift" |

#### Visual J: Production vs Plan Trend (Line Chart)

| Property | Value |
|---|---|
| **Visual Type** | Line chart |
| **X-Axis** | `dim_date[date]` (daily, current month default) |
| **Y-Axis** | Units |
| **Series 1** | Actual Units Produced — Steel Blue solid line |
| **Series 2** | Planned Units — Gold dashed line |
| **Series 3** | Cumulative Actual vs Cumulative Plan (secondary axis) |
| **Shading** | Fill between actual and plan lines: Green where actual > plan; Red where actual < plan |
| **Annotations** | Flag dates with significant downtime events |
| **Tooltip** | Date, actual units, planned units, variance, cumulative attainment % |
| **Drill-Down** | Month → Week → Day |
| **Title** | "Daily Production: Actual vs Plan" |

---

### Slicers — Manufacturing

| Slicer | Field | Type |
|---|---|---|
| Date Range | `dim_date[date]` | Between |
| Plant | `dim_plant[plant_name]` | Multi-select list |
| Production Line | `fact_production[production_line]` | Dropdown |
| Shift | `fact_production[shift]` | Button row (Morning / Afternoon / Night / All) |
| Vehicle Model | `dim_vehicle[model]` | Dropdown |
| Region | `dim_region[state_province]` | Dropdown |
| Downtime Reason | `fact_production[downtime_reason]` | Dropdown |

### Bookmarks — Manufacturing

| Bookmark | Purpose |
|---|---|
| `MFG_AllPlants` | Default — all plants aggregated |
| `MFG_LowOEE` | Filter to plants with OEE < 65% |
| `MFG_NightShift` | Filter to Night shift only (common quality monitoring use case) |
| `MFG_ThisWeek` | Date slicer set to current ISO week |

---

## Cross-Dashboard Interactions & Navigation

### Drill-Through Pages

The following detail pages are accessible via right-click → "Drill through" from any summary dashboard:

| Drill-Through Page | Trigger Field | Shows |
|---|---|---|
| Supplier Detail | `dim_supplier[supplier_name]` | Full shipment history, quality trends, cost trend, risk breakdown for one supplier |
| Warehouse Detail | `dim_warehouse[warehouse_name]` | Full SKU-level inventory list, receipt/issue history, stockout history |
| Plant Detail | `dim_plant[plant_name]` | Shift-by-shift production, all lines, all downtime events, full OEE history |
| Vehicle Model Detail | `dim_vehicle[model]` | Sales, production, inventory, and quality metrics for one model |

### Tooltip Pages

Custom tooltip pages (small pop-up visuals) appear on hover for:
- **Supplier bubbles** (Visual F, Dashboard 2): Mini line chart of OTD trend + risk score breakdown
- **Map regions** (Dashboard 5): Revenue bar with prior year + demand growth gauge
- **Warehouse map dots** (Dashboard 3): Inventory level bar showing quantity vs safety stock vs max

### Bookmark-Based Navigation Summary

| Bookmark | Dashboard | Purpose |
|---|---|---|
| `NAV_Executive` | All pages | Navigate to Executive Overview |
| `NAV_Supplier` | All pages | Navigate to Supplier Performance |
| `NAV_Inventory` | All pages | Navigate to Inventory & Warehouse |
| `NAV_Logistics` | All pages | Navigate to Logistics & Transportation |
| `NAV_Sales` | All pages | Navigate to Demand & Sales |
| `NAV_Manufacturing` | All pages | Navigate to Manufacturing Operations |
| `ALERT_CriticalOnly` | Dashboard 3 | Apply CRITICAL filter to stockout table |
| `RESET_AllFilters` | All pages | Clear all slicers to default state |

### Row-Level Security (RLS)

Configure the following RLS roles in Power BI Desktop (Modeling → Manage Roles):

| Role | Filter Rule | Use Case |
|---|---|---|
| `Region_Manager` | `dim_region[state_province] = USERNAME()` lookup | Regional managers see only their region's data |
| `Plant_Manager` | `dim_plant[manager_name] = USERNAME()` | Plant managers see only their plant |
| `Supplier_Portal` | `dim_supplier[supplier_id] = USERNAME()` | Supplier self-service performance view |
| `Executive` | No filter (full access) | C-suite and VP-level users |

---

*End of Dashboard Wireframe Specifications*
*Reference: 01_supply_chain_kpi_measures.dax and 02_power_bi_data_model.md for measure definitions and data model details.*
