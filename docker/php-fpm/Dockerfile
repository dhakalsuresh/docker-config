FROM php:7.1-fpm-alpine3.9 as base
LABEL maintainer="Linksol"

ARG NEWRELIC_VERSION
ARG NEW_RELIC_APP_NAME
ARG NEW_RELIC_LICENSE_KEY

# ---------------------------------------------------------- Setup build options
ARG DOCKER_USER_UID=true
ARG DOCKER_USER_GID=true

RUN if [ -z ${DOCKER_USER_UID+x} ]; then echo "DOCKER_USER_UID is unset"; DOCKER_USER_UID=1000; else echo "DOCKER_USER_UID is set to '$DOCKER_USER_UID'"; fi && \
    if [ -z ${DOCKER_USER_GID+x} ]; then echo "DOCKER_USER_GID is unset"; DOCKER_USER_GID=1000; else echo "DOCKER_USER_GID is set to '$DOCKER_USER_GID'"; fi

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Health check for the FPM server on port 9000.
HEALTHCHECK --interval=30s --timeout=5s \
  CMD REDIRECT_STATUS=true SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000

RUN apk --update add --no-cache \
      tzdata fcgi libjpeg-turbo-dev libpng-dev libmcrypt-dev zlib-dev curl \
      && rm -rf /var/cache/apk/*

# --------------------------------------------------------- Install dependancies
RUN apk add --update --no-cache \
        icu-libs \
        libintl \
        libzip \
        git \
        ssmtp \
        patch


# --------------------------------------------------- Install build dependancies
RUN apk add --update --no-cache --virtual .docker-php-global-dependancies \
        # Build dependencies for gd \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        gettext-dev \
        icu-dev \
        # Build dependencies for XML part \
        libxml2-dev \
        ldb-dev \
        libzip-dev \
        # Build dependancies for Pecl \
        autoconf \
        g++ \
        make \
        # Build dependancy for APCu \
        pcre-dev \
        wget

# ------------------------------------------------------- Install php extensions
RUN php -m && \
    docker-php-ext-configure bcmath --enable-bcmath && \
    docker-php-ext-configure gettext && \
    docker-php-ext-configure intl --enable-intl && \
    docker-php-ext-configure mbstring --enable-mbstring && \
    docker-php-ext-configure opcache --enable-opcache && \
    docker-php-ext-configure pcntl --enable-pcntl && \
    docker-php-ext-configure soap && \
    docker-php-ext-configure zip --enable-zip --with-libzip && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ && \
    docker-php-ext-install bcmath \
        gd \
        gettext \
        intl \
        mbstring \
        opcache \
        pcntl \
        soap \
        dom \
        -j$(nproc) \
        iconv \
        zip && \
    php -m

# Enable EXIF
RUN docker-php-ext-install exif && \
    docker-php-ext-enable exif && \
    php -m;
    
# Enable imagick
RUN apk add --update --no-cache \
          imagemagick \
          imagemagick-libs && \
      # Build dependancy for imagick \
      apk add --update --no-cache --virtual .docker-php-imagick-dependancies \
          imagemagick-dev && \
      pecl install imagick && \
      docker-php-ext-enable imagick && \
      apk del .docker-php-imagick-dependancies && \
      php -m;

# Enable MySQL
RUN apk add --update --no-cache --virtual .docker-php-mysql-dependancies \
          mysql-client && \
      # MySQLnd is already compiled. \
      # See: https://github.com/docker-library/php/issues/167 \
      docker-php-ext-configure mysqli && \
      docker-php-ext-configure pdo_mysql && \
      docker-php-ext-install mysqli \
          pdo_mysql && \
      apk del .docker-php-mysql-dependancies && \
      php -m;


#  For  Test suite
RUN pecl install pcov \
 	&& docker-php-ext-enable pcov

# Install xdebug
RUN apk add --no-cache \
 	&& pecl install xdebug-2.9.2 \
 	&& docker-php-ext-enable xdebug

# --------------------------------------------- Conditionnal tools installations
# Install composer.
RUN EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig) && \
      php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
      ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');") && \
      if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then \
        >&2 echo 'ERROR: Invalid installer signature' && \
        rm composer-setup.php && \
        exit 1; \
      else \
        php composer-setup.php --install-dir=/usr/bin --filename=composer && \
        RESULT=$? && \
        rm composer-setup.php && \
        exit $RESULT && \
        composer -V; \
      fi;

# use dumb-init to handle SIGINT, SIGTERM, etc
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64 && \
      echo "057ecd4ac1d3c3be31f82fc0848bf77b1326a975b4f8423fe31607205a0fe945  /usr/local/bin/dumb-init" | sha256sum -c - && \
      chmod 755 /usr/local/bin/dumb-init

RUN mkdir -p /var/log/newrelic /var/run/newrelic && \
      touch /var/log/newrelic/php_agent.log /var/log/newrelic/newrelic-daemon.log && \
      chmod -R g+ws /tmp /var/log/newrelic/ /var/run/newrelic/ && \
      chown -R 1001:0 /tmp /var/log/newrelic/ /var/run/newrelic/ && \
      # Download and install Newrelic binary
    export NEWRELIC_VERSION=$(curl -sS https://download.newrelic.com/php_agent/release/ | sed -n 's/.*>\(.*linux-musl\).tar.gz<.*/\1/p') && \
    cd /tmp && curl -sS "https://download.newrelic.com/php_agent/release/${NEWRELIC_VERSION}.tar.gz" | gzip -dc | tar xf - && \
    cd "${NEWRELIC_VERSION}" && \
    NR_INSTALL_SILENT=true ./newrelic-install install && \
    rm -f /var/run/newrelic-daemon.pid && \
    rm -f /tmp/.newrelic.sock && \
    # For Newrelic's APM (Application Monitoring) license and appname are required.
    # Enviroment variables `NEW_RELIC_LICENSE_KEY` and `NEW_RELIC_APP_NAME` are required when buidling Docker image,
    # so you must set them in your **BuildConfig** Environments.
    sed -i \
    -e "s/newrelic.license =.*/newrelic.license = ${NEW_RELIC_LICENSE_KEY}/" \
    -e "s/newrelic.appname =.*/newrelic.appname = ${NEW_RELIC_APP_NAME}/" \
    /usr/local/etc/php/conf.d/newrelic.ini

EXPOSE 9000

# source stage
FROM base AS source
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY php.ini /usr/local/etc/php/conf.d/php.ini
COPY ./ /var/www/html

# prod stage
FROM source AS prod

# Metadata params
ARG BUILD_DATE
ARG BUILD_SHA
ARG NAME
ARG VERSION

# Metadata
LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.build-sha=$BUILD_SHA \
  org.label-schema.name=$NAME \
  org.label-schema.version=$VERSION

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["php-fpm", "-F", "-R"]
