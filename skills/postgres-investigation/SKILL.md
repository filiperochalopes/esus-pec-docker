# SKILL.md — PostgreSQL Sensitive Data Investigation

## Objetivo

Investigar dados sensíveis em banco PostgreSQL com segurança, reprodutibilidade e baixa chance de alucinação de schema.

Esta skill deve ser usada sempre que a tarefa envolver:

- investigação em banco PostgreSQL;
- análise de dados sensíveis;
- e-SUS PEC ou bases clínicas;
- identificação de relações entre tabelas;
- auditoria, rastreabilidade ou inconsistências de dados.

## Antes da primeira investigação do dia:

1. Rodar ./scripts/db-healthcheck.sh
2. Se falhar com Docker permission denied, parar.
3. Se passar, continuar para introspecção.

## Regras obrigatórias

1. Nunca assumir que uma tabela, coluna, FK ou tipo existe.
2. Antes de escrever qualquer `SELECT` com joins, consultar o schema real.
3. Nunca usar `SELECT *` em tabelas grandes, exceto com `LIMIT 1` para inspeção inicial.
4. Nunca executar `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE INDEX`, `VACUUM FULL` ou qualquer DDL/DML.
5. Toda investigação deve ser feita em transação read-only.
6. Toda consulta exploratória deve ter `LIMIT`, exceto `COUNT(*)`.
7. Toda consulta deve usar `statement_timeout`.
8. Nunca exportar dados sensíveis completos para o prompt da LLM.
9. Preferir contagens, IDs técnicos, datas, status e amostras mascaradas.
10. Se houver erro de coluna/tabela inexistente, parar e voltar para introspecção. Não tentar corrigir por chute.
11. Registrar descobertas reutilizáveis em `KNOWLEDGE.md`.
12. Não registrar dados pessoais, nomes de pacientes, CNS, CPF, endereços, telefones, URLs privadas ou identificadores sensíveis em `KNOWLEDGE.md`.

## Fluxo obrigatório

### 1. Definir hipótese

Antes de consultar dados, escrever:

- pergunta da investigação;
- entidades envolvidas;
- período, se houver;
- tabelas candidatas;
- campos técnicos conhecidos;
- risco de exposição de dado sensível.

Exemplo:

```text
Hipótese:
Verificar se registros de atendimento profissional estão associados a uma lotação/profissional específico.

Tabelas candidatas:
- ta_atend_prof
- tb_lotacao
- tb_prof
- tb_ator_papel

Campos conhecidos:
- ta_atend_prof.co_lotacao
- tb_lotacao.co_seq_lotacao ou equivalente ainda precisa ser confirmado
```

### 2. Introspectar tabelas candidatas

Sempre executar antes de montar joins:

```sql
SELECT
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name ILIKE '%lotacao%'
ORDER BY table_name;
```

Depois:

```sql
SELECT
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tb_lotacao'
ORDER BY ordinal_position;
```

### 3. Confirmar chaves e relações

Usar constraints reais:

```sql
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND (
    tc.table_name IN ('ta_atend_prof', 'tb_lotacao')
    OR ccu.table_name IN ('ta_atend_prof', 'tb_lotacao')
  )
ORDER BY tc.table_name, kcu.column_name;
```

### 4. Só depois montar a query

Regras para query:

- usar aliases simples;
- comentar cada join;
- nunca usar coluna não validada;
- preferir `COUNT`, `GROUP BY`, `MIN`, `MAX`;
- só trazer amostra com `LIMIT 20`;
- mascarar campos textuais sensíveis.

### 5. Em caso de erro

Se ocorrer:

- `relation does not exist`;
- `column does not exist`;
- `operator does not exist`;
- erro de cast;
- erro de tipo;

então:

1. parar;
2. consultar `information_schema`;
3. corrigir com base no schema;
4. não repetir variações por tentativa e erro.

## Template seguro de execução

Toda investigação deve usar este padrão:

```sql
BEGIN READ ONLY;

SET LOCAL statement_timeout = '10s';
SET LOCAL idle_in_transaction_session_timeout = '30s';

-- consultas aqui

ROLLBACK;
```

## Padrões anti-alucinação

Proibido fazer:

```sql
SELECT * FROM tb_lotaca;
SELECT * FROM tb.lotacao;
SELECT ds_lotacao FROM tb_lotacao;
SELECT co_unico_lotaca FROM tb_lotacao;
```

Apenas usar nomes confirmados por:

```sql
information_schema.tables
information_schema.columns
\d nome_tabela
```

## Consultas úteis de introspecção

### Listar tabelas por termo

```sql
SELECT
  table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name ILIKE '%' || :'term' || '%'
ORDER BY table_name;
```

### Listar colunas por termo

```sql
SELECT
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name ILIKE '%' || :'term' || '%'
ORDER BY table_name, ordinal_position;
```

### Descrever uma tabela

```sql
SELECT
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  character_maximum_length,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = :'table'
ORDER BY ordinal_position;
```

### Ver tamanho aproximado das tabelas

```sql
SELECT
  relname AS table_name,
  n_live_tup AS estimated_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

### Ver FKs de uma tabela

```sql
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
 AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name = :'table'
ORDER BY tc.table_name, kcu.column_name;
```

## Saída esperada da LLM

A LLM deve responder sempre neste formato:

```text
Hipótese:
...

Schema confirmado:
- tabela.coluna tipo
- tabela.coluna tipo

Relações confirmadas:
- tabela_a.coluna -> tabela_b.coluna

Consulta proposta:
...

Risco de exposição:
baixo/médio/alto

Resultado:
...

Próximo passo:
...
```

## Regras para KNOWLEDGE.md

Adicionar somente conhecimento reutilizável, como:

```markdown
## e-SUS PEC — Relações de atendimento profissional

- `ta_atend_prof.co_lotacao` referencia a lotação usada no atendimento profissional.
- `tb_lotacao` usa coluna `...` como chave técnica. Confirmado por `information_schema` em YYYY-MM-DD.
- Não usar `tb_lotaca`: essa tabela não existe no schema PostgreSQL analisado.
```

Não adicionar:

- nomes de profissionais;
- nomes de pacientes;
- UUIDs reais de produção;
- CNS, CPF, telefones, endereços;
- dumps;
- URLs internas;
- senhas;
- prints de dados sensíveis.

## Classificação obrigatória de erros

Antes de tentar corrigir qualquer comando, classificar o erro em uma destas categorias:

### 1. Erro de schema SQL

Exemplos:

```text
relation "..." does not exist
column "..." does not exist
operator does not exist
function does not exist
```

Ação obrigatória:

1. Parar a query atual.
2. Consultar `information_schema.tables` ou `information_schema.columns`.
3. Corrigir somente com base no schema real.
4. Não tentar variações por chute.

Proibido:

- trocar `tb_lotacao` por `tb_lotaca`;
- trocar `tb_lotacao` por `tb.lotacao`;
- remover letras finais de nomes de tabelas/colunas;
- criar aliases ou subqueries para contornar coluna inexistente.

### 2. Erro de ambiente, Docker ou permissão

Exemplos:

```text
permission denied while trying to connect to the docker API
Cannot connect to the Docker daemon
Is the docker daemon running?
Got permission denied while trying to connect to the Docker daemon socket
```

Ação obrigatória:

1. Parar a investigação SQL.
2. Informar que o problema é de acesso ao Docker, não do banco.
3. Não alterar SQL.
4. Não trocar nomes de tabelas.
5. Não tentar Python, `psql`, `docker exec` alternativo ou query diferente até o acesso Docker ser restaurado.

Diagnóstico permitido:

```bash
docker ps
docker compose -f ./cloud/compose.yml ps
ls -l /var/run/docker.sock 2>/dev/null || true
ls -l "$HOME/.docker/run/docker.sock" 2>/dev/null || true
id
groups
```

Em macOS com Docker Desktop, também verificar manualmente se o Docker Desktop está aberto e se o contexto Docker está correto.

### 3. Erro de uso do psql

Exemplos:

```text
psql: warning: extra command-line argument "SELECT ..." ignored
invalid command
syntax error at or near "\"
```

Ação obrigatória:

1. Corrigir a forma de chamada do `psql`.
2. Não alterar a query lógica ainda.
3. Não inferir que tabela ou coluna está errada.

Forma correta para SQL inline:

```bash
docker compose -f ./cloud/compose.yml exec -T db \
  psql -U postgres -d esus -v ON_ERROR_STOP=1 \
  -c "SELECT 1 AS test;"
```

Forma correta para heredoc:

```bash
docker compose -f ./cloud/compose.yml exec -T db \
  psql -U postgres -d esus -v ON_ERROR_STOP=1 <<'QUERY'
SELECT 1 AS test;
QUERY
```

Forma incorreta:

```bash
psql -U postgres -d esus "SELECT 1;"
```

Porque o SQL vira argumento extra e é ignorado pelo `psql`.

## Política de reação a erros

A LLM deve seguir esta ordem:

1. O comando chegou ao PostgreSQL?
2. Se não chegou, resolver ambiente/comando.
3. Se chegou e erro é de schema, introspectar schema.
4. Se chegou e erro é de sintaxe SQL, corrigir sintaxe.
5. Se chegou e erro é de tipo/cast, consultar tipos reais.
6. Nunca misturar correção de ambiente com correção de SQL.

## Sinais de que o comando não chegou ao banco

Se a saída contém qualquer uma das mensagens abaixo, considerar que a query não foi executada no PostgreSQL:

```text
permission denied while trying to connect to the docker API
Cannot connect to the Docker daemon
psql: warning: extra command-line argument
docker: permission denied
```

Nestes casos, é proibido concluir qualquer coisa sobre tabelas, colunas ou dados.

## Regra especial para modelos pequenos

Ao usar modelos pequenos, como Qwen 9B, aplicar estas restrições adicionais:

1. Não executar mais de uma tentativa SQL após erro sem introspecção.
2. Não modificar nomes de tabelas ou colunas por similaridade textual.
3. Não pluralizar, singularizar, abreviar ou remover acentos/letras de nomes SQL.
4. Não usar nomes sugeridos pela mensagem de erro sem confirmar em `information_schema`.
5. Se o mesmo erro ocorrer duas vezes, parar e produzir diagnóstico em vez de continuar tentando.
6. Preferir comandos auxiliares determinísticos a SQL livre.
7. Produzir no máximo uma query final por ciclo de investigação.

Checklist obrigatório antes de executar query final:

```text
[ ] Todas as tabelas existem em information_schema.tables.
[ ] Todas as colunas existem em information_schema.columns.
[ ] Tipos de colunas usadas em joins/filtros foram conferidos.
[ ] A query é SELECT-only.
[ ] A query tem LIMIT quando retorna linhas.
[ ] A query usa read-only transaction ou wrapper seguro.
[ ] O último erro, se houver, não era Docker/permissão/psql.
```
