#!/bin/sh
set -eu

BASE_URL="${PEC_BASE_URL:-https://sisaps.saude.gov.br/sistemas/esusaps}"
BLOG_URL="${BASE_URL%/}/blog/"

if ! command -v curl >/dev/null 2>&1; then
  echo "Erro: curl nao encontrado." >&2
  exit 1
fi

fetch() {
  curl -fsSL "$1"
}

first_match() {
  grep -Eo "$1" | head -n 1 || true
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

blog_html="$(fetch "$BLOG_URL")"
release_url="$(printf '%s' "$blog_html" | first_match "https://sisaps\\.saude\\.gov\\.br/sistemas/esusaps/blog/versao-[0-9-]+")"

if [ -z "$release_url" ]; then
  echo "Erro: nao encontrei o post da ultima versao em $BLOG_URL." >&2
  exit 1
fi

slug="$(basename "$release_url")"
version="$(printf '%s' "$slug" | sed 's/^versao-//; s/-/./g')"
release_html="$(fetch "$release_url")"

linux_link="$(printf '%s' "$release_html" | first_match "https://arquivos\\.esus[^\"']+Linux64\\.jar")"

if [ -z "$linux_link" ]; then
  main_js_path="$(printf '%s' "$release_html" | first_match "/sistemas/esusaps/assets/js/main\\.[^\"']+\\.js")"

  if [ -z "$main_js_path" ]; then
    echo "Erro: nao encontrei o bundle main.js na pagina $release_url." >&2
    exit 1
  fi

  main_js_url="${BASE_URL%/}/${main_js_path#/sistemas/esusaps/}"
  main_js="$(fetch "$main_js_url")"
  chunk_id="$(printf '%s' "$main_js" \
    | grep -Eo "n\\.e\\([0-9]+\\)[^\"']+\"@site/blog/[0-9]{4}-[0-9]{2}-[0-9]{2}-${slug}\\.md" \
    | head -n 1 \
    | sed -E 's/.*n\.e\(([0-9]+)\).*/\1/' || true)"

  if [ -z "$chunk_id" ]; then
    echo "Erro: nao encontrei o chunk JS do post $slug." >&2
    exit 1
  fi

  runtime_js_path="$(printf '%s' "$release_html" | first_match "/sistemas/esusaps/assets/js/runtime~main\\.[^\"']+\\.js")"

  if [ -z "$runtime_js_path" ]; then
    echo "Erro: nao encontrei o runtime JS na pagina $release_url." >&2
    exit 1
  fi

  runtime_js_url="${BASE_URL%/}/${runtime_js_path#/sistemas/esusaps/}"
  runtime_js="$(fetch "$runtime_js_url")"
  chunk_name="$(printf '%s' "$runtime_js" | grep -Eo "${chunk_id}:\"[a-z0-9]+\"" | head -n 1 | sed -E 's/.*"([a-z0-9]+)"/\1/' || true)"
  chunk_hash="$(printf '%s' "$runtime_js" | grep -Eo "${chunk_id}:\"[a-z0-9]+\"" | tail -n 1 | sed -E 's/.*"([a-z0-9]+)"/\1/' || true)"

  if [ -z "$chunk_name" ] || [ -z "$chunk_hash" ]; then
    echo "Erro: nao consegui resolver o arquivo JS do chunk $chunk_id." >&2
    exit 1
  fi

  chunk_url="${BASE_URL%/}/assets/js/${chunk_name}.${chunk_hash}.js"
  chunk_js="$(fetch "$chunk_url")"
  linux_link="$(printf '%s' "$chunk_js" | first_match "https://arquivos\\.esus[^\"']+Linux64\\.jar")"
fi

if [ -z "$linux_link" ]; then
  echo "Erro: link Linux nao encontrado para a versao $version." >&2
  exit 1
fi

case "${1:-}" in
  --url-only)
    printf '%s\n' "$linux_link"
    ;;
  --version-only)
    printf '%s\n' "$version"
    ;;
  *)
    printf '{'
    printf '"versao_label":"%s",' "$(json_escape "$version")"
    printf '"url_release_page":"%s",' "$(json_escape "$release_url")"
    printf '"link_linux":"%s",' "$(json_escape "$linux_link")"
    printf '"source":"sisaps blog"'
    printf '}\n'
    ;;
esac
