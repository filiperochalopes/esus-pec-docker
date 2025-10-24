FROM amazoncorretto:17

ARG JAR_FILENAME
ARG HTTPS_DOMAIN
ARG DB_URL
ARG POSTGRES_PASS
ARG POSTGRES_USER
ARG TRAINING

ENV LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt \
    LC_ALL=pt_BR.UTF-8 \
    JAR_FILENAME=${JAR_FILENAME} \
    TRAINING=${TRAINING} \
    DB_URL=${DB_URL} \
    POSTGRES_PASS=${POSTGRES_PASS} \
    POSTGRES_USER=${POSTGRES_USER} \
    HTTPS_DOMAIN=${HTTPS_DOMAIN}

RUN mkdir -p /opt/e-SUS/webserver/chaves /backups /var/www/html
WORKDIR /var/www/html

COPY ./install.sh ./install.sh
COPY ./backups/ /backups/
COPY ./${JAR_FILENAME} ${JAR_FILENAME}
COPY apple/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh ./install.sh

ENTRYPOINT ["/entrypoint.sh"]
