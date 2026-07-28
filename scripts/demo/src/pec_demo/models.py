"""Typed in-memory contract for a synthetic CNES import."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date


@dataclass(frozen=True, slots=True)
class Address:
    cep: str
    uf: str
    municipality_ibge: str
    neighborhood: str
    street: str
    number: str
    complement: str = ""
    reference: str = ""


@dataclass(frozen=True, slots=True)
class Team:
    ine: str
    type_code: str
    abbreviation: str
    description: str
    area_code: str
    area_description: str
    reference_name: str
    home_care_type: str = ""
    deactivation_date: str = ""


@dataclass(frozen=True, slots=True)
class HealthUnit:
    name: str
    cnpj: str
    cnes: str
    unit_type_code: str
    unit_type_description: str
    address: Address
    complexities: tuple[str, ...] = ("AB",)
    teams: tuple[Team, ...] = ()
    subtype_code: str = ""
    subtype_description: str = ""
    phone_1: str = ""
    phone_2: str = ""
    fax: str = ""
    email: str = ""


@dataclass(frozen=True, slots=True)
class Assignment:
    cnes: str
    cbo: str
    ine: str = ""
    microarea: str = ""


@dataclass(frozen=True, slots=True)
class Professional:
    key: str
    name: str
    cpf: str
    cns: str
    birth_date: date
    sex: str
    assignments: tuple[Assignment, ...]
    planned_profiles: tuple[str, ...]
    planned_password: str = field(repr=False)
    council_id: str = ""
    council_uf: str = ""
    council_registration: str = ""
    email: str = ""
    phone: str = ""


@dataclass(frozen=True, slots=True)
class DemoDataset:
    seed: int
    pec_version: str
    generated_on: date
    municipality_ibge: str
    uf: str
    units: tuple[HealthUnit, ...]
    professionals: tuple[Professional, ...]
    xsd_version: str = "3.1"
    origin: str = "PORTAL"
    destination: str = "ESUS_AB"
