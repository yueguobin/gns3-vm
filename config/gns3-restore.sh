#!/bin/bash
#
# This command allows to fix a broken installation
#

if [[ $(id -u) -ne 0 ]] 
then
    echo "Please run this script as root or using sudo"
    exit 1
fi

# use the repositories this VM was installed from
if [[ -f "/etc/gns3vm-sources.conf" ]]
then
    . "/etc/gns3vm-sources.conf"
fi

export BRANCH="${GNS3_VM_BRANCH:-resolute-stable}"
curl -Lk "https://raw.githubusercontent.com/${GNS3_VM_REPO:-GNS3/gns3-vm}/$BRANCH/scripts/restore.sh" | bash
