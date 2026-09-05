from __future__ import annotations

from datetime import date

from pec_demo.factory import build_demo_dataset


def test_factory_is_deterministic():
    kwargs = {
        "seed": 5522,
        "municipality_ibge": "2927408",
        "uf": "BA",
        "cep": "40000000",
        "generated_on": date(2026, 7, 27),
    }

    assert build_demo_dataset(**kwargs) == build_demo_dataset(**kwargs)


def test_factory_has_the_required_diversity(dataset):
    assert len(dataset.units) == 2
    assert sum(len(unit.teams) for unit in dataset.units) == 2
    assert len(dataset.professionals) == 3
    assert sum(len(item.assignments) for item in dataset.professionals) == 4
    assert any(len(item.assignments) == 2 for item in dataset.professionals)

    cbos = {
        assignment.cbo
        for professional in dataset.professionals
        for assignment in professional.assignments
    }
    assert cbos == {"225130", "223505"}
    assert all("DEMO" in item.name for item in dataset.professionals)
    assert all(
        all(character.isalpha() or character.isspace() for character in item.name)
        for item in dataset.professionals
    )


def test_factory_uses_canonical_cnes_basic_health_unit_type(dataset):
    assert all(unit.unit_type_code == "2" for unit in dataset.units)
    assert all(
        unit.unit_type_description == "CENTRO DE SAUDE/UNIDADE BASICA"
        for unit in dataset.units
    )


def test_professionals_have_a_deterministic_demo_email(dataset):
    assert all(
        professional.email == f"{professional.key}@demo.pec.br"
        for professional in dataset.professionals
    )


def test_multiprofile_professional_covers_login_scenarios(dataset):
    multiprofile = next(item for item in dataset.professionals if item.key == "multiprofile")

    assert set(multiprofile.planned_profiles) == {
        "INSTALADOR",
        "ADMINISTRADOR_MUNICIPAL",
        "MEDICO",
        "ENFERMEIRO",
    }
    assert len({item.cnes for item in multiprofile.assignments}) == 2
    assert len({item.cbo for item in multiprofile.assignments}) == 2


def test_planned_password_does_not_reuse_demo_name_token(dataset):
    assert all(
        "demo" not in professional.planned_password.casefold()
        for professional in dataset.professionals
    )
