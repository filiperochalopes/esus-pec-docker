"""Human-readable index for choosing synthetic patients during demos."""

from __future__ import annotations

import csv
from pathlib import Path

from pec_demo.clinical import build_encounter_plan
from pec_demo.patients import SyntheticPatient


def write_patient_index(
    patients: tuple[SyntheticPatient, ...],
    output_path: Path,
) -> None:
    """Write one row per synthetic patient without CPF, CNS or address."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fields = (
        "paciente",
        "idade",
        "sexo",
        "cenario",
        "atendimentos",
        "historia_resumida",
        "problemas_em_aberto",
        "problemas_resolvidos",
        "medicacoes_uso_continuo",
        "consultas_sem_medicoes",
        "consultas_sem_cid10",
        "consultas_sem_prescricao",
    )
    with output_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for patient in patients:
            encounters = build_encounter_plan(patient)
            tracked: list[str] = []
            resolved: list[str] = []
            continuous_medications: list[str] = []
            for encounter in encounters:
                for code in encounter.resolve_cid10_codes:
                    if code not in resolved:
                        resolved.append(code)
                if (
                    encounter.cid10_code
                    and encounter.include_problem
                    and encounter.cid10_code not in tracked
                ):
                    tracked.append(encounter.cid10_code)
                for prescription in encounter.prescriptions:
                    if (
                        prescription.continuous_use
                        and prescription.medication_query not in continuous_medications
                    ):
                        continuous_medications.append(prescription.medication_query)
            active = [code for code in tracked if code not in resolved]
            history = (
                f"{patient.scenario}; {len(encounters)} atendimentos; "
                f"{len(active)} problema(s) em aberto, "
                f"{len(resolved)} resolvido(s); "
                f"{len(continuous_medications)} medicamento(s) contínuo(s)."
            )
            writer.writerow(
                {
                    "paciente": patient.name,
                    "idade": patient.age_years,
                    "sexo": patient.sex,
                    "cenario": patient.scenario,
                    "atendimentos": len(encounters),
                    "historia_resumida": history,
                    "problemas_em_aberto": "; ".join(active),
                    "problemas_resolvidos": "; ".join(resolved),
                    "medicacoes_uso_continuo": "; ".join(continuous_medications),
                    "consultas_sem_medicoes": sum(
                        not item.measurements for item in encounters
                    ),
                    "consultas_sem_cid10": sum(
                        item.cid10_code is None for item in encounters
                    ),
                    "consultas_sem_prescricao": sum(
                        not item.prescriptions for item in encounters
                    ),
                }
            )
