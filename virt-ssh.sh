#!/bin/bash

VM_NO=$(virsh list --all --name | nl | xargs whiptail --menu "Select a VM to ssh" 0 0 0 3>&1 1>&2 2>&3)
VM_NAME=$(virsh list --all --name | nl | awk -v vm_no=$VM_NO '$1 == vm_no { print $2 }')
VM_STATE=$(virsh list --all | awk -v vm_name=$VM_NAME '$2 == vm_name { print $3 }')

if [ "$VM_STATE" = "shut" ] ; then
  whiptail --yesno "$VM_NAME is not running, start it?" 0 0
  if [ $? -eq 0 ] ; then
    virsh start $VM_NAME
    echo "Waiting DHCP lease for VM..."
    bash -c "watch -g virsh net-dhcp-leases default" >/dev/null
  else
    exit 0
  fi
fi

if [ -z "$VM_NAME" ] ; then
  echo "No VM was selected"
  exit 1
fi

MAC=$(virsh dumpxml $VM_NAME | \
  xmllint --xpath "//mac/@address" - | \
  sed -r 's/^.*(..:..:..:..:..:..).*$/\1/')
if [ -z "$MAC" ] ; then
  echo "No mac address for $VM_NAME found"
  exit 1
fi 
	
IPv4=$(virsh net-dhcp-leases default | \
  grep $MAC | \
  awk '{ print $5 }' | \
  sed -r 's!/.*$!!')
if [ -z "$IPv4" ] ; then
  echo "No IPv4 address for $MAC found"
  exit 1
fi

ssh $IPv4
