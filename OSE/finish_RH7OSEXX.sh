#!/bin/bash

###   NOTE  !!!! NOTE  !!!!!
###   NOTE  !!!! NOTE  !!!!!
###   NOTE  !!!! NOTE  !!!!!
#   This is not intended to simply be run on a single node... it's still in a form where pieces 
#     need to be selectively applied (i.e. some steps are run on the master, other on the nodes, other on both...)


subscription-manager repos --disable=*
subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.0-rpms

yum -y remove NetworkManager
case `hostname -s` in 
  rh7osemst01)
    yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc
    yum -y install docker 
    sed -i -e "s/OPTIONS='--selinux-enabled'/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker
    yum -y install http://mirror.sfo12.us.leaseweb.net/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    yum -y install ansible 
  ;;
esac
Passw0rd
# Distribute Keys to ALL the OSe nodes (master, nodes, routers)
HOSTLIST="rh7osemst01 rh7osetcd01 rh7osetcd02 rh7osetcd03 rh7oseinf01 rh7oseinf02 rh7osenod01 rh7osenod02"
if [ ! -f ~/.ssh/id_rsa.pub ]; then echo | ssh-keygen -trsa -b2048 -N''; fi

for HOST in $HOSTLIST
do
  ssh-copy-id $HOST
done

# Register ALL nodes to MY Satellite (skip if using RHN)
for HOST in $HOSTLIST
do
  ssh $HOST "wget 192.168.122.1/register_node.sh"
  ssh $HOST "sh ./register_node.sh"
done

# Configure Docker storage
for HOST in rh7oseinf01 rh7oseinf02 rh7osenod01 rh7osenod02
do
    yum -y install docker
cat << EOF > /tmp/docker-storage-setup
# Docker-VG added by setup-script
DEVS=/dev/vdb
VG=docker-vg
SETUP_LVM_THIN_POOL=yes
EOF
    scp /tmp/docker-storage-setup ${HOST}:/etc/sysconfig/docker-storage-setup
    ssh ${HOST} "if [ -b /dev/vdb ]; then /usr/bin/docker-storage-setup; systemctl stop docker; rm -rf /var/lib/docker/*; systemctl start docker; systemctl status docker; fi"
done

case `hostname -s` in
  rh7ose)
   ###########################################################
########################### METHOD 1 ############################
   ###########################################################
    # Method 1
    sh <(curl -s https://install.openshift.com/ose/)

   ###########################################################
########################### METHOD 2 ############################
   ###########################################################
#curl -s https://install.openshift.com/ose/ > OSE-install-script.sh
# ./OSE-install-script.sh

# Method 3
   ###########################################################
########################### METHOD 3 ############################
   ###########################################################
# git clone https://github.com/openshift/openshift-ansible
# cd openshift-ansible
# mv /etc/ansible/hosts /etc/ansible/hosts.orig
cat << EOF > /etc/ansible/hosts
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes
etcd

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
ansible_ssh_user=root
product_type=openshift
deployment_type=enterprise

# uncomment the following to enable htpasswd authentication; defaults to DenyAllPasswordIdentityProvider
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]

# host group for masters
[masters]
rh7osemst01.aperture.lab

# host group for etcd
[etcd]
rh7osetcd01.aperture.lab
rh7osetcd02.aperture.lab
rh7osetcd03.aperture.lab

# host group for nodes, includes region info
[nodes]
rh7osemst01.aperture.lab openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
rh7oseinf01.aperture.lab openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
rh7oseinf02.aperture.lab openshift_node_labels="{'region': 'infra', 'zone': 'default'}"
rh7osenod01.aperture.lab openshift_node_labels="{'region': 'primary', 'zone': 'west'}"
rh7osenod02.aperture.lab openshift_node_labels="{'region': 'primary', 'zone': 'east'}"
EOF

# ansible-playbook ~/openshift-ansible/playbooks/byo/config.yml
   ###########################################################
#################### END OF METHOD 3 ############################
   ###########################################################
  ;;
esac

# Configure Authentication (HTPASS) 
useradd oseuser
echo Passw0rd | passwd --stdin oseuser
echo "echo \"oc login -u \`whoami\` --insecure-skip-tls-verify --server=https://rh7osemst01.aperture.lab:8443\" " >> ~oseuser/.bashrc

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
