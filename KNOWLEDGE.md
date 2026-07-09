# e-SUS-PEC — Base de Conhecimento Operacional

## Configurações do Sistema

### Tabela principal de configuração

As configurações globais do e-SUS-PEC ficam na tabela `tb_config_sistema` do banco `esus`:

```sql
SELECT co_config_sistema, ds_config_sistema, ds_texto, ds_inteiro
FROM tb_config_sistema;
```

### Campos críticos

| chave | descrição | nota |
|-------|-----------|------|
| `LINKINSTALACAO` | Endereço URI base da instalação | Define as rotas internas; deve apontar para a URL de acesso local (ex: `http://localhost:8082`) |
| `VERSAOBANCODADOS` | Versão do banco de dados | Deve ser compatível com a versão do JAR do app |
| `TIPOINSTALACAO` | Tipo: `PRONTUARIO` ou `CENTRALIZADORA` | Define o modo de operação |
| `NOMEINSTALACAO` | Nome da instalação | Identificador textual |
| `HORUSHABILITADO` / `CADSUSHABILITADO` | Integrações com Hórus / CADSUS | Desabilitar se não usar |

### Arquivos de configuração dentro do container

- `/etc/pec.config` — JSON com metadata da instalação (criado na primeira inicialização). Usado pelo `entrypoint.sh` para verificar se o sistema já foi instalado.
- `/opt/e-SUS/webserver/config/application.properties` — Configuração Spring Boot (apenas datasource: usuário, senha, URL do banco).

## Versão do App vs Versão do Banco

O e-SUS-PEC verifica compatibilidade na inicialização (`StartupListener` → `SystemVersionService.ensureCompatibleVersions`). Se as versões não coincidirem, a aplicação falha com:

```
O PEC e o seu banco de dados não estão na mesma versão.
```

Verificar:

```sql
-- Versão do banco
SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';
```

A versão do app está embutida no JAR (ex: `pec-bundle.jar:5.4.21`).

## Como acessar o banco via docker compose

```bash
# Listar bancos
docker compose exec db psql -U postgres -c "\l"

# Listar tabelas do banco esus
docker compose exec db psql -U postgres -d esus -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"

# Consultar configurações do sistema
docker compose exec db psql -U postgres -d esus -c "SELECT * FROM tb_config_sistema;"

# Atualizar URL base
docker compose exec db psql -U postgres -d esus -c \
  "UPDATE tb_config_sistema SET ds_texto = 'http://localhost:8082' WHERE co_config_sistema = 'LINKINSTALACAO';"

# Verificar versão do banco
docker compose exec db psql -U postgres -d esus -c \
  "SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';"

# Verificar configurações específicas
docker compose exec db psql -U postgres -d esus -c \
  "SELECT co_config_sistema, ds_texto FROM tb_config_sistema WHERE co_config_sistema IN ('LINKINSTALACAO','VERSAOBANCODADOS','TIPOINSTALACAO','NOMEINSTALACAO');"
```

## Como verificar logs do app

```bash
# Logs da aplicação
docker compose exec pec cat /opt/e-SUS/webserver/logs/pec.log

# Logs recentes
docker compose logs -f pec

# Reiniciar app após alterações de config
docker compose restart pec
```

## Fluxo de restauração de backup

1. Executar `build.sh -C -p -r <backup>` para reconstruir a imagem e restaurar o banco
2. Verificar se a versão do JAR bate com a versão no banco (`VERSAOBANCODADOS`)
3. Atualizar `LINKINSTALACAO` para a URL local
4. Reiniciar o container: `docker compose restart pec`
5. Verificar logs: `docker compose logs pec`

## Problemas comuns

- **Rotas não funcionam**: geralmente `LINKINSTALACAO` ainda aponta para a URL de produção
- **App não inicia**: version mismatch entre JAR e banco de dados
- **Erro de EntityManager**: consequência do version mismatch — o app falha na inicialização e fecha o EntityManagerFactory
- **Instalador não conecta no PostgreSQL** com `authentication type 10 is not supported`: o driver do instalador PEC pode não suportar autenticação SCRAM. Para banco local em Docker, inicializar PostgreSQL com autenticação host MD5 e `password_encryption=md5`.

## Compatibilidade com PostgreSQL

O instalador PEC pode usar driver PostgreSQL sem suporte a SCRAM-SHA-256. Em PostgreSQL moderno, isso aparece como:

```
The authentication type 10 is not supported.
```

Para bancos locais criados pelo Docker Compose, usar:

```yaml
command: ["postgres", "-c", "password_encryption=md5"]
environment:
  - POSTGRES_INITDB_ARGS=--auth-host=md5
```

Essa configuração só afeta a inicialização de um volume novo. Se o volume do PostgreSQL já foi criado com SCRAM, recriar o volume ou redefinir a senha do usuário com `password_encryption=md5`.

## JAR, latest release e instalação persistida

`build.sh` só busca o latest release quando `filename` está vazio. A origem do JAR pode ser:

- `-f <arquivo-ou-url>`
- `FILENAME` no `.env` ou `cloud/.env`
- `scripts/get-latest-pec-release.sh --url-only`, quando nenhum JAR foi informado

No modo cloud, `/opt/e-SUS` é persistido por bind mount:

```yaml
./esus-data/opt:/opt/e-SUS
```

Rebuild da imagem pode copiar um JAR novo para `/var/www/html`, mas isso não garante substituição do webserver já instalado em `/opt/e-SUS/webserver`. Quando houver mismatch, verificar:

```bash
docker compose exec db psql -U postgres -d esus -c \
  "SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';"

unzip -l cloud/esus-data/opt/webserver/pec-bundle.jar | grep 'backend-'
```

Se o webserver persistido estiver em versão antiga, preservar chaves/configurações necessárias e recriar ou limpar a instalação persistida antes de reinstalar.
"⚠️ Atenção ao atualizar para produção: o valor antigo (https://esus.dominio.com.br) pode ser restaurado quando necessário."