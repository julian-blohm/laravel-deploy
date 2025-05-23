# How to set up Laravel App on Lightsail instance (minimal setup)
## Prerequisites
- Laravel App needs to be configured running on frankenphp
    - https://laravel.com/docs/12.x/octane
- Domain purchased/available
- AWS lightsail account

## 1. Provision Lightsail Instance
- https://docs.aws.amazon.com/lightsail/latest/userguide/getting-started-with-amazon-lightsail.html
- Region: nearest to you
- Platform: Linux/Unix
- Blueprint: Ubuntu 24.04 LTS
- create or assign SSH key
- Network type: dual-stack
- Size: 1GB or 2GB RAM at least
- instance name: don't use a random name like "tom"

## 2. Configure the instance 
- lightsail console
    - go to your networking tab in lightsail console
    - attach a static ip to your instance and give it a name
- ssh into instance `ssh -i <your-ssh-key.pem> ubuntu@<your-static-ip>`

### 2.1 Check existing 'port blocker' like apache
```bash
# Update & upgrade
sudo apt update && sudo apt upgrade -y

# Check apache2 status
systemctl status apache2

# Stop & disable apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# OPTIONAL but good "houskeeping" - remove apache
sudo apt remove apache2 -y
sudo apt autoremove -y
```

### 2.2 Setup prerequisites for the app
- Execute following commands (or put them in a bash scrip an run it)

```bash
#!/bin/bash

# Update & upgrade
sudo apt update && sudo apt upgrade -y

# Add PHP 8.3 repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP 8.3 and required extensions
sudo apt install \
    php8.3 \
    php8.3-cli \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-curl \
    php8.3-bcmath \
    -y

# Install tools that we also need
sudo apt install \
    unzip \
    curl \
    git \
    supervisor \
    -y 
    
# Install Composer
cd ~
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer      
```

## 3. MySQL / MariaDB Setup
```bash
# Install and Setup MySQL/MariaDB (for local database)
sudo apt install mariadb-server -y
sudo systemctl enable mysql
sudo systemctl start mysql
sudo systemctl status mysql

#Secure MYSQL / MAriaDB
sudo mysql_secure_installation
### admin, n, n, n, Y, Y, Y

# Log in (pw = admin)
sudo mysql -u root -p

# In MySQL:
# Create DB
CREATE DATABASE laravel_db;
# Create User
CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'laravel_password';
# Set Privileges
GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'localhost';
# Load privileges
FLUSH PRIVILEGES;
# Exit MySQL
EXIT;
```

## 4. Initial Laravel Setup
### 4.1 Get Project
```bash
cd /var/www
sudo git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git laravel
cd laravel
```

### 4.2 Set Laravel Permissions
```bash
sudo chown -R $USER:www-data .
sudo chmod -R 775 storage bootstrap/cache
```

### 4.3 Install PHP Dependencies
```bash
composer install --no-dev --optimize-autoloader
```

### 4.3 Set up Laravel .env
```bash
cp .env.example .env
sudo vi .env
```

- set the following
```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=laravel_user
DB_PASSWORD=laravel_password
```

- generate app key
```bash
php artisan key:generate
```

### 4.4 Migrate Database
- ensure to execute from inside the laravel project (`/var/www/laravel`)
```bash
php artisan migrate --force
```

### 4.5 Start Laravel with FrankenPHP
- ensure that your setup has been successful so far; choose yes to download the binary
```bash
php artisan octane:frankenphp --host=0.0.0.0 --port=80
```
- stop the process, when you tested the project and everything runs so far :) 

## 5. Setup Domain / DNS Setting
- lightsail console
    - go to your networking tab in lightsail console
    - copy your static ip
- your domain provider
    - go to dns settings
    - create an A record
        - Host: @ or leave blank
        - Type: A
        - Value: the lightsail static ip
        - TTL: Default to 1 hour
    - OPTIONAL: set www subdomain
        - create a CNAME record for `www`pointing to your root domain or create another A record with the same IP
    - Wait for DNS propagation (minutes to hours wait time)
    - `ping yourdomain.com` to test im reachable


## 5. Set up FrnakenPHP on the instance
### 5.1 Install FrankenPHP on the instance
```bash
# Get it
curl -LO https://github.com/dunglas/frankenphp/releases/download/v1.6.0/frankenphp-linux-x86_64
sudo mv frankenphp-linux-amd64 /usr/local/bin/frankenphp
sudo chmod +x /usr/local/bin/frankenphp

# Check it is there
frankenphp --version

# Give it permission to bind to ports below 1024
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/frankenphp
```

### 5.2 Create Caddyfile
- create a caddyfile in the laravel project
```
yourdomain.com {
    root * /var/www/laravel/public
    php {
        worker /var/www/laravel/public/index.php
    }
    encode gzip
    file_server
}
```

## 6. Run the Application via Supervisor
- caddy will listen on port 443 and reverse proxy to frankenPHP running on port 9000
```bash
sudo vi /etc/supervisor/conf.d/frankenphp.conf
```

- paste:
```
[program:frankenphp]
directory=/var/www/stayfinder
command=/usr/local/bin/frankenphp run --config /var/www/laravel/Caddyfile
autostart=true
autorestart=true
stderr_logfile=/var/log/frankenphp.err.log
stdout_logfile=/var/log/frankenphp.out.log
user=root
```

- then reload supervisor and start the process
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start frankenphp
```
- check status
```bash
sudo supervisorctl status frankenphp

```

### 6.1 Check Firewall Setup
- In Lightsail console > Networking > Firewall, open ports 80 and 443 (TCP)

### 6.2 Verify HTTPS Access
```
curl -vk https://yourdomain.com
```

### 6.3 Troubleshooting Tips
- If you see HTTP 500 errors or blank page:
    - Check Laravel logs: `sudo tail -n 30 /var/www/stayfinder/storage/logs/laravel.log`
    - Check FrankenPHP logs: `sudo tail -n 30 /var/log/frankenphp.err.log` and `sudo tail -n 30 /var/log/frankenphp.out.log`
    - Check permissions on `storage` and `bootstrap/cache` folders
    - Temporarily set `APP_DEBUG=true` in `.env` to see error details in browser






## 5. Setup Domain & SSL / HTTPS
- We will be using Caddy for HTTPS
- Why?
    - No complex setup needed
    - works seemlessly with frankenphp
    - zero-config https via Let's Encrypt















