#!/bin/bash

RHNUSER=""
RHNPASSWD=""
ORGANIZATION=""
SATVERSION="6.1"
SATELLITE="rh7sat6"
DOMAIN="matrix.lab"

# Log the output of the script
LOG="./${0}.log"
exec > ${LOG}
exec 2>&1

echo "NOTE: you may view the output by viewing - ${LOG}"
rpm -qa tuned || yum -y install tuned
tuned-adm profile virtual-guest
systemctl enable tuned 

# If installing from CD (Sat 6.1), then manually import this key before starting...
#rpm --import https://www.redhat.com/security/f21541eb.txt

subscription-manager register --username="${RHNUSER}" --password="${RHNPASSWD}"

subscription-manager list --available --all > /var/tmp/subscription-manager_list--available--all.out
POOL=`grep -A15 "Red Hat Satellite 6" /var/tmp/subscription-manager_list--available--all.out | grep "Pool ID:" | awk -F: '{ print $2 }' | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'`
subscription-manager repos --disable "*"
subscription-manager repos > /var/tmp/subscription-manager_repos.out

uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager release --set=$RELEASE

case $RELEASE in 
  7Server) 
    subscription-manager repos --disable=*; subscription-manager repos --enable rhel-7-server-rpms --enable rhel-server-rhscl-7-rpms --enable rhel-7-server-satellite-${SATVERSION}-rpms --enable rhel-7-server-satellite-optional-${SATVERSION}-rpms  
  ;;
  6Server)
    subscription-manager repos --enable rhel-6-server-rpms --enable rhel-server-rhscl-6-rpms --enable rhel-6-server-satellite-${SATVERSION}-rpms --enable rhel-6-server-satellite-optional-${SATVERSION}-rpms
  ;;
esac

yum -y install ntp
# Figure out how to make this dynamic
sed -i -e 's/restrict ::1/restrict ::1\nrestrict 192.168.122.0 netmask 255.255.255.0 nomodify notrap/g' /etc/ntp.conf

case $RELEASE in 
  7Server) 
    systemctl disable chronyd && systemctl stop chronyd
    systemctl enable ntpd && systemctl start ntpd
  ;;
  6Server)
    chkconfig ntpd on && service ntpd start
  ;;
esac

# Firewall Ports required for Satellite functionality
TCP_PORTS="80 123 443 5671 5674 8080 8140 9090" 
UDP_PORTS="53 67 68 69 80 123 443 8080"
SVCS="ntp"
case $RELEASE in
  7Server)
    echo "`hostname -I` `hostname` `hostname -s` " >> /etc/hosts
    DEFAULT_ZONE=`/bin/firewall-cmd --get-default-zone`
    for SVC in $SVCS
    do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-service=${SVC}
    done
    for PORT in $TCP_PORTS
    do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/tcp
    done
    for PORT in $UDP_PORTS
    do
      /bin/firewall-cmd --permanent --zone=$DEFAULT_ZONE --add-port=${PORT}/udp
    done

    # The following is part of the Installation Doc (not exactly certain what they are for)
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
    echo "`hostname -i` `hostname` `hostname -s` " >> /etc/hosts
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

yum -y install katello
katello-installer

mkdir ~/.hammer ~/.foreman
chmod 0600 ~/.hammer
cat << EOF > ~/.hammer/cli_config.yml
:modules:
    - hammer_cli_foreman

:foreman:
    :enable_module: true
    :host: 'https://${SATELLITE}.${DOMAIN}'
    :username: 'satadmin'
    :password: 'Passw0rd'
    :organization: '${ORGANIZATION}'

    # Check API documentation cache status on each request
    #:refresh_cache: false

    # API request timeout. Set to -1 for no timeout
    #:request_timeout: 120 #seconds

:log_dir: '~/.foreman/log'
:log_level: 'error'
EOF

hammer product create --name='EPEL' --organization="${ORGANIZATION}"
hammer repository create --name='EPEL 7 - x86_64' --organization="${ORGANIZATION}" --product='EPEL' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/

for i in $(hammer --csv repository list --organization="${ORGANIZATION}" | awk -F, {'print $1'} | grep -vi '^ID'); do echo "hammer repository synchronize --id ${i} --organization="${ORGANIZATION}" --async"; done

# Add the oSCAP functionality
yum install ruby193-rubygem-foreman_openscap
systemctl restart foreman 

exit 0
== Good to know links
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=state+=+paused
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=state+=+planned
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=result+=+pending

== TODO
make sure the entire process is scripted: 
  register host
  create Organization
  import channels
  create Lifecycle Env
