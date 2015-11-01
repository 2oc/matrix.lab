# matrix.lab

## OVERVIEW
| Hostname  | Purpose | Proc, Mem Size |
| :----- |:---------------:| --------------:|
| RHEL7A | KVM Host        | i5-3570K, 16GB
| RHEL7B | RHEV Hypervisor | G620, 16GB
| RHEL7C | RHEV Hypervisor | G620, 16GB
| RHEL7D | NAS Host        | i5-4250U, 16GB

RHEL7A hosts the following KVM Guests
*  Satellite 6 (rh7sat6)
*  IDM (rh7idm01/02)
*  RHEV Manager (rh6rhevmgr)

RHEL7B/C are both RHEV Hypervisors (from RHEL 7)

RHEL7D is a Intel NUC with 2 x SSD installed which basically serves as a NAS (NFS and iSCSI)

## Build Steps
 - Build RHEL7A from DVD (manually) and register to RHN.
  - populate entire list of KVM guests in /etc/hosts
  - Build RH7SAT6 and register to RHN
  - Build RH7IDM01/02 and register to RH7SAT6
   - update DNS using 'ipa' command found in finish script
  - Build RH6RHEVMGR
 - Build RHEL7D and create iSCSI targets
 - Build RHEL7B/7C with RHEL7
  - Attach RHEL7B and 7C to RH6RHEVMGR to make them RHEV Hypervisors 
  - point RHEV Manager at RHEL7D for Storage

## NOTES
In general, I create:
 - a build_KVM.sh script, which relies on .config to identify parameters about each host.
 - \<HOSTNAME\>.ks file which is the kickstart file (anaconda-ks.cfg) for each host
 - ./post_install.sh a script that *should* end up in /root post kickstart.  This script registers node to Satellite and
    performs some housekeeping.
 - finish_\<HOSTNAME\>.sh which should contain all the post-build steps

```
# echo "RH7IDM01:EL7:2:2048:20:0" >> .config
# ./build_KVM.sh RH7IDM01
# ssh RH7IDM01
# ./post_install.sh
# wget http://10.10.10.10/finish_RH7IDM01.sh
# chmod u+x finish_RH7IDM01.sh
# ./finish_RH7IDM01.sh
```

## OSEv3
The primary function of my lab (at this time) is to have an OpenShift Enterprise v3 environment.

| Hostname  | Product      |  Purpose | Proc, Mem Size |
| :----- |:---------------:|:---------------:| --------------:|
| RH7SAT6 | Red Hat Satellite 6 | Host Management | 2, 4096m 
| RH7IDM01 | Red Hat Identity Management | IdM and DNS | 2, 1024m
| RH7IDM02 | Red Hat Identity Management | IdM and DNS | 2, 1024m
| -------- | --------------------------- | ----------- | --------
| RH7OSEMST01 | Red Hat OSEv3 | Master Node | 2, 1024m
| RH7OSEMST02 | Red Hat OSEv3 | Master Node | 2, 1024m (Optional Node)
| RH7OSEINF01 | Red Hat OSEv3 | Infrastructure Node | 2, 1024m
| RH7OSEINF02 | Red Hat OSEv3 | Infrastructure Node | 2, 1024m
| RH7OSETCD01 | Red Hat OSEv3 | ETCD Node | 2, 1024m
| RH7OSETCD02 | Red Hat OSEv3 | ETCD Node | 2, 1024m
| RH7OSETCD03 | Red Hat OSEv3 | ETCD Node | 2, 1024m
| RH7OSENOD01 | Red Hat OSEv3 | Container Node | 2, 1024m
| RH7OSENOD02 | Red Hat OSEv3 | Container Node | 2, 1024m


| Node Type | Description |
| :------------- |:---------------:|
| Master | Manages OSE Cluster, Hosts API, endpoint for Nodes to "check-in" for work
| Infrastructure | Nodes which will host container such as the registry and routers 
| ETCD | ETCD Nodes provide the clustered OSE object key-pair store
| Container | Container nodes will provide Docker for hosting your containers
