#!/bin/bash

# use the GNS3 server virtual environment and get the version
GNS3_VERSION=`source /home/gns3/.venv/gns3server-venv/bin/activate && python3 -m gns3server --version`

# use the repositories this VM was installed from
if [[ -f "/etc/gns3vm-sources.conf" ]]
then
    . "/etc/gns3vm-sources.conf"
fi

# used by the GNS3 restore command
export BRANCH="${GNS3_VM_BRANCH:-resolute-stable}"
curl -Lk "https://raw.githubusercontent.com/${GNS3_VM_REPO:-GNS3/gns3-vm}/$BRANCH/scripts/upgrade_3.1.sh" | bash -s -- "$GNS3_VERSION"
