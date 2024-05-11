#!/usr/bin/env bash
sudo apt-get update
sudo timedatectl set-timezone 'Europe/Moscow'
# Создаем директории для хранения скачаных файлов
mkdir /home/vagrant/Downloads
cd /home/vagrant/Downloads

# Скачиваем инсталяционные файлы
wget https://github.com/prometheus/prometheus/releases/download/v2.51.2/prometheus-2.51.2.linux-amd64.tar.gz
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz


# Распаковвываем архивы 
tar xzvf node_exporter-*.t*gz
tar xzvf prometheus-*.t*gz

# Добавляем пользователей
useradd --no-create-home --shell /usr/sbin/nologin prometheus
useradd --no-create-home --shell /bin/false node_exporter

# Установка node_exporter

# Копируем файлы в /usr/local
cp node_exporter-*.linux-amd64/node_exporter /usr/local/bin
chown node_exporter: /usr/local/bin/node_exporter


# Создаём службу node exporter
cat <<EOF > /etc/systemd/system/node_exporter.service
##############################
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
##############################
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl status node_exporter
systemctl enable node_exporter

# Установка prometheus
mkdir {/etc/,/var/lib/}prometheus
cp -vi prometheus-*.linux-amd64/prom{etheus,tool} /usr/local/bin
cp -rvi prometheus-*.linux-amd64/{console{_libraries,s},prometheus.yml} /etc/prometheus/
chown -Rv prometheus: /usr/local/bin/prom{etheus,tool} /etc/prometheus/ /var/lib/prometheus/


# Настраиваем сервис
cat <<EOF > /etc/systemd/system/prometheus.service
################################
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
#################################
EOF

# Конфиг prometheus
cat <<EOF > /etc/prometheus/prometheus.yml
#####################################
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']
  
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: 
        - '192.168.1.74:9100' # mysql-source
        - '192.168.1.75:9100' # mysql-replica
        - '192.168.1.71:9100' # web-app-nd1
        - '192.168.1.72:9100' # web-app-nd2
        - '192.168.1.73:9100' # nginx reverse proxy
        - 'localhost:9100'    # 192.168.1.70:9100 - prometheus itself
        - '192.168.1.76:9100' # elk stack
###############################################################
EOF



# Запускаем сервис Prometheus
systemctl daemon-reload
systemctl start prometheus
systemctl status prometheus
systemctl enable prometheus



# Установка Grafana

##wget https://dl.grafana.com/oss/release/grafana_6.7.0_amd64.deb -O /home/vagrant/Downloads/grafana_6.7.0_amd64.deb
wget https://dl.grafana.com/oss/release/grafana_10.4.2_amd64.deb -O /home/vagrant/Downloads/grafana_10.4.2_amd64.deb


##sudo apt-get install -y adduser libfontconfig
sudo apt-get install -y adduser libfontconfig1 musl

# Установка из пакета
sudo dpkg -i /home/vagrant/Downloads/grafana_10.4.2_amd64.deb

# Конфиг datasource grafana не работает 
#cat <<EOF > /etc/grafana/provisioning/datasources/sample.yaml
###############################################################
#apiVersion: 1
#data sources:
#    - name: Prometheus
#      type: prometheus
#      access: proxy
#      url: http://prometheus:9090
################################################################
#EOF

#скачиваем и восстанавливаем базу
wget https://github.com/goz8ya/otus_linux_basic_project/raw/main/grafana/grafana.db.back.dump -O /var/lib/grafana/grafana.db.back.dump
# wget https://github.com/goz8ya/otus_linux_basic_project/raw/main/grafana.db.bac -O /var/lib/grafana/grafana.db
#https://github.com/goz8ya/otus_linux_basic_project/raw/a33bac1536cfb1e7a9c2d05940864a580bd3817a/grafana.db.bak
apt install -y sqlite3 
#sqlite3 sqlite3 /var/lib/grafana/grafana.db ".backup /var/lib/grafana/grafana.db.bak"
# бекап
#sqlite3 /var/lib/grafana/grafana.db .dump >  /var/lib/grafana/grafana.db.back
#sqlite3 sample.db .dump > sample.bak
# восстановление
#sqlite3 sample.db < sample.bak
rm -f /var/lib/grafana/grafana1.db
sqlite3 /var/lib/grafana/grafana.db  < /var/lib/grafana/grafana.db.back.dump

# Устанавливаем нужные права
chmod 664 /var/lib/grafana/grafana.db
chown grafana: /var/lib/grafana/grafana.db

# start grafana service 
#sudo service grafana-server start

# Запуск
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
systemctl status grafana-server


