"""Deterministic, age-diverse synthetic patient cohort."""

from __future__ import annotations

from calendar import monthrange
from dataclasses import dataclass
from datetime import date
from random import Random
import unicodedata

from faker import Faker

from pec_demo.identifiers import generate_cns, generate_cpf


@dataclass(frozen=True, slots=True)
class SyntheticPatient:
    key: str
    name: str
    cpf: str
    cns: str
    birth_date: date
    sex: str
    mother_name: str
    father_name: str
    phone: str
    race: str
    scenario: str


def _letters(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value)
    return " ".join(
        "".join(
            character
            for character in normalized
            if character.isalpha() or character.isspace()
        ).upper().split()
    )


def _subtract_years(value: date, years: int) -> date:
    year = value.year - years
    day = min(value.day, monthrange(year, value.month)[1])
    return value.replace(year=year, day=day)


def build_patient_cohort(
    *,
    seed: int,
    generated_on: date,
) -> tuple[SyntheticPatient, ...]:
    """Return ten representative life-course patients."""
    rng = Random(seed ^ 0xC1DADA0)
    fake = Faker("pt_BR")
    fake.seed_instance(seed ^ 0xA7E0D)
    archetypes = (
        ("lactente", 0, "F", "BRANCA", "puericultura e aleitamento"),
        ("pre_escolar", 4, "M", "PARDA", "infeccao respiratoria aguda"),
        ("escolar", 10, "F", "PRETA", "asma e acompanhamento escolar"),
        ("adolescente", 16, "M", "PARDA", "saude do adolescente"),
        ("adulta_jovem", 24, "F", "AMARELA", "planejamento reprodutivo"),
        ("adulto", 35, "M", "BRANCA", "dor lombar e atividade laboral"),
        ("meia_idade", 48, "F", "PARDA", "hipertensao e diabetes"),
        ("idoso_jovem", 62, "M", "PRETA", "risco cardiovascular"),
        ("idosa", 76, "F", "BRANCA", "polifarmacia e prevencao de quedas"),
        ("longevo", 91, "M", "PARDA", "fragilidade e cuidado longitudinal"),
    )
    patients = []
    for index, (key, age, sex, race, scenario) in enumerate(archetypes):
        birthday = _subtract_years(generated_on, age)
        if age:
            birthday = birthday.replace(
                month=((index * 3 + 1) % 12) + 1,
                day=min(5 + index, monthrange(birthday.year, ((index * 3 + 1) % 12) + 1)[1]),
            )
        name = _letters(fake.name_female() if sex == "F" else fake.name_male())
        mother = _letters(fake.name_female())
        father = _letters(fake.name_male())
        patients.append(
            SyntheticPatient(
                key=key,
                name=f"PACIENTE DEMO {name}",
                cpf=generate_cpf(rng),
                cns=generate_cns(rng),
                birth_date=birthday,
                sex=sex,
                mother_name=f"MAE DEMO {mother}",
                father_name=f"PAI DEMO {father}",
                phone=f"719{rng.randrange(10_000_000, 100_000_000):08d}",
                race=race,
                scenario=scenario,
            )
        )
    return tuple(patients)
