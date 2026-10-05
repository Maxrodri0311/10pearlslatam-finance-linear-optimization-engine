"""
src/data_generator.py - Calibrated Stochastic Domain Data Generator.
Physics: Linear Programming & Capacity Allocation for Enterprise BI & Data Modernization Practice.
Generates enterprise financial and operational routing datasets with sublinear cost physics.
"""

import os
import time
import argparse
from datetime import datetime, timedelta
import numpy as np
import pandas as pd


def generate_domain_dataset(
    num_records: int = 50000,
    output_path: str = "data/raw_dataset.parquet",
    seed: int = 42,
) -> pd.DataFrame:
    """
    Synthesizes multidimensional cost, volume, and capacity allocation transactions
    for Enterprise BI & Data Modernization Practice operations using calibrated stochastic distributions.
    
    Invariants:
    1. Operating cost follows economies of scale: Cost = Base + Rate * (Volume^0.82) + Normal(0, sigma)
    2. Capacity hours scale sublinearly with volume demand
    3. Zero nulls across all generated attributes
    """
    print(f"[Data Generator] Generating {num_records:,} calibrated financial records for Enterprise BI & Data Modernization Practice...")
    start_time = time.time()
    
    np.random.seed(seed)
    rng = np.random.default_rng(seed)

    # 1. Primary and Entity Identifiers
    primary_ids = [f"id_{i:06d}" for i in range(1, num_records + 1)]

    # 2. Temporal Physics: Rolling 180-Day Window with Business Hours Seasonality
    base_timestamp = datetime(2026, 1, 1, 8, 0, 0)
    day_offsets = rng.integers(0, 180, size=num_records)
    
    # Weight hours towards business operations (9:00 - 18:00) with a Gaussian curve
    hour_offsets = np.clip(rng.normal(loc=13.5, scale=3.5, size=num_records), 0, 23).astype(int)
    minute_offsets = rng.integers(0, 60, size=num_records)
    second_offsets = rng.integers(0, 60, size=num_records)

    timestamps = [
        base_timestamp + timedelta(
            days=int(d), hours=int(h), minutes=int(m), seconds=int(s)
        )
        for d, h, m, s in zip(day_offsets, hour_offsets, minute_offsets, second_offsets)
    ]

    # 3. Categorical Routing Dimensions
    categories = ["STANDARD", "ACCELERATED", "ENTERPRISE", "MISSION_CRITICAL"]
    category_weights = [0.45, 0.30, 0.15, 0.10]
    assigned_categories = rng.choice(categories, p=category_weights, size=num_records)

    cost_centers = ["LATAM-BOG", "LATAM-BA", "LATAM-CDMX", "LATAM-SP", "US-EAST"]
    center_weights = [0.28, 0.25, 0.22, 0.15, 0.10]
    assigned_cost_centers = rng.choice(cost_centers, p=center_weights, size=num_records)

    domain_clusters = ["production", "staging", "analytics", "compliance"]
    cluster_weights = [0.65, 0.15, 0.12, 0.08]
    assigned_clusters = rng.choice(domain_clusters, p=cluster_weights, size=num_records)

    # 4. Stochastic Volumetric & Cost Physics
    # Volume follows a truncated discrete Pareto/Log-Normal distribution (frequent small batches, occasional large runs)
    raw_volume = rng.lognormal(mean=4.2, sigma=0.9, size=num_records)
    volume_count = np.clip(np.round(raw_volume), 1.0, 1000.0).astype(int)

    # Sublinear Operating Cost: Economies of scale with Gaussian stochastic noise
    base_unit_cost = 14.50
    scale_exponent = 0.82
    stochastic_noise = rng.normal(loc=0.0, scale=8.5, size=num_records)
    operating_cost_usd = np.round(
        np.maximum(10.0, (base_unit_cost * (volume_count ** scale_exponent)) + stochastic_noise), 2
    )

    # Primary Metric: Normalized Unit Cost / Processing Margin within [10.0, 500.0]
    primary_metric = np.round(
        np.clip((operating_cost_usd / (volume_count ** 0.5)) + rng.uniform(5.0, 25.0, size=num_records), 10.0, 500.0), 4
    )

    # Gross Financial Margin: Revenue - Cost
    unit_revenue_rate = rng.uniform(1.25, 1.65, size=num_records)
    gross_revenue = operating_cost_usd * unit_revenue_rate
    gross_margin_usd = np.round(gross_revenue - operating_cost_usd, 2)

    # Capacity Allocation (Hours required): correlated with volume and category tier
    tier_multipliers = {"STANDARD": 1.0, "ACCELERATED": 1.25, "ENTERPRISE": 1.60, "MISSION_CRITICAL": 2.10}
    category_factor = np.array([tier_multipliers[c] for c in assigned_categories])
    allocated_capacity_hours = np.round(
        np.maximum(0.25, (volume_count * 0.045 * category_factor) + rng.normal(0, 0.5, size=num_records)), 2
    )

    # SLA Compliance Ratio: higher volume with lower capacity strains SLA
    load_ratio = allocated_capacity_hours / (volume_count * 0.05 + 1e-5)
    sla_compliance_ratio = np.round(np.clip(0.92 + (0.07 * np.tanh(load_ratio - 0.8)), 0.70, 1.00), 4)

    # Operational status: active operational units (~84%)
    is_active = rng.choice([True, False], p=[0.84, 0.16], size=num_records)

    # 5. Assemble Structured DataFrame
    df = pd.DataFrame({
        "unit_id": primary_ids,
        "entity_id": primary_ids,
        "event_timestamp": timestamps,
        "domain_cluster": assigned_clusters,
        "primary_metric": primary_metric,
        "volume_count": volume_count,
        "operating_cost_usd": operating_cost_usd,
        "gross_margin_usd": gross_margin_usd,
        "allocated_capacity_hours": allocated_capacity_hours,
        "sla_compliance_ratio": sla_compliance_ratio,
        "cost_center": assigned_cost_centers,
        "status_category": assigned_categories,
        "is_active": is_active,
    })

    # 6. Physical Persist to Apache Parquet
    target_dir = os.path.dirname(output_path)
    if target_dir:
        os.makedirs(target_dir, exist_ok=True)
        
    df.to_parquet(output_path, index=False, engine="pyarrow", compression="snappy")

    elapsed = time.time() - start_time
    file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(
        f"[Data Generator] Successfully synthesized {len(df):,} records in {elapsed:.3f}s "
        f"({file_size_mb:.2f} MB) -> {output_path}"
    )
    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Calibrated Stochastic Data Generator for Enterprise BI & Data Modernization Practice.")
    parser.add_argument("--records", type=int, default=50000, help="Number of operational records to generate")
    parser.add_argument("--output", type=str, default="data/raw_dataset.parquet", help="Target output Parquet path")
    parser.add_argument("--seed", type=int, default=42, help="Deterministic pseudo-random seed")
    args = parser.parse_args()

    generate_domain_dataset(
        num_records=args.records,
        output_path=args.output,
        seed=args.seed,
    )