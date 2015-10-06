install
cdrom
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto static --ip 10.10.10.1003 --netmask 255.255.255.0 --gateway 10.10.10.10 --ipv6 auto --nameserver 10.10.10.99 --hostname rh6storage01.matrix.lab --domain matrix.lab
rootpw  --iscrypted $6$eSsUXtRvzQ1qra.6$o7.9T8R1Dd.2KPcFPt1uf5E23mH8jKXLMfqZzEeqyTzzUd2rh5LtU1tysl1zXmTis8mQFUIjqX97O.X2hZav91
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512
selinux --enforcing
timezone --utc America/New_York
bootloader --location=mbr --driveorder=vda --append="rhgb quiet"
# The following is the partition information you requested
# Note that any partitions you deleted are not expressed
# here so unless you clear all partitions first, this is
# not guaranteed to work
zerombr
clearpart --all --initlabel --drives=vda
bootloader --location=mbr --driveorder=vda
ignoredisk --drives=vdb

part /boot --fstype=ext4 --size=500
part pv.253002 --grow --size=1
volgroup vg_rh6storage01 --pesize=4096 pv.253002
logvol / --fstype=ext4 --name=lv_root --vgname=vg_rh6storage01 --grow --size=1024 --maxsize=51200
logvol swap --name=lv_swap --vgname=vg_rh6storage01 --grow --size=2016 --maxsize=2016

reboot

%packages
@base
@core
@glusterfs-all
@glusterfs-swift
@rhs-tools
@scalable-file-systems
yum-plugin-downloadonly
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
%end
