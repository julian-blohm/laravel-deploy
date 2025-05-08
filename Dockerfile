FROM dunglas/frankenphp

RUN install-php-extensions \
    pcntl

COPY . /app

EXPOSE 8000

ENTRYPOINT ["php", "artisan", "octane:frankenphp"]