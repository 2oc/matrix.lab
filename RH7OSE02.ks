#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512

# Use CDROM installation media
cdrom
# Use graphical install
graphical
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=eth0 --gateway=10.10.10.1 --ip=10.10.10.132 --nameserver=8.8.8.8,10.10.10.122,10.10.10.121 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=rh7ose02.matrix.lab
# Root password
rootpw --iscrypted $6$edRNjLHhSdhiegdj$rVg.7iVxdnKIuimm/orLt1TcxvqAq8zW6zkTGm/TBxBlC2OdRFSrK9LExt/JceeeEu4whdJg/14bspjKvYb4g.
# System timezone
timezone America/New_York --isUtc
user --groups=wheel --homedir=/home/morpheus --name=morpheus --password=$6$ABgbxEu1HKnJNE5f$4KRsPNevPTtELhWrHqT6nmk4NlDsVbohVNJnbKeuYJmg2DmXomlrRv77.NRHPjRqImDpCNMOAx1ZmqVSPeqn.1 --iscrypted --gecos="Morpheus"
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
# Partition clearing information
clearpart --none --initlabel 
# Disk partitioning information
part pv.124 --fstype="lvmpv" --ondisk=vda --size=50699
part /boot --fstype="xfs" --ondisk=vda --size=500
volgroup rhel --pesize=4096 pv.124
logvol /  --fstype="xfs" --grow --maxsize=51200 --size=1024 --name=root --vgname=rhel
logvol swap  --fstype="swap" --size=2048 --name=swap --vgname=rhel

%packages
@core
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
