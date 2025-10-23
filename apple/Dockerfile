FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Configura DNS e mirrors compatíveis com o builder do Apple Container
RUN printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf \
    && sed -i 's|http://ports.ubuntu.com/ubuntu-ports|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list

# Instala dependências básicas e fontes utilizadas pelo PEC
RUN apt-get update && apt-get install -y \
    locales \
    && locale-gen "pt_BR.UTF-8" \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && apt-get install -y \
    coreutils wget apt-utils gnupg2 software-properties-common file libfreetype6 ntp ttf-mscorefonts-installer fontconfig

RUN fc-cache -fv && chmod -R 777 /usr/share/fonts/truetype/msttcorefonts

# Instala Amazon Corretto 17
RUN wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list \
    && apt-get update && apt-get install -y java-17-amazon-corretto-jdk

# Instalações para systemd e demais utilitários necessários
RUN sed -i 's/# deb/deb/g' /etc/apt/sources.list \
    && apt-get update && apt-get install --no-install-recommends -y \
       dbus systemd systemd-cron rsyslog iproute2 python-is-python3 python3 python3-apt sudo bash ca-certificates \
    && apt-get clean \
    && rm -rf /usr/share/doc/* /usr/share/man/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Cliente PostgreSQL para execução dos scripts de treinamento
RUN apt-get update && apt-get install -y postgresql-client

# Substitui ps/systemctl para execução em ambientes sem systemd real
RUN mv /bin/ps /bin/ps.original \
    && { \
      echo '#!/bin/sh'; \
      echo 'if [ "$1" = "--no-headers" ] && [ "$2" = "-o" ] && [ "$3" = "comm" ] && [ "$4" = "1" ]; then'; \
      echo '  echo "systemd (simulated: ps $@)"'; \
      echo 'else'; \
      echo '  /bin/ps.original "$@"'; \
      echo 'fi'; \
    } > /bin/ps \
    && chmod +x /bin/ps

RUN { \
      echo '#!/bin/sh'; \
      echo 'echo "Simulated systemctl command: $0 $@"'; \
      echo 'case "$1" in'; \
      echo '  start|stop|restart|status) exit 0 ;;'; \
      echo '  *) echo "Simulated systemctl: $@"; exit 0 ;;'; \
      echo 'esac'; \
    } > /bin/systemctl \
    && chmod +x /bin/systemctl

ARG JAR_FILENAME
ARG HTTPS_DOMAIN
ARG DB_URL
ARG POSTGRES_PASS
ARG POSTGRES_USER
ARG TRAINING

ENV JAR_FILENAME=${JAR_FILENAME} \
    TRAINING=${TRAINING} \
    DB_URL=${DB_URL} \
    POSTGRES_PASS=${POSTGRES_PASS} \
    POSTGRES_USER=${POSTGRES_USER} \
    HTTPS_DOMAIN=${HTTPS_DOMAIN}

RUN mkdir -p /opt/e-SUS/webserver/chaves /backups /var/www/html
WORKDIR /var/www/html

COPY ./${JAR_FILENAME} ${JAR_FILENAME}
COPY ./install.sh ./install.sh
COPY backups/ /backups/
COPY apple/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh ./install.sh

ENTRYPOINT ["/entrypoint.sh"]
