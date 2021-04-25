#!/usr/bin/env bash

set -euxo pipefail

rm -rf /var/lib/waagent/
rm -f /var/log/waagent.log

waagent -force -deprovision+user

rm -f ~/.bash_history
export HISTSIZE=0

set +e
logout
