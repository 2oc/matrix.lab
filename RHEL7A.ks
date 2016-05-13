#version=RHEL7
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
network  --bootproto=dhcp --device=enp1s0f0 --onboot=off --ipv6=auto
network  --bootproto=dhcp --device=enp1s0f1 --onboot=off --ipv6=auto
network  --bootproto=dhcp --device=enp1s0f2 --onboot=off --ipv6=auto
network  --bootproto=dhcp --device=enp1s0f3 --onboot=off --ipv6=auto
network  --bootproto=dhcp --device=enp3s0 --ipv6=auto --activate
network  --hostname=rhel7a.matrix.private
# Root password
rootpw --iscrypted $6$K6beNUML$Z1KZvoI2k8YryzT0Tz2NkJaNTudnTCFSm0DduMqJE9o/jKnq2kAnX63rs9k7FS8cQp2twDtXXjjrBMV5mju9b.
# System timezone
timezone America/New_York --isUtc
user --groups=wheel --homedir=/home/morpheus --name=morpheus --password=$6$YTbEzW.h$aPoQPlRS8HR9CkX6.3m5wO/0aEhnBe1ajOZx7fYM0tggmoX8YWH2Y44cvfaH3Mt3waG9tJzMiGbw5u3Miajlb.  --iscrypted --uid=2025 --gecos="Morpheus" --gid=2025
# X Window System configuration information
xconfig  --startxonboot
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Disk partitioning information
part pv.308 --fstype="lvmpv" --ondisk=sda --size=243497
part /boot --fstype="xfs" --ondisk=sda --size=500
part /boot/efi --fstype="efi" --ondisk=sda --size=200 --fsoptions="umask=0077,shortname=winnt"
volgroup rhel_rhel7a --pesize=4096 pv.308
logvol /  --fstype="xfs" --size=20480 --name=root --vgname=rhel_rhel7a
logvol /home  --fstype="xfs" --size=215076 --name=home --vgname=rhel_rhel7a
logvol swap  --fstype="swap" --size=7936 --name=swap --vgname=rhel_rhel7a

%packages
@base
@core
@desktop-debugging
@dial-up
@fonts
@gnome-desktop
@guest-agents
@guest-desktop-agents
@input-methods
@internet-browser
@multimedia
@print-client
@virtualization-client
@virtualization-hypervisor
@virtualization-tools
@x11
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
