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
######################### ######################### #########################
# Registry
######################### ######################### #########################
# REGISTRY(S)
##   Method 1 - non-persistent
oadm registry --create \
    --config=/etc/openshift/master/admin.kubeconfig \
    --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

# Method 1.1 - persistent with PV/PVC
oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim --name=registryvol

##   Method 2 - persistent w/NFS
oadm registry --create --service-account=registry \
    --config=/etc/openshift/master/admin.kubeconfig \
    --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' \
    --selector='region=infra'

#  Clean out the existing NFS share... on NFS server
# rm -rf /exports/nfs/pvs/registry/* 
oc volume deploymentconfigs/docker-registry \
 --add --overwrite --name=registry-storage \
 --mount-path=/registry \
 --source='{"nfs": { "server": "192.168.122.1", "path":"/exports/nfs/pvs/registry"}}'

######################
# Registry (Secure)
######################
REGIP=`oc get service docker-registry | grep docker-registry | awk '{ print $2 }'`
CERTPATH=/etc/openshift/master/
oadm ca create-server-cert --signer-cert=${CERTPATH}ca.crt \
  --signer-key=${CERTPATH}ca.key --signer-serial=${CERTPATH}ca.serial.txt \
  --hostnames='docker-registry.default.svc.cluster.local,${REGIP}' \
  --cert=${CERTPATH}registry.crt --key=${CERTPATH}registry.key
oc secrets new registry-secret ${CERTPATH}registry.crt ${CERTPATH}registry.key
oc secrets add serviceaccounts/default secrets/registry-secret
oc volume dc/docker-registry --add --type=secret \
    --secret-name=registry-secret -m /etc/secrets
sleep 20
oc env dc/docker-registry \
    REGISTRY_HTTP_TLS_CERTIFICATE=/etc/secrets/registry.crt \
    REGISTRY_HTTP_TLS_KEY=/etc/secrets/registry.key
POD=`oc get pods | grep ^docker-registry | awk '{ print $1 }'`
# wait until registry is redeployed (check oc get all)
sleep 10
oc -it -p $POD exec ls /etc/secrets # this doesn't work for some reason....

######################### ######################### #########################
# Router
#  NOTE:  You need a registry before you can create the router
######################### ######################### #########################
oadm router harouter --stats-password='Passw0rd' --replicas=2 \
  --config=/etc/openshift/master/admin.kubeconfig  \
  --credentials='/etc/openshift/master/openshift-router.kubeconfig' \
  --images='registry.access.redhat.com/openshift3/ose-haproxy-router:v3.0.0.1' \
  --selector='region=infra' --service-account=router

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

######################
# PROJECT (S2I Build)
######################
# On Master
#  Simple Sinatra using source
MYPROJ='hello-s2i'
oadm new-project ${MYPROJ} --display-name="Hello Source2Image" \
    --description="This project is for Source to Image builds" \
      --node-selector='region=primary' --admin=oseuser
# Since I have now "plumbed my ENV to AD"....
#oc policy add-role-to-user admin 'CN=OSE User,CN=Users,DC=aperture,DC=lab' -n hello-s2i
oc policy add-role-to-user admin 'oseuser' -n hello-s2i

su - oseuser
oc login -u oseuser -p Passw0rd --insecure-skip-tls-verify --server=https://rh7osemst01.aperture.lab:8443
MYPROJ='hello-s2i'
mkdir -p ~/Projects/${MYPROJ}; cd $_
oc project ${MYPROJ}
oc new-app https://github.com/openshift/simple-openshift-sinatra-STI.git -o json | tee ./simple-sinatra.json
oc create -f ./simple-sinatra.json -n ${MYPROJ}
oc build-logs `oc get builds | grep sinatra | awk '{ print $1 }'`

curl http://`oc get services | grep sinatra | awk '{ print $2":"$4 }' | cut -f1 -d\/`

oc expose service simple-openshift-sinatra \
  --hostname=mysinatra.cloudapps.aperture.lab
# If you want to manage the route, run...
# oc edit route 
# http://mysinatra.cloudapps.aperture.lab/

# IF... you want to use ssh-keys and/or a specific .gitconfig
# JUST .gitconfig
mkdir 
mkdir -p ~/Projects/${MYPROJ}; cd $_
cat << EOF > ./.gitconfig
[http]
      sslVerify=false
EOF
oc secrets new mygitconfig .gitconfig=~/Projects/${MYPROJ}/.gitconfig 
oc secrets add serviceaccount/builder secrets/mygitconfig

# JUST sshkey
ssh-keygen -trsa -b2048 -N '' -i ~/Projects/${MYPROJ}/.ssh/id_rsa 
oc secrets new-sshauth mysshkey --ssh-privatekey=~/Projects/${MYPROJ}/.ssh/id_rsa 
oc secrets add serviceaccount/builder secrets/mysshkey

# BOTH
oc secrets new-sshauth mysshkey-gitconfig --ssh-privatekey=~/Projects/${MYPROJ}/.ssh/id_rsa --gitconfig=~/Projects/${MYPROJ}/.gitconfig
oc secrets add serviceaccount/builder secrets/mysshkey-gitconfig

oc edit bc
### THEN YOU NEED TO ADD THE FOLLOWING UNDER source:git
  source:
    git: 
      uri: git@github.com/myrepo/project/gitfile.git
>    sourceSecret:
>      name: mysshkey-gitconfig
    type: Git

######################### ######################### ######################### 
# Another S2I
######################### ######################### ######################### 
MYPROJ="ruby-keypair"
oadm new-project ${MYPROJ} --display-name="Demo KeyPair - Ruby Source2Image" \
    --description="OSE Origin Ruby Source to Image example" \
      --node-selector='region=primary' --admin=oseuser

su - oseuser
MYPROJ="ruby-keypair"
oc project ${MYPROJ}
mkdir ~/Templates; cd $_
wget https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json
oc create -f application-template-stibuild.json -n ${MYPROJ}
mkdir -p ~/Projects/${MYPROJ}; cd $_

oc process ruby-helloworld-sample -n ${MYPROJ} -o json > ruby-helloworld-sample
sed -i -e 's/www.example.com/ruby-keypair.cloudapps.aperture.lab/g' ruby-helloworld-sample
oc create -f ruby-helloworld-sample
# wait a tic... then go to...
# https://ruby-keypair.cloudapps.aperture.lab:443/

######################### ######################### ######################### 
# PROJECT RESOURCE MANAGEMENT
######################### ######################### ######################### 
oadm new-project resourcemanagement --display-name="Resources Management" \
    --description="resource management project" \
    --admin=oseuser --node-selector='region=primary'
oc policy add-role-to-user admin oseuser -n resourcemanagement

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

su - oseuser 
oc login -u oseuser --insecure-skip-tls-verify --server=https://rh7osemst01.aperture.lab:8443
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
# Ticketmonster
######################
oadm new-project ticketmonster --display-name="Ticketmonster" \
    --description='A demonstration of a Ticketmonster' \
    --node-selector='region=primary' --admin=oseuser

git clone https://github.com/jboss-developer/ticket-monster/

######################
# Quickstart
######################
oadm new-project quickstart --display-name="Quickstart" \
    --description='A demonstration of a "quickstart/template"' \
    --node-selector='region=primary' --admin=oseuser

mkdir Templates; cd $_
wget http://www.opentlc.com/download/ose_implementation/resources/Template_Example.json
oc create -f Template_Example.json -n openshift

######################
# Templates Example
######################
MYPROJ=wiring 
oadm new-project $MYPROJ --display-name='Wiring' \
    --description='A demonstration of wiring components together' \
    --node-selector='region=primary' --admin=oseuser
su - oseuser
mkdir -p Project/$MYPROJ; cd $_
oc project $MYPROJ
oc new-app -i openshift/ruby https://github.com/openshift/ruby-hello-world#beta4
oc get build
oc get buildconfig
oc get dc 
oc env dc/ruby-hello-world MYSQL_USER=root MYSQL_PASSWORD=redhat MYSQL_DATABASE=mydb
oc env dc/ruby-hello-world --list
oc expose service \
  --name=frontend-route ruby-hello-world \
  --hostname="frontwire.cloudapps.aperture.lab"
oc get route
mkdir -p Templates/; cd $_
wget http://www.opentlc.com/download/ose_implementation/resources/mysql_template.json
oc create -f mysql_template.json
# Create msyql by CLI
# See if DB responds	
curl `oc get services | egrep 'database|mysql' | awk '{print $2}'`:3306
# See which node(s) Mysql is running on
oc get pod -t '{{range .items}}{{.metadata.name}} {{.spec.host}}{{"\n"}}{{end}}' | grep ruby-hello-world|awk '{print $2}'
######################
# PROJECT (Binary Deployment) -- This is pretty hosed... :-(
######################
# PRE
# fork https://github.com/JaredBurck/ose-team-ex-3 to https://github.com/jradtke-rh/ose-team-ex-3
# clone the repo
# add a Dockerfile 
oc new-project petstore --description="Petstore Example"
oc policy add-role-to-user admin oseuser -n petstore 
su - oseuser
oc login -u oseuser --insecure-skip-tls-verify --server=https://rh7osemst01.aperture.lab:8443
oc project petstore 
mkdir -p projects/petstore && cd $_
git clone http://github.com/jradtke-rh/petstore.git
cd petstore
cat << EOF > ./Dockerfile
FROM registry.access.redhat.com/jboss-eap-6/eap-openshift:6.4
EXPOSE 8080 8888
RUN curl https://github.com/jradtke-rh/ose-team-ex-3/blob/master/deployments/jboss-helloworld.war -o \$JBOSS_HOME/standalone/deployments/ROOT.war
#RUN curl https://github.com/jradtke-rh/ose-team-ex-3/blob/master/deployments/ticket-monster.war -o \$JBOSS_HOME/standalone/deployments/ROOT.war
EOF
git commit -m "Adding Dockerfile" Dockerfile && git push
cd -
oc new-app https://github.com/jradtke-rh/petstore.git --name=petstore
curl `oc get services | grep petstore | awk '{ print $2":"$4 }' | cut -f1 -d\/`
oc expose service petstore --hostname=petstore.cloudapps.aperture.lab
oc exec -it -p petstore-1-build /bin/bash # This doesn't work since it is a privileged container, or something...

######################
# GIT Quicky
######################
echo "# matrix.lab" >> README.md
git init
git add README.md
git commit -m "first commit"
git remote add origin https://github.com/jradtke-rh/matrix.lab.git
git push -u origin master

