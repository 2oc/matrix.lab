#!/bin/bash

mv /home/morpheus /var/tmp
umount /home
lvremove -f /dev/mapper/rhel-home
lvcreate -y -L1g -nrhel-home rhel
mkfs.xfs /dev/rhel/rhel-home
mount -a

VIRT=0
subscription-manager register --auto-attach  --username=${RHNUSER} --password='RHNPASSWD'

subscription-manager repos --disable "*"
uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager release --set=$RELEASE
subscription-manager repos --enable rhel-7-server-rpms 

TCP_PORTS="22 3260"
UDP_PORTS="3260"
SERVICES="nfs rpc-bind mountd"
echo "`hostname -I` `hostname` `hostname -s` " >> /etc/hosts
DEFAULT_ZONE=`/bin/firewall-cmd --get-default-zone`
for PORT in $TCP_PORTS
do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/tcp
done
for PORT in $UDP_PORTS
do
  /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/udp
done
for SERVICE in $SERVICES
do
  /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-service=${SERVICE}
done

/bin/firewall-cmd --reload
/bin/firewall-cmd --list-ports

yum -y update && shutdown now -r
exit 0

#########################
#  NFS SERVER
yum -y install nfs-utils
firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --reload
lvcreate -L10g -nlv_isos rhel
mkfs.xfs /dev/mapper/rhel-lv_isos
mkdir -p /export/nfs/isos/vol0
echo "/dev/mapper/rhel-lv_isos /export/nfs/isos/vol0 xfs defaults 0 0" >> /etc/fstab
mount -a
useradd -u108 -g108 -c "oVirt Manager" -d /var/lib/ovirt-engine -s /sbin/nologin ovirt
chown ovirt:ovirt /export/nfs/isos/vol0
SVCS="rpcbind nfs-server nfs-lock nfs-idmap"
for SVC in $SVCS 
do 
  echo "# NOTE: Starting $SVC"
  systemctl enable $SVC
  systemctl start $SVC
done
echo "/export/nfs/isos/vol0 10.10.10.10(rw,no_root_squash) 10.10.10.11(rw,no_root_squash) 10.10.10.12(rw,no_root_squash)" >> /etc/exports
exportfs -a

exit 0


########################
# THIS IS FOR BUILDING THE BOX WITH KVM
if [ $VIRT == 1 ]
then 
systemctl stop NetworkManager
systemctl disable $_
sed -i -e 's/ONBOOT=no/ONBOOT=yes/g' /etc/sysconfig/network-scripts/ifcfg-enp0s25

  yum -y groupinstall "Virtualization Host"
  yum -y install virt-* libvirt-python
  systemctl start libvirtd
  systemctl enable libvirtd
fi 

nmcli con add type bridge autoconnect yes con-name brkvm ifname brkvm ip4 10.10.10.13/24 gw4 10.10.10.1
nmcli con modify brkvm ipv4.address 10.10.10.13/24 ipv4.method manual
nmcli con modify brkvm ipv4.gateway 10.10.10.1
nmcli con modify brkvm ipv4.dns "10.10.10.121"
nmcli con modify brkvm +ipv4.dns "10.10.10.122"
nmcli con modify brkvm ipv4.dns-search "matrix.lab"
nmcli con delete enp0s25
nmcli con add type bridge-slave autoconnect yes con-name enp0s25 ifname enp0s25 master brkvm
systemctl stop NetworkManager; systemctl start NetworkManager

