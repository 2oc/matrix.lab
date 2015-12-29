#!/bin/bash

#  This is to manage KVM-based VMs.  Not inteneded for the RHEV VMs

delete_keys() {
  echo "NOTE: cleaning up keys"
  sed -i -e '/rh7ose.*.matrix/d' ~jradtke/.ssh/known_hosts-lab
  sed -i -e '/10.10.10./d' ~jradtke/.ssh/known_hosts-lab
}

install_keys() {
for HOST in `sudo virsh list --all | grep -i rh7ose | awk '{ print $2 }'`
    do
      ssh-copy-id -oStrictHostKeyChecking=no -i ~jradtke/.ssh/id_rsa.pub ${HOST}.${DOMAIN}
    done
}

delete_VMs() {
  for VM in `sudo virsh list --all | grep -i rh7ose | awk '{ print $2 }'`
  do
    echo "# Removing VM: $VM"
    sudo virsh destroy $VM 
    sudo virsh undefine $VM 
  done
  sudo rm -rf /var/lib/libvirt/images/RH7OSE*
}

build_VMs() {
  for HOST in `grep -v \# hosts | grep -i rh7ose | cut -f1 -d\. | tr [a-z] [A-Z]`
  do 
    echo $HOST
    ./build_KVM.sh $HOST; sleep 180 
  done
}

usage() {
  echo "${0} [post|delete|build]"
  exit 9
}

case $1 in 
  post)
    for HOST in $HOSTS
    do 
      echo "# NOTE:  $HOST - post_install.sh"
      ssh $HOST "sh ./post_install.sh"
    done
  ;;
  build)
    build_VMs
  ;;
  deletekeys)
    delete_keys
  ;;
  delete)
    delete_VMs
  ;;
  start)
    for VM in `/usr/bin/sudo virsh list --all | grep -i rh7ose | awk '{ print $2 }'`; do /usr/bin/sudo virsh start $VM; done
  ;;
  stop)
    echo "NOTE: Stopping VMs" 
    for VM in `/usr/bin/sudo virsh list --all | grep -i rh7ose | awk '{ print $2 }'`; do /usr/bin/sudo virsh destroy $VM; done
  ;;
  *)
    exit 9
  ;;
esac

exit 0
