#!/bin/bash
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

if [ ! -f /etc/pec.config ]; then
    echo ">> Sistema ainda não foi instalado. Instalando..."
    echo ">> Gerando certificado com CertMgr e instalando o sistema..."
    chmod +x ./install.sh
    ./install.sh
fi

if [ -f "/etc/pec.config" ]; then
  config=$(cat /etc/pec.config)

  if echo "$config" | grep -q "\"success\" : true"; then
    echo ">> Iniciando aplicação principal..."
    exec /opt/e-SUS/webserver/standalone.sh
  else
    echo ">> Erro: Instalação não foi bem-sucedida."
    echo ">> Tentando reinstalar sistema..."
    chmod +x ./install.sh
    ./install.sh
    exit 1
  fi
fi

echo ">> Iniciando aplicação principal..."
exec /opt/e-SUS/webserver/standalone.sh
