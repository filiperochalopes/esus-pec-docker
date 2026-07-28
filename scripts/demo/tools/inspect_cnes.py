#!/usr/bin/env python3
"""Inspect CNES XML structure without printing attribute values.

This tool is intentionally metadata-only. It reports tag/attribute counts,
value shapes, checksum validity totals and internal XML references.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from typing import Iterable
import xml.etree.ElementTree as ET
from zipfile import ZipFile


def local_name(name: str) -> str:
    return name.rsplit("}", 1)[-1]


def classify(value: str) -> str:
    if value == "":
        return "empty"
    if re.fullmatch(r"\d+", value):
        return f"digits[{len(value)}]"
    if re.fullmatch(r"\d{2}/\d{2}/\d{4}", value):
        return "date-dd/mm/yyyy"
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return "date-iso"
    if re.fullmatch(r"[A-Z]{2}", value):
        return "two-uppercase"
    return "text"


def cpf_is_valid(value: str) -> bool:
    if len(value) != 11 or not value.isdigit() or len(set(value)) == 1:
        return False
    digits = [int(char) for char in value]
    first = sum(digits[index] * (10 - index) for index in range(9))
    first = (first * 10) % 11
    first = 0 if first == 10 else first
    second = sum(digits[index] * (11 - index) for index in range(10))
    second = (second * 10) % 11
    second = 0 if second == 10 else second
    return digits[9:] == [first, second]


def cnpj_is_valid(value: str) -> bool:
    if len(value) != 14 or not value.isdigit() or len(set(value)) == 1:
        return False
    digits = [int(char) for char in value]

    def check_digit(base: list[int], weights: list[int]) -> int:
        remainder = sum(number * weight for number, weight in zip(base, weights)) % 11
        return 0 if remainder < 2 else 11 - remainder

    first = check_digit(digits[:12], [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
    second = check_digit(
        digits[:12] + [first], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    )
    return digits[12:] == [first, second]


def cns_is_valid(value: str) -> bool:
    if len(value) != 15 or not value.isdigit():
        return False
    return (
        sum(int(char) * weight for char, weight in zip(value, range(15, 0, -1)))
        % 11
        == 0
    )


def xml_path_from_input(input_path: Path, temp_dir: Path) -> Path:
    if input_path.suffix.lower() != ".zip":
        return input_path

    with ZipFile(input_path) as archive:
        xml_entries = [
            entry for entry in archive.infolist() if entry.filename.lower().endswith(".xml")
        ]
        if len(xml_entries) != 1:
            raise ValueError(
                f"expected exactly one XML in ZIP, found {len(xml_entries)}"
            )
        entry = xml_entries[0]
        target = temp_dir / Path(entry.filename).name
        with archive.open(entry) as source, target.open("wb") as destination:
            while chunk := source.read(64 * 1024):
                destination.write(chunk)
        return target


def iter_tag(root: ET.Element, tag_name: str) -> Iterable[ET.Element]:
    return (element for element in root.iter() if local_name(element.tag) == tag_name)


def validate_xsd(xml_path: Path, xsd_path: Path) -> str:
    try:
        from lxml import etree
    except ImportError:
        xmllint = shutil.which("xmllint")
        if xmllint is None:
            return "not-run (install lxml or xmllint)"
        result = subprocess.run(
            [xmllint, "--noout", "--schema", str(xsd_path), str(xml_path)],
            capture_output=True,
            check=False,
            text=True,
        )
        return "valid" if result.returncode == 0 else "invalid"

    schema = etree.XMLSchema(etree.parse(str(xsd_path)))
    document = etree.parse(str(xml_path))
    if schema.validate(document):
        return "valid"
    first_error = schema.error_log.last_error
    if first_error is None:
        return "invalid"
    return f"invalid at line {first_error.line}, column {first_error.column}"


def inspect(xml_path: Path, xsd_path: Path | None) -> None:
    root = ET.parse(xml_path).getroot()
    tag_counts: Counter[str] = Counter()
    child_counts: dict[str, Counter[str]] = defaultdict(Counter)
    attribute_shapes: dict[str, dict[str, Counter[str]]] = defaultdict(
        lambda: defaultdict(Counter)
    )
    attribute_presence: dict[str, Counter[str]] = defaultdict(Counter)
    attribute_unique: dict[str, dict[str, set[str]]] = defaultdict(
        lambda: defaultdict(set)
    )

    for element in root.iter():
        tag = local_name(element.tag)
        tag_counts[tag] += 1
        for child in list(element):
            child_counts[tag][local_name(child.tag)] += 1
        for key, raw_value in element.attrib.items():
            attribute = local_name(key)
            value = raw_value.strip()
            attribute_presence[tag][attribute] += 1
            attribute_shapes[tag][attribute][classify(value)] += 1
            attribute_unique[tag][attribute].add(value)

    print(f"root={local_name(root.tag)}")
    if xsd_path is not None:
        print(f"xsd={validate_xsd(xml_path, xsd_path)}")

    print("\n[tag-counts]")
    for tag, count in sorted(tag_counts.items()):
        print(f"{tag}: {count}")

    print("\n[parent-children]")
    for parent in sorted(child_counts):
        relationships = ", ".join(
            f"{child}:{count}"
            for child, count in sorted(child_counts[parent].items())
        )
        print(f"{parent}: {relationships}")

    print("\n[attribute-shapes]")
    for tag in sorted(attribute_shapes):
        print(f"{tag}:")
        for attribute in sorted(attribute_shapes[tag]):
            shapes = ", ".join(
                f"{shape}:{count}"
                for shape, count in sorted(attribute_shapes[tag][attribute].items())
            )
            present = attribute_presence[tag][attribute]
            unique = len(attribute_unique[tag][attribute])
            print(
                f"  {attribute}: present={present}, unique={unique}, shapes={shapes}"
            )

    units = {
        element.attrib.get("CNES", "")
        for element in iter_tag(root, "DADOS_GERAIS_ESTABELECIMENTOS")
    }
    teams = {
        (unit.attrib.get("CNES", ""), team.attrib.get("CO_INE", ""))
        for unit in iter_tag(root, "DADOS_GERAIS_ESTABELECIMENTOS")
        for team in iter_tag(unit, "DADOS_EQUIPES")
    }
    professionals = list(iter_tag(root, "DADOS_PROFISSIONAIS"))
    assignments = list(iter_tag(root, "DADOS_LOTACOES"))
    assignments_with_team = [
        assignment for assignment in assignments if assignment.attrib.get("CO_INE", "")
    ]
    unit_rows = list(iter_tag(root, "DADOS_GERAIS_ESTABELECIMENTOS"))

    print("\n[checksums-and-references]")
    print(
        "cpf-valid="
        f"{sum(cpf_is_valid(row.attrib.get('CPF_PROF', '')) for row in professionals)}"
        f"/{len(professionals)}"
    )
    print(
        "cns-valid="
        f"{sum(cns_is_valid(row.attrib.get('CO_CNS', '')) for row in professionals)}"
        f"/{len(professionals)}"
    )
    print(
        "cnpj-valid="
        f"{sum(cnpj_is_valid(row.attrib.get('CNPJ', '')) for row in unit_rows)}"
        f"/{len(unit_rows)}"
    )
    print(
        "assignment-cnes-resolves="
        f"{sum(row.attrib.get('CNES', '') in units for row in assignments)}"
        f"/{len(assignments)}"
    )
    print(
        "assignment-cnes-ine-resolves="
        f"{sum((row.attrib.get('CNES', ''), row.attrib.get('CO_INE', '')) in teams for row in assignments_with_team)}"
        f"/{len(assignments_with_team)}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect CNES XML/ZIP metadata without printing values."
    )
    parser.add_argument("input", type=Path, help="CNES XML or ZIP")
    parser.add_argument("--xsd", type=Path, help="optional matching XSD")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.input.is_file():
        print(f"input not found: {args.input}", file=sys.stderr)
        return 2
    if args.xsd is not None and not args.xsd.is_file():
        print(f"XSD not found: {args.xsd}", file=sys.stderr)
        return 2

    try:
        with TemporaryDirectory(prefix="pec-demo-cnes-") as temp:
            xml_path = xml_path_from_input(args.input, Path(temp))
            inspect(xml_path, args.xsd)
    except (ET.ParseError, OSError, ValueError) as error:
        print(f"inspection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
