#!/bin/bash

# Log the output of the script
LOG="./${0}.log"
exec > ${LOG}
exec 2>&1

echo "NOTE: you may view the output by viewing - ${LOG}"
tuned-adm profile virtual-guest
systemctl enable tuned 

# If installing from CD (Sat 6.1), then manually import this key before starting...
#rpm --import https://www.redhat.com/security/f21541eb.txt

subscription-manager register --username=${RHNUSER} --password='RHNPASSWD'

subscription-manager list --available --all > /var/tmp/subscription-manager_list--available--all.out
POOL=`grep -A15 "Red Hat Satellite 6" /var/tmp/subscription-manager_list--available--all.out | grep "Pool ID:" | awk -F: '{ print $2 }' | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'`
subscription-manager repos --disable "*"
subscription-manager repos > /var/tmp/subscription-manager_repos.out

uname -a | grep el6 && RELEASE="6Server" || RELEASE="7Server"
subscription-manager release --set=$RELEASE

case $RELEASE in 
  7Server) 
    # This is a kludge at the moment... 
    #subscription-manager repos --enable rhel-7-server-rpms --enable rhel-server-rhscl-7-rpms 
    subscription-manager repos --enable rhel-7-server-rpms --enable rhel-server-rhscl-7-rpms --enable rhel-7-server-satellite-6.0-rpms --enable rhel-7-server-satellite-optional-6.0-rpms 
    #subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-satellite-6.1-rpms --enable rhel-7-server-satellite-optional-6.1-rpms --enable rhel-server-rhscl-7-rpms 
  ;;
  6Server)
    subscription-manager repos --enable rhel-6-server-rpms --enable rhel-6-server-satellite-6.0-rpms --enable rhel-6-server-satellite-optional-6.0-rpms --enable rhel-server-rhscl-6-rpms 
    chkconfig ntpd on && service ntpd start
  ;;
esac

TCP_PORTS="80 443 5671 5674 8080 8140 9090" 
UDP_PORTS="53 67 68 69 80 443 8080"
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
# I need to revisit customizing the installer answer file
#  It appears that there is an answer file (initially) which is then updated by katello-installer?
#sed -i -e 's/North Carolina/District of Columbia/g' /etc/katello-installer/answers.katello-installer.yaml
#sed -i -e 's/Raliegh/Washington/g' /etc/katello-installer/answers.katello-installer.yaml
katello-installer

mkdir ~/.hammer ~/.foreman
chmod 0600 ~/.hammer
cat << EOF > ~/.hammer/cli_config.yml
:modules:
    - hammer_cli_foreman

:foreman:
    :enable_module: true
    :host: 'https://rh7sat6.matrix.lab'
    :username: 'satadmin'
    :password: 'Passw0rd'
    :organization: 'MATRIX IT Labs'

    # Check API documentation cache status on each request
    #:refresh_cache: false

    # API request timeout. Set to -1 for no timeout
    #:request_timeout: 120 #seconds

:log_dir: '~/.foreman/log'
:log_level: 'error'
EOF

hammer product create --name='EPEL' --organization='MATRIX IT Labs'
hammer repository create --name='EPEL 7 - x86_64' --organization='MATRIX IT Labs' --product='EPEL' --content-type='yum' --publish-via-http=true --url=http://dl.fedoraproject.org/pub/epel/7/x86_64/

for i in $(hammer --csv repository list --organization='MATRIX IT' | awk -F, {'print $1'} | grep -vi '^ID'); do echo "hammer repository synchronize --id ${i} --organization='MATRIX IT' --async"; done

exit 0
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=state+=+paused
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=state+=+planned
https://rh7sat6.matrix.private/foreman_tasks/tasks?search=result+=+pending


