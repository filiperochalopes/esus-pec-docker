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
# Consultas ao banco: SEMPRE via scripts (nunca psql direto)
./scripts/db-safe-query.sh "SELECT co_config_sistema, ds_texto FROM tb_config_sistema;"

# Logs
docker compose logs -f pec
docker compose exec pec cat /opt/e-SUS/webserver/logs/pec.log

# Reiniciar
docker compose restart pec
```

Escrita no banco (ex: atualizar `LINKINSTALACAO`) é operação manual do administrador — agentes não executam UPDATE.

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

## Banco de dados: regra obrigatória

Qualquer consulta ao banco usa APENAS estes scripts (nunca `psql`, `docker compose exec ... psql`, Python ou SQL manual):

```bash
./scripts/db-healthcheck.sh              # sempre o 1º comando
./scripts/db-schema.sh <termo> [termo2]  # achar tabelas
./scripts/db-columns.sh <tabela>         # confirmar colunas
./scripts/db-fks.sh <tabela>             # confirmar joins
./scripts/db-safe-query.sh arquivo.sql   # executar SELECT (read-only + timeout)
```

- SQL próprio: grave em arquivo com heredoc `<<'EOF'` e rode `db-safe-query.sh arquivo.sql`. Nunca SQL inline na linha de comando.
- Confirme tabelas/colunas/FKs com os scripts ANTES de escrever a query. Copie nomes da saída; nunca digite de memória.
- Após `column does not exist`: o próximo comando é obrigatoriamente `db-columns.sh`, nunca outra query.
- Erro `permission denied ... docker` = problema de ambiente: PARE, não mude o SQL, não use fallback.
- Erro `does not exist` = volte para `db-schema.sh`/`db-columns.sh`. Mesmo erro 2x: pare e reporte.
- Apenas SELECT, sempre com `LIMIT` (exceto COUNT). Nunca copie dados pessoais (nomes, CPF, CNS) para respostas ou arquivos.
- Detalhes: `skills/postgres-investigation/SKILL.md`.