#sed -i -e 's/quiet/quiet  ipv6.disable=1/g' /etc/default/grub
#grub2-mkconfig -o /boot/grub2/grub.cfg

# DO NOT ADD /etc/puppetlabs AS A SEPARATE VOLUME, the installer does stuff
#  that depends on that directory
parted -s /dev/vdb mklabel gpt mkpart primary ext3 2048s 100% set 1 lvm on
pvcreate /dev/vdb1
vgcreate vg_apps /dev/vdb1

lvcreate -nlv_git -L1g vg_apps
#lvcreate -nlv_etc_puppetlabs -L2g vg_apps
lvcreate -nlv_opt_puppet -L4g vg_apps
lvcreate -nlv_var_log_pepuppet -L2g vg_apps
lvcreate -nlv_var_opt_pepuppet -L4g vg_apps

mkfs.xfs /dev/vg_apps/lv_git
#mkfs.xfs /dev/vg_apps/lv_etc_puppetlabs
mkfs.xfs /dev/vg_apps/lv_opt_puppet
mkfs.xfs /dev/vg_apps/lv_var_log_pepuppet
mkfs.xfs /dev/vg_apps/lv_var_opt_pepuppet

mkdir -p /var/lib/git /var/lib/puppet /opt/puppet /etc/puppetlabs /var/log/pe-puppet /var/opt/lib/pe-puppet
cat << EOF >> /etc/fstab
# Added for git and puppet
/dev/mapper/vg_apps-lv_git      	/var/lib/git    xfs     defaults        1 2
#/dev/mapper/vg_apps-lv_etc_puppetlabs 	/etc/puppetlabs     xfs     defaults        1 2
/dev/mapper/vg_apps-lv_opt_puppet       /opt/puppet     xfs     defaults        1 2
/dev/mapper/vg_apps-lv_var_log_pepuppet   /var/log/pe-puppet xfs     defaults        1 2
/dev/mapper/vg_apps-lv_var_opt_pepuppet   /var/opt/lib/pe-puppet xfs     defaults        1 2
EOF
mount -a
restorecon -RFvv /var/lib/git /var/lib/puppet /opt/puppet /etc/puppetlabs /var/log/pe-puppet /var/opt/lib/pe-puppet

echo "`hostname -i` `hostname` `hostname -s`" >> /etc/hosts

TCP_PORTS="80 443 4433 4435 8140 61613"
UDP_PORTS="443 8140"
DEFAULT_ZONE=`/bin/firewall-cmd --get-default-zone`
for PORT in $TCP_PORTS
do
  /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/tcp
done
for PORT in $UDP_PORTS
do
  /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/udp
done
/bin/firewall-cmd --reload
/bin/firewall-cmd --list-ports

PUPPETVERSION=3.8.0
PUPPETANSWER=all-in-one.answers.txt
mkdir /opt/build/ && cd /opt/build
wget http://rh6sat5.matrix.private/pub/SFW/PuppetEnterprise/puppet-enterprise-${PUPPETVERSION}-el-7-x86_64.tar.gz
tar -xvzf puppet-enterprise-${PUPPETVERSION}-el-7-x86_64.tar.gz
rm -f puppet-enterprise-${PUPPETVERSION}-el-7-x86_64.tar.gz
cd puppet-enterprise-${PUPPETVERSION}-el-7-x86_64
cp ./answers/all-in-one.answers.txt ${PUPPETANSWER}
sed -i -e 's/pe-puppet,pe-puppet.localdomain/puppet,puppet.matrix.private/g' ${PUPPETANSWER} 
sed -i -e 's/pe-puppet.localdomain/puppet.matrix.private/g' ${PUPPETANSWER}
sed -i -e 's/strongpassword2536/Passw0rd/g' ${PUPPETANSWER}
cat << EOF >> ${PUPPETANSWER}

# String - Whether or not to backup and purge old config
q_backup_and_purge_old_configuration=y
EOF
# Work-around with 3.7.1, possibly others...
mkdir /var/run/pe-puppet
./puppet-enterprise-installer -a /opt/build/puppet-enterprise-${PUPPETVERSION}-el-7-x86_64/${PUPPETANSWER}
cd -

yum -y install git

exit 0

systemctl stop pe-puppetserver

