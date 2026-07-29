import csv
from datetime import date

from pec_demo.patient_index import write_patient_index
from pec_demo.patients import build_patient_cohort


def test_patient_index_has_one_safe_summary_row_per_patient(tmp_path):
    cohort = build_patient_cohort(seed=5522, generated_on=date(2026, 7, 27))
    path = tmp_path / "patients.csv"

    write_patient_index(cohort, path)

    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    assert len(rows) == 10
    assert all(row["historia_resumida"] for row in rows)
    assert all(row["problemas_em_aberto"] for row in rows)
    assert "cpf" not in rows[0]
    assert "cns" not in rows[0]
    chronic = next(row for row in rows if row["idade"] == "48")
    assert "Losartana" in chronic["medicacoes_uso_continuo"]
    assert "Metformina" in chronic["medicacoes_uso_continuo"]
