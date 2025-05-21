# How to set up Laravel App on Lightsail instance (minimal setup)
## Prerequisites
- Laravel App needs to be configured running on frankenphp
- https://laravel.com/docs/12.x/octane

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
- ssh into instance `ssh -i <your-ssh-key.pem> ubuntu@<your-static-ip>`

### 2.1 Setup prerequisites for the app
- Execute following commands (or put them in a bash scrip an run it)

```bash
#!/bin/bash

# Update & upgrade
sudo apt update && sudo apt upgrade -y

# Add PHP 8.3 repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP 8.3 and required extensions
sudo apt install php8.3 php8.3-cli php8.3-mbstring php8.3-xml php8.3-curl \
php8.3-mysql php8.3-sqlite3 php8.3-bcmath php8.3-zip unzip curl git -y

# Install MySQL (for local database)
sudo apt install mysql-server -y

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

#Install Frankenphp
curl -fsSL https://github.com/dunglas/frankenphp/releases/latest/download/frankenphp-linux-x86_64 -o frankenphp
chmod +x frankenphp
sudo mv frankenphp /usr/local/bin/frankenphp
```

OPTIONAL: Save this script as `setup.sh`, upload it to your instance, and run it using:

```bash
chmod +x setup.sh
./setup.sh
```
### 2.2 Check existing 'port blocker' like apache
```bash
# Check apache2 status
systemctl status apache2

# Stop & disable apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# OPTIONAL but good "houskeeping" - remove apache
sudo apt remove apache2 -y
sudo apt autoremove -y
```


## 3. Initial Laravel Setup
### 3.1 Setup Project
```bash
cd /var/www
sudo git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git laravel
cd laravel
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
```
### 3.2 Set Laravel Permissions
```bash
sudo chown -R $USER:www-data .
chmod -R 775 storage bootstrap/cache
```
### 3.3 MySQL Setup
```bash
sudo mysql_secure_installation

# Log in
sudo mysql -u root -p

# In MySQL:
# Create DB
CREATE DATABASE laravel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
# Create User
CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'laravel_password';
# Set Privileges
GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'localhost';
# Load privileges
FLUSH PRIVILEGES;
# Exit MySQL
EXIT;
```

### 3.4 Update Laravel .env
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=laravel_user
DB_PASSWORD=laravel_password
```

### 3.5 Migrate Database
- ensure to execute from inside the laravel project (`/var/www/laravel`)
```bash
php artisan migrate --force
```

## 4. Start Laravel with FrankenPHP
- ensure that your setup has been successful so far
```bash
php artisan octane:install --server=frankenphp
php artisan octane:frankenphp --host=0.0.0.0 --port=80
```
- stop the process, when you tested the project and everything runs so far :) 

## 5. Setup Domain & SSL / HTTPS
- We will be using Caddy for HTTPS
- Why?
    - No complex setup needed
    - works seemlessly with frankenphp
    - zero-config https via Let's Encrypt

### 5.1 Install Caddy
```bash
# Install required packages for managing HTTPS repositories and verifying keys
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https

# Add Caddy’s official GPG key to your system to verify package authenticity
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add the Caddy package repository to your sources list (for automatic updates)
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian all main" | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Install Caddy
sudo apt update
sudo apt install caddy -y
```

### 5.2 Update DNS Settings with Domain
- lightsail console
    - go to your networking tab in lightsail console
    - attach a static ip to your instance and give it a name
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

### 5.3 Configure Caddy
- edit caddyfile
```bash
sudo vi /etc/caddy/Caddyfile
```
- replace contents with:
```
yourdomain.com {
    reverse_proxy 127.0.0.1:80
}
```
- restart caddy
```bash
sudo systemctl reload caddy
```
- or start if not running
```bash
sudo systemctl enable --now caddy
```
### 5.4 Test it on your domain
- and don'T forget to run your application again ;)
```bash
php artisan octane:frankenphp --host=0.0.0.0 --port=80
```












