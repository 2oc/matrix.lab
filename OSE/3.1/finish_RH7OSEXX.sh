#!/bin/bash

#### THIS IS CLOSE TO BEING DONE, BUT - IF YOU HAPPEN TO USE THIS
####   RUN THE STEPS MANUALLY
#### I execute this script on a single node, one of the masters.  RH7OSEMST01 to be exact.
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

# Update this according to your layout
cat << EOF > ./hosts
rh7osemst01.${DOMAIN}
rh7osemst02.${DOMAIN}
rh7osetcd01.${DOMAIN}
rh7osetcd02.${DOMAIN}
rh7osetcd03.${DOMAIN}
rh7oseinf01.${DOMAIN}
rh7oseinf02.${DOMAIN}
rh7osenod01.${DOMAIN}
rh7osenod02.${DOMAIN}
rh7osenod03.${DOMAIN}
rh7osenod04.${DOMAIN}
EOF

#host -l ${DOMAIN} | grep ose | awk  '{ print $4" "$1" "$1 }' | sed 's/.matrix.lab$//g' >> /etc/hosts

# Passw0rd
# Distribute Keys to ALL the OSe nodes (master, nodes, routers)
if [ ! -f ~/.ssh/id_rsa.pub ]; then echo | ssh-keygen -trsa -b2048 -N ''; fi
for HOST in `cat ./hosts`
do
  ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no $HOST
done
for HOST in `cat ./hosts`
do
  ssh $HOST "hostname; uptime"
done
for HOST in `cat hosts`
do
  echo "Configuring: $HOST"
  ssh $HOST "sh ./post_install.sh"
done

# CONFIGURE REPO(S) 
for HOST in `cat hosts` 
do  
  echo "# Configuring: $HOST"
  ssh $HOST bash -c "' subscription-manager repos --disable=* --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-${OSEVERSION}-rpms 
'"
  echo 
done

# THIS SHOULD ONLY RUN ON THE MASTER
# Temp work-around (there is a currently a version mismatch)
# yum -y install git-1.8.3.1-5.el7
yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc

#  Uncomment the following if you intend on having an insecure registry
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
yum -y install atomic-openshift-utils ansible

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
for HOST in `egrep 'oseinf|osenod|osemst' hosts`
do 
    echo "########## ############### ###############"
    ssh ${HOST} "yum -y install docker"
    scp /tmp/etc_sysconfig_docker-storage-setup ${HOST}:/etc/sysconfig/docker-storage-setup
    scp /tmp/my-docker-storage-setup ${HOST}:my-docker-storage-setup
    ssh ${HOST} "sh ./my-docker-storage-setup"
    echo
done
for HOST in `egrep 'oseinf|osenod|osemst' hosts`
do
  ssh ${HOST} "hostname; systemctl status docker | grep 'docker.service' -A3"
  #ssh ${HOST} "hostname; docker info"
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

cat << EOF > ~/.ansible.cfg
[defaults] 
log_path=~/.ansible.log
EOF

######## METHOD 3.a #############
#   you can either use the RPM included openshfit-ansible playbooks
#   Or, download them from github
mv /etc/ansible/hosts /etc/ansible/hosts.orig

# Update /etc/ansible/hosts with the appropriate topology 
cd /usr/share/ansible/openshift-ansible
ansible-playbook ./playbooks/byo/config.yml

######## METHOD 3.b #############
#cd
#git clone https://github.com/openshift/openshift-ansible
#cd openshift-ansible
#mv /etc/ansible/hosts /etc/ansible/hosts.orig
#for HOST in `grep -i rh7osemst ~/hosts`; do ssh $HOST "subscription-manager repos --enable=rhel-ha-for-rhel-7-server-rpms"; done
#ansible-playbook ~/openshift-ansible/playbooks/byo/config.yml

   ###########################################################
#################### END OF METHOD 3 ############################
   ###########################################################

# rm config and put the original ssh config back (if there was one)
rm -f ~/.ssh/config && mv ~/.ssh/config-`date +%F` ~/.ssh/config 

# Configure Authentication (HTPASS) - You need to run this on ALL masters
cat << EOF > add_http_auth.sh
DOMAIN=`hostname -d`
cp /etc/origin/master/master-config.yaml /etc/origin/master/.master-config.yaml.orig
sed -i -e 's/name: deny_all/name: htpasswd_auth/g' /etc/origin/master/master-config.yaml
sed -i -e 's/kind: DenyAllPasswordIdentityProvider/kind: HTPasswdPasswordIdentityProvider\n      file: \/etc\/origin\/openshift-passwd/g' /etc/origin/master/master-config.yaml
yum -y install httpd-tools
touch /etc/origin/openshift-passwd
useradd morpheus 
echo Passw0rd | passwd --stdin morpheus 

htpasswd -b /etc/origin/openshift-passwd morpheus Passw0rd

sed -i -e "s/subdomain:  \"\"/subdomain:  \"cloudapps.\${DOMAIN}\"/g" /etc/origin/master/master-config.yaml
systemctl restart atomic-openshift-master-api
EOF

for MASTER in `grep osemst hosts`
do 
  scp add_http_auth.sh ${MASTER}:
  ssh ${MASTER} "sh ./add_http_auth.sh"
done

echo "echo \"oc login -u \`whoami\` -p 'Passw0rd' --insecure-skip-tls-verify --server=https://openshift-cluster.${DOMAIN}:8443\" " >> ~morpheus/.bashrc

for NODE in  `cat hosts | egrep 'osemst|osenod|oseinf'`; do ssh $NODE "setsebool -P virt_use_nfs=true"; done

exit 0

### SATELLITE 6 INTEGRATION (Work in Progress 20151103)
curl http://rh7sat6.matrix.lab/pub/katello-server-ca.crt -O /etc/pki/ca-trust/source/anchors/katello-server-ca.crt
update-ca-trust

curl -X GET https://rh7sat6.matrix.lab:5000/v1/search?q=rhel7
curl -X GET https://rh7sat6.matrix.lab:5000/v1/search?q=latest

exit 0

###########

### DNS ZONE ON RHIDM
update_dns() {
ssh rh7idm01
kinit admin
ipa dnszone-add cloudapps.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 192.168.122.135
ipa dnsrecord-add cloudapps.matrix.lab '*' --a-rec 192.168.122.136
ipa dnszone-mod --allow-transfer='10.10.10.0/24;127.0.0.1' matrix.lab
}
# This is to expose my lab to the real world...
IPADDR=`curl http://checkip.dyndns.org | cut -f2 -d\: |cut -f1 -d\< |sed 's/ //g'`
ipa dnszone-add linuxrevolution.com --admin-email=root@linuxrevolution.com --minimum=3000 
ipa dnsrecord-add linuxrevolution.com '*' --a-rec $IPADDR
ipa dnszone-add cloudapps.linuxrevolution.com --admin-email=root@linuxrevolution.com --minimum=3000 
ipa dnsrecord-add cloudapps.linuxrevolution.com '*' --a-rec $IPADDR



# [root@rh6ns01 ~]# host -l matrix.lab | grep -v rh7idm | sed 's/.matrix.lab//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add matrix.lab "$1" --a-rec "$4 }'
# [root@rh6ns01 ~]# host -l matrix.lab | egrep -v 'rh7idm|^mat' | sort -k4 | sed 's/10.10.10.//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add 10.10.10.in-addr.arpa "$4" --ptr-rec "$1"." }'

