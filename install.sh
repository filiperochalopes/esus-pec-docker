#!/bin/sh

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
ARGS=""

# Verificando variáveis de ambiente
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ] && [ -n "$POSTGRES_DB" ]; then
    DB_URL="jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
fi

# Echo das variáveis de ambiente
echo -e "${GREEN}\n\n*******************"
echo "Variáveis de ambiente:"
echo "*******************"
echo "HTTPS_DOMAIN: ${HTTPS_DOMAIN}"
echo "DB_URL: ${DB_URL}"
echo "POSTGRES_USER: ${POSTGRES_USER}"  
echo "POSTGRES_PASS: ${POSTGRES_PASS}"
echo "JAR_FILENAME: ${JAR_FILENAME}"
echo "TRAINING: ${TRAINING}"
echo "*******************\n\n${NC}"


# Verificando variável de certificado https
if [ -n "$HTTPS_DOMAIN" ]; then
  ARGS="$ARGS -cert-domain=${HTTPS_DOMAIN}"
fi

# Verificando variáveis de banco de dados
if [ -n "$DB_URL" ]; then
  ARGS="$ARGS -url=${DB_URL}" 
fi

if [ -n "$POSTGRES_USER" ]; then
  ARGS="$ARGS -username=${POSTGRES_USER}"
fi

if [ -n "$POSTGRES_PASS" ]; then  
  ARGS="$ARGS -password=${POSTGRES_PASS}"
fi

# A ser executado java -jar
echo -e "${GREEN}\n\n*******************"
echo "java -jar ${JAR_FILENAME} -console ${ARGS} -continue"
echo "*******************\n\n${NC}"

# Executa o comando
java -jar ${JAR_FILENAME} -console ${ARGS} -continue


# O modo só é alterado quando declarado explicitamente. Banco externo continua
# com o comportamento anterior (TRAINING ausente), sem escrita adicional.
case "$TRAINING" in
  true)
    TRAINING_VALUE=1
    echo -e "${GREEN}Configurando instalação em modo treinamento...${NC}"
    ;;
  false)
    TRAINING_VALUE=0
    echo -e "${GREEN}Configurando instalação em modo produção...${NC}"
    ;;
  *)
    TRAINING_VALUE=''
    ;;
esac

if [ -n "$TRAINING_VALUE" ]; then
  export PGPASSWORD="${POSTGRES_PASS}"
  if psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 \
    -c "update tb_config_sistema set ds_texto = null, ds_inteiro = ${TRAINING_VALUE} where co_config_sistema = 'TREINAMENTO';"; then
    echo -e "${GREEN}Modo da instalação aplicado com sucesso.${NC}"
  else
    echo -e "${RED}Erro ao aplicar modo da instalação.${NC}"
    unset PGPASSWORD
    exit 1
  fi
  unset PGPASSWORD
fi
