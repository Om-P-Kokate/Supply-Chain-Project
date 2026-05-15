"""
Demand Forecasting — Automotive Supply Chain Analytics Platform
===============================================================

WHAT THIS SCRIPT DOES:
    Generates demand forecasts for vehicle sales using Prophet (Facebook's
    time series forecasting library). Also includes a lightweight shipment
    delay predictor using XGBoost.

WHY FORECASTING MATTERS IN AUTOMOTIVE SUPPLY CHAINS:
    Demand forecasting is the STARTING POINT of the entire supply chain.
    If we know how many F-150s will be sold next quarter, we can:
    - Order the right amount of steel, semiconductors, and components
    - Schedule the right production volumes at each plant
    - Pre-position inventory in the right warehouses
    - Negotiate the right freight capacity with carriers

    Poor forecasting = either too much or too little inventory
    Too much = wasted capital tied up in unsold parts
    Too little = production shutdowns and lost sales

    Tesla, Ford, GM all use sophisticated demand sensing systems.
    This script implements a lightweight version appropriate for a portfolio project.

MODELS USED:
    1. Prophet — for demand time series forecasting
       - Handles seasonality (Q4 demand peaks in automotive)
       - Handles holidays (plant shutdowns, Black Friday effects)
       - Easy to interpret for business users (trend + seasonality decomposition)

    2. XGBoost — for shipment delay classification
       - Predicts probability that a shipment will be delayed
       - Uses supplier history, route, season, and transportation mode as features
       - Outputs: delay probability score (0-1) for each planned shipment

HOW TO RUN:
    pip install prophet xgboost scikit-learn
    python scripts/forecasting/01_demand_forecasting.py

OUTPUT:
    - data/exports/demand_forecast_2025.csv (12-month forward forecast)
    - data/exports/delay_prediction_model_performance.csv
    - data/exports/supplier_risk_scores_ml.csv
"""

import pandas as pd
import numpy as np
import os
import warnings
warnings.filterwarnings("ignore")

# Check for optional ML libraries
PROPHET_AVAILABLE = False
XGBOOST_AVAILABLE = False
SKLEARN_AVAILABLE = False

try:
    from prophet import Prophet
    PROPHET_AVAILABLE = True
except ImportError:
    pass

try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    pass

try:
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import LabelEncoder
    from sklearn.metrics import accuracy_score, classification_report, roc_auc_score
    from sklearn.ensemble import RandomForestClassifier
    SKLEARN_AVAILABLE = True
except ImportError:
    pass

PROCESSED_DIR = "data/processed"
EXPORTS_DIR = "data/exports"
os.makedirs(EXPORTS_DIR, exist_ok=True)


def load_processed(filename):
    path = os.path.join(PROCESSED_DIR, filename)
    if os.path.exists(path):
        return pd.read_csv(path, parse_dates=True)
    return pd.DataFrame()


# ============================================================
# MODEL 1: DEMAND FORECASTING WITH PROPHET
# ============================================================

def forecast_vehicle_demand(sales_df: pd.DataFrame) -> pd.DataFrame:
    """
    Forecast vehicle demand for the next 12 months using Prophet.

    BUSINESS PURPOSE:
    Generate a 12-month demand forecast by vehicle category.
    This feeds into:
    - Production planning (how many vehicles to build)
    - Procurement planning (how many parts to order)
    - Inventory planning (how much safety stock to hold)

    HOW PROPHET WORKS:
    Prophet decomposes a time series into:
    1. Trend (long-term growth/decline)
    2. Yearly seasonality (Q4 peaks in automotive)
    3. Weekly seasonality (weekday vs weekend orders)
    4. Holiday effects (plant shutdowns)
    5. Residual noise

    WHY PROPHET FOR AUTOMOTIVE?
    - Handles the strong Q4 seasonality in vehicle sales
    - Robust to missing data and outliers (COVID disruptions)
    - Provides uncertainty intervals (important for inventory planning)
    - Business-interpretable components

    INPUT:
    - Monthly aggregated sales data by vehicle category

    OUTPUT:
    - 12-month forecast with upper/lower confidence intervals
    """
    print("\n" + "="*60)
    print("MODEL 1: VEHICLE DEMAND FORECASTING (Prophet)")
    print("="*60)

    if sales_df.empty:
        print("  Skipped — sales data not available")
        return pd.DataFrame()

    # Parse dates
    if "order_date" in sales_df.columns:
        sales_df["order_date"] = pd.to_datetime(sales_df["order_date"])
    else:
        print("  Skipped — no order_date column")
        return pd.DataFrame()

    # Aggregate to monthly total units sold
    monthly_sales = sales_df.groupby(
        pd.Grouper(key="order_date", freq="ME")
    )["units_sold"].sum().reset_index()
    monthly_sales.columns = ["ds", "y"]
    monthly_sales = monthly_sales[monthly_sales["y"] > 0]

    if len(monthly_sales) < 24:
        print(f"  Warning: Only {len(monthly_sales)} months of data — forecast may be less reliable")
        print("  Proceeding with available data...")

    if not PROPHET_AVAILABLE:
        print("  Prophet not installed. Using simple trend-based forecast instead.")
        print("  Install with: pip install prophet")
        return _simple_trend_forecast(monthly_sales)

    try:
        # Initialize Prophet with automotive seasonality patterns
        model = Prophet(
            yearly_seasonality=True,     # Q4 is always strongest in automotive
            weekly_seasonality=False,    # We're using monthly data, not daily
            daily_seasonality=False,
            seasonality_mode="multiplicative",  # Multiplicative handles growth better
            changepoint_prior_scale=0.1,         # Conservative — don't overfit to COVID spikes
            interval_width=0.80,                 # 80% confidence intervals
        )

        # Add automotive-specific seasonality
        # Q4 (Oct-Dec) is typically the strongest sales quarter
        # Q1 (Jan-Feb) is typically the weakest
        model.add_seasonality(
            name="automotive_quarterly",
            period=91.25,    # ~3 months
            fourier_order=5,
        )

        # Fit the model
        model.fit(monthly_sales)

        # Generate 12-month future forecast
        future = model.make_future_dataframe(periods=12, freq="ME")
        forecast = model.predict(future)

        # Keep only the forward-looking predictions (not historical)
        forecast_future = forecast[forecast["ds"] > monthly_sales["ds"].max()][[
            "ds", "yhat", "yhat_lower", "yhat_upper", "trend", "yearly"
        ]].copy()

        forecast_future.columns = [
            "forecast_date", "forecasted_units", "forecast_lower_bound",
            "forecast_upper_bound", "trend_component", "seasonality_component"
        ]

        # Round to integers (you can't sell 0.3 of a vehicle)
        forecast_future["forecasted_units"] = forecast_future["forecasted_units"].clip(0).round(0).astype(int)
        forecast_future["forecast_lower_bound"] = forecast_future["forecast_lower_bound"].clip(0).round(0).astype(int)
        forecast_future["forecast_upper_bound"] = forecast_future["forecast_upper_bound"].clip(0).round(0).astype(int)

        forecast_future["forecast_month"] = forecast_future["forecast_date"].dt.strftime("%b %Y")
        forecast_future["model_used"] = "Prophet"

        # Calculate MAPE on historical data
        historical_forecast = forecast[forecast["ds"].isin(monthly_sales["ds"])][["ds", "yhat"]]
        merged = monthly_sales.merge(historical_forecast, on="ds")
        mape = abs(merged["y"] - merged["yhat"]) / merged["y"].replace(0, np.nan)
        mape_pct = (1 - mape.mean()) * 100

        forecast_future.to_csv(os.path.join(EXPORTS_DIR, "demand_forecast_2025.csv"), index=False)

        print(f"  Training data: {len(monthly_sales)} months")
        print(f"  Forecast horizon: 12 months")
        print(f"  Model accuracy (historical MAPE-based): {mape_pct:.1f}%")
        print(f"  Forecast saved: data/exports/demand_forecast_2025.csv")

        total_forecast = forecast_future["forecasted_units"].sum()
        print(f"  12-month total forecasted units: {total_forecast:,}")

        return forecast_future

    except Exception as e:
        print(f"  Prophet model failed: {e}")
        print("  Falling back to trend-based forecast...")
        return _simple_trend_forecast(monthly_sales)


def _simple_trend_forecast(monthly_sales: pd.DataFrame) -> pd.DataFrame:
    """
    Simple trend-based forecast when Prophet is not available.
    Uses linear regression on recent 12 months + seasonal adjustment.
    """
    if len(monthly_sales) < 6:
        return pd.DataFrame()

    # Use last 12 months to fit trend
    recent = monthly_sales.tail(12).copy()
    recent["t"] = range(len(recent))

    # Linear trend
    from numpy.polynomial import polynomial as P
    coeffs = np.polyfit(recent["t"], recent["y"], 1)
    slope, intercept = coeffs

    # Generate 12 months forward
    last_t = recent["t"].max()
    last_date = monthly_sales["ds"].max()
    future_dates = pd.date_range(start=last_date + pd.DateOffset(months=1), periods=12, freq="ME")

    # Seasonal factors based on month (automotive patterns)
    seasonal_factors = {
        1: 0.82, 2: 0.80, 3: 0.95, 4: 0.98,   # Q1 weak, Q2 building
        5: 1.02, 6: 1.05, 7: 0.95, 8: 1.00,    # Q2 strong, Q3 moderate
        9: 1.03, 10: 1.08, 11: 1.10, 12: 1.12   # Q4 strongest
    }

    forecasts = []
    for i, date in enumerate(future_dates):
        t = last_t + i + 1
        base_forecast = max(0, slope * t + intercept)
        seasonal_adj = base_forecast * seasonal_factors.get(date.month, 1.0)
        forecasts.append({
            "forecast_date": date,
            "forecasted_units": max(0, int(seasonal_adj)),
            "forecast_lower_bound": max(0, int(seasonal_adj * 0.85)),
            "forecast_upper_bound": int(seasonal_adj * 1.15),
            "forecast_month": date.strftime("%b %Y"),
            "model_used": "Linear Trend + Seasonal Adjustment"
        })

    forecast_df = pd.DataFrame(forecasts)
    forecast_df.to_csv(os.path.join(EXPORTS_DIR, "demand_forecast_2025.csv"), index=False)

    print(f"  Simple trend forecast generated (12 months)")
    print(f"  Total forecasted units: {forecast_df['forecasted_units'].sum():,}")
    return forecast_df


# ============================================================
# MODEL 2: SHIPMENT DELAY PREDICTION
# ============================================================

def predict_shipment_delays(shipments_df: pd.DataFrame, suppliers_df: pd.DataFrame) -> dict:
    """
    Train a classifier to predict whether a planned shipment will be delayed.

    BUSINESS PURPOSE:
    If we can predict WHICH shipments are likely to be delayed BEFORE they happen,
    we can take proactive action:
    - Alert the receiving warehouse to adjust plans
    - Trigger emergency backup orders for critical parts
    - Notify production planning to adjust schedules
    - Contact the carrier/supplier to expedite

    This shifts supply chain management from REACTIVE to PROACTIVE.

    MODEL APPROACH:
    Binary classification: Will this shipment be delayed? (Yes/No)

    FEATURES USED:
    - Supplier's historical OTD rate (most predictive)
    - Supplier's risk score
    - Transportation mode (air is more reliable than truck)
    - Shipping month (weather-related delays higher in Jan, Feb, Dec)
    - Route distance (longer routes = more delay risk)
    - Shipment weight (heavier = more delay risk)

    MODEL: XGBoost (or Random Forest if XGBoost not available)
    - Fast to train
    - Handles mixed data types well
    - Produces interpretable feature importance
    - Industry standard for tabular data

    TARGET METRIC:
    - ROC-AUC (because we care about ranking delay probability, not just yes/no)
    - Precision at high recall (we want to catch most delays even if some false alarms)
    """
    print("\n" + "="*60)
    print("MODEL 2: SHIPMENT DELAY PREDICTION")
    print("="*60)

    if not SKLEARN_AVAILABLE:
        print("  Scikit-learn not installed. Skipping.")
        print("  Install with: pip install scikit-learn xgboost")
        return {}

    if shipments_df.empty:
        print("  Skipped — shipments data not available")
        return {}

    # ---- FEATURE ENGINEERING ----
    # Build feature matrix from shipment data
    print("  Building feature matrix...")

    df = shipments_df.copy()

    # Parse dates
    for col in ["shipment_date"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col])

    # Add supplier performance features if suppliers data available
    if not suppliers_df.empty:
        supplier_features = suppliers_df[[
            "supplier_id", "delivery_performance_pct",
            "supplier_risk_score", "defect_rate_pct", "lead_time_days"
        ]].copy()
        df = df.merge(supplier_features, on="supplier_id", how="left", suffixes=("", "_supplier"))

    # Build feature columns
    features = []

    # Supplier features (most predictive based on domain knowledge)
    if "delivery_performance_pct" in df.columns:
        features.append("delivery_performance_pct")
        df["delivery_performance_pct"] = df["delivery_performance_pct"].fillna(85)

    if "supplier_risk_score" in df.columns:
        features.append("supplier_risk_score")
        df["supplier_risk_score"] = df["supplier_risk_score"].fillna(5)

    if "defect_rate_pct" in df.columns:
        features.append("defect_rate_pct")
        df["defect_rate_pct"] = df["defect_rate_pct"].fillna(2)

    # Shipment characteristics
    if "distance_miles" in df.columns:
        features.append("distance_miles")
        df["distance_miles"] = df["distance_miles"].fillna(df["distance_miles"].median())

    if "shipment_weight_lbs" in df.columns:
        features.append("shipment_weight_lbs")
        df["shipment_weight_lbs"] = df["shipment_weight_lbs"].fillna(df["shipment_weight_lbs"].median())

    if "quantity_shipped" in df.columns:
        features.append("quantity_shipped")

    # Time features — seasonality matters for delays (winter weather, Q4 congestion)
    if "shipment_date" in df.columns:
        df["ship_month"] = df["shipment_date"].dt.month
        df["ship_quarter"] = df["shipment_date"].dt.quarter
        df["is_winter"] = df["ship_month"].isin([11, 12, 1, 2]).astype(int)
        df["is_q4"] = (df["ship_quarter"] == 4).astype(int)
        features.extend(["ship_month", "is_winter", "is_q4"])

    # Categorical features — encode for ML
    le = LabelEncoder()
    if "transportation_mode" in df.columns:
        df["transport_mode_encoded"] = le.fit_transform(df["transportation_mode"].fillna("Truck"))
        features.append("transport_mode_encoded")

    # Target variable
    if "is_on_time" not in df.columns:
        print("  No is_on_time column — skipping delay prediction")
        return {}

    df["is_delayed"] = 1 - df["is_on_time"]  # 1 = delayed, 0 = on time

    # Filter to only rows with all features
    feature_df = df[features + ["is_delayed"]].dropna()

    if len(feature_df) < 100:
        print(f"  Insufficient data for modeling ({len(feature_df)} rows)")
        return {}

    X = feature_df[features]
    y = feature_df["is_delayed"]

    # Train/test split (80/20, time-ordered if possible)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"  Training samples: {len(X_train):,}")
    print(f"  Test samples: {len(X_test):,}")
    print(f"  Delayed rate in training: {y_train.mean()*100:.1f}%")

    # Train model
    if XGBOOST_AVAILABLE:
        print("  Training XGBoost classifier...")
        model = xgb.XGBClassifier(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.1,
            use_label_encoder=False,
            eval_metric="auc",
            random_state=42,
            verbosity=0,
        )
    else:
        print("  XGBoost not available. Using Random Forest...")
        model = RandomForestClassifier(
            n_estimators=100, max_depth=6, random_state=42, n_jobs=-1
        )

    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    accuracy = accuracy_score(y_test, y_pred) * 100
    auc = roc_auc_score(y_test, y_proba) * 100

    print(f"\n  MODEL PERFORMANCE:")
    print(f"    Accuracy: {accuracy:.1f}%")
    print(f"    ROC-AUC: {auc:.1f}%")

    # Feature importance
    if hasattr(model, "feature_importances_"):
        importance_df = pd.DataFrame({
            "feature": features,
            "importance": model.feature_importances_
        }).sort_values("importance", ascending=False)

        print(f"\n  TOP DELAY PREDICTORS:")
        for _, row in importance_df.head(5).iterrows():
            print(f"    {row['feature']}: {row['importance']:.3f}")

        importance_df.to_csv(
            os.path.join(EXPORTS_DIR, "delay_prediction_feature_importance.csv"), index=False
        )

    # Save model performance summary
    performance_summary = pd.DataFrame([{
        "model_type": "XGBoost" if XGBOOST_AVAILABLE else "Random Forest",
        "accuracy_pct": round(accuracy, 2),
        "roc_auc_pct": round(auc, 2),
        "training_samples": len(X_train),
        "test_samples": len(X_test),
        "features_used": len(features),
        "positive_rate_pct": round(y.mean() * 100, 2),
    }])
    performance_summary.to_csv(
        os.path.join(EXPORTS_DIR, "delay_prediction_model_performance.csv"), index=False
    )

    return {
        "model": model,
        "accuracy": accuracy,
        "auc": auc,
        "features": features
    }


# ============================================================
# MODEL 3: SUPPLIER RISK SCORING
# ============================================================

def calculate_supplier_risk_scores(suppliers_df: pd.DataFrame, shipments_df: pd.DataFrame) -> pd.DataFrame:
    """
    Calculate data-driven supplier risk scores using a weighted scoring model.

    BUSINESS PURPOSE:
    Procurement teams need to prioritize which suppliers to focus on.
    A risk score helps identify:
    - Which suppliers need immediate attention
    - Which suppliers need dual-sourcing
    - Which suppliers should be audited

    SCORING METHODOLOGY:
    This uses a weighted scorecard approach (not pure ML) because:
    1. It's interpretable — procurement can explain the score to suppliers
    2. It incorporates domain knowledge about what matters in automotive
    3. It's auditable for supplier disputes

    RISK FACTORS:
    - On-Time Delivery performance (30%) — most critical
    - Defect rate history (25%) — quality impact
    - Lead time consistency (20%) — planning reliability
    - Contract value concentration (15%) — financial exposure if supplier fails
    - Supplier's own risk rating (10%) — baseline risk

    OUTPUT:
    Updated supplier table with calculated risk scores and tier classifications
    """
    print("\n" + "="*60)
    print("MODEL 3: SUPPLIER RISK SCORING")
    print("="*60)

    if suppliers_df.empty:
        print("  Skipped — supplier data not available")
        return pd.DataFrame()

    df = suppliers_df.copy()

    # If we have shipments, calculate actual OTD from transactions
    if not shipments_df.empty and "supplier_id" in shipments_df.columns:
        actual_otd = shipments_df.groupby("supplier_id")["is_on_time"].mean() * 100
        df = df.merge(actual_otd.rename("calculated_otd_pct"), on="supplier_id", how="left")
        # Use calculated OTD if available, fall back to supplier master
        df["effective_otd"] = df["calculated_otd_pct"].fillna(df["delivery_performance_pct"])
    else:
        df["effective_otd"] = df["delivery_performance_pct"]

    # ---- RISK SCORING COMPONENTS ----

    # Component 1: OTD Risk (0-30 points, lower OTD = higher risk)
    # Normalize: 100% OTD = 0 risk points, 70% OTD = 30 risk points
    df["otd_risk_score"] = (
        (100 - df["effective_otd"].clip(70, 100)) / 30 * 30
    ).clip(0, 30)

    # Component 2: Defect Rate Risk (0-25 points)
    # Normalize: 0% defect = 0 risk, 5%+ defect = 25 risk
    df["defect_risk_score"] = (
        (df["defect_rate_pct"].clip(0, 5) / 5) * 25
    ).clip(0, 25)

    # Component 3: Lead Time Risk (0-20 points)
    # Longer lead times = higher risk (less ability to respond to disruptions)
    # Normalize: 7 days = low risk, 60+ days = high risk
    df["lead_time_risk_score"] = (
        (df["lead_time_days"].clip(7, 60) - 7) / 53 * 20
    ).clip(0, 20)

    # Component 4: Financial Concentration Risk (0-15 points)
    # High-value single supplier = high risk if they fail
    max_value = df["annual_contract_value_usd"].max()
    df["concentration_risk_score"] = (
        (df["annual_contract_value_usd"] / max_value) * 15
    ).clip(0, 15)

    # Component 5: Base Risk Score (0-10 points)
    # From supplier master data (incorporates geopolitical, financial health, etc.)
    df["base_risk_score_component"] = (
        (df["supplier_risk_score"] - 1) / 9 * 10
    ).clip(0, 10)

    # ---- COMPOSITE RISK SCORE ----
    df["composite_risk_score"] = (
        df["otd_risk_score"] +
        df["defect_risk_score"] +
        df["lead_time_risk_score"] +
        df["concentration_risk_score"] +
        df["base_risk_score_component"]
    ).round(2)

    # Normalize to 0-100 scale
    df["risk_score_0_100"] = (df["composite_risk_score"] / 100 * 100).clip(0, 100).round(1)

    # Risk tier classification
    def risk_tier(score):
        if score <= 25:
            return "Low Risk (Green)"
        elif score <= 50:
            return "Moderate Risk (Yellow)"
        elif score <= 75:
            return "High Risk (Orange)"
        else:
            return "Critical Risk (Red)"

    df["risk_tier_calculated"] = df["risk_score_0_100"].apply(risk_tier)

    # Priority action
    def priority_action(score):
        if score <= 25:
            return "Standard Monitoring"
        elif score <= 50:
            return "Enhanced Monitoring — Quarterly Review"
        elif score <= 75:
            return "Corrective Action Plan Required"
        else:
            return "IMMEDIATE ESCALATION — Consider Dual-Sourcing"

    df["recommended_action"] = df["risk_score_0_100"].apply(priority_action)

    # Sort by risk score descending (most risky first)
    df = df.sort_values("risk_score_0_100", ascending=False).reset_index(drop=True)

    # Save
    output_cols = [
        "supplier_id", "supplier_name", "supplier_region", "primary_component",
        "effective_otd", "defect_rate_pct", "lead_time_days", "annual_contract_value_usd",
        "composite_risk_score", "risk_score_0_100", "risk_tier_calculated", "recommended_action",
        "otd_risk_score", "defect_risk_score", "lead_time_risk_score",
        "concentration_risk_score", "base_risk_score_component"
    ]
    output_cols = [c for c in output_cols if c in df.columns]
    df[output_cols].to_csv(os.path.join(EXPORTS_DIR, "supplier_risk_scores_ml.csv"), index=False)

    print(f"  Suppliers scored: {len(df)}")
    print(f"  Risk distribution:")
    print(df["risk_tier_calculated"].value_counts().to_string())
    print(f"  Highest risk supplier: {df.iloc[0].get('supplier_name', 'N/A')} "
          f"(score: {df.iloc[0]['risk_score_0_100']:.1f})")

    return df


# ============================================================
# MAIN
# ============================================================

def main():
    """Run all forecasting and predictive analytics."""
    print("=" * 60)
    print("AUTOMOTIVE SUPPLY CHAIN — PREDICTIVE ANALYTICS")
    print("=" * 60)

    # Load data
    sales_df = load_processed("sales_clean.csv")
    shipments_df = load_processed("shipments_clean.csv")
    suppliers_df = load_processed("suppliers_clean.csv")

    print(f"\nData loaded:")
    print(f"  Sales: {len(sales_df):,} rows")
    print(f"  Shipments: {len(shipments_df):,} rows")
    print(f"  Suppliers: {len(suppliers_df)} rows")

    if all(len(df) == 0 for df in [sales_df, shipments_df, suppliers_df]):
        print("\nNo cleaned data found. Run the following first:")
        print("  1. python scripts/data_generation/generate_datasets.py")
        print("  2. python scripts/data_cleaning/01_data_cleaning_pipeline.py")
        return

    # Run models
    forecast_df = forecast_vehicle_demand(sales_df)
    delay_results = predict_shipment_delays(shipments_df, suppliers_df)
    risk_scores = calculate_supplier_risk_scores(suppliers_df, shipments_df)

    print("\n" + "=" * 60)
    print("PREDICTIVE ANALYTICS COMPLETE")
    print(f"  Exports saved to: {EXPORTS_DIR}/")
    print("=" * 60)


if __name__ == "__main__":
    main()
