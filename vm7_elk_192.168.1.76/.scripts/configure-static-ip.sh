#!/bin/sh

echo 'Setting static IP address for Hyper-V...'
sudo hostnamectl set-hostname $5

cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no     	
      addresses: [$1/$3]
      gateway4: $2
      nameservers:
        addresses: [$4,8.8.8.8]
EOF

#sudo netplan apply
