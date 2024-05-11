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

# Вносим настройки для работы репликации  Source
echo "log-bin = mysql-bin"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "binlog_format = row"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "gtid-mode=ON"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "enforce-gtid-consistency"  >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "log-replica-updates"  >> /etc/mysql/mysql.conf.d/mysqld.cnf

#после чего делаем рестарт:
systemctl restart mysql


# mysql -h localhost -u root -e "show databases;";

# Устанавливаем пароль root
mysql -h localhost -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY 'Testpass1$';";

# Создаём пользователя для реплики
mysql -h localhost -u root -p'Testpass1$' -e "CREATE USER repl@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'oTUSlave#2020';";

# Даём ему права на репликацию
mysql -h localhost -u root -p'Testpass1$' -e "GRANT REPLICATION SLAVE ON *.* TO repl@'%';";

# Смотрим пользователей
mysql -h localhost -u root -p'Testpass1$' -e "SELECT User, Host FROM mysql.user;";

# Закрываем и блокируем все таблицы
mysql -h localhost -u root -p'Testpass1$' -e "FLUSH TABLES WITH READ LOCK;";


# Смотрим статус Мастера
#mysql -h localhost -u root -p'Testpass1$' -e "SHOW MASTER STATUS;";

# Добавляем таблицу
## mysql -h localhost -u root -p'Testpass1$' -e "create database test_database;";
## mysql -h localhost -u root -p'Testpass1$' -e "show databases;";
## mysql -h localhost -u root -p'Testpass1$' -e "CREATE TABLE test_database.test_table (id int);";
## mysql -h localhost -u root -p'Testpass1$' -e "insert into test_database.test_table values (2),(3),(4);";
## mysql -h localhost -u root -p'Testpass1$' -e "select * from test_database.test_table;";




# Install and run prometheus node exporter
apt-get -yq install prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter


# Смотрим статус Мастера
mysql -h localhost -u root -p'Testpass1$' -e "SHOW MASTER STATUS;";