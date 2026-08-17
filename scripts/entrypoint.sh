#!/usr/bin/env bash

set -e

: '
{
  "success" : true,
  "directory" : "/opt/e-SUS",
  "version" : "5.3.19",
  "production" : true,
  "customDatabase" : true,
  "databaseUrl" : "jdbc:postgresql://db:5432/esus",
  "databaseUsername" : "postgres",
  "databasePassword" : "pass",
  "jreVersion" : "17.0.10-linux_x64",
  "jreDirectory" : "/opt/e-SUS/jre/17.0.10-linux_x64",
  "webserverVersion" : "5.3.19",
  "webserverDirectory" : "/opt/e-SUS/webserver"
}
'

install_pec() {
    chmod +x ./install.sh
    ./install.sh

    if [ ! -x /opt/e-SUS/webserver/standalone.sh ]; then
        echo ">> Erro: instalação não gerou /opt/e-SUS/webserver/standalone.sh."
        echo ">> Verifique os logs acima; o PEC não será iniciado com instalação incompleta."
        exit 1
    fi
}

# Verifica se o sistema já foi instalado pela conferência da existência de um arquivo /etc/pec.config, caso não exista, instalar
if [ ! -f /etc/pec.config ]; then
    echo ">> Sistema ainda não foi instalado. Instalando..."
    echo ">> Gerando certificado com CertMgr e instalando o sistema..."
    install_pec
fi

# Verifica existe um /etc/pec.config e se a instalação está em sucesso, caso sim, não instala. a estrutura do pec.config no início do arquivo
if [ -f "/etc/pec.config" ]; then
  # Lê o conteúdo do arquivo /etc/pec.config
  config=$(cat /etc/pec.config)
  
  # Verifica se a instalação foi bem-sucedida
  # Se a instalação foi bem-sucedida, o campo "success" deve ser true
  if echo "$config" | grep -q "\"success\" : true"; then
    # Inicie a aplicação principal
    echo ">> Iniciando aplicação principal..."
    exec /opt/e-SUS/webserver/standalone.sh
  else
    # Se a instalação não foi bem-sucedida, exiba uma mensagem de erro
    echo ">> Erro: Instalação não foi bem-sucedida."
    echo ">> Tentando reinstalar sistema..."
    install_pec
    exit 1
  fi
fi

if [ ! -x /opt/e-SUS/webserver/standalone.sh ]; then
  echo ">> Erro: /opt/e-SUS/webserver/standalone.sh não existe ou não é executável."
  echo ">> Instalação incompleta; abortando inicialização."
  exit 1
fi

echo ">> Iniciando aplicação principal..."
exec /opt/e-SUS/webserver/standalone.sh
