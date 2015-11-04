#!/bin/bash
# This is a portion of 
# https://github.com/rhtconsulting/rhc-ose/blob/openshift-enterprise-3/provisioning/osc-install
####  
# I HAD TO ADD THIS TO MAKE IT WORK

OPENSHIFT_CLOUDAPPS_SUBDOMAIN="cloudapps"
OPENSHIFT_BASE_DOMAIN=`hostname -d`
SSH_CMD="/usr/bin/ssh"
SCP_CMD="/usr/bin/scp"
NODE_HOSTNAMES="rh7oseinf01 rh7oseinf02 rh7osenod01 rh7osenod02"
SCRIPT_BASE_DIR"./"

mkdir templates
cat << EOF > templates/registry-route.json
{
  "kind": "Route",
  "apiVersion": "v1",
  "metadata": {
    "name": "registry",
    "namespace": "default",
    "labels": {
      "{{SERVICE_NAME}}": "default"
    }
  },
  "spec": {
    "host": "{{HOSTNAME}}",
    "to": {
      "kind": "Service",
      "name": "{{SERVICE_NAME}}"
    },
    "tls": {
      "termination": "passthrough"
    }
  },
  "status": {}
}
EOF

process_template() {
  local template_file=$1
  shift
  local vars=$@
  local output="$(cat $template_file)"

  for var in $vars; do
    value=${!var}
    echo "${value}" > /tmp/${var}
    output=$(echo "$output" | perl -pe "s/{{$var}}/${value}/g")
  done

  echo "$output"
}
# END OF ADDED SECTION
####  

  CA=/etc/openshift/master

  # First, a bit of cleanup so we can re-run and update things
  for resource in service deploymentConfig pod route serviceaccount secret; do
    resource_names=$(oc get $resource | awk '/registry/ {print $1}')
    for name in ${resource_names/'\n'/ }; do
      echo "oc delete $resource $name"
      oc delete $resource $name
    done
  done

  # Create registry
  echo "mkdir -p /mnt/registry"
  mkdir -p /mnt/registry

  echo '{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"registry"}}' | oc create -f -
  echo "oc get scc privileged -o yaml > priv.yaml"
  oc get scc privileged -o yaml > priv.yaml
  if [ $(grep -c 'system:serviceaccount:default:registry' priv.yaml) -eq 0 ]; then
    echo '- system:serviceaccount:default:registry' >> priv.yaml
    oc replace scc privileged -f priv.yaml
  fi

  created_resources=$(oadm registry --service-account=registry \
  --config=/etc/openshift/master/admin.kubeconfig \
  --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
  --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' \
  --selector='region=infra' \
  --mount-host=/mnt/registry)

  service_name=$(echo "${created_resources}" | awk -F'/' '/services/ {print $2}')
  dc_name=$(echo "${created_resources}" | awk -F'/' '/deploymentconfigs/ {print $2}')
  service_ip=$(oc get service $service_name | awk '/registry/ {print $2}')

  # Secure the Registry
  oadm ca create-server-cert --signer-cert=$CA/ca.crt \
    --signer-key=$CA/ca.key \
    --signer-serial=$CA/ca.serial.txt  \
    --hostnames="registry.${OPENSHIFT_CLOUDAPPS_SUBDOMAIN}.${OPENSHIFT_BASE_DOMAIN},docker-registry.default.svc.cluster.local,${service_ip}"\
    --cert=$CA/registry.crt --key=$CA/registry.key

  oc secrets new registry-secret $CA/registry.crt $CA/registry.key

  oc secrets add serviceaccounts/registry secrets/registry-secret

  oc volume deploymentConfig/$dc_name --add --type=secret --secret-name=registry-secret -m /etc/secrets

  oc env deploymentConfig/$dc_name REGISTRY_HTTP_TLS_CERTIFICATE=/etc/secrets/registry.crt REGISTRY_HTTP_TLS_KEY=/etc/secrets/registry.key

  # Trust certs from all nodes
  certs_dirs="/etc/docker/certs.d/$service_ip:5000 /etc/docker/certs.d/docker-registry.default.svc.cluster.local:5000"
  for node in ${NODE_HOSTNAMES//,/ }; do
    for dir in $certs_dirs; do
      echo "$SSH_CMD $node \"mkdir -p $dir\" "
      #$SSH_CMD $node "mkdir -p $dir"
      echo "$SCP_CMD $CA/ca.crt $node:$dir"
      #$SCP_CMD $CA/ca.crt $node:$dir
    done
    echo "$SSH_CMD $node \"systemctl daemon-reload && systemctl restart docker && systemctl restart openshift-node\" "
  done

  # Create Route for External Access
  SERVICE_NAME=$service_name
  HOSTNAME=registry.${OPENSHIFT_CLOUDAPPS_SUBDOMAIN}.${OPENSHIFT_BASE_DOMAIN}
  route_resource=$(process_template ${SCRIPT_BASE_DIR}/templates/registry-route.json SERVICE_NAME HOSTNAME )

  echo "$route_resource" | oc create -f -
