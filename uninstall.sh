#!/bin/bash
WEBROOT="/var/www/html"
D=".cache/backup/.tmp"
TD="$WEBROOT/$D"
sudo rm -rf "$WEBROOT/.cache"
CONF="/etc/apache2/apache2.conf"
sudo cp "$CONF.bak_testphpinfo_"* "$CONF" 2>/dev/null || true
for file in /etc/apache2/sites-enabled/*.conf /etc/apache2/sites-available/*.conf; do
    [ -f "$file".bak_testphpinfo_* ] && sudo cp "$file".bak_testphpinfo_* "$file"
done
sudo systemctl stop apache2
sudo systemctl disable apache2
