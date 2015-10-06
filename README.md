# matrix.lab

'''OVERVIEW'''
| Hostname  | Purpose | Size |
| :------------ |:---------------:| -----:|
| RHEL7A        | KVM Host        | i5-3570K, 16GB
| RHEL7B        | RHEV Hypervisor | G620, 16GB
| RHEL7C        | RHEV Hypervisor | G620, 16GB
| RHEL7D        | NAS Host        | i5-4250U, 16GB

RHEL7A hosts the following KVM Guests
*  Satellite 6 (rh7sat6)
*  IDM (rh7idm01/02)
*  RHEV Manager (rh6rhevmgr)

RHEL7B/C are both RHEV Hypervisors (from RHEL 7)

RHEL7D is a Intel NUC with 2 x SSD installed which basically serves as a NAS (NFS and iSCSI)

'''Build Steps'''
Build RHEL7A from DVD (manually) and register to RHN.
 - populate entire list of KVM guests in /etc/hosts
 - Build RH7SAT6 and register to RHN
 - Build RH7IDM01/02 and register to RH7SAT6
 -- update DNS using 'ipa' command found in finish script
 - Build RH6RHEVMGR

Build RHEL7D and create iSCSI targets
Build RHEL7B/7C and use RH6RHEVMGR to make them RHEV Hypervisors and attach them to RHEL7D for Storage

'''NOTES'''
In general, I create:
 - a build_KVM.sh script, which relies on .config to identify parameters about each host.
 - <HOSTNAME>.ks file which is the kickstart file (anaconda-ks.cfg) for each host
 - ./post_install.sh a script that *should* end up in /root post kickstart.  This script registers node to Satellite and
    performs some housekeeping.
 - finish_<HOSTNAME>.sh which should contain all the post-build steps

