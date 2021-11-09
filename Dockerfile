FROM php:7.4-fpm-alpine

ENV EXT_APCU_VERSION=5.1.18
ENV EXT_REDIS_VERSION=5.3.1
ENV EXT_IGBINARY_VERSION=3.1.2

LABEL \
    MAINTAINER='lovizu <nug22kr@gmail.com>' \
    PHP_VERSION='7.4' \
    APCU_VERSION='${EXT_APCU_VERSION}' \
    REDIS_VERSION='${EXT_REDIS_VERSION}' \
    IGBINARY_VERSION='${EXT_IGBINARY_VERSION}'

RUN apk update && apk add git zip gnu-libiconv supervisor && \
    apk add --no-cache \
    nginx \
# for ext-intl
    icu-dev \
# for ext-zip
    zlib-dev libzip-dev \
# for ext-gd
    freetype libpng libjpeg-turbo \
    freetype-dev libpng-dev libjpeg-turbo-dev && \
# imagemagick
    apk add imagemagick imagemagick-dev && \
    apk add --update --no-cache autoconf g++ imagemagick-dev libtool make pcre-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick && \
    apk del autoconf g++ libtool make pcre-dev && \
# for ext-igbinary
    mkdir -p /usr/src/php/ext/igbinary /run/nginx/ && \
    curl -fsSL https://github.com/igbinary/igbinary/archive/$EXT_IGBINARY_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/igbinary --strip 1 && \
    docker-php-ext-configure gd \
        --with-freetype=/usr/include/ \
        --with-jpeg=/usr/include/ && \
    NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
    docker-php-ext-install -j${NPROC} opcache intl bcmath zip pdo_mysql sockets pcntl gd igbinary && \
    apk del freetype-dev libpng-dev libjpeg-turbo-dev && \
    docker-php-source delete

## for ext-apcu ext-redis
RUN docker-php-source extract && \
    mkdir -p /usr/src/php/ext/apcu /usr/src/php/ext/redis /usr/src/php/ext/ddtrace && \
    curl -fsSL https://github.com/krakjoe/apcu/archive/v$EXT_APCU_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/apcu --strip 1 && \
    curl -fsSL https://github.com/phpredis/phpredis/archive/$EXT_REDIS_VERSION.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 && \
    docker-php-ext-configure redis --enable-redis-igbinary && \
    NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
    docker-php-source delete && \
    echo 'apc.enable_cli = On' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini && \
    echo 'apc.serializer = igbinary' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini && \
    sed -i "s/display_errors = Off/display_errors = On/" /usr/local/etc/php/php.ini && \
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 16M/" /usr/local/etc/php/php.ini && \
    sed -i "s/memory_limit = .*/memory_limit = 2G/" /usr/local/etc/php/php.ini && \
    sed -i "s/post_max_size = .*/post_max_size = 16M/" /usr/local/etc/php/php.ini && \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /usr/local/etc/php/php.ini && \
    sed -i "s/variables_order = .*/variables_order = 'EGPCS'/" /usr/local/etc/php/php.ini && \
#    sed -i "s/session.serialize_handler = .*/session.serialize_handler = igbinary/" /usr/local/etc/php/php.ini && \
    sed -i "s/expose_php = .*/expose_php = Off/" /usr/local/etc/php/php.ini && \
# for php-fpm status
    sed -i "s/;pm.status_path = \/status/pm.status_path = \/status/" /usr/local/etc/php-fpm.d/www.conf && \
    sed -i "s/;ping.path = \/ping/ping.path = \/ping/" /usr/local/etc/php-fpm.d/www.conf

# cron
COPY docker/crontab /etc/cron.d/laravel
# nginx
COPY docker/vhost.conf /etc/nginx/http.d/default.conf
RUN chmod 0644 /etc/cron.d/laravel

# install composer & config packagist.kr
ENV COMPOSER_ALLOW_SUPERUSER 1
COPY --from=composer:2.0.2 /usr/bin/composer /usr/bin/composer
RUN composer config -g repos.packagist composer https://packagist.kr