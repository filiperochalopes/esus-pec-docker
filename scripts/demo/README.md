# PEC demo data factory

Fábrica de instalações e-SUS PEC prontas para demonstração e testes, usando
somente dados sintéticos.

O objetivo não é fabricar um banco do zero. O banco do PEC contém schema,
catálogos, migrações e dados de referência dependentes da versão. A estratégia
segura é partir de uma instalação limpa criada pelo instalador oficial da mesma
versão do PEC, importar um CNES sintético pelo próprio sistema, criar os
cenários clínicos e só então exportar um backup completo.

## Um comando, sem LLM e sem interface

Pré-requisitos: Docker com `docker compose`, `uv`, Python 3, `curl`, Git LFS e
o JAR `eSUS-AB-PEC-5.5.22-Linux64.jar` na raiz de `esus-pec`. Depois de clonar,
materialize o pack-base uma vez com `git lfs pull`.

Na raiz de `esus-pec`, execute:

```bash
sh scripts/demo/build-demo-backup.sh
```

O backup validado será publicado em:

```text
scripts/demo/output/pec-demo-5.5.22.backup
```

Para escolher outro nome ou evitar conflito de porta:

```bash
sh scripts/demo/build-demo-backup.sh \
  --output /caminho/pec-demo-teste-5.5.22.backup \
  --port 18083
```

O script não altera o Compose normal nem o pack-base. Ele cria projeto, rede,
volume e diretório temporário exclusivos; restaura o pack-base; inicia o PEC em
treinamento; gera e importa o CNES por API; garante credenciais, cidadãos e
atendimentos por GraphQL; recria o PEC em produção; exporta um archive custom;
restaura esse próprio archive em banco limpo e executa validação somente
leitura. Só após todo o round trip os arquivos finais são movidos para o
destino.

Além do `.backup`, são publicados com o mesmo prefixo:

- `.validation.json`, com versão, SHA-256, tamanho e checks executados;
- `.credentials.txt`, com os logins exclusivamente sintéticos;
- `.clinical-manifest.json`, com as chaves dos 60 atendimentos;
- `.patients.csv`, índice sem documentos com uma linha de história clínica
  por paciente para orientar os testes manuais;
- `.cnes.zip`, com o CNES 3.1 sintético usado.

O arquivo `packs/5.5.22/base.backup` é o bootstrap canônico, versionado por Git
LFS e protegido contra sobrescrita pelo script. Ele não é o resultado de cada
execução: serve como ponto de partida durável e verificável pelo checksum de
`packs/5.5.22/pack.json`.

## Resultado esperado

O primeiro alvo de execução será o PEC 5.5.22. O schema foi inspecionado
diretamente nessa versão e o codebase local também foi regenerado a partir do
JAR 5.5.22.

Para cada versão suportada do PEC, a fábrica deverá produzir:

- `cnes-demo.xml` e `cnes-demo.zip`;
- um manifesto sem segredos com a seed e os identificadores sintéticos;
- um relatório de validação;
- um backup custom do PostgreSQL para restauração pelo `make restore`;
- opcionalmente um dump SQL legível, também preso à versão;
- `demo_credentials.txt`, com CPF/login, senha, perfis e lotações de cada
  profissional sintético.

## Estado atual

O fluxo executável para o PEC 5.5.22 já:

- gera e valida o CNES 3.1 sintético;
- provisiona e valida as credenciais dos profissionais;
- cria dez cidadãos por mutations oficiais do PEC;
- cria 60 atendimentos SOAP finalizados, variando de 2 a 10 por cidadão;
- alterna medições completas, parciais e ausentes e inclui prescrições
  estruturadas, inclusive medicamentos de uso contínuo nas crônicas;
- alterna entre duas UBS, duas equipes e os CBOs `225130` e `223505`;
- publica um manifesto clínico para tornar a geração repetível;
- produz um backup completo restaurável pelo `make restore`.

O CNES é importado automaticamente pelo endpoint oficial do PEC. As demais
etapas usam as mesmas operações GraphQL consumidas pelo cliente web 5.5.22,
sem SQL clínico direto.
`demo_credentials.txt` é uma saída local de laboratório, publicada somente
depois da validação dos logins e ignorada pelo Git.

Execute tudo apenas em instalação isolada. CPF, CNS, CNES e INE são
sintéticos, mas sequências algoritmicamente válidas não constituem uma faixa
oficialmente reservada.

## Leitura sugerida

1. [`docs/01-escopo-e-seguranca.md`](docs/01-escopo-e-seguranca.md)
2. [`docs/02-contrato-cnes.md`](docs/02-contrato-cnes.md)
3. [`docs/03-arquitetura-proposta.md`](docs/03-arquitetura-proposta.md)
4. [`docs/04-status-da-investigacao.md`](docs/04-status-da-investigacao.md)
5. [`docs/05-inventario-schema-5.5.22.md`](docs/05-inventario-schema-5.5.22.md)
6. [`docs/06-revisao-prompt-01-5.5.22.md`](docs/06-revisao-prompt-01-5.5.22.md)
7. [`docs/07-revisao-prompts-01b-02-03.md`](docs/07-revisao-prompts-01b-02-03.md)
8. [`docs/08-contrato-cidadao-prontuario-codebase-5.5.22.md`](docs/08-contrato-cidadao-prontuario-codebase-5.5.22.md)
9. [`docs/09-identidade-acessos-credenciais-codebase-5.5.22.md`](docs/09-identidade-acessos-credenciais-codebase-5.5.22.md)
10. [`docs/10-fechamento-prompts-02b-03b-schema-5.5.22.md`](docs/10-fechamento-prompts-02b-03b-schema-5.5.22.md)
11. [`docs/11-codigos-naturais-operacionais-5.5.22.md`](docs/11-codigos-naturais-operacionais-5.5.22.md)
12. [`docs/12-fluxo-atendimento-soap-codebase-5.5.22.md`](docs/12-fluxo-atendimento-soap-codebase-5.5.22.md)
13. [`docs/13-backup-restauracao-e-integridade-local-5.5.22.md`](docs/13-backup-restauracao-e-integridade-local-5.5.22.md)
14. [`docs/14-scaffold-e-gerador-cnes-3.1.md`](docs/14-scaffold-e-gerador-cnes-3.1.md)
15. [`docs/15-provisionamento-cidadaos-e-soap-5.5.22.md`](docs/15-provisionamento-cidadaos-e-soap-5.5.22.md)
16. [`docs/16-fabrica-backup-um-comando.md`](docs/16-fabrica-backup-um-comando.md)
17. [`prompts/README.md`](prompts/README.md)

## Gerar o CNES sintético

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
  --generated-on 2026-07-27
```

O comando valida o dataset com a réplica Python das regras do importador e
depois com o XSD embarcado no JAR informado.

```bash
uv run pytest
```

## Comandos internos para desenvolvimento

O fluxo abaixo é útil para depuração de uma etapa específica. Para produzir o
backup reproduzível, use `build-demo-backup.sh`.

### Provisionar uma instalação limpa

Depois de importar `output/cnes-demo.zip` e concluir a ativação municipal,
gere as credenciais no mesmo processo que valida os logins:

```bash
uv run pec-demo provision-credentials \
  --base-url http://127.0.0.1:8082 \
  --admin-login '<CPF_ADMIN_DEMO>' \
  --admin-password '<SENHA_ADMIN_DEMO>' \
  --credentials-file demo_credentials.txt \
  --municipality-ibge 2927408 \
  --uf BA \
  --cep 40000000 \
  --seed 5522 \
  --generated-on 2026-07-27
```

Use uma credencial assistencial validada para criar a coorte:

```bash
uv run pec-demo provision-patients \
  --base-url http://127.0.0.1:8082 \
  --login '<CPF_PROFISSIONAL_DEMO>' \
  --password '<SENHA_DEMO>' \
  --municipality-ibge 2927408 \
  --municipality-name SALVADOR \
  --cnes '<CNES_UBS_MEDICA>' \
  --ine '<INE_EQUIPE_MEDICA>' \
  --seed 5522 \
  --generated-on 2026-07-27
```

Por fim, gere os históricos longitudinais por cidadão:

```bash
uv run pec-demo provision-histories \
  --base-url http://127.0.0.1:8082 \
  --login '<CPF_PROFISSIONAL_DEMO>' \
  --password '<SENHA_DEMO>' \
  --doctor-cnes '<CNES_UBS_MEDICA>' \
  --nurse-cnes '<CNES_UBS_ENFERMAGEM>' \
  --manifest-file output/clinical_manifest.json \
  --seed 5522 \
  --generated-on 2026-07-27
```

Os comandos de cidadãos e históricos são idempotentes: cidadãos são
resolvidos por CPF e os atendimentos concluídos são registrados no manifesto
atômico.

## Inspeção segura do arquivo CNES

O comando abaixo mostra somente estrutura, contagens, formatos e integridade
referencial. Ele nunca imprime valores dos atributos:

```bash
python3 scripts/demo/tools/inspect_cnes.py \
  /caminho/para/XmlParaESUS.zip \
  --xsd /caminho/para/cnes_3.1.xsd
```

O XSD da versão 3.1 está embarcado no `backend-<versao>.jar`, no caminho
`cnes/cnes_3.1.xsd`. O gerador o descobre pelo JAR da versão-alvo e não mantém
uma cópia divergente no repositório.
