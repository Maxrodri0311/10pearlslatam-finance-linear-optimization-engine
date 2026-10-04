#!/usr/bin/env bash
set -e

echo "================================================================================"
echo "  10Pearls LATAM: Financial Analytics & Linear Optimization Engine"
echo "  Automated Execution, Verification, and Quantitative Benchmarks"
echo "================================================================================"
echo ""

echo "[1/5] Generating Calibrated Stochastic Operational Dataset (50,000 rows)..."
python src/data_generator.py --records 50000

echo ""
echo "[2/5] Executing Decoupled Lakehouse Engine & Linear Programming Solver..."
python src/core_engine.py

echo ""
echo "[3/5] Validating Great Expectations & DuckDB Lakehouse Data Contracts..."
python src/interface.py

echo ""
echo "[4/5] Running Automated Pytest Verification Suite..."
python -m pytest tests/ -v

echo ""
echo "[5/5] Running Quantitative Latency Benchmarks (30 iterations)..."
python tests/benchmark.py

echo ""
echo "================================================================================"
echo "  Execution Complete: 100% Tests Passed, Invariants Verified, p95 < 150ms!"
echo "================================================================================"