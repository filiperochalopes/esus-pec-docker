# AGENTS.md — e-SUS-PEC (cloud)

## Regras de Conhecimento

- **Todo conhecimento reutilizável sobre a aplicação PEC, configuração, operação ou compatibilidade deve ser registrado em `KNOWLEDGE.md`** — a base cumulativa do projeto.
- Ao fazer busca, análise ou investigação, atualize `KNOWLEDGE.md` apenas com descobertas generalizáveis que facilitem próximas investigações.
- Não usar `KNOWLEDGE.md` como relatório de bugs, diário de incidente ou lista de logs.
- Nunca escrever dados confidenciais ou específicos de uma instalação (senhas, URLs de produção, nomes de instituições, nomes de pacientes, backups identificáveis) em arquivos de conhecimento.
- `KNOWLEDGE.md` é o arquivo de referência principal; este `AGENTS.md` aponta para ele e registra convenções do projeto.

## Estrutura do Projeto

```
cloud/
  compose.yml          # Docker Compose (pec + db)
  .env                 # Variáveis de ambiente
  build.sh             # Script de build/deploy com restauração de backup
esus-data/
  backups/             # Arquivos .backup e .sql para restauração
  opt/                 # /opt/e-SUS mapeado no container
entrypoint.sh          # Inicialização do container PEC
Dockerfile             # Imagem do container PEC
```

## Configurações do e-SUS-PEC

### Onde as configurações moram

| Local | O que armazena |
|-------|----------------|
| `tb_config_sistema` (banco) | Configurações globais: `LINKINSTALACAO`, `VERSAOBANCODADOS`, `TIPOINSTALACAO`, etc. |
| `/etc/pec.config` (container) | JSON de metadata da instalação (criado na 1ª inicialização) |
| `/opt/e-SUS/webserver/config/application.properties` | Config Spring Boot (apenas datasource) |

### Problemas conhecidos

- **Rotas quebradas**: `LINKINSTALACAO` aponta para URL de produção → atualizar para `http://localhost:8082`
- **App não inicia**: version mismatch entre JAR e banco → verificar `VERSAOBANCODADOS` vs versão do JAR

## Comandos úteis

```bash
# Acessar banco
docker compose exec db psql -U postgres -d esus

# Configurações do sistema
docker compose exec db psql -U postgres -d esus \
  -c "SELECT co_config_sistema, ds_texto FROM tb_config_sistema;"

# Atualizar URL base
docker compose exec db psql -U postgres -d esus \
  -c "UPDATE tb_config_sistema SET ds_texto = 'http://localhost:8082' WHERE co_config_sistema = 'LINKINSTALACAO';"

# Logs
docker compose logs -f pec
docker compose exec pec cat /opt/e-SUS/webserver/logs/pec.log

# Reiniciar
docker compose restart pec
```

## Fluxo de restauração

1. `sh build.sh -C -p -r <backup>`
2. Verificar versão: `VERSAOBANCODADOS` vs JAR
3. Atualizar `LINKINSTALACAO` para URL local
4. `docker compose restart pec`
5. Verificar logs

## Regras de trabalho

- Sempre verificar `KNOWLEDGE.md` antes de investigar configurações
- Registrar no `KNOWLEDGE.md` somente conhecimento aplicável novamente ao PEC
- Não catalogar bugs pontuais no `KNOWLEDGE.md`; transformar o achado em orientação operacional, Q&A ou Known Issue reutilizável

## Investigação em banco de dados sensível

- Use `skills/postgres-investigation/SKILL.md` para qualquer tarefa envolvendo PostgreSQL, e-SUS PEC ou dados sensíveis.
- Nunca investigar dados sensíveis usando tentativa e erro livre.
- Nunca assumir nomes de tabelas, colunas ou chaves.
- Antes de qualquer join, confirmar schema via `information_schema.columns` e FKs via `information_schema.table_constraints`.

- Preferir os scripts:
  - `scripts/db-schema.sh`
  - `scripts/db-columns.sh`
  - `scripts/db-fks.sh`
  - `scripts/db-safe-query.sh`

- Toda query deve ser read-only, com `statement_timeout`, `LIMIT` e saída mínima.
- Nunca usar `SELECT *` sem `LIMIT 1`.
- Nunca enviar dados pessoais completos para prompts de LLM.
- Registrar em `KNOWLEDGE.md` apenas descobertas reutilizáveis de schema, relações e padrões de investigação.
- Não registrar dados pessoais, identificadores de pacientes, nomes reais, CNS, CPF, endereços, telefones, URLs privadas ou dumps.

## Erros Docker, psql e SQL

Antes de reagir a erro em investigação de banco, classifique o erro:

- Docker/permissão: não é erro SQL. Parar e diagnosticar ambiente.
- Uso incorreto do `psql`: corrigir comando, não a query.
- Schema SQL: introspectar `information_schema`.
- Sintaxe SQL: corrigir SQL.
- Tipo/cast: consultar tipos reais em `information_schema.columns`.

Se aparecer:

```text
permission denied while trying to connect to the docker API
```

não tentar nova query SQL, não trocar tabela, não usar Python como fallback e não inferir nada sobre o banco.

Se aparecer:

```text
psql: warning: extra command-line argument "SELECT ..." ignored
```

usar `psql -c "SQL"` ou heredoc. Não passar SQL como argumento posicional.