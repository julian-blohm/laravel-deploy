FROM dunglas/frankenphp

RUN install-php-extensions \
    pcntl

COPY . /app

ENTRYPOINT ["php", "artisan", "octane:frankenphp"]