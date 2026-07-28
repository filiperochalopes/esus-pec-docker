from __future__ import annotations

import json
from zipfile import ZipFile

from pec_demo.artifacts import write_generation_artifacts


def test_generation_artifacts_include_valid_zip_and_manifest(
    dataset,
    backend_jar,
    tmp_path,
):
    paths = write_generation_artifacts(
        dataset,
        output_dir=tmp_path,
        backend_jar=backend_jar,
    )

    assert set(paths) == {"xml", "zip", "manifest"}
    with ZipFile(paths["zip"]) as archive:
        assert archive.namelist() == ["cnes-demo-3.1.xml"]

    manifest_text = paths["manifest"].read_text(encoding="utf-8")
    manifest = json.loads(manifest_text)
    assert manifest["status"] == "generated_not_imported"
    assert manifest["counts"] == {
        "units": 2,
        "teams": 2,
        "professionals": 3,
        "assignments": 4,
    }
    assert "senha" not in manifest_text.lower()
    assert all(item.planned_password not in manifest_text for item in dataset.professionals)

    assert not (tmp_path / "demo_credentials.txt").exists()
