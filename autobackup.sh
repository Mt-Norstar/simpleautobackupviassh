#!/bin/bash

# Variables
REMOTE_USER="your_remote_user"
REMOTE_HOST="your_remote_host"
REMOTE_WEB_DIR="/path/to/remote/website"
REMOTE_DB1="database1"
REMOTE_DB2="database2"
LOCAL_BACKUP_BASE_DIR="/path/to/local/backup"
REMOTE_BACKUP_DIR="/path/to/remote/backup"
DATE=$(date +'%Y-%m-%d')
BACKUP_DIR="${LOCAL_BACKUP_BASE_DIR}/SiteA_BACKUP_${DATE}"

# Create a new directory for the backup
mkdir -p ${BACKUP_DIR}

# SSH into the remote server and zip the website folder
ssh ${REMOTE_USER}@${REMOTE_HOST} "zip -r ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${REMOTE_WEB_DIR}" &

# Download the zipped website folder via scp
scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${BACKUP_DIR}/ &

# SSH into the remote server and create database dumps
ssh ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u root -p'password' ${REMOTE_DB1} > ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql" &
ssh ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u root -p'password' ${REMOTE_DB2} > ${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql" &

# Wait for the zipping and downloading to complete
wait

# Download the database dumps via scp
scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql ${BACKUP_DIR}/ &
scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql ${BACKUP_DIR}/ &

# Wait for all background processes to complete
wait

# Optional: Remove the backups from the remote server
ssh ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip"
ssh ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql"
ssh ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql"

echo "Backup completed and stored in ${BACKUP_DIR} on ${DATE}"
