# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions
alias vms="sudo virsh list --inactive --all"
alias vv="sudo virt-viewer ${1}"

alias doover='/usr/bin/sudo $(history -p \!\!)' 
alias please='/usr/bin/sudo $(history -p !!)'
alias butwhy='/usr/bin/systemctl status $_ '
alias itunes='/usr/bin/vncviewer --CompressLevel=6 cypher.matrix.private'

alias aplogin='oc login -u oseuser -p 'Passw0rd' --insecure-skip-tls-verify --server=https://openshift-cluster.aperture.lab.:8443'
#alias mtlogin='oc login -u morpheus -p 'Passw0rd' --insecure-skip-tls-verify --server=https://openshift-cluster.matrix.lab.:8443'
alias mtlogin='oc login -u morpheus -p 'Passw0rd' --insecure-skip-tls-verify --server=https://rh7osemst01.matrix.lab.:8443'

# Use vi as the EDITOR
set -o vi
