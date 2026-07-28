from __future__ import annotations

from random import Random

from validate_docbr import CNPJ, CNS, CPF

from pec_demo.identifiers import generate_cnpj, generate_cns, generate_cpf


def test_document_generators_are_deterministic_and_valid():
    first = Random(5522)
    second = Random(5522)

    values_1 = (
        generate_cpf(first),
        generate_cnpj(first),
        generate_cns(first),
    )
    values_2 = (
        generate_cpf(second),
        generate_cnpj(second),
        generate_cns(second),
    )

    assert values_1 == values_2
    assert CPF().validate(values_1[0])
    assert CNPJ().validate(values_1[1])
    assert CNS().validate(values_1[2])
    assert values_1[2].startswith("7")


def test_generated_documents_are_unformatted():
    rng = Random(10)

    assert generate_cpf(rng).isdigit()
    assert generate_cnpj(rng).isdigit()
    assert generate_cns(rng).isdigit()
