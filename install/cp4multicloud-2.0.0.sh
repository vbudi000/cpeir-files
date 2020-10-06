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

cat << EOF | oc create -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}-installer
spec:
  template:
    spec:
      serviceAccountName: cpeir
      containers:
      - name: installer
        env:
        - name: ENTITLED_REGISTRY_KEY
          value: ${ENTITLED_REGISTRY_KEY}
        - name: ENTITLED_REGISTRY
          value: ${ENTITLED_REGISTRY}
        - name: ENTITLED_REGISTRY_SECRET
          value: ${ENTITLED_REGISTRY_SECRET}
        - name: CP4MCM_NAMESPACE
          value: ${CP4MCM_NAMESPACE}
        - name: CP4MCM_BLOCK_STORAGECLASS
          value: ${CP4MCM_BLOCK_STORAGECLASS}
        - name: CP4MCM_FILE_STORAGECLASS
          value: ${CP4MCM_FILE_STORAGECLASS}
        - name: CP4MCM_FILE_GID_STORAGECLASS
          value: ${CP4MCM_FILE_GID_STORAGECLASS}
        - name: ROKS
          value: "${ROKS}"
        - name: ROKSREGION
          value: "${ROKSREGION}"
        - name: ROKSZONE
          value: "${ROKSZONE}"
        image: vbudi/cpeir-runtime:v0.05
        command: ["bash",  "installjob.sh", ${name}]
      restartPolicy: Never
EOF

exit
