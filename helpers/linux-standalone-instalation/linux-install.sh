#!/usr/bin/env bash

# Instalador interativo do e-SUS PEC para Ubuntu/Debian com systemd.
# Ordem: cliente PostgreSQL e pg_restore; depois Java, JAR e serviço PEC.
# Uso remoto recomendado:
#   bash <(curl -fsSL https://raw.githubusercontent.com/filiperochalopes/e-SUS-PEC/main/helpers/linux-standalone-instalation/linux-install.sh)

set -Eeuo pipefail

readonly PEC_BASE_URL="${PEC_BASE_URL:-https://sisaps.saude.gov.br/sistemas/esusaps}"
readonly PEC_RELEASES_URL="${PEC_RELEASES_URL:-${PEC_BASE_URL%/}/docs/Versoes}"
readonly DOWNLOAD_DIR="${PEC_DOWNLOAD_DIR:-/var/tmp/e-sus-pec-installer}"
readonly SERVICE_NAME="e-SUS-PEC.service"
readonly POSTGRES_CLIENT_MAJOR="${PEC_POSTGRES_CLIENT_MAJOR:-17}"
readonly RESTORE_LOG="${PEC_RESTORE_LOG:-$PWD/restore_warn_error.log}"
readonly RESTORE_FULL_LOG="${PEC_RESTORE_FULL_LOG:-$PWD/restore_full.log}"

TTY_DEVICE=''
SUDO=()
TEMP_FILES=()
PSQL_BIN=psql
PG_RESTORE_BIN=pg_restore

info() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32mOK:\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mAviso:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mErro:\033[0m %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local exit_code=$? file
  if (( ${#TEMP_FILES[@]} > 0 )); then
    for file in "${TEMP_FILES[@]}"; do
      if [[ -n "$file" && -e "$file" ]]; then
        rm -f -- "$file"
      fi
    done
  fi
  return "$exit_code"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Restaura opcionalmente um backup PostgreSQL e instala a versão mais recente do
e-SUS PEC em Ubuntu/Debian. Java e o instalador só são executados depois de uma
restauração bem-sucedida.

Uso:
  Execute como root ou com um usuário que tenha sudo sem senha (NOPASSWD).
  linux-install.sh
  linux-install.sh --jar-url URL
  linux-install.sh --latest-url
  linux-install.sh --help

Opções:
  --jar-url URL  Usa um instalador Linux64 específico em vez do latest.
  --latest-url   Apenas imprime a URL da versão mais recente e encerra.
  --help         Exibe esta ajuda.

Variáveis opcionais:
  PEC_DOWNLOAD_DIR  Diretório de cache do instalador (padrão:
                    /var/tmp/e-sus-pec-installer).
  PEC_BASE_URL      URL-base do portal SISAPS, útil para testes.
  PEC_POSTGRES_CLIENT_MAJOR
                    Versão do cliente pg_restore (padrão: 17).
  PEC_RESTORE_LOG   Arquivo de warnings/erros do pg_restore (padrão:
                    ./restore_warn_error.log).
  PEC_RESTORE_FULL_LOG
                    Saída completa do pg_restore (padrão: ./restore_full.log).
EOF
}

require_tty() {
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    TTY_DEVICE=/dev/tty
  else
    die "a instalação interativa precisa de um terminal. Execute o script em um shell com TTY."
  fi
}

prompt() {
  local label=$1 default_value=${2:-} value
  if [[ -n "$default_value" ]]; then
    printf '%s [%s]: ' "$label" "$default_value" >"$TTY_DEVICE"
  else
    printf '%s: ' "$label" >"$TTY_DEVICE"
  fi
  IFS= read -r value <"$TTY_DEVICE" || die "não foi possível ler a resposta."
  printf '%s' "${value:-$default_value}"
}

prompt_required() {
  local label=$1 default_value=${2:-} value
  while true; do
    value=$(prompt "$label" "$default_value")
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return
    fi
    warn "este campo é obrigatório."
  done
}

prompt_secret() {
  local label=$1 first second
  while true; do
    printf '%s: ' "$label" >"$TTY_DEVICE"
    IFS= read -r -s first <"$TTY_DEVICE" || die "não foi possível ler a senha."
    printf '\nRepita a senha: ' >"$TTY_DEVICE"
    IFS= read -r -s second <"$TTY_DEVICE" || die "não foi possível ler a confirmação da senha."
    printf '\n' >"$TTY_DEVICE"
    if [[ -z "$first" ]]; then
      warn "a senha não pode ficar vazia."
    elif [[ "$first" != "$second" ]]; then
      warn "as senhas não coincidem; tente novamente."
    else
      printf '%s' "$first"
      return
    fi
  done
}

confirm() {
  local label=$1 default_answer=${2:-s} answer hint
  if [[ "$default_answer" == s ]]; then
    hint='S/n'
  else
    hint='s/N'
  fi
  while true; do
    answer=$(prompt "$label ($hint)")
    answer=${answer,,}
    answer=${answer:-$default_answer}
    case "$answer" in
      s|sim|y|yes) return 0 ;;
      n|nao|não|no) return 1 ;;
      *) warn "responda com sim ou não." ;;
    esac
  done
}

validate_port() {
  local value=$1 label=$2
  [[ "$value" =~ ^[0-9]+$ ]] || die "$label deve ser um número."
  (( value >= 1 && value <= 65535 )) || die "$label deve estar entre 1 e 65535."
}

normalize_domain() {
  local value=$1
  value=${value#http://}
  value=${value#https://}
  value=${value%%/*}
  value=${value%%:*}
  value=${value%.}
  value=${value,,}
  [[ "$value" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$ ]] \
    || die "domínio inválido: informe algo como pec.exemplo.gov.br."
  printf '%s' "$value"
}

check_platform() {
  [[ "$(uname -s)" == Linux ]] || die "este instalador só pode ser usado em Linux."
  command -v apt-get >/dev/null 2>&1 \
    || die "distribuição não suportada: é necessário apt-get (Ubuntu ou Debian)."
  [[ -r /etc/os-release ]] || die "não foi possível identificar a distribuição."
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *)
      case " ${ID_LIKE:-} " in
        *' debian '*) ;;
        *) die "distribuição não suportada: ${PRETTY_NAME:-desconhecida}." ;;
      esac
      ;;
  esac
  [[ "$(uname -m)" == x86_64 ]] \
    || die "o instalador oficial Linux64 requer arquitetura x86_64 (detectada: $(uname -m))."
  [[ -d /run/systemd/system ]] \
    || die "systemd não está ativo; a instalação standalone precisa dele para gerenciar o serviço."
}

configure_privilege() {
  if (( EUID == 0 )); then
    SUDO=()
  else
    command -v sudo >/dev/null 2>&1 || die "sudo não está instalado."
    info "Validando sudo sem senha..."
    sudo -n true \
      || die "este usuário não possui sudo sem senha (NOPASSWD). Execute como root ou ajuste o sudoers; o instalador não solicitará senha administrativa."
    SUDO=(sudo)
    success "sudo sem senha disponível."
  fi
}

install_database_dependencies() {
  local distro_codename key_file repository_file
  [[ "$POSTGRES_CLIENT_MAJOR" =~ ^[0-9]+$ ]] \
    || die "PEC_POSTGRES_CLIENT_MAJOR deve ser uma versão numérica."

  info "Etapa 1/2: instalando o cliente PostgreSQL $POSTGRES_CLIENT_MAJOR..."
  export DEBIAN_FRONTEND=noninteractive
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y \
    ca-certificates curl gnupg

  if ! apt-cache show "postgresql-client-$POSTGRES_CLIENT_MAJOR" >/dev/null 2>&1; then
    # O Ubuntu 22.04 oferece cliente 14, que não lê dumps v1.16 do PostgreSQL 17.
    # Adiciona o repositório oficial PGDG somente quando a versão pedida não existe.
    # shellcheck disable=SC1091
    source /etc/os-release
    distro_codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
    [[ -n "$distro_codename" ]] \
      || die "não foi possível determinar o codename da distribuição para configurar o PGDG."

    key_file=$(mktemp /tmp/postgresql-pgdg-key.XXXXXX)
    repository_file=$(mktemp /tmp/postgresql-pgdg-repository.XXXXXX)
    TEMP_FILES+=("$key_file" "$repository_file")
    curl -fsSL --retry 3 --connect-timeout 20 \
      -o "$key_file" https://www.postgresql.org/media/keys/ACCC4CF8.asc
    "${SUDO[@]}" install -d -m 0755 /usr/share/keyrings
    "${SUDO[@]}" gpg --batch --yes --dearmor \
      --output /usr/share/keyrings/postgresql-pgdg.gpg "$key_file"
    printf 'deb [signed-by=/usr/share/keyrings/postgresql-pgdg.gpg] https://apt.postgresql.org/pub/repos/apt %s-pgdg main\n' \
      "$distro_codename" >"$repository_file"
    "${SUDO[@]}" install -m 0644 "$repository_file" /etc/apt/sources.list.d/postgresql-pgdg.list
    "${SUDO[@]}" apt-get update
  fi

  "${SUDO[@]}" apt-get install -y "postgresql-client-$POSTGRES_CLIENT_MAJOR"
  PSQL_BIN="/usr/lib/postgresql/$POSTGRES_CLIENT_MAJOR/bin/psql"
  PG_RESTORE_BIN="/usr/lib/postgresql/$POSTGRES_CLIENT_MAJOR/bin/pg_restore"
  [[ -x "$PSQL_BIN" && -x "$PG_RESTORE_BIN" ]] \
    || die "os binários do cliente PostgreSQL $POSTGRES_CLIENT_MAJOR não foram encontrados."
  success "cliente PostgreSQL instalado: $($PG_RESTORE_BIN --version)."
}

install_application_dependencies() {
  local timezone=$1
  info "Etapa 2/2: instalando Java 17, fontes e dependências do PEC..."
  export DEBIAN_FRONTEND=noninteractive
  "${SUDO[@]}" apt-get install -y \
    wget gnupg locales coreutils file fontconfig unzip debconf tzdata \
    libfreetype6 openjdk-17-jre-headless

  if apt-cache show ttf-mscorefonts-installer >/dev/null 2>&1; then
    printf 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true\n' \
      | "${SUDO[@]}" debconf-set-selections
    if ! "${SUDO[@]}" apt-get install -y ttf-mscorefonts-installer; then
      warn "as fontes Microsoft não foram instaladas; o PEC funcionará, mas alguns relatórios podem mudar de aparência."
    fi
  else
    warn "ttf-mscorefonts-installer não está disponível nos repositórios habilitados."
  fi

  if ! locale -a 2>/dev/null | grep -Eqi '^pt_BR\.utf-?8$'; then
    "${SUDO[@]}" sed -i 's/^# *pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
    "${SUDO[@]}" locale-gen pt_BR.UTF-8
  fi
  [[ -f "/usr/share/zoneinfo/$timezone" ]] || die "fuso horário não encontrado: $timezone."
  "${SUDO[@]}" timedatectl set-timezone "$timezone"
  "${SUDO[@]}" fc-cache -f
  success "dependências da aplicação instaladas."
}

fetch() {
  curl -fsSL --retry 3 --connect-timeout 20 "$1"
}

first_match() {
  grep -Eo "$1" | sed -n '1p' || true
}

last_line_matching() {
  grep -E "$1" | sed -n '$p' || true
}

asset_url() {
  local asset_path
  asset_path=$(printf '%s' "$1" | sed 's#^.*/assets/js/#assets/js/#')
  printf '%s/%s\n' "${PEC_BASE_URL%/}" "$asset_path"
}

find_latest_url() {
  local homepage_html advertised_version major minor blog_slug blog_module_pattern
  local main_js_path runtime_js_path main_js chunk_id runtime_js chunk_mappings
  local mapping_count chunk_hash chunk_name chunk_url chunk_js version_pattern linux_link

  homepage_html=$(fetch "${PEC_BASE_URL%/}/")
  advertised_version=$(printf '%s' "$homepage_html" \
    | first_match 'Download([^[:alpha:]]+para[[:space:]]+(Windows|Linux))?[[:space:]]*-[[:space:]]*[Vv]ers[aã]o[[:space:]]+[0-9]+\.[0-9]+(\.[0-9]+)?' \
    | first_match '[0-9]+\.[0-9]+(\.[0-9]+)?')
  [[ -n "$advertised_version" ]] \
    || die "não encontrei a versão anunciada na página inicial do SISAPS."

  major=${advertised_version%%.*}
  minor=$(printf '%s' "$advertised_version" | cut -d. -f2)
  # Mantidas para documentar o mesmo fluxo de descoberta usado pelo projeto.
  : "${PEC_RELEASES_URL%/}/versao_${major}_${minor}"
  blog_slug=${advertised_version//./-}
  blog_module_pattern="@site/blog/[^\"]*versao-${blog_slug}\\.md\""

  main_js_path=$(printf '%s' "$homepage_html" | first_match "/[^\"']*assets/js/main\\.[^\"']+\\.js")
  runtime_js_path=$(printf '%s' "$homepage_html" | first_match "/[^\"']*assets/js/runtime~main\\.[^\"']+\\.js")
  [[ -n "$main_js_path" && -n "$runtime_js_path" ]] \
    || die "não encontrei os bundles JavaScript da página inicial do SISAPS."

  main_js=$(fetch "$(asset_url "$main_js_path")")
  chunk_id=$(printf '%s' "$main_js" \
    | first_match "n\\.e\\([0-9]+\\)[^\"]*\"${blog_module_pattern}" \
    | sed -E 's/.*n\.e\(([0-9]+)\).*/\1/' || true)
  if [[ -z "$chunk_id" ]]; then
    chunk_id=$(printf '%s' "$main_js" \
      | first_match "n\\.e\\([0-9]+\\)[^\\\"']+\\\"@site/src/pages/index\\.(js|jsx|ts|tsx)\\\"" \
      | sed -E 's/.*n\.e\(([0-9]+)\).*/\1/' || true)
  fi
  [[ -n "$chunk_id" ]] || die "não encontrei o chunk de download da página inicial."

  runtime_js=$(fetch "$(asset_url "$runtime_js_path")")
  chunk_mappings=$(printf '%s' "$runtime_js" | grep -Eo "${chunk_id}:\"[a-z0-9]+\"" || true)
  mapping_count=$(printf '%s\n' "$chunk_mappings" | sed '/^$/d' | wc -l | tr -d ' ')
  (( mapping_count > 0 )) || die "não consegui resolver o arquivo do chunk $chunk_id."

  chunk_hash=$(printf '%s\n' "$chunk_mappings" | sed -n '$s/.*"\([a-z0-9]*\)"/\1/p')
  if (( mapping_count == 1 )); then
    chunk_name=$chunk_id
  else
    chunk_name=$(printf '%s\n' "$chunk_mappings" | sed -n '1s/.*"\([a-z0-9]*\)"/\1/p')
  fi
  chunk_url="${PEC_BASE_URL%/}/assets/js/${chunk_name}.${chunk_hash}.js"
  chunk_js=$(fetch "$chunk_url")
  version_pattern=${advertised_version//./\\.}
  linux_link=$(printf '%s' "$chunk_js" \
    | grep -Eo "https?://[^[:space:]\\\"'<>]*Linux[^[:space:]\\\"'<>]*\\.(jar|zip)(\\?[^[:space:]\\\"'<>]*)?" \
    | last_line_matching "/${version_pattern}[./-]")
  [[ -n "$linux_link" ]] \
    || die "link Linux não encontrado para a versão $advertised_version."
  printf '%s\n' "$linux_link"
}

download_installer() {
  local url=$1 filename destination partial
  filename=${url%%\?*}
  filename=${filename##*/}
  [[ "$filename" == *.jar ]] || filename='eSUS-AB-PEC-Linux64.jar'
  destination="$DOWNLOAD_DIR/$filename"
  partial="$destination.part"

  "${SUDO[@]}" install -d -m 0755 "$DOWNLOAD_DIR"
  if [[ -s "$destination" ]] && "${SUDO[@]}" unzip -tqq "$destination" >/dev/null 2>&1; then
    info "Usando instalador já baixado: $destination"
  else
    info "Baixando $url"
    "${SUDO[@]}" rm -f -- "$partial"
    "${SUDO[@]}" curl -fL --retry 3 --connect-timeout 20 \
      --progress-bar -o "$partial" "$url"
    "${SUDO[@]}" unzip -tqq "$partial" >/dev/null 2>&1 \
      || die "o arquivo baixado não é um JAR válido."
    "${SUDO[@]}" mv -f -- "$partial" "$destination"
  fi
  printf '%s' "$destination"
}

test_database() {
  local host=$1 port=$2 database=$3 username=$4 password=$5 sslmode=$6
  info "Testando conexão somente leitura com PostgreSQL em $host:$port..."
  if ! PGPASSWORD="$password" PGSSLMODE="$sslmode" "$PSQL_BIN" \
    --host="$host" --port="$port" --username="$username" --dbname="$database" \
    --no-password --set=ON_ERROR_STOP=1 --command='SELECT 1;' >/dev/null; then
    die "não foi possível conectar ao PostgreSQL. Nenhuma instalação foi iniciada."
  fi
  success "conexão com o PostgreSQL validada."
}

restore_database() {
  local backup_path=$1 host=$2 port=$3 database=$4 username=$5 sslmode=$6
  local restore_status tee_status log_line
  local -a pipeline_status

  info "Validando o arquivo de backup com $($PG_RESTORE_BIN --version)..."
  if ! "$PG_RESTORE_BIN" --list "$backup_path" >/dev/null; then
    die "o arquivo não é um backup aceito pelo pg_restore instalado. Verifique o formato e a versão do cliente PostgreSQL."
  fi

  warn "--clean removerá do banco $host:$port/$database os objetos presentes no backup antes de recriá-los."
  confirm 'Confirmar restauração destrutiva com --clean --if-exists?' n \
    || die "restauração cancelada pelo usuário."
  : >"$RESTORE_LOG" || die "não foi possível criar o log de restauração: $RESTORE_LOG"
  : >"$RESTORE_FULL_LOG" || die "não foi possível criar o log completo: $RESTORE_FULL_LOG"

  info "Restaurando $backup_path em $host:$port/$database..."
  info "O pg_restore solicitará a senha do usuário $username no terminal."
  set +e
  PGSSLMODE="$sslmode" "$PG_RESTORE_BIN" \
    --host="$host" --port="$port" --username="$username" --dbname="$database" \
    --password --clean --if-exists --no-owner --verbose \
    --exclude-schema=pg_catalog --format=custom "$backup_path" \
    2>&1 | tee "$RESTORE_FULL_LOG" >&2
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  restore_status=${pipeline_status[0]}
  tee_status=${pipeline_status[1]}

  (( tee_status == 0 )) || die "não foi possível gravar o log completo: $RESTORE_FULL_LOG"
  grep -Ei 'error|warning|erro|aviso' "$RESTORE_FULL_LOG" >"$RESTORE_LOG" || true

  if (( restore_status != 0 )); then
    warn "o pg_restore terminou com código $restore_status."
    printf '\nErros e avisos encontrados durante a restauração:\n' >&2
    if [[ -s "$RESTORE_LOG" ]]; then
      while IFS= read -r log_line; do
        printf '  %s\n' "$log_line" >&2
      done <"$RESTORE_LOG"
    else
      printf '  O pg_restore não registrou linhas classificadas como erro ou aviso.\n' >&2
    fi
    printf '\n' >&2
    warn "Relatório resumido: $RESTORE_LOG"
    warn "Relatório completo: $RESTORE_FULL_LOG"
    warn "* Os erros estarão disponíveis em log ao final da restauração e muitos são inofensivos."
    if confirm 'Continuar com Java e a instalação do PEC apesar dos erros?' s; then
      warn "a instalação continuará por decisão do administrador."
      return 0
    fi
    die "instalação interrompida após os erros do pg_restore."
  fi
  success "backup restaurado sem erros. Log completo: $RESTORE_FULL_LOG"
}

install_and_start() {
  local jar_path=$1 jdbc_url=$2 username=$3 password=$4 domain=$5 https_port=$6 training=$7
  local arg escaped args_file
  local -a installer_args
  installer_args=(
    -console
    "-url=$jdbc_url"
    "-username=$username"
    "-password=$password"
    -continue
  )
  if [[ -n "$domain" ]]; then
    installer_args+=("-cert-domain=$domain" "-cert-port=$https_port")
  fi
  [[ "$training" == true ]] && installer_args+=(-treinamento)

  args_file=$(mktemp /tmp/e-sus-pec-java-args.XXXXXX)
  chmod 0600 "$args_file"
  TEMP_FILES+=("$args_file")
  for arg in "${installer_args[@]}"; do
    escaped=${arg//\\/\\\\}
    escaped=${escaped//\"/\\\"}
    printf '"%s"\n' "$escaped" >>"$args_file"
  done

  info "Executando o instalador oficial. Esta etapa pode demorar vários minutos..."
  # O argfile 0600 evita expor a senha na linha de comando/listagem de processos.
  "${SUDO[@]}" java -jar "$jar_path" "@$args_file"
  rm -f -- "$args_file"
  unset 'installer_args'

  [[ -x /opt/e-SUS/webserver/standalone.sh ]] \
    || die "o instalador terminou sem gerar /opt/e-SUS/webserver/standalone.sh."

  if ! "${SUDO[@]}" systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
    [[ -f /opt/e-SUS/webserver/e-SUS-PEC.service ]] \
      || die "a unidade systemd não foi encontrada após a instalação."
    "${SUDO[@]}" install -m 0644 /opt/e-SUS/webserver/e-SUS-PEC.service \
      "/etc/systemd/system/$SERVICE_NAME"
  fi
  "${SUDO[@]}" systemctl daemon-reload
  "${SUDO[@]}" systemctl enable --now "$SERVICE_NAME"
  if ! "${SUDO[@]}" systemctl is-active --quiet "$SERVICE_NAME"; then
    "${SUDO[@]}" systemctl --no-pager --full status "$SERVICE_NAME" || true
    die "o serviço foi instalado, mas não permaneceu ativo."
  fi
  success "serviço $SERVICE_NAME habilitado e ativo."
}

main() {
  local jar_url='' latest_only=false
  local database_host database_port database_name database_user database_password
  local use_db_ssl db_sslmode jdbc_host jdbc_url domain='' https_port='' training=false jar_path access_url timezone
  local restore_requested=false backup_path=''

  while (( $# > 0 )); do
    case "$1" in
      --jar-url)
        (( $# >= 2 )) || die "--jar-url requer uma URL."
        jar_url=$2
        shift 2
        ;;
      --latest-url) latest_only=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "opção desconhecida: $1. Use --help." ;;
    esac
  done

  if [[ "$latest_only" == true ]]; then
    command -v curl >/dev/null 2>&1 || die "curl não está instalado."
    find_latest_url
    exit 0
  fi

  require_tty
  check_platform
  configure_privilege
  if [[ -e /etc/pec.config || -d /opt/e-SUS/webserver ]]; then
    die "já existe uma instalação em /opt/e-SUS ou /etc/pec.config; use o fluxo de atualização em vez deste instalador."
  fi

  printf '\nInstalação standalone do e-SUS PEC\n'
  printf 'O banco PostgreSQL informado deve existir e aceitar conexões deste servidor.\n\n'

  database_host=$(prompt_required 'Host do PostgreSQL' 'localhost')
  [[ "$database_host" != *[[:space:]/?#]* ]] \
    || die "o host do PostgreSQL contém caracteres inválidos."
  database_port=$(prompt_required 'Porta do PostgreSQL' '5432')
  validate_port "$database_port" 'A porta do PostgreSQL'
  database_name=$(prompt_required 'Nome do banco de dados' 'esus')
  [[ "$database_name" != *[[:space:]/?#]* ]] \
    || die "o nome do banco contém caracteres inválidos."
  database_user=$(prompt_required 'Usuário do banco de dados' 'postgres')
  database_password=$(prompt_secret 'Senha do banco (validação e instalador; o pg_restore pedirá novamente)')
  if confirm 'Restaurar um backup com pg_restore antes de instalar o PEC?' s; then
    restore_requested=true
    info "Dica: em outro terminal, execute: realpath caminho/do/arquivo.backup"
    backup_path=$(prompt_required 'Caminho do arquivo de backup PostgreSQL')
    if [[ "$backup_path" == '~/'* ]]; then
      backup_path="$HOME/${backup_path:2}"
    fi
    [[ -f "$backup_path" && -r "$backup_path" ]] \
      || die "arquivo de backup inexistente ou sem permissão de leitura: $backup_path"
    backup_path=$(realpath -- "$backup_path") \
      || die "não foi possível resolver o caminho absoluto do backup."
  fi
  timezone=$(prompt_required 'Fuso horário do servidor' 'America/Bahia')
  [[ "$timezone" != *'..'* && "$timezone" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$ ]] \
    || die "fuso horário inválido: $timezone."
  if confirm 'O PostgreSQL exige TLS/SSL?' n; then
    use_db_ssl=true
    db_sslmode=require
  else
    use_db_ssl=false
    db_sslmode=disable
  fi

  if confirm 'Configurar HTTPS automático no próprio PEC?' s; then
    domain=$(normalize_domain "$(prompt_required 'Domínio (com ou sem https://)')")
    https_port=$(prompt_required 'Porta HTTPS' '443')
    validate_port "$https_port" 'A porta HTTPS'
  fi
  if confirm 'Esta é uma instalação de treinamento?' n; then
    training=true
  fi

  jdbc_host=$database_host
  if [[ "$jdbc_host" == *:* && "$jdbc_host" != \[*\] ]]; then
    jdbc_host="[$jdbc_host]"
  fi
  jdbc_url="jdbc:postgresql://${jdbc_host}:${database_port}/${database_name}"
  [[ "$use_db_ssl" == true ]] && jdbc_url+='?sslmode=require'
  if [[ -n "$domain" ]]; then
    access_url="https://${domain}"
    [[ "$https_port" == 443 ]] || access_url+=":${https_port}"
  else
    access_url='http://IP-DESTE-SERVIDOR:8080'
  fi

  printf '\nResumo\n'
  printf '  Banco:       %s:%s/%s\n' "$database_host" "$database_port" "$database_name"
  printf '  Usuário:     %s\n' "$database_user"
  printf '  SSL banco:   %s\n' "$use_db_ssl"
  printf '  Restauração: %s\n' "${backup_path:-não solicitada}"
  if [[ "$restore_requested" == true ]]; then
    printf '  Estratégia:  --clean --if-exists --no-owner -Fc\n'
    printf '  Log resumido: %s\n' "$RESTORE_LOG"
    printf '  Log completo: %s\n' "$RESTORE_FULL_LOG"
  fi
  printf '  Fuso horário: %s\n' "$timezone"
  printf '  HTTPS PEC:   %s\n' "${domain:-não configurado}"
  printf '  Treinamento: %s\n\n' "$training"
  confirm 'Continuar com a instalação?' s || die "instalação cancelada pelo usuário."

  install_database_dependencies
  test_database "$database_host" "$database_port" "$database_name" \
    "$database_user" "$database_password" "$db_sslmode"
  if [[ "$restore_requested" == true ]]; then
    restore_database "$backup_path" "$database_host" "$database_port" "$database_name" \
      "$database_user" "$db_sslmode"
  fi

  install_application_dependencies "$timezone"

  if [[ -z "$jar_url" ]]; then
    info "Descobrindo a versão mais recente publicada pelo SISAPS..."
    jar_url=$(find_latest_url)
    success "instalador encontrado: $jar_url"
  fi
  [[ "$jar_url" == https://* || "$jar_url" == http://* ]] \
    || die "URL do instalador inválida: $jar_url"
  jar_path=$(download_installer "$jar_url")

  install_and_start "$jar_path" "$jdbc_url" "$database_user" "$database_password" \
    "$domain" "$https_port" "$training"
  database_password=''

  printf '\nInstalação concluída.\n'
  printf 'Acesso esperado: %s\n' "$access_url"
  printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
  printf 'Logs:   journalctl -u %s -f\n' "$SERVICE_NAME"
}

main "$@"
