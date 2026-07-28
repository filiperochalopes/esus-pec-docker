#!/usr/bin/env bash

set -o pipefail

JAR_FILE="${1:-}"

if [ -z "$JAR_FILE" ]; then
  echo "Uso:"
  echo "  $0 <jarfile> [output-directory]"
  echo
  echo "Exemplo:"
  echo "  $0 eSUS-AB-PEC-5.5.22-Linux64.jar"
  echo "  $0 eSUS-AB-PEC-5.5.22-Linux64.jar codebase-5.5.22"
  exit 1
fi

OUT="${2:-codebase}"
KNOWLEDGE_FILE="$OUT/KNOWLEDGE.md"
PRESERVED_KNOWLEDGE_DIR=""
PRESERVED_KNOWLEDGE_HASH=""

sha256_file() {
  local file="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{ print $1 }'
  else
    return 1
  fi
}

restore_preserved_knowledge() {
  [ -n "$PRESERVED_KNOWLEDGE_DIR" ] || return 0
  [ -f "$PRESERVED_KNOWLEDGE_DIR/KNOWLEDGE.md" ] || return 1

  mkdir -p "$OUT" || return 1
  cp -p "$PRESERVED_KNOWLEDGE_DIR/KNOWLEDGE.md" "$KNOWLEDGE_FILE" \
    || return 1

  local restored_hash
  restored_hash="$(sha256_file "$KNOWLEDGE_FILE")" || return 1
  [ "$restored_hash" = "$PRESERVED_KNOWLEDGE_HASH" ]
}

cleanup_preserved_knowledge() {
  if [ -n "$PRESERVED_KNOWLEDGE_DIR" ]; then
    local current_hash=""

    if [ -f "$KNOWLEDGE_FILE" ]; then
      current_hash="$(sha256_file "$KNOWLEDGE_FILE" 2>/dev/null || true)"
    fi

    if [ "$current_hash" != "$PRESERVED_KNOWLEDGE_HASH" ]; then
      restore_preserved_knowledge || {
        echo "ERRO: não foi possível restaurar $KNOWLEDGE_FILE" >&2
        return
      }
    fi

    rm -rf "$PRESERVED_KNOWLEDGE_DIR"
  fi
}

trap cleanup_preserved_knowledge EXIT

fail() {
  echo
  echo "ERRO: $*" >&2
  exit 1
}

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

count_lines() {
  local file="$1"

  if [ -f "$file" ]; then
    wc -l < "$file" | tr -d ' '
  else
    echo "0"
  fi
}

section "Configuração"

echo "JAR:   $JAR_FILE"
echo "Saída: $OUT"

test -f "$JAR_FILE" \
  || fail "Arquivo não encontrado: $JAR_FILE"

JAR_FILE="$(
  cd "$(dirname "$JAR_FILE")" \
    && printf '%s/%s\n' "$PWD" "$(basename "$JAR_FILE")"
)" || fail "Não foi possível resolver o caminho absoluto do JAR"

command -v java >/dev/null 2>&1 \
  || fail "java não encontrado no PATH"

command -v jar >/dev/null 2>&1 \
  || fail "jar não encontrado no PATH"

if command -v cfr-decompiler >/dev/null 2>&1; then
  CFR_BIN="$(command -v cfr-decompiler)"
elif command -v cfr >/dev/null 2>&1; then
  CFR_BIN="$(command -v cfr)"
else
  fail "CFR não encontrado. Instale com: brew install cfr-decompiler"
fi

RG_BIN=""

if command -v rg >/dev/null 2>&1; then
  RG_BIN="$(command -v rg)"
fi

section "Ferramentas"

java --version
jar --version

echo "CFR: $CFR_BIN"

if [ -n "$RG_BIN" ]; then
  echo "ripgrep: $RG_BIN"
else
  echo "Aviso: ripgrep não encontrado."
fi

section "Preparando diretórios"

if [ -f "$KNOWLEDGE_FILE" ]; then
  PRESERVED_KNOWLEDGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pec-codebase-knowledge.XXXXXX")" \
    || fail "Não foi possível criar diretório temporário para preservar KNOWLEDGE.md"
  cp -p "$KNOWLEDGE_FILE" "$PRESERVED_KNOWLEDGE_DIR/KNOWLEDGE.md" \
    || fail "Não foi possível preservar: $KNOWLEDGE_FILE"
  PRESERVED_KNOWLEDGE_HASH="$(sha256_file "$PRESERVED_KNOWLEDGE_DIR/KNOWLEDGE.md")" \
    || fail "Nenhuma ferramenta SHA-256 disponível para validar KNOWLEDGE.md"
  echo "KNOWLEDGE.md preservado: $PRESERVED_KNOWLEDGE_HASH"
fi

rm -rf "$OUT" \
  || fail "Não foi possível remover: $OUT"

mkdir -p \
  "$OUT/installer-extracted" \
  "$OUT/app-extracted" \
  "$OUT/frontend" \
  "$OUT/java-decompiled" \
  "$OUT/java-decompiled-selected" \
  "$OUT/reports" \
  || fail "Não foi possível criar a estrutura em: $OUT"

if [ -n "$PRESERVED_KNOWLEDGE_DIR" ]; then
  restore_preserved_knowledge \
    || fail "KNOWLEDGE.md restaurado diverge do arquivo preservado"
  echo "KNOWLEDGE.md restaurado e validado: $PRESERVED_KNOWLEDGE_HASH"
fi

section "Listando JAR externo"

jar tf "$JAR_FILE" \
  > "$OUT/reports/installer-contents.txt" \
  || fail "Não foi possível listar o conteúdo de: $JAR_FILE"

echo "Itens encontrados: $(count_lines "$OUT/reports/installer-contents.txt")"

section "Extraindo JAR externo"

(
  cd "$OUT/installer-extracted" || exit 1
  jar xf "$JAR_FILE"
) || fail "Falha ao extrair: $JAR_FILE"

EXPECTED_INNER_JAR="$OUT/installer-extracted/container/webserver/pec-bundle.jar"
INNER_JAR=""

if [ -f "$EXPECTED_INNER_JAR" ]; then
  INNER_JAR="$EXPECTED_INNER_JAR"
else
  echo
  echo "pec-bundle.jar não encontrado no caminho esperado."
  echo "Procurando JARs internos..."

  find "$OUT/installer-extracted" \
    -type f \
    -name '*.jar' \
    -print \
    | sort \
    | tee "$OUT/reports/nested-jars.txt"

  INNER_JAR="$(
    find "$OUT/installer-extracted" \
      -type f \
      -name 'pec-bundle.jar' \
      -print \
      -quit
  )"
fi

if [ -z "$INNER_JAR" ] || [ ! -f "$INNER_JAR" ]; then
  fail "Não foi possível localizar o pec-bundle.jar dentro de $JAR_FILE"
fi

section "Aplicação interna encontrada"

echo "$INNER_JAR"
ls -lh "$INNER_JAR"

section "Listando aplicação interna"

jar tf "$INNER_JAR" \
  > "$OUT/reports/app-contents.txt" \
  || fail "Não foi possível listar: $INNER_JAR"

echo "Itens encontrados: $(count_lines "$OUT/reports/app-contents.txt")"

echo
echo "Estrutura principal:"

awk -F/ '
  NF >= 1 { print $1 }
  NF >= 2 { print $1 "/" $2 }
  NF >= 3 { print $1 "/" $2 "/" $3 }
  NF >= 4 { print $1 "/" $2 "/" $3 "/" $4 }
' "$OUT/reports/app-contents.txt" \
  | sort -u \
  | head -300 \
  || true

section "Extraindo aplicação interna"

(
  cd "$OUT/app-extracted" || exit 1
  jar xf "../${INNER_JAR#"$OUT/"}"
) || {
  cp "$INNER_JAR" "$OUT/pec-bundle.jar" \
    || fail "Não foi possível copiar o JAR interno"

  (
    cd "$OUT/app-extracted" || exit 1
    jar xf "../pec-bundle.jar"
  ) || fail "Falha ao extrair o JAR interno"
}

section "Catalogando classes Java"

find "$OUT/app-extracted" \
  -type f \
  -name '*.class' \
  -print \
  | sort \
  > "$OUT/reports/class-files.txt"

CLASS_COUNT="$(count_lines "$OUT/reports/class-files.txt")"

echo "Classes encontradas: $CLASS_COUNT"

section "Catalogando arquivos web"

find "$OUT/app-extracted" \
  -type f \
  \( \
    -iname '*.html' -o \
    -iname '*.htm' -o \
    -iname '*.js' -o \
    -iname '*.mjs' -o \
    -iname '*.css' -o \
    -iname '*.map' -o \
    -iname '*.json' \
  \) \
  -print \
  | sort \
  | tee "$OUT/reports/web-assets.txt"

find "$OUT/app-extracted" \
  -type f \
  -iname 'index.html' \
  -print \
  | sort \
  | tee "$OUT/reports/index-files.txt"

find "$OUT/app-extracted" \
  -type f \
  -iname '*.map' \
  -print \
  | sort \
  | tee "$OUT/reports/source-maps.txt"

WEB_COUNT="$(count_lines "$OUT/reports/web-assets.txt")"
INDEX_COUNT="$(count_lines "$OUT/reports/index-files.txt")"
MAP_COUNT="$(count_lines "$OUT/reports/source-maps.txt")"

echo
echo "Assets web:  $WEB_COUNT"
echo "index.html:  $INDEX_COUNT"
echo "Source maps: $MAP_COUNT"

section "Catalogando diretórios de frontend"

find "$OUT/app-extracted" \
  -type d \
  \( \
    -iname 'static' -o \
    -iname 'public' -o \
    -iname 'assets' -o \
    -iname 'webapp' -o \
    -iname 'frontend' \
  \) \
  -print \
  | sort \
  | tee "$OUT/reports/frontend-directories.txt"

while IFS= read -r frontend_dir; do
  [ -d "$frontend_dir" ] || continue

  relative="${frontend_dir#"$OUT/app-extracted/"}"
  destination="$OUT/frontend/${relative//\//_}"

  mkdir -p "$destination"
  cp -R "$frontend_dir/." "$destination/" 2>/dev/null || true
done < "$OUT/reports/frontend-directories.txt"

section "Detectando framework frontend"

: > "$OUT/reports/frontend-framework-files.txt"

if [ -n "$RG_BIN" ]; then
  "$RG_BIN" \
    -i \
    -l \
    --glob '*.js' \
    --glob '*.mjs' \
    --glob '*.html' \
    --glob '*.json' \
    'react-dom|createRoot|createElement|webpackJsonp|__webpack_require__|angular|vue|vite' \
    "$OUT/app-extracted" \
    > "$OUT/reports/frontend-framework-files.txt" \
    2>/dev/null \
    || true
fi

head -100 "$OUT/reports/frontend-framework-files.txt" || true

section "Catalogando configurações"

find "$OUT/app-extracted" \
  -type f \
  \( \
    -iname 'application*.properties' -o \
    -iname 'application*.yml' -o \
    -iname 'application*.yaml' -o \
    -iname 'bootstrap*.properties' -o \
    -iname 'bootstrap*.yml' -o \
    -iname 'bootstrap*.yaml' -o \
    -iname 'logback*.xml' -o \
    -iname 'log4j*.properties' -o \
    -iname 'MANIFEST.MF' \
  \) \
  -print \
  | sort \
  | tee "$OUT/reports/config-files.txt"

section "Decompilando aplicação"

echo "Origem:"
echo "  $INNER_JAR"

echo
echo "Destino:"
echo "  $OUT/java-decompiled"

echo
echo "Log:"
echo "  $OUT/reports/cfr.log"

"$CFR_BIN" \
  "$INNER_JAR" \
  --outputdir "$OUT/java-decompiled" \
  --silent true \
  > "$OUT/reports/cfr.log" \
  2>&1

CFR_EXIT_CODE=$?

if [ "$CFR_EXIT_CODE" -ne 0 ]; then
  echo
  echo "Aviso: CFR terminou com código $CFR_EXIT_CODE."
  echo "A saída parcial foi preservada."
  echo
  tail -100 "$OUT/reports/cfr.log" || true
fi

section "Decompilando módulos internos da aplicação"

BACKEND_MODULE="$(
  find "$OUT/app-extracted/BOOT-INF/lib" \
    -maxdepth 1 \
    -type f \
    -name 'backend-*.jar' \
    -print \
    -quit \
    2>/dev/null
)"

if [ -n "$BACKEND_MODULE" ]; then
  BACKEND_BASENAME="$(basename "$BACKEND_MODULE")"
  APP_VERSION="${BACKEND_BASENAME#backend-}"
  APP_VERSION="${APP_VERSION%.jar}"

  find "$OUT/app-extracted/BOOT-INF/lib" \
    -maxdepth 1 \
    -type f \
    -name "*-${APP_VERSION}.jar" \
    -print \
    | sort \
    > "$OUT/reports/application-module-jars.txt"

  MODULE_COUNT="$(count_lines "$OUT/reports/application-module-jars.txt")"
  echo "Versão detectada: $APP_VERSION"
  echo "Módulos da aplicação: $MODULE_COUNT"

  while IFS= read -r module_jar; do
    [ -f "$module_jar" ] || continue
    echo "Decompilando módulo: $(basename "$module_jar")"

    "$CFR_BIN" \
      "$module_jar" \
      --outputdir "$OUT/java-decompiled" \
      --silent true \
      >> "$OUT/reports/cfr.log" \
      2>&1

    module_exit_code=$?
    if [ "$module_exit_code" -ne 0 ]; then
      echo "Aviso: CFR falhou no módulo $(basename "$module_jar")"
      CFR_EXIT_CODE="$module_exit_code"
    fi
  done < "$OUT/reports/application-module-jars.txt"
else
  APP_VERSION="não detectada"
  MODULE_COUNT="0"
  : > "$OUT/reports/application-module-jars.txt"
  echo "Nenhum backend-<versão>.jar encontrado; módulos internos não decompilados."
fi

find "$OUT/java-decompiled" \
  -type f \
  -name '*.java' \
  -print \
  | sort \
  > "$OUT/reports/decompiled-java-files.txt"

DECOMPILED_COUNT="$(count_lines "$OUT/reports/decompiled-java-files.txt")"

echo
echo "Arquivos Java decompilados: $DECOMPILED_COUNT"

section "Criando decompilador seletivo"

cat > "$OUT/decompile-class.sh" <<DECOMPILE_EOF
#!/usr/bin/env bash

CLASS_FILE="\${1:-}"
OUTPUT_DIR="\${2:-$OUT/java-decompiled-selected}"

if [ -z "\$CLASS_FILE" ]; then
  echo "Uso:"
  echo "  \$0 <class-file> [output-directory]"
  exit 1
fi

if [ ! -f "\$CLASS_FILE" ]; then
  echo "Classe não encontrada: \$CLASS_FILE" >&2
  exit 1
fi

mkdir -p "\$OUTPUT_DIR"

"$CFR_BIN" \
  "\$CLASS_FILE" \
  --outputdir "\$OUTPUT_DIR" \
  --silent true
DECOMPILE_EOF

chmod +x "$OUT/decompile-class.sh"

section "Gerando relatório"

cat > "$OUT/reports/summary.txt" <<SUMMARY_EOF
JAR externo:
  $JAR_FILE

Aplicação interna:
  $INNER_JAR

Diretórios:
  Instalador extraído:
    $OUT/installer-extracted

  Aplicação extraída:
    $OUT/app-extracted

  Frontend consolidado:
    $OUT/frontend

  Java decompilado:
    $OUT/java-decompiled

Contagens:
  Classes encontradas:
    $CLASS_COUNT

  Módulos internos da aplicação:
    $MODULE_COUNT

  Arquivos Java decompilados:
    $DECOMPILED_COUNT

  Assets web:
    $WEB_COUNT

  Arquivos index.html:
    $INDEX_COUNT

  Source maps:
    $MAP_COUNT

Relatórios:
  $OUT/reports/installer-contents.txt
  $OUT/reports/app-contents.txt
  $OUT/reports/class-files.txt
  $OUT/reports/decompiled-java-files.txt
  $OUT/reports/application-module-jars.txt
  $OUT/reports/web-assets.txt
  $OUT/reports/frontend-framework-files.txt
  $OUT/reports/cfr.log
SUMMARY_EOF

cat "$OUT/reports/summary.txt"

section "Uso de disco"

du -sh \
  "$OUT" \
  "$OUT/installer-extracted" \
  "$OUT/app-extracted" \
  "$OUT/frontend" \
  "$OUT/java-decompiled" \
  2>/dev/null \
  || true

section "Concluído"

echo "Abra com:"
echo
echo "  code \"$OUT\""
echo
echo "Buscar um termo:"
echo
echo "  rg -i -n 'TERMO' \"$OUT/java-decompiled\" \"$OUT/app-extracted\""
echo
echo "Ver o resumo:"
echo
echo "  cat \"$OUT/reports/summary.txt\""

if [ "$CFR_EXIT_CODE" -ne 0 ]; then
  exit "$CFR_EXIT_CODE"
fi
