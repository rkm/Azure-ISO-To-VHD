#!/bin/bash

set -euxo pipefail

packer_version="1.7.2"

wget https://releases.hashicorp.com/packer/"$packer_version"/packer_"$packer_version"_linux_amd64.zip
unzip packer_"$packer_version"_linux_amd64.zip
chmod +x packer
mv packer /usr/local/bin
