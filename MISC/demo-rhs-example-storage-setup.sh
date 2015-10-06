# *****************************************************
# ONLY RUN THIS ON STORAGE01
###   DISTRIBUTED VOLUME - gvol_distributed
gluster volume create gvol_distributed \
  rh6storage01.matrix.private:/data/glusterfs/gvol_distributed/BRICK11/anchor \
  rh6storage02.matrix.private:/data/glusterfs/gvol_distributed/BRICK11/anchor \
  rh6storage03.matrix.private:/data/glusterfs/gvol_distributed/BRICK11/anchor \
  rh6storage04.matrix.private:/data/glusterfs/gvol_distributed/BRICK11/anchor
gluster volume start gvol_distributed

###   REPLICATED VOLUME - gvol_replicated
gluster volume create gvol_replicated replica 4 \
  rh6storage01.matrix.private:/data/glusterfs/gvol_replicated/BRICK21/anchor \
  rh6storage02.matrix.private:/data/glusterfs/gvol_replicated/BRICK21/anchor \
  rh6storage03.matrix.private:/data/glusterfs/gvol_replicated/BRICK21/anchor \
  rh6storage04.matrix.private:/data/glusterfs/gvol_replicated/BRICK21/anchor
gluster volume start gvol_replicated

###   STRIPED VOLUME - gvol_striped
gluster volume create gvol_striped stripe 4 \
  rh6storage01.matrix.private:/data/glusterfs/gvol_striped/BRICK31/anchor \
  rh6storage02.matrix.private:/data/glusterfs/gvol_striped/BRICK31/anchor \
  rh6storage03.matrix.private:/data/glusterfs/gvol_striped/BRICK31/anchor \
  rh6storage04.matrix.private:/data/glusterfs/gvol_striped/BRICK31/anchor
gluster volume start gvol_striped

###    DISTRIBUTED REPLICATION
#       NOTE:   It turns out *this* actually is a distrep setup (4 bricks, 2 replica)
gluster volume create gvol_distrep replica 2 \
  rh6storage01.matrix.private:/data/glusterfs/gvol_distrep/BRICK41/anchor \
  rh6storage02.matrix.private:/data/glusterfs/gvol_distrep/BRICK41/anchor \
  rh6storage03.matrix.private:/data/glusterfs/gvol_distrep/BRICK41/anchor \
  rh6storage04.matrix.private:/data/glusterfs/gvol_distrep/BRICK41/anchor
gluster volume start gvol_distrep


# *****************************************************
###   GLUSTER VOLUME OPTIONS
# *****************************************************
for VOL in distributed striped replicated
do
  gluster volume set gvol_$VOL auth.allow "192.168.122.*"
done

# RUN THIS ON A CLIENT
yum -y install glusterfs-fuse
for FS in `showmount -e rh6storage01 | grep \/ | awk '{ print $1 }'`
do
  mkdir -p /gluster${FS}
  echo "rh6storage01:${FS} /gluster${FS} glusterfs _netdev,backupvolfile-server=rh6storage02 0 0" >> /etc/fstab
  mount /gluster${FS}
  dd if=/dev/zero of=/gluster${FS}/test-dd.img bs=512 count=204800
done

#volume add-brick <VOLNAME> [<stripe|replica> <COUNT>] <NEW-BRICK> ... [force] - add brick to volume <VOLNAME>

####>>>.... LATER DURING THE SHOW....
# *****************************************************
# Adding a brick
# *****************************************************
echo "/dev/vg_bricks/BRICK41 /data/glusterfs/gvol_replicated/BRICK41 xfs defaults 0 2" >> /etc/fstab
mkdir /data/glusterfs/gvol_replicated/BRICK41

gluster volume create ctdbmeta replica 4 \
  rh6storage01.matrix.private:/data/glusterfs/ctdbbrick1/anchor \
  rh6storage02.matrix.private:/data/glusterfs/ctdbbrick1/anchor \
  rh6storage03.matrix.private:/data/glusterfs/ctdbbrick1/anchor \
  rh6storage04.matrix.private:/data/glusterfs/ctdbbrick1/anchor

sed -i 's/^META="all"/META="ctdbmeta"/' /var/lib/glusterd/hooks/1/start/post/S29CTDBsetup.sh
sed -i 's/^META="all"/META="ctdbmeta"/' /var/lib/glusterd/hooks/1/stop/pre/S29CTDB-teardown.sh

# ONLY RUN THIS ON ONE NODE
cat << EOF >>  /gluster/lock/ctdb
CTDB_RECOVERY_LOCK=/gluster/lock/lockfile
CTDB_PUBLIC_ADDRESSES=/etc/ctdb/public_addresses
CTDB_MANAGES_SAMBA=yes
CTDB_NODES=/etc/ctdb/nodes
EOF

mv /etc/sysconfig/ctdb{,.bak}
ln -s /gluster/lock/ctdb /etc/sysconfig/ctdb
for IP in 192.168.122.{103,104,105,106}; do echo $IP >> /gluster/lock/nodes; done
echo "192.168.122.107/24 eth0" >> /gluster/lock/public_addresses
mkdir /etc/ctdb
ln -s /gluster/lock/public_addresses /etc/ctdb/public_addresses
ln -s /gluster/lock/nodes /etc/ctdb/

chkconfig smb off && service smb stop

# CLEAN UP A BOTCHED VOLUME CREATION
setfattr -x trusted.glusterfs.volume-id /data/glusterfs/gvol_distributed/BRICK11/anchor/
setfattr -x trusted.gfid /data/glusterfs/gvol_distributed/BRICK11/anchor
rm -rf /data/glusterfs/gvol_distributed/BRICK11/anchor/.glusterfs

