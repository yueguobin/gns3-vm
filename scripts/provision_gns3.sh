#!/bin/bash

# Installs GNS3 on a fresh VM

env

# wait for dpkg/apt locks to be released
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
   echo 'Waiting for the release of dpkg/apt locks...'
   sleep 5
done

# use the GNS3 server virtual environment
source /home/gns3/.venv/gns3server-venv/bin/activate

# upgrade pip, wheel and setuptools to the latest version
python3 -m pip install --upgrade pip wheel setuptools

# Exit immediately if a command exits with a non-zero status.
set -e

# remember what was explicitly requested before falling back to the defaults
GNS3_SERVER_REPO_OVERRIDE="$GNS3_SERVER_REPO"
GNS3_SERVER_REF_OVERRIDE="$GNS3_SERVER_REF"

# fall back to the repositories this VM is configured for, when none was
# passed in the environment (there is nothing to fall back to at build time,
# the file is written by install.sh)
if [[ -f "/etc/gns3vm-sources.conf" ]]
then
    . "/etc/gns3vm-sources.conf"
fi

export GNS3_SERVER_REPO="${GNS3_SERVER_REPO:-GNS3/gns3-server}"

if [[ "$GNS3_RELEASE_CHANNEL" == "2.2" ]]
then
  # Install from a branch on GitHub
  echo "Installing GNS3 server $GNS3_VERSION from GitHub"
  python3 -m pip install "gns3-server@git+https://github.com/${GNS3_SERVER_REPO}.git@v$GNS3_VERSION"
elif [[ "$GNS3_RELEASE_CHANNEL" == "3.1" && -n "$GNS3_SERVER_REF" ]]
then
  # A specific branch, tag or commit was requested: install it from GitHub
  echo "Installing GNS3 server $GNS3_SERVER_REF from GitHub"
  python3 -m pip install "gns3-server[ai-features]@git+https://github.com/${GNS3_SERVER_REPO}.git@${GNS3_SERVER_REF}"
elif [[ "$GNS3_RELEASE_CHANNEL" == "3.1" ]]
then
  echo "Installing GNS3 server $GNS3_VERSION from PyPI"
  python3 -m pip install gns3-server[ai-features]==${GNS3_VERSION}
elif [[ "$GNS3_RELEASE_CHANNEL" == "3.1dev" ]]
then
  # the latest development version, unless a ref was requested
  GNS3_SERVER_REF="${GNS3_SERVER_REF:-3.1}"
  echo "Installing GNS3 server dev $GNS3_SERVER_REF from GitHub"
  python3 -m pip install "gns3-server[ai-features]@git+https://github.com/${GNS3_SERVER_REPO}.git@${GNS3_SERVER_REF}"
fi

# clean pip cache to reduce the size of the VM
python3 -m pip cache info
python3 -m pip cache purge

set +e

# Configure the GNS3 server
mkdir -p "/opt/gns3/server"
cat > "/opt/gns3/server/gns3_server.conf" << EOF
[Server]
host = 0.0.0.0
port = 80
images_path = /opt/gns3/images
projects_path = /opt/gns3/projects
report_errors = True
default_nat_interface = gns3br0
EOF

# Remember the repository the server was installed from, so that the in-VM
# upgrade and restore commands keep using it. Only when one was explicitly
# requested, otherwise the configuration of the VM is left untouched.
if [[ -f "/etc/gns3vm-sources.conf" ]] && [[ -n "$GNS3_SERVER_REPO_OVERRIDE$GNS3_SERVER_REF_OVERRIDE" ]]
then
    sudo sed -i -e "s|^GNS3_SERVER_REPO=.*|GNS3_SERVER_REPO=\"${GNS3_SERVER_REPO}\"|" \
                -e "s|^GNS3_SERVER_REF=.*|GNS3_SERVER_REF=\"${GNS3_SERVER_REF}\"|" /etc/gns3vm-sources.conf
fi

# Make sure we have the latest version of the GNS3 VM menu
sudo mv "/tmp/gns3welcome.py" "/usr/local/bin/gns3welcome.py"
sudo chmod 755 "/usr/local/bin/gns3welcome.py"

sudo apt -y autoremove --purge
sudo apt -y clean

sudo rm -fr /var/lib/apt/lists/*
sudo rm -fr /var/cache/apt/*
sudo rm -fr /var/cache/debconf/*

# Defragment
sudo e4defrag / &>/dev/null

# Setup zerofree for disk compaction
sudo bash /usr/local/bin/zerofree

if [[ $PACKER_BUILDER_TYPE == "vmware-iso" ]]
then
   sudo vmware-toolbox-cmd disk shrink /
fi
