# Fábrica de backup demo em um comando

## Contrato

`scripts/demo/build-demo-backup.sh` deve produzir um backup completo do PEC,
na versão travada em `scripts/demo/pack/pack.json`, sem interface, LLM, banco
pré-existente ou dados externos. Uma execução usa apenas arquivos
versionados, o JAR da versão e imagens Docker.

O comando padrão é:

```bash
sh scripts/demo/build-demo-backup.sh
```

Uma saída alternativa, apropriada para ensaios, é:

```bash
sh scripts/demo/build-demo-backup.sh \
  --output /tmp/pec-demo-teste.backup \
  --port 18083
```

## Fontes determinísticas

- `pack/pack.json`: versão, seed, data, município e checksums;
- `pack/base.backup`: instalação sintética funcional usada como bootstrap e
  armazenada por Git LFS. Existe uma única pasta `pack/`, não uma por versão
  — atualizar a versão do PEC substitui esses três arquivos;
- `pack/clinical_manifest.json`: estado clínico esperado no bootstrap;
- `eSUS-AB-PEC-<versão>-Linux64.jar`: binário oficial correspondente, com o
  nome de arquivo lido de `pack.json`;
- código Python do gerador: CNES, profissionais, credenciais, pacientes e
  históricos.

O script verifica todos os checksums antes de criar containers. Ele recusa
qualquer `--output` dentro da pasta do pack para que uma execução nunca
substitua o bootstrap canônico.

## Pipeline

1. Gera o CNES 3.1 e valida as regras replicadas do importador e o XSD
   embarcado no JAR.
2. Cria um projeto Compose com nome exclusivo, volume PostgreSQL exclusivo,
   rede exclusiva e porta ligada somente a `127.0.0.1`.
3. Restaura o pack-base em um banco PostgreSQL novo.
4. Inicia o PEC em treinamento, necessário para a ativação municipal local.
5. Autentica com a identidade sintética determinística e envia o ZIP ao
   endpoint oficial `POST /api/cnes/{municipioId}`.
6. Aguarda o processamento assíncrono do CNES e confere 2 unidades, 2 equipes,
   3 profissionais e 4 lotações.
7. Normaliza e valida as três credenciais; cria ou resolve 10 cidadãos; cria ou
   resolve 60 atendimentos SOAP finalizados, distribuídos de 2 a 10 por
   cidadão.
8. Recria a aplicação em produção e exporta `pg_dump -Fc`.
9. Para o PEC, recria o banco e restaura o archive candidato com
   `pg_restore --single-transaction --no-owner --no-acl`.
10. Reinicia o PEC e valida, sem escritas, credenciais, lotações, pacientes,
    autoria, vínculo ao cidadão, finalização e conteúdo S/O/A/P.
11. Publica atomicamente o backup e seus arquivos auxiliares.
12. Remove containers, rede, volume e runtime exclusivos, mesmo em caso de
    erro.

## Saídas

Para uma saída `pec-demo-5.5.22.backup`, são criados:

- `pec-demo-5.5.22.backup`;
- `pec-demo-5.5.22.validation.json`;
- `pec-demo-5.5.22.credentials.txt`;
- `pec-demo-5.5.22.clinical-manifest.json`;
- `pec-demo-5.5.22.patients.csv`;
- `pec-demo-5.5.22.cnes.zip`.

O CSV contém nome sintético, idade, cenário, resumo em uma linha, problemas
abertos e resolvidos, medicamentos contínuos e contadores das lacunas
planejadas. CPF e CNS não são incluídos.

Nada é publicado antes da validação final. Arquivos temporários têm nome
exclusivo da execução e são removidos em falhas. Um backup já existente só é
substituído pelo `mv` final após a aprovação integral do candidato.

## Diagnóstico e recuperação

Use `--keep-runtime` para preservar CNES, manifesto, credenciais e archive
intermediários após a execução. O projeto Docker ainda é encerrado e seu volume
é removido; o diretório preservado serve para inspeção de artefatos, não para
continuar a instância.

Em Apple Silicon, o PEC `linux/amd64` roda sob emulação e cada inicialização
pode levar vários minutos. O script informa o tempo de espera e mostra os logs
do PEC caso o limite seja excedido.

O backup final pode ser consumido pelo fluxo normal:

```bash
make restore BACKUP=/caminho/pec-demo-5.5.22.backup
```

## Atualização para outra versão

`--upgrade-jar NOME_DO_JAR` + `--upgrade-pec-version VERSAO` fazem o script
restaurar o `pack/base.backup` atual, mas subir o PEC a partir de um JAR de
outra versão em vez do travado em `pack.json`. O próprio PEC migra o schema
em runtime ao iniciar sobre um banco de versão anterior — o mesmo mecanismo
de `make update-local`/`update.sh` numa instalação real — então não é preciso
partir de uma instalação vazia nem reimportar o CNES do zero. Nesse modo a
checagem de checksum do JAR é pulada (o `pack.json` ainda descreve o JAR
antigo) e o candidato validado sai em `output/`, sem tocar em `pack/`.

`scripts/demo/promote-pack.sh` promove esse candidato a novo pack canônico:
substitui `base.backup`, `clinical_manifest.json` e `pack.json` (recalculando
os checksums e herdando seed/município/UF/CEP do pack anterior) e atualiza
`DEFAULT_PEC_VERSION` em `src/pec_demo/version.py`. Não reutilize
silenciosamente um pack de outra versão sem passar por esse fluxo, e mantenha
o resultado anterior disponível (histórico do Git/LFS) até que o novo
candidato passe pelos mesmos checks. Veja `scripts/demo/README.md`, seção
"Atualizando o pack para uma nova versão do PEC", para o passo a passo.
