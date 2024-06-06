#!/bin/bash

# Variables
REMOTE_USER="SSH_USERNAME" #Your ssh username
REMOTE_HOST="REMOTE_HOST_IP" #Your Host IP address
SITE_NAME="SITE_NAME"
REMOTE_WEB_DIR="SITE_DIRECTORY_TO_BE_ZIPPED" # i.e. /path/to/sitedirectory this is the whole directory on the remote serever that will be zipped!
REMOTE_DB="DATABASE_NAME" #DB Name, this is the DB that we will create a dump of and that the script downloads
LOCAL_BACKUP_BASE_DIR="LOCAL_BACKUP_BASE_DIR" #this is the base local directory where the ${TRUE_BACKUP_DIR} is created, your files are stored within the ${TRUE_BACKUP_DIR}
REMOTE_BACKUP_DIR="REMOTE_BACKUP_DIR" #i.e. /remote/backup/path this is the directory on the remote server where your .zip file and the .sql db dump file will be stored
DATE=$(date +'%Y-%m-%d') #Date 
TRUE_BACKUP_DIR="${LOCAL_BACKUP_BASE_DIR}/${SITE_NAME}_BACKUP_${DATE}" #this is the directory that is made by the script where your files will be stored
SSH_PASS="SSH_PASSWORD" #ssh password
DB_USERNAME="DATABASE_USERNAME" #DB Username
DB_PASS="DATABASE_PASSWORD" #DB Password
SSH_PORT=22 #ssh port number
LOG_FILE="${LOCAL_BACKUP_BASE_DIR}/${SITE_NAME}_backup_log_${DATE}.log" #Log file created by script that logs actions and errors
SSH_OPTIONS="-o StrictHostKeyChecking=no -p ${SSH_PORT}" #Any specific ssh options you want to specify
ZIP_DIRECTORY_PATH="${REMOTE_BACKUP_DIR}/${SITE_NAME}_${DATE}.zip" #The path of the Zip of the ${REMOTE_WEB_DIR}
ZIP_FILE="${SITE_NAME}_${DATE}.zip" #The Zip File itself
DB_DUMP_PATH="${REMOTE_BACKUP_DIR}/${REMOTE_DB}_backup_${DATE}.sql" #The path of the dump of the ${REMOTE_DB}
DB_DUMP="${REMOTE_DB}_backup_${DATE}.sql" # The Dump file itself
CHECKSUM_FILE_PATH="${REMOTE_BACKUP_DIR}/${SITE_NAME}-checksum-$DATE.sha256" #Path of the Checksum file
CHECKSUM_FILE="${SITE_NAME}-checksum-$DATE.sha256" #The Checksum file generated when generating the checksums of the files, contains 256 hashes for both .zip and dump file

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a ${LOG_FILE}
}

# Create a new directory for the backup
log_message "Creating backup directory ${TRUE_BACKUP_DIR}"
mkdir -p ${TRUE_BACKUP_DIR}
if [ $? -ne 0 ]; then
    log_message "Failed to create backup directory ${TRUE_BACKUP_DIR}"
    exit 1
fi

# SSH into the remote server and zip the website folder
log_message "Zipping the website folder on the remote server"
sshpass -p "${SSH_PASS}" ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} "zip -r ${ZIP_DIRECTORY_PATH} ${REMOTE_WEB_DIR}" &
ZIP_PID=$!

wait $ZIP_PID
if [ $? -ne 0 ]; then
    log_message "Failed to zip the website folder on the remote server"
    exit 1
fi

# Download the zipped website folder via scp
log_message "Downloading the zipped website folder"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${ZIP_DIRECTORY_PATH} ${TRUE_BACKUP_DIR}/
if [ $? -ne 0 ]; then
    log_message "Failed to download the zipped website folder"
    exit 1
fi

# SSH into the remote server and create database dumps
log_message "Creating database dump for ${REMOTE_DB}"
sshpass -p "${SSH_PASS}" ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} "mysqldump -u ${DB_USERNAME} -p'${DB_PASS}' ${REMOTE_DB} > ${DB_DUMP_PATH}" &
DUMP_DB1_PID=$!

wait $DUMP_DB1_PID
if [ $? -ne 0 ]; then
    log_message "Database dump for ${REMOTE_DB} failed"
    exit 1
fi

# Download the database dumps via scp
log_message "Downloading the database dump for ${REMOTE_DB}"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${DB_DUMP_PATH} ${TRUE_BACKUP_DIR}/
if [ $? -ne 0 ]; then
    log_message "Failed to download the database dump for ${REMOTE_DB}"
    exit 1
fi

# Generate Checksums of the Zip File and the Dump
log_message "Generating checksum for the backup files"
sshpass -p "${SSH_PASS}" ssh ${SSH_OPTIONS} ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_BACKUP_DIR} && sha256sum ${ZIP_FILE} ${DB_DUMP} > ${CHECKSUM_FILE}" &
CHECK_PID=$!

wait $CHECK_PID
if [ $? -ne 0 ]; then
    log_message "Failed to generate checksum"
    exit 1
fi

log_message "Downloading the checksum file"
sshpass -p "${SSH_PASS}" scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${CHECKSUM_FILE_PATH} ${TRUE_BACKUP_DIR}
if [ $? -ne 0 ]; then
    log_message "Failed to download the checksum file"
    exit 1
fi

cd ${TRUE_BACKUP_DIR}
log_message "Verifying checksum"
sha256sum -c ${CHECKSUM_FILE}
if [ $? -eq 0 ]; then
    log_message "Checksum verification succeeded"

    # Optional: Remove the backups from the remote server
    log_message "Removing the backups from the remote server"
    sshpass -p "${SSH_PASS}" ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm ${ZIP_DIRECTORY_PATH} ${DB_DUMP_PATH} ${CHECKSUM_FILE_PATH}"

    log_message "Backup completed and stored in ${TRUE_BACKUP_DIR} on $(date)"
else
    log_message "Checksum verification failed. Please check the files."
    exit 1
fi
