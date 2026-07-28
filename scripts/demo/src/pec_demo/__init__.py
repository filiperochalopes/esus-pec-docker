"""Synthetic, version-bound demo data for e-SUS PEC."""

from pec_demo.factory import build_demo_dataset
from pec_demo.validation import CnesReplicaValidator

__all__ = ["CnesReplicaValidator", "build_demo_dataset"]
__version__ = "0.1.0"
