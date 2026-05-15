"""
generate_datasets.py
====================
Generates realistic synthetic automotive supply chain datasets for U.S. OEM companies:
Ford, Tesla, GM, Toyota, Rivian, and BMW (U.S. plants).

WHY THIS DATA?
--------------
Automotive supply chains are among the most complex in the world. A single vehicle
contains ~30,000 parts sourced from hundreds of suppliers across multiple tiers.
This dataset simulates the operational reality of managing that complexity, including:
  - Supplier reliability and risk
  - Warehouse inventory dynamics
  - Production scheduling and disruptions
  - Sales demand seasonality
  - The 2022 chip shortage and COVID-era disruptions

OUTPUT
------
All CSVs are written to /home/user/Supply-Chain-Project/data/raw/

TABLE SUMMARY
-------------
  suppliers.csv        50 rows    - Tier-1 and Tier-2 suppliers with risk metrics
  warehouses.csv       20 rows    - Regional distribution centers and part warehouses
  plants.csv           15 rows    - OEM manufacturing plants across the U.S.
  products.csv         30 rows    - Components and sub-assemblies
  shipments.csv        50,000+ rows - 3 years of inbound shipment records (2022-2024)
  inventory.csv        30,000+ rows - Daily warehouse inventory snapshots
  sales_demand.csv     30,000+ rows - Vehicle order and delivery records
  production.csv       20,000+ rows - Daily production line records per plant per shift

USAGE
-----
  python generate_datasets.py

DEPENDENCIES
------------
  pip install pandas numpy faker
"""

import os
import random
from datetime import datetime, timedelta, date

import numpy as np
import pandas as pd
from faker import Faker

# ---------------------------------------------------------------------------
# GLOBAL CONFIGURATION
# ---------------------------------------------------------------------------

# Reproducible output: fix all random seeds
RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

fake = Faker("en_US")
Faker.seed(RANDOM_SEED)

# Output directory
OUTPUT_DIR = "/home/user/Supply-Chain-Project/data/raw"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Simulation window: 3 full years covering chip shortage, COVID tail, and recovery
START_DATE = date(2022, 1, 1)
END_DATE = date(2024, 12, 31)
DATE_RANGE = pd.date_range(START_DATE, END_DATE, freq="D")

# OEM companies operating U.S. plants in this simulation
OEM_COMPANIES = ["Ford", "GM", "Toyota", "Tesla", "Rivian", "BMW"]

# U.S. automotive corridor states (real manufacturing footprint)
AUTOMOTIVE_STATES = {
    "Michigan":       ("Midwest",   [("Detroit", 42.3314, -83.0458), ("Lansing", 42.7325, -84.5555), ("Dearborn", 42.3223, -83.1763)]),
    "Ohio":           ("Midwest",   [("Toledo", 41.6639, -83.5552), ("Marysville", 40.2367, -83.3671), ("Lordstown", 41.1759, -80.8687)]),
    "Tennessee":      ("Southeast", [("Spring Hill", 35.7512, -86.9300), ("Smyrna", 35.9829, -86.5186), ("Chattanooga", 35.0456, -85.3097)]),
    "Kentucky":       ("Southeast", [("Georgetown", 38.2098, -84.5588), ("Louisville", 38.2527, -85.7585)]),
    "Alabama":        ("Southeast", [("Lincoln", 33.5743, -86.1183), ("Vance", 33.1615, -87.5397), ("Huntsville", 34.7304, -86.5861)]),
    "South Carolina": ("Southeast", [("Spartanburg", 34.9496, -81.9321), ("Greer", 34.9387, -82.2271)]),
    "Georgia":        ("Southeast", [("Atlanta", 33.7490, -84.3880), ("Savannah", 32.0835, -81.0998)]),
    "Texas":          ("Southwest", [("Austin", 30.2672, -97.7431), ("San Antonio", 29.4241, -98.4936), ("Fort Worth", 32.7555, -97.3308)]),
    "California":     ("West",      [("Fremont", 37.5485, -121.9886), ("Los Angeles", 34.0522, -118.2437)]),
    "Indiana":        ("Midwest",   [("Normal", 40.5142, -88.9906), ("Lafayette", 40.4167, -86.8753)]),
    "Missouri":       ("Midwest",   [("Wentzville", 38.8114, -90.8529)]),
    "Kansas":         ("Midwest",   [("Fairfax", 39.1122, -94.6275)]),
    "New Jersey":     ("Northeast", [("Trenton", 40.2171, -74.7429)]),
    "New York":       ("Northeast", [("Buffalo", 42.8864, -78.8784)]),
    "North Carolina": ("Southeast", [("Charlotte", 35.2271, -80.8431)]),
}


# ---------------------------------------------------------------------------
# HELPER UTILITIES
# ---------------------------------------------------------------------------

def random_date_between(start: date, end: date) -> date:
    """Return a random calendar date in [start, end]."""
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def covid_disruption_multiplier(d: date) -> float:
    """
    Returns a float multiplier representing supply chain stress severity on a
    given date.  WHY: 2022 was heavily impacted by:
      - COVID-era parts shortfalls carrying over from 2021
      - The semiconductor / chip shortage (peak mid-2022)
      - Ukraine conflict disrupting wire harness supply (Feb–Jun 2022)
    The multiplier feeds into delay_days, defect rates, and stockout scores.
    """
    if isinstance(d, (pd.Timestamp, datetime)):
        d = d.date()
    year = d.year
    month = d.month
    # Worst disruption: Jan–Aug 2022 (chip shortage + COVID tail)
    if year == 2022 and month <= 8:
        return 2.5
    # Moderate disruption: Sep–Dec 2022 (gradual recovery)
    if year == 2022:
        return 1.8
    # Early 2023: supply improving but labour disputes
    if year == 2023 and month <= 6:
        return 1.3
    # Late 2023–2024: mostly normalised
    return 1.0


def seasonal_demand_multiplier(d: date) -> float:
    """
    WHY: U.S. vehicle sales follow a well-documented seasonal pattern.
      - Q4 (Oct–Dec): strongest — year-end incentive pushes, fleet renewals
      - Q1 (Jan–Mar): weakest — consumer caution post-holiday
      - Q2 / Q3: moderate with summer travel bump in July–Aug
    """
    if isinstance(d, (pd.Timestamp, datetime)):
        d = d.date()
    month = d.month
    pattern = {1: 0.75, 2: 0.78, 3: 0.85, 4: 0.90, 5: 0.95, 6: 0.98,
               7: 1.02, 8: 1.05, 9: 1.00, 10: 1.10, 11: 1.15, 12: 1.20}
    return pattern.get(month, 1.0)


# ---------------------------------------------------------------------------
# 1. SUPPLIERS
# ---------------------------------------------------------------------------

def generate_suppliers() -> pd.DataFrame:
    """
    Generate 50 Tier-1 and Tier-2 automotive suppliers.

    WHY: Suppliers are the foundation of any supply chain model.  Real OEMs
    source from a mix of global giants (Bosch, Denso) and regional specialists.
    Key metrics tracked per supplier:
      - lead_time_days: how long from PO to arrival at the plant/warehouse
      - defect_rate_pct: incoming quality — directly tied to risk score
      - reliability_score: composite score (0-100) used in procurement decisions
      - delivery_performance_pct: % of orders arriving on or before due date
      - supplier_risk_score: 1-10; drives simulation of delays and disruptions
    """

    # Real Tier-1 and Tier-2 automotive suppliers (with real primary components)
    supplier_catalog = [
        ("Bosch Automotive",         "Electronics/Sensors",    "Germany",    "Tier-1"),
        ("Denso Corporation",        "HVAC/Thermal Systems",   "Japan",      "Tier-1"),
        ("Magna International",      "Body & Chassis",         "Canada",     "Tier-1"),
        ("BorgWarner",               "Powertrain",             "USA",        "Tier-1"),
        ("Aptiv",                    "Electrical Systems",     "Ireland",    "Tier-1"),
        ("Lear Corporation",         "Seating",                "USA",        "Tier-1"),
        ("Delphi Technologies",      "Engine Management",      "UK",         "Tier-1"),
        ("Continental AG",           "Tires & Chassis",        "Germany",    "Tier-1"),
        ("ZF Friedrichshafen",       "Transmissions",          "Germany",    "Tier-1"),
        ("Valeo",                    "Lighting Systems",       "France",     "Tier-1"),
        ("Faurecia",                 "Interiors",              "France",     "Tier-1"),
        ("Autoliv",                  "Safety Systems",         "Sweden",     "Tier-1"),
        ("Tenneco",                  "Exhaust Systems",        "USA",        "Tier-1"),
        ("Sensata Technologies",     "Sensors",                "Netherlands","Tier-2"),
        ("Gentex Corporation",       "Mirrors & Vision",       "USA",        "Tier-2"),
        ("Modine Manufacturing",     "Thermal Management",     "USA",        "Tier-2"),
        ("Dorman Products",          "Replacement Parts",      "USA",        "Tier-2"),
        ("Superior Industries",      "Aluminum Wheels",        "USA",        "Tier-2"),
        ("Strattec Security",        "Locks & Keys",           "USA",        "Tier-2"),
        ("Shiloh Industries",        "Metal Stampings",        "USA",        "Tier-2"),
        ("Tower International",      "Metal Stampings",        "USA",        "Tier-1"),
        ("Martinrea International",  "Metal Stampings",        "Canada",     "Tier-1"),
        ("Plastic Omnium",           "Bumpers & Fuel Systems", "France",     "Tier-1"),
        ("Gestamp",                  "Body Components",        "Spain",      "Tier-1"),
        ("Nemak",                    "Aluminum Castings",      "Mexico",     "Tier-1"),
        ("Linamar",                  "Drivetrain",             "Canada",     "Tier-1"),
        ("Trelleborg",               "Sealing Solutions",      "Sweden",     "Tier-2"),
        ("Parker Hannifin",          "Fluid Systems",          "USA",        "Tier-2"),
        ("Eaton",                    "Power Management",       "Ireland",    "Tier-1"),
        ("Dana Incorporated",        "Axles & Drivetrains",    "USA",        "Tier-1"),
        ("American Axle",            "Driveline Components",   "USA",        "Tier-1"),
        ("Methode Electronics",      "Connectors",             "USA",        "Tier-2"),
        ("CTS Corporation",          "Electronic Components",  "USA",        "Tier-2"),
        ("Stoneridge",               "Electronic Systems",     "USA",        "Tier-2"),
        ("Dorman Products",          "Hardware & Fasteners",   "USA",        "Tier-2"),
        ("NN Inc",                   "Precision Components",   "USA",        "Tier-2"),
        ("Koyo Bearings",            "Bearings",               "Japan",      "Tier-2"),
        ("NSK Ltd",                  "Steering Systems",       "Japan",      "Tier-1"),
        ("JTEKT Corporation",        "Bearings & Driveshafts", "Japan",      "Tier-1"),
        ("Hyundai Mobis",            "Modules & Parts",        "South Korea","Tier-1"),
        ("Hanon Systems",            "Thermal Systems",        "South Korea","Tier-1"),
        ("SL Corporation",           "Lighting",               "South Korea","Tier-2"),
        ("Samvardhana Motherson",    "Wiring Harnesses",       "India",      "Tier-1"),
        ("Minda Industries",         "Switches & Sensors",     "India",      "Tier-2"),
        ("Flex-N-Gate",              "Bumpers & Lighting",     "USA",        "Tier-1"),
        ("Showa Denko",              "Aluminum Products",      "Japan",      "Tier-2"),
        ("Tokai Rika",               "Switches & Locks",       "Japan",      "Tier-2"),
        ("Aisin Seiki",              "Drivetrain",             "Japan",      "Tier-1"),
        ("Panasonic Automotive",     "Infotainment",           "Japan",      "Tier-1"),
        ("Visteon Corporation",      "Cockpit Electronics",    "USA",        "Tier-1"),
    ]

    # Supplier regions (where they ship FROM, not where they're headquartered)
    us_regions = ["Midwest", "Southeast", "Southwest", "Northeast", "West",
                  "International - Asia", "International - Europe", "International - Canada/Mexico"]

    rows = []
    for i, (name, component, country, s_type) in enumerate(supplier_catalog):
        supplier_id = f"SUP-{i+1:03d}"

        # Risk score: 1 (low risk) to 10 (high risk)
        # International suppliers and Tier-2 get slightly higher base risk
        base_risk = 3.0 if s_type == "Tier-1" else 5.0
        if country not in ("USA", "Canada"):
            base_risk += 1.5
        risk_score = round(min(10, max(1, np.random.normal(base_risk, 1.5))), 2)

        # Defect rate correlates positively with risk score
        # Industry benchmark: 0.5% (excellent) to 5% (poor)
        defect_rate = round(max(0.2, min(5.0, 0.4 * risk_score + np.random.normal(0, 0.3))), 2)

        # Reliability and delivery performance inversely correlate with risk
        reliability = round(max(50, min(100, 100 - 5 * risk_score + np.random.normal(0, 3))), 1)
        delivery_perf = round(max(70, min(99, 95 - 2.5 * risk_score + np.random.normal(0, 2))), 1)

        # Lead time: domestic suppliers ship faster
        if country == "USA":
            lead_time = random.randint(3, 14)
        elif country in ("Canada", "Mexico"):
            lead_time = random.randint(5, 21)
        else:
            lead_time = random.randint(14, 45)

        # Contract value: Tier-1 majors command larger contracts
        if s_type == "Tier-1":
            contract_value = round(np.random.uniform(5_000_000, 250_000_000), 2)
        else:
            contract_value = round(np.random.uniform(500_000, 50_000_000), 2)

        # Supplier region (from which they distribute to U.S. plants)
        if country == "USA":
            region = random.choice(["Midwest", "Southeast", "Southwest", "Northeast", "West"])
        elif country == "Canada":
            region = "International - Canada/Mexico"
        elif country in ("Japan", "South Korea", "India"):
            region = "International - Asia"
        else:
            region = "International - Europe"

        cert_options = ["ISO 9001", "IATF 16949", "ISO 14001", "AS9100", "IATF 16949 + ISO 14001"]
        # Higher-risk suppliers less likely to hold premium certifications
        if risk_score > 7:
            cert = random.choice(["ISO 9001", "Uncertified"])
        else:
            cert = random.choice(cert_options)

        rows.append({
            "supplier_id":                supplier_id,
            "supplier_name":              name,
            "supplier_region":            region,
            "supplier_country":           country,
            "supplier_type":              s_type,
            "lead_time_days":             lead_time,
            "defect_rate_pct":            defect_rate,
            "reliability_score":          reliability,
            "delivery_performance_pct":   delivery_perf,
            "supplier_risk_score":        risk_score,
            "annual_contract_value_usd":  contract_value,
            "primary_component":          component,
            "years_in_contract":          random.randint(1, 20),
            "certification_status":       cert,
            "contact_email":              fake.company_email(),
        })

    df = pd.DataFrame(rows)
    return df


# ---------------------------------------------------------------------------
# 2. WAREHOUSES
# ---------------------------------------------------------------------------

def generate_warehouses() -> pd.DataFrame:
    """
    Generate 20 regional distribution centers and parts warehouses.

    WHY: Automotive OEMs use a hub-and-spoke warehouse network to buffer
    supplier lead times from plant Just-In-Time (JIT) requirements.
    Large distribution centers (DC) serve multiple plants; cross-docks are
    lean facilities for high-velocity parts.  Utilization 60-95% reflects
    real-world working range — below 60% is wasteful overhead, above 95%
    risks stockouts and receiving dock congestion.
    """

    warehouse_catalog = [
        ("Ford Detroit DC",             "Michigan",       "Detroit",       "Midwest",    "Distribution Center"),
        ("GM Midwest Parts Hub",        "Ohio",           "Toledo",        "Midwest",    "Distribution Center"),
        ("Toyota Southeast DC",         "Tennessee",      "Smyrna",        "Southeast",  "Distribution Center"),
        ("Tesla Gigafactory Warehouse", "Texas",          "Austin",        "Southwest",  "Manufacturing Support"),
        ("BMW Spartanburg Parts Hub",   "South Carolina", "Spartanburg",   "Southeast",  "Distribution Center"),
        ("Ford Kentucky Cross-Dock",    "Kentucky",       "Louisville",    "Southeast",  "Cross-Dock"),
        ("GM Alabama Buffer Store",     "Alabama",        "Lincoln",       "Southeast",  "Buffer Storage"),
        ("Rivian Normal IL Warehouse",  "Indiana",        "Normal",        "Midwest",    "Manufacturing Support"),
        ("Toyota Georgetown DC",        "Kentucky",       "Georgetown",    "Southeast",  "Distribution Center"),
        ("Ford Texas Regional DC",      "Texas",          "Fort Worth",    "Southwest",  "Distribution Center"),
        ("Tesla Fremont Parts Hub",     "California",     "Fremont",       "West",       "Manufacturing Support"),
        ("GM Wentzville Cross-Dock",    "Missouri",       "Wentzville",    "Midwest",    "Cross-Dock"),
        ("BMW Southeast Buffer",        "Georgia",        "Atlanta",       "Southeast",  "Buffer Storage"),
        ("Ford Southeast DC",           "Tennessee",      "Chattanooga",   "Southeast",  "Distribution Center"),
        ("Toyota Texas DC",             "Texas",          "San Antonio",   "Southwest",  "Distribution Center"),
        ("GM Northeast Regional",       "New York",       "Buffalo",       "Northeast",  "Distribution Center"),
        ("Ford Michigan Hub",           "Michigan",       "Lansing",       "Midwest",    "Distribution Center"),
        ("Rivian Georgia Parts Hub",    "Georgia",        "Savannah",      "Southeast",  "Buffer Storage"),
        ("GM Ohio Cross-Dock",          "Ohio",           "Marysville",    "Midwest",    "Cross-Dock"),
        ("BMW North Carolina DC",       "North Carolina", "Charlotte",     "Southeast",  "Distribution Center"),
    ]

    manager_first = ["James", "Maria", "Robert", "Linda", "David", "Susan", "Michael", "Karen",
                     "William", "Patricia", "Richard", "Jennifer", "Joseph", "Lisa", "Thomas",
                     "Nancy", "Charles", "Margaret", "Daniel", "Betty"]
    manager_last  = ["Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson",
                     "Martinez", "Anderson", "Taylor", "Thomas", "Hernandez", "Moore", "Martin",
                     "Jackson", "Thompson", "White", "Lopez", "Lee"]

    # Approximate lat/lon for each warehouse city (same order as catalog)
    coords = [
        (42.3314, -83.0458), (41.6639, -83.5552), (35.9829, -86.5186),
        (30.2672, -97.7431), (34.9496, -81.9321), (38.2527, -85.7585),
        (33.5743, -86.1183), (40.5142, -88.9906), (38.2098, -84.5588),
        (32.7555, -97.3308), (37.5485, -121.9886),(38.8114, -90.8529),
        (33.7490, -84.3880), (35.0456, -85.3097), (29.4241, -98.4936),
        (42.8864, -78.8784), (42.7325, -84.5555), (32.0835, -81.0998),
        (40.2367, -83.3671), (35.2271, -80.8431),
    ]

    rows = []
    for i, ((name, state, city, region, wtype), (lat, lon)) in enumerate(zip(warehouse_catalog, coords)):
        warehouse_id = f"WH-{i+1:02d}"

        # Capacity varies by warehouse type
        if wtype == "Distribution Center":
            capacity = random.randint(50_000, 200_000)
            op_cost  = round(np.random.uniform(150_000, 500_000), 2)
        elif wtype == "Manufacturing Support":
            capacity = random.randint(20_000, 80_000)
            op_cost  = round(np.random.uniform(80_000, 250_000), 2)
        elif wtype == "Cross-Dock":
            capacity = random.randint(10_000, 40_000)
            op_cost  = round(np.random.uniform(50_000, 150_000), 2)
        else:  # Buffer Storage
            capacity = random.randint(30_000, 100_000)
            op_cost  = round(np.random.uniform(60_000, 200_000), 2)

        # Utilization: 60-95% with small random variation per warehouse
        utilization = round(np.random.uniform(60, 95), 1)

        manager = f"{random.choice(manager_first)} {random.choice(manager_last)}"

        rows.append({
            "warehouse_id":                warehouse_id,
            "warehouse_name":              name,
            "region":                      region,
            "state":                       state,
            "city":                        city,
            "storage_capacity_units":      capacity,
            "current_utilization_pct":     utilization,
            "warehouse_type":              wtype,
            "manager_name":                manager,
            "operating_cost_monthly_usd":  op_cost,
            "latitude":                    lat,
            "longitude":                   lon,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 3. PLANTS
# ---------------------------------------------------------------------------

def generate_plants() -> pd.DataFrame:
    """
    Generate 15 U.S. automotive manufacturing plants.

    WHY: Plant data is the anchor for production records.  Each plant is
    tied to one OEM, operates in a known state/city, and has a realistic
    daily capacity.  Daily capacity ranges from ~500 units (specialty/EV)
    to ~2,000 units (full-size truck/SUV plants).  Workforce size scales
    proportionally.  Year established drives aging-infrastructure context
    (older plants have higher downtime rates in production data).
    """

    plant_catalog = [
        ("Ford Dearborn Truck Plant",     "Michigan",       "Dearborn",      "Ford",    "Truck Assembly"),
        ("Ford Kansas City Assembly",     "Missouri",       "Wentzville",    "Ford",    "Full Assembly"),  # actually Claycomo but Wentzville nearby
        ("Ford Kentucky Truck Plant",     "Kentucky",       "Louisville",    "Ford",    "Truck Assembly"),
        ("GM Lordstown Complex",          "Ohio",           "Lordstown",     "GM",      "Full Assembly"),
        ("GM Wentzville Assembly",        "Missouri",       "Wentzville",    "GM",      "Truck Assembly"),
        ("GM Fairfax Assembly",           "Kansas",         "Fairfax",       "GM",      "Full Assembly"),
        ("Toyota Georgetown Plant",       "Kentucky",       "Georgetown",    "Toyota",  "Full Assembly"),
        ("Toyota San Antonio Plant",      "Texas",          "San Antonio",   "Toyota",  "Truck Assembly"),
        ("Toyota Spring Hill Plant",      "Tennessee",      "Spring Hill",   "Toyota",  "Full Assembly"),
        ("Tesla Gigafactory Texas",       "Texas",          "Austin",        "Tesla",   "EV Assembly"),
        ("Tesla Fremont Factory",         "California",     "Fremont",       "Tesla",   "EV Assembly"),
        ("Rivian Normal Plant",           "Indiana",        "Normal",        "Rivian",  "EV Assembly"),
        ("BMW Spartanburg Plant",         "South Carolina", "Spartanburg",   "BMW",     "Full Assembly"),
        ("GM Spring Hill Assembly",       "Tennessee",      "Spring Hill",   "GM",      "Full Assembly"),
        ("Ford Chicago Assembly",         "Indiana",        "Lafayette",     "Ford",    "Full Assembly"),
    ]

    # Lat/lon for each plant (same order)
    coords = [
        (42.3223, -83.1763), (38.8114, -90.8529), (38.2527, -85.7585),
        (41.1759, -80.8687), (38.8114, -90.8529), (39.1122, -94.6275),
        (38.2098, -84.5588), (29.4241, -98.4936), (35.7512, -86.9300),
        (30.2672, -97.7431), (37.5485, -121.9886),(40.5142, -88.9906),
        (34.9496, -81.9321), (35.7512, -86.9300), (40.4167, -86.8753),
    ]

    rows = []
    for i, ((name, state, city, oem, ptype), (lat, lon)) in enumerate(zip(plant_catalog, coords)):
        plant_id = f"PLT-{i+1:02d}"

        # EV plants have lower daily capacity (new, ramping up)
        if ptype == "EV Assembly":
            capacity = random.randint(300, 800)
            workforce = random.randint(3_000, 8_000)
            yr_est    = random.randint(2017, 2022)
        elif ptype == "Truck Assembly":
            capacity = random.randint(1_000, 2_000)
            workforce = random.randint(5_000, 12_000)
            yr_est    = random.randint(1965, 2005)
        else:
            capacity = random.randint(800, 1_500)
            workforce = random.randint(4_000, 10_000)
            yr_est    = random.randint(1955, 2010)

        rows.append({
            "plant_id":                   plant_id,
            "plant_name":                 name,
            "state":                      state,
            "city":                       city,
            "oem_company":                oem,
            "plant_type":                 ptype,
            "total_capacity_units_daily": capacity,
            "workforce_size":             workforce,
            "year_established":           yr_est,
            "latitude":                   lat,
            "longitude":                  lon,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 4. PRODUCTS
# ---------------------------------------------------------------------------

def generate_products() -> pd.DataFrame:
    """
    Generate 30 automotive components and sub-assemblies.

    WHY: Products represent the specific parts flowing through the supply chain.
    Critical components (engine, battery pack, semiconductor modules) have
    tighter tolerances on supply; non-critical items have more buffer.
    Vehicle compatibility is key for demand planning — some parts are
    universal (fasteners, hoses) while others are model-specific.
    """

    product_catalog = [
        ("Engine Block V6",            "Powertrain",        2_800.00,  True,  ["F-150", "Silverado", "Tundra"],        85.0),
        ("Engine Block V8",            "Powertrain",        3_400.00,  True,  ["F-150", "Silverado", "Sierra"],        110.0),
        ("Electric Motor (Rear)",      "EV Powertrain",     4_200.00,  True,  ["Model 3", "Model Y", "Lightning"],     95.0),
        ("Battery Pack 75kWh",         "EV Powertrain",    12_500.00,  True,  ["Model 3", "Lightning", "R1T"],        600.0),
        ("Battery Pack 100kWh",        "EV Powertrain",    18_000.00,  True,  ["Model S", "Cybertruck", "R1S"],       900.0),
        ("Transmission (6-Speed Auto)","Powertrain",        1_800.00,  True,  ["F-150", "Silverado", "Camry"],         95.0),
        ("Semiconductor Control Module","Electronics",        450.00,  True,  ["All Models"],                           1.2),
        ("Infotainment System",        "Electronics",         380.00, False,  ["All Models"],                           4.5),
        ("ADAS Sensor Suite",          "Safety/Electronics",  620.00,  True,  ["Model Y", "F-150", "RAV4"],             3.8),
        ("Airbag Module (Front)",      "Safety",              125.00,  True,  ["All Models"],                           2.1),
        ("Airbag Module (Side)",       "Safety",               95.00,  True,  ["All Models"],                           1.4),
        ("Seat Assembly (Front Pair)", "Interiors",           780.00, False,  ["All Models"],                          45.0),
        ("Dashboard Assembly",         "Interiors",           420.00, False,  ["All Models"],                          18.0),
        ("Wiring Harness (Main)",      "Electrical",          340.00,  True,  ["All Models"],                          12.0),
        ("Brake Caliper Set",          "Braking",              85.00, False,  ["All Models"],                           8.5),
        ("Brake Rotor Set",            "Braking",              72.00, False,  ["All Models"],                          14.0),
        ("Suspension Strut Set",       "Chassis",             210.00, False,  ["All Models"],                          22.0),
        ("Aluminum Wheel Set (4)",     "Chassis",             480.00, False,  ["All Models"],                          60.0),
        ("Exhaust System",             "Powertrain",          320.00, False,  ["ICE Models"],                          18.0),
        ("Turbocharger",               "Powertrain",          650.00,  True,  ["F-150 EcoBoost", "Silverado"],         12.0),
        ("Catalytic Converter",        "Emissions",           280.00,  True,  ["ICE Models"],                           4.2),
        ("Fuel Injector Set",          "Powertrain",          195.00, False,  ["ICE Models"],                           1.8),
        ("Power Steering Pump",        "Chassis",             165.00, False,  ["All Models"],                           6.5),
        ("Alternator",                 "Electrical",          145.00, False,  ["ICE Models"],                           9.0),
        ("Radiator Assembly",          "Thermal",             185.00, False,  ["All Models"],                          12.0),
        ("AC Compressor",              "Thermal",             220.00, False,  ["All Models"],                           8.0),
        ("Door Panel Set",             "Body",                390.00, False,  ["All Models"],                          35.0),
        ("Bumper Assembly (Front)",    "Body",                240.00, False,  ["All Models"],                          18.0),
        ("Headlight Assembly (Pair)",  "Lighting",            195.00, False,  ["All Models"],                           5.5),
        ("Fastener Kit (1000-piece)",  "Hardware",             45.00, False,  ["All Models"],                           4.0),
    ]

    rows = []
    for i, (name, category, cost, critical, vehicles, weight) in enumerate(product_catalog):
        product_id = f"PRD-{i+1:03d}"
        rows.append({
            "product_id":            product_id,
            "product_name":          name,
            "product_category":      category,
            "unit_cost_usd":         cost,
            "vehicle_compatibility": ", ".join(vehicles),
            "weight_lbs":            weight,
            "is_critical_component": critical,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 5. SHIPMENTS  (50,000+ rows)
# ---------------------------------------------------------------------------

def generate_shipments(suppliers_df: pd.DataFrame,
                        warehouses_df: pd.DataFrame,
                        plants_df: pd.DataFrame,
                        products_df: pd.DataFrame,
                        target_rows: int = 52_000) -> pd.DataFrame:
    """
    Generate 50,000+ shipment records covering 2022–2024.

    WHY: Shipments are the core transactional table.  Each row represents
    one inbound shipment from a supplier to either a warehouse (standard)
    or directly to a plant (JIT).  Key business logic:
      - Delay days: influenced by covid_disruption_multiplier, supplier risk,
        and transportation mode (air is fastest, rail is slowest but cheapest)
      - Fuel cost: spikes in 2022 when diesel averaged $5+/gallon
      - Shipment status: 'delivered', 'in_transit', 'delayed', 'cancelled'
      - Chip shortage: semiconductor component shipments are preferentially
        delayed in 2022 to reflect the real-world Tier-2/3 supplier crisis
    """

    supplier_ids  = suppliers_df["supplier_id"].tolist()
    warehouse_ids = warehouses_df["warehouse_id"].tolist()
    plant_ids     = plants_df["plant_id"].tolist()
    product_ids   = products_df["product_id"].tolist()

    # Build product metadata lookup for business logic
    prod_lookup = products_df.set_index("product_id")[["unit_cost_usd", "weight_lbs",
                                                        "product_category", "is_critical_component"]].to_dict("index")
    sup_lookup  = suppliers_df.set_index("supplier_id")[["supplier_risk_score",
                                                          "lead_time_days", "delivery_performance_pct"]].to_dict("index")

    carriers = ["J.B. Hunt", "Werner Enterprises", "Knight-Swift", "XPO Logistics",
                "Schneider National", "Old Dominion Freight", "FedEx Freight",
                "UPS Supply Chain", "BNSF Railway", "Union Pacific Rail",
                "Delta Cargo", "American Airlines Cargo", "Maersk", "Coyote Logistics"]

    transport_modes = ["Truck", "Rail", "Air", "Intermodal", "LTL"]
    # Weights for mode selection: trucks dominate in North American auto supply chains
    mode_weights    = [0.55, 0.15, 0.08, 0.12, 0.10]

    delay_reasons = [
        "Supplier production delay", "Weather event", "Carrier capacity shortage",
        "Port congestion", "Customs clearance", "Chip shortage",
        "Labour strike", "Equipment failure", "Natural disaster",
        "COVID-related disruption", "Demand surge", "No delay"
    ]

    # Generate all shipment dates uniformly across 2022-2024
    all_dates = pd.date_range(START_DATE, END_DATE, freq="D")
    # np.random.choice on a DatetimeIndex returns numpy.datetime64 objects;
    # convert to pandas Timestamps so .date() works downstream
    shipment_dates = pd.DatetimeIndex(np.random.choice(all_dates, size=target_rows, replace=True)).sort_values()

    rows = []
    for idx, ship_date in enumerate(shipment_dates):
        shipment_id  = f"SHP-{idx+1:06d}"
        supplier_id  = random.choice(supplier_ids)
        product_id   = random.choice(product_ids)

        # ~70% go to a warehouse first; ~30% are direct-to-plant JIT shipments
        if random.random() < 0.70:
            warehouse_id = random.choice(warehouse_ids)
            plant_id     = random.choice(plant_ids)
        else:
            warehouse_id = random.choice(warehouse_ids)
            plant_id     = random.choice(plant_ids)

        sup_data  = sup_lookup[supplier_id]
        prod_data = prod_lookup[product_id]

        # Lead time from supplier record, jittered ±20%
        lead_time = max(1, int(sup_data["lead_time_days"] * np.random.uniform(0.8, 1.2)))

        transport_mode = random.choices(transport_modes, weights=mode_weights)[0]
        # Air shipments are faster (emergency/critical parts only)
        if transport_mode == "Air":
            lead_time = max(1, lead_time // 3)
        elif transport_mode == "Rail":
            lead_time = int(lead_time * 1.3)

        expected_delivery = ship_date + timedelta(days=lead_time)

        # --- DELAY LOGIC ---
        disruption_mult = covid_disruption_multiplier(ship_date.date())
        risk_score      = sup_data["supplier_risk_score"]
        delivery_perf   = sup_data["delivery_performance_pct"] / 100.0

        # Chip shortage: semiconductor parts delayed 2x more often in 2022
        is_chip = prod_data["product_category"] in ("Electronics", "Safety/Electronics")
        if is_chip and ship_date.year == 2022:
            disruption_mult *= 1.8

        # Probability of a delay: baseline 15%, scaled by risk and disruption
        delay_prob = min(0.85, 0.15 * disruption_mult * (risk_score / 5.0))
        # Counter-balanced by supplier's delivery performance rating
        delay_prob *= (1 - delivery_perf * 0.5)

        if random.random() < delay_prob:
            # Delay magnitude: 1–21 days, heavier tail in 2022
            delay_days   = int(np.random.exponential(3.0 * disruption_mult))
            delay_days   = max(1, min(delay_days, 30))
            delay_reason = random.choice([r for r in delay_reasons if r != "No delay"])
        else:
            delay_days   = 0
            delay_reason = "No delay"

        actual_delivery = expected_delivery + timedelta(days=delay_days)

        # Shipment status
        if ship_date.date() > (END_DATE - timedelta(days=14)):
            status = "In Transit"
        elif delay_days > 0:
            status = random.choices(["Delayed", "Delivered"], weights=[0.6, 0.4])[0]
        else:
            status = "Delivered"

        # Quantity and cost
        quantity = random.randint(10, 1_000)
        unit_cost = prod_data["unit_cost_usd"] * np.random.uniform(0.95, 1.05)

        # Distance estimation (domestic vs international)
        distance = random.randint(50, 3_000)

        weight_lbs = prod_data["weight_lbs"] * quantity

        # Transportation cost: mode-dependent, distance-sensitive
        if transport_mode == "Air":
            transport_cost = round(distance * 3.50 + weight_lbs * 0.15, 2)
        elif transport_mode == "Rail":
            transport_cost = round(distance * 0.08 + weight_lbs * 0.005, 2)
        elif transport_mode == "LTL":
            transport_cost = round(distance * 0.25 + weight_lbs * 0.02, 2)
        else:  # Truck / Intermodal
            transport_cost = round(distance * 0.18 + weight_lbs * 0.01, 2)

        # Fuel cost: diesel $/gallon was ~$5.20 in mid-2022, ~$3.80 in 2024
        # Approximate fuel component as % of transport cost
        if ship_date.year == 2022:
            fuel_pct = np.random.uniform(0.28, 0.38)
        elif ship_date.year == 2023:
            fuel_pct = np.random.uniform(0.22, 0.30)
        else:
            fuel_pct = np.random.uniform(0.18, 0.26)

        fuel_cost = round(transport_cost * fuel_pct, 2)

        # Route name (simplified)
        route_name = f"{supplier_id}-WH{warehouse_ids.index(warehouse_id)+1:02d}"

        carrier = random.choice(carriers)

        rows.append({
            "shipment_id":           shipment_id,
            "supplier_id":           supplier_id,
            "warehouse_id":          warehouse_id,
            "plant_id":              plant_id,
            "product_id":            product_id,
            "shipment_date":         ship_date.date(),
            "expected_delivery_date": expected_delivery.date(),
            "actual_delivery_date":  actual_delivery.date(),
            "delay_days":            delay_days,
            "quantity_shipped":      quantity,
            "unit_cost_usd":         round(unit_cost, 2),
            "transportation_cost_usd": transport_cost,
            "fuel_cost_usd":         fuel_cost,
            "shipment_status":       status,
            "transportation_mode":   transport_mode,
            "carrier_name":          carrier,
            "route_name":            route_name,
            "distance_miles":        distance,
            "shipment_weight_lbs":   round(weight_lbs, 1),
            "delay_reason":          delay_reason,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 6. INVENTORY  (30,000+ rows — daily snapshots per warehouse × product)
# ---------------------------------------------------------------------------

def generate_inventory(warehouses_df: pd.DataFrame,
                        products_df: pd.DataFrame,
                        target_rows: int = 31_000) -> pd.DataFrame:
    """
    Generate daily inventory snapshots across warehouses and products.

    WHY: Inventory snapshots capture the state of stock at each warehouse at
    end-of-day.  This is the primary source for:
      - Stockout risk detection (when days_of_supply < 7)
      - ABC analysis (A=high value, B=medium, C=low value parts)
      - Reorder point and safety stock compliance monitoring
    Data covers 2022-2024; stockout_risk_score spikes in 2022 due to
    chip shortage reducing inbound replenishment frequency.
    """

    warehouse_ids = warehouses_df["warehouse_id"].tolist()
    product_ids   = products_df["product_id"].tolist()
    prod_lookup   = products_df.set_index("product_id")[["unit_cost_usd", "is_critical_component"]].to_dict("index")
    wh_lookup     = warehouses_df.set_index("warehouse_id")["storage_capacity_units"].to_dict()

    # Sample dates: one row per (warehouse, product, snapshot_date)
    # We tile to get target_rows without over-indexing
    rows_needed = target_rows

    # Build a representative set of (warehouse, product) pairs
    pairs = [(w, p) for w in warehouse_ids for p in product_ids[:15]]  # 20 WH × 15 PRD = 300 pairs
    # Each pair gets ~100 date snapshots (300 × 103 ≈ 30,900)
    dates_per_pair = max(1, rows_needed // len(pairs))

    # Sample snapshot dates (not every day — roughly every 3 days)
    snapshot_dates = pd.date_range(START_DATE, END_DATE, freq="3D").tolist()
    if len(snapshot_dates) > dates_per_pair:
        snapshot_dates = snapshot_dates[:dates_per_pair]

    rows = []
    inv_id = 1
    for wh_id in warehouse_ids:
        wh_capacity = wh_lookup[wh_id]
        for prod_id in product_ids[:15]:  # Use first 15 products per warehouse
            prod_data   = prod_lookup[prod_id]
            unit_cost   = prod_data["unit_cost_usd"]
            is_critical = prod_data["is_critical_component"]

            # Safety stock: critical components carry higher buffer
            safety_stock  = random.randint(500, 2_000) if is_critical else random.randint(100, 500)
            reorder_level = safety_stock + random.randint(200, 800)

            prev_stock = random.randint(reorder_level, reorder_level + 5_000)

            for snap_date in snapshot_dates:
                disruption = covid_disruption_multiplier(snap_date.date())

                # Stock evolves: daily consumption minus replenishment
                daily_consumption = random.randint(50, 400)
                # Replenishment less frequent during disruptions
                replenishment = 0
                if random.random() < (0.3 / disruption):
                    replenishment = random.randint(500, 3_000)

                stock = max(0, int(prev_stock - daily_consumption + replenishment))
                # Cap at a fraction of warehouse capacity
                stock = min(stock, wh_capacity // 10)
                prev_stock = stock

                # ABC category: based on unit_cost
                if unit_cost > 1_000:
                    abc = "A"
                elif unit_cost > 200:
                    abc = "B"
                else:
                    abc = "C"

                inv_value = round(stock * unit_cost, 2)

                # Days of supply: how many days before stockout at current burn rate
                dos = round(stock / max(daily_consumption, 1), 1)

                # Stockout risk: 0-1 score; spikes when dos < safety threshold
                # Amplified during 2022 chip shortage for electronics
                base_stockout = max(0, 1 - (dos / 30))
                stockout_risk = round(min(1.0, base_stockout * disruption * 0.7), 3)

                last_replen_date = snap_date.date() - timedelta(days=random.randint(1, 14))

                rows.append({
                    "inventory_id":           f"INV-{inv_id:07d}",
                    "warehouse_id":           wh_id,
                    "product_id":             prod_id,
                    "snapshot_date":          snap_date.date(),
                    "stock_quantity":         stock,
                    "reorder_level":          reorder_level,
                    "safety_stock_level":     safety_stock,
                    "inventory_value_usd":    inv_value,
                    "stockout_risk_score":    stockout_risk,
                    "days_of_supply":         dos,
                    "last_replenishment_date": last_replen_date,
                    "abc_category":           abc,
                })
                inv_id += 1

                if inv_id > rows_needed + 1:
                    break
            if inv_id > rows_needed + 1:
                break
        if inv_id > rows_needed + 1:
            break

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 7. SALES & DEMAND  (30,000+ rows)
# ---------------------------------------------------------------------------

def generate_sales_demand(target_rows: int = 32_000) -> pd.DataFrame:
    """
    Generate vehicle order and delivery records covering 2022–2024.

    WHY: Sales/demand data links the downstream consumer market back to the
    supply chain.  Each row represents a batch of vehicle sales (not individual
    cars — OEM reporting is aggregated by region/channel/period).

    Key business logic:
      - Seasonal multiplier: Q4 strongest (incentive season), Q1 weakest
      - EV demand grows year-over-year (2022→2024) per actual market trends
      - Forecast accuracy degrades during 2022 disruptions
      - Revenue = units_sold × unit_price (with regional pricing variation)
      - Sales channels: Dealer (dominant), Fleet, Direct (Tesla model),
        Online, Corporate
    """

    vehicle_catalog = [
        # (vehicle_type,        vehicle_category, oem,     base_price,  ev)
        ("F-150",               "Pickup Truck",   "Ford",    42_000, False),
        ("Ford Explorer",       "SUV",            "Ford",    38_000, False),
        ("Ford Bronco",         "SUV",            "Ford",    35_000, False),
        ("Ford Mustang",        "Sports Car",     "Ford",    32_000, False),
        ("Ford Lightning",      "EV Pickup",      "Ford",    55_000, True),
        ("Ford Escape Hybrid",  "Hybrid SUV",     "Ford",    30_000, False),
        ("Chevy Silverado",     "Pickup Truck",   "GM",      40_000, False),
        ("Chevy Equinox",       "SUV",            "GM",      30_000, False),
        ("Chevy Bolt EV",       "EV Sedan",       "GM",      27_000, True),
        ("GMC Sierra",          "Pickup Truck",   "GM",      45_000, False),
        ("Cadillac Lyriq",      "EV SUV",         "GM",      62_000, True),
        ("Buick Enclave",       "SUV",            "GM",      44_000, False),
        ("Camry",               "Sedan",          "Toyota",  26_000, False),
        ("Tacoma",              "Pickup Truck",   "Toyota",  31_000, False),
        ("RAV4",                "SUV",            "Toyota",  29_000, False),
        ("Highlander",          "SUV",            "Toyota",  36_000, False),
        ("Tundra",              "Pickup Truck",   "Toyota",  38_000, False),
        ("RAV4 Prime",          "Hybrid SUV",     "Toyota",  43_000, False),
        ("Model 3",             "EV Sedan",       "Tesla",   42_000, True),
        ("Model Y",             "EV SUV",         "Tesla",   47_000, True),
        ("Model S",             "EV Sedan",       "Tesla",   89_000, True),
        ("Model X",             "EV SUV",         "Tesla",   98_000, True),
        ("Cybertruck",          "EV Pickup",      "Tesla",   67_000, True),
        ("Rivian R1T",          "EV Pickup",      "Rivian",  70_000, True),
        ("Rivian R1S",          "EV SUV",         "Rivian",  78_000, True),
        ("BMW X3",              "SUV",            "BMW",     47_000, False),
        ("BMW X5",              "SUV",            "BMW",     65_000, False),
        ("BMW iX",              "EV SUV",         "BMW",     87_000, True),
        ("BMW i4",              "EV Sedan",       "BMW",     56_000, True),
        ("BMW 3 Series",        "Sedan",          "BMW",     45_000, False),
    ]

    us_regions_states = {
        "Midwest":    ["Michigan", "Ohio", "Indiana", "Illinois", "Missouri", "Kansas"],
        "Southeast":  ["Tennessee", "Kentucky", "Alabama", "Georgia", "South Carolina", "North Carolina", "Florida"],
        "Southwest":  ["Texas", "Arizona", "New Mexico", "Oklahoma"],
        "Northeast":  ["New York", "New Jersey", "Pennsylvania", "Massachusetts", "Connecticut"],
        "West":       ["California", "Washington", "Colorado", "Nevada", "Oregon"],
    }

    channels  = ["Dealer Network", "Fleet Sales", "Direct Online", "Corporate Account", "Rental Fleet"]
    segments  = ["Individual Consumer", "Small Business", "Enterprise Fleet", "Government", "Rental Agency"]

    rows = []
    order_date_pool = pd.date_range(START_DATE, END_DATE, freq="D")

    for idx in range(target_rows):
        sale_id    = f"SL-{idx+1:07d}"
        veh        = random.choice(vehicle_catalog)
        v_type, v_cat, oem, base_price, is_ev = veh

        order_date = random.choice(order_date_pool)
        season_mult = seasonal_demand_multiplier(order_date.date())

        # EV demand trend: growing each year (market share increasing)
        if is_ev:
            ev_trend = {2022: 0.8, 2023: 1.0, 2024: 1.3}.get(order_date.year, 1.0)
        else:
            ev_trend = 1.0

        # Units sold per record (this is a batch/dealer-level report)
        base_units = int(np.random.exponential(12) * season_mult * ev_trend)
        units_sold = max(1, min(base_units, 500))

        # Regional pricing: West Coast and Northeast command slight premium
        region = random.choice(list(us_regions_states.keys()))
        state  = random.choice(us_regions_states[region])
        regional_premium = {"West": 1.04, "Northeast": 1.03, "Midwest": 1.0,
                            "Southeast": 0.99, "Southwest": 1.01}.get(region, 1.0)

        unit_price = round(base_price * regional_premium * np.random.uniform(0.97, 1.08), 0)
        revenue    = round(units_sold * unit_price, 2)

        # Delivery date: 2–90 days after order depending on channel and availability
        if oem == "Tesla":
            # Direct online: variable wait list
            delivery_lag = random.randint(14, 90)
        elif is_ev:
            delivery_lag = random.randint(30, 120)
        else:
            delivery_lag = random.randint(2, 45)

        delivery_date = order_date + timedelta(days=delivery_lag)
        if delivery_date > pd.Timestamp(END_DATE):
            delivery_date = pd.Timestamp(END_DATE)

        # Forecasted demand vs actuals
        # Forecast accuracy degrades significantly in 2022 (COVID disruptions)
        if order_date.year == 2022:
            accuracy = round(np.random.uniform(0.55, 0.85), 3)
        elif order_date.year == 2023:
            accuracy = round(np.random.uniform(0.70, 0.92), 3)
        else:
            accuracy = round(np.random.uniform(0.80, 0.96), 3)

        forecasted = round(units_sold / accuracy)

        channel = random.choice(channels)
        # Tesla uses Direct Online predominantly
        if oem == "Tesla":
            channel = random.choices(["Direct Online", "Dealer Network"],
                                     weights=[0.75, 0.25])[0]

        segment = random.choice(segments)
        if channel == "Fleet Sales":
            segment = "Enterprise Fleet"
        elif channel == "Rental Fleet":
            segment = "Rental Agency"
        elif channel == "Corporate Account":
            segment = "Small Business"

        rows.append({
            "sale_id":               sale_id,
            "vehicle_type":          v_type,
            "vehicle_category":      v_cat,
            "oem_company":           oem,
            "region":                region,
            "state":                 state,
            "order_date":            order_date.date(),
            "delivery_date":         delivery_date.date(),
            "units_sold":            units_sold,
            "unit_price_usd":        unit_price,
            "revenue_usd":           revenue,
            "forecasted_demand":     forecasted,
            "forecast_accuracy_pct": round(accuracy * 100, 1),
            "sales_channel":         channel,
            "customer_segment":      segment,
        })

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 8. PRODUCTION  (20,000+ rows)
# ---------------------------------------------------------------------------

def generate_production(plants_df: pd.DataFrame,
                         target_rows: int = 21_000) -> pd.DataFrame:
    """
    Generate daily production line records per plant, per shift.

    WHY: Production records capture the manufacturing output side of the
    supply chain.  A deficit between planned and actual production signals
    either a supply issue (parts shortage) or an operational issue (downtime,
    quality problem).  Key patterns simulated:
      - 2022 chip shortage: plants run at 60-75% of capacity because
        semiconductor modules aren't available (halts entire assembly lines)
      - 3 shifts per day per plant (Day, Afternoon, Night)
      - Downtime reasons: planned maintenance, chip shortage, strike,
        equipment failure, weather
      - Defect units: correlate with line efficiency; older plants have
        slightly higher defect rates
      - Energy consumption: roughly proportional to actual output
    """

    plant_ids   = plants_df["plant_id"].tolist()
    plant_lookup = plants_df.set_index("plant_id")[["total_capacity_units_daily",
                                                     "oem_company", "plant_type",
                                                     "year_established"]].to_dict("index")

    shifts         = ["Day", "Afternoon", "Night"]
    downtime_reasons = [
        "Planned Maintenance", "Equipment Failure", "Chip/Parts Shortage",
        "Supplier Delay", "Quality Hold", "Labour Strike",
        "Weather Delay", "Tool Change", "Safety Inspection", "No Downtime"
    ]

    vehicle_by_plant = {
        "PLT-01": "F-150",
        "PLT-02": "F-150",
        "PLT-03": "Ford Explorer",
        "PLT-04": "Chevy Silverado",
        "PLT-05": "Chevy Silverado",
        "PLT-06": "Chevy Equinox",
        "PLT-07": "Camry",
        "PLT-08": "Tundra",
        "PLT-09": "RAV4",
        "PLT-10": "Model Y",
        "PLT-11": "Model 3",
        "PLT-12": "Rivian R1T",
        "PLT-13": "BMW X5",
        "PLT-14": "GMC Sierra",
        "PLT-15": "Ford Mustang",
    }

    # Calculate rows per plant-shift combination
    rows_per_plant = max(1, target_rows // (len(plant_ids) * len(shifts)))
    prod_date_pool = pd.date_range(START_DATE, END_DATE, freq="D").tolist()

    rows = []
    prod_id = 1

    for plant_id in plant_ids:
        p_data       = plant_lookup[plant_id]
        daily_cap    = p_data["total_capacity_units_daily"]
        shift_cap    = daily_cap // 3  # Divide daily capacity across 3 shifts
        plant_type   = p_data["plant_type"]
        yr_est       = p_data["year_established"]
        # Older plants: slightly higher base downtime
        age_factor   = max(0, (2024 - yr_est) / 60)  # 0 (new) to ~1 (60-yr-old plant)

        v_type = vehicle_by_plant.get(plant_id, "Mixed")

        for shift in shifts:
            # Sample production dates for this plant-shift
            sample_dates = random.choices(prod_date_pool, k=rows_per_plant)
            sample_dates.sort()

            for prod_date in sample_dates:
                disruption = covid_disruption_multiplier(prod_date.date())

                # EV plants ramping up: lower utilization early on
                is_ev = plant_type == "EV Assembly"
                if is_ev and prod_date.year == 2022:
                    capacity_mult = np.random.uniform(0.35, 0.65)
                elif is_ev and prod_date.year == 2023:
                    capacity_mult = np.random.uniform(0.55, 0.80)
                elif is_ev:
                    capacity_mult = np.random.uniform(0.70, 0.95)
                else:
                    # ICE / hybrid plants: chip shortage reduces output in 2022
                    base_util = 0.85 / disruption
                    capacity_mult = max(0.30, np.random.uniform(base_util - 0.15,
                                                                base_util + 0.10))

                planned    = max(10, int(shift_cap))
                actual     = max(0, int(planned * capacity_mult))

                # Downtime: more frequent in 2022, older plants, EV ramp
                downtime_prob = 0.25 * disruption + 0.1 * age_factor
                if random.random() < min(0.80, downtime_prob):
                    downtime_hrs = round(np.random.exponential(1.5 * disruption), 1)
                    downtime_hrs = min(downtime_hrs, 8.0)
                    if disruption > 1.5 or (is_ev and prod_date.year <= 2023):
                        d_reason = random.choices(
                            downtime_reasons,
                            weights=[5, 10, 30, 15, 10, 5, 5, 5, 5, 10])[0]
                    else:
                        d_reason = random.choices(
                            downtime_reasons,
                            weights=[20, 15, 5, 5, 10, 3, 8, 15, 9, 10])[0]
                else:
                    downtime_hrs = 0.0
                    d_reason     = "No Downtime"

                # Defect units: correlate with efficiency and disruption
                line_eff    = round(max(30, min(100, 100 - 8 * age_factor
                                                   - 5 * (disruption - 1)
                                                   + np.random.normal(0, 3))), 1)
                defect_rate = max(0.003, min(0.08, 0.01 * disruption
                                               + 0.005 * age_factor
                                               + np.random.normal(0, 0.005)))
                defect_units = max(0, int(actual * defect_rate))

                util_rate = round((actual / max(planned, 1)) * 100, 1)

                # Energy consumption: ~50 kWh per unit produced + base plant load
                energy_kwh = round(actual * 50 + planned * 5 + np.random.normal(0, 200), 0)
                energy_kwh = max(0, energy_kwh)

                rows.append({
                    "production_id":             f"PROD-{prod_id:07d}",
                    "plant_id":                  plant_id,
                    "production_date":           prod_date.date(),
                    "shift":                     shift,
                    "vehicle_type":              v_type,
                    "planned_production_units":  planned,
                    "actual_production_units":   actual,
                    "defect_units":              defect_units,
                    "downtime_hours":            downtime_hrs,
                    "downtime_reason":           d_reason,
                    "utilization_rate_pct":      util_rate,
                    "line_efficiency_pct":       line_eff,
                    "energy_consumption_kwh":    energy_kwh,
                })
                prod_id += 1

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# MAIN ENTRY POINT
# ---------------------------------------------------------------------------

def main():
    """
    Orchestrates the generation of all eight supply chain datasets.
    Prints row counts and file sizes as a sanity check.
    """
    print("=" * 60)
    print("  U.S. Automotive Supply Chain Dataset Generator")
    print("  Simulating 2022-2024 | OEMs: Ford, GM, Toyota, Tesla,")
    print("  Rivian, BMW")
    print("=" * 60)
    print()

    # ---- DIMENSION TABLES (small, generated first) ----

    print("[1/8] Generating suppliers...")
    suppliers_df = generate_suppliers()
    out = os.path.join(OUTPUT_DIR, "suppliers.csv")
    suppliers_df.to_csv(out, index=False)
    print(f"      {len(suppliers_df):,} rows -> {out}")

    print("[2/8] Generating warehouses...")
    warehouses_df = generate_warehouses()
    out = os.path.join(OUTPUT_DIR, "warehouses.csv")
    warehouses_df.to_csv(out, index=False)
    print(f"      {len(warehouses_df):,} rows -> {out}")

    print("[3/8] Generating plants...")
    plants_df = generate_plants()
    out = os.path.join(OUTPUT_DIR, "plants.csv")
    plants_df.to_csv(out, index=False)
    print(f"      {len(plants_df):,} rows -> {out}")

    print("[4/8] Generating products...")
    products_df = generate_products()
    out = os.path.join(OUTPUT_DIR, "products.csv")
    products_df.to_csv(out, index=False)
    print(f"      {len(products_df):,} rows -> {out}")

    # ---- FACT / TRANSACTION TABLES (large) ----

    print("[5/8] Generating shipments (52,000 rows)...")
    shipments_df = generate_shipments(suppliers_df, warehouses_df, plants_df, products_df,
                                      target_rows=52_000)
    out = os.path.join(OUTPUT_DIR, "shipments.csv")
    shipments_df.to_csv(out, index=False)
    print(f"      {len(shipments_df):,} rows -> {out}")

    print("[6/8] Generating inventory snapshots (31,000 rows)...")
    inventory_df = generate_inventory(warehouses_df, products_df, target_rows=31_000)
    out = os.path.join(OUTPUT_DIR, "inventory.csv")
    inventory_df.to_csv(out, index=False)
    print(f"      {len(inventory_df):,} rows -> {out}")

    print("[7/8] Generating sales & demand (32,000 rows)...")
    sales_df = generate_sales_demand(target_rows=32_000)
    out = os.path.join(OUTPUT_DIR, "sales_demand.csv")
    sales_df.to_csv(out, index=False)
    print(f"      {len(sales_df):,} rows -> {out}")

    print("[8/8] Generating production records (21,000 rows)...")
    production_df = generate_production(plants_df, target_rows=21_000)
    out = os.path.join(OUTPUT_DIR, "production.csv")
    production_df.to_csv(out, index=False)
    print(f"      {len(production_df):,} rows -> {out}")

    # ---- SUMMARY ----
    print()
    print("=" * 60)
    print("  GENERATION COMPLETE — ROW COUNT SUMMARY")
    print("=" * 60)

    totals = {
        "suppliers.csv":     len(suppliers_df),
        "warehouses.csv":    len(warehouses_df),
        "plants.csv":        len(plants_df),
        "products.csv":      len(products_df),
        "shipments.csv":     len(shipments_df),
        "inventory.csv":     len(inventory_df),
        "sales_demand.csv":  len(sales_df),
        "production.csv":    len(production_df),
    }

    grand_total = 0
    for fname, count in totals.items():
        fpath = os.path.join(OUTPUT_DIR, fname)
        size_mb = os.path.getsize(fpath) / (1024 * 1024)
        print(f"  {fname:<25} {count:>8,} rows   {size_mb:>6.2f} MB")
        grand_total += count

    print("-" * 60)
    print(f"  {'TOTAL':25} {grand_total:>8,} rows")
    print("=" * 60)
    print()
    print(f"  All CSV files saved to: {OUTPUT_DIR}")
    print()

    # Validate key row count thresholds
    assert len(shipments_df)  >= 50_000, "Shipments < 50K rows!"
    assert len(inventory_df)  >= 30_000, "Inventory < 30K rows!"
    assert len(sales_df)      >= 30_000, "Sales demand < 30K rows!"
    assert len(production_df) >= 20_000, "Production < 20K rows!"
    print("  All row-count assertions passed.")
    print()


if __name__ == "__main__":
    main()
