#!/bin/bash

# This should be run on the node that is providing the NFS storage

######################### ######################### #########################
# NFS for Persistent Volumes (PVS) and Registry Storage
######################### ######################### #########################
#  On NFS "Server"
VG=rhel
LVSIZE=3g
cp /etc/fstab /etc/fstab.bak-`date +%F`
cp /etc/exports /etc/exports.bak-`date +%F`
for VOLUME in pv{1..10}
do
  lvcreate -L${LVSIZE} -nlv_${VOLUME} $VG
  mkfs.xfs -f /dev/mapper/${VG}-lv_${VOLUME}
  mkdir -p /export/nfs/pvs/${VOLUME}
  echo "/dev/mapper/${VG}-lv_${VOLUME} /export/nfs/pvs/${VOLUME} xfs defaults 0 0" >> /etc/fstab
  echo "/export/nfs/pvs/${VOLUME} 10.10.10.0/24(rw,sync,all_squash)" >> /etc/exports
done
mount -a
for VOLUME in pv{1..10}
do
  chown nfsnobody:nfsnobody /export/nfs/pvs/${VOLUME}
  chmod 700  /export/nfs/pvs/${VOLUME}
done
systemctl restart nfs
exportfs -a

VG=rhel
LVSIZE=1g
VOLUME=registryvol
lvcreate -L${LVSIZE} -nlv_${VOLUME} $VG
mkfs.xfs -f /dev/mapper/${VG}-lv_${VOLUME}
mkdir -p /export/nfs/pvs/${VOLUME}
echo "/dev/mapper/${VG}-lv_${VOLUME} /export/nfs/pvs/${VOLUME} xfs defaults 0 0" >> /etc/fstab
echo "/export/nfs/pvs/${VOLUME} *(rw,sync,all_squash)" >> /etc/exports
mount /export/nfs/pvs/${VOLUME}
chown nfsnobody:nfsnobody /export/nfs/pvs/${VOLUME}
chmod 700  /export/nfs/pvs/${VOLUME}
systemctl restart nfs

