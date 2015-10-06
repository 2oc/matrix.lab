#rhnreg_ks --username="${RHNUSER}" --password='${RHNPASSWD}'

cat << EOF >> /etc/hosts
# IP/HOSTNAME/ALIAS for IdM Servers
10.10.10.10 rh6ns01.matrix.private rh6ns01
10.10.10.101 rh6idm01.matrix.private rh6idm01
10.10.10.102 rh6idm02.matrix.private rh6idm02
EOF

yum -y install ipa-client ipa-admintools

ipa-client-install --enable-dns-updates


