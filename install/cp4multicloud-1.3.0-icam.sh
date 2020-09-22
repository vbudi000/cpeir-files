#!/bin/bash

entitlement=$1
# Installing

if [ -z $entitlement ]; then
  exit 9
fi

# Create entitelemt key -> imagePullSecrets
oc create secret docker-registry icr-io \
    --docker-username=cp \
    --docker-server="cp.icr.io" \
    --docker-password=${entitlement} \
    --docker-email="vbudi@us.ibm.com" \
    -n kube-system

# collect cluster info
icpconsole=$(oc get configmap ibmcloud-cluster-info -n kube-public -o=jsonpath='{.data.cluster_address}')
icpproxy=$(oc get configmap ibmcloud-cluster-info -n kube-public -o=jsonpath='{.data.proxy_address}')

# install CLIs
# cloudctl
curl -kLo cloudctl https://${icpconsole}:443/api/cli/cloudctl-linux-amd64

# helm
curl -kLo helm-linux-amd6.tar.gz https://${icpconsole}:443/api/cli/helm-linux-amd64.tar.gz
tar -xf helm-linux-amd64.tar.gz

#oc create serviceaccount tiller -n kube-system
#oc adm policy add-cluster-role-to-user cluster-admin -n kube-system -z tiller
#oc patch serviceaccount tiller -p '{"imagePullSecrets": [{"name": "icr-io"}]}' -n kube-system
oc patch serviceaccount default  -p '{"imagePullSecrets": [{"name": "icr-io"}]}' -n kube-system
oc patch serviceaccount ibmcloudappmgmt-ibm-cloud-appmgmt-prod-cacerts  -p '{"imagePullSecrets": [{"name": "icr-io"}]}' -n kube-system

#oc patch deployment tiller-deploy  -p='{"spec":{"template":{"spec":{"serviceAccountName": "tiller"}}}}' -n kube-system
./cloudctl login -u admin -p passw0rd -a https://${icpconsole} -n kube-system

#oc get secret tiller-secret -n kube-system -o yaml | grep -A5 '^data:' |awk -F: '{system("echo "$2" | base64 -d >"$1)}'
./linux-amd64/helm init --client-only
./linux-amd64/helm repo add entitled https://raw.githubusercontent.com/IBM/charts/master/repo/entitled/

helm install --debug --tls entitled/ibm-cloud-appmgmt-prod -n ibmcloudappmgmt --namespace kube-system \
      --set global.license="accept" \
      --set global.ingress.domain="${icpconsole}" \
      --set global.ingress.port=443 \
      --set global.icammcm.domain="${icpproxy}" \
      --set global.masterIP="${icpconsole}" \
      --set global.masterPort=443

# loop to check installation
# Install features

/check/$(basename $0)

## cleanup

#oc delete configmap cp4multicluster-1.3.0-configmap
#oc delete secret icr-io
exit
