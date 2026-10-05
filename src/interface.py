"""
src/interface.py - Lakehouse & Data Contracts Runner (MODERN_LAKEHOUSE_CONTRACTS Paradigm).
Schema contracts and data quality gate for proj_10pearls_latam_business_intelligence_engineer_bridge_pr.
"""

import os
import sys
from pathlib import Path

project_root = str(Path(__file__).resolve().parent.parent)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from src.core_engine import create_engine


def validate_contracts():
    print("[Lakehouse Contracts] Validating Great Expectations / DuckDB schemas for Enterprise BI & Data Modernization Practice...")
    engine = create_engine()
    df = engine.execute_analysis()
    
    # Contract assertions
    assert len(df) > 0, "Lakehouse must return records"
    assert "total_records" in df.columns, "Schema contract violation: missing total_records"
    assert "mean_primary_metric" in df.columns, "Schema contract violation: missing mean_primary_metric"
    assert df.iloc[0]["total_records"] > 0, "Total records must be positive"
    
    # Regional Mart Contract Assertion
    mart_df = engine.execute_executive_lakehouse_mart()
    assert len(mart_df) > 0, "Regional mart must return aggregated dimensions"
    assert "cost_center" in mart_df.columns, "Regional mart contract violation: missing cost_center"
    assert "total_operating_cost" in mart_df.columns, "Regional mart contract violation: missing total_operating_cost"

    # Optimization Contract Assertion
    opt_res = engine.optimize_regional_capacity()
    assert opt_res["success"] is True, "Linear programming solver failed to find optimal allocation"
    assert opt_res["optimal_cost_usd"] > 0, "Optimal cost must be strictly positive"

    print(
        f"[Lakehouse Contracts] All schema checks PASSED. "
        f"Verified {df.iloc[0]['total_records']:,} records across {len(mart_df)} regional slices. "
        f"Optimal allocation solved in {opt_res['execution_time_ms']:.2f}ms."
    )


if __name__ == "__main__":
    validate_contracts()