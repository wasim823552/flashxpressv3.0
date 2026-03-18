#!/bin/bash
#===============================================================================
# FlashXpress - PHP Version Management
# Install, switch, and manage PHP versions
# Supports: PHP 8.1, 8.2, 8.3, 8.4, 8.5
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_usage() {
    echo "FlashXpress PHP Manager"
    echo ""
    echo "Usage:"
    echo "  fx php version           - Show current PHP version"
    echo "  fx php versions          - List installed PHP versions"
    echo "  fx php install 8.5       - Install PHP version"
    echo "  fx php switch 8.5        - Switch default PHP version"
    echo "  fx php switch 8.5 --site=domain.com  - Switch PHP for site"
    echo "  fx php restart [version] - Restart PHP-FPM"
    echo ""
    echo "Available versions: 8.1, 8.2, 8.3, 8.4, 8.5"
}

case "$1" in
    version|--version|-v)
        echo "Current PHP version:"
        php -v | head -1
        ;;
    versions)
        echo "Installed PHP versions:"
        echo "====================="
        for ver in 8.1 8.2 8.3 8.4 8.5; do
            if [ -f "/usr/bin/php${ver}" ]; then
                status=""
                if [ "$(readlink -f /usr/bin/php)" == "/usr/bin/php${ver}" ]; then
                    status=" [DEFAULT]"
                fi
                full_ver=$(/usr/bin/php${ver} -v 2>/dev/null | head -1 | cut -d' ' -f2)
                echo -e "  PHP ${ver}: ${full_ver}${status}"
            fi
        done
        ;;
    install)
        VER=$2
        if [ -z "$VER" ]; then
            echo -e "${RED}Error: Please specify PHP version${NC}"
            echo "Usage: fx php install 8.4|8.5"
            exit 1
        fi
        
        echo -e "${YELLOW}Installing PHP ${VER}...${NC}"
        
        # Add PHP repository if not exists
        if [ ! -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]; then
            add-apt-repository -y ppa:ondrej/php
            apt update
        fi
        
        # Install PHP with common extensions
        apt install -y php${VER} php${VER}-fpm php${VER}-mysql php${VER}-curl \
            php${VER}-gd php${VER}-mbstring php${VER}-xml php${VER}-zip \
            php${VER}-bcmath php${VER}-intl php${VER}-redis php${VER}-imagick \
            php${VER}-opcache php${VER}-readline php${VER}-xmlrpc php${VER}-soap
        
        systemctl enable php${VER}-fpm
        systemctl start php${VER}-fpm
        
        echo -e "${GREEN}PHP ${VER} installed successfully!${NC}"
        ;;
    switch)
        VER=$2
        if [ -z "$VER" ]; then
            echo -e "${RED}Error: Please specify PHP version${NC}"
            echo "Usage: fx php switch 8.4|8.5 [--site=domain.com]"
            exit 1
        fi
        
        # Check if PHP version is installed
        if [ ! -f "/usr/bin/php${VER}" ]; then
            echo -e "${RED}Error: PHP ${VER} is not installed${NC}"
            echo "Install it first: fx php install ${VER}"
            exit 1
        fi
        
        # Check if --site argument
        if [[ "$3" == *"--site="* ]]; then
            SITE=$(echo $3 | cut -d= -f2)
            echo -e "${YELLOW}Switching PHP to ${VER} for site: ${SITE}${NC}"
            
            if [ ! -f "/etc/nginx/sites-available/${SITE}" ]; then
                echo -e "${RED}Error: Site ${SITE} not found${NC}"
                exit 1
            fi
            
            # Update NGINX config to use new PHP version
            sed -i "s|php[0-9]\.[0-9]-fpm\.sock|php${VER}-fpm.sock|g" /etc/nginx/sites-available/${SITE}
            
            # Save PHP version for site
            echo ${VER} > /var/www/${SITE}/.php-version
            
            nginx -t && systemctl reload nginx
            echo -e "${GREEN}Site ${SITE} now using PHP ${VER}${NC}"
        else
            echo -e "${YELLOW}Switching default PHP to ${VER}...${NC}"
            
            # Update alternatives
            update-alternatives --set php /usr/bin/php${VER}
            update-alternatives --set php-config /usr/bin/php-config${VER} 2>/dev/null || true
            update-alternatives --set phpize /usr/bin/phpize${VER} 2>/dev/null || true
            
            # Save as default
            echo ${VER} > /etc/flashxpress/default-php
            
            # Restart FPM
            systemctl restart php${VER}-fpm
            
            echo -e "${GREEN}Default PHP switched to ${VER}${NC}"
            php -v | head -1
        fi
        ;;
    restart)
        VER=${2:-$(cat /etc/flashxpress/default-php 2>/dev/null || echo "8.4")}
        echo -e "${YELLOW}Restarting PHP ${VER}-FPM...${NC}"
        systemctl restart php${VER}-fpm
        echo -e "${GREEN}PHP ${VER}-FPM restarted${NC}"
        ;;
    extensions)
        VER=${2:-$(cat /etc/flashxpress/default-php 2>/dev/null || echo "8.4")}
        echo "PHP ${VER} Extensions:"
        echo "======================"
        php -m | sort
        ;;
    *)
        show_usage
        ;;
esac
