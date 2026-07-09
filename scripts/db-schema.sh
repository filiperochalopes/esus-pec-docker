#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./cloud/compose.yml}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-esus}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <term> [term2 ...]   (plain substrings, no flags, no regex)" >&2
  exit 1
fi

CONDS=""
for TERM in "$@"; do
  if [[ "$TERM" == -* ]]; then
    echo "Error: '$TERM' looks like a flag. This script takes plain substrings only, e.g.: $0 atend lotacao" >&2
    exit 1
  fi
  TERM="${TERM//\'/}"
  [[ -n "$CONDS" ]] && CONDS+=" OR "
  CONDS+="table_name ILIKE '%${TERM}%'"
done

docker compose -f "$COMPOSE_FILE" exec -T "$DB_SERVICE" \
  psql -U "$DB_USER" -d "$DB_NAME" -q -v ON_ERROR_STOP=1 -P pager=off <<SQL
SELECT
  table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND ($CONDS)
ORDER BY table_name;
SQL
