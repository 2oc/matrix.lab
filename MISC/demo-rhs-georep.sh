wget http://rh6sat5.matrix.private/pub/bootstrap/bootstrap.sh
sh ./bootstrap.sh

cat << EOF >> /etc/hosts
192.168.122.103 rh6storage01.matrix.private rh6storage01
192.168.122.104 rh6storage02.matrix.private rh6storage02
192.168.122.105 rh6storage03.matrix.private rh6storage03
192.168.122.106 rh6storage04.matrix.private rh6storage04
EOF

tuned-adm profile rhs-high-throughput
shutdown now -r

# Both nodes (master/slave)
parted -s /dev/vdb mklabel gpt mkpart ext3 2048s 100% set 1 lvm on
pvcreate /dev/vdb1
vgcreate vg_bricks /dev/vdb1

for BRICKID in 11 
do
  BRICKNAME=BRICK${BRICKID}
  lvcreate -L2G -n${BRICKNAME} vg_bricks
  mkfs.xfs -i size=512 /dev/vg_bricks/${BRICKNAME}
done

# 01 - master
mkdir -p /data/glusterfs/geomaster/BRICK11
echo "/dev/vg_bricks/BRICK11 /data/glusterfs/geomaster/BRICK11 xfs defaults 0 2" >> /etc/fstab
mount -a && mkdir /data/glusterfs/geomaster/BRICK11/anchor
gluster volume create geomaster rh6storage01.matrix.private:/data/glusterfs/geomaster/BRICK11/anchor

# 04 - slave
mkdir -p /data/glusterfs/geoslave/BRICK11
echo "/dev/vg_bricks/BRICK11 /data/glusterfs/geoslave/BRICK11 xfs defaults 0 2" >> /etc/fstab
mount -a && mkdir /data/glusterfs/geoslave/BRICK11/anchor
gluster volume create geoslave rh6storage04.matrix.private:/data/glusterfs/geoslave/BRICK11/anchor
gluster volume start geoslave 

# 01 - master
ssh-keygen -P '' -f /var/lib/glusterd/geo-replication/secret.pem
sed -i 's|^|command="/usr/libexec/glusterfs/gsyncd" |' /var/lib/glusterd/geo-replication/secret.pem.pub
chmod 0600 /var/lib/glusterd/geo-replication/secret.pem.pub

# 04 - slave
groupadd geogroup
useradd -G geogroup geouser
echo redhat | passwd --stdin geouser

# 01 - master
ssh-copy-id -i /var/lib/glusterd/geo-replication/secret.pem.pub geouser@rh6storage04.matrix.private
ssh -i /var/lib/glusterd/geo-replication/secret.pem geouser@rh6storage04.matrix.private

# 04 - slave
mkdir /var/mountbroker-root

#- Add this to /etc/glusterfs/glusterd.vol
sed -i -e '/end-volume/d' /etc/glusterfs/glusterd.vol
cat << EOF >> /etc/glusterfs/glusterd.vol
    option mountbroker-root /var/mountbroker-root
    option mountbroker-geo-replication.geouser geoslave
    option geo-replication-log-group geogroup
end-volume
EOF
gluster volume start geoslave
service glusterd restart

# 01 - master
gluster volume geo-replication geomaster geouser@rh6storage04.matrix.private::geoslave start

# ADDING A CHANGE
