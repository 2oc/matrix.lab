#!/bin/bash

tuned-adm profile virtual-guest
chkconfig tuned on
echo "`hostname -i` `hostname` `hostname -s` " >> /etc/hosts

subscription-manager register --auto-attach
subscription-manager repos --disable "*"

uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager repos --enable rhel-6-server-rpms --enable rhel-6-server-supplementary-rpms --enable rhel-6-server-rhevm-3.5-rpms --enable jb-eap-6-for-rhel-6-server-rpms
subscription-manager release --set=$RELEASE

TCP_PORTS="22 80 443 6100"
UDP_PORTS="7410"
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.bak
for PORT in $TCP_PORTS
do
  iptables --insert INPUT 5 -p tcp --dport $PORT -j ACCEPT
done
for PORT in $UDP_PORTS
do
  iptables --insert INPUT 5 -p udp --dport $PORT -j ACCEPT
done
service iptables save
service iptables restart

yum -y update && shutdown now -r
yum -y install rhevm

#engine-setup --generate-answer=/root/answer-file.txt
cat << EOF > /root/answer-file.txt
# action=setup
[environment:default]
OVESETUP_DIALOG/confirmSettings=bool:True
OVESETUP_CONFIG/applicationMode=str:both
OVESETUP_CONFIG/remoteEngineSetupStyle=none:None
OVESETUP_CONFIG/adminPassword=str:Passw0rd
OVESETUP_CONFIG/storageIsLocal=bool:False
OVESETUP_CONFIG/firewallManager=str:iptables
OVESETUP_CONFIG/remoteEngineHostRootPassword=none:None
OVESETUP_CONFIG/updateFirewall=bool:True
OVESETUP_CONFIG/remoteEngineHostSshPort=none:None
OVESETUP_CONFIG/fqdn=str:rh6rhevmgr.matrix.lab
OVESETUP_CONFIG/storageType=none:None
OSETUP_RPMDISTRO/requireRollback=none:None
OSETUP_RPMDISTRO/enableUpgrade=none:None
OVESETUP_DB/database=str:engine
OVESETUP_DB/fixDbViolations=none:None
OVESETUP_DB/secured=bool:False
OVESETUP_DB/host=str:localhost
OVESETUP_DB/user=str:engine
OVESETUP_DB/securedHostValidation=bool:False
OVESETUP_DB/port=int:5432
OVESETUP_ENGINE_CORE/enable=bool:True
OVESETUP_CORE/engineStop=none:None
OVESETUP_SYSTEM/memCheckEnabled=bool:True
OVESETUP_SYSTEM/nfsConfigEnabled=bool:True
OVESETUP_PKI/organization=str:matrix.lab
OVESETUP_CONFIG/isoDomainMountPoint=str:/var/lib/exports/iso/
OVESETUP_CONFIG/engineHeapMax=str:1024M
OVESETUP_CONFIG/isoDomainName=str:ISO_DOMAIN
OVESETUP_CONFIG/isoDomainACL=str:rh6rhevmgr.matrix.lab(rw)
OVESETUP_CONFIG/engineHeapMin=str:1024M
OVESETUP_AIO/configure=none:None
OVESETUP_AIO/storageDomainName=none:None
OVESETUP_AIO/storageDomainDir=none:None
OVESETUP_PROVISIONING/postgresProvisioningEnabled=bool:True
OVESETUP_APACHE/configureRootRedirection=bool:True
OVESETUP_APACHE/configureSsl=bool:True
OVESETUP_RHEVM_SUPPORT/redhatSupportProxyPort=none:None
OVESETUP_RHEVM_SUPPORT/redhatSupportProxy=none:None
OVESETUP_RHEVM_SUPPORT/redhatSupportProxyUser=none:None
OVESETUP_RHEVM_SUPPORT/configureRedhatSupportPlugin=bool:False
OVESETUP_RHEVM_SUPPORT/redhatSupportProxyPassword=none:None
OVESETUP_RHEVM_SUPPORT/redhatSupportProxyEnabled=bool:False
OVESETUP_RHEVM_DIALOG/confirmUpgrade=bool:True
OVESETUP_CONFIG/websocketProxyConfig=bool:True
OVESETUP_ENGINE_CONFIG/fqdn=str:rh6rhevmgr.matrix.lab
EOF

engine-setup --config-append=/root/answer-file.txt
