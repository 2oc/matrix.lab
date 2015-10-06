systemctl stop NetworkManager
systemctl disable $_
sed -i -e 's/ONBOOT=no/ONBOOT=yes/g' /etc/sysconfig/network-scripts/ifcfg-enp0s25

subscription-manager register --auto-attach --username=${RHNUSER} --password='RHNPASSWD'

subscription-manager repos --disable "*"
uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager release --set=$RELEASE
subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-rhev-mgmt-agent-rpms

