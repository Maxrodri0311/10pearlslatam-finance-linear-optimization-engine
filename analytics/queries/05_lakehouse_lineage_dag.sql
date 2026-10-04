-- ==============================================================================
-- 10Pearls LATAM Analytical Lakehouse - Medallion Architecture Lineage DAG
-- Target: PostgreSQL 16 Enterprise / Microsoft Fabric Data Warehouse / DuckDB
-- Role: Business Intelligence Engineer | Paradigm: MODERN_LAKEHOUSE_CONTRACTS
-- Architecture: Bronze (Raw Ingestion) -> Silver (Conformed & Validated) -> Gold (Executive KPIs)
-- ==============================================================================

SET search_path TO analytical_lakehouse, public;

-- ------------------------------------------------------------------------------
-- LAYER 1: BRONZE VIEW (Raw Ingestion Normalization & Event Time Windowing)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_10pearls_bronze_telemetry_stream AS
SELECT
    telemetry_id,
    entity_id AS execution_unit_id,
    domain_cluster,
    primary_metric AS raw_processing_cost_metric,
    volume_count AS raw_batch_size,
    is_active AS raw_activity_flag,
    status_category AS raw_service_tier,
    event_timestamp,
    created_at AS ingestion_timestamp,
    -- Audit Metadata
    MD5(CONCAT(entity_id, '|', event_timestamp::text)) AS record_hash_fingerprint
FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry;

-- ------------------------------------------------------------------------------
-- LAYER 2: SILVER VIEW (Conformed Business Logic, Outlier Capping & Deduplication)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_10pearls_silver_conformed_operations AS
WITH deduplicated_bronze AS (
    SELECT
        telemetry_id,
        execution_unit_id,
        domain_cluster,
        raw_processing_cost_metric,
        raw_batch_size,
        raw_activity_flag,
        raw_service_tier,
        event_timestamp,
        ingestion_timestamp,
        record_hash_fingerprint,
        ROW_NUMBER() OVER (
            PARTITION BY execution_unit_id, event_timestamp
            ORDER BY ingestion_timestamp DESC
        ) AS dedup_rank
    FROM v_10pearls_bronze_telemetry_stream
),

enriched_silver AS (
    SELECT
        execution_unit_id,
        domain_cluster,
        raw_service_tier AS service_tier,
        event_timestamp,
        -- Capped and Validated Metric Boundaries
        GREATEST(10.0, LEAST(500.0, raw_processing_cost_metric)) AS normalized_unit_cost_usd,
        GREATEST(1, LEAST(1000, raw_batch_size)) AS validated_batch_volume,
        raw_activity_flag AS is_active,
        -- Regional Cost Center Inference based on Hash Bucketing for Distributed Processing
        CASE MOD(ABS(HASHTEXT(execution_unit_id)), 5)
            WHEN 0 THEN 'LATAM-BOG'
            WHEN 1 THEN 'LATAM-BA'
            WHEN 2 THEN 'LATAM-CDMX'
            WHEN 3 THEN 'LATAM-SP'
            ELSE 'US-EAST'
        END AS inferred_cost_center,
        -- SLA Baseline Attribution
        CASE raw_service_tier
            WHEN 'MISSION_CRITICAL' THEN 0.98
            WHEN 'ENTERPRISE'       THEN 0.95
            WHEN 'ACCELERATED'      THEN 0.92
            ELSE 0.88
        END AS target_sla_threshold
    FROM deduplicated_bronze
    WHERE dedup_rank = 1
)

SELECT
    execution_unit_id,
    inferred_cost_center,
    domain_cluster,
    service_tier,
    event_timestamp,
    normalized_unit_cost_usd,
    validated_batch_volume,
    is_active,
    target_sla_threshold,
    -- Financial Gross Margin Calculation: Revenue Baseline = Cost * Multiplier
    ROUND(
        (normalized_unit_cost_usd * validated_batch_volume * 1.35)::numeric, 
        2
    ) AS estimated_gross_revenue_usd,
    ROUND(
        (normalized_unit_cost_usd * validated_batch_volume)::numeric, 
        2
    ) AS estimated_operating_cost_usd,
    ROUND(
        ((normalized_unit_cost_usd * validated_batch_volume * 1.35) - (normalized_unit_cost_usd * validated_batch_volume))::numeric, 
        2
    ) AS estimated_gross_profit_usd
FROM enriched_silver;

-- ------------------------------------------------------------------------------
-- LAYER 3: GOLD AGGREGATE MART (Executive KPI Summaries & Cost Center Governance)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_10pearls_gold_executive_kpis AS
WITH regional_gold_cubes AS (
    SELECT
        inferred_cost_center AS cost_center,
        service_tier,
        DATE_TRUNC('month', event_timestamp) AS financial_reporting_month,
        COUNT(DISTINCT execution_unit_id) AS total_active_units,
        SUM(validated_batch_volume) AS total_processed_volume,
        ROUND(SUM(estimated_operating_cost_usd), 2) AS aggregate_operating_cost_usd,
        ROUND(SUM(estimated_gross_profit_usd), 2) AS aggregate_gross_profit_usd,
        ROUND(AVG(normalized_unit_cost_usd), 4) AS mean_unit_cost_usd,
        -- Weighted Profit Margin Percentage
        ROUND(
            (SUM(estimated_gross_profit_usd) / NULLIF(SUM(estimated_gross_revenue_usd), 0) * 100)::numeric, 
            2
        ) AS profit_margin_pct,
        -- Ranking of Service Tiers within each Regional Center
        DENSE_RANK() OVER (
            PARTITION BY inferred_cost_center, DATE_TRUNC('month', event_timestamp)
            ORDER BY SUM(estimated_gross_profit_usd) DESC
        ) AS tier_profitability_rank
    FROM v_10pearls_silver_conformed_operations
    WHERE is_active = TRUE
    GROUP BY inferred_cost_center, service_tier, DATE_TRUNC('month', event_timestamp)
)

SELECT
    financial_reporting_month,
    cost_center,
    service_tier,
    tier_profitability_rank,
    total_active_units,
    total_processed_volume,
    aggregate_operating_cost_usd,
    aggregate_gross_profit_usd,
    mean_unit_cost_usd,
    profit_margin_pct,
    -- Financial Efficiency Classification
    CASE
        WHEN profit_margin_pct >= 25.0 THEN 'EXEMPLARY_PROFITABILITY'
        WHEN profit_margin_pct >= 20.0 THEN 'HEALTHY_MARGIN'
        WHEN profit_margin_pct >= 15.0 THEN 'MODERATE_EFFICIENCY'
        ELSE 'LOW_MARGIN_INVESTIGATION_REQUIRED'
    END AS operational_margin_category,
    CURRENT_TIMESTAMP AS lineage_compiled_at
FROM regional_gold_cubes
ORDER BY 
    financial_reporting_month ASC, 
    cost_center ASC, 
    tier_profitability_rank ASC;

COMMENT ON VIEW v_10pearls_gold_executive_kpis IS
    'Gold Layer Medallion Executive KPI View: Full Data Lineage and SLA Attribution for 10Pearls LATAM.';
