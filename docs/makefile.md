# Comandos `make`

O [`Makefile`](../Makefile) é a interface operacional do projeto. Execute os
comandos a partir da raiz do repositório.

```sh
make help
```

## Instalação

| Comando | Uso |
| --- | --- |
| `make training` | Instala o PEC com banco local e modo de treinamento. Requer `.env`. |
| `make production` | Instala o PEC com banco local e modo de produção. Requer `.env`. |
| `make external` | Instala em modo de produção usando o banco PostgreSQL externo configurado em `.env`. |
| `make cloud` | Instala em modo de produção usando `cloud/.env` e `cloud/compose.yml`. |
| `make restore BACKUP=<arquivo>` | No modo cloud, recria o banco local a partir de um backup e inicia o PEC. Requer `cloud/.env`. |

`restore` encerra os containers do projeto, remove o banco `esus` atual e o
recria antes de restaurar o backup. Use-o somente quando puder substituir esse
banco.

## Manutenção e análise

| Comando | Uso |
| --- | --- |
| `make update-local` | Atualiza uma instalação com banco local usando `.env`. |
| `make update-external` | Atualiza uma instalação com banco externo usando `.env`. |
| `make codebase JAR=<arquivo>` | Gera uma versão decompilada do JAR para análise em `codebase/`. |

Para escolher outro diretório de saída do codebase:

```sh
make codebase JAR=/caminho/pec-bundle.jar OUTPUT=/caminho/codebase
```

## Variáveis

| Variável | Aplica-se a | Descrição |
| --- | --- | --- |
| `JAR=<arquivo-ou-url>` | instalação e `restore` | Seleciona o JAR do PEC. Tem precedência sobre `FILENAME` do arquivo de ambiente. |
| `BACKUP=<arquivo>` | `restore` | Caminho do backup PostgreSQL a restaurar. |
| `OUTPUT=<diretório>` | `codebase` | Diretório de saída; o padrão é `codebase`. |
| `BUILD_ARGS="..."` | instalação e `restore` | Opções adicionais repassadas para `scripts/build.sh`. |

Se `JAR` não for informado, o fluxo usa `FILENAME` de `.env` ou `cloud/.env`.
Sem os dois, procura a versão mais recente no portal SISAPS.

O JAR e o banco precisam ser compatíveis. Para restaurar uma demonstração com
o backup-base incluído no repositório, consulte [Como executar a PEC demo](run-demo.md).
