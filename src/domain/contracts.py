"""
src/domain/contracts.py - Inversion of Dependencies (DIP) Protocols.
All analytical and delivery services depend strictly on these abstract interfaces.
"""

from typing import Protocol, Optional, List, Dict, Any
import pandas as pd
from .entities import ExecutionContext


class AnalyticalStorageProtocol(Protocol):
    """Abstract analytical storage contract (DuckDB, Athena, or In-Memory Mock)."""
    def execute_query(self, query: str) -> pd.DataFrame: ...
    def scan_dataset(self, base_path: str) -> pd.DataFrame: ...


class CoreModelProtocol(Protocol):
    """Abstract algorithmic decision engine (AlgorithmFamily.LINEAR_PROGRAMMING)."""
    def evaluate(self, context: ExecutionContext) -> Dict[str, Any]: ...


class DeliverySinkProtocol(Protocol):
    """Abstract delivery contract for DeliveryParadigm.MODERN_LAKEHOUSE_CONTRACTS."""
    def render(self, data: pd.DataFrame) -> Any: ...