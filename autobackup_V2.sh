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
SSH_PASS="your_ssh_password"
DB_PASS="your_db_password"
SSH_PORT=your_ssh_port_number
LOG_FILE="${LOCAL_BACKUP_BASE_DIR}/backup_log_${DATE}.log"

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
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "zip -r ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${REMOTE_WEB_DIR}" &
ZIP_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate zipping the website folder on the remote server"
    exit 1
fi

# Download the zipped website folder via scp
log_message "Downloading the zipped website folder"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip ${BACKUP_DIR}/ &
SCP_ZIP_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate download of the zipped website folder"
    exit 1
fi

# SSH into the remote server and create database dumps
log_message "Creating database dump for ${REMOTE_DB1}"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u root -p'${DB_PASS}' ${REMOTE_DB1} > ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql" &
DUMP_DB1_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate database dump for ${REMOTE_DB1}"
    exit 1
fi

log_message "Creating database dump for ${REMOTE_DB2}"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u root -p'${DB_PASS}' ${REMOTE_DB2} > ${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql" &
DUMP_DB2_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate database dump for ${REMOTE_DB2}"
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

log_message "Downloading the database dump for ${REMOTE_DB2}"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql ${BACKUP_DIR}/ &
SCP_DB2_PID=$!
if [ $? -ne 0 ]; then
    log_message "Failed to initiate download of the database dump for ${REMOTE_DB2}"
    exit 1
fi

# Wait for all background processes to complete
wait $DUMP_DB1_PID
if [ $? -ne 0 ]; then
    log_message "Database dump for ${REMOTE_DB1} failed"
    exit 1
fi

wait $DUMP_DB2_PID
if [ $? -ne 0 ]; then
    log_message "Database dump for ${REMOTE_DB2} failed"
    exit 1
fi

wait $SCP_DB1_PID
if [ $? -ne 0 ]; then
    log_message "Downloading the database dump for ${REMOTE_DB1} failed"
    exit 1
fi

wait $SCP_DB2_PID
if [ $? -ne 0 ]; then
    log_message "Downloading the database dump for ${REMOTE_DB2} failed"
    exit 1
fi

# Optional: Remove the backups from the remote server
log_message "Removing the backups from the remote server"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/website_backup_${DATE}.zip"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/${REMOTE_DB1}_backup_${DATE}.sql"
sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${REMOTE_BACKUP_DIR}/${REMOTE_DB2}_backup_${DATE}.sql"

log_message "Backup completed and stored in ${BACKUP_DIR} on ${DATE}"
