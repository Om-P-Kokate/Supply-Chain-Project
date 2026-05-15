"""
Data Cleaning Pipeline — Automotive Supply Chain Analytics Platform
====================================================================

WHAT THIS SCRIPT DOES:
    Takes raw synthetic CSV data and transforms it into clean, analysis-ready
    data for Power BI, SQL, and Python analytics.

WHY WE NEED DATA CLEANING:
    Even "clean" synthetic data benefits from standardization steps that
    mirror what you'd do in a real automotive analytics project:
    - Standardizing date formats for Power BI compatibility
    - Validating calculated fields (delay_days, revenue, etc.)
    - Adding derived columns used in dashboards
    - Checking referential integrity between tables
    - Flagging outliers and anomalies for analyst review
    - Generating a data quality report

BUSINESS CONTEXT:
    In real automotive companies, data comes from multiple source systems:
    ERP (SAP), WMS (Oracle), TMS (various), MES, CRM.
    Each system has different formats, naming conventions, and data quality.
    This pipeline standardizes everything into the analytical data model.

HOW TO RUN:
    python scripts/data_cleaning/01_data_cleaning_pipeline.py

OUTPUT:
    - data/processed/ — cleaned CSV files ready for Power BI import
    - data/exports/ — Excel files for stakeholder sharing
    - docs/data_quality_report.txt — automated data quality summary
"""

import pandas as pd
import numpy as np
import os
import logging
from datetime import datetime, date

# ============================================================
# CONFIGURATION
# ============================================================

# File paths
RAW_DATA_DIR = "data/raw"
PROCESSED_DATA_DIR = "data/processed"
EXPORTS_DIR = "data/exports"
DOCS_DIR = "docs"

# Set up logging — tracks all cleaning steps for audit trail
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("docs/data_cleaning_log.txt"),
    ]
)
logger = logging.getLogger(__name__)


# ============================================================
# UTILITY FUNCTIONS
# ============================================================

def load_csv(filename: str) -> pd.DataFrame:
    """Load a CSV file from the raw data directory."""
    filepath = os.path.join(RAW_DATA_DIR, filename)
    if not os.path.exists(filepath):
        logger.error(f"File not found: {filepath}")
        raise FileNotFoundError(f"Raw data file missing: {filepath}")
    df = pd.read_csv(filepath)
    logger.info(f"Loaded {filename}: {len(df):,} rows, {len(df.columns)} columns")
    return df


def save_processed(df: pd.DataFrame, filename: str):
    """Save cleaned DataFrame to processed directory."""
    filepath = os.path.join(PROCESSED_DATA_DIR, filename)
    df.to_csv(filepath, index=False)
    logger.info(f"Saved processed file: {filename} ({len(df):,} rows)")


def data_quality_check(df: pd.DataFrame, table_name: str) -> dict:
    """
    Run standard data quality checks and return a quality report dictionary.

    WHY: In BI projects, you ALWAYS validate data before presenting to stakeholders.
    A dashboard built on dirty data destroys trust — and in supply chain, bad data
    leads to bad decisions (ordering too much/little inventory, wrong supplier actions).
    """
    report = {
        "table": table_name,
        "total_rows": len(df),
        "total_columns": len(df.columns),
        "null_counts": df.isnull().sum().to_dict(),
        "null_pct": (df.isnull().sum() / len(df) * 100).round(2).to_dict(),
        "duplicates": df.duplicated().sum(),
        "dtypes": df.dtypes.astype(str).to_dict(),
    }
    return report


def format_quality_report(reports: list) -> str:
    """Format quality reports into readable text."""
    lines = [
        "=" * 60,
        "DATA QUALITY REPORT",
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "Automotive Supply Chain Analytics Platform",
        "=" * 60,
        ""
    ]

    total_rows = 0
    for r in reports:
        total_rows += r["total_rows"]
        lines.append(f"TABLE: {r['table']}")
        lines.append(f"  Rows: {r['total_rows']:,}")
        lines.append(f"  Columns: {r['total_columns']}")
        lines.append(f"  Duplicate rows: {r['duplicates']}")

        # Show nulls only where they exist
        null_issues = {k: v for k, v in r["null_pct"].items() if v > 0}
        if null_issues:
            lines.append("  Null percentages:")
            for col, pct in null_issues.items():
                status = "⚠️ WARNING" if pct > 5 else "OK"
                lines.append(f"    {col}: {pct:.1f}% null  {status}")
        else:
            lines.append("  Nulls: None found ✓")
        lines.append("")

    lines.append(f"TOTAL ROWS ACROSS ALL TABLES: {total_rows:,}")
    lines.append("=" * 60)
    return "\n".join(lines)


# ============================================================
# TABLE-SPECIFIC CLEANING FUNCTIONS
# ============================================================

def clean_suppliers(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and enrich the suppliers dimension table.

    KEY CLEANING STEPS:
    1. Standardize text fields (strip whitespace, proper case)
    2. Validate score ranges (all scores should be 0-100)
    3. Add risk tier classification column (used in Power BI for color coding)
    4. Calculate a composite supplier health index
    """
    logger.info("Cleaning suppliers table...")

    # Step 1: Standardize text columns
    text_cols = ["supplier_name", "supplier_region", "supplier_country",
                 "supplier_type", "primary_component", "certification_status"]
    for col in text_cols:
        if col in df.columns:
            df[col] = df[col].str.strip().str.title()

    # Step 2: Validate score ranges
    # In real data, sometimes scores get corrupted or miscalculated
    df["reliability_score"] = df["reliability_score"].clip(0, 100)
    df["delivery_performance_pct"] = df["delivery_performance_pct"].clip(0, 100)
    df["defect_rate_pct"] = df["defect_rate_pct"].clip(0, 100)
    df["supplier_risk_score"] = df["supplier_risk_score"].clip(1, 10)

    # Step 3: Add supplier risk tier (used for color coding in Power BI)
    # This is a DERIVED COLUMN — calculated from existing data
    def get_risk_tier(risk_score):
        if risk_score <= 3:
            return "Low Risk"
        elif risk_score <= 6:
            return "Medium Risk"
        else:
            return "High Risk"

    df["risk_tier"] = df["supplier_risk_score"].apply(get_risk_tier)

    # Step 4: Add performance tier based on reliability score
    def get_performance_tier(score):
        if score >= 90:
            return "Preferred Supplier"
        elif score >= 80:
            return "Approved Supplier"
        elif score >= 70:
            return "Conditional Supplier"
        else:
            return "Probationary Supplier"

    df["performance_tier"] = df["reliability_score"].apply(get_performance_tier)

    # Step 5: Flag single-source risk
    # In a real project this would join to a separate table, but here we approximate
    # Suppliers with high contract value and high risk score = dangerous single-source
    df["single_source_risk_flag"] = (
        (df["supplier_risk_score"] > 6) &
        (df["annual_contract_value_usd"] > 10_000_000)
    ).astype(int)

    logger.info(f"Suppliers cleaned. Risk tiers: {df['risk_tier'].value_counts().to_dict()}")
    return df


def clean_shipments(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and enrich the shipments fact table.

    KEY CLEANING STEPS:
    1. Parse and validate all date columns
    2. Recalculate delay_days (validate against date columns)
    3. Add on-time flag (OTD indicator)
    4. Add shipment month/year for time series analysis
    5. Validate financial amounts (no negatives)
    6. Classify delay severity
    """
    logger.info("Cleaning shipments table...")

    # Step 1: Parse date columns
    date_cols = ["shipment_date", "expected_delivery_date", "actual_delivery_date"]
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col])

    # Step 2: Recalculate delay_days from actual dates
    # WHY: Never trust a pre-calculated delay field — validate it
    if all(col in df.columns for col in date_cols):
        calculated_delay = (df["actual_delivery_date"] - df["expected_delivery_date"]).dt.days
        # Flag discrepancies (more than 1 day difference = data issue)
        discrepancies = (abs(calculated_delay - df["delay_days"]) > 1).sum()
        if discrepancies > 0:
            logger.warning(f"Found {discrepancies} delay_days discrepancies — recalculating")
        df["delay_days"] = calculated_delay

    # Step 3: Add on-time delivery flag (1 = on time, 0 = delayed)
    # This is the CORE KPI field — "On-Time Delivery %"
    df["is_on_time"] = (df["delay_days"] <= 0).astype(int)

    # Step 4: Classify delay severity for root cause analysis
    def classify_delay(days):
        if days <= 0:
            return "On Time"
        elif days <= 2:
            return "Minor Delay (1-2 days)"
        elif days <= 5:
            return "Moderate Delay (3-5 days)"
        elif days <= 10:
            return "Significant Delay (6-10 days)"
        else:
            return "Critical Delay (>10 days)"

    df["delay_category"] = df["delay_days"].apply(classify_delay)

    # Step 5: Add time period columns for Power BI slicing
    if "shipment_date" in df.columns:
        df["shipment_year"] = df["shipment_date"].dt.year
        df["shipment_month"] = df["shipment_date"].dt.month
        df["shipment_month_name"] = df["shipment_date"].dt.strftime("%b")
        df["shipment_quarter"] = df["shipment_date"].dt.quarter
        df["shipment_quarter_label"] = "Q" + df["shipment_quarter"].astype(str) + " " + df["shipment_year"].astype(str)

    # Step 6: Validate financial amounts
    financial_cols = ["transportation_cost_usd", "fuel_cost_usd", "unit_cost_usd"]
    for col in financial_cols:
        if col in df.columns:
            negative_count = (df[col] < 0).sum()
            if negative_count > 0:
                logger.warning(f"Found {negative_count} negative values in {col} — setting to 0")
            df[col] = df[col].clip(lower=0)

    # Step 7: Add total shipment value column
    if "quantity_shipped" in df.columns and "unit_cost_usd" in df.columns:
        df["total_shipment_value_usd"] = df["quantity_shipped"] * df["unit_cost_usd"]

    # Step 8: Add cost per mile for efficiency analysis
    if "transportation_cost_usd" in df.columns and "distance_miles" in df.columns:
        df["cost_per_mile_usd"] = np.where(
            df["distance_miles"] > 0,
            df["transportation_cost_usd"] / df["distance_miles"],
            0
        ).round(2)

    # Step 9: Standardize status field
    if "shipment_status" in df.columns:
        df["shipment_status"] = df["shipment_status"].str.strip().str.title()

    on_time_pct = df["is_on_time"].mean() * 100
    logger.info(f"Shipments cleaned. On-Time Delivery: {on_time_pct:.1f}%")
    return df


def clean_inventory(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and enrich the inventory fact table.

    KEY CLEANING STEPS:
    1. Validate stock quantities (no negatives)
    2. Recalculate inventory value
    3. Add stockout alert flags
    4. Recalculate days_of_supply
    5. Add inventory health status
    """
    logger.info("Cleaning inventory table...")

    # Step 1: Parse date columns
    date_cols = ["snapshot_date", "last_replenishment_date"]
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col])

    # Step 2: Validate stock quantities
    if "stock_quantity" in df.columns:
        df["stock_quantity"] = df["stock_quantity"].clip(lower=0)

    # Step 3: Add stockout alert flag
    # Critical business logic: when stock_quantity < safety_stock → stockout risk
    if all(col in df.columns for col in ["stock_quantity", "safety_stock_level"]):
        df["is_below_safety_stock"] = (df["stock_quantity"] < df["safety_stock_level"]).astype(int)
        df["is_below_reorder"] = (df["stock_quantity"] < df["reorder_level"]).astype(int)

    # Step 4: Add inventory health status (used in Power BI conditional formatting)
    def inventory_health_status(row):
        if row.get("stock_quantity", 0) < row.get("safety_stock_level", 0):
            return "CRITICAL - Below Safety Stock"
        elif row.get("stock_quantity", 0) < row.get("reorder_level", 0):
            return "WARNING - Reorder Required"
        elif row.get("days_of_supply", 999) > 60:
            return "OVERSTOCK - Review"
        else:
            return "Healthy"

    df["inventory_status"] = df.apply(inventory_health_status, axis=1)

    # Step 5: Add time period columns
    if "snapshot_date" in df.columns:
        df["snapshot_year"] = df["snapshot_date"].dt.year
        df["snapshot_month"] = df["snapshot_date"].dt.month
        df["snapshot_quarter"] = df["snapshot_date"].dt.quarter

    status_dist = df["inventory_status"].value_counts().to_dict()
    logger.info(f"Inventory cleaned. Status distribution: {status_dist}")
    return df


def clean_production(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and enrich the production fact table.

    KEY CLEANING STEPS:
    1. Parse date columns
    2. Validate production quantities
    3. Recalculate utilization rate
    4. Add OEE components
    5. Classify downtime by severity
    """
    logger.info("Cleaning production table...")

    # Parse dates
    if "production_date" in df.columns:
        df["production_date"] = pd.to_datetime(df["production_date"])
        df["production_year"] = df["production_date"].dt.year
        df["production_month"] = df["production_date"].dt.month
        df["production_quarter"] = df["production_date"].dt.quarter

    # Validate quantities (cannot be negative)
    qty_cols = ["planned_production_units", "actual_production_units", "defect_units"]
    for col in qty_cols:
        if col in df.columns:
            df[col] = df[col].clip(lower=0)

    # Defect units cannot exceed actual production
    if all(col in df.columns for col in ["actual_production_units", "defect_units"]):
        df["defect_units"] = df[["defect_units", "actual_production_units"]].min(axis=1)

    # Recalculate good units
    if all(col in df.columns for col in ["actual_production_units", "defect_units"]):
        df["good_units"] = df["actual_production_units"] - df["defect_units"]

    # Recalculate utilization rate (validate against planned/actual)
    if all(col in df.columns for col in ["actual_production_units", "planned_production_units"]):
        df["utilization_rate_pct"] = np.where(
            df["planned_production_units"] > 0,
            (df["actual_production_units"] / df["planned_production_units"] * 100).round(2),
            0
        ).clip(0, 100)

    # Calculate defect rate
    if all(col in df.columns for col in ["defect_units", "actual_production_units"]):
        df["defect_rate_pct"] = np.where(
            df["actual_production_units"] > 0,
            (df["defect_units"] / df["actual_production_units"] * 100).round(3),
            0
        )

    # Classify downtime severity
    def classify_downtime(hours):
        if hours == 0:
            return "No Downtime"
        elif hours < 1:
            return "Minor (<1hr)"
        elif hours < 4:
            return "Moderate (1-4hrs)"
        elif hours < 8:
            return "Major (4-8hrs)"
        else:
            return "Critical (>8hrs)"

    if "downtime_hours" in df.columns:
        df["downtime_category"] = df["downtime_hours"].apply(classify_downtime)
        df["has_downtime"] = (df["downtime_hours"] > 0).astype(int)

    avg_util = df["utilization_rate_pct"].mean() if "utilization_rate_pct" in df.columns else 0
    logger.info(f"Production cleaned. Average utilization: {avg_util:.1f}%")
    return df


def clean_sales(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and enrich the sales/demand fact table.

    KEY CLEANING STEPS:
    1. Parse date columns
    2. Validate revenue calculations
    3. Add forecast accuracy classification
    4. Add YoY comparison columns
    5. Add vehicle category groupings
    """
    logger.info("Cleaning sales table...")

    # Parse dates
    date_cols = ["order_date", "delivery_date"]
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col])

    # Add time period columns
    if "order_date" in df.columns:
        df["order_year"] = df["order_date"].dt.year
        df["order_month"] = df["order_date"].dt.month
        df["order_quarter"] = df["order_date"].dt.quarter
        df["order_quarter_label"] = "Q" + df["order_quarter"].astype(str) + " " + df["order_year"].astype(str)
        df["order_month_name"] = df["order_date"].dt.strftime("%b")

    # Validate revenue
    if all(col in df.columns for col in ["units_sold", "unit_price_usd"]):
        calculated_revenue = df["units_sold"] * df["unit_price_usd"]
        discrepancies = (abs(calculated_revenue - df["revenue_usd"]) > 1).sum()
        if discrepancies > 0:
            logger.warning(f"Found {discrepancies} revenue discrepancies — recalculating")
        df["revenue_usd"] = calculated_revenue

    # Add forecast accuracy classification
    if "forecast_accuracy_pct" in df.columns:
        def classify_forecast(pct):
            if pct >= 95:
                return "Excellent (≥95%)"
            elif pct >= 85:
                return "Good (85-95%)"
            elif pct >= 75:
                return "Fair (75-85%)"
            else:
                return "Poor (<75%)"
        df["forecast_accuracy_tier"] = df["forecast_accuracy_pct"].apply(classify_forecast)

    # Add EV flag for EV-specific analysis
    ev_categories = ["Electric Vehicle", "EV", "Battery Electric Vehicle",
                     "Electric Truck", "Electric Suv", "Electric Sedan"]
    if "vehicle_category" in df.columns:
        df["is_ev"] = df["vehicle_category"].str.contains(
            "Electric|EV|Battery", case=False, na=False
        ).astype(int)

    total_revenue = df["revenue_usd"].sum() if "revenue_usd" in df.columns else 0
    logger.info(f"Sales cleaned. Total revenue: ${total_revenue:,.0f}")
    return df


def clean_warehouses(df: pd.DataFrame) -> pd.DataFrame:
    """Clean the warehouses dimension table."""
    logger.info("Cleaning warehouses table...")

    text_cols = ["warehouse_name", "region", "state", "city", "warehouse_type"]
    for col in text_cols:
        if col in df.columns:
            df[col] = df[col].str.strip().str.title()

    if "current_utilization_pct" in df.columns:
        df["current_utilization_pct"] = df["current_utilization_pct"].clip(0, 100)

        def warehouse_util_status(pct):
            if pct < 60:
                return "Underutilized (<60%)"
            elif pct <= 75:
                return "Low (60-75%)"
            elif pct <= 85:
                return "Optimal (75-85%)"
            elif pct <= 95:
                return "High (85-95%)"
            else:
                return "At Capacity (>95%)"

        df["utilization_status"] = df["current_utilization_pct"].apply(warehouse_util_status)

    logger.info("Warehouses cleaned.")
    return df


# ============================================================
# MAIN PIPELINE
# ============================================================

def run_cleaning_pipeline():
    """
    Main function — runs the complete data cleaning pipeline.

    This function:
    1. Loads all raw CSV files
    2. Runs table-specific cleaning functions
    3. Performs data quality checks
    4. Saves processed files
    5. Generates data quality report
    """
    logger.info("=" * 60)
    logger.info("STARTING DATA CLEANING PIPELINE")
    logger.info("Automotive Supply Chain Analytics Platform")
    logger.info("=" * 60)

    # Create output directories if they don't exist
    os.makedirs(PROCESSED_DATA_DIR, exist_ok=True)
    os.makedirs(EXPORTS_DIR, exist_ok=True)

    quality_reports = []
    processed_tables = {}

    # ---- CLEAN EACH TABLE ----

    # Suppliers
    if os.path.exists(os.path.join(RAW_DATA_DIR, "suppliers.csv")):
        df = load_csv("suppliers.csv")
        quality_reports.append(data_quality_check(df, "suppliers (raw)"))
        df = clean_suppliers(df)
        quality_reports.append(data_quality_check(df, "suppliers (cleaned)"))
        save_processed(df, "suppliers_clean.csv")
        processed_tables["suppliers"] = df

    # Shipments
    if os.path.exists(os.path.join(RAW_DATA_DIR, "shipments.csv")):
        df = load_csv("shipments.csv")
        quality_reports.append(data_quality_check(df, "shipments (raw)"))
        df = clean_shipments(df)
        quality_reports.append(data_quality_check(df, "shipments (cleaned)"))
        save_processed(df, "shipments_clean.csv")
        processed_tables["shipments"] = df

    # Inventory
    if os.path.exists(os.path.join(RAW_DATA_DIR, "inventory.csv")):
        df = load_csv("inventory.csv")
        quality_reports.append(data_quality_check(df, "inventory (raw)"))
        df = clean_inventory(df)
        quality_reports.append(data_quality_check(df, "inventory (cleaned)"))
        save_processed(df, "inventory_clean.csv")
        processed_tables["inventory"] = df

    # Production
    if os.path.exists(os.path.join(RAW_DATA_DIR, "production.csv")):
        df = load_csv("production.csv")
        quality_reports.append(data_quality_check(df, "production (raw)"))
        df = clean_production(df)
        quality_reports.append(data_quality_check(df, "production (cleaned)"))
        save_processed(df, "production_clean.csv")
        processed_tables["production"] = df

    # Sales
    if os.path.exists(os.path.join(RAW_DATA_DIR, "sales_demand.csv")):
        df = load_csv("sales_demand.csv")
        quality_reports.append(data_quality_check(df, "sales (raw)"))
        df = clean_sales(df)
        quality_reports.append(data_quality_check(df, "sales (cleaned)"))
        save_processed(df, "sales_clean.csv")
        processed_tables["sales"] = df

    # Warehouses
    if os.path.exists(os.path.join(RAW_DATA_DIR, "warehouses.csv")):
        df = load_csv("warehouses.csv")
        quality_reports.append(data_quality_check(df, "warehouses (raw)"))
        df = clean_warehouses(df)
        quality_reports.append(data_quality_check(df, "warehouses (cleaned)"))
        save_processed(df, "warehouses_clean.csv")
        processed_tables["warehouses"] = df

    # Plants — just load and save (minimal cleaning needed)
    if os.path.exists(os.path.join(RAW_DATA_DIR, "plants.csv")):
        df = load_csv("plants.csv")
        quality_reports.append(data_quality_check(df, "plants"))
        save_processed(df, "plants_clean.csv")
        processed_tables["plants"] = df

    # Products — just load and save
    if os.path.exists(os.path.join(RAW_DATA_DIR, "products.csv")):
        df = load_csv("products.csv")
        quality_reports.append(data_quality_check(df, "products"))
        save_processed(df, "products_clean.csv")
        processed_tables["products"] = df

    # ---- SAVE DATA QUALITY REPORT ----
    quality_report_text = format_quality_report(quality_reports)
    report_path = os.path.join(DOCS_DIR, "data_quality_report.txt")
    with open(report_path, "w") as f:
        f.write(quality_report_text)
    logger.info(f"Data quality report saved to {report_path}")

    # ---- PRINT SUMMARY ----
    logger.info("=" * 60)
    logger.info("CLEANING PIPELINE COMPLETE")
    logger.info(f"Tables processed: {list(processed_tables.keys())}")
    total_rows = sum(len(df) for df in processed_tables.values())
    logger.info(f"Total rows processed: {total_rows:,}")
    logger.info(f"Processed files saved to: {PROCESSED_DATA_DIR}/")
    logger.info("=" * 60)

    return processed_tables


if __name__ == "__main__":
    run_cleaning_pipeline()
