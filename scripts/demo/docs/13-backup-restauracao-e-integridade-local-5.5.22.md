# Backup, restauração e integridade local — PEC 5.5.22

Data da revisão: 2026-07-28.

Este documento audita o relatório do Prompt 05 contra o `scripts/build.sh`, os arquivos
Compose e o codebase 5.5.22.

## Resultado da auditoria

O relatório externo não é utilizável como checklist executável. Ele inventou
ou não provou:

- as tabelas `atendimento_soap` e `cidadão`;
- o endpoint `/api/v1/auth/login`;
- comandos de verificação de sequence baseados nessas tabelas;
- a coluna `extension_name` em `pg_extension` — a coluna correta é `extname`;
- a existência de um modo de instalação `DEMO` no enum do PEC.

O enum de tipo de instalação encontrado no codebase contém `PRONTUARIO` e
`CENTRALIZADORA`. Treinamento é uma modalidade do instalador, não um terceiro
valor desse enum.

## Contrato real do `scripts/build.sh`

O caminho de restauração suportado é:

```sh
sh scripts/build.sh -f eSUS-AB-PEC-5.5.22-Linux64.jar \
  -r /caminho/pec-demo-5.5.22.backup
```

Com banco local, o script:

1. copia o backup para o volume montado em `/backups`;
2. sobe somente o serviço `db`;
3. espera `pg_isready`;
4. encerra conexões do banco-alvo;
5. remove e recria o banco;
6. executa:

```sh
pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -1 --no-owner --no-acl "/backups/<arquivo>.backup"
```

7. inicia o serviço `pec`.

A opção `-r` é recusada com banco externo. O procedimento é destrutivo para o
banco local configurado, portanto só poderá ser usado contra volume
descartável e inequivocamente sintético.

## Formato do backup

O artefato canônico será PostgreSQL custom:

```sh
pg_dump --format=custom --blobs --encoding=UTF8 \
  --no-privileges --no-tablespaces \
  --file pec-demo-5.5.22.backup esus
```

Owner e ACL são ignorados na restauração. Large objects e sequences fazem
parte do archive custom. A fábrica deve registrar as versões cliente/servidor
de PostgreSQL e testar o round trip com a mesma major version usada pelo
Compose, atualmente PostgreSQL 17.

Não será usado `--no-unlogged-table-data` até provar que nenhuma tabela
unlogged contém estado necessário ao demo.

## Provas de versão

O manifesto deve guardar:

- versão-alvo `5.5.22`;
- nome e SHA-256 do JAR;
- versão de banco lida pela configuração técnica do PEC;
- PostgreSQL server version;
- SHA-256 do backup;
- seed e versão do gerador;
- fingerprint dos catálogos e do schema;
- horário UTC de criação e validação.

`TB_CONFIG_SISTEMA.CO_CONFIG_SISTEMA` é `String` no mapeamento JPA 5.5.22 e
`DS_TEXTO` é o valor textual. A existência e o nome exato da chave de versão
serão confirmados no preflight por metadados/consulta técnica permitida; o
gerador abortará se JAR e banco não coincidirem.

## Critérios mínimos do round trip

O artefato somente será marcado como validado após:

- restauração bem-sucedida em volume novo;
- startup do PEC sem erro de migração ou incompatibilidade;
- login de todas as credenciais sintéticas;
- seleção das duas lotações e perfis esperados;
- localização dos dez cidadãos sintéticos;
- abertura dos históricos e SOAPs esperados;
- problemas ativos/resolvidos coerentes com as fixtures;
- ausência de órfãos no grafo gerado;
- sequences maiores ou iguais ao maior identificador persistido;
- integrações externas desabilitadas;
- ausência de qualquer marcador proveniente do CNES de referência real.

Os testes funcionais serão realizados pela API/UI real. Uma consulta SQL a uma
tabela inventada não substitui o smoke test.

## Manifesto

O manifesto não terá um `status: validated` autoatribuído. A propriedade será
escrita somente depois de todos os checks, com os resultados individualizados
em `validation.json`. Senhas ficarão exclusivamente em
`demo_credentials.txt`, nunca no manifesto.

## Round trip executado

O artefato
`esus-pec-demo-5.5.22-seed-5522-production.backup` foi validado em
2026-07-28:

- formato custom, PostgreSQL 17.10, 13.367 entradas no TOC;
- tamanho de 61.700.092 bytes;
- SHA-256
  `7618358aa9f53cfe684362ff36e9c252ee929474a243ec73908bcbf58e293ad6`;
- volume `cloud_esus-db-data` anterior removido com `down -v`;
- volume novo criado antes da restauração;
- `pg_restore` concluído em transação única;
- migração 5.5.22 concluída;
- modo produção aplicado pelo instalador;
- HTTP 200;
- 10 cidadãos encontrados sem recriação;
- 20 históricos gerados e validados: 10 médicos e 10 de enfermagem;
- 1 histórico médico sintético adicional, criado durante a captura do contrato
  oficial da mutation, preservado intencionalmente no primeiro cidadão.

Os resultados estruturados ficam em `scripts/demo/validation.json`. A cópia
canônica pronta para uso está em:

```text
~/Downloads/esus-pec-demo-5.5.22-seed-5522-production.backup
```

O comando de restauração validado é:

```sh
make restore \
  JAR=eSUS-AB-PEC-5.5.22-Linux64.jar \
  BACKUP=~/Downloads/esus-pec-demo-5.5.22-seed-5522-production.backup
```

Em Apple Silicon, a imagem `linux/amd64` executa o Java sob QEMU. Após a
mensagem de instalação concluída, o primeiro HTTP 200 levou vários minutos,
com o processo usando CPU continuamente. Reset de conexão durante esse
intervalo não indicou falha; os gates foram processo ativo, ausência de
reinício, migração concluída e resposta HTTP final.

## Evoluções futuras

- guarda explícita de ambiente demo no exportador;
- confirmação automática da versão e do fingerprint;
- subcomandos dedicados de exportação e validação;
- modo dry-run;
- recusa automática de host/banco não permitido;
- validação de problemas ativos/resolvidos quando essa fixture for adicionada.
