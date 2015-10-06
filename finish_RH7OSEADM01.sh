
yum -y install rhevm-guest-agent-common rng-tools
yum -y update && shutdown now -r

# Setup Client DNS
sed -i -e '/DNS1/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e '/DNS2/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i -e '/DNS3/d' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS1=10.10.10.139" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS2=10.10.10.1" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS3=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0

# Update Firewall
DEFAULTZONE=`firewall-cmd --get-default-zone`
firewall-cmd --permanent --add-port=53/tcp --zone=${DEFAULTZONE}
firewall-cmd --permanent --add-service=dns --zone=${DEFAULTZONE}
firewall-cmd --reload


# Install BIND and configure it
yum -y install bind bind-utils bind-chroot
systemctl enable named-chroot
sed -i -e 's/127.0.0.1;/127.0.0.1; 10.10.10.139;/g' /etc/named.conf
sed -i -e 's/listen-on-v6/#listen-on-v6/g' /etc/named.conf
sed -i -e 's/dnssec-enable yes;/dnssec-enable no;/g' /etc/named.conf
sed -i -e 's/dnssec-validation yes;/dnssec-validation no;/g' /etc/named.conf
echo "`hostname -I` `hostname` `hostname -s`" >> /etc/hosts

mkdir /var/named/chroot/var/named/masters  && chgrp named /var/named/chroot/var/named/masters/ && chmod g+rwx /var/named/chroot/var/named/masters/
mkdir /var/named/chroot/var/named/data && chgrp named /var/named/chroot/var/named/data/ && chmod g+rwx /var/named/chroot/var/named/data/
mkdir /var/named/chroot/var/named/dynamic/ && chgrp named /var/named/chroot/var/named/dynamic/
touch /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run
chgrp named /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run
chmod 644 /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run
cp /var/named/named.localhost /var/named/named.ca /usr/share/doc/bind-9.?.?/sample/var/named/named.loopback /usr/share/doc/bind-9.?.?/sample/var/named/named.empty /var/named/chroot/var/named
chmod 0644 /var/named/chroot/var/named/named.*
chown -R root:named /var/named/chroot/var/named/masters
chmod g+w /var/named/chroot/var/named/dynamic/
chown named:named /var/named/chroot/var/named/dynamic/
find /var/named/chroot/var/named/data -type f -exec chmod 0664 {} \;
find /var/named/chroot/var/named/dynamic -type f -exec chmod 0664 {} \;
find /var/named/chroot/var/named/masters -type d -exec chmod 755 {} \; && find /var/named/chroot/var/named/masters -type f -exec chmod 644 {} \;
restorecon -RFvv /var/named/chroot/var/named

NAMEDCFG=/var/named/chroot/etc/named.conf
cp /etc/named.conf ${NAMEDCFG} && chgrp named ${NAMEDCFG}

if [ ! -f /etc/rndc.key ]
then
  echo "Run this in another window to create key: rngd -r /dev/urandom -o /dev/random -f"
  rndc-confgen -a -c /etc/rndc.key
  restorecon /etc/rndc.key
  chown root:named /etc/rndc.key
  chmod 0640 /etc/rndc.key

cat << EOF >> ${NAMEDCFG}
controls {
  inet 127.0.0.1 port 953
  allow { 127.0.0.1; 10.10.10.139; }
  keys { "rndc-key"; };
};
EOF

  echo "# RNDC KEY" >> ${NAMEDCFG}
  echo "include \"/etc/rndc.key\";" >> ${NAMEDCFG}
  echo  >> ${NAMEDCFG}
fi

MYLINENO=`grep -n managed-keys ${NAMEDCFG} | cut -f1 -d\:`
INSERT=$((MYLINENO+1))
sed -i -e "${INSERT}i\ \ \ \ \ \ \ \ forwarders { 10.10.10.121; 10.10.10.122; };" ${NAMEDCFG}
sed -i -e 's/localhost/any/g' ${NAMEDCFG}

cat << EOF >> ${NAMEDCFG}

# .LAB Zone Files
zone "cloudapps.matrix.lab" {
    type master;
    allow-transfer { 10.10.10.1/24; };
    file "masters/db.cloudapps.matrix.lab";
};
# .LAB Zone Files
zone "matrix.lab" {
    type forward;
    forwarders { 10.10.10.121; 10.10.10.122; };
};


EOF

cat << EOF > /var/named/chroot/var/named/masters/db.cloudapps.matrix.lab
\$TTL 86400
@       IN      SOA     master.cloudapps.matrix.lab. hostmaster.cloudapps.matrix.lab. (
                               2015031901      ; Serial
                               43200      ; Refresh
                               3600       ; Retry
                               3600000    ; Expire
                               2592000 )  ; Minimum
  		IN	NS master.cloudapps.matrix.lab.
\$ORIGIN cloudapps.matrix.lab.
; Specific Hosts here (probably not necessary)
master	IN	A	10.10.10.139
test 	IN	A 	10.10.10.135
; Followed by Wildcard
*	IN	A	10.10.10.135
*	IN	A	10.10.10.136

EOF

restorecon -Fvv /var/named/chroot/var/named/masters/db.cloudapps.matrix.lab
