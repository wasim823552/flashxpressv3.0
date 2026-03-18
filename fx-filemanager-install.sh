#!/bin/bash
#===============================================================================
# FlashXpress - File Manager Installer
# Web-based file manager for server management
#===============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FM_URL=${1:-"files-$(openssl rand -hex 4)"}
FM_USER="fxadmin"
FM_PASS=$(openssl rand -base64 12)

echo "FlashXpress File Manager Setup"
echo "==============================="

# Install TinyFileManager (lightweight .NET file manager alternative)
# Using elFinder with PHP
echo -e "${YELLOW}[1/3] Installing File Manager...${NC}"

# Create file manager directory
mkdir -p /var/www/fm
cd /var/www/fm

# Download elFinder
wget -q https://github.com/Studio-42/elFinder/releases/download/2.1.61/elfinder-2.1.61.zip -O fm.zip
unzip -q fm.zip
rm fm.zip

# Configure
cat > /var/www/fm/php/connector.minimal.php-dist << 'FMCONFIG'
<?php
error_reporting(0);
require './autoload.php';
elFinder::$netDrivers['ftp'] = 'FTP';

$opts = array(
    'roots' => array(
        array(
            'driver'        => 'LocalFileSystem',
            'path'          => '/var/www/',
            'URL'           => '',
            'uploadDeny'    => array('all'),
            'uploadAllow'   => array('image', 'text/plain', 'text/html', 'application/zip', 'application/x-gzip'),
            'uploadOrder'   => array('deny', 'allow'),
            'accessControl' => 'access'
        )
    )
);

$connector = new elFinderConnector(new elFinder($opts));
$connector->run();
FMCONFIG

# Create NGINX config with HTTP Basic Auth
echo -e "${YELLOW}[2/3] Creating secure access with authentication...${NC}"

# Create password file
apt install -y apache2-utils
htpasswd -bc /etc/nginx/.htpasswd $FM_USER $FM_PASS

cat > /etc/nginx/conf.d/fm.conf << FM_CONF
# File Manager - Secure Access
location /${FM_URL} {
    alias /var/www/fm;
    index index.html;
    
    auth_basic "FlashXpress File Manager";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location ~ ^/${FM_URL}/php/.*\.php$ {
        alias /var/www/fm;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        include fastcgi_params;
    }
}
FM_CONF

nginx -t && systemctl reload nginx

# Set permissions
chown -R www-data:www-data /var/www/fm

echo -e "${YELLOW}[3/3] Generating access credentials...${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  File Manager Installed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Access URL:"
echo -e "${YELLOW}  https://your-server-ip/${FM_URL}/${NC}"
echo ""
echo "Login Credentials:"
echo "  Username: $FM_USER"
echo "  Password: $FM_PASS"
echo ""
echo "Root Directory: /var/www/"
echo ""
echo "Important: Save these credentials securely!"
echo "To disable: sudo rm /etc/nginx/conf.d/fm.conf && sudo systemctl reload nginx"
