"""Load the exact CNES 3.1 XSD from a PEC backend JAR."""

from __future__ import annotations

from pathlib import Path
import shutil
from tempfile import SpooledTemporaryFile
from zipfile import BadZipFile, ZipFile

from lxml import etree


XSD_ENTRY = "cnes/cnes_3.1.xsd"


def load_cnes_xsd(jar_path: Path) -> bytes:
    """Find cnes_3.1.xsd in a backend, bundle, or outer installer JAR."""
    try:
        with ZipFile(jar_path) as archive:
            result = _load_from_archive(archive, depth=0)
    except (BadZipFile, OSError) as error:
        raise ValueError(f"invalid PEC JAR: {jar_path}") from error
    if result is None:
        raise ValueError(f"{XSD_ENTRY} not found in {jar_path}")
    return result


def _load_from_archive(archive: ZipFile, depth: int) -> bytes | None:
    names = archive.namelist()
    direct = next((name for name in names if name.endswith(XSD_ENTRY)), None)
    if direct is not None:
        return archive.read(direct)
    if depth >= 2:
        return None

    nested = [
        name
        for name in names
        if name.endswith(".jar")
        and (
            "/backend-" in name
            or name.endswith("backend.jar")
            or name.endswith("pec-bundle.jar")
        )
    ]
    nested.sort(key=lambda name: ("backend-" not in name, name))
    for name in nested:
        try:
            with SpooledTemporaryFile(max_size=16 * 1024 * 1024) as nested_file:
                with archive.open(name) as source:
                    shutil.copyfileobj(source, nested_file, length=1024 * 1024)
                nested_file.seek(0)
                with ZipFile(nested_file) as child:
                    result = _load_from_archive(child, depth + 1)
        except BadZipFile:
            continue
        if result is not None:
            return result
    return None


def validate_xml(xml_bytes: bytes, xsd_bytes: bytes) -> None:
    """Raise ValueError with the first XSD violation."""
    try:
        schema_document = etree.fromstring(xsd_bytes)
        schema = etree.XMLSchema(schema_document)
        document = etree.fromstring(xml_bytes)
        schema.assertValid(document)
    except (etree.XMLSyntaxError, etree.DocumentInvalid) as error:
        last = error.error_log.last_error
        location = ""
        if last is not None:
            location = f" at line {last.line}, column {last.column}"
        raise ValueError(f"CNES XML is invalid{location}: {error}") from error
