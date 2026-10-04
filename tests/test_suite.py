"""
tests/test_suite.py - Automated Pytest Suite.
Verifies data generation, schema integrity, linear programming invariants, and Dependency Inversion Principle (DIP).
"""

import os
import tempfile
import pytest
import numpy as np
import pandas as pd

from src.data_generator import generate_domain_dataset
from src.core_engine import (
    DomainAnalyticsEngine,
    DuckDBStorageAdapter,
    LinearOptimizationEngine,
    create_engine,
)
from src.domain.contracts import AnalyticalStorageProtocol, CoreModelProtocol, ExecutionContext
from src.interface import validate_contracts


@pytest.fixture(scope="session")
def test_dataset(tmp_path_factory):
    """Generates a calibrated fixture dataset for testing."""
    fn = tmp_path_factory.mktemp("data") / "test_data.parquet"
    df = generate_domain_dataset(num_records=2500, output_path=str(fn), seed=42)
    return str(fn)


def test_data_generation_integrity(test_dataset):
    """Asserts schema completeness, column naming, and absence of nulls."""
    df = pd.read_parquet(test_dataset)
    assert len(df) == 2500
    assert "unit_id" in df.columns
    assert "entity_id" in df.columns
    assert "operating_cost_usd" in df.columns
    assert "gross_margin_usd" in df.columns
    assert "sla_compliance_ratio" in df.columns
    assert "cost_center" in df.columns
    assert "status_category" in df.columns
    assert df.isnull().sum().sum() == 0


def test_stochastic_physics_boundaries(test_dataset):
    """Verifies that generated variables respect physical domain bounds."""
    df = pd.read_parquet(test_dataset)
    
    # Financial Bounds
    assert (df["primary_metric"] >= 10.0).all()
    assert (df["primary_metric"] <= 500.0).all()
    assert (df["volume_count"] >= 1).all()
    assert (df["volume_count"] <= 1000).all()
    assert (df["operating_cost_usd"] > 0).all()
    
    # Operational SLA Bounds
    assert (df["sla_compliance_ratio"] >= 0.70).all()
    assert (df["sla_compliance_ratio"] <= 1.00).all()

    # Categorical Invariants
    expected_centers = {"LATAM-BOG", "LATAM-BA", "LATAM-CDMX", "LATAM-SP", "US-EAST"}
    assert set(df["cost_center"].unique()).issubset(expected_centers)

    expected_tiers = {"STANDARD", "ACCELERATED", "ENTERPRISE", "MISSION_CRITICAL"}
    assert set(df["status_category"].unique()).issubset(expected_tiers)


def test_core_engine_execution_with_duckdb(test_dataset):
    """Asserts that DuckDB columnar execution returns valid summary stats."""
    adapter = DuckDBStorageAdapter()
    engine = DomainAnalyticsEngine(storage=adapter, data_path=test_dataset)
    res = engine.execute_analysis()
    
    assert len(res) == 1
    assert "total_records" in res.columns
    assert "mean_primary_metric" in res.columns
    assert "p95_metric" in res.columns
    assert res.iloc[0]["total_records"] == 2500
    assert res.iloc[0]["min_metric"] <= res.iloc[0]["mean_primary_metric"] <= res.iloc[0]["max_metric"]


def test_executive_lakehouse_mart_aggregation(test_dataset):
    """Validates multidimensional regional mart rollups and SLA averages."""
    adapter = DuckDBStorageAdapter()
    engine = DomainAnalyticsEngine(storage=adapter, data_path=test_dataset)
    mart = engine.execute_executive_lakehouse_mart()

    assert len(mart) > 0
    assert "cost_center" in mart.columns
    assert "status_category" in mart.columns
    assert "total_operating_cost" in mart.columns
    assert "total_gross_margin" in mart.columns
    assert "avg_sla_compliance_pct" in mart.columns
    
    # Financial consistency: total margin should be strictly positive across aggregations
    assert (mart["total_operating_cost"] > 0).all()
    assert (mart["avg_sla_compliance_pct"] >= 70.0).all()


def test_linear_optimization_mathematical_invariants():
    """Asserts linear programming optimization convergence, demand conservation and capacity limits."""
    solver = LinearOptimizationEngine()
    
    custom_demand = {
        "STANDARD": 10000.0,
        "ACCELERATED": 5000.0,
        "ENTERPRISE": 2500.0,
        "MISSION_CRITICAL": 1000.0,
    }
    custom_capacity = {
        "LATAM-BOG": 8000.0,
        "LATAM-BA": 7000.0,
        "LATAM-CDMX": 5000.0,
        "LATAM-SP": 4000.0,
        "US-EAST": 3000.0,
    }
    
    res = solver.solve_allocation_problem(
        demand_requirements=custom_demand,
        capacity_limits=custom_capacity,
    )
    
    assert res["success"] is True
    assert res["optimal_cost_usd"] > 0.0
    
    # 1. Demand Conservation Invariant: Sum of allocated units == total demand
    total_expected_demand = sum(custom_demand.values())
    assert abs(res["total_allocated_units"] - total_expected_demand) < 1e-4

    # 2. Capacity Constraint Invariant: Center allocation <= max capacity
    alloc = res["allocation_matrix"]
    for center, max_cap in custom_capacity.items():
        allocated_to_center = sum(alloc[cat][center] for cat in custom_demand.keys())
        assert allocated_to_center <= max_cap + 1e-4

    # 3. Latency constraint: Solver must execute sub-50ms
    assert res["execution_time_ms"] < 50.0


def test_core_engine_dependency_inversion_mock():
    """Validates that domain logic works with in-memory mock adapters without disk or DuckDB."""
    class MockStorageAdapter:
        def execute_query(self, query: str) -> pd.DataFrame:
            return pd.DataFrame([
                {"total_records": 500, "mean_primary_metric": 42.0, "p95_metric": 88.0, "min_metric": 10.0, "max_metric": 120.0}
            ])
        def scan_dataset(self, base_path: str) -> pd.DataFrame:
            return pd.DataFrame()

    class MockOptimizerAdapter:
        def evaluate(self, context: ExecutionContext):
            return {
                "success": True,
                "optimal_cost_usd": 50000.0,
                "total_allocated_units": 500.0,
                "execution_time_ms": 1.25,
            }

    with tempfile.NamedTemporaryFile(suffix=".parquet") as tmp:
        engine = DomainAnalyticsEngine(
            storage=MockStorageAdapter(),
            data_path=tmp.name,
            optimizer=MockOptimizerAdapter(),
        )
        res = engine.execute_analysis()
        assert len(res) == 1
        assert res.iloc[0]["mean_primary_metric"] == 42.0

        opt_res = engine.optimize_regional_capacity()
        assert opt_res["success"] is True
        assert opt_res["optimal_cost_usd"] == 50000.0


def test_interface_contract_verification():
    """Validates that the contract verification runner succeeds without assertion errors."""
    # Runs the formal interface check
    validate_contracts()