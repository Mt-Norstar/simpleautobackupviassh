#!/bin/bash

# Variables
REMOTE_USER="username" #Your ssh username
REMOTE_HOST="HOST_IP" #Your Host IP address
REMOTE_WEB_DIR="REMOTE_SITE_FILE_PATH" # i.e. /domain/site/sitedirectory this is the whole directory on the remote serever that will be zipped!
REMOTE_DB1="SITE_DB_NAME" #DB Name, this is the DB that we will create a dump of and that the script downloads
LOCAL_BACKUP_BASE_DIR="BASE_FILE_PATH_WHERE_YOU_ARE_BACKING_UP_TO" #this is the base local directory where the $BACKUP_DIR is created, your files are stored within the $BACKUP_DIR
REMOTE_BACKUP_DIR="REMOTE_SITE_FILE_PATH_BASE" #i.e. /domain/site this is the directory on the remote server where your .zip file and the .sql db dump file will be stored
DATE=$(date +'%Y-%m-%d') #Date 
BACKUP_DIR="${LOCAL_BACKUP_BASE_DIR}/SITE_BACKUP_${DATE}" #this is the directory that is made by the script where your files will be stored
SSH_PASS="SSH_PASSWORD" #ssh password
DB_USERNAME="SITE_DB_USERNAME" #DB Username
DB_PASS="SITE_DB_PASSWORD" #DB Password
SSH_PORT=SSH_PORT_ #ssh port number
LOG_FILE="${LOCAL_BACKUP_BASE_DIR}/backup_log_${DATE}.log" #Log file created by script that logs actions and errors
SSH_OPTIONS="SSH_OPTIONS -p ${SSH_PORT}" #Any specific ssh options you want to specify

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
