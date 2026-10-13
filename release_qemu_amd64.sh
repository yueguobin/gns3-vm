#!/bin/bash
#
# This script takes a VM and installs GNS3 server on it.
#
# Unlike the other release scripts it only needs Qemu, so it can run on a
# plain Linux machine with KVM and no VMware or VirtualBox. The result is a
# KVM/libvirt ready qcow2 image.
#
# You need to pass GNS3 version as parameter
#

set -e

export GNS3_VERSION=`echo $1 | sed "s/^v//"`
export GNS3_VM_FILE=$2

if [[ "$GNS3_VERSION" == "" ]]
then
    echo "You need to pass the GNS3 version as parameter"
    exit 1
fi

# GNS3_SERVER_REPO and GNS3_SERVER_REF can be set in the environment to
# install the GNS3 server from a fork (see config/gns3vm-sources.conf)
if [[ "$GNS3_VERSION" == *dev ]]
then
    # development release, e.g. 3.1dev
    export GNS3_RELEASE_CHANNEL=`echo -n $GNS3_VERSION | sed "s/dev$//"`
else
    export GNS3_RELEASE_CHANNEL=`echo -n $GNS3_VERSION | sed "s/\.[^.]*$//"`
fi

echo "Build VM for GNS3 $GNS3_VERSION"
echo "Release channel: $GNS3_RELEASE_CHANNEL"

export GNS3VM_VERSION=`cat version`

if [[ "$GNS3_VM_FILE" == "" ]]
then
    export GNS3VM_URL="https://github.com/${GNS3_VM_REPO:-GNS3/gns3-vm}/releases/download/v${GNS3VM_VERSION}/GNS3VM.Base.${GNS3VM_VERSION}.zip"
    echo "Download the base GNS3 VM version ${GNS3VM_VERSION} from GitHub"
    if [[ ! -f "/tmp/GNS3VM.Base.${GNS3VM_VERSION}.zip" ]]
    then
        echo "Downloading $GNS3VM_URL"
        curl -Lk "$GNS3VM_URL" > "/tmp/GNS3VM.Base.${GNS3VM_VERSION}.zip"
    fi
else
    echo "GNS3 VM file: $GNS3_VM_FILE"
    cp "$GNS3_VM_FILE" "/tmp/GNS3VM.Base.${GNS3VM_VERSION}.zip"
fi

7z e -y "/tmp/GNS3VM.Base.${GNS3VM_VERSION}.zip"

rm -Rf output-qemu-amd64
packer build -only=qemu-amd64 gns3_release.json

# The disks are the ones in the current directory (see the -drive qemuargs
# of the qemu-amd64 builder), the GNS3 server is installed in the first one
qemu-img convert -O qcow2 gns3vm-disk1.qcow2 "GNS3 VM-disk001.qcow2"
qemu-img convert -O qcow2 gns3vm-disk2.qcow2 "GNS3 VM-disk002.qcow2"
rm -Rf output-qemu-amd64

# Reuse the libvirt definition and the start script shipped for the KVM VM
rm -Rf qemu-build
mkdir qemu-build
mv "GNS3 VM-disk001.qcow2" "GNS3 VM-disk002.qcow2" qemu-build/
cp gns3vm_libvirt.xml start-gns3vm.sh qemu-build/
sed -i "s|GNS3\.VM\.KVM\.[0-9.]\+|GNS3.VM.QEMU.${GNS3_VERSION}|g" qemu-build/gns3vm_libvirt.xml

cd qemu-build
7z a -bsp1 -mx=1 "../GNS3.VM.QEMU.${GNS3_VERSION}.zip" "GNS3 VM-disk001.qcow2" "GNS3 VM-disk002.qcow2" gns3vm_libvirt.xml start-gns3vm.sh
cd ..
rm -Rf qemu-build
