# Scaffold Python e gerador CNES 3.1

Data: 2026-07-27.

## Entrega

O pacote `pec-demo` implementa a primeira fase executável da fábrica:

- Python 3.10+;
- `Faker==40.36.0`;
- `validate-docbr==2.0.0`;
- `lxml==6.0.2`;
- CLI instalável;
- modelos imutáveis para unidade, equipe, profissional e lotação;
- geração determinística por seed;
- XML e ZIP CNES 3.1;
- manifesto sem senhas;
- validação pela réplica Python das regras do PEC;
- validação integral pelo XSD extraído do JAR 5.5.22.

## Coorte CNES inicial

A seed `5522` produz:

- duas UBS sintéticas;
- duas equipes ESF;
- três profissionais;
- quatro lotações;
- CBO `225130` para médico de família e comunidade;
- CBO `223505` para enfermeiro;
- um profissional multiperfil com duas lotações, duas unidades e dois CBOs.

Os nomes incluem marcadores explícitos `DEMO` ou `DEMONSTRACAO`. CNES e INE
usam prefixo técnico de laboratório, mas continuam sendo apenas números
offline: não existe faixa nacional oficialmente reservada para dados
sintéticos.

CPF, CNPJ e CNS são algoritmicamente válidos e não são copiados de pessoas ou
estabelecimentos. Isso não permite garantir que uma sequência válida jamais
tenha sido atribuída no mundo real. Por isso os artefatos só podem ser usados
em instalação isolada.

## Réplica das regras Java

`CnesReplicaValidator` reproduz as invariantes relevantes de:

- `UnidadeSaudeCnesValidator`;
- `EquipeCnesValidator`;
- `ProfissionalCnesValidator`;
- `LotacaoCnesValidator`;
- `VinculacaoEquipesCnesValidator`.

São testados:

- obrigatoriedade e dígitos de CNPJ, CPF e CNS;
- município/UF da unidade;
- tipo de unidade e complexidade;
- tipo, INE e data de desativação da equipe;
- CBO elegível;
- resolução da unidade por CNES;
- resolução de equipe pelo par CNES/INE;
- coerência e unicidade de CPF/CNS;
- diversidade mínima da coorte.

A réplica é um preflight. O importador oficial continua sendo a autoridade
final.

## XSD preso à versão

O CLI recebe um backend JAR, `pec-bundle.jar` ou instalador JAR e procura
recursivamente:

```text
cnes/cnes_3.1.xsd
```

O artefato somente é escrito depois de passar no validador Python e no XSD do
JAR informado. O SHA-256 do XSD e do JAR entra no manifesto.

## Execução

```bash
cd scripts/demo
uv sync --extra dev

uv run pec-demo generate-cnes \
  --output-dir output \
  --backend-jar ../../codebase/app-extracted/BOOT-INF/lib/backend-5.5.22.jar \
  --municipality-ibge 2927408 \
  --uf BA \
  --cep 40000000 \
  --seed 5522 \
  --generated-on 2026-07-27 \
  --pec-version 5.5.22
```

Saídas:

- `output/cnes-demo.xml`;
- `output/cnes-demo.zip`;
- `output/manifest.json`.

`demo_credentials.txt` não é criado na etapa `generate-cnes`. Ele é publicado
por `provision-credentials` somente depois da importação CNES,
provisionamento de senha/perfis e validação dos logins no mesmo fluxo de
aplicação.

## Testes

```bash
uv run pytest
```

A suíte contém 23 testes e valida o XML contra o XSD real da versão
5.5.22.

## Validação no importador oficial 5.5.22

Em 2026-07-27 o ZIP gerado pela seed `5522` foi importado pela interface do
PEC 5.5.22 em uma instalação isolada de treinamento. O relatório terminal
`Importado` confirmou:

- 2 unidades novas e 0 atualizadas;
- 2 equipes novas e 0 atualizadas;
- 2 profissionais novos e 1 atualizado;
- 4 lotações novas e 0 atualizadas.

O profissional atualizado é o multiperfil já cadastrado como instalador antes
da importação. O PEC também identificou corretamente suas duas lotações e
avisou que a agenda específica delas ainda não estava configurada.

Para ativar o município sem depender de contra-chave real, a preparação usa
temporariamente `TREINAMENTO=1`. O build local agora declara o modo
explicitamente; `make production` aplica `TREINAMENTO=0` antes da exportação final.
Quando `TRAINING` não é informado (caso do banco externo), `scripts/install.sh`
preserva o comportamento anterior e não altera a configuração.

## Etapas posteriores concluídas

O fluxo também implementa resolução de usuários por CPF, provisionamento e
validação de credenciais, troca de lotação, dez cidadãos e vinte históricos
SOAP. O contrato e a validação estão documentados em
`15-provisionamento-cidadaos-e-soap-5.5.22.md`.
