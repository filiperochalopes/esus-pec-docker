#!/bin/bash

set -euo pipefail

REQUIRED_COMMANDS=(container curl jq)

check_dependencies() {
  local missing=()
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -ne 0 ]; then
    echo "Dependências ausentes: ${missing[*]}" >&2
    exit 1
  fi
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

create_env_file_if_needed() {
  if [ ! -f .env ]; then
    if [ -f .env.example ]; then
      cp .env.example .env
      echo "Arquivo .env criado a partir de .env.example. Edite se necessário."
    else
      echo "Arquivo .env não encontrado e .env.example indisponível."
      exit 1
    fi
  fi
}

strip_quotes() {
  local value="$1"
  value="${value%\'}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value#\"}"
  printf '%s' "$value"
}

load_env() {
  set -o allexport
  # shellcheck disable=SC2046
  source <(grep -v '^#' .env | sed '/^[[:space:]]*$/d')
  set +o allexport

  POSTGRES_DB=$(strip_quotes "${POSTGRES_DB:-esus}")
  POSTGRES_USER=$(strip_quotes "${POSTGRES_USER:-postgres}")
  POSTGRES_PASS=$(strip_quotes "${POSTGRES_PASS:-pass}")
  POSTGRES_HOST=$(strip_quotes "${POSTGRES_HOST:-db}")
  POSTGRES_PORT=$(strip_quotes "${POSTGRES_PORT:-5432}")
  HTTPS_DOMAIN=$(strip_quotes "${HTTPS_DOMAIN:-}")
  TZ=$(strip_quotes "${TZ:-America/Sao_Paulo}")
  FILENAME=$(strip_quotes "${FILENAME:-}")
}

determine_jar() {
  if [ -z "$FILENAME" ]; then
    echo "Buscando link do instalador mais recente..."
    local endpoint="https://n8n.adri.orango.io/webhook/b1b09703-6eff-42cc-a2a2-8affd46debd3"
    local response
    if ! response=$(curl -fsSL "$endpoint"); then
      echo "Não foi possível obter o link do instalador." >&2
      exit 1
    fi
    FILENAME=$(printf '%s' "$response" | jq -r '.link_linux')
    if [ -z "$FILENAME" ] || [ "$FILENAME" = "null" ]; then
      echo "Resposta inválida ao buscar link do instalador." >&2
      exit 1
    fi
  fi

  if echo "$FILENAME" | grep -Eq '^https?://'; then
    JAR_FILENAME=$(basename "$FILENAME")
    if [ ! -f "$JAR_FILENAME" ]; then
      echo "Baixando $JAR_FILENAME..."
      curl -fsSL "$FILENAME" -o "$JAR_FILENAME"
    else
      echo "Arquivo $JAR_FILENAME já disponível, reutilizando download."
    fi
  else
    if [ ! -f "$FILENAME" ]; then
      echo "Arquivo informado em FILENAME não encontrado: $FILENAME" >&2
      exit 1
    fi
    JAR_FILENAME=$(basename "$FILENAME")
    if [ "$FILENAME" != "$JAR_FILENAME" ]; then
      cp "$FILENAME" "$JAR_FILENAME"
    fi
  fi
}

prepare_volumes() {
  mkdir -p esus-data/db esus-data/opt esus-data/backups
}

cleanup_existing_container() {
  local name="$1"
  if container inspect "$name" >/dev/null 2>&1; then
    container stop "$name" >/dev/null 2>&1 || true
    container delete "$name" >/dev/null 2>&1 || true
  fi
}

build_image() {
  local image_name="$1"
  local jdbc_url="jdbc:postgresql://db:${POSTGRES_PORT}/${POSTGRES_DB}"
  local build_args=(
    "--tag" "$image_name"
    "--file" "apple/Dockerfile"
    "--build-arg" "JAR_FILENAME=$JAR_FILENAME"
    "--build-arg" "HTTPS_DOMAIN=$HTTPS_DOMAIN"
    "--build-arg" "DB_URL=$jdbc_url"
    "--build-arg" "POSTGRES_USER=$POSTGRES_USER"
    "--build-arg" "POSTGRES_PASS=$POSTGRES_PASS"
    "--build-arg" "TRAINING=true"
  )
  echo "Construindo imagem $image_name..."
  container build "${build_args[@]}" .
}

create_runtime_env_file() {
  RUNTIME_ENV_FILE=$(mktemp)
  cat > "$RUNTIME_ENV_FILE" <<EOF_ENV
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASS=$POSTGRES_PASS
POSTGRES_HOST=db
POSTGRES_PORT=$POSTGRES_PORT
HTTPS_DOMAIN=$HTTPS_DOMAIN
TZ=$TZ
TRAINING=true
EOF_ENV
}

start_database() {
  echo "Iniciando banco de dados..."
  container run --name db --detach \
    --env POSTGRES_USER="$POSTGRES_USER" \
    --env POSTGRES_PASSWORD="$POSTGRES_PASS" \
    --env POSTGRES_DB="$POSTGRES_DB" \
    --volume "$(pwd)/esus-data/db:/var/lib/postgresql/data" \
    postgres:9.6-alpine >/dev/null
}

start_pec() {
  local image_name="$1"
  echo "Iniciando PEC em modo treinamento..."
  container run --name pec --detach \
    --volume "$(pwd)/esus-data/opt:/opt/e-SUS" \
    --volume "$(pwd)/esus-data/backups:/backups" \
    --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --env-file "$RUNTIME_ENV_FILE" \
    --publish 8080:8080 \
    --publish 80:80 \
    --publish 443:443 \
    "$image_name" >/dev/null
}

main() {
  check_dependencies
  create_env_file_if_needed
  load_env
  determine_jar
  prepare_volumes

  echo "Iniciando serviço Apple Container..."
  container system start

  local image_name="pec-training"
  build_image "$image_name"

  cleanup_existing_container pec
  cleanup_existing_container db

  create_runtime_env_file
  trap 'rm -f "$RUNTIME_ENV_FILE"' EXIT

  start_database
  echo "Aguardando inicialização do banco..."
  sleep 10
  start_pec "$image_name"

  echo "Containers iniciados. Acesse http://localhost:8080"
}

main "$@"
