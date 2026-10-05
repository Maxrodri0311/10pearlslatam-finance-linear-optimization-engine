-- ==============================================================================
-- Enterprise BI & Data Modernization Practice Analytical Lakehouse - Capacity & Margin Optimization Data Mart
-- Target: PostgreSQL 16 Materialized Views & Analytical Rollups
-- Role: Business Intelligence Engineer | Paradigm: MODERN_LAKEHOUSE_CONTRACTS
-- Business Case: WebFOCUS Legacy Migration vs Dynamic Linear Programming Allocation
-- ==============================================================================

SET search_path TO analytical_lakehouse, public;

DROP MATERIALIZED VIEW IF EXISTS mv_10pearls_capacity_optimization_mart CASCADE;

CREATE MATERIALIZED VIEW mv_10pearls_capacity_optimization_mart AS
WITH regional_demand_summary AS (
    SELECT
        cost_center,
        status_category,
        COUNT(DISTINCT entity_id) AS active_execution_units,
        SUM(volume_count) AS total_demand_volume,
        ROUND(SUM(operating_cost_usd)::numeric, 2) AS aggregate_operating_cost,
        ROUND(SUM(gross_margin_usd)::numeric, 2) AS aggregate_gross_margin,
        ROUND(AVG(allocated_capacity_hours)::numeric, 2) AS mean_capacity_hours_allocated,
        ROUND(AVG(sla_compliance_ratio * 100)::numeric, 2) AS observed_sla_pct
    FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
    WHERE is_active = TRUE
    GROUP BY cost_center, status_category
),

center_capacity_benchmarks AS (
    SELECT
        cost_center,
        SUM(total_demand_volume) AS center_total_volume,
        SUM(aggregate_operating_cost) AS center_total_cost,
        SUM(aggregate_gross_margin) AS center_total_margin,
        CASE cost_center
            WHEN 'LATAM-BOG' THEN 18000.0
            WHEN 'LATAM-BA'  THEN 16000.0
            WHEN 'LATAM-CDMX' THEN 14000.0
            WHEN 'LATAM-SP'  THEN 10000.0
            WHEN 'US-EAST'   THEN 8000.0
            ELSE 12000.0
        END AS max_capacity_threshold_units
    FROM regional_demand_summary
    GROUP BY cost_center
),

optimization_variance_cte AS (
    SELECT
        r.cost_center,
        r.status_category,
        r.active_execution_units,
        r.total_demand_volume,
        r.aggregate_operating_cost,
        r.aggregate_gross_margin,
        r.observed_sla_pct,
        b.center_total_volume,
        b.max_capacity_threshold_units,
        -- Utilization Ratio: Demanded volume vs physical center capacity
        ROUND((b.center_total_volume / b.max_capacity_threshold_units * 100)::numeric, 2) AS capacity_utilization_pct,
        -- Legacy WebFOCUS Static Model Cost Projection (linear flat rate with no scale efficiency)
        ROUND((r.total_demand_volume * 24.50)::numeric, 2) AS legacy_webfocus_projected_cost,
        -- Net Savings achieved through Dynamic Optimized Allocation (Linear Programming)
        ROUND(((r.total_demand_volume * 24.50) - r.aggregate_operating_cost)::numeric, 2) AS optimization_cost_savings_usd,
        -- Unit Cost Efficiency Score
        ROUND((r.aggregate_operating_cost / NULLIF(r.total_demand_volume, 0))::numeric, 4) AS unit_cost_usd
    FROM regional_demand_summary r
    JOIN center_capacity_benchmarks b ON r.cost_center = b.cost_center
)

SELECT
    cost_center,
    status_category,
    active_execution_units,
    total_demand_volume,
    aggregate_operating_cost,
    aggregate_gross_margin,
    observed_sla_pct,
    capacity_utilization_pct,
    legacy_webfocus_projected_cost,
    optimization_cost_savings_usd,
    unit_cost_usd,
    CASE
        WHEN capacity_utilization_pct >= 95.0 THEN 'CAPACITY_BOTTLENECK_HIGH_RISK'
        WHEN capacity_utilization_pct >= 80.0 THEN 'ELEVATED_LOAD_STABLE'
        ELSE 'HEADROOM_AVAILABLE'
    END AS operational_headroom_status,
    CURRENT_TIMESTAMP AS mart_compiled_at
FROM optimization_variance_cte
ORDER BY 
    cost_center ASC, 
    aggregate_gross_margin DESC;

CREATE UNIQUE INDEX IF NOT EXISTS uq_idx_10pearls_capacity_mart 
    ON mv_10pearls_capacity_optimization_mart (cost_center, status_category);

COMMENT ON MATERIALIZED VIEW mv_10pearls_capacity_optimization_mart IS
    'C-Level Executive Lakehouse Mart comparing legacy static allocations against dynamic linear programming routing.';
