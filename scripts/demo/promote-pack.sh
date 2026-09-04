#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Uso:
  sh scripts/demo/promote-pack.sh --backup ARQUIVO.backup --jar NOME_DO_JAR --pec-version VERSAO

Promove o resultado de uma execução de build-demo-backup.sh feita com
--upgrade-jar/--upgrade-pec-version a novo pack-base canônico: substitui
scripts/demo/pack/base.backup, clinical_manifest.json e pack.json, e atualiza
DEFAULT_PEC_VERSION em src/pec_demo/version.py. Seed, município, UF e CEP são
herdados do pack.json atual, pois não dependem da versão do PEC.

ARQUIVO.backup e o .clinical-manifest.json irmão publicado pelo mesmo
build-demo-backup.sh (mesmo prefixo) são a fonte. NOME_DO_JAR deve existir em
REPO_ROOT/NOME_DO_JAR, igual ao usado no --upgrade-jar da build.

Exemplo:
  sh scripts/demo/build-demo-backup.sh \
    --upgrade-jar eSUS-AB-PEC-5.5.25-Linux64.jar \
    --upgrade-pec-version 5.5.25

  sh scripts/demo/promote-pack.sh \
    --backup scripts/demo/output/pec-demo-5.5.25.backup \
    --jar eSUS-AB-PEC-5.5.25-Linux64.jar \
    --pec-version 5.5.25

O pack anterior não é preservado em disco após a promoção (o script
sobrescreve scripts/demo/pack/ diretamente); ele continua recuperável pelo
histórico do Git/LFS caso seja preciso comparar versões.
EOF
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
PACK_DIR="$SCRIPT_DIR/pack"

BACKUP=
JAR_FILENAME=
PEC_VERSION=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --backup)
            [ "$#" -ge 2 ] || { echo "Falta valor para --backup" >&2; exit 2; }
            BACKUP=$2
            shift 2
            ;;
        --jar)
            [ "$#" -ge 2 ] || { echo "Falta valor para --jar" >&2; exit 2; }
            JAR_FILENAME=$2
            shift 2
            ;;
        --pec-version)
            [ "$#" -ge 2 ] || { echo "Falta valor para --pec-version" >&2; exit 2; }
            PEC_VERSION=$2
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$BACKUP" ] && [ -n "$JAR_FILENAME" ] && [ -n "$PEC_VERSION" ] || {
    echo "Informe --backup, --jar e --pec-version." >&2
    usage >&2
    exit 2
}

for command_name in python3 shasum; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Dependência ausente: $command_name" >&2
        exit 1
    }
done

[ -f "$BACKUP" ] || { echo "Backup não encontrado: $BACKUP" >&2; exit 1; }

OUTPUT_DIR=$(CDPATH= cd -- "$(dirname -- "$BACKUP")" && pwd)
OUTPUT_NAME=$(basename "$BACKUP" .backup)
MANIFEST="$OUTPUT_DIR/$OUTPUT_NAME.clinical-manifest.json"
[ -f "$MANIFEST" ] || {
    echo "Manifesto clínico irmão não encontrado: $MANIFEST" >&2
    exit 1
}

JAR_PATH="$REPO_ROOT/$JAR_FILENAME"
[ -f "$JAR_PATH" ] || { echo "JAR não encontrado: $JAR_PATH" >&2; exit 1; }

OLD_PACK_METADATA="$PACK_DIR/pack.json"
[ -f "$OLD_PACK_METADATA" ] || {
    echo "pack.json atual não encontrado: $OLD_PACK_METADATA" >&2
    exit 1
}

sha256_file() {
    shasum -a 256 "$1" | awk '{print $1}'
}

NEW_BASE_BACKUP_SHA=$(sha256_file "$BACKUP")
NEW_MANIFEST_SHA=$(sha256_file "$MANIFEST")
NEW_JAR_SHA=$(sha256_file "$JAR_PATH")

cp "$BACKUP" "$PACK_DIR/base.backup.tmp"
cp "$MANIFEST" "$PACK_DIR/clinical_manifest.json.tmp"

python3 - \
    "$OLD_PACK_METADATA" "$PACK_DIR/pack.json.tmp" \
    "$PEC_VERSION" "$JAR_FILENAME" \
    "$NEW_JAR_SHA" "$NEW_BASE_BACKUP_SHA" "$NEW_MANIFEST_SHA" <<'PY'
import json
import sys

old_path, new_path, pec_version, jar_filename, jar_sha, backup_sha, manifest_sha = sys.argv[1:8]

data = json.load(open(old_path, encoding="utf-8"))
data["pec_version"] = pec_version
data["base_backup"] = {"filename": "base.backup", "sha256": backup_sha}
data["clinical_manifest"] = {
    "filename": "clinical_manifest.json",
    "sha256": manifest_sha,
}
data["jar"] = {"filename": jar_filename, "sha256": jar_sha}

with open(new_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

mv "$PACK_DIR/base.backup.tmp" "$PACK_DIR/base.backup"
mv "$PACK_DIR/clinical_manifest.json.tmp" "$PACK_DIR/clinical_manifest.json"
mv "$PACK_DIR/pack.json.tmp" "$PACK_DIR/pack.json"

VERSION_FILE="$SCRIPT_DIR/src/pec_demo/version.py"
python3 - "$VERSION_FILE" "$PEC_VERSION" <<'PY'
import re
import sys

path, version = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
new_text, count = re.subn(
    r'DEFAULT_PEC_VERSION = "[^"]*"',
    f'DEFAULT_PEC_VERSION = "{version}"',
    text,
)
if count != 1:
    sys.exit(f"esperava 1 substituição em {path}, encontrei {count}")
open(path, "w", encoding="utf-8").write(new_text)
PY

echo "Pack promovido para PEC $PEC_VERSION."
echo "  pack/base.backup, pack/clinical_manifest.json e pack.json atualizados."
echo "  DEFAULT_PEC_VERSION atualizado em src/pec_demo/version.py."
echo
echo "Falta:"
echo "  - revisar 'git status'/'git diff' em scripts/demo/pack/ e version.py;"
echo "  - atualizar a seção \"Versão atual\" em scripts/demo/README.md;"
echo "  - rodar 'uv run pytest' antes de comitar."
