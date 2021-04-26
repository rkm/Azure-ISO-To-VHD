#!/usr/bin/env bash

# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-centos

set -euxo pipefail

systemctl enable NetworkManager
nmcli con mod eth0 connection.autoconnect yes ipv4.method auto

grub2-editenv - unset kernelopts

sed -i 's/GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="rootdelay=300 console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 earlyprintk=ttyS0 net.ifnames=0 rhgb quiet crashkernel=auto"/' /etc/default/grub
sed -i 's/GRUB_TERMINAL_OUTPUT=".*"/GRUB_TERMINAL_OUTPUT="serial console"/' /etc/default/grub
sed -i 's/GRUB_SERIAL_COMMAND=".*"/GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"/' /etc/default/grub

grub2-mkconfig -o /boot/grub2/grub.cfg
# eeh
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

echo "ClientAliveInterval 180" >> /etc/ssh/sshd_config

yum clean all
yum -y update

yum install -y python3-pyasn1 WALinuxAgent
systemctl enable waagent

yum install -y cloud-init cloud-utils-growpart gdisk hyperv-daemons
systemctl enable cloud-init

sed -i 's/Provisioning.Agent=auto/Provisioning.Agent=cloud-init/g' /etc/waagent.conf
sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf

echo "Adding mounts and disk_setup to init stage"
sed -i '/ - mounts/d' /etc/cloud/cloud.cfg
sed -i '/ - disk_setup/d' /etc/cloud/cloud.cfg
sed -i '/cloud_init_modules/a\\ - mounts' /etc/cloud/cloud.cfg
sed -i '/cloud_init_modules/a\\ - disk_setup' /etc/cloud/cloud.cfg

echo "Allow only Azure datasource, disable fetching network setting via IMDS"
cat > /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<EOF
datasource_list: [ Azure ]
datasource:
    Azure:
        apply_network_config: False
EOF

if [[ -f /mnt/resource/swapfile ]]; then
    echo "Removing swapfile" #RHEL uses a swapfile by defaul
    swapoff /mnt/resource/swapfile
    rm /mnt/resource/swapfile -f
fi

echo "Add console log file"
cat >> /etc/cloud/cloud.cfg.d/05_logging.cfg <<EOF

# This tells cloud-init to redirect its stdout and stderr to
# 'tee -a /var/log/cloud-init-output.log' so the user can see output
# there without needing to look on the console.
output: {all: '| tee -a /var/log/cloud-init-output.log'}
EOF

sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf

