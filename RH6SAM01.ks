#version=DEVEL
install
cdrom
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto static --ip 10.10.10.103 --netmask 255.255.255.0 --gateway 10.10.10.1 --noipv6 --nameserver 10.10.10.121 --hostname rh6sam01.matrix.lab --domain matrix.lab

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
clearpart --all --initlabel --drives=vda,vdb
bootloader --location=mbr --driveorder=vda,vdb

part /boot --fstype=ext4 --size=500 --ondisk=vda
part pv.vda2 --grow --size=1 --ondisk=vda
part pv.vdb1 --grow --size=1 --ondisk=vdb

volgroup vg_rh6sam501 --pesize=4096 pv.vda2
logvol / --fstype=ext4 --name=lv_root --vgname=vg_rh6sam501 --size=10240
logvol swap --name=lv_swap --vgname=vg_rh6sam501 --size=8192

volgroup vg_sam --pesize=4096 pv.vdb1
# /rh6sam5 is now /var/lib/pgsql
logvol /var/cache/rhn --fstype=ext4 --name=lv_varcrhn --vgname=vg_sam --size=5120

reboot 

%packages
@base
@core
yum-plugin-downloadonly
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
%end

