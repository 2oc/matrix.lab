# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs
TERM=vt100
EDITOR=vim
VISUAL=vim
HOSTNAME=`hostname | cut -f1 -d.`
GIT_EDTIOR=vim

PATH=$PATH:/usr/bin/:/sbin:/usr/sbin
PATH=$PATH:$HOME/.local/bin:$HOME/bin
#PATH=$PATH:/usr/openv/netbackup/bin:/usr/openv/netbackup/bin/admincmd
#PATH=$PATH:/opt/VRTS/bin:/opt/VRTSperl/bin:/opt/VRTSvcs/bin
case `uname` in
 SunOS)
   PS1="`/usr/ucb/whoami`@${HOSTNAME} $ "
   echo "\033]0; `uname -n` - `/usr/ucb/whoami` \007"
   PATH=$PATH:/usr/sfw/bin:/opt/sfw/bin:/usr/sfw/sbin:/opt/sfw/sbin:/usr/openwin/bin
   PATH=$PATH:/usr/ucb/:/usr/platform/sun4u/bin:/usr/platform/i86pc:/usr/ccs/bin
   PATH=$PATH:/opt/VRTS/bin:/opt/VRTSvcs/bin:/usr/openv/netbackup/bin
   PATH=$PATH:/usr/openv/volmgr/bin:/opt/SUNWsrspx/bin:/opt/SUNWppro/bin
   LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/sfw/lib:/opt/sfw/lib
 ;;
 AIX)
   PS1="`/usr/bin/whoami`@${HOSTNAME} $ "
   echo "\033]0; ${HOSTNAME} - `/usr/bin/whoami` \007";
 ;;
 Linux)
   #set_title "${USER}@${HOSTNAME}"
   #echo -e "\033];${title}\007";
 ;;
 Darwin)
   # Placeholder for Apple Mac OS X
 ;;
esac

MANPATH=$MANPATH:/usr/share/man:/opt/VRTS/man
export PATH PS1 MANPATH LD_LIBRARY_PATH TERM EDITOR VISUAL GIT_EDITOR

