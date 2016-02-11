#!/bin/bash

#### THIS IS CLOSE TO BEING DONE, BUT - IF YOU HAPPEN TO USE THIS
####   RUN THE STEPS MANUALLY
#### Technically, the ansible playbook can be run anywhere and pointed at the nodes.
#### I have found that you should likely run this from a RHEL host which has access 
####   to the OSE channels

#### NOTE:  You need to configure your ~/.ssh/config file as follows 
# Host rh7ose*  RH7OSE*
#     user root

HAMSTR=1
OSEVERSION=3.1

case `lsb_release -i | awk '{ print $3 }'` in 
  Fedora)
    YUMCOMMAND="sudo dnf"
  ;;
  *)
    YUMCOMMAND="sudo yum"
  ;;
esac
    
while getopts d: OPT
do  
  case $OPT in
    d)
       DOMAIN=$OPTARG
    ;;
    \?)
      echo -e \\n"Option $OPT not allowed"
    ;;
  esac
done
shift $((OPTIND-1)) 

if [ -z $DOMAIN ]; then DOMAIN=`hostname -d`; fi

echo "DOMAIN: $DOMAIN"

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

# Passw0rd
# Distribute Keys to ALL the OSe nodes (master, nodes, routers)
#if [ ! -f ~/.ssh/id_rsa.pub ]; then echo | ssh-keygen -trsa -b2048 -N ''; fi
rm ~/.ssh/known_hosts-lab
for HOST in `cat ./hosts`
do
  ssh-copy-id -i ~/.ssh/id_rsa -oStrictHostKeyChecking=no $HOST
done
for HOST in `cat ./hosts`
do
  ssh -q $HOST "hostname; uptime"
done
for HOST in `cat hosts`
do
  echo "Configuring: $HOST"
  ssh $HOST "sh ./post_install.sh"
done
for HOST in `cat hosts`
do
  echo "Configuring: $HOST"
  ssh $HOST "yum -y update; shutdown now -r"
done

# CONFIGURE REPO(S) 
for HOST in `cat hosts` 
do  
  echo "# Configuring: $HOST"
  ssh $HOST bash -c "' subscription-manager repos --disable=* --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-${OSEVERSION}-rpms 
'"
  echo 
done

# The following will depend on whether you are running Fedora or RHEL (I assume)
# code this to figure out what you are running, what command to run and what packages it needs
$YUMCOMMAND -y install wget git net-tools python-virtualenv gcc ansible

for HOST in `cat hosts` 
do  
  echo "# Configuring: $HOST"
  ssh $HOST "yum -y install net-tools bind-utils iptables-services bridge-utils python-virtualenv" 
done 

#  Uncomment the following if you intend on having an insecure registry
#sed -i -e "s/OPTIONS='--selinux-enabled'/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker
#  Add EPEL 
$YUMCOMMAND repolist | grep -i epel
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
for HOST in `egrep -i 'oseinf|osenod|osemst' hosts`
do 
    echo "########## ############### ###############"
    ssh ${HOST} "yum -y install docker"
    scp /tmp/etc_sysconfig_docker-storage-setup ${HOST}:/etc/sysconfig/docker-storage-setup
    scp /tmp/my-docker-storage-setup ${HOST}:my-docker-storage-setup
    ssh ${HOST} "sh ./my-docker-storage-setup"
    echo
done
for HOST in `egrep -i 'oseinf|osenod|osemst' hosts`
do
  ssh -q ${HOST} "hostname; systemctl status docker | grep 'docker.service' -A3" 
  #ssh ${HOST} "hostname; docker info"
  echo "# *****************************"
done

# Since host keys seemed to hose people up
if [ -f ~/.ssh/config ]; then cp ~/.ssh/config ~/.ssh/config-`date +%F`; fi
cat << EOF >> ~/.ssh/config
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
#  If your host is sub'd to the OSE channels - otherwise, you need to get them using
#     [root@rh7osemst01 tmp]# yum -y install --downloadonly --downloaddir=/var/tmp/ atomic-openshift-utils
#     
$YUMCOMMAND -y install atomic-openshift-utils 
$YUMCOMMAND -y install ansible
mv /etc/ansible/hosts /etc/ansible/hosts.orig

# Update /etc/ansible/hosts with the appropriate topology 
cd /usr/share/ansible/openshift-ansible
PATH_TO_INVENTORY_FILE=./ansible_hosts
ansible-playbook ./playbooks/byo/config.yml -i ${PATH_TO_INVENTORY_FILE}

######## METHOD 3.b #############
# sudo mkdir /home/Projects/; cd $_
# sudo chown `whoami` /home/Projects
# git clone https://github.com/openshift/openshift-ansible
# cd openshift-ansible
# for HOST in `grep -i rh7osemst ~/hosts`; do ssh $HOST "subscription-manager repos --enable=rhel-ha-for-rhel-7-server-rpms"; done
fi [ ! -f ${PATH_TO_INVENTORY_FILE} ]; then echo "Ansible Hosts file not found"; exit 9; fi

# ansible-playbook ./playbooks/byo/config.yml -i ${PATH_TO_INVENTORY_FILE}

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
ipa dnszone-mod --allow-transfer='10.10.10.0/24;127.0.0.1' cloudapps.matrix.lab
}

# This is to expose my lab to the real world...
IPADDR=`curl http://checkip.dyndns.org | cut -f2 -d\: |cut -f1 -d\< |sed 's/ //g'`
ipa dnszone-add linuxrevolution.com --admin-email=root@linuxrevolution.com --minimum=3000 
ipa dnsrecord-add linuxrevolution.com '*' --a-rec $IPADDR
ipa dnszone-add cloudapps.linuxrevolution.com --admin-email=root@linuxrevolution.com --minimum=3000 
ipa dnsrecord-add cloudapps.linuxrevolution.com '*' --a-rec $IPADDR

# [root@rh6ns01 ~]# host -l matrix.lab | grep -v rh7idm | sed 's/.matrix.lab//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add matrix.lab "$1" --a-rec "$4 }'
# [root@rh6ns01 ~]# host -l matrix.lab | egrep -v 'rh7idm|^mat' | sort -k4 | sed 's/10.10.10.//g' | grep -v dhcp | awk '{ print "ipa dnsrecord-add 10.10.10.in-addr.arpa "$4" --ptr-rec "$1"." }'

