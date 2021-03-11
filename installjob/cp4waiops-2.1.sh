#!/bin/bash

echo "Step 1 - Create zeno namespace and entitlement"

entitlement=$(oc get secret entitlement -o custom-columns=ent:data.entitlementKey --no-headers | base64 -d)
if [ -z $entitlement ]; then
  echo { "error": "entitlement key not found" }
  exit 9
fi

ENTITLED_REGISTRY_KEY=${entitlement}
ENTITLED_REGISTRY="cp.icr.io"
ENTITLED_REGISTRY_STG="cp.stg.icr.io"
CP4WAIOPS_NAMESPACE="zeno"
DOCKER_EMAIL="myemail@ibm.com"

oc new-project $CP4WAIOPS_NAMESPACE
oc create secret docker-registry $ENTITLED_REGISTRY --docker-username=cp --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=$DOCKER_EMAIL --docker-server=$ENTITLED_REGISTRY -n $CP4WAIOPS_NAMESPACE
oc create secret docker-registry $ENTITLED_REGISTRY_STG --docker-username=cp --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=$DOCKER_EMAIL --docker-server=$ENTITLED_REGISTRY_STG -n $CP4WAIOPS_NAMESPACE

echo "Step 2 - Installing Strimzi"
