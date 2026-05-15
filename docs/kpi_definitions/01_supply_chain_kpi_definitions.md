# Supply Chain KPI Definitions & Business Reference Guide
## Automotive Supply Chain Intelligence Platform

---

## HOW TO USE THIS DOCUMENT

This document defines every KPI used in the Automotive Supply Chain Analytics Platform.
For each KPI you will find:
- **What it measures** — plain English definition
- **Why it matters** — business reason for tracking it
- **How it's calculated** — formula
- **Target / Benchmark** — industry standard for U.S. automotive
- **Warning thresholds** — when to raise an alert
- **Power BI location** — which dashboard shows it
- **Business action** — what decision-makers should do based on the KPI

---

## SECTION 1: SUPPLY CHAIN DELIVERY KPIs

---

### 1.1 On-Time Delivery % (OTD)

| Field | Detail |
|-------|--------|
| **Definition** | Percentage of shipments delivered on or before the promised delivery date |
| **Formula** | (Shipments with delay_days ≤ 0) / Total Shipments × 100 |
| **Target** | ≥ 95% (Automotive industry standard) |
| **Warning** | < 90% triggers supplier review |
| **Critical** | < 85% triggers contract escalation |
| **Dashboard** | Executive Overview, Supplier Performance, Logistics |
| **Data Source** | fact_shipments |

**Business Meaning:**
OTD is the most fundamental supply chain metric. In automotive manufacturing,
a single delayed part can halt an entire assembly line costing $1M+ per hour.
Ford, GM, and Toyota use OTD as the primary supplier evaluation criterion.

**Business Action:**
- OTD < 90% → Trigger supplier corrective action plan (SCAP)
- OTD < 85% → Consider dual-sourcing strategy for that part
- OTD trending down 3+ months → Escalate to procurement leadership

---

### 1.2 Perfect Order Rate (POR)

| Field | Detail |
|-------|--------|
| **Definition** | % of orders delivered: on time, in full, with no damage, and with correct documentation |
| **Formula** | (OTD% × Fill Rate% × No-Defect Rate% × Documentation Accuracy%) / 10,000 |
| **Target** | ≥ 90% |
| **Warning** | < 85% |
| **Dashboard** | Executive Overview |

**Business Meaning:**
POR is the gold standard supply chain metric because it measures TOTAL order
perfection across all dimensions simultaneously. A shipment that arrives on time
but is damaged does NOT count as a perfect order. Automotive OEMs use POR to
evaluate supplier contracts.

**Business Action:**
- Decompose low POR into its components to find the biggest drag
- Most automotive companies find that OTD is the biggest POR killer (60-70% of issues)

---

### 1.3 Average Lead Time (ALT)

| Field | Detail |
|-------|--------|
| **Definition** | Average number of days from order placement to delivery |
| **Formula** | AVG(actual_delivery_date - shipment_date) |
| **Target** | Varies by component: Critical parts ≤ 5 days, Standard parts ≤ 14 days |
| **Warning** | > 20% above contracted lead time |
| **Dashboard** | Supplier Performance |

**Business Meaning:**
Lead time drives inventory levels. Longer lead times force companies to hold MORE
safety stock, tying up working capital. Semiconductor shortages in 2021-2022
caused lead times for chips to spike from 12 weeks to 52+ weeks, directly
causing production shutdowns at Ford, GM, and Toyota.

---

### 1.4 Fill Rate %

| Field | Detail |
|-------|--------|
| **Definition** | % of customer/plant demand that is filled from available inventory without backorders |
| **Formula** | Units Shipped / Units Ordered × 100 |
| **Target** | ≥ 98% for critical components |
| **Warning** | < 95% |
| **Dashboard** | Inventory & Warehouse, Executive Overview |

**Business Meaning:**
Fill Rate measures whether inventory is in the right place at the right time.
A 95% fill rate means 5% of orders are NOT fully satisfied from stock — those
5% either cause production delays or require expensive emergency procurement.

---

## SECTION 2: INVENTORY KPIs

---

### 2.1 Inventory Turnover Ratio

| Field | Detail |
|-------|--------|
| **Definition** | How many times inventory is completely sold/used in a given period |
| **Formula** | Cost of Goods Used / Average Inventory Value |
| **Target** | 8-12x per year (automotive standard) |
| **Warning** | < 6x (overstocked) or > 15x (understocked) |
| **Dashboard** | Inventory & Warehouse |

**Business Meaning:**
Higher turnover = less cash tied up in inventory = more efficient operations.
Toyota's famous Just-In-Time (JIT) system targets very high turnover.
However, too-high turnover with insufficient safety stock creates stockout risk
(as Toyota experienced during COVID-19 and the 2011 Japan earthquake).

**Calculation Example:**
- Annual COGS = $50M
- Average Inventory Value = $6M
- Inventory Turnover = 50/6 = 8.3x (healthy)

---

### 2.2 Days Inventory Outstanding (DIO)

| Field | Detail |
|-------|--------|
| **Definition** | Average number of days inventory is held before being used |
| **Formula** | 365 / Inventory Turnover Ratio |
| **Target** | 30-45 days (automotive) |
| **Warning** | > 60 days (too much cash tied up) |
| **Dashboard** | Inventory & Warehouse |

---

### 2.3 Stockout Rate %

| Field | Detail |
|-------|--------|
| **Definition** | % of SKU-location combinations that have fallen below safety stock level |
| **Formula** | Count(stock_quantity < safety_stock_level) / Total SKU-Locations × 100 |
| **Target** | < 2% |
| **Warning** | > 5% |
| **Critical** | > 10% (production risk) |
| **Dashboard** | Inventory & Warehouse |

**Business Meaning:**
In automotive, a stockout of a single critical component (e.g., a specific
microcontroller) can shut down an entire vehicle assembly line. Ford lost
~$1B in revenue in 2021 due to chip stockouts forcing plant shutdowns.

---

### 2.4 Warehouse Utilization %

| Field | Detail |
|-------|--------|
| **Definition** | % of total warehouse storage capacity currently in use |
| **Formula** | Current Inventory Units / Maximum Storage Capacity × 100 |
| **Target** | 75-85% (optimal range) |
| **Warning Low** | < 60% (underutilized, wasted cost) |
| **Warning High** | > 90% (too full, receiving/picking efficiency drops) |
| **Dashboard** | Inventory & Warehouse |

---

### 2.5 Safety Stock Coverage (Days of Supply)

| Field | Detail |
|-------|--------|
| **Definition** | How many days of production demand current inventory can cover |
| **Formula** | Current Stock Quantity / Average Daily Demand |
| **Target** | 10-30 days (critical parts), 7-14 days (standard parts) |
| **Critical** | < 3 days (emergency reorder required) |
| **Dashboard** | Inventory & Warehouse |

---

## SECTION 3: SUPPLIER KPIs

---

### 3.1 Supplier Reliability Score

| Field | Detail |
|-------|--------|
| **Definition** | Composite score (0-100) measuring overall supplier trustworthiness |
| **Formula** | Weighted average: OTD(40%) + Quality(30%) + Lead Time Consistency(20%) + Documentation(10%) |
| **Target** | ≥ 85/100 |
| **Warning** | < 75 |
| **Critical** | < 65 (supplier improvement plan required) |
| **Dashboard** | Supplier Performance & Risk |

---

### 3.2 Supplier Defect Rate %

| Field | Detail |
|-------|--------|
| **Definition** | % of incoming parts/materials that fail quality inspection |
| **Formula** | Defective Units Received / Total Units Received × 100 |
| **Target** | < 0.5% (500 PPM — Parts Per Million) |
| **Warning** | > 1% |
| **Critical** | > 3% |
| **Dashboard** | Supplier Performance & Risk, Manufacturing Operations |

**Business Meaning:**
Every defective part received from a supplier either gets caught in incoming
inspection (costing time/money) or slips through to assembly (costing much more
— typically 10x-100x more to fix defects further down the production line).

---

### 3.3 Supplier Risk Score

| Field | Detail |
|-------|--------|
| **Definition** | Composite risk rating (1-10, higher = riskier) based on financial, geopolitical, and operational factors |
| **Formula** | Weighted model: Financial Risk(30%) + Geopolitical Risk(20%) + Delivery Risk(25%) + Quality Risk(25%) |
| **Target** | < 4 (Low Risk) |
| **Warning** | 4-7 (Medium Risk) |
| **Critical** | > 7 (High Risk) |
| **Dashboard** | Supplier Performance & Risk |

---

## SECTION 4: MANUFACTURING KPIs

---

### 4.1 Plant Utilization Rate %

| Field | Detail |
|-------|--------|
| **Definition** | % of total production capacity actually being used |
| **Formula** | Actual Production Units / Planned Production Capacity × 100 |
| **Target** | 80-90% (optimal) |
| **Warning Low** | < 70% (underutilized, fixed costs spread over fewer units) |
| **Warning High** | > 95% (risk of quality issues and equipment strain) |
| **Dashboard** | Manufacturing Operations |

**Business Meaning:**
A plant running at 75% utilization is absorbing the same fixed costs (depreciation,
labor, utilities) as one running at 90% but producing 17% fewer vehicles. GM
targets ~85% utilization across its North American plants as the sweet spot
for cost efficiency without sacrificing quality.

---

### 4.2 Downtime % (Unplanned)

| Field | Detail |
|-------|--------|
| **Definition** | % of scheduled production time lost to unplanned stoppages |
| **Formula** | Unplanned Downtime Hours / Total Scheduled Hours × 100 |
| **Target** | < 5% |
| **Warning** | > 8% |
| **Critical** | > 12% |
| **Dashboard** | Manufacturing Operations |

**Downtime Categories:**
1. Equipment Failure (mechanical breakdown)
2. Material Shortage (stockout-caused)
3. Quality Hold (defective incoming parts)
4. Changeover (planned, excluded from unplanned metric)
5. Labor (absenteeism, training)
6. Utility Failure (power, compressed air)

---

### 4.3 Overall Equipment Effectiveness (OEE)

| Field | Detail |
|-------|--------|
| **Definition** | Gold standard manufacturing metric combining availability, performance, and quality |
| **Formula** | Availability % × Performance % × Quality % |
| **Target** | ≥ 85% (world-class manufacturing) |
| **Good** | 65-85% |
| **Warning** | < 65% |
| **Dashboard** | Manufacturing Operations |

**Component Definitions:**
- **Availability** = (Scheduled Time - Downtime) / Scheduled Time
- **Performance** = Actual Output Rate / Ideal Output Rate
- **Quality** = Good Units / Total Units Produced

**Example:**
- Availability = 95%, Performance = 90%, Quality = 98%
- OEE = 0.95 × 0.90 × 0.98 = 83.8% (world-class)

---

### 4.4 Manufacturing Defect Rate (Outgoing)

| Field | Detail |
|-------|--------|
| **Definition** | % of vehicles/assemblies produced that have quality defects |
| **Formula** | Defective Units / Total Units Produced × 100 |
| **Target** | < 1% |
| **Warning** | > 2% |
| **Dashboard** | Manufacturing Operations, Executive Overview |

---

## SECTION 5: LOGISTICS KPIs

---

### 5.1 Transportation Cost Ratio (TCR)

| Field | Detail |
|-------|--------|
| **Definition** | Transportation costs as a % of total revenue — measures logistics efficiency |
| **Formula** | Total Transportation Cost / Total Revenue × 100 |
| **Target** | 3-5% (automotive standard) |
| **Warning** | > 7% |
| **Dashboard** | Logistics & Transportation |

**Business Meaning:**
Transportation costs in automotive are heavily influenced by fuel prices, route
optimization, and carrier mix. Road vs rail vs air have dramatically different cost
profiles. Air freight costs 5-10x more than truck but is sometimes necessary for
critical parts during supply disruptions.

---

### 5.2 Average Transportation Cost per Shipment

| Field | Detail |
|-------|--------|
| **Definition** | Average cost to transport one shipment |
| **Formula** | Total Transportation Cost / Number of Shipments |
| **Benchmark** | $850-$1,200 per truckload shipment (2024 U.S. average) |
| **Dashboard** | Logistics & Transportation |

---

### 5.3 Freight Cost per Unit

| Field | Detail |
|-------|--------|
| **Definition** | Transportation cost allocated per unit shipped |
| **Formula** | Total Transportation Cost / Total Units Shipped |
| **Dashboard** | Logistics & Transportation |

---

## SECTION 6: DEMAND & SALES KPIs

---

### 6.1 Forecast Accuracy %

| Field | Detail |
|-------|--------|
| **Definition** | How close demand forecasts are to actual sales/demand |
| **Formula** | 100 - (|Actual - Forecast| / Actual × 100) |
| **Also Known As** | 100 - MAPE (Mean Absolute Percentage Error) |
| **Target** | ≥ 85% (weekly), ≥ 90% (monthly) |
| **Warning** | < 75% |
| **Dashboard** | Demand & Sales |

**Business Meaning:**
Poor forecast accuracy is the ROOT CAUSE of most supply chain problems.
Overforecasting → excess inventory (capital tied up, storage costs)
Underforecasting → stockouts, production delays, lost sales

---

### 6.2 Revenue Growth % (YoY)

| Field | Detail |
|-------|--------|
| **Definition** | Year-over-year revenue growth |
| **Formula** | (Current Year Revenue - Prior Year Revenue) / Prior Year Revenue × 100 |
| **Target** | Varies by OEM and market conditions |
| **Dashboard** | Demand & Sales, Executive Overview |

---

### 6.3 Vehicle Category Mix %

| Field | Detail |
|-------|--------|
| **Definition** | % of revenue/units by vehicle category (EV, SUV, Truck, Sedan, etc.) |
| **Business Use** | Identifies demand shifts (e.g., EV transition accelerating) |
| **Dashboard** | Demand & Sales |

---

## APPENDIX: KPI TRAFFIC LIGHT SUMMARY

| KPI | Green (Good) | Yellow (Warning) | Red (Critical) |
|-----|-------------|------------------|----------------|
| On-Time Delivery % | ≥ 95% | 85-95% | < 85% |
| Inventory Turnover | 8-12x | 6-8x or 12-15x | < 6x or > 15x |
| Fill Rate % | ≥ 98% | 95-98% | < 95% |
| Stockout Rate % | < 2% | 2-5% | > 5% |
| Warehouse Utilization % | 75-85% | 60-75% or 85-90% | < 60% or > 90% |
| Supplier Reliability | ≥ 85 | 75-85 | < 75 |
| Defect Rate % | < 0.5% | 0.5-2% | > 2% |
| Plant Utilization % | 80-90% | 70-80% or > 95% | < 70% |
| Downtime % | < 5% | 5-10% | > 10% |
| Forecast Accuracy % | ≥ 90% | 75-90% | < 75% |
| Transportation Cost Ratio | < 5% | 5-7% | > 7% |
| Perfect Order Rate % | ≥ 95% | 85-95% | < 85% |

---

*Document Version: 1.0 | Last Updated: 2024 | Automotive Supply Chain Intelligence Platform*
