#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline

# Use network installation
#url --url="http://10.10.10.10/RHEL-7.1-x86_64/"
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=eth0 --ip=10.10.10.139 --netmask=255.255.255.0 --gateway=10.10.10.1 --activate --nameserver=10.10.10.121,10.10.10.122 --hostname=rh7osenod03.matrix.lab 

# Root password
rootpw --iscrypted $6$K6beNUML$Z1KZvoI2k8YryzT0Tz2NkJaNTudnTCFSm0DduMqJE9o/jKnq2kAnX63rs9k7FS8cQp2twDtXXjjrBMV5mju9b.
user --groups=wheel --name=morpheus --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="Morpheus"
# System timezone
timezone America/New_York --isUtc --ntpservers=rh7idm01.matrix.lab,rh7idm02.matrix.lab,rh7sat6.matrix.lab

#########################################################################
### DISK ###
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
ignoredisk --only-use=vda

# Partition clearing information
#autopart --type=lvm
clearpart --all --initlabel --drives=vda

# Partition Info
part /boot --fstype="xfs" --ondisk=vda --size=500
part pv.03 --fstype="lvmpv" --ondisk=vda --size=10240 --grow
#
volgroup vg_rh7osenod03 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rh7osenod03 --name=lv_root --label="root" --size=8192
logvol swap --fstype=swap --vgname=vg_rh7osenod03 --name=lv_swap --label="swap" --size=2048
logvol /home --fstype=xfs --vgname=vg_rh7osenod03 --name=lv_home --label="home" --size=1024
logvol /tmp --fstype=xfs --vgname=vg_rh7osenod03 --name=lv_tmp --label="temp" --size=2048
logvol /var/lib/docker --fstype=xfs --vgname=vg_rh7osenod03 --name=lv_vrlbdckr --label="docker" --size=5120

eula --agreed
reboot

%packages
@base
@core
ntp
perl
yum-plugin-downloadonly
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
%end

