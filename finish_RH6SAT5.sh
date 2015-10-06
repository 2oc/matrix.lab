

echo "`hostname -i` `hostname` `hostname -s`" >> /etc/hosts

rhnreg_ks --username="${RHNUSER}" --password='${RHNPASSWD}' || exit 9

cp /etc/sysconfig/iptables /etc/sysconfig/iptables.bak
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 69 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m udp -p udp --dport 69 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 4545 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 5222 -j ACCEPT
iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 5269 -j ACCEPT
#iptables --insert INPUT 5 -m state --state NEW -m tcp -p tcp --dport 9055 -j ACCEPT # Oracle XE
service iptables save

wget -O /root/answers.txt http://10.10.10.10/MISC/RH6SAT5-answers.txt
wget -O /root/RH6SAT5.xml http://10.10.10.10/MISC/RH6SAT5.xml
if [ ! -f /root/answers.txt ]; then echo "ERROR:  need answers.txt"; exit 9; fi
if [ ! -f /root/RH6SAT5.xml ]; then echo "ERROR:  need RH6SAT5.xml"; exit 9; fi

if [ ! -f /mnt/install.pl ]; then echo "ERROR:  need RH6SAT5.xml"; exit 9; fi

scp 10.10.10.10:/var/lib/libvirt/images-tier2/satellite-5.7.0-20150108-rhel-6-x86_64.iso /tmp

#mount /dev/cdrom /mnt
mount -oloop,ro /tmp/satellite-5.7.0-20150108-rhel-6-x86_64.iso /mnt
if [ $? -ne 0 ]; then echo "ERROR: you may need to manually mount the install media"; exit 9; fi

lvcreate -npgsql_tmp -L14g vg_satellite
mkfs.ext4 /dev/vg_satellite/pgsql_tmp
mkdir /var/lib/pgsql 
mount /dev/vg_satellite/pgsql_tmp /var/lib/pgsql
chown postgres:postgres /var/lib/pgsql
restorecon -Rv /var/lib/pgsql

cd /mnt
./install.pl --answer-file=/root/answers.txt

umount /var/lib/pgsql
lvremove /dev/vg_satellite/pgsql_tmp

satellite-sync -c rhel-x86_64-server-6 -c rhel-x86_64-server-6-thirdparty-oracle-java -c rhel-x86_64-server-extras-6 -c rhel-x86_64-server-supplementary-6 -c rhn-tools-rhel-x86_64-server-6 -c rhel-x86_64-server-7 -c rhel-x86_64-server-supplementary-7 -c rhn-tools-rhel-x86_64-server-7 -c rhel-x86_64-server-7-thirdparty-oracle-java

# Additional Channels for Red Hat Storage (and RHS Console)
satellite-sync -c rhel-x86_64-server-6-rhs-3 -c rhel-x86_64-server-sfs-6 -c rhel-x86_64-server-6-rhs-nagios-3 -c jbappplatform-6-x86_64-server-6-rpm -c rhel-x86_64-server-6-rhs-rhsc-3

# Additional Channels for Red Hat Enterprise Virtualization
satellite-sync -c rhel-x86_64-server-6-rhevm-3.5 -c rhel-x86_64-rhev-agent-6-server -c rhel-x86_64-rhev-mgmt-agent-6 
