#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./cloud/compose.yml}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-esus}"
TABLE="${1:-}"

if [[ -z "$TABLE" || "$TABLE" == -* ]]; then
  echo "Usage: $0 <table>   (exact table name, no flags). Ex: $0 tb_lotacao" >&2
  exit 1
fi
TABLE="${TABLE//\'/}"

OUT="$(docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" \
  psql -U "$DB_USER" -d "$DB_NAME" -q -v ON_ERROR_STOP=1 -P pager=off <<SQL
SELECT
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = '$TABLE'
ORDER BY ordinal_position;
SQL
)"

printf '%s\n' "$OUT"
if grep -q '(0 rows)' <<<"$OUT"; then
  echo "HINT: table '$TABLE' does not exist in schema public. Find the real name with: ./scripts/db-schema.sh <term>" >&2
  exit 3
fi
