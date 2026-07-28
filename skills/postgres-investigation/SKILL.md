---
name: postgres-investigation
description: Investigar o banco PostgreSQL do e-SUS PEC. Use SEMPRE que a tarefa envolver consultas, auditoria ou análise de dados no banco. Proíbe SQL manual via docker/psql; obriga o uso dos scripts em ./scripts/.
---

# Investigação no banco e-SUS PEC

## Limite de escopo antes de usar esta skill

Esta skill existe para perguntas que dependam materialmente do PostgreSQL.
Antes de consultar ou encaminhar trabalho ao agente/modelo com acesso a dados
sensíveis:

1. investigue localmente o JAR/codebase da versão-alvo;
2. responda localmente tudo que for demonstrável por classes, métodos,
   validações, mutations/endpoints, mapeamentos JPA, fluxos de serviço,
   normalização, hashing ou regras de importação;
3. reduza o escopo do banco às lacunas físicas restantes, como PK/FK,
   constraints, índices, defaults, triggers e códigos técnicos.

Nunca solicite ao agente de dados sensíveis investigação de codebase. Não
misture no mesmo prompt perguntas Java e perguntas de schema. Se um prompt
existente fizer isso, execute a parte de codebase localmente e reescreva o
prompt antes de encaminhá-lo.

## Regra única

NUNCA execute `docker compose exec ... psql`, `psql`, Python ou qualquer SQL manual.
Use SOMENTE os 5 scripts abaixo. Se um script falhar, NÃO tente outro caminho.

## Comandos (os únicos permitidos)

```bash
./scripts/db-healthcheck.sh              # 1º comando de toda investigação
./scripts/db-schema.sh <termo> [termo2]  # listar tabelas por termo. Ex: ./scripts/db-schema.sh atend lotacao
./scripts/db-columns.sh <tabela>         # colunas de uma tabela. Ex: ./scripts/db-columns.sh tb_lotacao
./scripts/db-fks.sh <tabela>             # FKs de/para uma tabela
./scripts/db-safe-query.sh arquivo.sql   # executa SELECT de um arquivo (read-only, timeout automático)
```

Regras de uso dos scripts:
- Sem flags (`-e`, `-t`, etc). Argumentos são termos/nomes simples.
- NÃO inclua `BEGIN`, `ROLLBACK` ou `COMMIT` na query — o script já envolve tudo em transação read-only.

## Como executar SQL próprio (único jeito permitido)

Nunca passe SQL inline na linha de comando (aspas quebram no shell). SEMPRE grave em arquivo e execute:

```bash
cat > /tmp/q.sql <<'EOF'
SELECT co_lotacao, COUNT(*)
FROM ta_atend_prof
WHERE co_lotacao IN (5048, 5049)
GROUP BY co_lotacao;
EOF
./scripts/db-safe-query.sh /tmp/q.sql
```

Antes de gravar o arquivo, TODA coluna usada deve ter aparecido literalmente na saída de `db-columns.sh` nesta conversa. Se não apareceu, rode `db-columns.sh` primeiro. Copie e cole os nomes — nunca digite de memória.

## Fluxo obrigatório (nesta ordem)

1. `./scripts/db-healthcheck.sh` — se falhar (ex: "permission denied ... docker"), PARE e informe que o Docker está inacessível. Não tente SQL.
2. `./scripts/db-schema.sh <termo>` — confirme que as tabelas existem.
3. `./scripts/db-columns.sh <tabela>` — confirme cada coluna que vai usar.
4. `./scripts/db-fks.sh <tabela>` — confirme os joins.
5. Só então: `./scripts/db-safe-query.sh "SELECT ..."` — uma query por vez, sempre com `LIMIT` (exceto `COUNT`).

## Se der erro

- `permission denied ... docker` / `Cannot connect to the Docker daemon` → problema de ambiente. PARE. Não mude o SQL, não use Python, não tente psql direto.
- `column/relation ... does not exist` → PROIBIDO executar outra query. O próximo comando DEVE ser `./scripts/db-columns.sh <tabela>` (ou `db-schema.sh`). Só depois reescreva o arquivo .sql copiando o nome exato da saída.
- `unmatched "` / `unmatched '` do shell → você passou SQL inline. Use o fluxo de arquivo acima.
- Mesmo erro 2 vezes → PARE e reporte o diagnóstico, sem nova tentativa.

## Regras de segurança

- Apenas SELECT. O script bloqueia escrita; não tente contornar.
- Nunca copie dados pessoais (nomes, CPF, CNS, endereços, telefones) para arquivo. Prefira contagens, IDs técnicos e datas. Em respostas pode exibir os dados pessoais quando utilizado com modelos locais e app que não envia dados para telemetria em nenhum servidor em nuvem.
- Descobertas reutilizáveis de schema/relações vão em `KNOWLEDGE.md` (sem dados pessoais).

## Formato de resposta

```text
Origem da evidência: SCHEMA (não codebase)
Schema confirmado: tabela.coluna ...
Query executada: (o comando ./scripts/db-safe-query.sh usado)
Resultado: ...
Próximo passo: ...
```
