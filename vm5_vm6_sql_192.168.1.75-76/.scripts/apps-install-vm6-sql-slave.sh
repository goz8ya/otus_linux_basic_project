echo 'Setting static IP it set after restart'
# hostname -i 
sudo uname -r
sudo apt-get update

# install integration services Hyperv
echo 'hv_vmbus' >> /etc/initramfs-tools/modules
echo 'hv_storvsc' >> /etc/initramfs-tools/modules
echo 'hv_blkvsc' >> /etc/initramfs-tools/modules
echo 'hv_netvsc' >> /etc/initramfs-tools/modules
apt -y install linux-virtual linux-cloud-tools-virtual linux-tools-virtual
update-initramfs -u

# Устанавливаем MySQL
apt install mysql-server -y

#По умолчанию было настроено только чтобы слушать localhost.
#должен слушать не только localhost, но и другие адреса! 
#Делаем изменение в конфиг файле: /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i '/^bind-address/s/127.0.0.1/0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
#восстанавливаем строку mysqlx-bind-address после предыдущей команды 
#sed -i '/mysqlx-bind-address/s/0.0.0.0/127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Вносим настройки для работы репликации Replica
echo "log-bin = mysql-bin"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "relay-log = relay-log-server"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "read-only = ON"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "gtid-mode=ON"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "enforce-gtid-consistency"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "log-replica-updates"  >> /etc/mysql/mysql.conf.d/mysqld.cnf

#Меняем сервер ID, чтобы отличались у мастера и реплики.
sudo sed -i '/# server-id/c server-id  = 2' /etc/mysql/mysql.conf.d/mysqld.cnf

#после чего делаем рестарт:
systemctl restart mysql

mysql -h localhost -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY 'Testpass1$';";

#mysql -h localhost -u root -p 'Testpass1$' -e "SHOW GLOBAL VARIABLES LIKE 'caching_sha2_password_public_key_path';"
mysql -h localhost -u root -p'Testpass1$' -e "SHOW STATUS LIKE 'Caching_sha2_password_rsa_public_key'\G;";


#mysql -h localhost -u root -p'Testpass1$' -e "STOP SLAVE;";
#mysql -h localhost -u root -p'Testpass1$' -e "CHANGE MASTER TO MASTER_HOST='192.168.1.74', MASTER_USER='repl', MASTER_PASSWORD='oTUSlave#2020', MASTER_LOG_FILE='binlog.000005', MASTER_LOG_POS=688, GET_MASTER_PUBLIC_KEY = 1;";
#mysql -h localhost -u root -p'Testpass1$' -e "START SLAVE;";

mysql -h localhost -u root -p'Testpass1$' -e "STOP REPLICA;";
mysql -h localhost -u root -p'Testpass1$' -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.1.74', SOURCE_USER='repl', SOURCE_PASSWORD='oTUSlave#2020', SOURCE_AUTO_POSITION = 1, GET_SOURCE_PUBLIC_KEY = 1;";
mysql -h localhost -u root -p'Testpass1$' -e "START REPLICA;";

mysql -h localhost -u root  -p'Testpass1$' -e "show replica status\G;";



#show replica status\G
## mysql -h localhost -u root -p'Testpass1$' -e "show databases;";


# Install and run prometheus node exporter
apt-get -yq install prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter


# Скрипт бекапа потаблично
sudo mkdir -p /home/vagrant/backup
cat <<'EOF' > /home/vagrant/backup/backup-mysql.sh
#!/bin/bash

# Mysql backup scriptckup script

PATH=$PATH:/usr/local/bin
DIR=$(date +"%Y-%m-%d");
DATE=$(date +"%Y%m%d");
MYSQL="mysql -h localhost -u root -p'Testpass1$' --skip-column-names";
#echo   $($MYSQL -N -e "SHOW DATABASES;");

echo "=============================================="
for DB in $(mysql -h localhost -u root -p'Testpass1$' --skip-column-names -N -e "SHOW DATABASES;"); do
echo "=============================================="
        echo -e "BACKUP DATABASE: $DB\n"
 echo "-----------------------"
 if [ -d "$DIR"_"$DB" ]
        then
            echo "введеная директория "$DIR"_"$DB" существует, продолжаем работу программы"
        else
         mkdir "$DIR"_"$DB"
fi
 for TABLES in $(mysql -h localhost -u root -p'Testpass1$' --skip-column-names -N -e "SHOW TABLES FROM $DB;"); do


         echo -e "BACKUP TABLES FROM "$DB" "$TABLES""
#  echo -e "SHOW $TABLES FROM $DB"
  /usr/bin/mysqldump -u root -p'Testpass1$' --add-drop-table --add-locks --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset --events --routines --triggers  "$DB" "$TABLES" > "$DIR"_"$DB"/$TABLES.sql 2>/dev/null
 done
done
echo "=============================================="

exit 0
EOF

# выполнение бекапа
sudo bash /home/vagrant/backup/backup-mysql.sh

mysql -h localhost -u root  -p'Testpass1$' -e "show replica status\G;";
