#!/bin/bash
#curl -v -u "admin@internal:Passw0rd" --cacert rh6rhevmgr.matrix.lab.cer -H "Content-type: application/xml" -X GET http(s)://rh6rhevmgr.matrix.lab:443/api/vms/xxx
#curl -v -u "admin@internal:Passw0rd" --insecure -H "Content-type: application/xml" -X GET http(s)://rh6rhevmgr.matrix.lab:443/api/vms/xxx
# curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}
# curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/vms

CONFIG=./.config
if [ ! -f $CONFIG ]
then
  echo "ERROR: No Config File found"
  exit 9
fi

RHEVMGR=rh6rhevmgr.matrix.lab
RHEVCRT="${RHEVMGR}.cer"
RHEVAPI=https://${RHEVMGR}:443/api
RHEVCLUSTER="Production"
#OPTIONS='--insecure '
CREDS="admin@internal:Passw0rd"
HEADER1="Content-type: application/xml"
HEADER2="Accept: application/xml"


if [ ! -f ${RHEVCRT} ]
then
  curl -o ${RHEVCRT} http://${RHEVMGR}:80/ca.crt
fi

usage() {
  echo "${0} [delete|create|shutdown|start|list]"
}

list() {
# RETRIEVE VMS (INFORMATIONAL) 
# curl -v -u "${CREDS}"  -H "${HEADER1}" $OPTIONS --cacert $RHEVCRT -X GET ${RHEVAPI}
curl -v -u "${CREDS}" \
  -H "${HEADER1}" \
  $OPTIONS \
  --cacert $RHEVCRT \
  -X GET ${RHEVAPI}/vms/
}
start_all() {
for ID in `curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/vms?search=RH7OSE* | grep 'vm href' | cut -f4 -d\"`
do
  echo "# NOTE:  Startup - $ID"
  echo "curl -s -u \"${CREDS}\" --cacert ${RHEVCRT} ${OPTIONS} -H \"${HEADER1}\" -d '<action/>' ${RHEVAPI}/vms/${ID}/start"
  curl -s -u "${CREDS}" --cacert ${RHEVCRT} ${OPTIONS} -H "${HEADER1}" -d '<action/>' ${RHEVAPI}/vms/${ID}/start
done
}
shutdown_all() {
for ID in `curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/vms?search=RH7OSE* | grep 'vm href' | cut -f4 -d\"`
do
  echo "# NOTE:  Shutdown - $ID"
  echo "curl -s -u \"${CREDS}\" --cacert ${RHEVCRT} ${OPTIONS} -H \"${HEADER1}\" -d '<action/>' ${RHEVAPI}/vms/${ID}/shutdown"
  curl -s -u "${CREDS}" --cacert ${RHEVCRT} ${OPTIONS} -H "${HEADER1}" -d '<action/>' ${RHEVAPI}/vms/${ID}/shutdown
done
}
delete_all() {
for ID in `curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/vms?search=RH7OSE* | grep 'vm href' | cut -f4 -d\"`
do
  echo "# NOTE:  Deleting - $ID"
  echo "curl -s -u \"${CREDS}\" $OPTIONS --cacert ${RHEVCRT} -X DELETE ${RHEVAPI}/vms/${ID} HTTP/1.1"
  curl -s -u "${CREDS}" $OPTIONS --cacert ${RHEVCRT} -X DELETE ${RHEVAPI}/vms/${ID} HTTP/1.1
  echo
done
echo

}
create_VMS() {
#curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u [USER:PASS] --cacert [CERT] -d "<vm><name>vm1</name><cluster><name>default</name></cluster><template><name>Blank</name></template><memory>536870912</memory><os><boot dev='hd'/></os></vm>" https://[RHEVM Host]:8443/api/vms  
grep -v ^# ${CONFIG} | awk -F':' '{ print $1" "$2" "$3" "$4" "$5" "$6 }' | while read GUESTNAME RELEASE NUMCPUS MEM HDDA HDDB
do
  echo $GUESTNAME $RELEASE $NUMCPUS $MEM $HDD0 $HDD1
  echo "GUESTNAME: $GUESTNAME"
  echo "RELEASE: $RELEASE"
  echo "NUMCPUS: $NUMCPUS"
  echo "MEM: $MEM"
  echo "HDDA: $HDDA"
  echo "HDDB: $HDDB"

  echo "NOTE: pause for 5 seconds to review parameters above"
  #sleep 5 
  echo "############################################################################################################"
  echo "############################################################################################################"

  # 1.  Create VM
  echo "curl -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u \"${CREDS}\" --cacert ${RHEVCRT} -d \"<vm><name>${GUESTNAME}</name><cluster><name>${RHEVCLUSTER}</name></cluster><template><name>Blank</name></template><cpu><topology cores='${NUMCPUS}' sockets='1'/></cpu><memory>${MEM}</memory><descritption>OSE v3 Host</description><os><boot dev='hd'/></os></vm>\" ${RHEVAPI}/vms"
  curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u "${CREDS}" --cacert ${RHEVCRT} -d "<vm><name>${GUESTNAME}</name><cluster><name>${RHEVCLUSTER}</name></cluster><template><name>Blank</name></template><cpu><topology cores='${NUMCPUS}' sockets='1'/></cpu><memory>${MEM}</memory><description>OSE v3 Host</description><os><boot dev='hd'/></os></vm>" ${RHEVAPI}/vms
  # 1.5 - Retrieve the UUID of the VM
  VMID=`curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/vms?search=${GUESTNAME} | grep 'vm href' | cut -f4 -d\"`

  # 2.  Create Virtual NIC (on rhevm)
  # curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u [USER:PASS] --cacert [CERT] -d "<nic><name>nic1</name><network><name>rhevm</name></network></nic>" https://[RHEVM Host]:8443/api/vms/6efc0cfa-8495-4a96-93e5-ee490328cf48/nics
  echo "curl -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u \"${CREDS}\" --cacert ${RHEVCRT} -d \"<nic><name>nic1</name><network><name>rhevm</name></network></nic>\" ${RHEVAPI}/vms/${VMID}/nics"
  curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u "${CREDS}" --cacert ${RHEVCRT} -d "<nic><name>nic1</name><network><name>rhevm</name></network></nic>" ${RHEVAPI}/vms/${VMID}/nics

  # 3.  Create VDDs
  # 3.1  - Retrieve the storage_domain UUID 
  # curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/storagedomains 
  STORAGEDOMID=`curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/storagedomains | grep -A1 "<name>iSCSI</name>" | grep "link href" | awk -F\" '{ print $2 }' | cut -f4 -d\/`
  #

  # curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u [USER:PASS] --cacert [CERT] -d "<disk><storage_domains><storage_domain id='9ca7cb40-9a2a-4513-acef-dc254af57aac'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable></disk>" https://[RHEVM Host]:8443/api/vms/6efc0cfa-8495-4a96-93e5-ee490328cf48/disks
  case ${HDDB} in
    0)
      # ONLY CREATE 1 VDD
      echo "# NOTE:  Creating 1 VDD - $HDDA"
      echo "curl -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u \"${CREDS}\" --cacert ${RHEVCRT} -d \"<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable><description>OS Disk</description></disk>\" ${RHEVAPI}/vms/${VMID}/disks"
      curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u "${CREDS}" --cacert ${RHEVCRT} -d "<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable><description>OS Disk</description></disk>" ${RHEVAPI}/vms/${VMID}/disks
    ;;
    *)
      # ONLY CREATE 2 VDD
      echo "# NOTE:  Creating 2 VDD"
      echo "curl -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u \"${CREDS}\" --cacert ${RHEVCRT} -d \"<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable><description>OS Disk</description></disk>\" ${RHEVAPI}/vms/${VMID}/disks"
      curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u "${CREDS}" --cacert ${RHEVCRT} -d "<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable><description>OS Disk</description></disk>" ${RHEVAPI}/vms/${VMID}/disks
      echo "curl -X POST -H \"Accept: application/xml\" -H \"Content-Type: application/xml\" -u \"${CREDS}\" --cacert ${RHEVCRT} -d \"<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDB}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>true</bootable><description>Data Disk</description></disk>\" ${RHEVAPI}/vms/${VMID}/disks"
      curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u "${CREDS}" --cacert ${RHEVCRT} -d "<disk><storage_domains><storage_domain id='${STORAGEDOMID}'/></storage_domains><size>${HDDA}</size><type>system</type><interface>virtio</interface><format>cow</format><bootable>false</bootable><description>Data Disk</description></disk>" ${RHEVAPI}/vms/${VMID}/disks
    ;;
  esac
  # 4. Attach ISO to VM (this... does not work)
  # The next two lines will (first) retrieve the UUID of the ISO_DOMAIN, then (second) Display the files it has
  # curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -X GET ${RHEVAPI}/storagedomains | grep -A3 "<name>ISO_DOMAIN</name>" | grep "link href" | awk -F\" '{ print $2 }' | cut -f4 -d\/`
  # curl -s -u "admin@internal:Passw0rd" --cacert rh6rhevmgr.matrix.lab.cer --insecure  -H "Content-type: application/xml" -X GET https://rh6rhevmgr.matrix.lab:443/api/storagedomains/ba7dc41b-80c0-4417-b259-ff137bd4255e/files
  # curl -X POST -H "Accept: application/xml" -H "Content-Type: application/xml" -u [USER:PASS] --cacert [CERT] -d "<cdrom><file id='rhel-server-6.0-x86_64-dvd.iso'/></cdrom>" https://[RHEVM Host]:8443/api/vms/6efc0cfa-8495-4a96-93e5-ee490328cf48/cdroms
  echo "curl -s -u \"${CREDS}\" --cacert ${RHEVCRT} $OPTIONS -H \"${HEADER1}\" -H \"${HEADER2}\" -X POST -d \"<cdrom><file id='rhel-server-7.1-x86_64-dvd.iso'/></cdrom>\" ${RHEVAPI}/storagedomains/${VMID}/cdroms"
  #curl -s -u "${CREDS}" --cacert ${RHEVCRT} $OPTIONS -H "${HEADER1}" -H "${HEADER2}" -X POST -d "<cdrom><file id='rhel-server-7.1-x86_64-dvd.iso'/></cdrom>" ${RHEVAPI}/storagedomains/${VMID}/cdroms

  # 5.  Build the VM (work in progress)
  # start VM
  # append to boot string "inst.ks=http://10.10.10.10/${GUESTNAME}.ks"


  echo
  echo
  echo
done
}
 

case $1 in 
  delete)
    delete_all
  ;;
  create) 
    create_VMS 
  ;;
  shutdown)
    shutdown_all
  ;;
  start)
    start_all
  ;;
  list)
    list 
  ;;
  *)
    echo "# ERROR: unknown option $1 "
    usage
    exit 9
esac
  
exit 0


https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Virtualization/3.0/html-single/REST_API_Guide/#chap-REST_API_Guide-Authentication
