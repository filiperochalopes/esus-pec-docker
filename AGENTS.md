# AGENTS.md — e-SUS-PEC (cloud)

## Regras de Conhecimento

- **Todo conhecimento reutilizável sobre a aplicação PEC, configuração, operação ou compatibilidade deve ser registrado em `docs/KNOWLEDGE.md`** — a base cumulativa do projeto.
- Ao fazer busca, análise ou investigação, atualize `docs/KNOWLEDGE.md` apenas com descobertas generalizáveis que facilitem próximas investigações.
- Não usar `docs/KNOWLEDGE.md` como relatório de bugs, diário de incidente ou lista de logs.
- Nunca escrever dados confidenciais ou específicos de uma instalação (senhas, URLs de produção, nomes de instituições, nomes de pacientes, backups identificáveis) em arquivos de conhecimento.
- `docs/KNOWLEDGE.md` é o arquivo de referência principal; este `AGENTS.md` aponta para ele e registra convenções do projeto.

## Estrutura do Projeto

```
Makefile               # Interface para instalação, atualização e codebase
cloud/
  compose.yml          # Docker Compose (pec + db)
  .env                 # Variáveis de ambiente
scripts/
  build.sh             # Build/deploy e restauração de backup
  update.sh            # Atualização de uma instalação existente
  entrypoint.sh        # Inicialização do container PEC
  install.sh           # Execução do instalador dentro da imagem
  gen-codebase.sh      # Gera o codebase a partir do JAR alvo
esus-data/
  backups/             # Arquivos .backup e .sql para restauração
  opt/                 # /opt/e-SUS mapeado no container
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
./scripts/db-safe-query.sh consulta.sql

# Logs
docker compose logs -f pec
docker compose exec pec cat /opt/e-SUS/webserver/logs/pec.log

# Reiniciar
docker compose restart pec
```

Escrita no banco (ex: atualizar `LINKINSTALACAO`) é operação manual do administrador — agentes não executam UPDATE.

## Fluxo de restauração

1. `make restore BACKUP=<backup>`
2. Verificar versão: `VERSAOBANCODADOS` vs JAR
3. Atualizar `LINKINSTALACAO` para URL local
4. `docker compose restart pec`
5. Verificar logs

## Regras de trabalho

- Sempre verificar `docs/KNOWLEDGE.md` antes de investigar configurações
- Registrar no `docs/KNOWLEDGE.md` somente conhecimento aplicável novamente ao PEC
- Não catalogar bugs pontuais no `docs/KNOWLEDGE.md`; transformar o achado em orientação operacional, Q&A ou Known Issue reutilizável

## Fronteira entre codebase e agente de dados sensíveis

- **Nunca delegar ao agente/modelo com acesso a dados sensíveis uma
  investigação que possa ser respondida pelo JAR, codebase decompilado,
  configurações, documentação ou arquivos locais.** Isso inclui classes,
  métodos, mutations/endpoints, validações de negócio, normalizadores, fluxos
  de persistência, hashing, atribuição de perfis e efeitos dos serviços.
- Antes de escrever um prompt para esse agente, investigar o codebase local da
  versão-alvo. O prompt externo deve conter somente lacunas que dependam
  materialmente de metadados ou conteúdo autorizado do PostgreSQL.
- Quando a lacuna for de schema, pedir apenas PKs, FKs, constraints, índices,
  defaults, triggers e códigos técnicos que não estejam demonstrados no
  codebase. Não pedir novamente comportamento Java já verificável localmente.
- Relatórios locais devem separar explicitamente:
  `CONFIRMADO NO CODEBASE`, `CONFIRMADO NO SCHEMA` e `NÃO CONFIRMADO`.
- O agente de dados sensíveis não deve ser usado como substituto de busca no
  codebase nem para economizar investigação local.

## Atualização segura do codebase decompilado

- O codebase deve ser gerado a partir do JAR exato da versão-alvo com
  `make codebase JAR=<jar> [OUTPUT=<diretório-de-saída>]` ou
  `./scripts/gen-codebase.sh <jar> [diretório-de-saída]`.
- Quando a saída já contém `KNOWLEDGE.md`, esse arquivo é patrimônio cumulativo
  e deve permanecer **byte a byte intacto** durante a regeneração.
- `scripts/gen-codebase.sh` preserva o arquivo fora do diretório de saída antes da
  limpeza, restaura-o imediatamente e compara o SHA-256. Falha de cópia ou
  divergência de hash deve abortar a geração.
- Depois da geração, confirmar:
  1. versão/JAR em `codebase/reports/summary.txt`;
  2. módulos internos em `reports/application-module-jars.txt`;
  3. quantidade não nula de Java em `reports/decompiled-java-files.txt`;
  4. hash do `codebase/KNOWLEDGE.md`.
- Não substituir o codebase diretamente por uma pasta paralela sem preservar
  `KNOWLEDGE.md`. Cópias temporárias só devem ser removidas depois das
  validações.
- Descobertas novas e reutilizáveis vão em `docs/KNOWLEDGE.md`. Não alterar
  o `codebase/KNOWLEDGE.md` durante uma simples atualização de versão.

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
- Apenas SELECT, sempre com `LIMIT` (exceto COUNT).
- Detalhes: `skills/postgres-investigation/SKILL.md`.
