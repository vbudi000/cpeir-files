#!/bin/bash

fn=$(basename $0)
name="${fn%.*}"

objid=$1

entitlement=$(oc get secret entitlement -o custom-columns=ent:data.entitlementKey --no-headers | base64 -d)
# Installing
if [ -z $entitlement ]; then
  echo { "error": "entitlement key not found" }
  exit 9
fi

ENTITLED_REGISTRY_KEY=${entitlement}
ENTITLED_REGISTRY="cp.icr.io"
ENTITLED_REGISTRY_SECRET="ibm-management-pull-secret"
DOCKER_EMAIL="myemail@ibm.com"

CP4MCM_NAMESPACE="cp4m"

###########################
# Parameters for ROKS
# Currently only used for CAM
###########################
ibmroks=$(oc cluster-info | grep "cloud.ibm.com" )
storclass=$(oc get cpeir cp4multicloud -o custom-columns=sc:spec.storageClass --no-headers)
defsc=$(oc get storageclass | grep -v NAME | grep "(default)" | cut -f1 -d" " )

if [ $(oc get sc ${storclass} --no-headers 2>/dev/null | wc -l) -le 0 ]; then
  echo { "error": "Storage Class ${storclass} is invalid" }
  exit 9
fi

if [ -z $ibmroks ]; then
  ROKS="false"
  ROKSREGION=""
  ROKSZONE=""
  # check storage class
else
  ROKS="true"
  ROKSREGION=$(oc get node -o yaml | grep region | cut -d: -f2 | head -1 | tr -d '[:space:]')
  ROKSZONE=""
fi

CP4MCM_BLOCK_STORAGECLASS=${storclass}
CP4MCM_FILE_STORAGECLASS=${storclass}
CP4MCM_FILE_GID_STORAGECLASS=${storclass}

running=$(oc get job ${name}-installer -n cpeir --no-headers 2>/dev/null | wc -l)

if [ $running -gt 0 ]; then
  /check/${fn}
  exit 0
fi

export ENTITLED_REGISTRY_KEY ENTITLED_REGISTRY ENTITLED_REGISTRY_SECRET DOCKER_EMAIL
export CP4MCM_NAMESPACE CP4MCM_BLOCK_STORAGECLASS CP4MCM_FILE_STORAGECLASS CP4MCM_FILE_GID_STORAGECLASS
export ROKS ROKSREGION ROKSZONE

cd /install

bash /script/1-common-services.sh
bash /script/cp4m/2-cp4mcm-core.sh
# Create the cp4mcm Namespace

# loop to check installation
# Install features

/check/$(basename $0)

## cleanup

#oc delete configmap cp4multicluster-1.3.0-configmap
#oc delete secret icr-io
exit
