DOMAIN=`hostname -d`
CLOUDDOMAIN="cloudapps.${DOMAIN}"
echo "$DOMAIN $CLOUDDOMAIN"

# NOTE:  This is basically intended to be run on rh7osemst01 (with the resultant
#          updates to be distributed to other master nodes, and then the OSE 
#          service restarted.

for NODE in `egrep 'oseinf|osenod|osemst' ./hosts`
do 
  ssh-copy-id $NODE
done

######################### ######################### #########################
# Customize Login Page (webUI)
######################### ######################### #########################
oadm create-login-template > /etc/origin/master/login-template.html
# I'm not smart enough to script this
#  cp /etc/origin/master/master-config.yaml /etc/origin/master/master-config.yaml-`date +%F`
# vi /etc/origin/master/master-config.yaml
#oauthConfig:
#  ...
#  templates:
#    login: /etc/origin/master/login-template.html
# for NODE in `grep rh7osemst hosts | grep -v mst01`; do scp /etc/origin/master/login-template.html $NODE:/etc/origin/master/login-template.html; done

######################### ######################### #########################
# Create Certificate for OSE Router(s)
######################### ######################### #########################
CERTPATH=/etc/origin/master/
oadm ca create-server-cert --signer-cert=${CERTPATH}ca.crt \
  --signer-key=${CERTPATH}ca.key --signer-serial=${CERTPATH}ca.serial.txt \
  --hostnames="*.${CLOUDDOMAIN}" \
  --cert=${CERTPATH}${CLOUDDOMAIN}.crt --key=${CERTPATH}${CLOUDDOMAIN}.key

cat ${CERTPATH}${CLOUDDOMAIN}.crt ${CERTPATH}${CLOUDDOMAIN}.key ${CERTPATH}ca.crt > ${CERTPATH}${CLOUDDOMAIN}.pem

######################### ######################### #########################
# Registry
######################### ######################### #########################
# REGISTRY(S)
##   Method 1 - non-persistent
oadm registry --create --service-account=registry \
    --config=/etc/origin/master/admin.kubeconfig \
    --credentials=/etc/origin/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' \ 
    --selector='region=infra'

# Method 1.a - persistent with PV/PVC
oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim --name=registryvol

#   Method 1.b - persistent w/NFS
#  Add the NFS volume
# Clean out the existing NFS share... on NFS server
# rm -rf /exports/nfs/pvs/registry/* 
oc volume deploymentconfigs/docker-registry \
 --add --overwrite --name=registry-storage \
 --mount-path=/registry \
 --source='{"nfs": { "server": "10.10.10.3", "path":"/exports/nfs/registry"}}'

# Set the registry IP to a fixed address that is easy to reference (restart OSE)
REGISTRY_IP=172.30.0.2
TMPFILE=$(mktemp)
oc get svc docker-registry -n default -o yaml | sed -re "/(cluster|portal)IP:/s/:\s+[0-9.]+$/: ${REGISTRY_IP}/" > $TMPFILE || exit 1
# Have to use delete/create since IP address is immutable attribute
oc delete svc docker-registry -n default
oc create -f $TMPFILE
rm -f $TMPFILE
systemctl restart atomic-openshift-master-*

###################### ###################### ######################
# Expose/Secure the Registry 
###################### ###################### ######################
REGIP=`oc get service docker-registry | grep docker-registry | awk '{ print $2 }'`
CERTPATH=/etc/origin/master
EXTREGISTRY="registry.${CLOUDDOMAIN}"
# NOTE:  I may need/want to figure out how to add the external IPs to this command also
oadm ca create-server-cert --signer-cert=${CERTPATH}/ca.crt \
  --signer-key=${CERTPATH}/ca.key --signer-serial=${CERTPATH}/ca.serial.txt \
  --hostnames="docker-registry.default.svc.cluster.local,${EXTREGISTRY},${REGIP}" \
  --cert=${CERTPATH}/registry.crt --key=${CERTPATH}/registry.key

cat ${CERTPATH}/registry.crt ${CERTPATH}/registry.key > ${CERTPATH}/registry.pem

for MASTER in `grep mst hosts | grep -v mst01`; do scp ${CERTPATH}/registry.* ${MASTER}:${CERTPATH}/; done

# Display Cert content
openssl x509 -in ${CERTPATH}/registry.pem -text | grep DNS
  
oc secrets new registry-secret ${CERTPATH}/registry.crt ${CERTPATH}/registry.key
oc secrets add serviceaccounts/default secrets/registry-secret
oc volume dc/docker-registry --add --type=secret \
    --secret-name=registry-secret -m /etc/secrets
sleep 20
#  You now need to update the dc:docker-registry to set livenessProbe:httpGet:scheme: HTTP (to HTTPS)
# oc edit dc docker-registry

oc env dc/docker-registry \
    REGISTRY_HTTP_TLS_CERTIFICATE=/etc/secrets/registry.crt \
    REGISTRY_HTTP_TLS_KEY=/etc/secrets/registry.key
# wait until registry is redeployed (check oc get all)
# watch -n5 "oc get all"
sleep 10
oc exec -i -t -p `oc get pods | grep ^docker-registry | awk '{ print $1 }' ` ls /etc/secrets
# Confirm it is secure
oc log `oc get pods | grep ^docker-registry | awk '{ print $1 }' ` | grep tls

# Place certs in Docker directory and Copy certs to all the Docker nodes...
mkdir /etc/docker/certs.d/docker-registry.default.svc.cluster.local:5000/
mkdir /etc/docker/certs.d/`oc get service | grep registry | awk '{ print $2":"$4 }' | sed 's/\/TCP//g'`
#mkdir /etc/docker/certs.d/${EXTREGISTRY}:5000/
Passw0rd
chmod 755 /etc/docker/certs.d/*:5000/
cp /etc/origin/master/ca.crt /etc/docker/certs.d/`oc get service | grep registry | awk '{ print $2":"$4 }' | sed 's/\/TCP//g'`  
cp /etc/origin/master/ca.crt /etc/docker/certs.d/docker-registry.default.svc.cluster.local:5000/
#cp /etc/origin/master/ca.crt /etc/docker/certs.d/${EXTREGISTRY}:5000/
for NODE in `egrep 'oseinf|osenod|osemst' ./hosts | grep -v mst01`
do
  rsync -tugrpolvv /etc/docker/certs.d/`oc get service | grep registry | awk '{ print $2":"$4 }' | sed 's/\/TCP//g'` ${NODE}:/etc/docker/certs.d/
  rsync -tugrpolvv /etc/docker/certs.d/docker-registry.default.svc.cluster.local:5000 ${NODE}:/etc/docker/certs.d/
#  rsync -tugrpolvv /etc/docker/certs.d/${EXTREGISTRY}:5000 ${NODE}:/etc/docker/certs.d/
done
  
# Remove the insecure-registry from /etc/sysconfig/docker
for NODE in `egrep 'oseinf|osenod|osemst' ./hosts`
do
  #ssh $NODE 'sed -i "s/--insecure-registry=172.30.0.0\/16//" /etc/sysconfig/docker; systemctl daemon-reload; systemctl restart docker'
  ssh $NODE "systemctl daemon-reload; systemctl restart docker"
done

######################### ######################### #########################
# Router
#  NOTE:  You need a registry before you can create the router
######################### ######################### #########################
# Create a PEM file from your cert, key and intermediate cert (alphassl)
cat ${CERTPATH}/star_cloudapps_linuxrevolution_com.crt ${CERTPATH}/star_cloudapps_linuxrevolution_com.key > ${CERTPATH}${CLOUDDOMAIN}.pem
oadm router harouter --stats-password='Passw0rd' --replicas=2 \
  --default-cert=${CERTPATH}/star_cloudapps_linuxrevolution_com.pem \
  --config=/etc/origin/master/admin.kubeconfig  \
  --credentials='/etc/origin/master/openshift-router.kubeconfig' \
  --images='registry.access.redhat.com/openshift3/ose-haproxy-router:latest' \
  --selector='region=infra,zone=default' --service-account=router
  
######################### ######################### #########################
# Expose Registry
######################### ######################### #########################
EXTREGISTRY="registry.${CLOUDDOMAIN}"
mkdir -p ~/Projects/Registry; cd $_
cat << EOF > expose-registry.json
apiVersion: v1
kind: Route
metadata:
  name: registry
spec:
  host: $EXTREGISTRY
  to:
    kind: Service
    name: docker-registry 
  tls:
    termination: passthrough
EOF
oc create -f ./expose-registry.json

CERTPATH=/etc/origin/master/
mkdir /etc/docker/certs.d/${EXTREGISTRY}; chmod 755 $_
cp ${CERTPATH}registry.crt ${CERTPATH}registry.key /etc/docker/certs.d/${EXTREGISTRY}
for NODE in `egrep 'oseinf|osenod|osemst' ./hosts`
do
  rsync -tugrpolvv /etc/docker/certs.d/${EXTREGISTRY} ${NODE}:/etc/docker/certs.d/
  ssh ${NODE} "systemctl daemon-reload; systemctl restart docker"
done

##########################
# Declare PVs/PVCs on Master for *whatever*
##########################
mkdir /root/pvs
export volsize="1Gi"
for volume in pv{1..2} ; do
cat << EOF > /root/pvs/${volume}
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "${volume}"
  },
  "spec": {
    "capacity": {
        "storage": "${volsize}"
    },
    "accessModes": [ "ReadWriteOnce" ],
    "nfs": {
        "path": "/exports/nfs/pvs/${volume}",
        "server": "192.168.122.1"
    },
    "persistentVolumeReclaimPolicy": "Recycle"
  }
}
EOF
echo "Created def file for ${volume}";
done
cd /root/pvs
cat pv{1..2} | oc create -f - -n default

######################### ######################### ######################### 
# PROJECT RESOURCE MANAGEMENT
######################### ######################### ######################### 
oadm new-project resourcemanagement --display-name="Resources Management" \
    --description="resource management project" \
    --admin=morpheus --node-selector='region=primary'
oc policy add-role-to-user admin morpheus -n resourcemanagement

# QUOTAS
cat << EOF > quota.json
{
  "apiVersion": "v1",
  "kind": "ResourceQuota",
  "metadata": {
    "name": "test-quota"
  },
  "spec": {
    "hard": {
      "memory": "1Gi",
      "cpu": "20",
      "pods": "3",
      "services": "5",
      "replicationcontrollers":"5",
      "resourcequotas":"1"
    }
  }
}
EOF
oc create -f quota.json --namespace=resourcemanagement

# LIMITS
cat << EOF > limits.json
{
    "kind": "LimitRange",
    "apiVersion": "v1",
    "metadata": {
        "name": "limits",
        "creationTimestamp": null
    },
    "spec": {
        "limits": [
            {
                "type": "Pod",
                "max": {
                    "cpu": "500m",
                    "memory": "750Mi"
                },
                "min": {
                    "cpu": "10m",
                    "memory": "5Mi"
                }
            },
            {
                "type": "Container",
                "max": {
                    "cpu": "500m",
                    "memory": "750Mi"
                },
                "min": {
                    "cpu": "10m",
                    "memory": "5Mi"
                },
                "default": {
                    "cpu": "100m",
                    "memory": "100Mi"
                }
            }
        ]
    }
}
EOF
oc create -f limits.json --namespace=resourcemanagement

# DISPLAY SETTINGS
oc get quota -n resourcemanagement 
oc describe quota test-quota -n resourcemanagement
oc describe limitranges limits -n resourcemanagement

su - morpheus 
oc login -u morpheus --insecure-skip-tls-verify --server=https://rh7osemst01.matrix.lab:8443
oc project resourcemanagement
mkdir -p ~/proeject/resourcemanagement/; cd $_

cat <<EOF > hello-pod.json
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "hello-openshift",
    "creationTimestamp": null,
    "labels": {
      "name": "hello-openshift"
    }
  },
  "spec": {
    "containers": [
      {
        "name": "hello-openshift",
        "image": "openshift/hello-openshift:v0.4.3",
        "ports": [
          {
            "containerPort": 8080,
            "protocol": "TCP"
          }
        ],
        "resources": {
          "limits": {
            "cpu": "10m",
            "memory": "16Mi"
          }
        },
        "terminationMessagePath": "/dev/termination-log",
        "imagePullPolicy": "IfNotPresent",
        "capabilities": {},
        "securityContext": {
          "capabilities": {},
          "privileged": false
        },
        "nodeSelector": {
          "region": "primary"
        }
      }
    ],
    "restartPolicy": "Always",
    "dnsPolicy": "ClusterFirst",
    "serviceAccount": ""
  },
  "status": {}
}
EOF
oc create -f hello-pod.json -n resourcemanagement

######################
# GIT Quicky
######################
echo "# matrix.lab" >> README.md
git init
git add README.md
git commit -m "first commit"
git remote add origin https://github.com/jradtke-rh/matrix.lab.git
git push -u origin master


################################################################################
for ITEM in nodes pods services ; do echo "## $ITEM"; oc get $ITEM; echo; done
for ITEM in rc dc bc; do echo "## $ITEM"; oc get $ITEM; echo; done
for ITEM in projects templates; do echo "## $ITEM"; oc get $ITEM; done
for ITEM in sa; do echo "## $ITEM"; oc get $ITEM; done
for ITEM in pv pvc; do echo "## $ITEM"; oc get $ITEM; done

# for i in buildconfig deploymentconfig service; do echo $i; oc get $i; echo -e "\n\n"; done
# oc get all
# oc get services
# oc get pods
# oc get rc
# oc get nodes
# oc logs docker-registry-1-deploy
# oc get enpoints 
# oc get hostsubnet 
