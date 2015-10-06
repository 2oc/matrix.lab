#rhnreg_ks --username="${RHNUSER}" --password='${RHNPASSWD}'
wget 10.10.10.100/pub/bootstrap/bootstrap.sh
sh ./bootstrap.sh

sed -i -e '/DNS1/d' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS1=10.10.10.10" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS2=10.10.10.1" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS3=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0
shutdown now -r

cp /etc/sysconfig/iptables /etc/sysconfig/iptables.orig
iptables --insert INPUT 5 -p tcp --dport 53 -j ACCEPT
iptables --insert INPUT 5 -p udp --dport 53 -j ACCEPT
iptables --insert INPUT 5 -p tcp --dport 123 -j ACCEPT
iptables --insert INPUT 5 -p udp --dport 123 -j ACCEPT
service iptables save

for SVC in netfs nfslock postfix cups autofs; do chkconfig $SVC off; done
for SVC in ntpd; do chkconfig $SVC on; done
echo "`hostname -I` `hostname` `hostname -s`" >> /etc/hosts

yum -y install bind-chroot
mkdir /var/named/chroot/var/named/masters  && chgrp named /var/named/chroot/var/named/masters/ && chmod g+rwx /var/named/chroot/var/named/masters/
mkdir /var/named/chroot/var/named/data && chgrp named /var/named/chroot/var/named/data/ && chmod g+rwx /var/named/chroot/var/named/data/
mkdir /var/named/chroot/var/named/dynamic/ && chgrp named /var/named/chroot/var/named/dynamic/
touch /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run
chgrp named /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run
chmod 644 /var/named/chroot/var/named/dynamic/managed-keys.bind /var/named/chroot/var/named/data/cache_dump.db /var/named/chroot/var/named/data/named_stats.txt /var/named/chroot/var/named/data/named_mem_stats.txt /var/named/chroot/var/named/data/named.run

NAMEDCFG=/var/named/chroot/etc/named.conf
cp /etc/named.conf ${NAMEDCFG} && chgrp named ${NAMEDCFG}

if [ ! -f /etc/rndc.key ] 
then 
  rndc-confgen -a -c /etc/rndc.key
  restorecon /etc/rndc.key 
  chown root:named /etc/rndc.key
  chmod 0640 /etc/rndc.key 

cat << EOF >> ${NAMEDCFG}
controls {
  inet 127.0.0.1 port 953
  allow { 127.0.0.1; 10.10.10.10; }
  keys { "rndc-key"; };
}; 
EOF

  echo "# RNDC KEY" >> ${NAMEDCFG}
  echo "include \"/etc/rndc.key\";" >> ${NAMEDCFG}
  echo  >> ${NAMEDCFG}
fi

MYLINENO=`grep -n managed-keys ${NAMEDCFG} | cut -f1 -d\:`
INSERT=$((MYLINENO+1))
sed -i -e "${INSERT}i\ \ \ \ \ \ \ \ forwarders { 8.8.8.8; };" ${NAMEDCFG}
sed -i -e 's/127.0.0.1;/127.0.0.1; 10.10.10.1\/24;/g' ${NAMEDCFG}
sed -i -e 's/localhost/any/g' ${NAMEDCFG}

cat << EOF >> ${NAMEDCFG}

# .LAB Zone Files
zone "matrix.private" {
    type master;
    allow-transfer {10.10.10.1/24;};
    file "masters/db.matrix.private";
};
zone "10.10.10.in-addr.arpa" {
    type master;
    file "masters/db.10.10.10.in-addr.arpa";
};
EOF

cat << EOF > /var/named/chroot/var/named/masters/db.10.10.10.in-addr.arpa
\$TTL 2d  ; 172800 seconds
@             IN      SOA   ns1.matrix.private. hostmaster.matrix.private.  (
                              2015031901      ; Serial
                              3h         ; refresh
                              15m        ; update retry
                              3w         ; expiry
                              3h         ; nx = nxdomain ttl
                              )
              IN      NS      rh6ns01.matrix.private.
1             IN      PTR     router.matrix.private. 
10             IN      PTR     rh6ns01.matrix.private.
100 	IN PTR rh6sat5.matrix.private.
101 	IN PTR rh6sat6.matrix.private.
102 	IN PTR rh7sat6.matrix.private.
109 	IN PTR rh6rhsc.matrix.private.
110 	IN PTR rh6storage.matrix.private.
111 	IN PTR rh6storage01.matrix.private.
112 	IN PTR rh6storage02.matrix.private.
113 	IN PTR rh6storage03.matrix.private.
114 	IN PTR rh6storage04.matrix.private.
121 	IN PTR rh7idm01.matrix.private.
122 	IN PTR rh7idm02.matrix.private.
123 	IN PTR ms2k8ad11.matrix.private.
124 	IN PTR ms2k8ad12.matrix.private.
141 	IN PTR rh7puppet01.matrix.private.
142 	IN PTR rh7puppet02.matrix.private.
201 	IN PTR rh6clnt01.matrix.private.
201 	IN PTR rh7clnt01.matrix.private.
202 	IN PTR rh6clnt11.matrix.private.
203 	IN PTR rh7clnt11.matrix.private.
222             IN      PTR     dhcp-222.matrix.private.
223             IN      PTR     dhcp-223.matrix.private.
224             IN      PTR     dhcp-224.matrix.private.
225             IN      PTR     dhcp-225.matrix.private.
226             IN      PTR     dhcp-226.matrix.private.
227             IN      PTR     dhcp-227.matrix.private.
228             IN      PTR     dhcp-228.matrix.private.
229             IN      PTR     dhcp-229.matrix.private.
EOF
cat << EOF > /var/named/chroot/var/named/masters/db.matrix.private
\$TTL 86400
@       IN      SOA     matrix.private. hostmaster.matrix.private. (
                               2015031901      ; Serial
                               43200      ; Refresh
                               3600       ; Retry
                               3600000    ; Expire
                               2592000 )  ; Minimum
               IN      NS      rh6ns01.matrix.private.
               IN      A       10.10.10.10
\$ORIGIN matrix.private.

;       Define the nameservers and the mail servers
rh6ns01	 	IN	 A 10.10.10.10
rh6sat5	 	IN	 A 10.10.10.100
rh6sat6	 	IN	 A 10.10.10.101
rh7sat6	 	IN	 A 10.10.10.102
rh6rhsc	 	IN	 A 10.10.10.109
rh6storage	 IN	 A 10.10.10.110
rh6storage01	 IN	 A 10.10.10.111
rh6storage02	 IN	 A 10.10.10.112
rh6storage03	 IN	 A 10.10.10.113
rh6storage04	 IN	 A 10.10.10.114
rh7idm01	 IN	 A 10.10.10.121
rh7idm02	 IN	 A 10.10.10.122
ms2k8ad11	 IN	 A 10.10.10.123
ms2k8ad12	 IN	 A 10.10.10.124
rh7puppet01	 IN	 A 10.10.10.141
rh7puppet02	 IN	 A 10.10.10.142
rh6clnt01	 IN	 A 10.10.10.201
rh7clnt01	 IN	 A 10.10.10.201
rh6clnt11	 IN	 A 10.10.10.202
rh7clnt11	 IN	 A 10.10.10.203
dhcp-222		IN	A	10.10.10.222
dhcp-223		IN	A	10.10.10.223
dhcp-224		IN	A	10.10.10.224
dhcp-225		IN	A	10.10.10.225
dhcp-226		IN	A	10.10.10.226
dhcp-227		IN	A	10.10.10.227
dhcp-228		IN	A	10.10.10.228
dhcp-229		IN	A	10.10.10.229
EOF
cp /var/named/named.localhost /var/named/named.ca /usr/share/doc/bind-9.8.2/sample/var/named/named.loopback /usr/share/doc/bind-9.8.2/sample/var/named/named.empty /var/named/chroot/var/named
chmod 0644 /var/named/named.localhost /var/named/named.ca /usr/share/doc/bind-9.8.2/sample/var/named/named.loopback /usr/share/doc/bind-9.8.2/sample/var/named/named.empty /var/named/chroot/var/named/named.ca /var/named/chroot/var/named/named.localhost
chown -R root:named /var/named/chroot/var/named/masters
chgrp named /var/named/chroot/var/named/dynamic/*
find /var/named/chroot/var/named/data -type f -exec chmod 0664 {} \;
find /var/named/chroot/var/named/dynamic -type f -exec chmod 0664 {} \;
find /var/named/chroot/var/named/masters -type d -exec chmod 755 {} \; && find /var/named/chroot/var/named/masters -type f -exec chmod 644 {} \;
restorecon -RFvv /var/named/chroot/var/named
chkconfig named on
yum -y update
service named start
