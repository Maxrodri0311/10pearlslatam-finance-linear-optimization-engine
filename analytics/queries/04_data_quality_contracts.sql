-- ==============================================================================
-- 10Pearls LATAM Analytical Lakehouse - Declarative Data Quality Contracts & Tests
-- Target: PostgreSQL 16 Enterprise / DuckDB Automated Invariant Verifications
-- Role: Business Intelligence Engineer | Paradigm: MODERN_LAKEHOUSE_CONTRACTS
-- ==============================================================================

SET search_path TO analytical_lakehouse, public;

-- ------------------------------------------------------------------------------
-- 1. Primary Key Uniqueness & Nullability Contract
-- ------------------------------------------------------------------------------
WITH duplicate_keys_test AS (
    SELECT 
        entity_id, 
        COUNT(*) AS occurrence_count
    FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
    GROUP BY entity_id
    HAVING COUNT(*) > 1
)
SELECT 
    'TEST_PK_UNIQUENESS' AS test_name,
    COUNT(*) AS failure_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS test_status
FROM duplicate_keys_test;

-- ------------------------------------------------------------------------------
-- 2. Completeness & Not-Null Invariants
-- ------------------------------------------------------------------------------
SELECT 
    'TEST_COMPLETENESS_NOT_NULL' AS test_name,
    COUNT(*) AS failure_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS test_status
FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
WHERE 
    entity_id IS NULL
    OR primary_metric IS NULL
    OR volume_count IS NULL
    OR is_active IS NULL
    OR status_category IS NULL
    OR event_timestamp IS NULL;

-- ------------------------------------------------------------------------------
-- 3. Range Invariants & Non-Negative Financial Boundaries
-- ------------------------------------------------------------------------------
SELECT 
    'TEST_FINANCIAL_BOUNDARIES' AS test_name,
    COUNT(*) AS failure_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS test_status
FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
WHERE 
    primary_metric < 10.0 
    OR primary_metric > 500.0
    OR volume_count < 1 
    OR volume_count > 1000;

-- ------------------------------------------------------------------------------
-- 4. Categorical Domain Integrity Contract
-- ------------------------------------------------------------------------------
SELECT 
    'TEST_CATEGORICAL_INTEGRITY' AS test_name,
    COUNT(*) AS failure_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS test_status
FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
WHERE status_category NOT IN ('STANDARD', 'ACCELERATED', 'ENTERPRISE', 'MISSION_CRITICAL');

-- ------------------------------------------------------------------------------
-- 5. SLA Compliance Boundary Contract (70.0% to 100.0%)
-- ------------------------------------------------------------------------------
SELECT 
    'TEST_SLA_RATIO_BOUNDS' AS test_name,
    COUNT(*) AS failure_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END AS test_status
FROM proj_10pearls_latam_business_intelligence_engineer_bridge_pr_telemetry
WHERE sla_compliance_ratio < 0.70 OR sla_compliance_ratio > 1.00;
