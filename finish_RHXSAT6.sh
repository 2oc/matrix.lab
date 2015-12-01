#!/bin/bash

# To convert the file for the other ENV
# cat finish_RHXSAT6.sh | sed 's/10.10.10/10.10.10/g' | sed 's/MATRIX/MATRIX/g' | sed 's/matrix/matrix/g' |sed 's/10.10.10/10.10.10/g' > ../matrix.lab/finish_RHXSAT6.sh 

####################
# Users (post-script)
#  ORG: default
#    GROUP: N/A 
#    USER: admin / Passw0rd (Satellite Administrator)
#  ORG: ${ORGANIZATION}
#    GROUP: regusers
#      USER: satmgr / Passw0rd (Manager)
#      USER: reguser / Passw0rd (Edit Hosts)
####################

# I have found it easier to NOT use whitespace in the ORGANIZATION Variable
cat << EOF >> ~/.bash_profile
ORGANIZATION="MATRIXLABS"
LOCATION="HomeLab"
SATELLITE="rh7sat6"
DOMAIN="matrix.lab"
EXPORT DOMAIN SATELLITE LOCATION ORGANIZATION
EOF
RHNUSER=""
RHNPASSWD=""

if [ -z ${RHNUSER} ] || [ -z ${RHNPASSWD} ]
then
  echo "ERROR:  Please update RHNUSER/RHNPASSWD Variables in the beginning of this script."
  echo "        Script cannot proceed with empty values."
  exit 9
fi

####################################################################################
###  PRE
####################################################################################
tuned-adm profile virtual-guest
systemctl enable tuned 

# If installing from CD (Sat 6.1), then manually import this key before starting...
# rpm --import https://www.redhat.com/security/f21541eb.txt

subscription-manager register --auto-attach --username="$RHNUSER" --password="$RHNPASSWD"
subscription-manager list --available --all > /var/tmp/subscription-manager_list--available--all.out
# THE PROCESS TO RETRIEVE "POOL" MAY, OR MAY NOT WORK FOR YOU
POOL=`awk '/Red Hat Satellite 6/ {flag=1;next} /Available:/{flag=0} flag {print}' /var/tmp/subscription-manager_list--available--all.out | grep "Pool ID:" | awk '{ print $3 }'`
#POOL=`grep -A15 "Red Hat Satellite 6" /var/tmp/subscription-manager_list--available--all.out | grep "Pool ID:" | awk -F: '{ print $2 }' | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'`
subscription-manager subscribe --pool=${POOL} 
subscription-manager repos --disable "*"
subscription-manager repos > /var/tmp/subscription-manager_repos.out

uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager release --set=$RELEASE

case $RELEASE in 
  7Server) 
    # This is a kludge at the moment... 
    #subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-satellite-6.1-rpms --enable rhel-7-server-satellite-optional-6.1-rpms --enable rhel-server-rhscl-7-rpms --releasever=${RELEASE}
    subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-satellite-6.1-rpms --enable rhel-server-rhscl-7-rpms 
  ;;
  6Server)
    subscription-manager repos --enable rhel-6-server-rpms --enable rhel-6-server-satellite-6.0-rpms --enable rhel-6-server-satellite-optional-6.0-rpms --enable rhel-server-rhscl-6-rpms --releasever=${RELEASE}
    chkconfig ntpd on && service ntpd start
  ;;
  *)
    echo "ERROR: RELEASE not configured"
    exit 9
  ;;
esac

TCP_PORTS="80 443 5000 5671 5674 8080 8140 9090" 
UDP_PORTS="53 67 68 69 80 443 8080 "
case $RELEASE in
  7Server)
    echo "`hostname -I` `hostname` `hostname -s` " >> /etc/hosts
    DEFAULT_ZONE=`/bin/firewall-cmd --get-default-zone`
    for PORT in $TCP_PORTS
    do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/tcp
    done
    for PORT in $UDP_PORTS
    do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/udp
    done

    for USER in foreman katello root
    do 
      firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -o lo -p tcp -m tcp --dport 9200 -m owner --uid-owner $USER -j ACCEPT
      firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 0 -o lo -p tcp -m tcp --dport 9200 -m owner --uid-owner $USER -j ACCEPT
    done

    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -o lo -p tcp -m tcp --dport 9200 -j DROP
    firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 1 -o lo -p tcp -m tcp --dport 9200 -j DROP

    /bin/firewall-cmd --reload
    /bin/firewall-cmd --list-ports
  ;;
  6Server)
    cp /etc/sysconfig/iptables /etc/sysconfig/iptables.bak     
    for PORT in $TCP_PORTS
    do
      iptables --insert INPUT 5 -p tcp --dport $PORT -j ACCEPT
    done
    for PORT in $UDP_PORTS
    do
      iptables --insert INPUT 5 -p udp --dport $PORT -j ACCEPT
    done
    service iptables save
    service iptables restart 
  ;;
esac

####################################################################################
## INSTALL
####################################################################################
# I cannot seem to get the install to work via channels ;-(
# From channels
yum -y install katello

# Or... ISO
#scp 10.10.10.1:/var/lib/libvirt/images/Satellite-6.1.0-RHEL-7-20150428.0-Satellite-x86_64-dvd1.iso /tmp
#mount -oloop /tmp/Satellite-6.1.0-RHEL-7-20150428.0-Satellite-x86_64-dvd1.iso /mnt
#mount /dev/cdrom /mnt
#cd /mnt && ./install_packages --enhanced_reporting

# Without these tweaks the installation was failing
# (need to validate this is the correct way to apply these tweaks)
cat << EOF >> /etc/foreman/settings.yaml
# Added for Satellite Installation
:idle_timeout: 60
:proxy_request_timeout: 99
EOF
# Equivalent to...
#foreman-rake config -- -k idle_timeout -v 60
#foreman-rake config -- -k proxy_request_timeout -v 99

## NOTE:  I don't know what the cause may be... but, I have noticed that occasionally I need to
##    attempt an installation, let it fail, reboot, and try again to get the installer to work :-=(
# Tune this for your own environment
cat << EOF > katello-installer.cmd
katello-installer --foreman-admin-username="admin" \
  --foreman-admin-password="Passw0rd" \
  --foreman-authentication=true \
  --foreman-initial-organization="${ORGANIZATION}" \
  --foreman-initial-location="${LOCATION}" \
  --capsule-tftp=true --capsule-tftp-servername="10.10.10.102" \
  --capsule-dns=true --capsule-dns-forwarders="10.10.10.1" \
  --capsule-dns-interface="eth0" --capsule-dns-reverse="10.10.10.in-addr.arpa" \
  --capsule-dns-zone="${DOMAIN}" \
  --capsule-dhcp=true --capsule-dhcp-interface=eth0 \
  --capsule-dhcp-gateway="10.10.10.1" --capsule-dhcp-range="10.10.10.200 10.10.10.220" 
EOF
sh ./katello-installer.cmd
  #--capsule-dhcp=true --capsule-dhcp-interface=eth0 \
  #--capsule-dhcp-gateway="10.10.10.1" --capsule-dhcp-range="10.10.10.200 10.10.10.220" 
  
yum -y update && shutdown now -r

# If things don't seem to be working... (I don't know if this works long-term)
# katello-installer --reset 

####################################################################################
## POST 
####################################################################################
mkdir ~/.hammer ~/.foreman
chmod 0600 ~/.hammer
cat << EOF > ~/.hammer/cli_config.yml
:modules:
    - hammer_cli_foreman

:foreman:
    :enable_module: true
    :host: 'https://${SATELLITE}.${DOMAIN}'
    :username: 'admin'
    :password: 'Passw0rd'
    :organization: '${DOMAIN}'

    # Check API documentation cache status on each request
    #:refresh_cache: false

    # API request timeout. Set to -1 for no timeout
    #:request_timeout: 120 #seconds

:log_dir: '~/.foreman/log'
:log_level: 'error'
EOF

###################
# --source-id=1 (should be INTERNAL)
hammer user create --login satadmin --mail="satadmin@${SATELLITE}.${DOMAIN}" --firstname="Satellite" --lastname="Adminstrator" --password="Passw0rd" --auth-source-id=1
hammer user add-role --login=satadmin --role-id=9
hammer user create --login reguser --mail="reguser@${SATELLITE}.${DOMAIN}" --firstname="Registration" --lastname="User" --password="Passw0rd" --auth-source-id=1
hammer user-group create --name="regusers" --role-ids=12 --users=satadmin,reguser

#hammer organization create --name="${ORGANIZATION}" --label="${ORGANIZATION}"
hammer organization add-user --user=satadmin --name="${ORGANIZATION}"
hammer organization add-user --user=reguser --name="${ORGANIZATION}"

#hammer location create --name="${LOCATION}"

hammer location add-organization --name="${LOCATION}" --organization="${ORGANIZATION}"

hammer domain create --name="${DOMAIN}"

hammer subnet create --domain-ids=1 --gateway='10.10.10.1' --mask='255.255.255.0' --name='10.10.10.0/24' --tftp-id=1 --network='10.10.10.0' --dns-primary='10.10.10.121' --dns-secondary='10.10.10.122'

hammer organization add-subnet --subnet-id=1 --name="${ORGANIZATION}"
hammer organization add-domain --domain="${DOMAIN}" --name="${ORGANIZATION}" 

scp 10.10.10.1:/home/jradtke/Downloads/RH7SAT6-APLABS-20151105.zip  ./
hammer subscription upload --file RH7SAT6-APLABS-20151105.zip --organization="${ORGANIZATION}"

######################
## Collect information
hammer product list --organization="${ORGANIZATION}" > ~/hammer_product_list.out
PRODUCT='Red Hat Enterprise Linux Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out

######################
PRODUCT='Red Hat Enterprise Linux Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="3815 2463 2472 2456 2476"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='7Server' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done
## THERE ARE REPOS WHICH DO *NOT* ACCEPT A "releasever" VALUE
REPOS="4185 4188 3030"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done
######################
PRODUCT='Red Hat Enterprise Linux High Availability for RHEL Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="2762"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  echo "hammer repository-set enable --organization=\"${ORGANIZATION}\" --basearch='x86_64' --releasever='7Server' --product=\"${PRODUCT}\" --id=\"${REPO}\" "
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done

######################
PRODUCT='Red Hat OpenShift Enterprise'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="4025"  # 3.0
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done
## THERE ARE REPOS WHICH DO *NOT* ACCEPT A "releasever" VALUE
REPOS="4658" # 3.1
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
done
######################
PRODUCT='Red Hat Software Collections for RHEL Server'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="2808"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done
######################
PRODUCT='Red Hat Enterprise Virtualization'
hammer repository-set list --organization="${ORGANIZATION}" --product "${PRODUCT}" > ~/hammer_repository-set_list-"${PRODUCT}".out
REPOS="3245 3109"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done
## THIS PACKAGE IS 6Server specific (at this time)
REPOS=4425
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  #hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --product="${PRODUCT}" --id="${REPO}"
  hammer repository-set enable --organization="${ORGANIZATION}"  --product="${PRODUCT}" --id="${REPO}"
done
######################
PRODUCT='Oracle Java for RHEL Server'
REPOS="3254"
for REPO in $REPOS
do
  echo; echo "NOTE:  Enabling (${REPO}): `grep $REPO ~/hammer_repository-set_list-"${PRODUCT}".out | cut -f3 -d\|`"
  #hammer repository-set enable --organization="${ORGANIZATION}" --basearch='x86_64' --releasever='7Server' --product="${PRODUCT}" --id="${REPO}"
done
#################
## EPEL Stuff - Pay attention to the output of this section.  It's not tested/validated
#    If it doesn't work, update the GPG-KEY via the WebUI
wget -q https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7  -O /root/RPM-GPG-KEY-EPEL-7
hammer gpg create --key /root/RPM-GPG-KEY-EPEL-7 --name 'GPG-EPEL-7' --organization="${ORGANIZATION}"
GPGKEYID=`hammer gpg list --name="GPG-EPEL-7" --organization="${ORGANIZATION}" | grep ^[0-9] | awk '{ print $1 }'`
PRODUCT='Extra Packages for Enterprise Linux'
hammer product create --name="${PRODUCT}" --organization="${ORGANIZATION}" 
hammer repository create --name='EPEL 7 - x86_64' --organization="${ORGANIZATION}" --product="${PRODUCT}" --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/ --gpg-key-id="${GPGKEYID}" --gpg-key="${GPG-EPEL-7}"
#################
## SYNC EVERYTHING (Manually)
#for i in $(hammer --csv repository list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do echo "hammer repository synchronize --id ${i} --organization=\"${ORGANIZATION}\" --async"; done
for i in $(hammer --csv repository list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do hammer repository synchronize --id ${i} --organization="${ORGANIZATION}" --async; done
#################
## LIFECYCLE ENVIRONMENT
hammer lifecycle-environment create --name='DEV' --prior='Library' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='TEST' --prior='DEV' --organization="${ORGANIZATION}"
hammer lifecycle-environment create --name='PROD' --prior='TEST' --organization="${ORGANIZATION}"

#################
# SYNC PLANS - I believe these are working now.
hammer sync-plan create --enabled true --interval=daily --name='Daily sync - Red Hat' --description="Daily Sync Plan for Red Hat Products" --sync-date='2015-11-22 02:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat OpenShift Enterprise'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Linux Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Linux High Availability for RHEL Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat OpenShift Enterprise'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Software Collections for RHEL Server'
hammer product set-sync-plan --sync-plan='Daily sync - Red Hat' --organization="${ORGANIZATION}" --name='Red Hat Enterprise Virtualization'
hammer sync-plan create --enabled true --interval=daily --name='Daily sync - EPEL' --description="Daily Sync Plan for EPEL" --sync-date='2015-11-22 03:00:00' --organization="${ORGANIZATION}"
hammer product set-sync-plan --sync-plan='Daily sync - EPEL' --organization="${ORGANIZATION}" --name='Extra Packages for Enterprise Linux'

# It's best y'all leave right now....
exit 0

#################
## CONTENT VIEWS (I DONT UNDERSTAND THIS YET)
hammer content-view create --name='rhel-7-server-x86_64-CV' --organization="${ORGANIZATION}"
hammer content-view publish --name="rhel-7-server-x86_64-CV" --organization="${ORGANIZATION}" --async

# NOT EVEN SURE WHAT I NEED TO DO HERE...
LIFECYCLEID=`hammer lifecycle-environment list --organization="${ORGANIZATION}" | grep -v "Library" | awk '{ print $1 }' | head -1`
for LIFECYCLEENV in `hammer lifecycle-environment list --organization="${ORGANIZATION}" | awk '{ print $1 }' | grep -v Library`
do 
  hammer content-view version promote --organization="${ORGANIZATION}"  --to-lifecycle-environment=${LIFECYCLEENV} --id=${LIFECYCLEID} --async
done

#################
## HOST COLLECTION AND ACTIVATION KEYS
hammer host-collection create --name='RHEL 7 x86_64' --organization="${ORGANIZATION}"
hammer activation-key create --description='DEV Activation Key' --name='rhel-7-server-x86_64-key-DEV' --lifecycle-environment='DEV' --organization="${ORGANIZATION}"
hammer activation-key create --description='TEST Activation Key' --name='rhel-7-server-x86_64-key-TEST' --lifecycle-environment='TEST' --organization="${ORGANIZATION}"
hammer activation-key create --description='PROD Activation Key' --name='rhel-7-server-x86_64-key-PROD' --lifecycle-environment='PROD' --organization="${ORGANIZATION}"
hammer activation-key add-host-collection --name='rhel-7-server-x86_64-key-DEV' --host-collection='RHEL 7 x86_64' --organization="${ORGANIZATION}"
hammer activation-key add-host-collection --name='rhel-7-server-x86_64-key-TEST' --host-collection='RHEL 7 x86_64' --organization="${ORGANIZATION}"
hammer activation-key add-host-collection --name='rhel-7-server-x86_64-key-PROD' --host-collection='RHEL 7 x86_64' --organization="${ORGANIZATION}"
# OSE Activation Key (Contract: 10169796)
hammer activation-key create --description='OSEv3 Library Activation Key' --name='OSEv3-Library' --lifecycle-environment='Library' --organization="${ORGANIZATION}"
hammer activation-key add-host-collection --name='OSEv3-Library' --host-collection='RHEL 7 x86_64' --organization="${ORGANIZATION}"

## ASSOCIATE KEYS AND SUBSCRIPTIONS
for i in $(hammer --csv activation-key list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do for j in $(hammer --csv subscription list --organization="${ORGANIZATION}" | awk -F, {'print $8'} | grep -vi '^ID'); do hammer activation-key add-subscription --id ${i} --subscription-id ${j}; done; done

exit 0

## HELPFUL LINKS
https://rh7sat6.matrix.lab/foreman_tasks/task?search=state+=+paused
https://rh7sat6.matrix.lab/foreman_tasks/tasks?search=state+=+planned
https://rh7sat6.matrix.lab/foreman_tasks/tasks?search=result+=+pending

#################
## DOCKER STUFF

hammer product create --name='Containers' --organization="${ORGANIZATION}"
hammer repository create --name='Red Hat Containers' --organization="${ORGANIZATION}" --product='Containers' --content-type='docker' --url='https://registry.access.redhat.com' --docker-upstream-name='rhel' --publish-via-http="true"
hammer product synchronize --organization='MATRIX Labs' --name='Containers'

# Add a Compute Resource
hammer compute-resource create --organizations 'MATRIX Labs' --locations 'Laptop Lab' --provider docker --name rh7ose01.matrix.lab --url http://rh7ose01.matrix.lab:4243
hammer compute-resource create --organizations 'MATRIX Labs' --locations 'Laptop Lab' --provider docker --name rh7ose02.matrix.lab --url http://rh7ose02.matrix.lab:4243

hammer repository info --id `hammer repository list --content-type docker --organization 'MATRIX Labs' --content-view "Production Registry" --environment Production | grep docker | grep rhel | awk '{print $1}'`

# Publish from external repo
hammer docker container create \
--organizations 'MATRIX Labs' \
--locations 'Laptop Lab' \
 --compute-resource rh7ose01.matrix.lab \
--repository-name rhel \
--tag latest \
--name test \
--command bash

# Create Content View, Add Repo and Publish
hammer content-view create --organization="${ORGANIZATION}" --name "Production Registry" --description "Production Registry"
hammer content-view add-repository --organization="${ORGANIZATION}" --name "Production Registry" --repository "rhel" --product "Containers"
hammer content-view publish --organization="${ORGANIZATION}" --name "Production Registry"

#Promote Content View
hammer content-view version promote --organization="${ORGANIZATION}" --to-lifecycle-environment Development --content-view "Production Registry" --async
hammer content-view version promote --organization="${ORGANIZATION}" --to-lifecycle-environment QA --content-view "Production Registry" --async
hammer content-view version promote --organization="${ORGANIZATION}" --to-lifecycle-environment Production --content-view "Production Registry" --async


##################################
##   Red Hat IDM Integration
## If you don't know what this, you probably should not proceed with any of this...

yum -y install ipa-client foreman-proxy ipa-admintools
ipa-client-install --password='Passw0rd'
foreman-prepare-realm admin 
