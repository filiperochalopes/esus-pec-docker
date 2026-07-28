"""Deterministic identifiers with independent checksum verification."""

from __future__ import annotations

from random import Random

from validate_docbr import CNPJ, CNS, CPF


_cpf_validator = CPF()
_cnpj_validator = CNPJ()
_cns_validator = CNS()


def _cpf_digit(base: list[int], factor: int) -> int:
    total = sum(digit * weight for digit, weight in zip(base, range(factor, 1, -1)))
    remainder = (total * 10) % 11
    return 0 if remainder == 10 else remainder


def generate_cpf(rng: Random) -> str:
    """Generate an unformatted CPF and verify it with validate-docbr."""
    while True:
        digits = [rng.randrange(10) for _ in range(9)]
        if len(set(digits)) != 1:
            break
    digits.append(_cpf_digit(digits, 10))
    digits.append(_cpf_digit(digits, 11))
    value = "".join(map(str, digits))
    if not _cpf_validator.validate(value):
        raise AssertionError("internal CPF generator produced an invalid value")
    return value


def _cnpj_digit(base: list[int], weights: tuple[int, ...]) -> int:
    remainder = sum(digit * weight for digit, weight in zip(base, weights)) % 11
    return 0 if remainder < 2 else 11 - remainder


def generate_cnpj(rng: Random) -> str:
    """Generate an unformatted numeric CNPJ and verify it with validate-docbr."""
    root = [rng.randrange(10) for _ in range(8)]
    base = root + [0, 0, 0, 1]
    base.append(_cnpj_digit(base, (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)))
    base.append(_cnpj_digit(base, (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)))
    value = "".join(map(str, base))
    if not _cnpj_validator.validate(value):
        raise AssertionError("internal CNPJ generator produced an invalid value")
    return value


def generate_cns(rng: Random) -> str:
    """Generate a CNS in a synthetic 7-series and validate its checksum."""
    while True:
        first_fourteen = [7] + [rng.randrange(10) for _ in range(13)]
        weighted = sum(
            digit * weight
            for digit, weight in zip(first_fourteen, range(15, 1, -1))
        )
        check_digit = (-weighted) % 11
        if check_digit <= 9:
            value = "".join(map(str, first_fourteen + [check_digit]))
            if _cns_validator.validate(value):
                return value


def generate_numeric_code(
    rng: Random,
    *,
    width: int,
    prefix: str,
    used: set[str],
) -> str:
    """Generate a unique fixed-width identifier with an explicit demo prefix."""
    if not prefix.isdigit() or len(prefix) >= width:
        raise ValueError("prefix must contain digits and be shorter than width")
    remaining = width - len(prefix)
    while True:
        value = prefix + f"{rng.randrange(10**remaining):0{remaining}d}"
        if value not in used:
            used.add(value)
            return value
