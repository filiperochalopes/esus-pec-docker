from __future__ import annotations

from copy import deepcopy

import pytest

from pec_demo.pec_client import PecClientError
from pec_demo.provisioning import provision_demo_credentials


class FakePec:
    def __init__(self, dataset):
        self.dataset = dataset
        self.passwords = {dataset.professionals[0].cpf: dataset.professionals[0].planned_password}
        self.tokens: dict[str, str] = {}

    def client(self, _base_url):
        return FakeClient(self)


class FakeClient:
    def __init__(self, pec):
        self.pec = pec
        self.cpf = None

    def login(self, username, password, *, force=True):
        if self.pec.passwords.get(username) != password:
            raise PecClientError("bad credentials")
        self.cpf = username

    def select_credential_admin_access(self):
        return {"id": "3", "tipo": "ADMINISTRADOR_MUNICIPAL"}

    def request_password_reset_token(self, cpf):
        token = f"token-{cpf}"
        self.pec.tokens[token] = cpf
        return token

    def reset_password(self, cpf, token, password):
        assert self.pec.tokens.pop(token) == cpf
        self.pec.passwords[cpf] = password

    def session(self):
        professional = next(
            item for item in self.pec.dataset.professionals if item.cpf == self.cpf
        )
        units = {
            unit.cnes: unit
            for unit in self.pec.dataset.units
        }
        accesses = []
        if professional.key == "multiprofile":
            accesses.append(
                {
                    "id": "3",
                    "tipo": "ADMINISTRADOR_MUNICIPAL",
                    "perfis": [{"id": "1", "nome": "ADMINISTRADOR_MUNICIPAL"}],
                }
            )
        for index, assignment in enumerate(professional.assignments):
            unit = units[assignment.cnes]
            team = next(
                team for team in unit.teams if team.ine == assignment.ine
            )
            accesses.append(
                {
                    "id": str(10 + index),
                    "tipo": "LOTACAO",
                    "perfis": [{"id": "2", "nome": professional.key.upper()}],
                    "unidadeSaude": {"nome": unit.name, "cnes": unit.cnes},
                    "equipe": {"nome": team.reference_name, "ine": team.ine},
                    "cbo": {"nome": assignment.cbo, "cbo2002": assignment.cbo},
                }
            )
        return {
            "profissional": {
                "cpf": professional.cpf,
                "usuario": {"forcarTrocaSenha": False},
                "acessos": accesses,
            }
        }


def test_credentials_are_written_only_after_all_logins_validate(dataset, tmp_path):
    pec = FakePec(dataset)
    output = tmp_path / "demo_credentials.txt"

    validated = provision_demo_credentials(
        dataset,
        base_url="http://pec",
        admin_login=dataset.professionals[0].cpf,
        admin_password=dataset.professionals[0].planned_password,
        credentials_path=output,
        client_factory=pec.client,
    )

    assert len(validated) == 3
    assert len(validated[0].assignments) == 2
    text = output.read_text(encoding="utf-8")
    assert all(item.cpf in text for item in dataset.professionals)
    assert all(item.planned_password in text for item in dataset.professionals)
    assert (output.stat().st_mode & 0o777) == 0o600


def test_credentials_file_is_not_published_after_failed_validation(dataset, tmp_path):
    pec = FakePec(dataset)
    broken = deepcopy(pec.dataset)
    pec.dataset = broken
    output = tmp_path / "demo_credentials.txt"
    pec.passwords[dataset.professionals[1].cpf] = "wrong-after-reset"

    original_reset = FakeClient.reset_password

    def broken_reset(self, cpf, token, password):
        original_reset(self, cpf, token, password)
        if cpf == dataset.professionals[1].cpf:
            self.pec.passwords[cpf] = "wrong-after-reset"

    FakeClient.reset_password = broken_reset
    try:
        with pytest.raises(PecClientError):
            provision_demo_credentials(
                dataset,
                base_url="http://pec",
                admin_login=dataset.professionals[0].cpf,
                admin_password=dataset.professionals[0].planned_password,
                credentials_path=output,
                client_factory=pec.client,
            )
    finally:
        FakeClient.reset_password = original_reset

    assert not output.exists()
