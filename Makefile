SHELL := /bin/sh
.DEFAULT_GOAL := help

BUILD_SCRIPT := scripts/build.sh
UPDATE_SCRIPT := scripts/update.sh
CODEBASE_SCRIPT := scripts/gen-codebase.sh
BUILD_ARGS ?=
JAR ?=
BACKUP ?=
OUTPUT ?= codebase

jar_arg = $(if $(strip $(JAR)),-f "$(JAR)")

.PHONY: help training production external cloud restore update-local update-external codebase check-env check-cloud-env

help:
	@printf '%s\n' \
		'Uso: make <alvo> [VAR=valor]' \
		'' \
		'Instalação:' \
		'  training       Instala com banco local em modo de treinamento' \
		'  production     Instala com banco local em modo de produção' \
		'  external       Instala em produção usando o banco externo do .env' \
		'  cloud          Instala em produção usando cloud/.env' \
		'  restore        Restaura BACKUP no modo cloud e inicia o PEC' \
		'' \
		'Manutenção:' \
		'  update-local    Atualiza a instalação com banco local' \
		'  update-external Atualiza a instalação com banco externo' \
		'  codebase       Gera o codebase de JAR em OUTPUT (padrão: codebase)' \
		'' \
		'Variáveis:' \
		'  JAR=<arquivo-ou-url>  Usa uma versão específica do PEC' \
		'  BACKUP=<arquivo>      Backup usado pelo alvo restore' \
		'  OUTPUT=<diretório>    Saída usada pelo alvo codebase' \
		'  BUILD_ARGS="..."      Opções adicionais para scripts/build.sh'

check-env:
	@test -f .env || { echo 'Erro: copie .env.example para .env e revise a configuração.' >&2; exit 1; }

check-cloud-env:
	@test -f cloud/.env || { echo 'Erro: copie cloud/.env.example para cloud/.env e revise a configuração.' >&2; exit 1; }

training: check-env
	@sh $(BUILD_SCRIPT) $(jar_arg) $(BUILD_ARGS)

production: check-env
	@sh $(BUILD_SCRIPT) -p $(jar_arg) $(BUILD_ARGS)

external: check-env
	@sh $(BUILD_SCRIPT) -e $(jar_arg) $(BUILD_ARGS)

cloud: check-cloud-env
	@sh $(BUILD_SCRIPT) -C -p $(jar_arg) $(BUILD_ARGS)

restore: check-cloud-env
	@test -n "$(BACKUP)" || { echo 'Erro: informe BACKUP=/caminho/arquivo.backup.' >&2; exit 1; }
	@sh $(BUILD_SCRIPT) -C -p $(jar_arg) -r "$(BACKUP)" $(BUILD_ARGS)

update-local: check-env
	@sh $(UPDATE_SCRIPT) compose.local-db.yml

update-external: check-env
	@sh $(UPDATE_SCRIPT) compose.external-db.yml

codebase:
	@test -n "$(JAR)" || { echo 'Erro: informe JAR=/caminho/arquivo.jar.' >&2; exit 1; }
	@bash $(CODEBASE_SCRIPT) "$(JAR)" "$(OUTPUT)"
