#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512

# Use CDROM installation media
cdrom
# Use graphical install
graphical
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=sdb
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=enp0s25 --gateway=10.10.10.1 --ip=10.10.10.13 --nameserver=8.8.8.8,10.10.10.122,10.10.10.121 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=rhel7d.matrix.lab
# Root password
rootpw --iscrypted $6$K6beNUML$Z1KZvoI2k8YryzT0Tz2NkJaNTudnTCFSm0DduMqJE9o/jKnq2kAnX63rs9k7FS8cQp2twDtXXjjrBMV5mju9b.
# System timezone
timezone America/New_York --isUtc
user --groups=wheel --name=morpheus --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="Morpheus"
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sdb

# Partition clearing information
clearpart --all --initlabel --drives=sdb
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=sdb --size=500
part /boot/efi --fstype="efi" --ondisk=sdb --size=200 --fsoptions="umask=0077,shortname=winnt"
part pv.214 --fstype="lvmpv" --ondisk=sdb --size=30391
volgroup rhel7d --pesize=4096 pv.214
logvol swap  --fstype="swap" --size=8000 --name=swap --vgname=rhel7d
logvol /  --fstype="xfs" --size=20480 --name=root --vgname=rhel7d
logvol /home  --fstype="xfs" --size=1904 --name=home --vgname=rhel7d

eula --agreed
reboot

%packages
@core
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

