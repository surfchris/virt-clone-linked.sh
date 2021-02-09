#!/bin/bash

set -xe
# This script takes as a parameter the name of the VM
# and creates a linked clone
# Ref: https://unix.stackexchange.com/a/33584
# The scripts assumes that it runs from the same folder 
# where the vm image is located and it coincides with the 
# image name

# if less than two arguments supplied, display usage 
if [  $# -ne 2 ] 
then 
    echo "This script takes as input the name of the VM to clone"
    echo "Usage: $0 vm_name_orig vm_name_clone"
    exit 1
fi 

VM_NAME=$1
VM_CLONE=$2

# You cannot "clone" a running vm, stop it.  suspend and destroy
# are also valid options for less graceful cloning
if  virsh --connect=qemu:///system list | grep $VM_NAME
then
    virsh --connect=qemu:///system shutdown $VM_NAME
    sleep 60
fi
# Make the golden image read only
chmod a-w $VM_NAME.qcow2

# dump the xml for the original
virsh --connect=qemu:///system dumpxml $VM_NAME > /tmp/golden-vm.xml

# Create a linked clone in the current folder
qemu-img create -f qcow2 -b $VM_NAME.qcow2 $VM_CLONE.qcow2

# hardware addresses need to be removed, libvirt will assign
# new addresses automatically
sed -i /uuid/d /tmp/golden-vm.xml
sed -i '/mac address/d' /tmp/golden-vm.xml

# and actually rename the vm: (this also updates the storage path)
sed -i s/$VM_NAME/$VM_CLONE/ /tmp/golden-vm.xml

# finally, create the new vm
virsh --connect=qemu:///system define /tmp/golden-vm.xml
