#!/bin/bash

#set -x
set -e

# This script takes as a parameter the name of the VM
# and creates a linked clone
# Ref: https://unix.stackexchange.com/a/33584
# Ref: https://gist.github.com/aojea/7b32879f949f909f241d41c4c9dbf80c
# Changes:
#   * VM shutdown replaced with check
#   * One or less QCOW2 image device support (check added)
#   * Start form image directory not required anymore
#   * Base VM name don't have to be the same as image name anymore
#   * Temporary file is not created anymore

# if less than two arguments supplied, display usage 
if [  $# -ne 2 ] 
then 
    echo "This script takes as input the name of the VM to clone"
    echo "Usage: $0 vm_name_orig vm_name_clone"
    exit 1
fi 

VM_NAME="$1"
VM_CLONE="$2"

# You cannot "clone" a running vm, stop it.  suspend and destroy
# are also valid options for less graceful cloning
if  virsh list | grep "$VM_NAME" &> /dev/null ; then
  echo "(!) Base VM have to be in stopped state to used as clone base.
    Stop it using, for example, one of following commands, and re-run this script:
      virsh shutdown \"$VM_NAME\"
      virsh suspend \"$VM_NAME\"
      virsh destroy \"$VM_NAME\"
    Exiting..."
  exit 1
fi

# Get VM XML to variable
VM_XML="$(virsh dumpxml --domain "$VM_NAME")"

# Check if VM has one or less QCOW2 image device
if [ $(echo "$VM_XML" | grep -o -P "(?<=').*?\.qcow2(?=')" | wc -l) -gt 1 ]; then
  echo "(!) VM's with one QCOW2 image device supported as clone base only.
    Exiting..."
  exit 1
fi

# Get QCOW2 image pathname (the first only)
VM_IMAGE="$(echo "$VM_XML" | grep -o -P "(?<=').*?\.qcow2(?=')" | head -n 1)"

# Create clone VM QCOW2 image pathname
VM_CLONE_IMAGE="$(echo "$VM_XML" | fgrep .qcow2 | grep -o -P "(?<=').*/(?=.*')" | head -n 1)$VM_CLONE.qcow2"

# Make the golden image read only
chmod a-w "$VM_IMAGE"

# Create linked clone image
qemu-img create -q -f qcow2 -F qcow2 -b "$VM_IMAGE" "$VM_CLONE_IMAGE"

# dump the xml for the original
# hardware addresses need to be removed, libvirt will assign
# new addresses automatically
# and actually rename the vm: (this also updates the storage path)
# finally, create the new vm
virsh define <( \
  echo "$VM_XML" | \
  sed /uuid/d | \
  sed '/mac address/d' | \
  sed "s/"$VM_NAME"/"$VM_CLONE"/" ) &>  /dev/null

