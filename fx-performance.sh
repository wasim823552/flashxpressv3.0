#!/bin/bash
#===============================================================================
# FlashXpress - Performance Optimization Script
# Enables Redis, FastCGI Cache, Brotli, HTTP/3 and optimizes PHP
#===============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN=$1
PHP_VER=$(cat /etc/flashxpress/default-php 2>/dev/null || echo "8.4")

echo "FlashXpress Performance Optimization"
echo "====================================="

# Enable Redis
echo -e "${YELLOW}[1/4] Enabling Redis Object Cache...${NC}"
if command -v redis-cli &> /dev/null; then
    systemctl enable redis-server
    systemctl start redis-server
    echo "Redis is now active"
else
    apt install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server
fi

# Optimize PHP settings for all installed versions
echo -e "${YELLOW}[2/4] Optimizing PHP settings...${NC}"
for VER in 8.4 8.5; do
    PHP_INI="/etc/php/${VER}/fpm/php.ini"
    if [ -f "$PHP_INI" ]; then
        # Increase memory limit
        sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
        # Increase max execution time
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
        # Increase upload limits
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' $PHP_INI
        sed -i 's/post_max_size = .*/post_max_size = 64M/' $PHP_INI
        # Enable OPcache
        sed -i 's/;opcache.enable=1/opcache.enable=1/' $PHP_INI
        sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=256/' $PHP_INI
        sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=16/' $PHP_INI
        sed -i 's/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=20000/' $PHP_INI
        
        systemctl restart php${VER}-fpm
        echo "PHP ${VER} optimized"
    fi
done

# Install Brotli for NGINX
echo -e "${YELLOW}[3/4] Installing Brotli compression...${NC}"
apt install -y libnginx-mod-http-brotli-filter || true

# Add Brotli config to NGINX
if ! grep -q "brotli on" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    # Brotli Compression\n    brotli on;\n    brotli_comp_level 6;\n    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;' /etc/nginx/nginx.conf
fi

# Enable FastCGI Cache
echo -e "${YELLOW}[4/4] Configuring FastCGI Cache...${NC}"
mkdir -p /var/cache/nginx/fastcgi
chown -R www-data:www-data /var/cache/nginx

# Add cache zone to NGINX config
if ! grep -q "fastcgi_cache_path" /etc/nginx/nginx.conf; then
    sed -i '/http {/a\    # FastCGI Cache\n    fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=FXCACHE:100m inactive=60m max_size=1g;' /etc/nginx/nginx.conf
fi

# Enable HTTP/3 (QUIC) - requires NGINX 1.25+
echo -e "${YELLOW}Enabling HTTP/3 (QUIC)...${NC}"
if nginx -v 2>&1 | grep -q "1.25\|1.26\|1.27"; then
    sed -i 's/listen 443 ssl;/listen 443 quic reuseport;\n    listen 443 ssl;/' /etc/nginx/sites-available/* 2>/dev/null || true
    sed -i '/listen 443/a\    add_header Alt-Svc '\''h3=":443"; ma=86400'\'';' /etc/nginx/sites-available/* 2>/dev/null || true
fi

systemctl reload nginx

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Performance Optimization Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Enabled features:"
echo "  ✓ Redis Object Cache"
echo "  ✓ PHP OPcache (256MB)"
echo "  ✓ Brotli Compression"
echo "  ✓ FastCGI Cache (1GB)"
echo ""
echo "Current PHP Version: ${PHP_VER}"
echo ""
echo "For site-specific cache, run:"
echo "  sudo fx cache enable yoursite.com"
