# NOTE: THIS SYSTEM WILL BE CONFIGURED TO COMMUNICATE DIRECTLY WITH AD
if [ ! -f ./bootstrap.sh ]; then wget http://10.10.10.100/pub/bootstrap/bootstrap.sh; fi

grep rh6sat5 /etc/hosts || echo "10.10.10.100 rh6sat5.matrix.private rh6sat5" >> /etc/hosts

sh ./bootstrap.sh && shutdown now -r
yum -y install samba samba-client samba-common samba-winbind samba-winbind-clients

service smb start; chkconfig smb on

# FIND WHERE THE SERVER DEFINITION(S) ARE, DELETE THEM, RE-ADD MY OWN
#  DEFINITIONS
#MYLINE=`grep -n ^server /etc/ntp.conf | head -1 | cut -f1 -d\:`
#sed -i -e '/^server/d' /etc/ntp.conf
#sed -i -e "${MYLINE}iserver 1.pool.ntp.org" /etc/ntp.conf
#sed -i -e "${MYLINE}iserver 0.pool.ntp.org" /etc/ntp.conf
#sed -i -e "${MYLINE}iserver ms2k8ad11.corp.matrix.private" /etc/ntp.conf
#service ntpd start; chkconfig ntpd on

yum -y install krb5-workstation
cp -p /etc/krb5.conf{,.orig}

sed -i -e 's/EXAMPLE.COM/CORP.MATRIX.LAB/g' /etc/krb5.conf
sed -i -e 's/kerberos.example.com/ms2k8ad11.corp.matrix.private/g' /etc/krb5.conf
sed -i -e 's/example.com/matrix.private/g' /etc/krb5.conf
kinit administrator@CORP.MATRIX.LAB
yum -y install oddjob-mkhomedir && service oddjobd start && chkconfig oddjobd on
