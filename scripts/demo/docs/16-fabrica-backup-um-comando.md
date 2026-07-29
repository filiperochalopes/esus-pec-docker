# Fábrica de backup demo em um comando

## Contrato

`scripts/demo/build-demo-backup.sh` deve produzir um backup completo do PEC
5.5.22 sem interface, LLM, banco pré-existente ou dados externos. Uma execução
usa apenas arquivos versionados, o JAR da versão e imagens Docker.

O comando padrão é:

```bash
sh scripts/demo/build-demo-backup.sh
```

Uma saída alternativa, apropriada para ensaios, é:

```bash
sh scripts/demo/build-demo-backup.sh \
  --output /tmp/pec-demo-teste-5.5.22.backup \
  --port 18083
```

## Fontes determinísticas

- `packs/5.5.22/pack.json`: versão, seed, data, município e checksums;
- `packs/5.5.22/base.backup`: instalação sintética funcional usada como
  bootstrap e armazenada por Git LFS;
- `packs/5.5.22/clinical_manifest.json`: estado clínico esperado no bootstrap;
- `eSUS-AB-PEC-5.5.22-Linux64.jar`: binário oficial correspondente;
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
sh build.sh -C -p -r /caminho/pec-demo-5.5.22.backup
```

## Atualização para outra versão

Uma nova versão exige um novo diretório `packs/<versão>`, novo checksum do JAR
e uma execução completa do round trip. Não reutilize silenciosamente um pack
de outra versão. O resultado anterior deve permanecer disponível até que o
novo candidato passe pelos mesmos checks.
