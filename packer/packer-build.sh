#!/bin/bash

#Bake image
#Building image with packer
cd /root/config
packer fix template.json > template-fixed.json
PACKER_LOG=1 PACKER_LOG_PATH=/root/packer.log packer build template-fixed.json

#Packer image build complete. Converting to VHD format.
qemu-img convert -f raw -o subformat=fixed,force_size -O vpc disk/baked baked.vhd
