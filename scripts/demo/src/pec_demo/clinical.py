"""Provision deterministic SOAP histories through PEC's official mutations."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import date
from html import escape
import json
import os
from pathlib import Path
import tempfile
from typing import Any

from pec_demo.patients import SyntheticPatient
from pec_demo.pec_client import PecClientError, PecGraphQLClient


DOCTOR_CBO = "225130"
NURSE_CBO = "223505"
DOCTOR_PROCEDURE = "0301010064"
NURSE_PROCEDURE = "0301010030"
PREVENTIVE_CIAP = "A98"


@dataclass(frozen=True, slots=True)
class ClinicalAssignment:
    role: str
    cnes: str
    cbo2002: str
    automatic_procedure_code: str


@dataclass(frozen=True, slots=True)
class PlannedEncounter:
    key: str
    patient_key: str
    role: str
    subjective: str
    objective: str
    assessment: str
    plan: str


@dataclass(frozen=True, slots=True)
class ProvisionedEncounter:
    key: str
    patient_key: str
    role: str
    citizen_id: str
    attendance_id: str
    attendance_professional_id: str


def _age_on(birth_date: date, reference: date) -> int:
    return reference.year - birth_date.year - (
        (reference.month, reference.day) < (birth_date.month, birth_date.day)
    )


def build_encounter_plan(patient: SyntheticPatient) -> tuple[PlannedEncounter, ...]:
    """Build one medical and one nursing encounter for a life-course scenario."""
    marker = patient.key.upper().replace("_", "-")
    context = patient.scenario
    return (
        PlannedEncounter(
            key=f"{patient.key}:medico",
            patient_key=patient.key,
            role="medico",
            subjective=(
                f"Paciente ou responsável descreve evolução relacionada a {context}, "
                f"sem sinais de alarme no momento. DEMO-SOAP-{marker}-MED."
            ),
            objective=(
                f"Avaliação clínica sintética compatível com a faixa etária; estado "
                "geral preservado, hidratado, corado e eupneico."
            ),
            assessment=(
                f"Acompanhamento integral de {context}; cenário exclusivamente "
                "sintético para treinamento e validação funcional."
            ),
            plan=(
                "Orientações individualizadas, sinais de alarme, promoção da saúde "
                "e retorno programado na Atenção Primária."
            ),
        ),
        PlannedEncounter(
            key=f"{patient.key}:enfermagem",
            patient_key=patient.key,
            role="enfermagem",
            subjective=(
                f"Em seguimento de enfermagem, relata adesão às orientações sobre "
                f"{context}. DEMO-SOAP-{marker}-ENF."
            ),
            objective=(
                "Reavaliação sintética de enfermagem: condição estável, comunicação "
                "adequada e ausência de intercorrências agudas."
            ),
            assessment=(
                f"Necessidade de continuidade do cuidado para {context}, com foco "
                "em autocuidado e vigilância de riscos."
            ),
            plan=(
                "Educação em saúde, reforço de adesão, prevenção, atualização de "
                "cuidados e retorno longitudinal com a equipe."
            ),
        ),
    )


def _html_paragraph(value: str) -> str:
    return f"<p>{escape(value, quote=False)}</p>"


def build_individual_attendance_input(
    encounter: PlannedEncounter,
    *,
    attendance_id: str,
    ciap_id: str,
    automatic_procedure_id: str,
) -> dict[str, Any]:
    """Replicate the 5.5.22 web client's validated minimal SOAP payload."""
    return {
        "id": str(attendance_id),
        "antecedentes": {
            "pessoal": {
                "puericultura": {},
                "informacoesObstetricas": {
                    "desfechoUltimaGestacao": "NAO_INFORMADO"
                },
                "cirurgiasInternacoes": [],
            },
            "familiar": {},
        },
        "subjetivo": {"texto": _html_paragraph(encounter.subjective)},
        "objetivo": {
            "texto": _html_paragraph(encounter.objective),
            "medicoes": {"vacinacaoEmDia": True, "exameFisico": None},
            "puericultura": None,
        },
        "avaliacao": {
            "texto": _html_paragraph(encounter.assessment),
            "problemasCondicoesAvaliadas": [{"ciapId": str(ciap_id)}],
            "alergiasAvaliadas": [],
            "vigilanciaSaudeBucal": None,
        },
        "plano": {
            "texto": _html_paragraph(encounter.plan),
            "procedimentos": [],
            "prescricaoMedicamento": None,
            "compartilhamentosCuidado": None,
        },
        "finalizacao": {
            "tipoAtendimento": "CONSULTA_NO_DIA",
            "procedimentosAdministrativos": [
                {"id": str(automatic_procedure_id), "automatico": True}
            ],
            "condutas": ["RETORNO_PARA_CUIDADO_CONTINUADO_PROGRAMADO"],
            "desfechoAtendimento": {"manterCidadaoLista": False},
            "agendamentoConsultas": {
                "enviarComprovantesParaCidadao": False
            },
            "tipoParticipacaoCidadao": "PRESENCIAL",
            "tipoParticipacaoProfissionalConvidado": "NAO_PARTICIPOU",
        },
        "medicoesAnteriores": [],
        "lembretes": [],
        "registrosVacinacao": [],
        "problemasECondicoes": [],
    }


def _load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": 1, "encounters": {}}
    try:
        content = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PecClientError(f"invalid clinical manifest {path}: {error}") from error
    if content.get("version") != 1 or not isinstance(
        content.get("encounters"), dict
    ):
        raise PecClientError(f"unsupported clinical manifest {path}")
    return content


def _write_manifest(path: Path, content: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(content, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def provision_clinical_histories(
    patients: tuple[SyntheticPatient, ...],
    *,
    client: PecGraphQLClient,
    assignments: tuple[ClinicalAssignment, ...],
    reference_date: date,
    manifest_path: Path,
) -> tuple[ProvisionedEncounter, ...]:
    """Create two verified, finalized SOAP encounters per synthetic citizen."""
    by_role = {assignment.role: assignment for assignment in assignments}
    if set(by_role) != {"medico", "enfermagem"}:
        raise PecClientError("clinical assignments must include medico and enfermagem")

    # Citizen lookup is protected by an operational access. Select the medical
    # assignment before resolving the cohort, then switch per encounter group.
    doctor = by_role["medico"]
    client.select_assignment_access(cnes=doctor.cnes, cbo2002=doctor.cbo2002)
    citizens: dict[str, str] = {}
    for patient in patients:
        citizen = client.citizen_by_cpf(patient.cpf)
        if not citizen:
            raise PecClientError(
                f"synthetic citizen {patient.key} must be provisioned first"
            )
        citizens[patient.key] = str(citizen["id"])

    manifest = _load_manifest(manifest_path)
    results = []
    for role in ("medico", "enfermagem"):
        assignment = by_role[role]
        client.select_assignment_access(
            cnes=assignment.cnes,
            cbo2002=assignment.cbo2002,
        )
        procedure_id = client.automatic_procedure_id(
            assignment.automatic_procedure_code
        )
        for patient in patients:
            encounter = next(
                item for item in build_encounter_plan(patient) if item.role == role
            )
            previous = manifest["encounters"].get(encounter.key)
            if previous:
                results.append(ProvisionedEncounter(**previous))
                continue
            ciap_id = client.ciap_id(
                PREVENTIVE_CIAP,
                sex="FEMININO" if patient.sex == "F" else "MASCULINO",
                age=_age_on(patient.birth_date, reference_date),
            )
            attendance = client.save_attendance(citizens[patient.key])
            attendance_id = str(attendance["id"])
            started = client.start_individual_attendance(attendance_id)
            finalized = client.save_individual_attendance(
                build_individual_attendance_input(
                    encounter,
                    attendance_id=attendance_id,
                    ciap_id=ciap_id,
                    automatic_procedure_id=procedure_id,
                )
            )
            result = ProvisionedEncounter(
                key=encounter.key,
                patient_key=patient.key,
                role=role,
                citizen_id=citizens[patient.key],
                attendance_id=attendance_id,
                attendance_professional_id=str(finalized["atendProf"]["id"]),
            )
            started_id = str(started["atendimentoProfissional"]["id"])
            if result.attendance_professional_id != started_id:
                raise PecClientError(
                    f"professional attendance changed while finalizing {encounter.key}"
                )
            manifest["encounters"][encounter.key] = asdict(result)
            _write_manifest(manifest_path, manifest)
            results.append(result)
    return tuple(results)
