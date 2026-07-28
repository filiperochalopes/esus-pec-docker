from datetime import date

from pec_demo.clinical import (
    ClinicalAssignment,
    build_encounter_plan,
    build_individual_attendance_input,
    provision_clinical_histories,
)
from pec_demo.patients import build_patient_cohort


def test_encounter_plan_has_medical_and_nursing_markers():
    patient = build_patient_cohort(
        seed=5522, generated_on=date(2026, 7, 27)
    )[0]

    encounters = build_encounter_plan(patient)

    assert [item.role for item in encounters] == ["medico", "enfermagem"]
    assert all("DEMO-SOAP-" in item.subjective for item in encounters)
    assert len({item.key for item in encounters}) == 2


def test_payload_replicates_captured_pec_5522_contract():
    patient = build_patient_cohort(
        seed=5522, generated_on=date(2026, 7, 27)
    )[0]
    encounter = build_encounter_plan(patient)[0]

    payload = build_individual_attendance_input(
        encounter,
        attendance_id="41",
        ciap_id="9",
        automatic_procedure_id="1077",
    )

    assert payload["id"] == "41"
    assert payload["subjetivo"]["texto"].startswith("<p>")
    assert payload["avaliacao"]["problemasCondicoesAvaliadas"] == [
        {"ciapId": "9"}
    ]
    assert payload["finalizacao"]["tipoAtendimento"] == "CONSULTA_NO_DIA"
    assert payload["finalizacao"]["condutas"] == [
        "RETORNO_PARA_CUIDADO_CONTINUADO_PROGRAMADO"
    ]
    assert payload["finalizacao"]["procedimentosAdministrativos"] == [
        {"id": "1077", "automatico": True}
    ]


class FakeClinicalClient:
    def __init__(self, patients):
        self.patient_ids = {
            patient.cpf: str(index)
            for index, patient in enumerate(patients, start=1)
        }
        self.selected = []
        self.saved = []

    def citizen_by_cpf(self, cpf):
        return {"id": self.patient_ids[cpf]}

    def select_assignment_access(self, *, cnes, cbo2002):
        self.selected.append((cnes, cbo2002))

    def automatic_procedure_id(self, code):
        return {"0301010064": "1077", "0301010030": "1074"}[code]

    def ciap_id(self, code, *, sex, age):
        assert code == "A98"
        return "9"

    def save_attendance(self, citizen_id):
        return {"id": str(len(self.saved) + 1)}

    def start_individual_attendance(self, attendance_id):
        return {"atendimentoProfissional": {"id": attendance_id}}

    def save_individual_attendance(self, input_data):
        self.saved.append(input_data)
        return {"atendProf": {"id": input_data["id"]}}


def test_provision_histories_is_manifest_idempotent(tmp_path):
    patients = build_patient_cohort(
        seed=5522, generated_on=date(2026, 7, 27)
    )[:2]
    client = FakeClinicalClient(patients)
    assignments = (
        ClinicalAssignment("medico", "1111111", "225130", "0301010064"),
        ClinicalAssignment("enfermagem", "2222222", "223505", "0301010030"),
    )
    manifest = tmp_path / "clinical.json"

    first = provision_clinical_histories(
        patients,
        client=client,
        assignments=assignments,
        reference_date=date(2026, 7, 27),
        manifest_path=manifest,
    )
    second = provision_clinical_histories(
        patients,
        client=client,
        assignments=assignments,
        reference_date=date(2026, 7, 27),
        manifest_path=manifest,
    )

    assert len(first) == len(second) == 4
    assert len(client.saved) == 4
    assert len({item.key for item in first}) == 4
