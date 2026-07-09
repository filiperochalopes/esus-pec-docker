#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./cloud/compose.yml}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-esus}"
ARG="${1:-}"

if [[ -z "$ARG" ]]; then
  echo "Usage: $0 <query.sql | \"SELECT ...\">" >&2
  exit 1
fi

if [[ -f "$ARG" ]]; then
  SQL_BODY="$(cat "$ARG")"
else
  SQL_BODY="$ARG"
fi

if grep -Eiq '\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|vacuum|reindex|copy)\b' <<<"$SQL_BODY"; then
  echo "Refusing to run query: forbidden SQL keyword found." >&2
  exit 2
fi

if grep -Eiq '\b(begin|commit|rollback|start transaction)\b' <<<"$SQL_BODY"; then
  echo "Do not include BEGIN/COMMIT/ROLLBACK: this script already wraps the query in a read-only transaction." >&2
  exit 2
fi

# Strip trailing whitespace and guarantee exactly one terminating semicolon
SQL_BODY="$(printf '%s' "$SQL_BODY" | sed -e 's/[[:space:]]*$//')"
SQL_BODY="${SQL_BODY%;};"

{
  printf '%s\n' \
    "BEGIN READ ONLY;" \
    "SET LOCAL statement_timeout = '10s';" \
    "SET LOCAL idle_in_transaction_session_timeout = '30s';"
  printf '%s\n' "$SQL_BODY"
  printf '%s\n' "ROLLBACK;"
} | docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" \
      psql -U "$DB_USER" -d "$DB_NAME" -q -v ON_ERROR_STOP=1 -P pager=off
