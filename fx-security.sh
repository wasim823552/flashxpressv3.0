#!/bin/bash
#===============================================================================
# FlashXpress - Security Hardening Script
# Configures firewall, fail2ban, and security settings
#===============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "FlashXpress Security Hardening"
echo "================================"

# Configure UFW Firewall
echo -e "${YELLOW}[1/5] Configuring UFW Firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable

# Configure Fail2Ban
echo -e "${YELLOW}[2/5] Configuring Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[wordpress]
enabled = true
filter = wordpress
logpath = /var/log/nginx/*access.log
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/*error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/*error.log
F2B

# Create WordPress fail2ban filter
cat > /etc/fail2ban/filter.d/wordpress.conf << 'WPCONF'
[Definition]
failregex = ^<HOST> .* "POST .*wp-login.php
            ^<HOST> .* "POST .*xmlrpc.php
ignoreregex =
WPCONF

systemctl restart fail2ban

# Secure PHP (for both 8.4 and 8.5)
echo -e "${YELLOW}[3/5] Hardening PHP...${NC}"
for VER in 8.4 8.5; do
    PHP_INI="/etc/php/${VER}/fpm/php.ini"
    if [ -f "$PHP_INI" ]; then
        sed -i 's/expose_php = On/expose_php = Off/' $PHP_INI
        sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/' $PHP_INI
        sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' $PHP_INI
        systemctl restart php${VER}-fpm
    fi
done

# Secure MariaDB
echo -e "${YELLOW}[4/5] Hardening MariaDB...${NC}"
mysql -u root -pflashxpress << 'SQL' 2>/dev/null || true
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

# Set proper permissions
echo -e "${YELLOW}[5/5] Setting permissions...${NC}"
find /var/www -type d -exec chmod 755 {} \;
find /var/www -type f -exec chmod 644 {} \;
chown -R www-data:www-data /var/www

# Secure wp-config files
find /var/www -name "wp-config.php" -exec chmod 600 {} \;

echo ""
echo -e "${GREEN}Security hardening complete!${NC}"
echo "- UFW Firewall: Active"
echo "- Fail2Ban: Active"
echo "- PHP: Hardened (8.4, 8.5)"
echo "- MariaDB: Secured"
echo "- Permissions: Optimized"
