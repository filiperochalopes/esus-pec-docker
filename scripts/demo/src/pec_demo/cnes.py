"""Render a DemoDataset as deterministic CNES 3.1 XML and ZIP."""

from __future__ import annotations

from datetime import date
from io import BytesIO
import xml.etree.ElementTree as ET
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from pec_demo.models import DemoDataset


XSI = "http://www.w3.org/2001/XMLSchema-instance"
ET.register_namespace("xsi", XSI)


def _date_br(value: date) -> str:
    return value.strftime("%d/%m/%Y")


def render_xml(dataset: DemoDataset) -> bytes:
    root = ET.Element(
        "ImportarXMLCNES",
        {f"{{{XSI}}}noNamespaceSchemaLocation": "cnes_3.1.xsd"},
    )
    identification = ET.SubElement(
        root,
        "IDENTIFICACAO",
        {
            "DATA": dataset.generated_on.isoformat(),
            "ORIGEM": dataset.origin,
            "DESTINO": dataset.destination,
            "CO_IBGE_MUN": dataset.municipality_ibge,
            "VERSAO_XSD": dataset.xsd_version,
        },
    )
    establishments = ET.SubElement(identification, "ESTABELECIMENTOS")
    for unit in dataset.units:
        unit_node = ET.SubElement(
            establishments,
            "DADOS_GERAIS_ESTABELECIMENTOS",
            {
                "NM_FANTA": unit.name,
                "CNPJ": unit.cnpj,
                "CNES": unit.cnes,
                "TP_UNID_ID": unit.unit_type_code,
                "DS_TP_UNID": unit.unit_type_description,
                "CO_SUBTIPO_UNID": unit.subtype_code,
                "DS_SUBTIPO_UNID": unit.subtype_description,
                "TELEFONE1": unit.phone_1,
                "TELEFONE2": unit.phone_2,
                "FAX": unit.fax,
                "E_MAIL": unit.email,
            },
        )
        address_node = ET.SubElement(unit_node, "ENDERECO")
        ET.SubElement(
            address_node,
            "DADOS_ENDERECO",
            {
                "CO_CEP": unit.address.cep,
                "SG_UF": unit.address.uf,
                "CO_IBGE_MUN": unit.address.municipality_ibge,
                "BAIRRO": unit.address.neighborhood,
                "LOGRADOURO": unit.address.street,
                "NUMERO": unit.address.number,
                "COMPLEMENT": unit.address.complement,
                "PONTO_REF": unit.address.reference,
            },
        )
        complexity_node = ET.SubElement(unit_node, "COMPLEXIDADE")
        for complexity in unit.complexities:
            ET.SubElement(
                complexity_node,
                "DADOS_COMPLEXIDADE",
                {"SG_COMPLEXIDADE": complexity},
            )
        teams_node = ET.SubElement(unit_node, "EQUIPES")
        for team in unit.teams:
            ET.SubElement(
                teams_node,
                "DADOS_EQUIPES",
                {
                    "ID_TP_EQUIPE": team.home_care_type,
                    "TP_EQUIPE": team.type_code,
                    "SG_EQUIPE": team.abbreviation,
                    "DS_EQUIPE": team.description,
                    "CO_INE": team.ine,
                    "CO_AREA": team.area_code,
                    "DS_AREA": team.area_description,
                    "NM_REFERENCIA": team.reference_name,
                    "DT_DESATIVACAO": team.deactivation_date,
                },
            )

    professionals_node = ET.SubElement(identification, "PROFISSIONAIS")
    for professional in dataset.professionals:
        professional_node = ET.SubElement(
            professionals_node,
            "DADOS_PROFISSIONAIS",
            {
                "NM_PROF": professional.name,
                "CPF_PROF": professional.cpf,
                "CO_CNS": professional.cns,
                "DT_NASC": _date_br(professional.birth_date),
                "SEXO": professional.sex,
                "CONSELHO_ID": professional.council_id,
                "SG_UF_EMIS": professional.council_uf,
                "NU_REGISTRO": professional.council_registration,
                "E_MAIL": professional.email,
                "TELEFONE": professional.phone,
            },
        )
        ET.SubElement(professional_node, "ENDERECO")
        assignments_node = ET.SubElement(professional_node, "LOTACOES")
        for assignment in professional.assignments:
            ET.SubElement(
                assignments_node,
                "DADOS_LOTACOES",
                {
                    "CNES": assignment.cnes,
                    "CO_INE": assignment.ine,
                    "CO_CBO": assignment.cbo,
                    "MICROAREA": assignment.microarea,
                },
            )

    ET.indent(root, space="  ")
    return ET.tostring(
        root,
        encoding="ISO-8859-1",
        xml_declaration=True,
        short_empty_elements=True,
    )


def render_zip(xml_bytes: bytes, xml_name: str = "cnes-demo-3.1.xml") -> bytes:
    output = BytesIO()
    entry = ZipInfo(xml_name, date_time=(1980, 1, 1, 0, 0, 0))
    entry.compress_type = ZIP_DEFLATED
    entry.external_attr = 0o600 << 16
    with ZipFile(output, "w") as archive:
        archive.writestr(entry, xml_bytes)
    return output.getvalue()
