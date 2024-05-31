#!/bin/bash

# Variables
REMOTE_USER="username"
REMOTE_HOST="HOST_IP"
REMOTE_WEB_DIR="REMOTE_SITE_FILE_PATH" # i.e. /domain/site/sitedirectory
REMOTE_DB1="SITE_DB_NAME"
LOCAL_BACKUP_BASE_DIR="FILE_PATH_WHERE_YOU_ARE_BACKING_UP_TO"
REMOTE_BACKUP_DIR="REMOTE_SITE_FILE_PATH_BASE" #i.e. /domain/site (may be same as REMOTE_WEB_DIR)
DATE=$(date +'%Y-%m-%d')
BACKUP_DIR="${LOCAL_BACKUP_BASE_DIR}/SITE_BACKUP_${DATE}"
SSH_PASS="SSH_PASSWORD"
DB_USERNAME="SITE_DB_USERNAME"
DB_PASS="SITE_DB_PASSWORD"
SSH_PORT=SSH_PORT_#
LOG_FILE="${LOCAL_BACKUP_BASE_DIR}/backup_log_${DATE}.log"
SSH_OPTIONS="SSH_OPTIONS -p ${SSH_PORT}"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a ${LOG_FILE}
}

# Create a new directory for the backup
log_message "Creating backup directory ${BACKUP_DIR}"
mkdir -p ${BACKUP_DIR}
if [ $? -ne 0 ]; then
    log_message "Failed to create backup directory ${BACKUP_DIR}"
    exit 1
fi

# SSH into the remote server and zip the website folder
log_message "Zipping the website folder on the remote server"
sshpass -p "${SSH_PASS}" ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} "zip -r ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${REMOTE_WEB_DIR}" &
ZIP_PID=$!

wait $ZIP_PID
if [ $? -ne 0 ]; then
    log_message "Failed to initiate zipping the website folder on the remote server"
    exit 1
fi

# Download the zipped website folder via scp
log_message "Downloading the zipped website folder"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${BACKUP_DIR}/ &
SCP_ZIP_PID=$!

wait $SCP_ZIP_PID
if [ $? -ne 0 ]; then
    log_message "Failed to initiate download of the zipped website folder"
    exit 1
fi

# SSH into the remote server and create database dumps
log_message "Creating database dump for ${REMOTE_DB1}"
sshpass -p "${SSH_PASS}" ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u ${DB_USERNAME} -p'${DB_PASS}' ${REMOTE_DB1} > ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql" &
DUMP_DB1_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate database dump for ${REMOTE_DB1}"
    exit 1
fi

# Wait for the zipping and downloading to complete
wait $ZIP_PID
if [ $? -ne 0 ]; then
    log_message "Zipping the website folder failed"
    exit 1
fi

wait $SCP_ZIP_PID
if [ $? -ne 0 ]; then
    log_message "Downloading the zipped website folder failed"
    exit 1
fi

# Download the database dumps via scp
log_message "Downloading the database dump for ${REMOTE_DB1}"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql ${BACKUP_DIR}/ &
SCP_DB1_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate download of the database dump for ${REMOTE_DB1}"
    exit 1
fi

# Wait for all background processes to complete
wait $DUMP_DB1_PID
if [ $? -ne 0 ]; then
    log_message "Database dump for ${REMOTE_DB1} failed"
    exit 1
fi

wait $SCP_DB1_PID
if [ $? -ne 0 ]; then
    log_message "Downloading the database dump for ${REMOTE_DB1} failed"
    exit 1
fi

# Optional: Remove the backups from the remote server
log_message "Removing the backups from the remote server"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql"

log_message "Backup completed and stored in ${BACKUP_DIR} on ${DATE}"
