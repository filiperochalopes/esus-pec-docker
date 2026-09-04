#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Uso:
  sh scripts/resolve-pec-jar.sh [arquivo-ou-url]

Resolve qual JAR do e-SUS PEC usar e garante que ele fique na raiz do
repositório (exigido pelo build Docker, que faz COPY relativo a essa pasta).

- Sem argumento: descobre e baixa a última versão publicada via
  scripts/get-latest-pec-release.sh --url-only, o mesmo mecanismo que
  scripts/build.sh usa quando chamado sem -f. Pula o download se o arquivo já
  existir na raiz.
- Com uma URL: baixa (pulando se o arquivo já existir na raiz).
- Com um caminho local: copia para a raiz se ainda não estiver lá.

Imprime em stdout uma única linha "<caminho-absoluto-na-raiz> <versão>".
Mensagens de progresso vão para stderr.
EOF
}

if [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

INPUT="${1:-}"

if [ -z "$INPUT" ]; then
    command -v curl >/dev/null 2>&1 || {
        echo "Erro: curl não encontrado." >&2
        exit 1
    }
    INPUT=$("$SCRIPT_DIR/get-latest-pec-release.sh" --url-only)
    [ -n "$INPUT" ] || {
        echo "Erro: link de download não encontrado." >&2
        exit 1
    }
    echo "Última versão publicada: $INPUT" >&2
fi

case "$INPUT" in
    http://*|https://*)
        jar_filename=$(basename "$INPUT")
        jar_path="$REPO_ROOT/$jar_filename"
        if [ -f "$jar_path" ]; then
            echo "JAR já presente: $jar_filename" >&2
        else
            command -v curl >/dev/null 2>&1 || {
                echo "Erro: curl não encontrado." >&2
                exit 1
            }
            echo "Baixando $jar_filename..." >&2
            curl -fsSL -o "$jar_path.tmp" "$INPUT"
            mv "$jar_path.tmp" "$jar_path"
        fi
        ;;
    *)
        [ -f "$INPUT" ] || {
            echo "Erro: JAR não encontrado: $INPUT" >&2
            exit 1
        }
        source_dir=$(CDPATH= cd -- "$(dirname -- "$INPUT")" && pwd)
        source_path="$source_dir/$(basename "$INPUT")"
        jar_path="$REPO_ROOT/$(basename "$source_path")"
        if [ "$source_path" != "$jar_path" ]; then
            if [ -f "$jar_path" ]; then
                echo "JAR já presente em $jar_path; ignorando $source_path" >&2
            else
                cp "$source_path" "$jar_path"
            fi
        fi
        ;;
esac

version=$(basename "$jar_path" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
[ -n "$version" ] || {
    echo "Erro: não consegui extrair a versão do nome do arquivo: $(basename "$jar_path")" >&2
    exit 1
}

printf '%s %s\n' "$jar_path" "$version"
