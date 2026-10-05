-- ==============================================================================
-- Enterprise BI & Data Modernization Practice Analytical Lakehouse - Advanced Longitudinal Cohort & Survival Analytics
-- Target: PostgreSQL 16 Enterprise / DuckDB In-Memory OLAP
-- Role: Business Intelligence Engineer | Paradigm: DeliveryParadigm.MODERN_LAKEHOUSE_CONTRACTS
-- Techniques: Time-to-Event Analysis, Moving Quantiles, Window Frames & Dense Ranking
-- ==============================================================================

WITH base_telemetry AS (
    SELECT
        unit_id AS entity_id,
        cost_center,
        status_category,
        primary_metric,
        volume_count,
        operating_cost_usd,
        gross_margin_usd,
        allocated_capacity_hours,
        sla_compliance_ratio,
        is_active,
        event_timestamp,
        DATE_TRUNC('month', event_timestamp) AS cohort_month,
        DATE_TRUNC('week', event_timestamp) AS cohort_week
    FROM telemetry_events
),

longitudinal_metrics AS (
    SELECT
        entity_id,
        cost_center,
        status_category,
        cohort_month,
        cohort_week,
        primary_metric,
        volume_count,
        operating_cost_usd,
        gross_margin_usd,
        allocated_capacity_hours,
        sla_compliance_ratio,
        is_active,
        -- Sequential Event Indexing per Entity
        ROW_NUMBER() OVER (
            PARTITION BY entity_id 
            ORDER BY event_timestamp ASC
        ) AS event_sequence_num,
        -- Moving Operating Cost Window (7-Event Rolling Average)
        AVG(operating_cost_usd) OVER (
            PARTITION BY entity_id 
            ORDER BY event_timestamp ASC
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_avg_cost_usd,
        -- Category Benchmark Average
        AVG(primary_metric) OVER (
            PARTITION BY status_category
        ) AS category_benchmark_avg,
        -- Regional Cost Center Baseline
        AVG(operating_cost_usd) OVER (
            PARTITION BY cost_center
        ) AS regional_cost_baseline,
        -- Latency & Velocity: Delta from Previous Event
        operating_cost_usd - COALESCE(
            LAG(operating_cost_usd, 1) OVER (
                PARTITION BY entity_id ORDER BY event_timestamp ASC
            ),
            operating_cost_usd
        ) AS cost_velocity_delta
    FROM base_telemetry
),

cohort_stratification AS (
    SELECT
        entity_id,
        cost_center,
        status_category,
        cohort_month,
        primary_metric,
        volume_count,
        operating_cost_usd,
        gross_margin_usd,
        sla_compliance_ratio,
        rolling_avg_cost_usd,
        cost_velocity_delta,
        category_benchmark_avg,
        -- Mathematical Stratification: Cost Margin Anomaly & Operational Health Tier
        CASE
            WHEN primary_metric >= category_benchmark_avg * 1.30 AND sla_compliance_ratio < 0.85 THEN 'CRITICAL_LATENCY_SURGE'
            WHEN primary_metric >= category_benchmark_avg * 1.15 THEN 'HIGH_COST_VARIANCE'
            WHEN primary_metric <= category_benchmark_avg * 0.80 AND sla_compliance_ratio >= 0.95 THEN 'OPTIMAL_EFFICIENCY'
            ELSE 'NOMINAL_OPERATION'
        END AS operational_health_tier,
        -- Survival / Risk Scoring (0.0 to 1.0 Normalized Hazard Probability)
        ROUND(
            LEAST(1.0, GREATEST(0.0, 
                (1.0 - sla_compliance_ratio) * 0.60 + 
                (operating_cost_usd / (regional_cost_baseline + 1e-5)) * 0.40
            ))::numeric, 
            4
        ) AS hazard_risk_score,
        -- Multi-Regional Ranking
        DENSE_RANK() OVER (
            PARTITION BY cost_center 
            ORDER BY gross_margin_usd DESC
        ) AS regional_profitability_rank,
        -- Global Decile Assignment
        NTILE(10) OVER (
            ORDER BY operating_cost_usd DESC
        ) AS global_cost_decile
    FROM longitudinal_metrics
)

SELECT
    cohort_month,
    cost_center,
    status_category,
    operational_health_tier,
    COUNT(DISTINCT entity_id) AS total_tracked_units,
    ROUND(SUM(volume_count)::numeric, 0) AS aggregate_processed_volume,
    ROUND(AVG(operating_cost_usd)::numeric, 2) AS mean_operating_cost_usd,
    ROUND(SUM(gross_margin_usd)::numeric, 2) AS total_gross_margin_usd,
    ROUND(AVG(sla_compliance_ratio * 100)::numeric, 2) AS avg_sla_compliance_pct,
    ROUND(AVG(hazard_risk_score)::numeric, 4) AS mean_hazard_score,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY operating_cost_usd)::numeric, 2) AS p95_cost_boundary
FROM cohort_stratification
GROUP BY 
    cohort_month, 
    cost_center, 
    status_category, 
    operational_health_tier
HAVING COUNT(DISTINCT entity_id) >= 1
ORDER BY 
    cohort_month ASC, 
    total_gross_margin_usd DESC;