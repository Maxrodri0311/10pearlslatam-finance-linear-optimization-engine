@echo off
setlocal enabledelayedexpansion

echo ================================================================================
echo   Enterprise BI & Data Modernization Practice: Financial Analytics and Linear Optimization Engine
echo   Automated Execution, Verification, and Quantitative Benchmarks
echo ================================================================================
echo.

echo [1/5] Generating Calibrated Stochastic Operational Dataset (50,000 rows)...
python src/data_generator.py --records 50000
if errorlevel 1 (
    echo [ERROR] Data generator failed
    exit /b 1
)

echo.
echo [2/5] Executing Decoupled Lakehouse Engine and Linear Programming Solver...
python src/core_engine.py
if errorlevel 1 (
    echo [ERROR] Core engine failed
    exit /b 1
)

echo.
echo [3/5] Validating Great Expectations and DuckDB Lakehouse Data Contracts...
python src/interface.py
if errorlevel 1 (
    echo [ERROR] Contract validation failed
    exit /b 1
)

echo.
echo [4/5] Running Automated Pytest Verification Suite...
python -m pytest tests/ -v
if errorlevel 1 (
    echo [ERROR] Pytest suite failed
    exit /b 1
)

echo.
echo [5/5] Running Quantitative Latency Benchmarks (30 iterations)...
python tests/benchmark.py
if errorlevel 1 (
    echo [ERROR] Benchmark failed
    exit /b 1
)

echo.
echo ================================================================================
echo   Execution Complete: All Tests Passed, Invariants Verified, p95 below 150ms!
echo ================================================================================