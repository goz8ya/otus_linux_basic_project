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

#############################################################
ELK setup
#############################################################

sudo apt update
sudo apt install default-jdk -y

java -version

wget http://192.168.1.77/elasticsearch-8.13.4-amd64.deb
wget http://192.168.1.77/filebeat-8.13.4-amd64.deb
wget http://192.168.1.77/kibana-8.13.4-amd64.deb
wget http://192.168.1.77/logstash-8.13.4-amd64.deb
wget http://192.168.1.77/metricbeat-8.13.4-amd64.deb
wget http://192.168.1.77/packetbeat-8.13.4-amd64.deb


# Устанавливаем ES
sudo dpkg -i elasticsearch-8.13.4-amd64.deb


# Устанавливаем лимиты памяти для виртуальной машины Java
##cat > /etc/elasticsearch/jvm.options.d/jvm.options
##-Xms1g
##-Xmx1g

echo -Xms1g >> /etc/elasticsearch/jvm.options.d/jvm.options
echo -Xmx1g >> /etc/elasticsearch/jvm.options.d/jvm.options

# Правим  сертификаты и безопасность /etc/elasticsearch/elasticsearch.yml
sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/' /etc/elasticsearch/elasticsearch.yml
sed -i 's/^  enabled: true/  enabled: false/' /etc/elasticsearch/elasticsearch.yml


# Старт сервиса
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch.service


# Установка kibana
dpkg -i kibana-8.13.4-amd64.deb

sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml


# Старт сервиса
sudo systemctl daemon-reload
sudo systemctl enable --now kibana.service
sudo  systemctl restart kibana


#############################################
# Установка Logstash
dpkg -i logstash-8.13.4-amd64.deb


sed -i 's/# path.config:/path.config: \/etc\/logstash\/conf.d/' /etc/logstash/logstash.yml
#systemctl enable --now logstash.service
#path.logs: /var/log/logstash

######
# logstash config

#cat <<'EOF'> /etc/logstash/logstash.yml
##############################################
#path.config: /etc/logstash/conf.d
##############################################
#EOF


cat <<'EOF' > /etc/logstash/conf.d/logstash-nginx-es.conf
####################################################
input {
    beats {
        host => "0.0.0.0"
		port => 5400
    }
}

filter {
 grok {
   match => [ "message" , "%{COMBINEDAPACHELOG}+%{GREEDYDATA:extra_fields}"]
   overwrite => [ "message" ]
 }
 mutate {
   convert => ["response", "integer"]
   convert => ["bytes", "integer"]
   convert => ["responsetime", "float"]
 }
 date {
   match => [ "timestamp" , "dd/MMM/YYYY:HH:mm:ss Z" ]
   remove_field => [ "timestamp" ]
 }
 useragent {
   source => "agent"
 }
}

output {
 elasticsearch {
   hosts => ["http://localhost:9200"]
   #cacert => '/etc/logstash/certs/http_ca.crt'
   #ssl => true
   index => "weblogs-%{+YYYY.MM.dd}"
   document_type => "nginx_logs"
 }
 stdout { codec => rubydebug }
}
########################################################
EOF



cat <<'EOF' > /etc/logstash/conf.d/logstash-apache-es.conf
########################################################
input {
    beats {
        host => "0.0.0.0"
        port => 5401
    }
}

filter {
  grok {
    match => { "message" => "%{COMBINEDAPACHELOG}" }
  }
  date {
    match => [ "timestamp" , "dd/MMM/yyyy:HH:mm:ss Z" ]
  }
  useragent {
    source => "agent"
  }
}

output {
 elasticsearch {
   hosts => ["http://localhost:9200"]
   #cacert => '/etc/logstash/certs/http_ca.crt'
   #ssl => true
   index => "weblogs-%{+YYYY.MM.dd}"
   document_type => "apache_logs"
 }
 #stdout { codec => rubydebug }
}
########################################################
EOF


systemctl enable logstash.service
systemctl restart logstash.service


# Установка filebeat
dpkg -i filebeat-8.13.4-amd64.deb 



#sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bcp


 
# filebeat конфиг резерв
cat <<'EOF' > /etc/filebeat/filebeat.yml_new
###########################################
filebeat.inputs:
- type: filestream
  id: my-filestream-id
  enabled: false
  paths:
    - /var/log/*.log
- type: filestream
  paths:
    - /var/log/nginx/*.log
  enabled: true
  exclude_files: ['.gz$']
  prospector.scanner.exclude_files: ['.gz$']
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: true
  setup.template.settings:
  index.number_of_shards: 1
setup.kibana:
output.logstash:
  hosts: ["localhost:5400"]
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
############################################
EOF

#systemctl enable filebeat
#systemctl restart filebeat

#sudo filebeat modules enable nginx


# Metricbeat настройка
#dpkg -i metricbeat-8.9.1-amd64.deb

#systemctl enable --now metricbeat

# https://www.elastic.co/guide/en/beats/metricbeat/current/load-kibana-dashboards.html

#metricbeat setup --dashboards


# Install and run prometheus node exporter
apt-get -yq install prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

sudo filebeat setup --dashboards