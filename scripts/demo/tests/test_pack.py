from __future__ import annotations

from datetime import date

import json

from pec_demo.clinical import build_encounter_plan
from pec_demo.pack import refresh_demo_pack, validate_demo_pack
from pec_demo.patients import build_patient_cohort


class FakeImporter:
    def __init__(self, *_args, **_kwargs):
        self.professional = None

    def login(self, username, password):
        self.professional = (username, password)

    def select_general_admin_access(self):
        return {"id": "1", "tipo": "ADMINISTRADOR_GERAL"}

    def municipality_id_by_ibge(self, ibge, *, query):
        assert ibge == "2927408"
        assert query == "SALVADOR"
        return "1088"

    def import_cnes_and_wait(self, archive, *, municipality_id):
        assert archive.name == "cnes.zip"
        assert municipality_id == "1088"
        return {
            "id": "7",
            "unidadesSaudeNovas": 0,
            "unidadesSaudeAtualizadas": 2,
            "equipesNovas": 0,
            "equipesAtualizadas": 2,
            "profissionaisNovos": 0,
            "profissionaisAtualizados": 3,
            "lotacoesNovas": 0,
            "lotacoesAtualizadas": 4,
        }


class FakeClinicalClient:
    def __init__(self, *_args, **_kwargs):
        pass

    def login(self, *_args, **_kwargs):
        pass


class FakeValidationClient:
    citizens = {}
    attendances = {}

    def __init__(self, *_args, **_kwargs):
        pass

    def login(self, *_args, **_kwargs):
        pass

    def select_assignment_access(self, **_kwargs):
        return {}

    def citizen_by_cpf(self, cpf):
        return self.citizens.get(cpf)

    def individual_attendance(self, attendance_id):
        return self.attendances[attendance_id]


def test_refresh_pack_orchestrates_all_stages(monkeypatch, tmp_path):
    monkeypatch.setattr("pec_demo.pack.PecGraphQLClient", FakeImporter)
    monkeypatch.setattr(
        "pec_demo.pack.provision_demo_credentials",
        lambda *_args, **_kwargs: (
            type("Credential", (), {"assignments": (1, 2)})(),
            type("Credential", (), {"assignments": (1,)})(),
            type("Credential", (), {"assignments": (1,)})(),
        ),
    )
    monkeypatch.setattr(
        "pec_demo.pack.provision_citizens",
        lambda *_args, **_kwargs: tuple(
            type("Citizen", (), {"created": False})() for _ in range(10)
        ),
    )
    monkeypatch.setattr(
        "pec_demo.pack.provision_clinical_histories",
        lambda *_args, **_kwargs: tuple(range(60)),
    )
    archive = tmp_path / "cnes.zip"
    archive.write_bytes(b"zip")

    result = refresh_demo_pack(
        base_url="http://pec",
        cnes_archive=archive,
        credentials_path=tmp_path / "credentials.txt",
        clinical_manifest_path=tmp_path / "clinical.json",
        municipality_ibge="2927408",
        municipality_name="SALVADOR",
        uf="BA",
        cep="40000000",
        seed=5522,
        generated_on=date(2026, 7, 27),
        pec_version="5.5.22",
    )

    assert result.cnes_import_id == "7"
    assert result.credentials == 3
    assert result.assignments == 4
    assert result.patients == 10
    assert result.patients_created == 0
    assert result.histories == 60


def test_validate_pack_checks_all_patients_and_soap(monkeypatch, tmp_path):
    generated_on = date(2026, 7, 27)
    cohort = build_patient_cohort(seed=5522, generated_on=generated_on)
    encounters = {}
    FakeValidationClient.citizens = {
        patient.cpf: {"id": str(index), "nome": patient.name}
        for index, patient in enumerate(cohort, start=1)
    }
    FakeValidationClient.attendances = {}
    attendance_id = 1
    for patient in cohort:
        for plan in build_encounter_plan(patient):
            identifier = str(attendance_id)
            encounters[plan.key] = {
                "attendance_professional_id": identifier,
            }
            FakeValidationClient.attendances[identifier] = {
                "finalizadoEm": "2026-07-27T12:00:00",
                "atendimento": {
                    "cidadao": {"id": FakeValidationClient.citizens[patient.cpf]["id"]}
                },
                "evolucaoSubjetivo": {"descricao": f"<p>{plan.subjective}</p>"},
                "evolucaoObjetivo": {"descricao": f"<p>{plan.objective}</p>"},
                "evolucaoAvaliacao": {"descricao": f"<p>{plan.assessment}</p>"},
                "evolucaoPlano": {"descricao": f"<p>{plan.plan}</p>"},
            }
            attendance_id += 1
    manifest = tmp_path / "clinical.json"
    manifest.write_text(
        json.dumps({"version": 4, "encounters": encounters}),
        encoding="utf-8",
    )
    monkeypatch.setattr("pec_demo.pack.PecGraphQLClient", FakeValidationClient)
    monkeypatch.setattr(
        "pec_demo.pack.validate_demo_credentials",
        lambda *_args, **_kwargs: (
            type("Credential", (), {"assignments": (1, 2)})(),
            type("Credential", (), {"assignments": (1,)})(),
            type("Credential", (), {"assignments": (1,)})(),
        ),
    )

    result = validate_demo_pack(
        base_url="http://pec",
        clinical_manifest_path=manifest,
        municipality_ibge="2927408",
        uf="BA",
        cep="40000000",
        seed=5522,
        generated_on=generated_on,
        pec_version="5.5.22",
    )

    assert result.credentials == 3
    assert result.assignments == 4
    assert result.patients == 10
    assert result.histories == 60
