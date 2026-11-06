FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalar las versiones mas recientes con todos los parches de seguridad actuales
# Versiones: Apache 2.4.58+, Samba 4.19+, vsftpd 3.0.5+, PHP 8.3
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    vsftpd \
    samba \
    smbclient \
    iputils-ping \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crear directorios seguros y usuario con contrasena robusta (sin acceso anonimo)
RUN mkdir -p /var/run/vsftpd/empty /srv/samba/privado /var/www/html/backups /var/www/html/uploads \
    && useradd -m -s /bin/bash usuario_seguro \
    && echo "usuario_seguro:S3cur3P@ss2026!" | chpasswd \
    && (echo "S3cur3P@ss2026!"; echo "S3cur3P@ss2026!") | smbpasswd -s -a usuario_seguro \
    && chown -R usuario_seguro:usuario_seguro /srv/samba/privado \
    && chmod 700 /srv/samba/privado \
    && chmod 750 /var/www/html/backups /var/www/html/uploads \
    && rm -f /var/www/html/index.html

# Endurecer Apache (ocultar version exacta y deshabilitar listado de directorios)
RUN sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-enabled/security.conf \
    && sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-enabled/security.conf \
    && sed -i 's/Options Indexes FollowSymLinks/Options -Indexes +FollowSymLinks/' /etc/apache2/apache2.conf

COPY src/index.php /var/www/html/index.php
COPY vsftpd.conf /etc/vsftpd.conf
COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /entrypoint.sh

RUN sed -i 's/\r$//' /entrypoint.sh /etc/vsftpd.conf /etc/samba/smb.conf /var/www/html/index.php \
    && chmod +x /entrypoint.sh

EXPOSE 80 21 139 445 21100-21110

ENTRYPOINT ["/entrypoint.sh"]
