# !/bin/bash

### log file ###
touch /home/update_mariadb.txt
LOGS_FILE=/home/update_mariadb.txt

### add rep mariadb ###
touch /etc/yum.repos.d/MariaDB.repo

echo "# MariaDB 10.4 CentOS repository list" >>/etc/yum.repos.d/MariaDB.repo
echo "# http://downloads.mariadb.org/mariadb/repositories/" >>/etc/yum.repos.d/MariaDB.repo
echo [mariadb] >>/etc/yum.repos.d/MariaDB.repo
echo name = MariaDB >>/etc/yum.repos.d/MariaDB.repo
echo baseurl = http://yum.mariadb.org/10.4/centos7-amd64 >>/etc/yum.repos.d/MariaDB.repo
echo gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB >>/etc/yum.repos.d/MariaDB.repo
echo gpgcheck=1 >>/etc/yum.repos.d/MariaDB.repo

### clean cache and update package ###
echo "Update package, pls wait...."
yum clean all >>$LOGS_FILE 2>&1
yum makecache >>$LOGS_FILE 2>&1
yum -y install psmisc >>$LOGS_FILE 2>&1
yum -y update >>$LOGS_FILE 2>&1

line=$(grep -ni "/var/run/mysqld/mysqld.pid" /etc/my.cnf | head -c 1)

echo "Fix config my.cnf..."

### fix bug new database ###
cp /etc/my.cnf /etc/my.cnf_backup
sed -i ''$line'd' /etc/my.cnf
sed -i '2ilog-error=/var/log/mariadb/mariadb.log' /etc/my.cnf
sed -i '17imax-allowed-packet = 512M' /etc/my.cnf
sed -i '18iwait-timeout = 500' /etc/my.cnf
sed -i '19imax-connections = 100' /etc/my.cnf
sed -i '20iconnect-timeout = 30' /etc/my.cnf
sed -i '21inet-write-timeout = 90' /etc/my.cnf
sed -i '22inet-read-timeout = 90' /etc/my.cnf
sed -i '23imax-heap-table-size = 32M' /etc/my.cnf
sed -i '24itmp-table-size = 32M' /etc/my.cnf
sed -i '25itable-cache = 4096' /etc/my.cnf
sed -i '26itable-definition-cache = 4096' /etc/my.cnf
sed -i '27itable-open-cache = 4096' /etc/my.cnf
sed -i '28iquery-cache-size = 128M' /etc/my.cnf
sed -i '29iquery-cache-limit = 1M' /etc/my.cnf
sed -i '30ithread-cache-size = 32' /etc/my.cnf
sed -i '31ikey-buffer-size = 128M' /etc/my.cnf
sed -i '32iinnodb-buffer-pool-size = 128M' /etc/my.cnf
sed -i '33iinnodb-buffer-pool-instances = 1' /etc/my.cnf
sed -i '34iinnodb-file-per-table = 1' /etc/my.cnf
sed -i '35iinnodb-flush-log-at-trx-commit = 0' /etc/my.cnf
sed -i '36iinnodb-flush-method = O_DIRECT' /etc/my.cnf
sed -i '37itransaction-isolation = READ-COMMITTED' /etc/my.cnf
sed -i '38isql_mode = ''' /etc/my.cnf

killall mysqld
echo "path mysqld /usr/sbin/mysqld" >>/usr/local/mgr5/etc/ispmgr.conf.d/mysql.conf
ln -s /usr/sbin/mysqld /usr/libexec/mysqld >>$LOGS_FILE 2>&1
killall core

echo "Starting the database..."

/bin/systemctl enable mariadb >>$LOGS_FILE 2>&1
/bin/systemctl start mariadb.service
mysql_upgrade >>$LOGS_FILE 2>&1
/bin/systemctl restart mariadb.service

echo "Database successfully updated..."

rm -- "$0"
