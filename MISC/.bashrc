# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions
function set_title {
  title=$1;
  echo -e "\033];${title}\007";
}

# replaced the following by using ~/.ssh/config
#alias ssh="ssh -o TCPKeepAlive=yes -o ServerAliveInterval=50 -XCA ${1}"
alias vms="sudo virsh list --inactive --all"
alias vv="sudo virt-viewer ${1}"

alias doover='/usr/bin/sudo $(history -p \!\!)' 
alias please='/usr/bin/sudo $(history -p !!)'
alias itunes='/usr/bin/vncviewer cypher.matrix.private'
