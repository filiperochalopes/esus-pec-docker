from datetime import date

from validate_docbr import CNS, CPF

from pec_demo.patients import build_patient_cohort


def test_patient_cohort_is_deterministic_and_life_course_diverse():
    first = build_patient_cohort(seed=5522, generated_on=date(2026, 7, 27))
    second = build_patient_cohort(seed=5522, generated_on=date(2026, 7, 27))

    assert first == second
    assert len(first) == 10
    ages = {2026 - item.birth_date.year for item in first}
    assert min(ages) == 0
    assert max(ages) >= 90
    assert {item.sex for item in first} == {"F", "M"}
    assert len({item.race for item in first}) >= 4
    assert all(CPF().validate(item.cpf) for item in first)
    assert all(CNS().validate(item.cns) for item in first)
