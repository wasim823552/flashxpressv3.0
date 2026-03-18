#!/bin/bash
#===============================================================================
# FlashXpress - WordPress Site Creator
# Usage: fx-site-create.sh domain.com [--wp|--php|--html]
#===============================================================================

set -e

DOMAIN=$1
TYPE=$2
PHP_VER="8.5"

if [ -z "$DOMAIN" ]; then
    echo "Usage: fx-site-create.sh domain.com [--wp|--php|--html]"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Creating site: $DOMAIN${NC}"

# Create site directory
mkdir -p /var/www/$DOMAIN/public
mkdir -p /var/www/$DOMAIN/logs
chown -R www-data:www-data /var/www/$DOMAIN

# Create database
DB_NAME=$(echo $DOMAIN | tr -d '.-' | cut -c1-16)
DB_USER="fx_${DB_NAME}"
DB_PASS=$(openssl rand -base64 12)

mysql -u root -pflashxpress <<MYSQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL

# Download WordPress
if [[ "$TYPE" == "--wp" ]] || [[ -z "$TYPE" ]]; then
    echo "Installing WordPress..."
    cd /var/www/$DOMAIN/public
    wp core download --allow-root
    wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root
    ADMIN_PASS=$(openssl rand -base64 12)
    wp core install --url=$DOMAIN --title="$DOMAIN" --admin_user=admin --admin_password=$ADMIN_PASS --admin_email=admin@$DOMAIN --allow-root
    chown -R www-data:www-data /var/www/$DOMAIN
fi

# Create NGINX config
cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN www.DOMAIN;
    root /var/www/DOMAIN/public;
    index index.php index.html;
    
    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # FastCGI Cache
    set $skip_cache 0;
    if ($request_method = POST) { set $skip_cache 1; }
    if ($query_string != "") { set $skip_cache 1; }
    if ($request_uri ~* "/wp-admin/|/wp-login.php") { set $skip_cache 1; }
    
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/phpPHPVER-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Deny access to sensitive files
    location ~ /\. { deny all; }
    location ~ /wp-config.php { deny all; }
}
NGINX

# Replace placeholders
sed -i "s/DOMAIN/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN
sed -i "s/PHPVER/$PHP_VER/g" /etc/nginx/sites-available/$DOMAIN

# Enable site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# SSL with Let's Encrypt
echo "Installing SSL certificate..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || true

# Save credentials
cat > /var/www/$DOMAIN/.fx-creds << CREDS
DOMAIN=$DOMAIN
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
WP_ADMIN=admin
WP_PASS=$ADMIN_PASS
CREDS
chmod 600 /var/www/$DOMAIN/.fx-creds

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Site Created Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "URL: https://$DOMAIN"
echo "Admin: https://$DOMAIN/wp-admin"
echo "Database: $DB_NAME"
echo "DB User: $DB_USER"
echo "DB Pass: $DB_PASS"
echo ""
echo "Credentials saved: /var/www/$DOMAIN/.fx-creds"
