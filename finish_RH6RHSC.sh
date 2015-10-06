#!/bin/bash

sh ./bootstrap.sh || exit 0

cp /etc/sysconfig/iptables /etc/sysconfig/iptables.orig
for PORT in 80 443 88 464 389 636 54321
do 
  iptables --insert INPUT 5 -p tcp --dport ${PORT} -j ACCEPT
done

for PORT in 88 464  5432
do 
  iptables --insert INPUT 5 -p udp --dport ${PORT} -j ACCEPT
done
service iptables save

# The following user-administration should occur duing package install
#groupadd -g 36 kvm 
#groupadd -g 108 ovirt
#useradd -u36 -gkvm -Govirt -c "VDSM user" vdsm

rhn-channel -a -c rhel-x86_64-server-6-rhs-3 -c jbappplatform-6-x86_64-server-6-rpm -c rhel-x86_64-server-6-rhs-nagios-3 -c rhel-x86_64-server-6-rhs-rhsc-3 

satellite-sync -c rhel-x86_64-server-6-rhs-3 -c jb-eap-6-for-rhel-6-server-rpms -c rhs-nagios-3-for-rhel-6-server-rpms -c rhsc-3-for-rhel-6-server-rpms -c rhel-x86_64-server-6-rhs-rhsc-3

