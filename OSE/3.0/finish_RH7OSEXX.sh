#!/bin/bash

#### THIS IS CLOSE TO BEING DONE, BUT - IF YOU HAPPEN TO USE THIS
####  RUN THE STEPS MANUALLYA
####  I execute this script on a single node, one of the masters.  RH7OSEMST01 to be exact.
####   Technically, the ansible playbook can be run anywhere and pointed at the nodes.

HAMSTR=1
OSEVERSION=3.1

DOMAIN=`hostname -d`
case $DOMAIN in 
  'matrix.lab')
    WEBREPO=10.10.10.10
  ;;
  'aperture.lab')
    WEBREPO=192.168.122.1
  ;;
  *)
    echo "ERROR: Domain not recognized foo..."
    echo "   [can|should] not proceed."
    exit 9
  ;;
esac

cat << EOF > hosts
rh7osemst.${DOMAIN}
rh7osemst01.${DOMAIN}
rh7osemst02.${DOMAIN}
rh7osetcd01.${DOMAIN}
rh7osetcd02.${DOMAIN}
rh7osetcd03.${DOMAIN}
rh7osenod01.${DOMAIN}
rh7osenod02.${DOMAIN}
EOF

# Passw0rd
# Distribute Keys to ALL the OSe nodes (master, nodes, routers)
if [ ! -f ~/.ssh/id_rsa.pub ]; then echo | ssh-keygen -trsa -b2048 -N ''; fi
# Passw0rd
for HOST in `cat ~/hosts`
do
  ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no $HOST
done
for HOST in `cat ~/hosts`
do
  ssh $HOST "hostname; uptime"
done

# CONFIGURE REPO(S) 
for HOST in `cat hosts` 
do  
  echo "Configuring: $HOST"
  ssh $HOST bash -c "' subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-${OSEVERSION}-rpms 
'"
done

# THIS SHOULD ONLY RUN ON THE MASTER
yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc
yum -y install docker 
#  Uncomment the following if you do NOT intend on having a secure registry
#sed -i -e "s/OPTIONS='--selinux-enabled'/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker
#  Add EPEL 
yum repolist | grep -i epel
case $? in 
  0)
    echo "NOTE:  EPEL is already present"
  ;;
  *)
    POOLID=`subscription-manager list --available --all | awk '/EPEL/ {flag=1;next} /Available:/{flag=0} flag {print}' | grep ^Pool | awk '{ print $3 }'`
    if [ -z ${POOLID} ]
    then
      echo "NOTE:  Installing external EPEL"
      yum -y install http://mirror.sfo12.us.leaseweb.net/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    else 
      subscription-manager subscribe --pool=${POOLID}
      subscription-manager repos --enable='${ORGANIZATION}_Extra_Packages_for_Enterprise_Linux_EPEL_7_-_x86_64'
    fi
  ;;
esac
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
    wget ${WEBREPO}/OSE/ose-single_master-multi_etcd-${OSEVERSION}.txt -O /etc/ansible/hosts
  ;;
  *)
    echo "# NOTE:  Building OSE using multiple master"
    wget ${WEBREPO}/OSE/ose-multi_master-multi_etcd-${OSEVERSION}.txt -O /etc/ansible/hosts
    # 3.0 needs pacemaker (from the HA channel)
    case $OSEVERSION in
      3.0)
        for HOST in `grep -i rh7osemst ~/hosts`; do ssh $HOST "subscription-manager repos --enable=rhel-ha-for-rhel-7-server-rpms"; done
      ;;
     esac
  ;;
esac 
cat << EOF > ~/.ansible.cfg
[defaults] 
log_path=~/.ansible.log
EOF

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
systemctl restart openshift-master

sed -i -e "s/subdomain:  \"\"/subdomain:  \"cloudapps.${DOMAIN}\"/g" /etc/openshift/master/master-config.yaml
systemctl restart openshift-master

HOSTLIST="rh7oseinf01 rh7oseinf02 rh7osenod01 rh7osenod02"
for NODE in $HOSTLIST; do ssh $NODE "setsebool -P virt_use_nfs=true"; done

exit 0

### VERY TEMPORARY WORK-AROUND
wget https://raw.githubusercontent.com/rhtconsulting/rhc-ose/openshift-enterprise-3/provisioning/templates/image-streams-rhel7-ose3_0_2.json -O /root/openshift-ansible/roles/openshift_examples/files/examples/image-streams/image-streams-rhel7-ose3_0_2.json
oc delete imagestreams --all -n openshift
oc create -n openshift -f /root/openshift-ansible/roles/openshift_examples/files/examples/image-streams/image-streams-rhel7-ose3_0_2.json
oc create -n openshift -f /usr/share/openshift/examples/xpaas-streams/jboss-image-streams.json


### SATELLITE 6 INTEGRATION (Work in Progress 20151103)
curl http://rh7sat6.aperture.lab/pub/katello-server-ca.crt -O /etc/pki/ca-trust/source/anchors/katello-server-ca.crt
update-ca-trust

curl -X GET https://rh7sat6.aperture.lab:5000/v1/search?q=rhel7
curl -X GET https://rh7sat6.aperture.lab:5000/v1/search?q=latest

exit 0

###########

### DNS ZONE ON RHIDM
update_dns() {
ssh rh7idm01
kinit admin
ipa dnszone-add cloudapps.aperture.lab --admin-email=root@aperture.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add cloudapps.aperture.lab '*' --a-rec 192.168.122.135
ipa dnsrecord-add cloudapps.aperture.lab '*' --a-rec 192.168.122.136
ipa dnszone-mod --allow-transfer='192.168.122.0/24;127.0.0.1' aperture.lab

}

# [root@rh6ns01 ~]# host -l matrix.lab | grep -v rh7idm | sed 's/.matrix.lab//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add matrix.lab "$1" --a-rec "$4 }'
# [root@rh6ns01 ~]# host -l matrix.lab | egrep -v 'rh7idm|^mat' | sort -k4 | sed 's/10.10.10.//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add 10.10.10.in-addr.arpa "$4" --ptr-rec "$1"." }'

