#!/bin/bash

#  USER-CONFIGURABLE STUFF HERE....
SATELLITE="rh7sat6"

# Determine which lab environment we're in...
DOMAIN=`hostname -d`
case $DOMAIN in
  'matrix.lab')
    ORGANIZATION="MATRIXLABS"
  ;;
  'aperture.lab')
    ORGANIZATION="APERTURELABS"
  ;;
  *)
    echo "ERROR: domain not recognized..."
    echo "[can|should] not proceed"
    exit 9
  ;;
esac

# NOTE:  need to update this to allow it to be run numerous times (i.e. check whether a condition exists, then update if neccessary)

subscription-manager clean
yum -y localinstall http://${SATELLITE}.${DOMAIN}/pub/katello-ca-consumer-latest.noarch.rpm
case `hostname -s` in 
  rh7ose*)
    # Lock my OSE hosts at 7.2
    subscription-manager register --activationkey='OSEv3-Library' --org="${ORGANIZATION}" --release=7.2 --force
  ;;
  *)
    echo "NOTE: using username/password for Activation"
    subscription-manager register --org="${ORGANIZATION}" --environment="Library" --username='admin' --password='Passw0rd' --release=7Server  --auto-attach --force
    subscription-manager repos --disable=* --enable rhel-7-server-rpms --enable rhel-7-server-rh-common-rpms --enable rhel-7-server-satellite-tools-6.1-rpms
  ;;
esac

yum -y install katello-agent
katello-package-upload 

# Add fstab entry to bind-mount /var/tmp over /tmp -- for STIG compliance
#echo "# bind mount for /var/tmp" >> /etc/fstab
#echo "/tmp /var/tmp none	bind" >> /etc/fstab

# Update sudoers to allow NOPASSWD for group:wheel
sed -i -e 's/^%wheel/##%wheel/g' /etc/sudoers
sed -i -e 's/^# %wheel/%wheel/g' /etc/sudoers

id morpheus
case $? in
  0)
    echo "NOTE: User exists"
  ;;
  *)
    /usr/sbin/useradd -u1000 -U -Gwheel -c "Morpheus - local account" -p '$6$YTbEzW.h$aPoQPlRS8HR9CkX6.3m5wO/0aEhnBe1ajOZx7fYM0tggmoX8YWH2Y44cvfaH3Mt3waG9tJzMiGbw5u3Miajlb.' morpheus
    su - morpheus -c "echo | ssh-keygen -trsa -b2048 -N ''"
    echo | ssh-keygen -trsa -b2048 -N ''
cat << EOF >> /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbSrkWSGjq6d2Tq8zhUO9EfnVxAexkvjhzSMh0a92nniLszFxpFE6X71IDi2VdEwQZk5sqURBt/fQ7nuVhJb4oUCtBUfGbMlZV7eSuW83cqwpS1Q60jEpSbKxU9ZV/jXajVmZi4hM6XYZCuJCfHAfEcxBckviJROtvVNqDtR0gRQgz+gm0F4o1qqJvSS76BAgq2nORl7vbL3G+DdOu1PzMADLlQLcKTV4D06WkDfQu2ODYui5QBhmoSkSeFTvtIAsy6Yb2FJCyOpuE71ax+1SRePIQD76D3UYCQXy+g9QPqEcY5jDNOFCirIk2nzSls518yof9BzpWD4EYO73pIzR9 morpheus@seraph.matrix.private
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwr2CZHWa06iOHWPo8wCxKnhQuFNx8xLSX0akLg2pGUCwzZoOf5SFobSi5cFPSvIkUmKVLtdd+3eq52HTz0v3io1ofcd/BCI5EAISM2VmoUGbuHkU5KW8XrNW92YBCdL2paHsAGBmbFdPaI9wTOuZp3z8Mt3UR5uQhAlfUgl6jElBTVHIjlrDhh4QnTQuVAT8nK/3986SChIgNNu5WLNFC4deDMdgNv7ihecFE4mGx3B0zkoZvFjXwPtlZreDCXhpjjE0AhGNacCxixTj2wtMikG9P+MaZWf0bd8fpAjPqjnTPzxHFpyaKGVIxhAibypYUquKaJSQvfrg0Cx/sJloF jradtke@trinity.matrix.private
EOF
    chmod 0600 /root/.ssh/authorized_keys
    restorecon -F /root/.ssh/authorized_keys
  ;;
esac

case `dmidecode -s system-manufacturer` in
  'Red Hat')
    yum -y install tuned
    tuned-adm profile virtual-guest
    subscription-manager repos --enable=rhel-7-server-rhev-mgmt-agent-rpms
    yum -y install rhevm-guest-agent; systemctl enable ovirt-guest-agent; systemctl start $_
  ;;
esac

exit 0
