#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

DOWNLOAD_URL=$("$ROOT_DIR/scripts/get-latest-pec-release.sh" --url-only)

# Verifica se encontrou o link
if [ -z "$DOWNLOAD_URL" ]; then
  echo "Erro: Link para download não encontrado."
  exit 1
fi

# Exibe o link encontrado
echo "Link para download encontrado: $DOWNLOAD_URL"

# Baixa o arquivo
wget "$DOWNLOAD_URL"
