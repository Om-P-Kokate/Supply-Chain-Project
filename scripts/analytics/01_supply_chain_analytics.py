"""
Supply Chain Analytics Script — Automotive Supply Chain Analytics Platform
==========================================================================

WHAT THIS SCRIPT DOES:
    Performs core supply chain analytics calculations on cleaned data.
    Generates KPI summaries, trend analyses, and risk assessments
    that feed into Power BI dashboards and executive reports.

WHY THIS ANALYSIS MATTERS:
    Raw data doesn't answer business questions — analytics does.
    This script transforms cleaned transactional data into
    actionable business intelligence:
    - Which suppliers are underperforming?
    - Which warehouses are at risk?
    - What are the cost drivers?
    - What are the trends?

BUSINESS CONTEXT:
    This mirrors the work a Supply Chain Analyst does BEFORE building
    a Power BI dashboard. You need to understand the data, validate
    KPI calculations, and identify key findings first.
    The outputs here feed directly into Power BI via CSV exports.

HOW TO RUN:
    python scripts/analytics/01_supply_chain_analytics.py

OUTPUT:
    - data/exports/kpi_summary.csv
    - data/exports/supplier_scorecard.csv
    - data/exports/inventory_risk_report.csv
    - data/exports/logistics_efficiency.csv
    - data/exports/monthly_trends.csv
"""

import pandas as pd
import numpy as np
import os
import warnings
warnings.filterwarnings("ignore")

# ============================================================
# CONFIGURATION
# ============================================================

PROCESSED_DIR = "data/processed"
EXPORTS_DIR = "data/exports"
os.makedirs(EXPORTS_DIR, exist_ok=True)


def load_processed(filename):
    """Load a cleaned CSV file."""
    path = os.path.join(PROCESSED_DIR, filename)
    if os.path.exists(path):
        return pd.read_csv(path, parse_dates=True)
    return pd.DataFrame()


# ============================================================
# ANALYSIS 1: SUPPLIER PERFORMANCE SCORECARD
# ============================================================

def analyze_supplier_performance(shipments_df, suppliers_df):
    """
    Build a comprehensive supplier performance scorecard.

    BUSINESS PURPOSE:
    The supplier scorecard is the primary tool procurement teams use
    to manage supplier relationships. It answers:
    - Which suppliers are performing well?
    - Which suppliers need corrective action?
    - How are suppliers trending over time?

    KPIs CALCULATED:
    - On-Time Delivery % (most critical)
    - Average Delay Days
    - Total Shipment Volume
    - Total Shipment Value
    - Transportation Cost per Shipment
    - Defect Rate (from supplier master data)
    - Composite Performance Score

    METHODOLOGY:
    Aggregate shipment-level data to supplier level, then join
    supplier master attributes for a complete view.
    """
    print("\n" + "="*60)
    print("ANALYSIS 1: SUPPLIER PERFORMANCE SCORECARD")
    print("="*60)

    if shipments_df.empty or suppliers_df.empty:
        print("  Skipped — data not available")
        return pd.DataFrame()

    # Ensure date columns are parsed
    if "shipment_date" in shipments_df.columns:
        shipments_df["shipment_date"] = pd.to_datetime(shipments_df["shipment_date"])

    # Aggregate shipment metrics by supplier
    supplier_metrics = shipments_df.groupby("supplier_id").agg(
        total_shipments=("shipment_id", "count"),
        on_time_shipments=("is_on_time", "sum"),
        avg_delay_days=("delay_days", "mean"),
        max_delay_days=("delay_days", "max"),
        total_quantity_shipped=("quantity_shipped", "sum"),
        total_shipment_value_usd=("total_shipment_value_usd", "sum"),
        avg_transportation_cost=("transportation_cost_usd", "mean"),
        total_transportation_cost=("transportation_cost_usd", "sum"),
        total_fuel_cost=("fuel_cost_usd", "sum"),
    ).reset_index()

    # Calculate OTD %
    supplier_metrics["otd_pct"] = (
        supplier_metrics["on_time_shipments"] / supplier_metrics["total_shipments"] * 100
    ).round(2)

    # Join with supplier master data for additional attributes
    scorecard = supplier_metrics.merge(
        suppliers_df[[
            "supplier_id", "supplier_name", "supplier_region",
            "defect_rate_pct", "reliability_score", "supplier_risk_score",
            "risk_tier", "performance_tier", "annual_contract_value_usd",
            "primary_component", "lead_time_days", "certification_status"
        ]],
        on="supplier_id",
        how="left"
    )

    # Calculate composite performance score (used for ranking)
    # Formula: OTD weighted 50% + (100 - defect_rate) weighted 30% + reliability 20%
    # This mirrors how automotive OEMs actually score suppliers
    scorecard["composite_score"] = (
        scorecard["otd_pct"] * 0.50 +
        (100 - scorecard["defect_rate_pct"].fillna(5)) * 0.30 +
        scorecard["reliability_score"].fillna(70) * 0.20
    ).round(2)

    # Performance classification
    def classify_performance(score):
        if score >= 90:
            return "1 - Excellent"
        elif score >= 80:
            return "2 - Good"
        elif score >= 70:
            return "3 - Fair"
        elif score >= 60:
            return "4 - Poor"
        else:
            return "5 - Critical"

    scorecard["performance_grade"] = scorecard["composite_score"].apply(classify_performance)

    # Sort by composite score descending (best performers first)
    scorecard = scorecard.sort_values("composite_score", ascending=False).reset_index(drop=True)
    scorecard["rank"] = range(1, len(scorecard) + 1)

    # Save to exports
    scorecard.to_csv(os.path.join(EXPORTS_DIR, "supplier_scorecard.csv"), index=False)

    print(f"  Suppliers analyzed: {len(scorecard)}")
    print(f"  Average OTD across all suppliers: {scorecard['otd_pct'].mean():.1f}%")
    print(f"  Suppliers with OTD < 85%: {(scorecard['otd_pct'] < 85).sum()}")
    print(f"  Top performer: {scorecard.iloc[0]['supplier_name'] if 'supplier_name' in scorecard.columns else 'N/A'}")
    if len(scorecard) > 0 and "supplier_name" in scorecard.columns:
        worst = scorecard.iloc[-1]
        print(f"  Worst performer: {worst['supplier_name']} ({worst['otd_pct']:.1f}% OTD)")

    return scorecard


# ============================================================
# ANALYSIS 2: INVENTORY RISK ASSESSMENT
# ============================================================

def analyze_inventory_risk(inventory_df, warehouses_df, products_df):
    """
    Analyze inventory health and identify stockout risks.

    BUSINESS PURPOSE:
    In automotive manufacturing, inventory problems are PRODUCTION problems.
    A single missing part can shut down a $1M+/day assembly line.
    This analysis flags WHERE and WHAT is at risk.

    KPIs CALCULATED:
    - Stockout Rate % by warehouse
    - Average Days of Supply by warehouse
    - Inventory Value by warehouse
    - ABC breakdown
    - Items below safety stock
    - Items below reorder point

    METHODOLOGY:
    Take the most recent inventory snapshot (latest date) for each
    warehouse-product combination. This gives the "current state" view
    used on the Power BI Inventory Dashboard.
    """
    print("\n" + "="*60)
    print("ANALYSIS 2: INVENTORY RISK ASSESSMENT")
    print("="*60)

    if inventory_df.empty:
        print("  Skipped — data not available")
        return pd.DataFrame()

    # Parse dates
    if "snapshot_date" in inventory_df.columns:
        inventory_df["snapshot_date"] = pd.to_datetime(inventory_df["snapshot_date"])

    # Get most recent snapshot per warehouse-product combination
    latest_snapshot = inventory_df.loc[
        inventory_df.groupby(["warehouse_id", "product_id"])["snapshot_date"].idxmax()
    ].copy()

    # Aggregate by warehouse for high-level view
    warehouse_inventory = latest_snapshot.groupby("warehouse_id").agg(
        total_sku_count=("product_id", "nunique"),
        total_stock_value=("inventory_value_usd", "sum"),
        avg_days_of_supply=("days_of_supply", "mean"),
        items_below_safety_stock=("is_below_safety_stock", "sum"),
        items_below_reorder=("is_below_reorder", "sum"),
        critical_stockout_items=("stockout_risk_score", lambda x: (x > 80).sum()),
    ).reset_index()

    # Calculate stockout rate %
    warehouse_inventory["stockout_rate_pct"] = (
        warehouse_inventory["items_below_safety_stock"] /
        warehouse_inventory["total_sku_count"] * 100
    ).round(2)

    # Add warehouse risk classification
    def warehouse_risk(row):
        if row["items_below_safety_stock"] > 5 or row["avg_days_of_supply"] < 5:
            return "CRITICAL"
        elif row["items_below_reorder"] > 3 or row["avg_days_of_supply"] < 10:
            return "HIGH RISK"
        elif row["stockout_rate_pct"] > 10:
            return "MEDIUM RISK"
        else:
            return "Healthy"

    warehouse_inventory["warehouse_risk_level"] = warehouse_inventory.apply(warehouse_risk, axis=1)

    # Join with warehouse master data
    if not warehouses_df.empty and "warehouse_id" in warehouses_df.columns:
        warehouse_inventory = warehouse_inventory.merge(
            warehouses_df[["warehouse_id", "warehouse_name", "region", "state",
                          "storage_capacity_units", "current_utilization_pct"]],
            on="warehouse_id",
            how="left"
        )

    # ABC analysis summary
    abc_summary = latest_snapshot.groupby("abc_category").agg(
        item_count=("product_id", "nunique"),
        total_value=("inventory_value_usd", "sum"),
    ).reset_index()
    abc_summary["value_pct"] = (abc_summary["total_value"] / abc_summary["total_value"].sum() * 100).round(1)

    # Save exports
    warehouse_inventory.to_csv(os.path.join(EXPORTS_DIR, "inventory_risk_report.csv"), index=False)

    print(f"  Warehouses analyzed: {len(warehouse_inventory)}")
    critical_wh = warehouse_inventory[warehouse_inventory["warehouse_risk_level"] == "CRITICAL"]
    print(f"  CRITICAL risk warehouses: {len(critical_wh)}")
    high_risk_wh = warehouse_inventory[warehouse_inventory["warehouse_risk_level"] == "HIGH RISK"]
    print(f"  HIGH RISK warehouses: {len(high_risk_wh)}")
    total_value = latest_snapshot["inventory_value_usd"].sum()
    print(f"  Total inventory value: ${total_value:,.0f}")
    overall_stockout = (
        latest_snapshot["is_below_safety_stock"].sum() /
        len(latest_snapshot) * 100
    )
    print(f"  Overall stockout rate: {overall_stockout:.1f}%")

    return warehouse_inventory


# ============================================================
# ANALYSIS 3: LOGISTICS & TRANSPORTATION EFFICIENCY
# ============================================================

def analyze_logistics_efficiency(shipments_df, warehouses_df):
    """
    Analyze transportation costs and logistics efficiency by route and region.

    BUSINESS PURPOSE:
    Transportation is typically 5-8% of revenue in automotive.
    Identifying inefficient routes and high-cost lanes enables
    procurement and logistics teams to renegotiate and optimize.

    KPIs CALCULATED:
    - Cost per Mile by route
    - Delay frequency by carrier
    - Regional cost comparison
    - Mode of transport analysis
    - Monthly cost trends
    """
    print("\n" + "="*60)
    print("ANALYSIS 3: LOGISTICS & TRANSPORTATION EFFICIENCY")
    print("="*60)

    if shipments_df.empty:
        print("  Skipped — data not available")
        return pd.DataFrame()

    # Regional cost analysis
    regional_logistics = shipments_df.groupby(
        ["shipment_year", "shipment_quarter_label"]
    ).agg(
        total_shipments=("shipment_id", "count"),
        on_time_shipments=("is_on_time", "sum"),
        avg_delay_days=("delay_days", "mean"),
        total_transport_cost=("transportation_cost_usd", "sum"),
        total_fuel_cost=("fuel_cost_usd", "sum"),
        avg_cost_per_mile=("cost_per_mile_usd", "mean"),
        avg_distance=("distance_miles", "mean"),
        total_quantity=("quantity_shipped", "sum"),
    ).reset_index()

    regional_logistics["otd_pct"] = (
        regional_logistics["on_time_shipments"] / regional_logistics["total_shipments"] * 100
    ).round(2)

    # Carrier performance analysis
    if "carrier_name" in shipments_df.columns:
        carrier_perf = shipments_df.groupby("carrier_name").agg(
            shipment_count=("shipment_id", "count"),
            otd_pct=("is_on_time", lambda x: x.mean() * 100),
            avg_delay=("delay_days", "mean"),
            avg_cost=("transportation_cost_usd", "mean"),
            total_cost=("transportation_cost_usd", "sum"),
        ).round(2).reset_index()
        carrier_perf.to_csv(os.path.join(EXPORTS_DIR, "carrier_performance.csv"), index=False)

    # Transportation mode analysis
    if "transportation_mode" in shipments_df.columns:
        mode_analysis = shipments_df.groupby("transportation_mode").agg(
            shipment_count=("shipment_id", "count"),
            otd_pct=("is_on_time", lambda x: x.mean() * 100),
            avg_cost=("transportation_cost_usd", "mean"),
            avg_delay=("delay_days", "mean"),
            total_cost=("transportation_cost_usd", "sum"),
            avg_cost_per_mile=("cost_per_mile_usd", "mean"),
        ).round(2).reset_index()
        mode_analysis["cost_share_pct"] = (
            mode_analysis["total_cost"] / mode_analysis["total_cost"].sum() * 100
        ).round(1)
        mode_analysis.to_csv(os.path.join(EXPORTS_DIR, "transport_mode_analysis.csv"), index=False)

    regional_logistics.to_csv(os.path.join(EXPORTS_DIR, "logistics_efficiency.csv"), index=False)

    print(f"  Time periods analyzed: {len(regional_logistics)}")
    total_transport = shipments_df["transportation_cost_usd"].sum()
    print(f"  Total transportation spend: ${total_transport:,.0f}")
    avg_otd = shipments_df["is_on_time"].mean() * 100
    print(f"  Overall OTD rate: {avg_otd:.1f}%")
    if "carrier_name" in shipments_df.columns:
        print(f"  Carriers analyzed: {shipments_df['carrier_name'].nunique()}")

    return regional_logistics


# ============================================================
# ANALYSIS 4: EXECUTIVE KPI SUMMARY
# ============================================================

def calculate_executive_kpis(shipments_df, inventory_df, sales_df, production_df, suppliers_df):
    """
    Calculate the top-line KPIs shown on the Executive Overview Dashboard.

    BUSINESS PURPOSE:
    The executive dashboard shows the "health of the supply chain at a glance."
    C-suite executives need to see 6-8 critical numbers at any time,
    with trend direction (up/down arrows) and RAG status (Red/Amber/Green).

    KPIs CALCULATED:
    - On-Time Delivery %
    - Total Shipments
    - Total Inventory Value
    - Average Supplier Reliability Score
    - Total Transportation Cost
    - Plant Utilization %
    - Stockout Rate %
    - Forecast Accuracy %
    """
    print("\n" + "="*60)
    print("ANALYSIS 4: EXECUTIVE KPI SUMMARY")
    print("="*60)

    kpis = {}

    # --- SUPPLY CHAIN KPIs ---
    if not shipments_df.empty:
        kpis["on_time_delivery_pct"] = round(shipments_df["is_on_time"].mean() * 100, 2)
        kpis["total_shipments"] = int(len(shipments_df))
        kpis["total_transportation_cost_usd"] = round(shipments_df["transportation_cost_usd"].sum(), 2)
        kpis["avg_delay_days"] = round(shipments_df[shipments_df["delay_days"] > 0]["delay_days"].mean(), 2)
        kpis["delayed_shipments_count"] = int((shipments_df["delay_days"] > 0).sum())
        kpis["delayed_shipments_pct"] = round(kpis["delayed_shipments_count"] / kpis["total_shipments"] * 100, 2)

    # --- INVENTORY KPIs ---
    if not inventory_df.empty:
        if "snapshot_date" in inventory_df.columns:
            inventory_df["snapshot_date"] = pd.to_datetime(inventory_df["snapshot_date"])
            latest_inv = inventory_df[
                inventory_df["snapshot_date"] == inventory_df["snapshot_date"].max()
            ]
        else:
            latest_inv = inventory_df
        kpis["total_inventory_value_usd"] = round(latest_inv["inventory_value_usd"].sum(), 2)
        kpis["stockout_rate_pct"] = round(latest_inv["is_below_safety_stock"].mean() * 100, 2)
        kpis["avg_days_of_supply"] = round(latest_inv["days_of_supply"].mean(), 2)

    # --- SUPPLIER KPIs ---
    if not suppliers_df.empty:
        kpis["avg_supplier_reliability_score"] = round(suppliers_df["reliability_score"].mean(), 2)
        kpis["high_risk_suppliers"] = int((suppliers_df.get("risk_tier", pd.Series()) == "High Risk").sum())
        kpis["suppliers_below_85_otd"] = int((suppliers_df["delivery_performance_pct"] < 85).sum())

    # --- PRODUCTION KPIs ---
    if not production_df.empty:
        kpis["avg_plant_utilization_pct"] = round(production_df["utilization_rate_pct"].mean(), 2)
        kpis["avg_defect_rate_pct"] = round(production_df["defect_rate_pct"].mean(), 3)
        kpis["total_production_units"] = int(production_df["actual_production_units"].sum())
        kpis["total_downtime_hours"] = round(production_df["downtime_hours"].sum(), 1)

    # --- SALES KPIs ---
    if not sales_df.empty:
        kpis["total_revenue_usd"] = round(sales_df["revenue_usd"].sum(), 2)
        kpis["total_units_sold"] = int(sales_df["units_sold"].sum())
        kpis["avg_forecast_accuracy_pct"] = round(sales_df["forecast_accuracy_pct"].mean(), 2)

    # Derived KPIs
    if "total_transportation_cost_usd" in kpis and "total_revenue_usd" in kpis:
        if kpis["total_revenue_usd"] > 0:
            kpis["transportation_cost_ratio_pct"] = round(
                kpis["total_transportation_cost_usd"] / kpis["total_revenue_usd"] * 100, 2
            )

    # Save KPI summary
    kpi_df = pd.DataFrame([kpis])
    kpi_df.to_csv(os.path.join(EXPORTS_DIR, "kpi_summary.csv"), index=False)

    # Print KPIs
    print("\n  EXECUTIVE KPI SUMMARY:")
    kpi_display = {
        "On-Time Delivery %": f"{kpis.get('on_time_delivery_pct', 'N/A')}%",
        "Total Shipments": f"{kpis.get('total_shipments', 'N/A'):,}",
        "Total Inventory Value": f"${kpis.get('total_inventory_value_usd', 0):,.0f}",
        "Avg Supplier Reliability": f"{kpis.get('avg_supplier_reliability_score', 'N/A')}/100",
        "Total Transportation Cost": f"${kpis.get('total_transportation_cost_usd', 0):,.0f}",
        "Plant Utilization %": f"{kpis.get('avg_plant_utilization_pct', 'N/A')}%",
        "Stockout Rate %": f"{kpis.get('stockout_rate_pct', 'N/A')}%",
        "Forecast Accuracy %": f"{kpis.get('avg_forecast_accuracy_pct', 'N/A')}%",
        "Total Revenue": f"${kpis.get('total_revenue_usd', 0):,.0f}",
        "Transportation Cost Ratio": f"{kpis.get('transportation_cost_ratio_pct', 'N/A')}%",
    }
    for name, value in kpi_display.items():
        print(f"    {name}: {value}")

    return kpis


# ============================================================
# ANALYSIS 5: MONTHLY TREND ANALYSIS
# ============================================================

def analyze_monthly_trends(shipments_df, sales_df, production_df):
    """
    Build monthly trend data for time-series charts in Power BI.

    BUSINESS PURPOSE:
    Trend analysis reveals whether performance is improving or deteriorating.
    Month-over-month and year-over-year comparisons are the two most common
    time comparisons used by supply chain leadership in their weekly reviews.

    OUTPUT:
    A unified monthly trends table that can be used to power:
    - OTD trend line chart
    - Revenue trend chart
    - Production trend chart
    - Cost trend chart
    """
    print("\n" + "="*60)
    print("ANALYSIS 5: MONTHLY TREND ANALYSIS")
    print("="*60)

    monthly_frames = []

    if not shipments_df.empty and "shipment_year" in shipments_df.columns:
        shipment_trends = shipments_df.groupby(
            ["shipment_year", "shipment_month"]
        ).agg(
            shipment_count=("shipment_id", "count"),
            otd_pct=("is_on_time", lambda x: round(x.mean() * 100, 2)),
            avg_delay=("delay_days", "mean"),
            transport_cost=("transportation_cost_usd", "sum"),
            fuel_cost=("fuel_cost_usd", "sum"),
        ).reset_index()
        shipment_trends.rename(
            columns={"shipment_year": "year", "shipment_month": "month"}, inplace=True
        )
        monthly_frames.append(shipment_trends)

    if not sales_df.empty and "order_year" in sales_df.columns:
        sales_trends = sales_df.groupby(
            ["order_year", "order_month"]
        ).agg(
            units_sold=("units_sold", "sum"),
            revenue_usd=("revenue_usd", "sum"),
            avg_forecast_accuracy=("forecast_accuracy_pct", "mean"),
        ).reset_index()
        sales_trends.rename(
            columns={"order_year": "year", "order_month": "month"}, inplace=True
        )

        if monthly_frames:
            monthly_frames[0] = monthly_frames[0].merge(
                sales_trends, on=["year", "month"], how="left"
            )
        else:
            monthly_frames.append(sales_trends)

    if not production_df.empty and "production_year" in production_df.columns:
        prod_trends = production_df.groupby(
            ["production_year", "production_month"]
        ).agg(
            actual_production=("actual_production_units", "sum"),
            planned_production=("planned_production_units", "sum"),
            total_downtime=("downtime_hours", "sum"),
            avg_utilization=("utilization_rate_pct", "mean"),
        ).reset_index()
        prod_trends.rename(
            columns={"production_year": "year", "production_month": "month"}, inplace=True
        )

        if monthly_frames:
            monthly_frames[0] = monthly_frames[0].merge(
                prod_trends, on=["year", "month"], how="left"
            )
        else:
            monthly_frames.append(prod_trends)

    if monthly_frames:
        monthly_trends = monthly_frames[0].sort_values(["year", "month"]).reset_index(drop=True)
        monthly_trends.to_csv(os.path.join(EXPORTS_DIR, "monthly_trends.csv"), index=False)
        print(f"  Monthly trend records: {len(monthly_trends)}")
        print(f"  Date range: {monthly_trends['year'].min()} - {monthly_trends['year'].max()}")
        return monthly_trends

    return pd.DataFrame()


# ============================================================
# MAIN FUNCTION
# ============================================================

def main():
    """Run all supply chain analytics."""
    print("=" * 60)
    print("AUTOMOTIVE SUPPLY CHAIN ANALYTICS")
    print("Supply Chain Intelligence Platform")
    print("=" * 60)

    # Load cleaned data
    print("\nLoading cleaned data...")
    suppliers_df = load_processed("suppliers_clean.csv")
    shipments_df = load_processed("shipments_clean.csv")
    inventory_df = load_processed("inventory_clean.csv")
    production_df = load_processed("production_clean.csv")
    sales_df = load_processed("sales_clean.csv")
    warehouses_df = load_processed("warehouses_clean.csv")
    products_df = load_processed("products_clean.csv")

    loaded = {
        "suppliers": len(suppliers_df),
        "shipments": len(shipments_df),
        "inventory": len(inventory_df),
        "production": len(production_df),
        "sales": len(sales_df),
    }
    for table, count in loaded.items():
        print(f"  {table}: {count:,} rows")

    if all(count == 0 for count in loaded.values()):
        print("\n  No cleaned data found. Run data_cleaning_pipeline.py first.")
        print("  Or run generate_datasets.py then data_cleaning_pipeline.py")
        return

    # Run all analyses
    scorecard = analyze_supplier_performance(shipments_df, suppliers_df)
    inventory_risk = analyze_inventory_risk(inventory_df, warehouses_df, products_df)
    logistics = analyze_logistics_efficiency(shipments_df, warehouses_df)
    kpis = calculate_executive_kpis(
        shipments_df, inventory_df, sales_df, production_df, suppliers_df
    )
    trends = analyze_monthly_trends(shipments_df, sales_df, production_df)

    print("\n" + "=" * 60)
    print("ANALYTICS COMPLETE")
    print(f"  Exports saved to: {EXPORTS_DIR}/")
    print("  Files generated:")
    for f in os.listdir(EXPORTS_DIR):
        size_kb = os.path.getsize(os.path.join(EXPORTS_DIR, f)) / 1024
        print(f"    {f} ({size_kb:.1f} KB)")
    print("=" * 60)


if __name__ == "__main__":
    main()
