
## TO MY OWN SATELLITE ##
subscription-manager clean
wget http://rh7sat6.matrix.lab/pub/katello-ca-consumer-latest.noarch.rpm
yum -y localinstall katello-ca-consumer-latest.noarch.rpm
#subscription-manager register --org="MATRIXLABS" --activationkey="RH7OSE" --release=7.1

subscription-manager register --org="MATRIXLABS" --username='admin' --password='Passw0rd' --release=7.1 --auto-attach --force

subscription-manager release --set=7.1
#subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-ose-3.0-rpms --enable=rhel-7-server-optional-rpms
subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-extras-rpms --enable rhel-7-server-ose-3.0-rpms
#yum -y install python-virtualenv gcc libyaml
#


yum -y remove NetworkManager
yum -y install wget git net-tools bind-utils iptables-services bridge-utils python-virtualenv gcc
yum -y install docker
sed -i -e "s/OPTIONS='--selinux-enabled'/OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0\/16'/" /etc/sysconfig/docker

for HOST in rh7ose rh7ose01 rh7ose02
do
  ssh-copy-id $HOST
done

for HOST in rh7ose rh7ose01 rh7ose02
do
  ssh $HOST "hostname"
done

# I *believe* that the docker-storage-setup handles all this...
#parted -s /dev/vdb mklabel gpt mkpart primary ext3 2048s 100% set 1 lvm on
#partprobe /dev/vdb
case `hostname -s` in 
  rh7ose0*)
    echo "Configuring Storage"
if [ -b /dev/vdb ]
then
  echo "WTF"
cat << EOF >> /etc/sysconfig/docker-storage-setup
# Docker-VG added by script
DEVS=/dev/vdb
VG=docker-vg
EOF
fi
    docker-storage-setup
    systemctl stop docker
    rm -rf /var/lib/docker/*
    systemctl start docker
    systemctl status docker

  ;;
  *)
    echo "NOTE: nothing to do"
  ;;
esac
  
# Does this run on all (or one) systems?
case `hostname -s` in
  rh7ose)
    sh <(curl -s https://install.openshift.com/ose/)
  ;;
esac

#curl -s https://install.openshift.com/ose/ > OSE-install-script.sh

oadm registry --config=/etc/openshift/master/admin.kubeconfig \
    --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'
oc get pods
oc get rc
oc get nodes 
oc logs docker-registry-1-deploy

# Configure Authentication Bypass
cp /etc/openshift/master/master-config.yaml /etc/openshift/master/.master-config.yaml.orig

sed -i -e 's/deny_all/my_allow_provider/g' /etc/openshift/master/master-config.yaml
sed -i -e 's/DenyAllPasswordIdentityProvider/AllowAllPasswordIdentityProvider/g' /etc/openshift/master/master-config.yaml
sed -i -e 's/challenge: True/challenge: true/g' /etc/openshift/master/master-config.yaml
sed -i -e 's/login: True/login: true/g' /etc/openshift/master/master-config.yaml
systemctl restart openshift-master
# Login to Web UI and create a project named: matrixlab, then...
oc policy add-role-to-user admin admin -n matrixlab 


# MISC
oc create -f /usr/share/openshift/examples/image-streams/image-streams-rhel7.json -n openshift
oc create -f /usr/share/openshift/examples/db-templates -n openshift
oc create -f /usr/share/openshift/examples/quickstart-templates -n openshift

