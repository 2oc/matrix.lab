#!/bin/bash
# Register to Satellite (else RHN using rhn_register, etc...)
[ -f ./bootstrap.sh ] || wget http://rh6sat5.matrix.private/pub/bootstrap/bootstrap.sh
sh ./bootstrap.sh

# Extra step to register clients to IDM hosts (I *think* this is now solid)
yum -y install ipa-client
#--server=rh7idm01.matrix.private
# DO not use single-quotes around value, they get passed in to the ipa-client command
IPA_OPTIONS="
--domain=matrix.private
--realm=MATRIX.LAB
--principal=admin
--password=Passw0rd
--mkhomedir 
--enable-dns-updates
--unattended"
ipa-client-install $IPA_OPTIONS

# Update hosts file in case DNS is unavailable
cat << EOF >> /etc/hosts
10.10.10.103 rh6storage01.matrix.private rh6storage01
10.10.10.104 rh6storage02.matrix.private rh6storage02
10.10.10.105 rh6storage03.matrix.private rh6storage03
10.10.10.106 rh6storage04.matrix.private rh6storage04
10.10.10.107 rh6storage.matrix.private rh6storage
EOF

tuned-adm profile rhs-high-throughput

# *****************************************************
# CREATE VG FOR BRICKS
# *****************************************************
parted -s /dev/vdb mklabel gpt mkpart ext3 2048s 100% set 1 lvm on
pvcreate /dev/vdb1
vgcreate vg_bricks /dev/vdb1

# *****************************************************
###   CREATE BRICK(S) ON EACH NODE
# *****************************************************
for BRICKID in 11 21 31 41 
do 
  BRICKNAME=BRICK${BRICKID}
  lvcreate -L2G -n${BRICKNAME} vg_bricks
  mkfs.xfs -i size=512 -n size 8192 -d su=128k /dev/vg_bricks/${BRICKNAME}
  #mkfs.xfs -i size=512 /dev/vg_bricks/${BRICKNAME}
done

mkdir -p /data/glusterfs/{gvol_distributed,gvol_replicated,gvol_striped,gvol_distrep}
mkdir /data/glusterfs/gvol_distributed/BRICK11 /data/glusterfs/gvol_replicated/BRICK21 /data/glusterfs/gvol_striped/BRICK31 /data/glusterfs/gvol_distrep/BRICK41

echo "/dev/vg_bricks/BRICK11 /data/glusterfs/gvol_distributed/BRICK11 xfs defaults 0 2" >> /etc/fstab
echo "/dev/vg_bricks/BRICK21 /data/glusterfs/gvol_replicated/BRICK21 xfs defaults 0 2" >> /etc/fstab
echo "/dev/vg_bricks/BRICK31 /data/glusterfs/gvol_striped/BRICK31 xfs defaults 0 2" >> /etc/fstab
echo "/dev/vg_bricks/BRICK41 /data/glusterfs/gvol_distrep/BRICK41 xfs defaults 0 2" >> /etc/fstab
mount -a
mkdir -p /data/glusterfs/gvol_{distributed,replicated,striped,distrep}/BRICK*/anchor

case `hostname -s` in 
  rh6storage01)
    for HOST in 01 02 03 04
    do 
      gluster peer probe rh6storage${HOST}.matrix.private
    done
  ;;
esac

shutdown now -r

# If you mess up...
exit 0
setfattr -x trusted.glusterfs.volume-id brick
setfattr -x trusted.gfid brick
