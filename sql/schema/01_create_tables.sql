-- =============================================================================
-- FILE: 01_create_tables.sql
-- PROJECT: Automotive Supply Chain Analytics
-- PURPOSE: Full DDL for star schema dimensional model
--
-- SCHEMA OVERVIEW:
--   This star schema supports analytics across the full automotive supply
--   chain lifecycle: procurement, inventory, logistics, manufacturing, and sales.
--
--   DIMENSION TABLES (prefix: dim_)
--     dim_supplier   - Supplier master data and risk attributes
--     dim_warehouse  - Storage facility details and capacity
--     dim_plant      - Manufacturing plant attributes
--     dim_product    - Part/component catalog
--     dim_date       - Date dimension with fiscal and calendar attributes
--     dim_region     - Geographic hierarchy (country -> region -> zone)
--     dim_vehicle    - Vehicle model and segment data
--
--   FACT TABLES (prefix: fact_)
--     fact_shipments   - Inbound/outbound logistics events
--     fact_inventory   - Daily inventory snapshot per warehouse/product
--     fact_sales       - Vehicle and parts sales transactions
--     fact_production  - Manufacturing run metrics
--
-- COMPATIBILITY: SQL Server and PostgreSQL
--   Differences are noted inline with -- [SQL Server] and -- [PostgreSQL] comments
--   For PostgreSQL: replace NVARCHAR -> VARCHAR, BIT -> BOOLEAN,
--                   GETDATE() -> CURRENT_TIMESTAMP, IDENTITY -> SERIAL/GENERATED
-- =============================================================================


-- =============================================================================
-- DIMENSION TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dim_supplier
-- PURPOSE: Stores master data for all Tier-1, Tier-2, and Tier-3 suppliers.
--          Used to analyze supplier performance, risk, and geographic concentration.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_supplier (
    supplier_key        INT             NOT NULL,   -- Surrogate key (warehouse key)
    supplier_id         NVARCHAR(20)    NOT NULL,   -- Natural/business key (e.g., 'SUP-00123')
    supplier_name       NVARCHAR(200)   NOT NULL,   -- Legal entity name
    supplier_short_name NVARCHAR(50)    NULL,       -- Commonly used abbreviation
    tier_level          TINYINT         NOT NULL,   -- 1=direct, 2=sub-supplier, 3=raw material
    supplier_type       NVARCHAR(50)    NOT NULL,   -- e.g., 'Machining', 'Electronics', 'Rubber'
    country             NVARCHAR(100)   NOT NULL,
    region              NVARCHAR(100)   NOT NULL,   -- Geographic region (e.g., 'North America')
    city                NVARCHAR(100)   NULL,
    postal_code         NVARCHAR(20)    NULL,
    contact_name        NVARCHAR(150)   NULL,
    contact_email       NVARCHAR(200)   NULL,
    contract_start_date DATE            NULL,       -- Current contract start
    contract_end_date   DATE            NULL,       -- Current contract expiry
    payment_terms_days  SMALLINT        NULL,       -- Net payment days (e.g., 30, 60, 90)
    currency_code       CHAR(3)         NOT NULL DEFAULT 'USD',
    risk_rating         NVARCHAR(10)    NOT NULL DEFAULT 'Medium',  -- Low / Medium / High / Critical
    is_preferred        BIT             NOT NULL DEFAULT 0,         -- Preferred vendor flag
    is_active           BIT             NOT NULL DEFAULT 1,
    certification_iso   BIT             NOT NULL DEFAULT 0,         -- ISO 9001 certified
    certification_iatf  BIT             NOT NULL DEFAULT 0,         -- IATF 16949 certified
    annual_spend_usd    DECIMAL(18,2)   NULL,       -- Last full-year spend
    created_at          DATETIME        NOT NULL DEFAULT GETDATE(),  -- [PostgreSQL: CURRENT_TIMESTAMP]
    updated_at          DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_dim_supplier PRIMARY KEY (supplier_key)
);

CREATE UNIQUE INDEX UX_dim_supplier_id ON dim_supplier (supplier_id);
CREATE INDEX IX_dim_supplier_country  ON dim_supplier (country);
CREATE INDEX IX_dim_supplier_tier     ON dim_supplier (tier_level);
CREATE INDEX IX_dim_supplier_risk     ON dim_supplier (risk_rating);

COMMENT ON TABLE dim_supplier IS 'Supplier master dimension - supports performance, risk, and spend analysis';


-- -----------------------------------------------------------------------------
-- dim_warehouse
-- PURPOSE: Physical and virtual storage locations. Supports inventory
--          optimization, stockout risk analysis, and network design.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_warehouse (
    warehouse_key       INT             NOT NULL,
    warehouse_id        NVARCHAR(20)    NOT NULL,   -- Business key (e.g., 'WH-DET-01')
    warehouse_name      NVARCHAR(200)   NOT NULL,
    warehouse_type      NVARCHAR(50)    NOT NULL,   -- 'Distribution', 'Buffer', 'Finished Goods', 'Raw Material'
    country             NVARCHAR(100)   NOT NULL,
    region              NVARCHAR(100)   NOT NULL,
    city                NVARCHAR(100)   NOT NULL,
    address_line1       NVARCHAR(255)   NULL,
    postal_code         NVARCHAR(20)    NULL,
    latitude            DECIMAL(9,6)    NULL,       -- GPS coordinates for mapping
    longitude           DECIMAL(9,6)    NULL,
    total_capacity_sqft DECIMAL(12,2)   NULL,       -- Total floor space
    usable_capacity_sqft DECIMAL(12,2)  NULL,       -- Usable after aisles/structure
    max_pallet_positions INT            NULL,       -- Racking capacity in pallet positions
    refrigerated        BIT             NOT NULL DEFAULT 0,
    hazmat_certified    BIT             NOT NULL DEFAULT 0,
    owned_or_leased     NVARCHAR(10)    NOT NULL DEFAULT 'Owned',   -- 'Owned' / 'Leased' / '3PL'
    3pl_provider        NVARCHAR(100)   NULL,       -- Third-party logistics provider name
    operating_cost_monthly DECIMAL(14,2) NULL,      -- Monthly operating cost in USD
    manager_name        NVARCHAR(150)   NULL,
    is_active           BIT             NOT NULL DEFAULT 1,
    created_at          DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_dim_warehouse PRIMARY KEY (warehouse_key)
);

CREATE UNIQUE INDEX UX_dim_warehouse_id ON dim_warehouse (warehouse_id);
CREATE INDEX IX_dim_warehouse_region   ON dim_warehouse (region);
CREATE INDEX IX_dim_warehouse_type     ON dim_warehouse (warehouse_type);

COMMENT ON TABLE dim_warehouse IS 'Warehouse/storage location dimension for inventory and logistics analysis';


-- -----------------------------------------------------------------------------
-- dim_plant
-- PURPOSE: Manufacturing plant master data. Supports production efficiency,
--          downtime, OEE analysis, and capacity planning.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_plant (
    plant_key           INT             NOT NULL,
    plant_id            NVARCHAR(20)    NOT NULL,   -- Business key (e.g., 'PLT-MI-01')
    plant_name          NVARCHAR(200)   NOT NULL,
    plant_type          NVARCHAR(50)    NOT NULL,   -- 'Assembly', 'Stamping', 'Powertrain', 'Paint'
    country             NVARCHAR(100)   NOT NULL,
    region              NVARCHAR(100)   NOT NULL,
    city                NVARCHAR(100)   NOT NULL,
    address_line1       NVARCHAR(255)   NULL,
    latitude            DECIMAL(9,6)    NULL,
    longitude           DECIMAL(9,6)    NULL,
    annual_capacity_units INT           NOT NULL,   -- Vehicles or parts per year at rated capacity
    num_shifts          TINYINT         NOT NULL DEFAULT 2,   -- Shifts per day (1/2/3)
    num_production_lines SMALLINT       NOT NULL DEFAULT 1,
    workforce_size      INT             NULL,       -- Total headcount
    union_plant         BIT             NOT NULL DEFAULT 0,
    commissioning_date  DATE            NULL,       -- When plant became operational
    last_audit_date     DATE            NULL,
    is_active           BIT             NOT NULL DEFAULT 1,
    created_at          DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_dim_plant PRIMARY KEY (plant_key)
);

CREATE UNIQUE INDEX UX_dim_plant_id ON dim_plant (plant_id);
CREATE INDEX IX_dim_plant_type       ON dim_plant (plant_type);
CREATE INDEX IX_dim_plant_region     ON dim_plant (region, country);

COMMENT ON TABLE dim_plant IS 'Manufacturing plant dimension for production and OEE analysis';


-- -----------------------------------------------------------------------------
-- dim_product
-- PURPOSE: Part and component catalog. Links raw materials, sub-assemblies,
--          and finished components for BOM-level cost and quality analysis.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_product (
    product_key         INT             NOT NULL,
    product_id          NVARCHAR(30)    NOT NULL,   -- Part number / SKU
    product_name        NVARCHAR(300)   NOT NULL,
    product_description NVARCHAR(1000)  NULL,
    product_category    NVARCHAR(100)   NOT NULL,   -- e.g., 'Engine', 'Chassis', 'Electrical'
    product_subcategory NVARCHAR(100)   NULL,       -- e.g., 'Cylinder Block', 'Wiring Harness'
    product_type        NVARCHAR(50)    NOT NULL,   -- 'Raw Material', 'Sub-Assembly', 'Finished Part'
    unit_of_measure     NVARCHAR(20)    NOT NULL DEFAULT 'EA',  -- EA, KG, LTR, MTR
    standard_cost_usd   DECIMAL(14,4)   NULL,       -- Standard cost per UOM
    list_price_usd      DECIMAL(14,4)   NULL,       -- List / transfer price
    weight_kg           DECIMAL(10,4)   NULL,
    dimensions_cm       NVARCHAR(50)    NULL,       -- 'LxWxH' string
    hazardous_material  BIT             NOT NULL DEFAULT 0,
    perishable          BIT             NOT NULL DEFAULT 0,
    lead_time_days      SMALLINT        NULL,       -- Typical supplier lead time
    safety_stock_qty    INT             NULL,       -- Minimum stock level
    reorder_point_qty   INT             NULL,       -- Stock level triggering reorder
    economic_order_qty  INT             NULL,       -- EOQ in units
    shelf_life_days     SMALLINT        NULL,       -- NULL = no expiry
    primary_supplier_key INT            NULL,       -- FK to dim_supplier (preferred supplier)
    is_active           BIT             NOT NULL DEFAULT 1,
    created_at          DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_dim_product PRIMARY KEY (product_key),
    CONSTRAINT FK_dim_product_supplier FOREIGN KEY (primary_supplier_key)
        REFERENCES dim_supplier (supplier_key)
);

CREATE UNIQUE INDEX UX_dim_product_id    ON dim_product (product_id);
CREATE INDEX IX_dim_product_category     ON dim_product (product_category, product_subcategory);
CREATE INDEX IX_dim_product_type         ON dim_product (product_type);

COMMENT ON TABLE dim_product IS 'Product/part catalog dimension for cost, quality, and inventory analysis';


-- -----------------------------------------------------------------------------
-- dim_date
-- PURPOSE: Calendar date dimension supporting both Gregorian and fiscal year
--          analysis. Populated once for 2020-2030 via 02_populate_date_dim.sql.
--          Fiscal year assumed to start in October (adjust as needed).
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key            INT             NOT NULL,   -- YYYYMMDD integer (e.g., 20240315)
    full_date           DATE            NOT NULL,
    day_of_week         TINYINT         NOT NULL,   -- 1=Sunday ... 7=Saturday
    day_name            NVARCHAR(10)    NOT NULL,   -- 'Monday', 'Tuesday', etc.
    day_name_short      CHAR(3)         NOT NULL,   -- 'Mon', 'Tue', etc.
    day_of_month        TINYINT         NOT NULL,   -- 1-31
    day_of_quarter      SMALLINT        NOT NULL,   -- 1-92
    day_of_year         SMALLINT        NOT NULL,   -- 1-366
    week_of_year        TINYINT         NOT NULL,   -- ISO week 1-53
    week_of_month       TINYINT         NOT NULL,   -- 1-5
    month_number        TINYINT         NOT NULL,   -- 1-12
    month_name          NVARCHAR(10)    NOT NULL,   -- 'January', 'February', etc.
    month_name_short    CHAR(3)         NOT NULL,   -- 'Jan', 'Feb', etc.
    month_start_date    DATE            NOT NULL,   -- First day of the month
    month_end_date      DATE            NOT NULL,   -- Last day of the month
    quarter_number      TINYINT         NOT NULL,   -- 1-4
    quarter_name        CHAR(2)         NOT NULL,   -- 'Q1', 'Q2', 'Q3', 'Q4'
    quarter_start_date  DATE            NOT NULL,
    quarter_end_date    DATE            NOT NULL,
    year_number         SMALLINT        NOT NULL,   -- 4-digit year
    year_month          CHAR(7)         NOT NULL,   -- 'YYYY-MM' for grouping
    year_quarter        CHAR(7)         NOT NULL,   -- 'YYYY-Q#' for grouping
    is_weekend          BIT             NOT NULL,   -- 1 if Saturday or Sunday
    is_weekday          BIT             NOT NULL,   -- 1 if Monday-Friday
    is_holiday          BIT             NOT NULL DEFAULT 0,  -- US holidays (update as needed)
    holiday_name        NVARCHAR(100)   NULL,       -- Name of holiday if is_holiday=1
    is_business_day     BIT             NOT NULL,   -- is_weekday AND NOT is_holiday
    -- Fiscal year attributes (fiscal year starts October 1)
    fiscal_year         SMALLINT        NOT NULL,   -- e.g., FY2025 starts Oct 2024
    fiscal_quarter      TINYINT         NOT NULL,   -- 1-4 within fiscal year
    fiscal_month        TINYINT         NOT NULL,   -- 1-12 within fiscal year
    fiscal_year_quarter CHAR(8)         NOT NULL,   -- 'FY2025Q1'
    -- Rolling window helpers
    is_current_day      BIT             NOT NULL DEFAULT 0,
    is_current_week     BIT             NOT NULL DEFAULT 0,
    is_current_month    BIT             NOT NULL DEFAULT 0,
    is_current_quarter  BIT             NOT NULL DEFAULT 0,
    is_current_year     BIT             NOT NULL DEFAULT 0,
    is_prior_year       BIT             NOT NULL DEFAULT 0,

    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);

CREATE UNIQUE INDEX UX_dim_date_full_date ON dim_date (full_date);
CREATE INDEX IX_dim_date_year_month       ON dim_date (year_number, month_number);
CREATE INDEX IX_dim_date_fiscal           ON dim_date (fiscal_year, fiscal_quarter);
CREATE INDEX IX_dim_date_is_weekend       ON dim_date (is_weekend);
CREATE INDEX IX_dim_date_year_quarter     ON dim_date (year_quarter);

COMMENT ON TABLE dim_date IS 'Date dimension with calendar and fiscal year attributes for time-series analysis';


-- -----------------------------------------------------------------------------
-- dim_region
-- PURPOSE: Geographic hierarchy for market and logistics analysis.
--          Supports drill-down from continent -> country -> zone -> city.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_region (
    region_key          INT             NOT NULL,
    region_id           NVARCHAR(20)    NOT NULL,   -- Business key (e.g., 'REG-NA-GREAT-LAKES')
    continent           NVARCHAR(50)    NOT NULL,   -- 'North America', 'Europe', 'Asia Pacific'
    country             NVARCHAR(100)   NOT NULL,
    country_code        CHAR(2)         NOT NULL,   -- ISO 3166-1 alpha-2 (e.g., 'US', 'DE')
    region_name         NVARCHAR(100)   NOT NULL,   -- Business region (e.g., 'Midwest', 'Southeast')
    sub_region          NVARCHAR(100)   NULL,       -- Optional finer geography
    major_city          NVARCHAR(100)   NULL,       -- Largest city / hub in region
    time_zone           NVARCHAR(50)    NULL,       -- IANA time zone string
    currency_code       CHAR(3)         NOT NULL DEFAULT 'USD',
    is_high_tariff_zone BIT             NOT NULL DEFAULT 0,  -- Flags cross-border complexity
    is_active           BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_dim_region PRIMARY KEY (region_key)
);

CREATE UNIQUE INDEX UX_dim_region_id   ON dim_region (region_id);
CREATE INDEX IX_dim_region_country     ON dim_region (country_code);
CREATE INDEX IX_dim_region_continent   ON dim_region (continent);

COMMENT ON TABLE dim_region IS 'Geographic region dimension for market, logistics, and risk segmentation';


-- -----------------------------------------------------------------------------
-- dim_vehicle
-- PURPOSE: Vehicle model master data. Links production and sales facts to
--          support segment-level revenue, demand, and production analysis.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_vehicle (
    vehicle_key         INT             NOT NULL,
    vehicle_id          NVARCHAR(30)    NOT NULL,   -- Model code / program code
    vehicle_name        NVARCHAR(200)   NOT NULL,   -- Full marketing name
    brand               NVARCHAR(100)   NOT NULL,   -- Brand / marque (e.g., 'Ford', 'Chevrolet')
    model_family        NVARCHAR(100)   NULL,       -- Platform family (e.g., 'F-Series', 'Silverado')
    vehicle_segment     NVARCHAR(50)    NOT NULL,   -- 'Truck', 'SUV', 'Sedan', 'EV', 'Van'
    body_style          NVARCHAR(50)    NULL,       -- 'Pickup', 'Crossover', 'Hatchback'
    drivetrain          NVARCHAR(20)    NULL,       -- 'FWD', 'RWD', 'AWD', '4WD'
    powertrain_type     NVARCHAR(30)    NOT NULL,   -- 'ICE', 'Hybrid', 'PHEV', 'BEV', 'FCEV'
    engine_displacement_l DECIMAL(4,1)  NULL,       -- Engine size in litres (NULL for BEV)
    battery_capacity_kwh DECIMAL(6,1)   NULL,       -- Battery size in kWh (NULL for ICE)
    msrp_base_usd       DECIMAL(10,2)   NULL,       -- Base MSRP in USD
    production_start_year SMALLINT      NOT NULL,   -- Model year production began
    production_end_year SMALLINT        NULL,       -- NULL = still in production
    assembly_plant_key  INT             NULL,       -- FK to dim_plant (primary assembly plant)
    is_current_model_year BIT           NOT NULL DEFAULT 1,
    is_active           BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_dim_vehicle PRIMARY KEY (vehicle_key),
    CONSTRAINT FK_dim_vehicle_plant FOREIGN KEY (assembly_plant_key)
        REFERENCES dim_plant (plant_key)
);

CREATE UNIQUE INDEX UX_dim_vehicle_id      ON dim_vehicle (vehicle_id);
CREATE INDEX IX_dim_vehicle_segment        ON dim_vehicle (vehicle_segment);
CREATE INDEX IX_dim_vehicle_powertrain     ON dim_vehicle (powertrain_type);
CREATE INDEX IX_dim_vehicle_brand          ON dim_vehicle (brand);

COMMENT ON TABLE dim_vehicle IS 'Vehicle model dimension for sales, production, and demand analysis';


-- =============================================================================
-- FACT TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact_shipments
-- PURPOSE: Records each inbound or outbound shipment event at the line level.
--          Supports on-time delivery, transportation cost, delay, and carrier
--          performance analysis. Grain: one row per shipment line item.
-- -----------------------------------------------------------------------------
CREATE TABLE fact_shipments (
    shipment_id             BIGINT          NOT NULL,   -- Surrogate / ETL-assigned row ID
    shipment_number         NVARCHAR(30)    NOT NULL,   -- Source system shipment number
    shipment_line           SMALLINT        NOT NULL DEFAULT 1,  -- Line within shipment

    -- Dimension foreign keys
    supplier_key            INT             NOT NULL,
    origin_warehouse_key    INT             NULL,       -- NULL for supplier-direct shipments
    dest_warehouse_key      INT             NULL,       -- NULL for plant-direct delivery
    dest_plant_key          INT             NULL,       -- Destination plant
    product_key             INT             NOT NULL,
    ship_date_key           INT             NOT NULL,   -- FK to dim_date (actual ship date)
    scheduled_delivery_date_key INT         NOT NULL,   -- FK to dim_date (promised delivery)
    actual_delivery_date_key    INT         NULL,       -- FK to dim_date (actual delivery; NULL=in transit)
    origin_region_key       INT             NULL,       -- FK to dim_region
    dest_region_key         INT             NULL,       -- FK to dim_region

    -- Shipment attributes
    shipment_direction      NVARCHAR(10)    NOT NULL,   -- 'Inbound' / 'Outbound'
    transport_mode          NVARCHAR(20)    NOT NULL,   -- 'Road', 'Rail', 'Air', 'Sea', 'Intermodal'
    carrier_name            NVARCHAR(100)   NULL,
    carrier_scac            CHAR(4)         NULL,       -- Standard Carrier Alpha Code
    service_level           NVARCHAR(30)    NULL,       -- 'Standard', 'Expedited', 'LTL', 'FTL'
    incoterms               CHAR(3)         NULL,       -- 'EXW', 'FOB', 'CIF', 'DDP', etc.

    -- Quantity and weight
    quantity_ordered        DECIMAL(14,4)   NOT NULL,
    quantity_shipped        DECIMAL(14,4)   NOT NULL,
    quantity_received       DECIMAL(14,4)   NULL,       -- NULL until receipt confirmed
    unit_of_measure         NVARCHAR(20)    NOT NULL DEFAULT 'EA',
    gross_weight_kg         DECIMAL(12,4)   NULL,
    volume_m3               DECIMAL(10,4)   NULL,

    -- Cost
    freight_cost_usd        DECIMAL(14,2)   NULL,
    fuel_surcharge_usd      DECIMAL(12,2)   NULL,
    handling_cost_usd       DECIMAL(12,2)   NULL,
    customs_duty_usd        DECIMAL(12,2)   NULL,
    total_logistics_cost_usd DECIMAL(14,2)  NULL,       -- Sum of all cost components
    cost_per_unit_usd       DECIMAL(14,4)   NULL,       -- total_logistics_cost / quantity_shipped

    -- Time performance
    planned_transit_days    SMALLINT        NULL,
    actual_transit_days     SMALLINT        NULL,
    delay_days              SMALLINT        NULL,       -- Negative = early; 0 = on time; positive = late
    is_on_time              BIT             NULL,       -- 1 if delivered on or before scheduled date
    delay_reason_code       NVARCHAR(20)    NULL,       -- 'WX' weather, 'TRF' traffic, 'CUS' customs, etc.
    delay_reason_desc       NVARCHAR(200)   NULL,

    -- Quality at receipt
    quantity_rejected       DECIMAL(14,4)   NULL DEFAULT 0,
    rejection_reason        NVARCHAR(200)   NULL,
    defect_rate_pct         DECIMAL(7,4)    NULL,       -- quantity_rejected / quantity_received * 100

    -- Status
    shipment_status         NVARCHAR(20)    NOT NULL DEFAULT 'In Transit',  -- 'Created','In Transit','Delivered','Cancelled'
    po_number               NVARCHAR(30)    NULL,       -- Purchase order reference
    invoice_number          NVARCHAR(30)    NULL,

    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_fact_shipments PRIMARY KEY (shipment_id),
    CONSTRAINT FK_fship_supplier   FOREIGN KEY (supplier_key)         REFERENCES dim_supplier (supplier_key),
    CONSTRAINT FK_fship_orig_wh    FOREIGN KEY (origin_warehouse_key) REFERENCES dim_warehouse (warehouse_key),
    CONSTRAINT FK_fship_dest_wh    FOREIGN KEY (dest_warehouse_key)   REFERENCES dim_warehouse (warehouse_key),
    CONSTRAINT FK_fship_dest_plt   FOREIGN KEY (dest_plant_key)       REFERENCES dim_plant (plant_key),
    CONSTRAINT FK_fship_product    FOREIGN KEY (product_key)          REFERENCES dim_product (product_key),
    CONSTRAINT FK_fship_ship_dt    FOREIGN KEY (ship_date_key)        REFERENCES dim_date (date_key),
    CONSTRAINT FK_fship_sched_dt   FOREIGN KEY (scheduled_delivery_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT FK_fship_act_dt     FOREIGN KEY (actual_delivery_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT FK_fship_orig_rgn   FOREIGN KEY (origin_region_key)   REFERENCES dim_region (region_key),
    CONSTRAINT FK_fship_dest_rgn   FOREIGN KEY (dest_region_key)     REFERENCES dim_region (region_key)
);

-- Performance indexes aligned to common query patterns
CREATE INDEX IX_fship_supplier_date    ON fact_shipments (supplier_key, ship_date_key);
CREATE INDEX IX_fship_product_date     ON fact_shipments (product_key, ship_date_key);
CREATE INDEX IX_fship_dest_wh          ON fact_shipments (dest_warehouse_key);
CREATE INDEX IX_fship_dest_plant       ON fact_shipments (dest_plant_key);
CREATE INDEX IX_fship_on_time          ON fact_shipments (is_on_time, ship_date_key);
CREATE INDEX IX_fship_status           ON fact_shipments (shipment_status);
CREATE INDEX IX_fship_ship_date        ON fact_shipments (ship_date_key);
CREATE INDEX IX_fship_scheduled_date   ON fact_shipments (scheduled_delivery_date_key);

COMMENT ON TABLE fact_shipments IS 'Shipment fact table - grain: one row per shipment line item. Supports logistics KPI analysis.';


-- -----------------------------------------------------------------------------
-- fact_inventory
-- PURPOSE: Daily inventory snapshot per product per warehouse.
--          Enables stockout risk, turnover, ABC analysis, and aging.
--          Grain: one row per (product, warehouse, date).
-- -----------------------------------------------------------------------------
CREATE TABLE fact_inventory (
    inventory_id            BIGINT          NOT NULL,

    -- Dimension foreign keys
    product_key             INT             NOT NULL,
    warehouse_key           INT             NOT NULL,
    snapshot_date_key       INT             NOT NULL,   -- FK to dim_date (snapshot date)
    supplier_key            INT             NULL,       -- Supplier who produced this stock

    -- Quantity measures
    opening_stock_qty       DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Start of day quantity
    receipts_qty            DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Received during day
    issues_qty              DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Consumed/shipped during day
    adjustments_qty         DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Write-offs, corrections
    closing_stock_qty       DECIMAL(14,4)   NOT NULL,             -- End of day quantity
    reserved_qty            DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Allocated to open orders
    available_qty           DECIMAL(14,4)   NOT NULL,             -- closing - reserved
    in_transit_qty          DECIMAL(14,4)   NOT NULL DEFAULT 0,   -- Ordered but not received

    -- Thresholds (copied from dim_product at snapshot time for historical accuracy)
    safety_stock_qty        DECIMAL(14,4)   NOT NULL DEFAULT 0,
    reorder_point_qty       DECIMAL(14,4)   NOT NULL DEFAULT 0,
    max_stock_qty           DECIMAL(14,4)   NULL,                 -- Maximum storage capacity

    -- Value measures
    unit_cost_usd           DECIMAL(14,4)   NULL,
    total_stock_value_usd   DECIMAL(18,2)   NULL,   -- closing_stock_qty * unit_cost_usd

    -- Derived indicators (calculated during ETL for query performance)
    days_of_supply          DECIMAL(8,2)    NULL,   -- closing_stock / avg_daily_usage
    stockout_risk_flag      BIT             NOT NULL DEFAULT 0,   -- closing < safety_stock
    overstock_flag          BIT             NOT NULL DEFAULT 0,   -- closing > max_stock * 1.2
    days_since_last_receipt SMALLINT        NULL,

    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_fact_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT FK_finv_product    FOREIGN KEY (product_key)      REFERENCES dim_product (product_key),
    CONSTRAINT FK_finv_warehouse  FOREIGN KEY (warehouse_key)    REFERENCES dim_warehouse (warehouse_key),
    CONSTRAINT FK_finv_date       FOREIGN KEY (snapshot_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT FK_finv_supplier   FOREIGN KEY (supplier_key)     REFERENCES dim_supplier (supplier_key)
);

CREATE UNIQUE INDEX UX_finv_product_wh_date  ON fact_inventory (product_key, warehouse_key, snapshot_date_key);
CREATE INDEX IX_finv_warehouse_date          ON fact_inventory (warehouse_key, snapshot_date_key);
CREATE INDEX IX_finv_product_date            ON fact_inventory (product_key, snapshot_date_key);
CREATE INDEX IX_finv_stockout_flag           ON fact_inventory (stockout_risk_flag, snapshot_date_key);
CREATE INDEX IX_finv_overstock_flag          ON fact_inventory (overstock_flag, snapshot_date_key);

COMMENT ON TABLE fact_inventory IS 'Daily inventory snapshot fact table - grain: product x warehouse x date';


-- -----------------------------------------------------------------------------
-- fact_sales
-- PURPOSE: Records vehicle and parts sales at the transaction level.
--          Supports revenue, forecast accuracy, and demand analysis.
--          Grain: one row per sales order line.
-- -----------------------------------------------------------------------------
CREATE TABLE fact_sales (
    sales_id                BIGINT          NOT NULL,
    order_number            NVARCHAR(30)    NOT NULL,
    order_line              SMALLINT        NOT NULL DEFAULT 1,

    -- Dimension foreign keys
    vehicle_key             INT             NULL,       -- NULL for parts-only orders
    product_key             INT             NOT NULL,   -- Part / vehicle configuration code
    customer_region_key     INT             NOT NULL,   -- FK to dim_region
    ship_from_warehouse_key INT             NULL,       -- FK to dim_warehouse
    order_date_key          INT             NOT NULL,   -- FK to dim_date
    ship_date_key           INT             NULL,
    delivery_date_key       INT             NULL,

    -- Customer attributes (de-normalized for query convenience)
    customer_type           NVARCHAR(50)    NOT NULL,   -- 'Fleet', 'Dealer', 'Retail', 'Government'
    customer_name           NVARCHAR(200)   NULL,
    sales_channel           NVARCHAR(50)    NULL,       -- 'Online', 'Dealership', 'Direct'

    -- Quantity and pricing
    quantity_ordered        DECIMAL(14,4)   NOT NULL,
    quantity_fulfilled      DECIMAL(14,4)   NULL,
    unit_price_usd          DECIMAL(14,4)   NOT NULL,
    unit_cost_usd           DECIMAL(14,4)   NULL,
    discount_pct            DECIMAL(6,4)    NULL DEFAULT 0,
    discount_amount_usd     DECIMAL(14,2)   NULL DEFAULT 0,
    gross_revenue_usd       DECIMAL(18,2)   NOT NULL,   -- quantity_ordered * unit_price
    net_revenue_usd         DECIMAL(18,2)   NOT NULL,   -- gross - discounts
    cogs_usd                DECIMAL(18,2)   NULL,       -- Cost of goods sold
    gross_margin_usd        DECIMAL(18,2)   NULL,       -- net_revenue - cogs
    gross_margin_pct        DECIMAL(7,4)    NULL,

    -- Forecast vs actual (for demand accuracy analysis)
    forecasted_quantity     DECIMAL(14,4)   NULL,       -- Demand forecast for this period
    forecast_error          DECIMAL(14,4)   NULL,       -- actual - forecast
    forecast_accuracy_pct   DECIMAL(7,4)    NULL,       -- 1 - ABS(error)/forecast * 100

    -- Fulfillment
    is_fulfilled_on_time    BIT             NULL,
    fill_rate_pct           DECIMAL(7,4)    NULL,       -- quantity_fulfilled / quantity_ordered
    order_status            NVARCHAR(20)    NOT NULL DEFAULT 'Open',

    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_fact_sales PRIMARY KEY (sales_id),
    CONSTRAINT FK_fsales_vehicle   FOREIGN KEY (vehicle_key)             REFERENCES dim_vehicle (vehicle_key),
    CONSTRAINT FK_fsales_product   FOREIGN KEY (product_key)             REFERENCES dim_product (product_key),
    CONSTRAINT FK_fsales_region    FOREIGN KEY (customer_region_key)     REFERENCES dim_region (region_key),
    CONSTRAINT FK_fsales_warehouse FOREIGN KEY (ship_from_warehouse_key) REFERENCES dim_warehouse (warehouse_key),
    CONSTRAINT FK_fsales_ord_dt    FOREIGN KEY (order_date_key)          REFERENCES dim_date (date_key),
    CONSTRAINT FK_fsales_ship_dt   FOREIGN KEY (ship_date_key)           REFERENCES dim_date (date_key),
    CONSTRAINT FK_fsales_del_dt    FOREIGN KEY (delivery_date_key)       REFERENCES dim_date (date_key)
);

CREATE INDEX IX_fsales_vehicle_date    ON fact_sales (vehicle_key, order_date_key);
CREATE INDEX IX_fsales_region_date     ON fact_sales (customer_region_key, order_date_key);
CREATE INDEX IX_fsales_product_date    ON fact_sales (product_key, order_date_key);
CREATE INDEX IX_fsales_order_date      ON fact_sales (order_date_key);
CREATE INDEX IX_fsales_channel         ON fact_sales (sales_channel, order_date_key);

COMMENT ON TABLE fact_sales IS 'Sales fact table - grain: sales order line. Supports revenue, margin, and demand analysis.';


-- -----------------------------------------------------------------------------
-- fact_production
-- PURPOSE: Manufacturing run metrics per plant per production day.
--          Supports OEE, utilization, downtime, and defect rate analysis.
--          Grain: one row per production run (shift + line + product).
-- -----------------------------------------------------------------------------
CREATE TABLE fact_production (
    production_id           BIGINT          NOT NULL,
    production_run_number   NVARCHAR(30)    NULL,   -- Source system run ID

    -- Dimension foreign keys
    plant_key               INT             NOT NULL,
    product_key             INT             NOT NULL,   -- Product being produced
    vehicle_key             INT             NULL,       -- Vehicle model (if applicable)
    production_date_key     INT             NOT NULL,   -- FK to dim_date

    -- Production attributes
    shift_number            TINYINT         NOT NULL,   -- 1, 2, or 3
    production_line_id      NVARCHAR(20)    NULL,       -- Line identifier within plant
    work_order_number       NVARCHAR(30)    NULL,

    -- Time measures (in minutes)
    planned_production_time_min  INT        NOT NULL,   -- Total scheduled production time
    actual_production_time_min   INT        NULL,       -- Actual time producing
    downtime_total_min           INT        NOT NULL DEFAULT 0,
    downtime_planned_min         INT        NOT NULL DEFAULT 0,   -- Scheduled maintenance, breaks
    downtime_unplanned_min       INT        NOT NULL DEFAULT 0,   -- Breakdowns, shortages
    setup_time_min               INT        NOT NULL DEFAULT 0,
    changeover_time_min          INT        NOT NULL DEFAULT 0,

    -- Downtime reason (primary reason if multiple)
    downtime_reason_code    NVARCHAR(20)    NULL,   -- 'MAINT', 'SUPPLY', 'QUALITY', 'UTIL', 'OTHER'
    downtime_reason_desc    NVARCHAR(200)   NULL,

    -- Output measures
    planned_output_units    INT             NOT NULL,   -- Units planned for this run
    actual_output_units     INT             NOT NULL,   -- Total units produced (good + defect)
    good_units              INT             NOT NULL,   -- Units passing quality check
    defective_units         INT             NOT NULL DEFAULT 0,
    rework_units            INT             NOT NULL DEFAULT 0,   -- Defective but salvageable
    scrap_units             INT             NOT NULL DEFAULT 0,   -- Written off entirely

    -- OEE components (expressed as decimals 0-1 for precision; multiply by 100 for %)
    --   Availability = (planned_time - downtime_unplanned) / planned_time
    --   Performance  = actual_output / (actual_production_time * ideal_cycle_rate)
    --   Quality      = good_units / actual_output_units
    --   OEE          = Availability * Performance * Quality
    availability_rate       DECIMAL(7,6)    NULL,   -- e.g., 0.920000 = 92%
    performance_rate        DECIMAL(7,6)    NULL,   -- e.g., 0.870000 = 87%
    quality_rate            DECIMAL(7,6)    NULL,   -- e.g., 0.985000 = 98.5%
    oee_rate                DECIMAL(7,6)    NULL,   -- overall equipment effectiveness
    ideal_cycle_time_sec    DECIMAL(10,4)   NULL,   -- Ideal seconds per unit (from engineering)

    -- Cost
    direct_labor_cost_usd   DECIMAL(14,2)   NULL,
    material_cost_usd       DECIMAL(14,2)   NULL,
    overhead_cost_usd       DECIMAL(14,2)   NULL,
    total_production_cost_usd DECIMAL(14,2) NULL,
    cost_per_unit_usd       DECIMAL(14,4)   NULL,   -- total_cost / good_units

    -- Energy
    energy_consumption_kwh  DECIMAL(12,4)   NULL,
    energy_cost_usd         DECIMAL(12,2)   NULL,

    created_at              DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_fact_production PRIMARY KEY (production_id),
    CONSTRAINT FK_fprod_plant    FOREIGN KEY (plant_key)            REFERENCES dim_plant (plant_key),
    CONSTRAINT FK_fprod_product  FOREIGN KEY (product_key)          REFERENCES dim_product (product_key),
    CONSTRAINT FK_fprod_vehicle  FOREIGN KEY (vehicle_key)          REFERENCES dim_vehicle (vehicle_key),
    CONSTRAINT FK_fprod_date     FOREIGN KEY (production_date_key)  REFERENCES dim_date (date_key)
);

CREATE INDEX IX_fprod_plant_date     ON fact_production (plant_key, production_date_key);
CREATE INDEX IX_fprod_product_date   ON fact_production (product_key, production_date_key);
CREATE INDEX IX_fprod_vehicle_date   ON fact_production (vehicle_key, production_date_key);
CREATE INDEX IX_fprod_oee            ON fact_production (plant_key, oee_rate);
CREATE INDEX IX_fprod_downtime       ON fact_production (downtime_unplanned_min, production_date_key);

COMMENT ON TABLE fact_production IS 'Production run fact table - grain: shift x line x product x date. Supports OEE and efficiency analysis.';


-- =============================================================================
-- END OF FILE: 01_create_tables.sql
-- =============================================================================
