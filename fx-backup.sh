#!/bin/bash
#===============================================================================
# FlashXpress - Automated Backup Script
# Backs up all WordPress sites (files + database)
#===============================================================================

BACKUP_DIR="/var/www/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p $BACKUP_DIR

echo -e "${YELLOW}Starting FlashXpress Backup - $DATE${NC}"

# Get all sites
SITES=$(ls /var/www | grep -v html | grep -v backups)

for SITE in $SITES; do
    if [ -d "/var/www/$SITE/public" ]; then
        echo "Backing up: $SITE"
        
        # Get database name from wp-config or .fx-creds
        if [ -f "/var/www/$SITE/.fx-creds" ]; then
            DB_NAME=$(grep DB_NAME /var/www/$SITE/.fx-creds | cut -d= -f2)
        elif [ -f /var/www/$SITE/public/wp-config.php ]; then
            DB_NAME=$(grep DB_NAME /var/www/$SITE/public/wp-config.php | head -1 | cut -d "'" -f 4)
        fi
        
        # Backup database
        if [ ! -z "$DB_NAME" ]; then
            echo "  - Database: $DB_NAME"
            mysqldump -u root -pflashxpress $DB_NAME > $BACKUP_DIR/${SITE}_db_${DATE}.sql 2>/dev/null || echo "  - Database backup skipped"
        fi
        
        # Backup files
        echo "  - Files"
        tar -czf $BACKUP_DIR/${SITE}_files_${DATE}.tar.gz -C /var/www $SITE 2>/dev/null
    fi
done

# Clean old backups
echo ""
echo "Cleaning old backups (older than $RETENTION_DAYS days)..."
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

# Show backup size
BACKUP_SIZE=$(du -sh $BACKUP_DIR | cut -f1)
BACKUP_COUNT=$(ls -1 $BACKUP_DIR | wc -l)

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Backup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo "Location: $BACKUP_DIR"
echo "Total Size: $BACKUP_SIZE"
echo "Total Files: $BACKUP_COUNT"
