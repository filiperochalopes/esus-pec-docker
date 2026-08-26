# Como executar a PEC demo

Este procedimento inicia uma instância local descartável a partir do
`base.backup` sintético versionado no repositório. Não use o backup nem a
instância resultante em produção.

## Pré-requisitos

- Docker Engine com Docker Compose;
- Git LFS, para obter o arquivo de backup;
- o JAR `eSUS-AB-PEC-5.5.22-Linux64.jar` (ou outro JAR compatível com o backup).

Na raiz do projeto:

```sh
git lfs pull
cp cloud/.env.example cloud/.env
```

Revise `cloud/.env`, especialmente `APP_PORT` se a porta `8082` já estiver em
uso.

## Restaurar o backup-base

O backup em `scripts/demo/packs/5.5.22/base.backup` requer o PEC **5.5.22**.
Informe explicitamente o JAR correspondente:

```sh
make restore \
  BACKUP="$PWD/scripts/demo/packs/5.5.22/base.backup" \
  JAR=/caminho/para/eSUS-AB-PEC-5.5.22-Linux64.jar
```

`JAR` só pode ser omitido se `FILENAME` em `cloud/.env` já apontar para o JAR
do PEC **5.5.22**:

```sh
make restore \
  BACKUP="$PWD/scripts/demo/packs/5.5.22/base.backup"
```

Sem `JAR` nem `FILENAME`, o comando baixa a versão mais recente disponível do
PEC. Não use essa alternativa para a demo, pois essa versão pode não ser a
5.5.22 e tornar o banco incompatível.

O comando encerra os containers do projeto, constrói a imagem, inicia o
PostgreSQL, recria o banco `esus`, restaura o backup e inicia o PEC.

## Acompanhar e acessar

```sh
docker compose -f cloud/compose.yml --env-file cloud/.env logs -f pec
```

Com a configuração padrão, acesse [http://localhost:8082](http://localhost:8082).
Se `APP_PORT` foi alterada, substitua `8082` pela porta escolhida.

Se o PEC informar incompatibilidade de versão, o JAR não corresponde ao
backup. Use o JAR 5.5.22 ou verifique `VERSAOBANCODADOS` e o JAR utilizado.

## Demonstração hospedada e credenciais

O repositório não contém a URL nem as credenciais da demonstração hospedada.
Publique apenas credenciais sintéticas e mantenha-as fora do backup-base quando
precisar rotacioná-las. Consulte [Comandos `make`](makefile.md) para os demais
fluxos operacionais.
