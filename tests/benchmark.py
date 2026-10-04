"""
tests/benchmark.py - Quantitative Latency & Algorithmic Benchmark for 10Pearls LATAM.
Measures p50, p95, and p99 query latency over 30 iterations for:
  1. DuckDB In-Memory Columnar Scans & Aggregations
  2. Multi-Regional Linear Programming Capacity Solver (SciPy HiGHS)
Enforces SLA constraints: p95 < 150.0 ms.
"""

import os
import sys
import time
import tempfile
from pathlib import Path
import numpy as np

project_root = str(Path(__file__).resolve().parent.parent)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from src.data_generator import generate_domain_dataset
from src.core_engine import DomainAnalyticsEngine, DuckDBStorageAdapter, LinearOptimizationEngine


def run_benchmarks(iterations: int = 30, num_records: int = 50000):
    print(f"[Benchmark] Preparing calibrated dataset with {num_records:,} records...")
    with tempfile.NamedTemporaryFile(suffix=".parquet", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        generate_domain_dataset(num_records=num_records, output_path=tmp_path, seed=42)
        adapter = DuckDBStorageAdapter()
        optimizer = LinearOptimizationEngine()
        engine = DomainAnalyticsEngine(storage=adapter, data_path=tmp_path, optimizer=optimizer)
        
        # 1. Warmup Runs
        engine.execute_analysis()
        engine.execute_executive_lakehouse_mart()
        optimizer.solve_allocation_problem()
        
        print(f"[Benchmark] Running {iterations} iterations over 50,000-row Lakehouse & LP Solver...")
        scan_latencies = []
        mart_latencies = []
        solver_latencies = []

        for _ in range(iterations):
            # Benchmark 1: Core Columnar Aggregation
            t0 = time.perf_counter()
            engine.execute_analysis()
            scan_latencies.append((time.perf_counter() - t0) * 1000.0)

            # Benchmark 2: Multidimensional Regional Mart
            t1 = time.perf_counter()
            engine.execute_executive_lakehouse_mart()
            mart_latencies.append((time.perf_counter() - t1) * 1000.0)

            # Benchmark 3: Linear Programming Solver
            t2 = time.perf_counter()
            optimizer.solve_allocation_problem()
            solver_latencies.append((time.perf_counter() - t2) * 1000.0)
            
        # Statistical Metrics
        scan_p50 = float(np.percentile(scan_latencies, 50))
        scan_p95 = float(np.percentile(scan_latencies, 95))
        scan_p99 = float(np.percentile(scan_latencies, 99))

        mart_p50 = float(np.percentile(mart_latencies, 50))
        mart_p95 = float(np.percentile(mart_latencies, 95))
        mart_p99 = float(np.percentile(mart_latencies, 99))

        solver_p50 = float(np.percentile(solver_latencies, 50))
        solver_p95 = float(np.percentile(solver_latencies, 95))
        solver_p99 = float(np.percentile(solver_latencies, 99))
        
        print("\n" + "="*80)
        print("  10PEARLS LATAM - QUANTITATIVE BENCHMARK REPORT (ms)")
        print("="*80)
        print(f"  Dataset Size: {num_records:,} rows | Sample Iterations: {iterations}")
        print("-" * 80)
        print("  1. DUCKDB COLUMNAR SCAN (read_parquet)")
        print(f"     p50 Latency:  {scan_p50:6.2f} ms")
        print(f"     p95 Latency:  {scan_p95:6.2f} ms (Constraint: < 150.0 ms)")
        print(f"     p99 Latency:  {scan_p99:6.2f} ms")
        print("-" * 80)
        print("  2. EXECUTIVE REGIONAL LAKEHOUSE MART (GROUP BY cost_center, tier)")
        print(f"     p50 Latency:  {mart_p50:6.2f} ms")
        print(f"     p95 Latency:  {mart_p95:6.2f} ms (Constraint: < 150.0 ms)")
        print(f"     p99 Latency:  {mart_p99:6.2f} ms")
        print("-" * 80)
        print("  3. LINEAR PROGRAMMING SOLVER (SciPy HiGHS Allocation Matrix)")
        print(f"     p50 Latency:  {solver_p50:6.2f} ms")
        print(f"     p95 Latency:  {solver_p95:6.2f} ms (Constraint: < 50.0 ms)")
        print(f"     p99 Latency:  {solver_p99:6.2f} ms")
        print("="*80)
        
        # Enforce SLA Guard Assertions
        assert scan_p95 < 150.0, f"SLA Violation: Columnar scan p95 latency {scan_p95:.2f}ms exceeds 150.0ms"
        assert mart_p95 < 150.0, f"SLA Violation: Regional mart p95 latency {mart_p95:.2f}ms exceeds 150.0ms"
        assert solver_p95 < 50.0, f"SLA Violation: LP Solver p95 latency {solver_p95:.2f}ms exceeds 50.0ms"
        print("[Benchmark Guard PASS] All quantitative benchmarks satisfy strict SLA constraints.\n")

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


if __name__ == "__main__":
    run_benchmarks()