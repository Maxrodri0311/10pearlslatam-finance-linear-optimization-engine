"""
src/domain/entities.py - Pure domain models for proj_10pearls_latam_business_intelligence_engineer_bridge_pr.
Zero external I/O or vendor dependencies imported here.
"""

from typing import Optional, List, Dict
from pydantic import BaseModel, Field

class PrimaryExecutionUnit(BaseModel):
    """Core domain entity representing business transactions for 10Pearls LATAM"""
    unit_id: str = Field(description="Unique transaction or execution unit identifier")
    primary_metric: float = Field(default=0.0, description="Financial margin or processing cost in USD")
    is_active: bool = Field(default=True, description="Operational status flag")
    volume_count: float = Field(default=1.0, ge=0.0, description="Transaction batch volume count")
    status_category: str = Field(default="STANDARD", description="Processing lifecycle category")


class ResourceAllocationConstraint(BaseModel):
    """Business boundary constraint for linear programming optimization."""
    constraint_id: str
    max_budget_limit: float = Field(gt=0.0, description="Upper threshold on operating budget")
    penalty_rate: float = Field(ge=0.0, default=1.5, description="Penalty multiplier on boundary overrun")
    is_hard_constraint: bool = Field(default=True)


class ExecutionContext(BaseModel):
    """Runtime context for the analytical engine."""
    execution_id: str
    target_metric: float = 0.0
    is_active: bool = True