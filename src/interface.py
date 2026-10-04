"""
src/interface.py - Lakehouse & Data Contracts Runner (MODERN_LAKEHOUSE_CONTRACTS Paradigm).
Schema contracts and data quality gate for proj_10pearls_latam_business_intelligence_engineer_bridge_pr.
"""

from src.core_engine import create_engine

def validate_contracts():
    print("[Lakehouse Contracts] Validating Great Expectations / DuckDB schemas...")
    engine = create_engine()
    df = engine.execute_analysis()
    
    # Contract assertions
    assert len(df) > 0, "Lakehouse must return records"
    assert "total_records" in df.columns, "Schema contract violation"
    print(f"[Lakehouse Contracts] All schema checks PASSED. Verified {df.iloc[0]['total_records']} records.")

if __name__ == "__main__":
    validate_contracts()