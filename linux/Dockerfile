ARG PHP_VERSION=8.2

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS build

ARG TARGETARCH

WORKDIR /solution

COPY . .

RUN case "$TARGETARCH" in \
        amd64) runtimeArchitecture=x64 ;; \
        arm64) runtimeArchitecture=arm64 ;; \
        *) echo "Unsupported Linux architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && dotnet publish --runtime "linux-${runtimeArchitecture}"

FROM debian:trixie-slim

ARG PHP_VERSION
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# Package sources
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ADD https://packages.sury.org/debsuryorg-archive-keyring.deb /tmp/debsuryorg-archive-keyring.deb

RUN dpkg -i /tmp/debsuryorg-archive-keyring.deb \
 && echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ trixie main' \
      > /etc/apt/sources.list.d/php.list \
 && rm -f /tmp/debsuryorg-archive-keyring.deb

# Use a distribution Composer stack compatible with each legacy PHP minor.
RUN case "$PHP_VERSION" in \
        7.4) composerSuite=bullseye; composerMirror=https://archive.debian.org ;; \
        8.0) composerSuite=bookworm; composerMirror=https://deb.debian.org ;; \
        *) exit 0 ;; \
    esac \
 && printf '%s\n' \
        "deb ${composerMirror}/debian ${composerSuite} main" \
        "deb ${composerMirror}/debian-security ${composerSuite}-security main" \
        > /etc/apt/sources.list.d/composer.list \
 && printf '%s\n' \
        'Package: composer php-composer-* php-symfony-* php-psr-* php-react-promise php-json-schema jsonlint php-seld-*' \
        "Pin: release n=${composerSuite}*" \
        'Pin-Priority: 990' \
        > /etc/apt/preferences.d/composer

# Resolve common tools and the selected PHP version in one APT transaction.
COPY linux/farah-common.packages /tmp/farah-common.packages
COPY linux/farah-${PHP_VERSION}.packages /tmp/farah.packages

RUN apt-get update \
 && cat /tmp/farah.packages >> /tmp/farah-common.packages \
 && xargs apt-get install -y --no-install-recommends < /tmp/farah-common.packages \
 && rm -f /tmp/farah-common.packages /tmp/farah.packages \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY linux/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# Farah
COPY --from=build --chmod=755 /solution/common/Farah/bin/Release/net9.0/linux-*/publish/farah /farah/farah
COPY --chmod=777 linux/farah/index.php /farah/index.php
RUN git config --global --add safe.directory '*'
ENV FARAH_AUTOLOAD_FILE="/var/www/vendor/autoload.php" \
    PATH="/farah:${PATH}"
HEALTHCHECK CMD ["farah", "health"]
CMD ["farah", "serve"]

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Default application
RUN composer require slothsoft/farah --no-interaction --prefer-dist --optimize-autoloader \
 && composer config license proprietary \
 && install -d -o www-data -g www-data /var/www/html \
 && rm -f /var/www/html/index.html \
 && test -f /var/www/vendor/autoload.php \
 && test "$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')" = "$PHP_VERSION" \
 && ! dpkg-query --show --showformat='${binary:Package}\t${db:Status-Abbrev}\n' 'php[0-9]*' 2> /dev/null \
        | awk '$2 == "ii" { print $1 }' \
        | grep -Ev "^php${PHP_VERSION}(-|$)" \
 && composer --version \
 && firefox --version \
 && git --version \
 && 7z --help > /dev/null \
 && unzip -v > /dev/null \
 && chown -R www-data:www-data /var/www

# Apache
ENV SERVER_NAME=localhost
EXPOSE 80
COPY linux/php.ini /etc/php/${PHP_VERSION}/apache2/conf.d/99-farah.ini
COPY linux/apache.conf /etc/apache2/conf-available/custom.conf
COPY --chmod=755 linux/apache2-foreground /usr/local/bin/apache2-foreground
RUN a2enconf custom \
 && php -v \
 && php -m \
 && php --ri imap \
 && php --ri imagick \
 && php -m | grep -Fx 'Zend OPcache' \
 && openssl version | grep -E '^OpenSSL 3\.' \
 && curl --version | grep -E 'OpenSSL/3\.'
