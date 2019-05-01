# python, pip, awscli install
# AWS configure with secret_key and access_key
# AWS S3 bucket creation

########################
#!/bin/bash

DATE=$(date +%Y%m%d)
BACKUP_DIR=/home/deploy/.backup/
CONFIG_DIR=/home/deploy/exchange/config
BACKUP_DB=db_$DATE.zip
BACKUP_CONFIG=config_$DATE.tar.gz

MYSQL_USER=root
MYSQL_PASSWORD=admin
DB_NAME=m365_production

BUCKET=m365
S3_KEY=$BUCKET/backups/

# DB backup
mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD $DB_NAME  > $BACKUP_DIR$BACKUP_DB

# mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD  > $BACKUP_DIR$BACKUP_DB
# mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD $DB_NAME  > $BACKUP_DIR$BACKUP_DB
# mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD  --all-databases > $BACKUP_DIR$BACKUP_DB
# mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD  --all-databases | zip > $BACKUP_DIR$BACKUP_DB


# configuration backup
tar zcf $BACKUP_DIR$BACKUP_CONFIG $CONFIG_DIR


# Delete old DB backup (7 days before)
find $BACKUP_DIR -ctime +7 -exec rm -f {} \;

# S3 upload

/home/deploy/.local/bin/aws s3 cp $BACKUP_DIR$BACKUP_DB s3://$S3_KEY --sse AES256
/home/deploy/.local/bin/aws s3 cp $BACKUP_DIR$BACKUP_CONFIG s3://$S3_KEY --sse AES256

########################
#crontab -e
##########
#00 04 * * 01 /home/deploy/exchange/config/backup.sh
########################
