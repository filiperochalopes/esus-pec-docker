from __future__ import annotations

from io import BytesIO
import xml.etree.ElementTree as ET
from zipfile import ZipFile

from pec_demo.cnes import render_xml, render_zip
from pec_demo.xsd import load_cnes_xsd, validate_xml


def test_xml_validates_against_xsd_from_backend_5524(dataset, backend_jar):
    xml_bytes = render_xml(dataset)
    xsd_bytes = load_cnes_xsd(backend_jar)

    validate_xml(xml_bytes, xsd_bytes)


def test_xml_has_expected_graph_and_cross_references(dataset):
    root = ET.fromstring(render_xml(dataset))
    units = root.findall("./IDENTIFICACAO/ESTABELECIMENTOS/DADOS_GERAIS_ESTABELECIMENTOS")
    professionals = root.findall("./IDENTIFICACAO/PROFISSIONAIS/DADOS_PROFISSIONAIS")
    assignments = root.findall(
        "./IDENTIFICACAO/PROFISSIONAIS/DADOS_PROFISSIONAIS/LOTACOES/DADOS_LOTACOES"
    )
    teams = root.findall(
        "./IDENTIFICACAO/ESTABELECIMENTOS/"
        "DADOS_GERAIS_ESTABELECIMENTOS/EQUIPES/DADOS_EQUIPES"
    )

    assert len(units) == 2
    assert len(teams) == 2
    assert len(professionals) == 3
    assert len(assignments) == 4

    assert all(item.attrib["TP_UNID_ID"] == "2" for item in units)
    assert all(
        item.attrib["DS_TP_UNID"] == "CENTRO DE SAUDE/UNIDADE BASICA"
        for item in units
    )

    unit_codes = {item.attrib["CNES"] for item in units}
    team_pairs = {
        (unit.attrib["CNES"], team.attrib["CO_INE"])
        for unit in units
        for team in unit.findall("./EQUIPES/DADOS_EQUIPES")
    }
    assert all(item.attrib["CNES"] in unit_codes for item in assignments)
    assert all(
        (item.attrib["CNES"], item.attrib["CO_INE"]) in team_pairs
        for item in assignments
        if item.attrib["CO_INE"]
    )


def test_zip_is_reproducible_and_contains_exactly_one_xml(dataset):
    xml_bytes = render_xml(dataset)

    first = render_zip(xml_bytes)
    second = render_zip(xml_bytes)
    assert first == second

    with ZipFile(BytesIO(first)) as archive:
        names = archive.namelist()
        assert names == ["cnes-demo-3.1.xml"]
        assert archive.read(names[0]) == xml_bytes
