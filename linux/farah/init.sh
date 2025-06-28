composer -d /var/www install --no-interaction --no-dev --optimize-autoloader --classmap-authoritative
apache2-foreground -DSERVER_NAME=$SERVER_NAME