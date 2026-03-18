#!/bin/bash
#===============================================================================
# FlashXpress - phpMyAdmin Installer
# Secure phpMyAdmin access with random URL
#===============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PMA_URL=${1:-"pma-$(openssl rand -hex 4)"}

echo "FlashXpress phpMyAdmin Setup"
echo "============================="

# Install phpMyAdmin
echo -e "${YELLOW}[1/3] Installing phpMyAdmin...${NC}"
apt install -y phpmyadmin

# Create secure NGINX config
echo -e "${YELLOW}[2/3] Creating secure access...${NC}"
cat > /etc/nginx/conf.d/pma.conf << PMA_CONF
# phpMyAdmin - Secure Access
location /${PMA_URL} {
    alias /usr/share/phpmyadmin;
    index index.php;
    
    # Allow only specific IPs (optional)
    # allow YOUR_IP;
    # deny all;
    
    location ~ ^/${PMA_URL}/(.+\.php)$ {
        alias /usr/share/phpmyadmin/\$1;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        include fastcgi_params;
    }
    
    location ~* ^/${PMA_URL}/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        alias /usr/share/phpmyadmin/\$1;
    }
}
PMA_CONF

nginx -t && systemctl reload nginx

# Create temp directory for phpMyAdmin
mkdir -p /usr/share/phpmyadmin/tmp
chown -R www-data:www-data /usr/share/phpmyadmin/tmp

echo -e "${YELLOW}[3/3] Generating access link...${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  phpMyAdmin Installed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Access URL:"
echo -e "${YELLOW}  https://your-server-ip/${PMA_URL}/${NC}"
echo ""
echo "MySQL Root Credentials:"
echo "  Username: root"
echo "  Password: flashxpress"
echo ""
echo "Important: Save this URL securely!"
echo "To disable: sudo rm /etc/nginx/conf.d/pma.conf && sudo systemctl reload nginx"
