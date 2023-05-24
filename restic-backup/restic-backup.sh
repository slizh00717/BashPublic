#!/bin/bash

RESTIC_REPOSITORY_FILE="sftp:root@1.1.1.1:/backup"
RESTIC_PASSWORD_FILE=/etc/restic-backup/pass.txt
BACKUP_FOLDERS=/etc/restic-backup/folderslist.txt
BACKUP_EXCLUDE=/etc/restic-backup/excludes.txt
BACKUP_LOG=/var/log/restic-backup.log
DATABASES_SETTINGS=/etc/restic-backup/databases.conf
BACKUP_STATUS_LOG=/var/log/restic-backup-status

FirstValue=$1
DaysRemovingBackup=5

# Help
if [[ "$FirstValue" == "--help" || "$FirstValue" == "-h" ]]; then
    cat <<EOF
-l, -l <directory>        --list, Check snapshots list
-c,                       --check, Checking repository integrity
-cr,                      --check-read-data, Checking the repository structure and the integrity of files in the repository
-s,                       --stats, Output of information about backups
-r,                       --restore, Restoring a backup
-r -f,                    Manual recovery of a specific file
-u,                       --unlock, Use only if the system is locked
-d,                       --diff, Compares the backup
ls,                       -ls, --ls, Viewing the contents of a snapshot
EOF
    exit 0
fi

# Backups of files from the $BACKUP_FOLDERS file
backup_folders() {
    cat $BACKUP_FOLDERS | while read folder; do
        restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE backup --exclude-file=$BACKUP_EXCLUDE $folder >>$BACKUP_LOG
    done
}

# Rotation of backup logs
log_rotate() {
  ( # subshell to capture output
    if [ -s "$BACKUP_LOG" ]; then
      tar -czf "/var/log/restic-backup.$(date +%Y-%m-%d-%H-%M).tar.gz" "$BACKUP_LOG" && \
      rm "$BACKUP_LOG"
    fi
  ) >> "$BACKUP_STATUS_LOG" 2>&1
}

# Restoring all backup(function)
restore_backup() {
    read -p "Enter the backup ID: " id
    if [[ -z "$id" ]]; then
        echo "Error: backup ID is empty!"
        return 1
    fi

    if [[ "$id" =~ ^[Nn][Oo]?$ ]]; then
        echo "Recovery canceled by user."
        return 0
    fi

    read -p "Enter the path to restore the backup (default: /): " backup_path
    backup_path=${backup_path:-/}

    restic -p "$RESTIC_PASSWORD_FILE" -r "$RESTIC_REPOSITORY_FILE" restore "$id" --target "$backup_path"
}

# Restoring one specific file
restore_sinle_backup() {
    read -p "Specify the backup id: " id
    if [ -z "${id}" ]; then
        echo "Id is empty!"
        exit
    fi
    if [ "${id}" = "no" -o "${id}" = "No" -o "${id}" = "N" -o "${id}" = "n" ]; then
        echo "You canceled the recovery!"
        exit
    fi
    read -p "Enter the file you want to restore: " BackupFile
    read -p "Directory for file recovery(default /): " BackupFolder
    if [ -z "${BackupFolder}" ]; then
        restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" restore "${id}" --target / --include "${BackupFile}"
    else
        restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" restore "${id}" --target "${BackupFolder}" --include "${BackupFile}"
    fi
}

# Database backup
backup_database() {
    MysqlDumpSetting=$(cat $DATABASES_SETTINGS | grep "true" | awk '{print $1}')
    for DB in $MysqlDumpSetting; do
        if [ "$DB" = "PERCONA" ]; then #Percona xtrabackup
            MySQLUser=$(cat /root/.my.cnf | grep "user" | awk {'print $2'})
            MySQLUserPassword=$(cat /root/.my.cnf | grep "password" | awk {'print $2'})
            if test -z "$MySQLUser"; then
                echo "Empty string(User Name)!"
                exit
            fi
            if test -z "$MySQLUserPassword"; then
                echo "Empty string(User password)!"
                exit
            fi
            DiskName=$(cat /etc/fstab | grep /dev/ | awk {'print $1'} | tail -1)
            FreeDisk=$(df | grep $DiskName | awk {'print $4'} | sed 's/G//')
            DiskUseMySQL=$(du -s /var/lib/mysql | awk {'print $1'} | sed 's/G//')

            if [ "$FreeDisk" -gt "$DiskUseMySQL" ]; then
                CheckPerconaBackupFolder=$(ls -ls /mnt/ | grep "percona" | wc -l)
                if [ $CheckPerconaBackupFolder -eq 0 ]; then
                    mkdir /mnt/percona/
                fi
                xtrabackup --backup --user=$MySQLUser --password=$MySQLUserPassword --target-dir=/mnt/percona/ --open-files-limit=100000 >>$BACKUP_LOG 2>&1
                xtrabackup --prepare --target-dir=/mnt/percona/ >>$BACKUP_LOG 2>&1
                restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE backup --tag XtraBackup /mnt/percona/ >>$BACKUP_LOG
                rm -rf /mnt/percona/*
            else
                echo "ERROR: There is not enough disk to create a database dump!" >>$BACKUP_LOG 2>&1
            fi
        elif [ "$DB" = "MYSQLDUMP" ]; then #MySQLDump
            MySQLUser=$(cat /root/.my.cnf | grep "user" | awk {'print $2'})
            MySQLUserPassword=$(cat /root/.my.cnf | grep "password" | awk {'print $2'})
            if test -z "$MySQLUser"; then
                echo "Empty string(User Name)!"
                exit
            fi
            if test -z "$MySQLUserPassword"; then
                echo "Empty string(User password)!"
                exit
            fi
            mysql -u"$MySQLUser" -p"$MySQLUserPassword" -e 'show databases;' | sed 's/information_schema//' | sed 's/Database//' | sed 's/mysql//' | sed 's/sys//' | sed 's/performance_schema//' | awk '{if(NF>0) {print $0}}' | while read MySQLDatabase; do
                mysqldump --databases $MySQLDatabase | restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE backup --tag MysqlDump --stdin --stdin-filename $MySQLDatabase.sql >>$BACKUP_LOG 2>&1
            done
        elif [ "$DB" = "POSTGRES" ]; then
            sudo -Hiu postgres psql -A -q -t -c 'SELECT datname FROM pg_database;' | egrep -v template | egrep -v postgres | while read PostgressDatabase; do
                sudo -Hiu postgres pg_dump -c $PostgressDatabase | restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE backup --tag PgDump --stdin --stdin-filename $PostgressDatabase.sql >>$BACKUP_LOG 2>&1
            done
        elif [ "$DB" = "MARIADB" ]; then
            echo "MARIADB"
        fi
    done
}

# Remiving old backup
delete_old_backup() {
    restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE forget --keep-daily $DaysRemovingBackup
}

# Display list backups
case "$FirstValue" in
-l | --list | -L)
    SecondValue=$2
    if [ -z "$RESTIC_PASSWORD_FILE" ]; then
        echo "RESTIC_PASSWORD_FILE is not set!"
        exit
    fi
    if [ -z "$RESTIC_REPOSITORY_FILE" ]; then
        echo "RESTIC_REPOSITORY_FILE is not set!"
        exit
    fi
    if [ -z "$SecondValue" ]; then
        restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE snapshots
    else
        restic -p $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY_FILE snapshots --path="/$SecondValue"
    fi
    exit
    ;;
esac

# Check metadate storage
case "${FirstValue}" in
-c | --check | -C)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" check
    exit
    ;;
esac

# Re-reads metadata
case "${FirstValue}" in
-cr | --check-read-data | -CR | -Cr | -cR)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" check --read-data
    exit
    ;;
esac

# Output of information about backups
case "${FirstValue}" in
-s | --stats | -S)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" check
    exit
    ;;
esac
# Restoring backup
case "${FirstValue}" in
-r | --restore | -R)
    SecondValue="${2}"
    if [ "${SecondValue}" = "-f" ]; then
        restore_sinle_backup
    fi
    if [ -z "${SecondValue}" ]; then
        restore_backup
    fi
    exit
    ;;
esac

# If the repository is locked, it can be unlocked with the unlock key
case "${FirstValue}" in
-u | --unlock | -U)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" unlock
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" check
    exit
    ;;
esac

# Viewing backup files
case "${FirstValue}" in
ls | -ls | --ls | LS | Ls | -lS | -LS | -Ls | -lS)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" snapshots
    read -p "Enter the backup id to view the contents: " ID
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" ls "${ID}"
    exit
    ;;
esac

# Comparing backups
case "${FirstValue}" in
-d | --diff | -D)
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" snapshots
    read -p "The first backup for comparison: " FirstID
    if [ -z "${FirstID}" ]; then
        echo "Id is empty!"
        exit
    fi
    read -p "The second backup for comparison: " SecondID
    if [ -z "${SecondID}" ]; then
        echo "Id is empty!"
        exit
    fi
    restic -p "${RESTIC_PASSWORD_FILE}" -r "${RESTIC_REPOSITORY_FILE}" diff "${FirstID}" "${SecondID}"
    exit
    ;;
esac

# Running backup's command
log_rotate
backup_database
backup_folders
delete_old_backup

PresenceOfErrors=$(egrep -w "error|ERROR|Error" "${BACKUP_LOG}" | wc -l)
if [ "${PresenceOfErrors}" -eq 0 ]; then
    echo "Backup Status: ok" >"${BACKUP_STATUS_LOG}"
else
    echo "Backup Status: error" >"${BACKUP_STATUS_LOG}"
fi
