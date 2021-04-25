#!/usr/bin/env bash

# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-centos

set -euxo pipefail

cat >> /etc/sysconfig/network  <<EOF
 NETWORKING=yes
 HOSTNAME=localhost.localdomain
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
 DEVICE=eth0
 ONBOOT=yes
 BOOTPROTO=dhcp
 TYPE=Ethernet
 USERCTL=no
 PEERDNS=yes
 IPV6INIT=no
 NM_CONTROLLED=no
EOF

ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules

sed -i 's/GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="rootdelay=300 console=ttyS0 earlyprintk=ttyS0 net.ifnames=0 " /' /etc/default/grub

grub2-mkconfig -o /boot/grub2/grub.cfg

echo 'add_drivers+=" hv_vmbus hv_netvsc hv_storvsc "' >> /etc/dracut.conf
dracut -f -v

yum clean all
yum -y update

yum install -y WALinuxAgent
systemctl enable waagent

# cloud-init
yum install -y cloud-init cloud-utils-growpart gdisk hyperv-daemons

# Configure waagent for cloud-init
sed -i 's/Provisioning.UseCloudInit=n/Provisioning.UseCloudInit=y/g' /etc/waagent.conf
sed -i 's/Provisioning.Enabled=y/Provisioning.Enabled=n/g' /etc/waagent.conf


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
echo Removing swapfile - RHEL uses a swapfile by default
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
