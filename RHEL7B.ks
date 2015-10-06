#version=RHEL7
url --url="http://rh6sat5.matrix.lab/ks/dist/ks-rhel-x86_64-server-7-7.1"

# System authorization information
auth --enableshadow --passalgo=sha512

# Use CDROM installation media
cdrom
# Use graphical install
graphical
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=sda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=enp0s25 --onboot=on --ipv6=auto --ip=10.10.10.11 --netmask=255.255.255.0 gateway=10.10.10.1 --nameserver=10.10.10.121 --hostname=rhel7b.matrix.lab --activate
network  --bootproto=dhcp --device=enp3s0 --onboot=off --ipv6=auto

# Root password
rootpw --iscrypted $6$/rtrqqzFasIO4IWN$tWrmNecAtVghwurw4UcPBR4AbZUn9pJ5/c0.rDCMV7emDSzzG7X0y7dGFKbES6vXT2lgErNuK0S5RfY3ylovp1
# System timezone
timezone America/New_York --isUtc

# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=sda --size=500
part pv.240 --fstype="lvmpv" --ondisk=sda --size=243697
volgroup rhel7b --pesize=4096 pv.240
logvol /  --fstype="xfs" --size=8192 --name=root --vgname=rhel7b
logvol /home  --fstype="xfs" --size=1024 --name=home --vgname=rhel7b
logvol swap  --fstype="swap" --size=8192 --name=swap --vgname=rhel7b

eula --agreed
reboot

%packages
@core
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/post_install.sh -O /root/post_install.sh
%end

