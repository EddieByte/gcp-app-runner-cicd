# syntax=docker/dockerfile:1
# -----------------------------------------------------------------------------
# PHP-FPM + Nginx in one image, run by supervisord.
# Build from the REPO ROOT:  docker build -f docker/Dockerfile -t php-app .
#
# Why one image: the brief asks for "a Dockerfile", and one container is the
# simplest unit to run on Cloud Run and locally. Cloud Run sidecars
# (Nginx and PHP-FPM as separate containers) are the documented upgrade.
# Docs: https://cloud.google.com/run/docs/container-contract
# -----------------------------------------------------------------------------

# --- Stage 1: install PHP dependencies (no dev deps in the final image) ------
FROM composer:2 AS vendor
WORKDIR /app
COPY app/composer.json app/composer.lock* ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --no-scripts --no-autoloader
COPY app/src ./src
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative

# --- Stage 2: runtime ---------------------------------------------------------
FROM php:8.5-fpm-alpine AS runtime

# `apk upgrade` pulls OS security patches released since the base image was
# published; every CI build therefore gets the latest fixes. Base image tags
# are kept current by Dependabot (.github/dependabot.yml) and every image is
# scanned by Trivy before it can be pushed or deployed.
# nginx + supervisor from Alpine; pdo_mysql + opcache compiled into PHP.
RUN apk upgrade --no-cache \
 && apk add --no-cache nginx supervisor \
 && docker-php-ext-install pdo_mysql opcache \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY docker/php/app.ini       "$PHP_INI_DIR/conf.d/zz-app.ini"
COPY docker/php/zzz-app.conf  /usr/local/etc/php-fpm.d/zzz-app.conf
COPY docker/nginx/nginx.conf  /etc/nginx/nginx.conf
COPY docker/supervisor/supervisord.conf /etc/supervisord.conf

WORKDIR /var/www/html
COPY --from=vendor /app/vendor ./vendor
COPY app/src    ./src
COPY app/public ./public

# Run everything as the unprivileged www-data user (uid 82 on Alpine).
# Nginx listens on 8080 and writes pid/temp files under /tmp, so no root needed.
RUN chown -R www-data:www-data /var/www/html
USER www-data

# Cloud Run sends traffic to $PORT (8080 by default); our Nginx listens there.
EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
