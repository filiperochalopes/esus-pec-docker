"""Create the synthetic citizen cohort through PEC's official mutation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from pec_demo.patients import SyntheticPatient
from pec_demo.pec_client import PecClientError, PecGraphQLClient


@dataclass(frozen=True, slots=True)
class ProvisionedCitizen:
    patient: SyntheticPatient
    pec_id: str
    created: bool


def _citizen_input(
    patient: SyntheticPatient,
    *,
    municipality_id: str,
    professional_cns: str,
    cnes: str,
    ine: str,
    cbo2002: str,
) -> dict[str, Any]:
    return {
        "nome": patient.name,
        "sexo": "FEMININO" if patient.sex == "F" else "MASCULINO",
        "dataNascimento": patient.birth_date.isoformat(),
        "cpf": patient.cpf,
        "cns": patient.cns,
        "stNaoPossuiCpf": False,
        "justificativaNaoPossuiCpf": None,
        "racaCor": patient.race,
        "nacionalidade": "BRASILEIRA",
        "municipioNascimento": municipality_id,
        "dataEntradaPais": None,
        "paisNascimento": "31",
        "dataNaturalizacao": None,
        "portariaNaturalizacao": None,
        "nomePai": patient.father_name,
        "nomeMae": patient.mother_name,
        "desejaInformarOrientacaoSexual": False,
        "identidadeGenero": None,
        "desejaInformarIdentidadeGenero": False,
        "orientacaoSexual": None,
        "vinculacaoCidadaoTerritorio": {
            "cbo2002": cbo2002,
            "cnes": cnes,
            "cns": professional_cns,
            "ine": ine,
        },
        "vinculacaoCidadaoFamilia": {"isResponsavelFamiliar": False},
        "telefoneCelular": patient.phone,
        "endereco": None,
        "paisResidenciaId": "31",
        "informacoesSocioEconomicas": None,
        "informacoesSociodemograficas": None,
        "condicoesSaudeAutorreferidas": None,
        "stCompartilhaProntuario": True,
        "stSituacaoDeRua": False,
        "situacaoDeRua": None,
        "isCidadaoAldeado": False,
        "cidadaoAldeadoInput": None,
        "tipoEndereco": "LOGRADOURO",
        "numeroFamilia": None,
    }


def provision_citizens(
    patients: tuple[SyntheticPatient, ...],
    *,
    client: PecGraphQLClient,
    municipality_ibge: str,
    municipality_name: str,
    cnes: str,
    ine: str,
    cbo2002: str = "225130",
) -> tuple[ProvisionedCitizen, ...]:
    """Idempotently create ten citizens and verify each by synthetic CPF."""
    access = client.select_assignment_access(cnes=cnes, cbo2002=cbo2002)
    session = client.session()
    professional_cns = session["profissional"].get("cns")
    if not professional_cns:
        raise PecClientError("authenticated professional has no CNS")
    team = access.get("equipe") or {}
    if team.get("ine") != ine:
        raise PecClientError(
            f"selected assignment has INE {team.get('ine')}, expected {ine}"
        )
    municipality_id = client.municipality_id_by_ibge(
        municipality_ibge,
        query=municipality_name,
    )
    results = []
    for patient in patients:
        existing = client.citizen_by_cpf(patient.cpf)
        if existing:
            if existing.get("nome") != patient.name:
                raise PecClientError(
                    f"CPF collision for synthetic patient {patient.key}"
                )
            results.append(
                ProvisionedCitizen(patient, str(existing["id"]), created=False)
            )
            continue
        saved = client.save_citizen(
            _citizen_input(
                patient,
                municipality_id=municipality_id,
                professional_cns=professional_cns,
                cnes=cnes,
                ine=ine,
                cbo2002=cbo2002,
            )
        )
        verified = client.citizen_by_cpf(patient.cpf)
        if not verified or str(verified["id"]) != str(saved["id"]):
            raise PecClientError(f"could not verify saved citizen {patient.key}")
        results.append(
            ProvisionedCitizen(patient, str(saved["id"]), created=True)
        )
    return tuple(results)
