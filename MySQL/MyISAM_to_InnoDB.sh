#!/bin/bash

FirstValue=$1

#Ключи помощи.
if [ "$FirstValue" = "--help" -o "$FirstValue" = "-h" ]; then
    echo "-c,      - Check databases space"
    exit
fi

#Проверяет обеъем базы данных в /var/lib/mysql
if [ "$FirstValue" = "-c" ]; then
    cd /var/lib/mysql
    FolderDatabases=$(ls -1 -d */)
    for FolderDatabases in $FolderDatabases; do
        CheckSpaceDatabasesFolder=$(du -hs "$FolderDatabases")
        echo $CheckSpaceDatabasesFolder
    done
    exit
fi

#Данный скрипт будет работать только при условии установленного bc.

check_tables=$(mysql -e 'SELECT TABLE_SCHEMA as DbName ,TABLE_NAME as TableName ,ENGINE as Engine FROM information_schema.TABLES WHERE ENGINE="'MyISAM'" AND TABLE_SCHEMA NOT IN("'mysql'","'information_schema'","'performance_schema'");')
Quantity_tables=$(echo "$check_tables" | grep "MyISAM" | wc -l)

#Проверка свободного места на сервере

DiskSpace() {

    DiskFromServer=$(df | grep "/dev/sda1" | awk {'print $2'})                     #Кол-во выделенного диска на сервере
    UseDiskFromServer=$(df -h | grep "/dev/sda1" | awk {'print $5'} | sed 's/%//') #Кол-во занятого места.
    MySQLUseServer=$(du -s /var/lib/mysql | awk {'print $1'})                      #Провека занимаемого место базами
    AllowDumpSpace=$(echo $MySQLUseServer - 40 / 100 | bc)                         # 60% от занимаемого место в /var/lib/mysql
    percents30=$(echo "$AllowDumpSpace * 30 / 100" | bc)                           #30% от всего сервера
    if [ $percents30 -lt $AllowDumpSpace ]; then
        echo "No disk space"
    fi
    while true; do
        read -p "There may not be enough space on the server. Are you sure you want to continue? " yn
        case $yn in
        [YyYesYES]*) break ;;
        [NnNoNO]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
}

#Создает дамп баз данных, вкоторых будет выполняется конвертирование.
CreateDatabasesDump() {
    num_databases=$(mysql -e 'SELECT TABLE_SCHEMA as DbName ,TABLE_NAME as TableName ,ENGINE as Engine FROM information_schema.TABLES WHERE ENGINE="'MyISAM'" AND TABLE_SCHEMA NOT IN("'mysql'","'information_schema'","'performance_schema'");' | awk {'print $1'} | uniq | sed 's/DbName//' | awk '{if(NF>0) {print $1}}' | wc -l)
    while true; do
        read -p "Do you want to dump $num_databases databases? " yn
        case $yn in
        [YyYesYES]*) break ;;
        [NnNoNO]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    mkdir /root/dump_script/
    mysql -e 'SELECT TABLE_SCHEMA as DbName ,TABLE_NAME as TableName ,ENGINE as Engine FROM information_schema.TABLES WHERE ENGINE="'MyISAM'" AND TABLE_SCHEMA NOT IN("'mysql'","'information_schema'","'performance_schema'");' | awk {'print $1'} | uniq | sed 's/DbName//' | awk '{if(NF>0) {print $1}}' | while read LINE; do
        mysqldump $LINE >/root/dump_script/$LINE.sql
    done
}

#Конвертация таблиц в InnoDB.
ConverTables() {
    while true; do
        read -p "Have you created a database dump? " yn
        case $yn in
        [YyYesYES]*) break ;;
        [NnNoNO]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    while true; do
        read -p "Do you agree to convert $Quantity_tables table(s)? " yn
        case $yn in
        [YyYesYES]*) break ;;
        [NnNoNO]*) exit ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    convet_command=$(mysql -e "SELECT CONCAT('ALTER TABLE ', TABLE_SCHEMA,'.',TABLE_NAME, ' ENGINE = InnoDB;') FROM information_schema.TABLES WHERE ENGINE='MyISAM' AND TABLE_SCHEMA NOT IN('mysql','information_schema','performance_schema');" | sed 's/|//' >/root/command.txt)
    sed -i '1d' /root/command.txt
    while
        read command
    do
        mysql -e "$command"
    done </root/command.txt
}

#Условия, при куоторых выполняется првоерка.
if [ $Quantity_tables -eq 0 ]; then
    echo "MyISAM not found"
else
    DiskSpace
    CreateDatabasesDump
    ConverTables
fi

echo "Done"

rm -- "$0"
