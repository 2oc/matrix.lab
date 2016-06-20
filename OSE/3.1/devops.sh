#  I decided to move all of my "devops" type stuff to this file as it is not
#    part of the installation or configuration of OSE

######################
# PROJECT (S2I Build) - Hello Sinatra Ruby App
#  This particular S2I is boringly simple, but it allows for simple curl to test
######################
# On Master
#  Simple Sinatra using source
MYPROJ='hello-s2i'
oadm new-project ${MYPROJ} --display-name="Hello Source2Image" \
    --description="This project is for Source to Image builds" \
      --node-selector='region=primary' --admin=morpheus
# Since I have now "plumbed my ENV to AD"....
#oc policy add-role-to-user admin 'CN=OSE User,CN=Users,DC=matrix,DC=lab' -n hello-s2i
#oc policy add-role-to-user admin 'morpheus' -n hello-s2i

su - morpheus
oc login -u morpheus -p Passw0rd --insecure-skip-tls-verify --server=https://openshift-cluster.${DOMAIN}:8443
MYPROJ='hello-s2i'
mkdir -p ~/Projects/${MYPROJ}; cd $_
oc project ${MYPROJ}
oc new-app https://github.com/openshift/simple-openshift-sinatra-STI.git -o json | tee ./simple-sinatra.json
oc create -f ./simple-sinatra.json -n ${MYPROJ}
oc build-logs `oc get builds | grep sinatra | head -1 | awk '{ print $1 }'`

curl http://`oc get services | grep sinatra | awk '{ print $2":"$4 }' | cut -f1 -d\/`

oc expose service simple-openshift-sinatra \
  --hostname=mysinatra.cloudapps.matrix.lab
# If you want to manage the route, run...
# oc edit route
# http://mysinatra.cloudapps.matrix.lab/

######################### ######################### #########################
# Another S2I - Ruby Keypair
######################### ######################### #########################
# https://github.com/openshift/origin/tree/master/examples
MYPROJ="ruby-keypair"
oadm new-project ${MYPROJ} --display-name="Demo KeyPair - Ruby Source2Image" \
    --description="OSE Origin Ruby Source to Image example" \
      --node-selector='region=primary' --admin=morpheus

su - morpheus
MYPROJ="ruby-keypair"
oc project ${MYPROJ}
mkdir ~/Templates; cd $_
wget https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json
oc create -f application-template-stibuild.json -n ${MYPROJ}
mkdir -p ~/Projects/${MYPROJ}; cd $_

oc process ruby-helloworld-sample -n ${MYPROJ} -o json > ruby-helloworld-sample
sed -i -e 's/www.example.com/ruby-keypair.cloudapps.linuxrevolution.com/g' ruby-helloworld-sample
oc create -f ruby-helloworld-sample
# wait a tic... then go to...
# https://ruby-keypair.cloudapps.linuxrevolution.com:443/

######################### ######################### #########################
#  PROJECT - S2I build of Sinatra Ruby app for Rock:Paper:Scissor
######################### ######################### #########################
MYPROJ="ruby-sinatra-rps"
oc new-project ${MYPROJ}
mkdir ~/Projects/$_; cd $_
oc new-app https://github.com/jradtke-rh/ruby-sinatra-rps.git -o json | tee ./ruby-sinatra-rps.json

oc create -f ./ruby-sinatra-rps.json
#oc get pods -o wide --watch

echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "ruby-sinatra-rps", "creationTimestamp": null, "labels": { "app": "ruby-sinatra-rps" } }, "spec": { "host": "ruby-sinatra-rps.cloudapps.linuxrevolution.com", "to": { "kind": "Service", "name": "ruby-sinatra-rps" }, "port": { "targetPort": "8080-tcp" }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

######################### ######################### #########################
#  PROJECT - S2I build of PHP App for "Wipeout" type game
######################### ######################### #########################
MYPROJ="hexgl"
oc new-project $MYPROJ
oc new-app php:5.6~https://github.com/jradtke-rh/HexGL.git
# Create a secure route
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.cloudapps.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

######################### ######################### #########################
#  PROJECT - Nodejs example - Work in Progress
######################### ######################### #########################
oc new-project nodejs-echo --display-name="nodejs" --description="Sample Node.js app"
oc new-app https://github.com/openshift/nodejs-ex -l name=nodejs-echo
oc expose svc nodejs-ex --hostname=nodejs-example.cloudapps.linuxrevolution.com
oc edit route

######################
# PROJECT - Ticketmonster
######################
oadm new-project ticketmonster --display-name="Ticketmonster" \
    --description='A demonstration of a Ticketmonster' \
    --node-selector='region=primary' --admin=morpheus

git clone https://github.com/jboss-developer/ticket-monster/

######################
# Quickstart
######################
oadm new-project quickstart --display-name="Quickstart" \
    --description='A demonstration of a "quickstart/template"' \
    --node-selector='region=primary' --admin=morpheus

mkdir Templates; cd $_
wget http://www.opentlc.com/download/ose_implementation/resources/Template_Example.json
oc create -f Template_Example.json -n openshift

######################
# PROJECT (Binary Deployment) -- This is pretty hosed... :-(
######################
# PRE
# fork https://github.com/JaredBurck/ose-team-ex-3 to https://github.com/jradtke-rh/ose-team-ex-3
# clone the repo
# add a Dockerfile
oc new-project petstore --description="Petstore Example"
oc policy add-role-to-user admin morpheus -n petstore
su - morpheus
oc login -u morpheus --insecure-skip-tls-verify --server=https://rh7osemst01.matrix.lab:8443
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
oc expose service petstore --hostname=petstore.cloudapps.matrix.lab
oc exec -it -p petstore-1-build /bin/bash # This doesn't work since it is a privileged container, or something...

######################### ######################### #########################
#  Random bits regarding ssh keys and git creds
######################### ######################### #########################
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
