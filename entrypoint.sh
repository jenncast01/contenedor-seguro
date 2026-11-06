#!/bin/bash
set -e

echo "Iniciando Apache (HTTP Seguro)..."
service apache2 start

echo "Iniciando vsftpd (FTP Seguro)..."
/usr/sbin/vsftpd /etc/vsftpd.conf &

echo "Iniciando Samba (SMBv3 Seguro)..."
exec /usr/sbin/smbd --foreground --no-process-group
