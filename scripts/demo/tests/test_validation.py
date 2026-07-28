from __future__ import annotations

from dataclasses import replace

import pytest

from pec_demo.models import Assignment
from pec_demo.validation import CnesReplicaValidator


def issue_codes(report):
    return {issue.code for issue in report.issues}


def test_valid_dataset_mirrors_pec_business_rules(dataset):
    report = CnesReplicaValidator().validate(dataset)

    assert report.is_valid, report.issues


@pytest.mark.parametrize(
    ("field", "value", "expected_code"),
    (
        ("cnpj", "00000000000000", "cnpj"),
        ("unit_type_code", "999", "catalog"),
    ),
)
def test_unit_validator_rejects_invalid_values(dataset, field, value, expected_code):
    bad_unit = replace(dataset.units[0], **{field: value})
    invalid = replace(dataset, units=(bad_unit, dataset.units[1]))

    assert expected_code in issue_codes(CnesReplicaValidator().validate(invalid))


def test_unit_must_belong_to_import_municipality(dataset):
    bad_address = replace(dataset.units[0].address, municipality_ibge="3550308")
    bad_unit = replace(dataset.units[0], address=bad_address)
    invalid = replace(dataset, units=(bad_unit, dataset.units[1]))

    assert "municipality" in issue_codes(CnesReplicaValidator().validate(invalid))


def test_professional_validator_rejects_invalid_cpf_and_cns(dataset):
    bad_professional = replace(
        dataset.professionals[0],
        cpf="00000000000",
        cns="000000000000000",
    )
    invalid = replace(
        dataset,
        professionals=(bad_professional, *dataset.professionals[1:]),
    )

    codes = issue_codes(CnesReplicaValidator().validate(invalid))
    assert {"cpf", "cns"} <= codes


def test_assignment_requires_resolvable_cnes_ine_and_cbo(dataset):
    bad_assignment = Assignment(
        cnes=dataset.units[0].cnes,
        ine=dataset.units[1].teams[0].ine,
        cbo="999999",
    )
    bad_professional = replace(
        dataset.professionals[0],
        assignments=(bad_assignment, dataset.professionals[0].assignments[1]),
    )
    invalid = replace(
        dataset,
        professionals=(bad_professional, *dataset.professionals[1:]),
    )

    codes = issue_codes(CnesReplicaValidator().validate(invalid))
    assert {"ine-reference", "cbo-catalog"} <= codes


def test_team_deactivation_date_matches_java_parser_contract(dataset):
    bad_team = replace(dataset.units[0].teams[0], deactivation_date="2026/07/27")
    bad_unit = replace(dataset.units[0], teams=(bad_team,))
    invalid = replace(dataset, units=(bad_unit, dataset.units[1]))

    assert "date" in issue_codes(CnesReplicaValidator().validate(invalid))
