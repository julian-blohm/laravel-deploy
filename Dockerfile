FROM dunglas/frankenphp

RUN install-php-extensions \
    pcntl

COPY . /app

RUN chmod -R 775 storage bootstrap/cache
RUN chmod -R 775 storage storage

CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=80"]
