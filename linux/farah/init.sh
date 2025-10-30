COMPOSER_UPDATE="${COMPOSER_UPDATE:-install}"

case "$COMPOSER_UPDATE" in
  skip)
    echo "Skipping composer update step."
    ;;

  install)
    composer -d /var/www install --no-interaction --no-dev --optimize-autoloader --classmap-authoritative
    ;;

  install-dev)
    composer -d /var/www install --no-interaction
    ;;

  lowest)
    composer -d /var/www update --no-interaction --prefer-lowest --no-dev --optimize-autoloader --classmap-authoritative
    ;;

  lowest-dev)
    composer -d /var/www update --no-interaction --prefer-lowest
    ;;

  stable)
    composer -d /var/www update --no-interaction --prefer-stable --no-dev --optimize-autoloader --classmap-authoritative
    ;;

  stable-dev)
    composer -d /var/www update --no-interaction --prefer-stable
    ;;

  *)
    echo "Unknown COMPOSER_UPDATE mode: '$COMPOSER_UPDATE'" >&2
    ;;
esac

apache2-foreground -DSERVER_NAME=$SERVER_NAME