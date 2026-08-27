# Instalação standalone do e-SUS PEC

## Executar

```bash
curl -fsSL \
  https://raw.githubusercontent.com/filiperochalopes/esus-pec-docker/main/helpers/linux-standalone-instalation/linux-install.sh \
  -o linux-install.sh

chmod +x linux-install.sh

./linux-install.sh
```

## Requisitos

- Ubuntu ou Debian Linux x86_64 com systemd.
- Execução como `root` ou usuário com `sudo` sem senha (`NOPASSWD`).
- Banco PostgreSQL existente e acessível pelo servidor.
- Backup PostgreSQL custom (`.backup`), caso haja restauração.

Para descobrir o caminho absoluto do backup, execute em outro terminal:

```bash
realpath caminho/do/arquivo.backup
```

Exemplo:

```bash
realpath 20250606123938-esus-postgres.backup
```

Copie a saída e cole em `Caminho do arquivo de backup PostgreSQL`.

## O que o script pergunta

- Host, porta, nome, usuário e senha do PostgreSQL.
- Arquivo de backup e confirmação da restauração.
- SSL do banco, domínio HTTPS, porta, fuso horário e modo treinamento.

## O que o script faz

1. Instala o cliente PostgreSQL 17.
2. Restaura o backup com `pg_restore`, quando solicitado.
3. Instala Java 17, fontes e dependências.
4. Baixa o instalador Linux64 mais recente do SISAPS.
5. Instala e inicia `e-SUS-PEC.service`.

> A restauração usa `--clean --if-exists`: objetos existentes que também estão
> no backup serão removidos antes de serem recriados. O script pede confirmação.

O script gera dois relatórios:

- `restore_warn_error.log`: somente warnings e erros.
- `restore_full.log`: saída completa do `pg_restore`, incluindo o contexto.

Se `pg_restore` retornar erro, o administrador pode revisar os relatórios e
decidir interativamente se a instalação do PEC deve continuar. Continuar é a
opção padrão (`S/n`), pois muitos erros de restauração são inofensivos; responda
`n` para interromper. Antes da pergunta, o script lê `restore_warn_error.log` e
mostra no terminal todos os erros e avisos encontrados.

## Opções

```bash
./linux-install.sh --help
./linux-install.sh --latest-url
./linux-install.sh --jar-url URL_DO_JAR
```

- `--latest-url`: mostra somente o link do instalador mais recente.
- `--jar-url`: usa uma versão específica do instalador.
