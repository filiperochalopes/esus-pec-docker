"""Write CNES generation outputs without leaking credentials to the manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from pec_demo.cnes import render_xml, render_zip
from pec_demo.models import DemoDataset
from pec_demo.validation import CnesReplicaValidator
from pec_demo.xsd import load_cnes_xsd, validate_xml


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def write_generation_artifacts(
    dataset: DemoDataset,
    *,
    output_dir: Path,
    backend_jar: Path,
) -> dict[str, Path]:
    CnesReplicaValidator().validate(dataset).require_valid()
    xml_bytes = render_xml(dataset)
    xsd_bytes = load_cnes_xsd(backend_jar)
    validate_xml(xml_bytes, xsd_bytes)
    zip_bytes = render_zip(xml_bytes)

    output_dir.mkdir(parents=True, exist_ok=True)
    xml_path = output_dir / "cnes-demo.xml"
    zip_path = output_dir / "cnes-demo.zip"
    manifest_path = output_dir / "manifest.json"

    xml_path.write_bytes(xml_bytes)
    zip_path.write_bytes(zip_bytes)

    manifest = {
        "schema_version": 1,
        "generator_version": "0.1.0",
        "pec_version": dataset.pec_version,
        "xsd_version": dataset.xsd_version,
        "seed": dataset.seed,
        "generated_on": dataset.generated_on.isoformat(),
        "municipality_ibge": dataset.municipality_ibge,
        "synthetic_only": True,
        "counts": {
            "units": len(dataset.units),
            "teams": sum(len(unit.teams) for unit in dataset.units),
            "professionals": len(dataset.professionals),
            "assignments": sum(
                len(professional.assignments)
                for professional in dataset.professionals
            ),
        },
        "professionals": [
            {
                "key": item.key,
                "profiles": list(item.planned_profiles),
                "assignment_count": len(item.assignments),
            }
            for item in dataset.professionals
        ],
        "checksums": {
            "xml_sha256": _sha256(xml_bytes),
            "zip_sha256": _sha256(zip_bytes),
            "xsd_sha256": _sha256(xsd_bytes),
            "backend_jar_sha256": _sha256(backend_jar.read_bytes()),
        },
        "status": "generated_not_imported",
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    return {
        "xml": xml_path,
        "zip": zip_path,
        "manifest": manifest_path,
    }
