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

# CONFIGURE REPO(S) 
for HOST in `cat hosts`; do  
ssh $HOST bash -c "' subscription-manager repos --disable=*; subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.0-rpms 
'"
done

# THIS SHOULD ONLY RUN ON THE MASTER
yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc
yum -y install docker 
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
MASTERS=`grep rh7osemst hosts`
case $HAMSTR in
  0|no)
    echo "# NOTE:  Building OSE using a single master"
    wget ${WEBREPO}/OSE/ose-single_master-multi_etcd.txt -O /etc/ansible/hosts
  ;;
  *)
    echo "# NOTE:  Building OSE using multiple master"
    wget ${WEBREPO}/OSE/ose-multi_master-multi_etcd.txt -O /etc/ansible/hosts
    for HOST in `grep -i rh7osemst hosts`; do ssh $HOST "subscription-manager repos --enable=rhel-ha-for-rhel-7-server-rpms"; done
  ;;
esac 
cd; ansible-playbook ~/openshift-ansible/playbooks/byo/config.yml

# I believe this is not necessary...
case $HAMSTR in
  0|no)
    echo "# NOTE: Proceeding"
  ;;
  *) 
   oc manage-node `grep rh7osemst hosts` --schedulable=false
  ;;
esac  
   ###########################################################
#################### END OF METHOD 3 ############################
   ###########################################################
  ;;
esac
# rm config and put the original ssh config back (if there was one)
rm ~/.ssh/config && mv ~/.ssh/config-`date +%F` ~/.ssh/config 

# Configure Authentication (HTPASS) 
useradd oseuser
echo Passw0rd | passwd --stdin oseuser
echo "echo \"oc login -u \`whoami\` --insecure-skip-tls-verify --server=https://rh7osemst01.matrix.lab:8443\" " >> ~oseuser/.bashrc

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
for HOST in $HOSTLIST; do ssh $NODE "setsebool -P virt_use_nfs=true"; done

exit 0

###########33

### DNS ZONE ON RHIDM
update_dns() {
ssh rh7idm01
kinit admin
ipa dnszone-add cloudapps.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 10.10.10.135
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 10.10.10.136
}


# [root@rh6ns01 ~]# host -l matrix.lab | grep -v rh7idm | sed 's/.matrix.lab//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add matrix.lab "$1" --a-rec "$4 }'
# [root@rh6ns01 ~]# host -l matrix.lab | egrep -v 'rh7idm|^mat' | sort -k4 | sed 's/10.10.10.//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add 10.10.10.in-addr.arpa "$4" --ptr-rec "$1"." }'

ipa dnsrecord-add matrix.lab ciscoasa --a-rec 10.10.10.1
ipa dnsrecord-add matrix.lab rhel7a --a-rec 10.10.10.10
ipa dnsrecord-add matrix.lab rhel7b --a-rec 10.10.10.11
ipa dnsrecord-add matrix.lab rhel7c --a-rec 10.10.10.12
ipa dnsrecord-add matrix.lab rh7os6a --a-rec 10.10.10.20
ipa dnsrecord-add matrix.lab rh7os6b --a-rec 10.10.10.21
ipa dnsrecord-add matrix.lab rh7os6c --a-rec 10.10.10.22
ipa dnsrecord-add matrix.lab rh6ns01 --a-rec 10.10.10.99
ipa dnsrecord-add matrix.lab rh6sat5 --a-rec 10.10.10.100
ipa dnsrecord-add matrix.lab rh6sat6 --a-rec 10.10.10.101
ipa dnsrecord-add matrix.lab rh7sat6 --a-rec 10.10.10.102
ipa dnsrecord-add matrix.lab rh6rhsc --a-rec 10.10.10.109
ipa dnsrecord-add matrix.lab rh6storage --a-rec 10.10.10.110
ipa dnsrecord-add matrix.lab rh6storage01 --a-rec 10.10.10.111
ipa dnsrecord-add matrix.lab rh6storage02 --a-rec 10.10.10.112
ipa dnsrecord-add matrix.lab rh6storage03 --a-rec 10.10.10.113
ipa dnsrecord-add matrix.lab rh6storage04 --a-rec 10.10.10.114
ipa dnsrecord-add matrix.lab rh6rhevmgr --a-rec 10.10.10.125
ipa dnsrecord-add matrix.lab rh6rhevmgr --a-rec 10.10.10.125

ipa dnsrecord-add matrix.lab rh7osemst --a-rec 10.10.10.129
ipa dnsrecord-add matrix.lab rh7osemst01 --a-rec 10.10.10.130
ipa dnsrecord-add matrix.lab rh7osemst02 --a-rec 10.10.10.131
ipa dnsrecord-add matrix.lab rh7osetcd01 --a-rec 10.10.10.132
ipa dnsrecord-add matrix.lab rh7osetcd02 --a-rec 10.10.10.133
ipa dnsrecord-add matrix.lab rh7osetcd03 --a-rec 10.10.10.134
ipa dnsrecord-add matrix.lab rh7oseinf01 --a-rec 10.10.10.135
ipa dnsrecord-add matrix.lab rh7oseinf02 --a-rec 10.10.10.136
ipa dnsrecord-add matrix.lab rh7osenod01 --a-rec 10.10.10.137
ipa dnsrecord-add matrix.lab rh7osenod02 --a-rec 10.10.10.138
ipa dnsrecord-add matrix.lab rh6clnt01 --a-rec 10.10.10.201
ipa dnsrecord-add matrix.lab rh7clnt01 --a-rec 10.10.10.202
ipa dnsrecord-add matrix.lab rh6clnt11 --a-rec 10.10.10.203
ipa dnsrecord-add matrix.lab rh7clnt11 --a-rec 10.10.10.204
ipa dnsrecord-add 10.10.10.in-addr.arpa 1 --ptr-rec ciscoasa.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 10 --ptr-rec rhel7a.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 11 --ptr-rec rhel7b.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 12 --ptr-rec rhel7c.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 20 --ptr-rec rh7os6a.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 21 --ptr-rec rh7os6b.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 22 --ptr-rec rh7os6c.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 99 --ptr-rec rh6ns01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 100 --ptr-rec rh6sat5.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 101 --ptr-rec rh6sat6.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 102 --ptr-rec rh7sat6.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 109 --ptr-rec rh6rhsc.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 110 --ptr-rec rh6storage.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 111 --ptr-rec rh6storage01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 112 --ptr-rec rh6storage02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 113 --ptr-rec rh6storage03.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 114 --ptr-rec rh6storage04.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 125 --ptr-rec rh6rhevmgr.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 129 --ptr-rec rh7osemst.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 130 --ptr-rec rh7osemst01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 131 --ptr-rec rh7osemst02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 132 --ptr-rec rh7osetcd01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 133 --ptr-rec rh7osetcd02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 134 --ptr-rec rh7osetcd03.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 135 --ptr-rec rh7oseinf01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 136 --ptr-rec rh7oseinf02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 137 --ptr-rec rh7osenod01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 138 --ptr-rec rh7osenod02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 141 --ptr-rec rh7puppet01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 142 --ptr-rec rh7puppet02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 201 --ptr-rec rh6clnt01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 202 --ptr-rec rh7clnt01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 203 --ptr-rec rh6clnt11.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 204 --ptr-rec rh7clnt11.matrix.lab.
