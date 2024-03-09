#!/bin/bash

source /etc/os-release

# uninstall
if [[ $1 == "-u" ]]; then
    if [[ $ID == "debian" || $ID == "ubuntu" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        apt remove --purge -yq nginx php-fpm mariadb-*
    elif [[ $ID == "centos" ]]; then
        yum -y remove nginx php-fpm mariadb-server wget
    else
        echo "Unsupported OS!"
        exit 1
    fi
    rm -rf /var/www/phpmyadmin
    rm -rf /var/lib/mysql
    exit 0
fi

#install
if [[ $ID == "debian" || $ID == "ubuntu" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt install -y nginx php-fpm php-mysqli php-zip mariadb-server
elif [[ $ID == "centos" ]]; then
    yum -y update
    yum -y install epel-release centos-release-scl-rh
    yum -y update
    yum -y install nginx php-fpm php-mysqli php-zip mariadb-server wget
else
    echo "Unsupported OS!"
    exit 1
fi

cat <<NGINX > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/phpmyadmin/;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:##TARGET##;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
NGINX


if [[ $ID == "debian" || $ID == "ubuntu" ]]; then
    PHPV=$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;")
    sed -i "s/##TARGET##/\/run\/php\/php$PHPV-fpm.sock/gi" /etc/nginx/sites-available/default
elif [[ $ID == "centos" ]]; then
    sed -i "s/##TARGET##/\/run\/php-fpm\/www.sock/gi" /etc/nginx/sites-available/default
fi

cd /var/www/ || exit 1
rm -rf php*
wget -qO pma.tar.gz https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar xvf pma.tar.gz
mv php* phpmyadmin
rm pma.tar.gz

service nginx restart

cd ~ || exit 1
PW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
# mysql -e "UPDATE mysql.user SET authentication_string=PASSWORD('$PW'),host='%',plugin='mysql_native_password' WHERE user='root';FLUSH PRIVILEGES;"
mysql -e "ALTER USER root@localhost identified by '$PW';FLUSH PRIVILEGES;"

echo -e "u=root\np=$PW" > mysql.txt

exit 0
