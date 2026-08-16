#!/bin/sh
set -eu

BASE_URL="${PEC_BASE_URL:-https://sisaps.saude.gov.br/sistemas/esusaps}"
RELEASES_URL="${PEC_RELEASES_URL:-${BASE_URL%/}/docs/Versoes}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Erro: curl nao encontrado." >&2
  exit 1
fi

fetch() {
  curl -fsSL "$1"
}

first_match() {
  grep -Eo "$1" | sed -n '1p' || true
}

last_line_matching() {
  grep -E "$1" | sed -n '$p' || true
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

asset_url() {
  asset_path="$(printf '%s' "$1" | sed 's#^.*/assets/js/#assets/js/#')"
  printf '%s/%s\n' "${BASE_URL%/}" "$asset_path"
}

homepage_html="$(fetch "${BASE_URL%/}/")"
advertised_version="$(printf '%s' "$homepage_html" \
  | first_match 'Download([^[:alpha:]]+para[[:space:]]+(Windows|Linux))?[[:space:]]*-[[:space:]]*[Vv]ers[aã]o[[:space:]]+[0-9]+\.[0-9]+(\.[0-9]+)?' \
  | first_match '[0-9]+\.[0-9]+(\.[0-9]+)?')"

if [ -z "$advertised_version" ]; then
  echo "Erro: nao encontrei a versao no botao de download da pagina inicial." >&2
  exit 1
fi

major="$(printf '%s' "$advertised_version" | cut -d. -f1)"
minor="$(printf '%s' "$advertised_version" | cut -d. -f2)"
release_url="${RELEASES_URL%/}/versao_${major}_${minor}"

# O portal passou a centralizar os instaladores no post do blog da versão.
# Para versões completas, tente esse fluxo primeiro; a resolução pela página
# inicial abaixo permanece como compatibilidade com o layout anterior.
blog_slug="$(printf '%s' "$advertised_version" | tr '.' '-')"
blog_module_pattern="@site/blog/[^\"]*versao-${blog_slug}\.md\""

# O Docusaurus associa o download a um onClick e nao publica um href no HTML.
# Resolve apenas o chunk da pagina inicial, onde o handler e o link sao gerados.
main_js_path="$(printf '%s' "$homepage_html" | first_match "/[^\"']*assets/js/main\\.[^\"']+\\.js")"
runtime_js_path="$(printf '%s' "$homepage_html" | first_match "/[^\"']*assets/js/runtime~main\\.[^\"']+\\.js")"

if [ -z "$main_js_path" ] || [ -z "$runtime_js_path" ]; then
  echo "Erro: nao encontrei os bundles JavaScript da pagina inicial." >&2
  exit 1
fi

main_js="$(fetch "$(asset_url "$main_js_path")")"
chunk_id="$(printf '%s' "$main_js" \
  | first_match "n\\.e\\([0-9]+\\)[^\"]*\"${blog_module_pattern}" \
  | sed -E 's/.*n\.e\(([0-9]+)\).*/\1/' || true)"

if [ -z "$chunk_id" ]; then
  chunk_id="$(printf '%s' "$main_js" \
    | first_match "n\\.e\\([0-9]+\\)[^\"']+\"@site/src/pages/index\\.(js|jsx|ts|tsx)\"" \
    | sed -E 's/.*n\.e\(([0-9]+)\).*/\1/' || true)"
fi

if [ -z "$chunk_id" ]; then
  echo "Erro: nao encontrei o chunk JavaScript da pagina inicial." >&2
  exit 1
fi

runtime_js="$(fetch "$(asset_url "$runtime_js_path")")"
chunk_mappings="$(printf '%s' "$runtime_js" | grep -Eo "${chunk_id}:\"[a-z0-9]+\"" || true)"
mapping_count="$(printf '%s\n' "$chunk_mappings" | sed '/^$/d' | wc -l | tr -d ' ')"

if [ "$mapping_count" -eq 0 ]; then
  echo "Erro: nao consegui resolver o arquivo do chunk $chunk_id." >&2
  exit 1
fi

chunk_hash="$(printf '%s\n' "$chunk_mappings" | sed -n '$s/.*"\([a-z0-9]*\)"/\1/p')"
if [ "$mapping_count" -eq 1 ]; then
  chunk_name="$chunk_id"
else
  chunk_name="$(printf '%s\n' "$chunk_mappings" | sed -n '1s/.*"\([a-z0-9]*\)"/\1/p')"
fi

chunk_url="${BASE_URL%/}/assets/js/${chunk_name}.${chunk_hash}.js"
chunk_js="$(fetch "$chunk_url")"
version_pattern="$(printf '%s' "$advertised_version" | sed 's/\./\\./g')"
linux_link="$(printf '%s' "$chunk_js" \
  | grep -Eo "https?://[^[:space:]\"'<>]*Linux[^[:space:]\"'<>]*\\.(jar|zip)(\\?[^[:space:]\"'<>]*)?" \
  | last_line_matching "/${version_pattern}[./-]")"

if [ -n "$linux_link" ] && [ "$chunk_id" != "" ] && [ "$advertised_version" != "${major}.${minor}" ]; then
  release_url="${BASE_URL%/}/blog/versao-${blog_slug}"
fi

if [ -z "$linux_link" ]; then
  echo "Erro: link Linux nao encontrado para a versao $advertised_version." >&2
  exit 1
fi

version="$(printf '%s' "$linux_link" | first_match '[0-9]+\.[0-9]+\.[0-9]+')"
version="${version:-$advertised_version}"

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
    printf '"source":"sisaps homepage"'
    printf '}\n'
    ;;
esac
