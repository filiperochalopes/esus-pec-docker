#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./cloud/compose.yml}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-esus}"
ARG="${1:-}"

die() {
  echo "Error: $*" >&2
  exit 1
}

if [[ -z "$ARG" ]]; then
  echo "Usage: $0 <query.sql | \"SELECT ...\">" >&2
  exit 1
fi

if [[ -f "$ARG" ]]; then
  SQL_BODY="$(cat -- "$ARG")"
else
  SQL_BODY="$ARG"
fi

if [[ -z "${SQL_BODY//[[:space:]]/}" ]]; then
  die "empty SQL query"
fi

# Remove comentários antes da validação:
#   -- comentário de linha
#   /* comentário de bloco */
#
# Isso evita falsos positivos causados por palavras como DELETE ou UPDATE
# presentes apenas na documentação do arquivo.
SQL_FOR_VALIDATION="$(
  printf '%s' "$SQL_BODY" |
    perl -0777 -pe '
      s{/\*.*?\*/}{ }gs;
      s{--[^\r\n]*}{ }g;
    '
)"

# Limites explícitos de identificadores SQL.
# Evita depender de \b, que varia entre implementações do grep.
FORBIDDEN_WRITE_PATTERN='(^|[^[:alnum:]_])(insert|update|delete|truncate|drop|alter|create|grant|revoke|vacuum|reindex|copy)([^[:alnum:]_]|$)'
FORBIDDEN_TRANSACTION_PATTERN='(^|[^[:alnum:]_])(begin|commit|rollback)([^[:alnum:]_]|$)|(^|[^[:alnum:]_])start[[:space:]]+transaction([^[:alnum:]_]|$)'

if printf '%s\n' "$SQL_FOR_VALIDATION" |
  grep -Eiq "$FORBIDDEN_WRITE_PATTERN"; then
  echo "Refusing to run query: forbidden SQL keyword found." >&2

  echo "Matched lines:" >&2
  printf '%s\n' "$SQL_FOR_VALIDATION" |
    grep -Ein "$FORBIDDEN_WRITE_PATTERN" >&2 || true

  exit 2
fi

if printf '%s\n' "$SQL_FOR_VALIDATION" |
  grep -Eiq "$FORBIDDEN_TRANSACTION_PATTERN"; then
  echo "Do not include BEGIN/COMMIT/ROLLBACK: this script already wraps the query in a read-only transaction." >&2

  echo "Matched lines:" >&2
  printf '%s\n' "$SQL_FOR_VALIDATION" |
    grep -Ein "$FORBIDDEN_TRANSACTION_PATTERN" >&2 || true

  exit 2
fi

# Remove whitespace final e garante exatamente um ponto e vírgula.
SQL_BODY="$(
  printf '%s' "$SQL_BODY" |
    sed -e 's/[[:space:]]*$//'
)"
SQL_BODY="${SQL_BODY%;};"

{
  printf '%s\n' \
    "BEGIN READ ONLY;" \
    "SET LOCAL statement_timeout = '10s';" \
    "SET LOCAL idle_in_transaction_session_timeout = '30s';"

  printf '%s\n' "$SQL_BODY"

  printf '%s\n' "ROLLBACK;"
} |
  docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" \
    psql \
      -U "$DB_USER" \
      -d "$DB_NAME" \
      -q \
      -v ON_ERROR_STOP=1 \
      -P pager=off
