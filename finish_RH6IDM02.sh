#rhnreg_ks --username="${RHNUSER}" --password='${RHNPASSWD}'

cp /etc/sysconfig/iptables /etc/sysconfig/iptables.bak
for PORT in 80 443 389 636 88 464 53 123 7389
do
  iptables --insert INPUT 5 -p tcp --dport ${PORT} -j ACCEPT
done
for PORT in 88 464 53 123
do
  iptables --insert INPUT 5 -p udp --dport ${PORT} -j ACCEPT
done
service iptables save
service iptables restart

echo | ssh-keygen -trsa -b2048 -N ''
yum -y update && shutdown now -r

yum -y install ipa-server bind bind-dyndb-ldap

cat << EOF >> /etc/hosts
# IP/HOSTNAME/ALIAS for IdM Servers
10.10.10.10 rh6ns01.matrix.private rh6ns01
10.10.10.101	rh6idm01.matrix.private rh6idm01
10.10.10.102	rh6idm02.matrix.private rh6idm02
EOF

ssh-copy-id rh6idm01
ipa-replica-install --setup-ca --setup-dns --forwarder=10.10.10.10 /var/lib/ipa/replica-info-rh6idm02.matrix.private.gpg
