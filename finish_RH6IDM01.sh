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

cat << EOF >> /etc/hosts
# IP/HOSTNAME/ALIAS for IdM Servers
10.10.10.10 rh6ns01.matrix.private rh6ns01
10.10.10.101 rh6idm01.matrix.private rh6idm01
10.10.10.102 rh6idm02.matrix.private rh6idm02
EOF

yum -y update && shutdown now -r

yum -y install ipa-server bind bind-dyndb-ldap

IPA_OPTIONS="
--realm=MATRIX.private
--domain=MATRIX.private
--ds-password=Passw0rd
--master-password=Passw0rd
--admin-password=Passw0rd
--hostname=rh6idm01.matrix.private
--ip-address=10.10.10.101
--no-ntp"

CERTIFICATE_OPTIONS="
--subject=
--selfsign"

echo "ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS"
ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS

echo "Configuring IPA to allow logins without a Kerberos ticket"
echo "/etc/httpd/conf.d/ipa.conf"
echo "sed -i -e 's/KrbMethodK5Passwd\ off/KrbMethodK5Passwd\ on/g' /etc/httpd/conf.d/ipa.conf"
echo "dig SRV _kerberos._tcp.matrix.private"

#ipa-server-install --realm=MATRIX.LAB --domain=matrix.private --ds-password='Passw0rd' --admin-password='Passw0rd' --hostname=rh6idm01.matrix.private --ip-address=10.10.10.101 --forwarder=10.10.10.10 --setup-dns

ipa-replica-prepare rh6idm02.matrix.private --ip-address 10.10.10.102
ssh-copy-id rh6idm02
scp /var/lib/ipa/replica-info-rh6idm02.matrix.private.gpg rh6idm02:/var/lib/ipa/

