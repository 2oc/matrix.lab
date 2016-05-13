#!/bin/sh
#
# Purpose:  This is a script create to process a single hostname as input 
#             and fetch the configuration parameters from a configuration file
#           I created it to primarily save myself some time
#  Author:  James Radtke <jradtke@redhat.com>
#   NOTES:  This is NOT a Red Hat supported work

usage() {
  echo "ERROR: Pass a guestname" 
  echo "       $0 <hostname>"
  exit 9; 
}

if [ $# -ne 1 ]; then usage; fi 
if [ `whoami` != "root" ]; then echo "ERROR: you should be root"; exit 9; fi

# See if the VM is already running
virsh list | grep ${1} 
case $? in 
  0)
    echo "NOTE: VM ${1} already exists."; 
    exit 9
  ;;
  *)
    echo "NOTE: creating ${1}"
  ;;
esac

GUESTNAME=${1}
CONFIG=./.config
WEBSERVER=`ip a | grep inet | egrep -v 'inet6|host lo|br0' | awk '{ print $2 }' | cut -f1 -d\/ | head -1`
WEBSERVER="10.10.10.10"

if [ ! -f $CONFIG ]
then
  echo "ERROR: No Config File found"
  exit 9
fi

grep ${GUESTNAME} $CONFIG 
case $? in 
  0)
    echo "SUCCESS:  $GUESTNAME found in $CONFIG"
  ;;
  *)
    echo "ERROR: $GUESTNAME not found in $CONFIG"; 
    exit 9
  ;;
esac

grep ^${GUESTNAME} $CONFIG | awk -F':' '{ print $1" "$2" "$3" "$4" "$5" "$6 }' | while read GUESTNAME RELEASE NUMCPUS MEM HDDA HDDB
do
  echo $GUESTNAME $RELEASE $NUMCPUS $MEM $HDD0 $HDD1
  echo "GUESTNAME: $GUESTNAME"
  echo "RELEASE: $RELEASE"
  echo "NUMCPUS: $NUMCPUS"
  echo "MEM: $MEM"
  echo "HDDA: $HDDA"
  echo "HDDB: $HDDB"

  echo "NOTE: pause for 5 seconds to review parameters above"
  sleep 5
# CREATE THE BASEDIR AND DISK IMAGE FILES
if [ ! -d /var/lib/libvirt/images/${GUESTNAME} ]
then
  echo "mkdir /var/lib/libvirt/images/${GUESTNAME}"
  mkdir /var/lib/libvirt/images/${GUESTNAME}
fi
if [ ! -f /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-0.img  ]
then
  echo "qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-0.img ${HDDA}G "
  qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-0.img ${HDDA}G 
fi 
if [ $HDDB != 0 ]
then
  NUMDISK=2
  if [ ! -f /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-1.img  ]
  then
    echo "qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-1.img ${HDDB}G "
    qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-1.img ${HDDB}G 
  fi 
fi
find /var/lib/libvirt/images/${GUESTNAME} -type d -exec chmod 770 {} \;
find /var/lib/libvirt/images/${GUESTNAME} -type f -exec chmod 660 {} \;
chown -R qemu:qemu /var/lib/libvirt/images/${GUESTNAME}
restorecon -RFvv /var/lib/libvirt/images/${GUESTNAME}

case $RELEASE in 
  EL6) OSDIR="RHEL-6.6-x86_64"; OSVARIANT="rhel6" ;;
  EL7) OSDIR="RHEL-7.2-x86_64"; OSVARIANT="rhel7";;
  RHS3) OSDIR="RHS-3";;
  *)  echo "ERROR: Unsupported Release in $CONFIG"; exit 9;;
esac

# Need to create a way to deal with more than one "build-time" disk
case $NUMDISK in
  2)
    echo "Started: `date`"
virt-install --noautoconsole --name ${GUESTNAME} --hvm --connect qemu:///system \
  --description "${GUESTNAME}" --virt-type=kvm \
  --network=bridge:brkvm --vcpus=${NUMCPUS} --ram=${MEM} \
  --disk /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-0.img,device=disk,bus=virtio,format=qcow2 \
  --disk /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-1.img,device=disk,bus=virtio,format=qcow2 \
  --os-type=linux --os-variant=${OSVARIANT}  \
  --location="http://${WEBSERVER}/OS/${OSDIR}" \
  -x "ks=http://${WEBSERVER}/${GUESTNAME}.ks"
  echo "Completed: `date`"
  ;;
  *)
    echo "Started: `date`"
virt-install --noautoconsole --name ${GUESTNAME} --hvm --connect qemu:///system \
  --description "${GUESTNAME}" --virt-type=kvm \
  --network=bridge:brkvm --vcpus=${NUMCPUS} --ram=${MEM} \
  --disk /var/lib/libvirt/images/${GUESTNAME}/${GUESTNAME}-0.img,device=disk,bus=virtio,format=qcow2 \
  --os-type=linux --os-variant=${OSVARIANT} \
  --location="http://${WEBSERVER}/OS/${OSDIR}" \
  -x "ks=http://${WEBSERVER}/${GUESTNAME}.ks"
  echo "Completed: `date`"
  ;;
esac

done

exit 0
# Snippet about newer style of boot params
echo "inst.gpt ip=10.10.10.121:10.10.10.1:255.255.255.0:rh7idm01.matrix.lab:eth0:static ks=http://${WEBSERVER}/${GUESTNAME}.ks"
