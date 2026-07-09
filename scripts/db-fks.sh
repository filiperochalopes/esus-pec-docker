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
  AND (
    tc.table_name = '$TABLE'
    OR ccu.table_name = '$TABLE'
  )
ORDER BY tc.table_name, kcu.column_name;
SQL
)"

printf '%s\n' "$OUT"
if grep -q '(0 rows)' <<<"$OUT"; then
  echo "NOTE: no foreign keys declared for '$TABLE' (common in ta_* audit tables). Join columns must still be confirmed with ./scripts/db-columns.sh" >&2
fi
