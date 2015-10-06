#version=DEVEL
install
cdrom
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto static --ip 10.10.10.201 --netmask 255.255.255.0 --gateway 10.10.10.10 --noipv6 --nameserver 10.10.10.99 --hostname rh6clnt01.matrix.lab --domain matrix.lab
rootpw  --iscrypted $6$tayqK8crl/nVU/aN$ZQlw5okgLxoDzMV6IYaPQa3YlDUw4CcqJzFqtGHgp/nh8rBGyG/t5O0yJqsQLQVMRhW57tq/FBsRBu/OqUrsl0
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512
selinux --enforcing
timezone --utc America/New_York
# The following is the partition information you requested
# Note that any partitions you deleted are not expressed
# here so unless you clear all partitions first, this is
# not guaranteed to work
zerombr
clearpart --all --initlabel --drives=vda
bootloader --location=mbr --driveorder=vda

part /boot --fstype=ext4 --size=500
part pv.02 --grow --size=1
volgroup vg_rh6clnt01 --pesize=4096 pv.02
logvol / --fstype=ext4 --name=lv_root --vgname=vg_rh6clnt01 --grow --size=4096 --maxsize=20480
logvol swap --name=lv_swap --vgname=vg_rh6clnt01 --size=1024 --maxsize=1024

reboot 

%packages
@base
@client-mgmt-tools
@console-internet
@core
@debugging
@directory-client
@hardware-monitoring
@java-platform
@large-systems
@network-file-system-client
@performance
@perl-runtime
@server-platform
@server-policy
pax
python-dmidecode
oddjob
sgpio
device-mapper-persistent-data
samba-winbind
certmonger
pam_krb5
krb5-workstation
perl-DBD-SQLite
yum-plugin-downloadonly
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
%end

