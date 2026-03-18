#!/bin/bash
#===============================================================================
#  ⚡ FlashXpress - WORLD'S FASTEST WordPress Stack
#  https://wp.flashxpress.cloud | Version 3.1.0
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
echo "████████╗██╗      █████╗ ██████╗ ███████╗██╗  ██╗██╗   ██╗"
echo "██╔════╝██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ██╔╝"
echo "█████╗  ██║     ███████║██████╔╝███████╗███████║ ╚████╔╝ "
echo "██╔══╝  ██║     ██╔══██║██╔══██╗╚════██║██╔══██║  ╚██╔╝  "
echo "██║     ███████╗██║  ██║██████╔╝███████║██║  ██║   ██║   "
echo "╚═╝     ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝   "
echo -e "${NC}"
echo -e "${BOLD}${GREEN}⚡ FlashXpress v3.1.0 - World's Fastest WordPress Stack${NC}"
echo -e "${BLUE}   Lowest TTFB | FlashXPRESS HIT Cache | HTTP/3 Ready${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Error: Please run as root${NC}"
    echo "Usage: curl -sSL https://wp.flashxpress.cloud/install | sudo bash"
    exit 1
fi

DB_PASS="flashxpress"
export DEBIAN_FRONTEND=noninteractive

echo -e "${GREEN}► Installing FlashXpress Stack...${NC}"
echo ""

# ============================================================================
# STEP 1: Update System
# ============================================================================
echo -e "${YELLOW}[1/6] Updating system...${NC}"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
echo -e "${GREEN}✓ System updated${NC}"

# ============================================================================
# STEP 2: Install NGINX
# ============================================================================
echo -e "${YELLOW}[2/6] Installing NGINX...${NC}"

apt-get install -y -qq nginx

mkdir -p /var/cache/nginx/fastcgi
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
chown -R www-data:www-data /var/cache/nginx

cat > /etc/nginx/nginx.conf << 'ENDNGINX'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 65535;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 64m;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent cache=$upstream_cache_status';
    access_log /var/log/nginx/access.log main;

    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=FLASHXPRESS:100m inactive=60m max_size=1g;
    fastcgi_cache_key "$scheme$request_method$host$request_uri";
    fastcgi_cache_lock on;

    include /etc/nginx/sites-enabled/*;
}
ENDNGINX

systemctl enable nginx
systemctl start nginx
echo -e "${GREEN}✓ NGINX installed with FlashXPRESS Cache${NC}"

# ============================================================================
# STEP 3: Install MariaDB
# ============================================================================
echo -e "${YELLOW}[3/6] Installing MariaDB 11.4...${NC}"

curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version=mariadb-11.4
apt-get update -qq
apt-get install -y -qq mariadb-server mariadb-client

systemctl enable mariadb
systemctl start mariadb

mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}'; FLUSH PRIVILEGES;" 2>/dev/null || true

echo -e "${GREEN}✓ MariaDB 11.4 installed${NC}"

# ============================================================================
# STEP 4: Install PHP (with proper detection and fallback)
# ============================================================================
echo -e "${YELLOW}[4/6] Installing PHP...${NC}"

# Add PHP repository
echo -e "${CYAN}  Adding PHP repository...${NC}"
add-apt-repository -y ppa:ondrej/php
apt-get update -qq

# Try PHP versions in order
PHP_VER=""
for VER in 8.4 8.3 8.2 8.1; do
    echo -e "${CYAN}  Trying PHP ${VER}...${NC}"

    # Install PHP packages
    if apt-get install -y php${VER}-fpm php${VER}-mysql php${VER}-curl php${VER}-gd php${VER}-mbstring php${VER}-xml php${VER}-zip php${VER}-bcmath php${VER}-intl php${VER}-opcache php${VER}-readline 2>/dev/null; then
        # Check if FPM binary exists
        if [ -x "/usr/sbin/php-fpm${VER}" ]; then
            PHP_VER=$VER
            echo -e "${GREEN}  ✓ PHP ${VER} packages installed${NC}"
            break
        fi
    fi
    echo -e "${YELLOW}  PHP ${VER} not available, trying next...${NC}"
done

if [ -z "$PHP_VER" ]; then
    echo -e "${RED}✗ ERROR: Could not install PHP. Trying system default...${NC}"
    apt-get install -y php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath php-intl php-opcache
    PHP_VER="default"
fi

# Configure OPcache
if [ -d "/etc/php/${PHP_VER}/fpm/conf.d" ]; then
    cat > /etc/php/${PHP_VER}/fpm/conf.d/99-flashxpress.ini << 'ENDOPCACHE'
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=50000
opcache.validate_timestamps=0
opcache.jit_buffer_size=64M
opcache.jit=1255
memory_limit=256M
upload_max_filesize=64M
post_max_size=64M
ENDOPCACHE

    cat > /etc/php/${PHP_VER}/fpm/pool.d/www.conf << ENDFPM
[www]
user = www-data
group = www-data
listen = /run/php/php${PHP_VER}-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 1000
ENDFPM
fi

mkdir -p /run/php
systemctl daemon-reload

# Start PHP-FPM
echo -e "${CYAN}  Starting PHP-FPM service...${NC}"
if [ "$PHP_VER" != "default" ]; then
    systemctl enable php${PHP_VER}-fpm
    systemctl start php${PHP_VER}-fpm
else
    systemctl enable php-fpm
    systemctl start php-fpm
fi

sleep 2
echo -e "${GREEN}✓ PHP installed and running${NC}"

# Install PHP Redis extension
apt-get install -y -qq php${PHP_VER}-redis 2>/dev/null || apt-get install -y -qq php-redis 2>/dev/null || true

# ============================================================================
# STEP 5: Install Redis
# ============================================================================
echo -e "${YELLOW}[5/6] Installing Redis...${NC}"

curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis.gpg 2>/dev/null
echo "deb [signed-by=/usr/share/keyrings/redis.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/redis.list
apt-get update -qq
apt-get install -y -qq redis

sed -i 's/^maxmemory.*/maxmemory 128mb/' /etc/redis/redis.conf 2>/dev/null || echo "maxmemory 128mb" >> /etc/redis/redis.conf
sed -i 's/^maxmemory-policy.*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf 2>/dev/null || echo "maxmemory-policy allkeys-lru" >> /etc/redis/redis.conf

systemctl enable redis-server
systemctl start redis-server
echo -e "${GREEN}✓ Redis installed${NC}"

# ============================================================================
# STEP 6: WP-CLI, Certbot, Security
# ============================================================================
echo -e "${YELLOW}[6/6] Installing WP-CLI & Security...${NC}"

curl -sSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
chmod +x /usr/local/bin/wp

apt-get install -y -qq certbot python3-certbot-nginx

ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw allow 443/udp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

apt-get install -y -qq fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo -e "${GREEN}✓ WP-CLI, Certbot, Security installed${NC}"

# ============================================================================
# Create directories and config
# ============================================================================
mkdir -p /etc/flashxpress
mkdir -p /var/www/html
mkdir -p /var/www/backups
mkdir -p /opt/flashxpress

echo "${PHP_VER}" > /etc/flashxpress/default-php
echo "${DB_PASS}" > /etc/flashxpress/db-password
chmod 600 /etc/flashxpress/db-password

# Create fx command
cat > /usr/local/bin/fx << 'ENDFX'
#!/bin/bash
PHP_VER=$(cat /etc/flashxpress/default-php 2>/dev/null || echo "8.3")
DB_PASS=$(cat /etc/flashxpress/db-password 2>/dev/null || echo "flashxpress")

case "$1" in
    status)
        echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[1;32m  FlashXpress Stack Status\033[0m"
        echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "  NGINX:      $(systemctl is-active nginx)"
        echo "  MariaDB:    $(systemctl is-active mariadb)"
        echo "  PHP-FPM:    $(systemctl is-active php${PHP_VER}-fpm 2>/dev/null || echo 'active')"
        echo "  Redis:      $(systemctl is-active redis-server)"
        echo "  Firewall:   $(ufw status 2>/dev/null | head -1 | awk '{print $2}')"
        echo ""
        echo "  PHP Version: ${PHP_VER}"
        ;;
    site)
        /opt/flashxpress/site-create.sh "$3"
        ;;
    cache)
        rm -rf /var/cache/nginx/fastcgi/*
        systemctl reload nginx
        echo -e "\033[32m✓ Cache purged!\033[0m"
        ;;
    db)
        echo "Database Credentials:"
        echo "  Host: localhost"
        echo "  User: root"
        echo "  Pass: ${DB_PASS}"
        ;;
    *)
        echo -e "\033[1;36mFlashXpress v3.1.0\033[0m"
        echo ""
        echo "Commands:"
        echo "  fx status          Show stack status"
        echo "  fx site create     Create WordPress site"
        echo "  fx cache           Clear FastCGI cache"
        echo "  fx db              Show database credentials"
        ;;
esac
ENDFX
chmod +x /usr/local/bin/fx

# Create site creation script
cat > /opt/flashxpress/site-create.sh << 'ENDSITE'
#!/bin/bash
DOMAIN=$1
PHP_VER=$(cat /etc/flashxpress/default-php 2>/dev/null || echo "8.3")
DB_PASS=$(cat /etc/flashxpress/db-password 2>/dev/null || echo "flashxpress")

if [ -z "$DOMAIN" ]; then
    echo "Usage: fx site create domain.com"
    exit 1
fi

echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m  Creating Site: ${DOMAIN}\033[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

mkdir -p /var/www/${DOMAIN}/public
mkdir -p /var/www/${DOMAIN}/logs

DB_NAME=$(echo ${DOMAIN} | tr -d '.-' | cut -c1-16)
DB_USER="fx_${DB_NAME}"
DB_PASS_NEW=$(openssl rand -base64 12 | tr -d '/+=' | head -c16)

mysql -u root -p"${DB_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null
mysql -u root -p"${DB_PASS}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS_NEW}';" 2>/dev/null
mysql -u root -p"${DB_PASS}" -e "GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
mysql -u root -p"${DB_PASS}" -e "FLUSH PRIVILEGES;" 2>/dev/null

cd /var/www/${DOMAIN}/public
wp core download --allow-root --quiet 2>/dev/null || curl -sSL https://wordpress.org/latest.tar.gz | tar xz --strip-components=1
wp config create --dbname=${DB_NAME} --dbuser=${DB_USER} --dbpass=${DB_PASS_NEW} --allow-root --quiet 2>/dev/null || true

ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c16)
wp core install --url=${DOMAIN} --title="${DOMAIN}" --admin_user=admin --admin_password=${ADMIN_PASS} --admin_email=admin@${DOMAIN} --allow-root --quiet 2>/dev/null || true

wp plugin install redis-cache --activate --allow-root --quiet 2>/dev/null || true
wp redis enable --allow-root --quiet 2>/dev/null || true

chown -R www-data:www-data /var/www/${DOMAIN}

cat > /etc/nginx/sites-available/${DOMAIN} << ENDNGINX
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    root /var/www/${DOMAIN}/public;
    index index.php;

    set \$skip_cache 0;
    if (\$request_method = POST) { set \$skip_cache 1; }
    if (\$query_string != "") { set \$skip_cache 1; }
    if (\$request_uri ~* "/wp-admin|/wp-login.php|xmlrpc.php") { set \$skip_cache 1; }
    if (\$http_cookie ~* "wordpress_logged_in|wp-postpass") { set \$skip_cache 1; }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_cache FLASHXPRESS;
        fastcgi_cache_valid 200 60m;
        fastcgi_cache_bypass \$skip_cache;
        fastcgi_no_cache \$skip_cache;
        add_header X-FlashXpress-Cache \$upstream_cache_status always;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)\$ {
        expires 365d;
        add_header X-FlashXpress-Cache "HIT-STATIC";
    }
}
ENDNGINX

ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN} --quiet 2>/dev/null || echo "Run: certbot --nginx -d ${DOMAIN} for SSL"

echo ""
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m  ✅ Site Created!\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
echo "  URL:      https://${DOMAIN}"
echo "  Admin:    https://${DOMAIN}/wp-admin"
echo "  DB Name:  ${DB_NAME}"
echo "  DB User:  ${DB_USER}"
echo "  DB Pass:  ${DB_PASS_NEW}"
echo "  WP User:  admin"
echo "  WP Pass:  ${ADMIN_PASS}"
ENDSITE
chmod +x /opt/flashxpress/site-create.sh

# Success
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}   ✅ FLASHXPRESS v3.1.0 INSTALLED SUCCESSFULLY!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Installed Components:${NC}"
echo -e "  ${GREEN}✓${NC} NGINX with FlashXPRESS FastCGI Cache"
echo -e "  ${GREEN}✓${NC} MariaDB 11.4"
echo -e "  ${GREEN}✓${NC} PHP ${PHP_VER} + OPcache JIT"
echo -e "  ${GREEN}✓${NC} Redis Object Cache"
echo -e "  ${GREEN}✓${NC} WP-CLI + Certbot"
echo -e "  ${GREEN}✓${NC} UFW Firewall + Fail2Ban"
echo ""
echo -e "${CYAN}Cache Feature:${NC}"
echo -e "  Response Header: ${GREEN}X-FlashXpress-Cache: HIT${NC}"
echo ""
echo -e "${CYAN}Quick Commands:${NC}"
echo -e "  ${YELLOW}fx status${NC}          Show stack status"
echo -e "  ${YELLOW}fx site create${NC}     Create WordPress site"
echo -e "  ${YELLOW}fx db${NC}              Show database credentials"
echo ""
echo -e "${CYAN}Database:${NC}"
echo -e "  Host: localhost"
echo -e "  User: root"
echo -e "  Pass: ${DB_PASS}"
echo ""
echo -e "${BLUE}Website: https://wp.flashxpress.cloud${NC}"
