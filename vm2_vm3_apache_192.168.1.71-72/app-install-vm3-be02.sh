echo "Start Install app"
sudo timedatectl set-timezone 'Europe/Moscow'
#sudo uname -r
sudo apt-get update
sudo apt install apache2 -y
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl status apache2
sudo sed -i 's/Apache2 Default Page/VM3-BE02 Test Page/' /var/www/html/index.html


wget http://192.168.1.77/filebeat-8.13.4-amd64.deb
dpkg -i filebeat-8.13.4-amd64.deb 



sudo filebeat modules enable apache
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bcp


sudo filebeat modules enable apache


# filebeat конфиг актуалочка
cat <<'EOF' > /etc/filebeat/filebeat.yml
###########################################
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: true
  reload.period: 30s
setup.template.settings:
  index.number_of_shards: 1
tags: ["web", "apache"]
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

#модуль apache
cat <<'EOF' > /etc/filebeat/modules.d/apache.yml
# Module: apache
# Docs: https://www.elastic.co/guide/en/beats/filebeat/8.13/filebeat-module-apache.html

- module: apache
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

############################################
EOF

# Install and run prometheus node exporter
apt-get -yq install prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter