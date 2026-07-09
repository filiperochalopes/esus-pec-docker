#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./cloud/compose.yml}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-esus}"
QUERY_FILE="${1:-}"

if [[ -z "$QUERY_FILE" || ! -f "$QUERY_FILE" ]]; then
  echo "Usage: $0 <query.sql>" >&2
  exit 1
fi

if grep -Eiq '\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|vacuum|reindex|copy)\b' "$QUERY_FILE"; then
  echo "Refusing to run query: forbidden SQL keyword found." >&2
  exit 2
fi

docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" \
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SET LOCAL idle_in_transaction_session_timeout = '30s';

\i /dev/stdin

ROLLBACK;
SQL < "$QUERY_FILE"
