#!/bin/bash

### WORKING ON MAKING THIS TO BE RUN FROM THE MASTER...
#### IT IS CLOSE TO BEING DONE, BUT - IF YOU HAPPEN TO USE THIS
####  RUN THE STEPS MANUALLY

###   NOTE  !!!! NOTE  !!!!!
###   NOTE  !!!! NOTE  !!!!!
###   NOTE  !!!! NOTE  !!!!!
#   This is not intended to simply be run on a single node... it's still in a form where pieces 
#     need to be selectively applied (i.e. some steps are run on the master, other on the nodes, other on both...)
DOMAIN=matrix.lab; WEBREPO=10.10.10.10
#DOMAIN=aperture.lab; WEBREPO=192.168.122.1
HAMSTR=0

cat << EOF > hosts
rh7osemst01.${DOMAIN}
rh7osemst02.${DOMAIN}
rh7osetcd01.${DOMAIN}
rh7osetcd02.${DOMAIN}
rh7osetcd03.${DOMAIN}
rh7oseinf01.${DOMAIN}
rh7oseinf02.${DOMAIN}
rh7osenod01.${DOMAIN}
rh7osenod02.${DOMAIN}
EOF

# Passw0rd
# Distribute Keys to ALL the OSe nodes (master, nodes, routers)
for HOST in `cat hosts`
do
  #if [ ! -f ~/.ssh/id_rsa.pub ]; then echo | ssh-keygen -trsa -b2048 -N''; fi
  ssh-copy-id -oStrictHostKeyChecking=no $HOST
done
for HOST in `cat hosts`
do
  ssh $HOST "uptime"
done

# CONFIGURE REPO(S) 
for HOST in `cat hosts` 
do  
  echo "Configuring: $HOST"
  ssh $HOST bash -c "' subscription-manager repos --disable=*; subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.0-rpms 
'"
done

# THIS SHOULD ONLY RUN ON THE MASTER
yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc
yum -y install docker 
#  DOUBLE-CHECK THE RESULTS OF THIS COMMAND....
sed -i -e "s/OPTIONS='--selinux-enabled'/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker
yum -y install http://mirror.sfo12.us.leaseweb.net/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum -y install ansible 

# Configure Docker storage (only on Docker nodes, obviously...)
# FIRST CREATE COMMAND FILES, THEN DISTRIBUTE THEM, THEN RUN THEM
cat << EOF > /tmp/etc_sysconfig_docker-storage-setup
# Docker-VG added by setup-script
DEVS=/dev/vdb
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
EOF
cat << EOF > /tmp/my-docker-storage-setup
if [ -b /dev/vdb ] 
then 
  /usr/bin/docker-storage-setup 
  systemctl stop docker
  rm -rf /var/lib/docker/*  
  systemctl start docker
  systemctl status docker
fi
EOF
for HOST in `egrep 'oseinf|osenod' hosts`
do
    ssh ${HOST} "yum -y install docker"
    scp /tmp/etc_sysconfig_docker-storage-setup ${HOST}:/etc/sysconfig/docker-storage-setup
    scp /tmp/my-docker-storage-setup ${HOST}:my-docker-storage-setup
    ssh ${HOST} "sh ./my-docker-storage-setup"
done

# Since host keys seemed to hose people up
if [ -f ~/.ssh/config ]; then mv ~/.ssh/config ~/.ssh/config-`date +%F`; fi
cat << EOF > ~/.ssh/config
host *
  StrictHostKeyChecking no
EOF

   ###########################################################
########################### METHOD 1 ############################
   ###########################################################
    # sh <(curl -s https://install.openshift.com/ose/)

   ###########################################################
########################### METHOD 2 ############################
   ###########################################################
   #curl -s https://install.openshift.com/ose/ > OSE-install-script.sh
   # ./OSE-install-script.sh

   ###########################################################
########################### METHOD 3 ############################
   ###########################################################
cd
git clone https://github.com/openshift/openshift-ansible
cd openshift-ansible
mv /etc/ansible/hosts /etc/ansible/hosts.orig
MASTERS=`grep rh7osemst ~/hosts`
case $HAMSTR in
  0|no)
    echo "# NOTE:  Building OSE using a single master"
    wget ${WEBREPO}/OSE/ose-single_master-multi_etcd.txt -O /etc/ansible/hosts
  ;;
  *)
    echo "# NOTE:  Building OSE using multiple master"
    wget ${WEBREPO}/OSE/ose-multi_master-multi_etcd.txt -O /etc/ansible/hosts
    for HOST in `grep -i rh7osemst ~/hosts`; do ssh $HOST "subscription-manager repos --enable=rhel-ha-for-rhel-7-server-rpms"; done
  ;;
esac 
cat << EOF > ./.ansible.cfg
[defaults] 
log_path=./installation.log
EOF
# See if this works (instead of cd ~; )
ansible-playbook ~/openshift-ansible/playbooks/byo/config.yml

# I believe this is not necessary...
case $HAMSTR in
  0|no)
    echo "# NOTE: Proceeding"
  ;;
  *) 
   oadm manage-node `grep rh7osemst hosts` --schedulable=false
  ;;
esac  
   ###########################################################
#################### END OF METHOD 3 ############################
   ###########################################################
  ;;
esac
# rm config and put the original ssh config back (if there was one)
rm -f ~/.ssh/config && mv ~/.ssh/config-`date +%F` ~/.ssh/config 

# Configure Authentication (HTPASS) 
useradd oseuser
echo Passw0rd | passwd --stdin oseuser
echo "echo \"oc login -u \`whoami\` -p 'Passw0rd' --insecure-skip-tls-verify --server=https://rh7osemst01.${DOMAIN}:8443\" " >> ~oseuser/.bashrc

cp /etc/openshift/master/master-config.yaml /etc/openshift/master/.master-config.yaml.orig
sed -i -e 's/name: deny_all/name: htpasswd_auth/g' /etc/openshift/master/master-config.yaml
sed -i -e 's/kind: DenyAllPasswordIdentityProvider/kind: HTPasswdPasswordIdentityProvider\n      file: \/etc\/openshift\/openshift-passwd/g' /etc/openshift/master/master-config.yaml
yum -y install httpd-tools
touch /etc/openshift/openshift-passwd
htpasswd -b /etc/openshift/openshift-passwd oseuser Passw0rd
htpasswd -b /etc/openshift/openshift-passwd admin Passw0rd
useradd admin && echo Passw0rd | passwd --stdin admin
systemctl restart openshift-master

HOSTLIST="rh7oseinf01 rh7oseinf02 rh7osenod01 rh7osenod02"
for NODE in $HOSTLIST; do ssh $NODE "setsebool -P virt_use_nfs=true"; done

exit 0

###########

### DNS ZONE ON RHIDM
update_dns() {
ssh rh7idm01
kinit admin
ipa dnszone-add cloudapps.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 10.10.10.135
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 10.10.10.136
ipa dnszone-mod --allow-transfer='10.10.10.0/24' cloudapps.matrix.lab
}


# [root@rh6ns01 ~]# host -l matrix.lab | grep -v rh7idm | sed 's/.matrix.lab//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add matrix.lab "$1" --a-rec "$4 }'
# [root@rh6ns01 ~]# host -l matrix.lab | egrep -v 'rh7idm|^mat' | sort -k4 | sed 's/10.10.10.//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add 10.10.10.in-addr.arpa "$4" --ptr-rec "$1"." }'

