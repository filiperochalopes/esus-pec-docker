from __future__ import annotations

from datetime import date
from pathlib import Path

import pytest

from pec_demo.factory import build_demo_dataset


@pytest.fixture
def dataset():
    return build_demo_dataset(
        seed=5522,
        municipality_ibge="2927408",
        uf="BA",
        cep="40000000",
        generated_on=date(2026, 7, 27),
    )


@pytest.fixture
def backend_jar() -> Path:
    path = (
        Path(__file__).resolve().parents[3]
        / "codebase"
        / "app-extracted"
        / "BOOT-INF"
        / "lib"
        / "backend-5.5.22.jar"
    )
    if not path.is_file():
        pytest.skip("backend-5.5.22.jar is not available")
    return path
