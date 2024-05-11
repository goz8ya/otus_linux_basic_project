#!/usr/bin/env bash
sudo apt-get update
sudo timedatectl set-timezone 'Europe/Moscow'
# Устанавливаем nginx
sudo apt install nginx -y

cat <<'EOF' > /etc/nginx/sites-available/default
#################################
upstream backend {
                least_conn;
        server 192.168.1.71:80;
        server 192.168.1.72:80;
}

server {
       listen 80;
#       listen [::]:80;
#
#       server_name example.com;

       root /var/www/html;
       index index.html;
location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
        }
}
##################################
EOF





# Install and run prometheus node exporter
apt-get -yq install prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter


systemctl enable nginx
systemctl reload nginx
systemctl start nginx
systemctl status nginx

# Установка filebeat

wget http://192.168.1.77/filebeat-8.13.4-amd64.deb
dpkg -i filebeat-8.13.4-amd64.deb 



sudo filebeat modules enable nginx
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bcp


# filebeat конфиг резерв
cat <<'EOF' > /etc/filebeat/filebeat.yml_bcp
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
  hosts: ["192.168.1.76:5400"]
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
############################################
EOF

# filebeat конфиг актуалочка
cat <<'EOF' > /etc/filebeat/filebeat.yml
###########################################
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: true
  reload.period: 30s
setup.template.settings:
  index.number_of_shards: 1
tags: ["web", "nginx"]
#setup.kibana:
output.elasticsearch:
  hosts: ["192.168.1.76:9200"]
  preset: balanced
#output.logstash:
#  hosts: ["192.168.1.76:5400"]
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
############################################
EOF

#модуль nginx
cat <<'EOF' > /etc/filebeat/modules.d/nginx.yml
# Module: nginx
# Docs: https://www.elastic.co/guide/en/beats/filebeat/8.13/filebeat-module-nginx.html

- module: nginx
  # Access logs
  access:
    enabled: true

    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    #var.paths:

  # Error logs
  error:
    enabled: true

    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    #var.paths:

  # Ingress-nginx controller logs. This is disabled by default. It could be used in Kubernetes environments to parse ingress-nginx logs
  ingress_controller:
    enabled: false

    # Set custom paths for the log files. If left empty,
    # Filebeat will choose the paths depending on your OS.
    #var.paths:
############################################
EOF

sudo systemctl enable filebeat
sudo systemctl start filebeat

