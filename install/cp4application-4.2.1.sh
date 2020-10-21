#!/bin/bash

fn=$(basename $0)
name="${fn%.*}"
version=$(echo ${name} | cut -d"-" -f2)

objid=$1

entitlement=$(oc get secret entitlement -o custom-columns=ent:data.entitlementKey --no-headers | base64 -d)
# Installing
if [ -z $entitlement ]; then
  echo { "error": "entitlement key not found" }
  exit 9
fi

ENTITLED_REGISTRY_KEY=${entitlement}
ENTITLED_REGISTRY_USER=cp
ENTITLED_REGISTRY="cp.icr.io"

OPENSHIFT_URL=$(oc whoami --show-server)
OPENSHIFT_TOKEN=$(oc whoami -t)

###########################
# Parameters for ROKS
# Currently only used for CAM
###########################
ibmroks=$(oc get clusterversion version -o custom-columns=image:status.desired.image --no-headers | grep "bluemix.net\|icr.io")
# ibmroks=$(oc cluster-info | grep "cloud.ibm.com" )
storclass=$(oc get cpeir ${objid} -o custom-columns=sc:spec.storageClass --no-headers)
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
  node=$(oc get node --no-headers -o name | head -1)
  ROKSREGION=$(oc get ${node} -o yaml | grep "ibm-cloud.kubernetes.io/region:" | cut -d: -f2 | tr -d '[:space:]')
  ROKSZONE=$(oc get ${node} -o yaml | grep "ibm-cloud.kubernetes.io/zone:" | cut -d: -f2 | tr -d '[:space:]')
fi

oc create secret docker-registry icpa --docker-password=${ENTITLED_REGISTRY_KEY} --docker-username=${ENTITLED_REGISTRY_USER} --docker-email="myuser@ibm.com" --docker-server="cp.icr.io"
oc secret link cpeir icpa --for=pull


running=$(oc get job ${name}-installer -n cpeir --no-headers 2>/dev/null | wc -l)

if [ $running -gt 0 ]; then
  /check/${fn}
  exit 0
fi

export ENTITLED_REGISTRY_KEY ENTITLED_REGISTRY ENTITLED_REGISTRY_USER
export ROKS ROKSREGION ROKSZONE

cat << EOF | oc create -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cpainst
  namespace: cpeir
data:
  runinst.sh: |
    #/bin/bash
    sed -i 's/get subscription/get subscriptions.operators.coreos.com/g' playbook/roles/common/tasks/check-operator.yaml
    bash main.sh install
EOF

cat << EOF | oc create -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}-installer
  namespace: cpeir
spec:
  template:
    spec:
      serviceAccountName: cpeir
      containers:
      - name: icpa-installer
        env:
        - name: LICENSE
          value: "accept"
        - name: ENTITLED_REGISTRY_KEY
          value: "${ENTITLED_REGISTRY_KEY}"
        - name: ENTITLED_REGISTRY
          value: "${ENTITLED_REGISTRY}"
        - name: ENTITLED_REGISTRY_USER
          value: ${ENTITLED_REGISTRY_USER}
        - name: OPENSHIFT_URL
          value: "${OPENSHIFT_URL}"
        - name: OPENSHIFT_TOKEN
          value: "${OPENSHIFT_TOKEN}"
        - name: ROKS
          value: "${ROKS}"
        - name: ROKSREGION
          value: "${ROKSREGION}"
        - name: ROKSZONE
          value: "${ROKSZONE}"
        image: $ENTITLED_REGISTRY/cp/icpa/icpa-installer:$version
        command: ["bash", "/cm/runinst.sh"]
        volumeMounts:
        - name: cm
          mountPath: /cm
      volumes:
      - name: cm
        configMap:
        name: cpainst
      restartPolicy: Never
EOF

exit
