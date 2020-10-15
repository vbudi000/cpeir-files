#!/bin/bash

counter=0
mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.0.0 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)

until [ "$mcmcsvphase" = "Succeeded" ]; do
  ((counter++))
  if [ $counter -gt 100 ]; then
     echo "Timeout waiting for MCM core"
     exit 999
  fi
  sleep 60
  mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.0.0 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)
  now=$(date)
  echo "${now} - Checking whether MCM core is installed; step ${counter} of 100"
done
now=$(date)
echo "${now} - MCM core is installed "

# Setting up ansible

cat "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" >> /etc/apt/sources.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
apt update
apt install ansible

# Additional packages can be found here:
ANSIBLE_SETUP_PACKAGE="ansible-tower-openshift-setup-3.7.2-1.tar.gz"
ANSIBLE_NAMESPACE="management-ansible-tower"
ANSIBLE_PASSWORD="Passw0rd"

curl -kLo ${ANSIBLE_SETUP_PACKAGE} https://releases.ansible.com/ansible-tower/setup_openshift/${ANSIBLE_SETUP_PACKAGE}
curl -kLo jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod a+x jq
export PATH=$PATH:.

echo "Creating namespace for Ansible Tower."
oc new-project $ANSIBLE_NAMESPACE

#
# Create PVC for the Postgres DB
#
echo "Creating PVC for Ansible Tower."
oc create -f - <<EOF
 apiVersion: v1
 kind: PersistentVolumeClaim
 metadata:
   annotations:
   labels:
   name: postgresql
   namespace: $ANSIBLE_NAMESPACE
 spec:
   accessModes:
   - ReadWriteOnce
   resources:
     requests:
       storage: 10Gi
   storageClassName: $CP4MCM_FILE_GID_STORAGECLASS
EOF

#
# Extract Ansible binaries
#
echo "Extracting Ansible Tower installer."
mkdir tmp
tar xvf ${ANSIBLE_SETUP_PACKAGE} -C ./tmp

#
# Change Ansible to use insecure login
#
echo "Patching Ansible Tower installer to use insecure login."
authyml=$(find . -name openshift_auth.yml)
sed -i'.old' "s/{{ openshift_skip_tls_verify | default(false)/{{ openshift_skip_tls_verify | default(true)/g" ${authyml}


#
# Get install values
#
echo "Collecting Ansible Tower installation parameters."
KUBE_API_SERVER_HOST=$(oc get configmap ibmcloud-cluster-info -n kube-public -o jsonpath='{.data.cluster_kube_apiserver_host}')
KUBE_API_SERVER_PORT=$(oc get configmap ibmcloud-cluster-info -n kube-public -o jsonpath='{.data.cluster_kube_apiserver_port}')
OPENSHIFT_USER=$(oc whoami)
OPENSHIFT_TOKEN=$(oc whoami -t)

MY_SECRET=`echo $ANSIBLE_PASSWORD | base64`
PG_USERNAME='admin'
PG_PASSWORD=$ANSIBLE_PASSWORD
RABBITMQ_PASSWORD=$ANSIBLE_PASSWORD
RABBITERLANGAPWD='rabbiterlangapwd'

echo "The following parameters will be passed to the Ansible Tower installer:"
echo "  KUBE_API_SERVER_HOST=$KUBE_API_SERVER_HOST"
echo "  KUBE_API_SERVER_PORT=$KUBE_API_SERVER_PORT"
echo "  OPENSHIFT_USER=$OPENSHIFT_USER"
echo "  OPENSHIFT_TOKEN=$OPENSHIFT_TOKEN"
echo "  MY_SECRET=$MY_SECRET"
echo "  PG_USERNAME=$PG_USERNAME"
echo "  PG_PASSWORD=$PG_PASSWORD"
echo "  RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD"
echo "  RABBITERLANGAPWD=$RABBITERLANGAPWD"

#
# Install Ansible
#
export ANSIBLE_NOCOWS=1
echo "Executing the Ansible Tower installer:"
./tmp/ansible-tower-openshift-setup-3.7.2-1/setup_openshift.sh -e openshift_host=https://$KUBE_API_SERVER_HOST:$KUBE_API_SERVER_PORT -e openshift_project=$ANSIBLE_NAMESPACE -e openshift_user=$OPENSHIFT_USER \
-e openshift_token=$OPENSHIFT_TOKEN -e admin_password=$OPENSHIFT_TOKEN -e secret_key=$MY_SECRET -e pg_username=$PG_USERNAME -e pg_password=$PG_PASSWORD \
-e rabbitmq_password=$RABBITMQ_PASSWORD -e rabbitmq_erlang_cookie=$RABBITERLANGAPWD

#
# Print Login credentials
#
ANSIBLE_ROUTE=$(oc get route -n ${ANSIBLE_NAMESPACE} --template '{{.spec.host}}')

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Ansible Tower installation complete."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo " You can access User Interface with the URL and credentials below:"
echo " URL=$ANSIBLE_ROUTE"
echo " User=admin"
echo " Password=$ANSIBLE_PASSWORD"

exit 0
