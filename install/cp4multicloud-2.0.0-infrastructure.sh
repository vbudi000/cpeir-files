#!/bin/bash

fn=$(basename $0)
name="${fn%.*}"

entitlement=$1
# Installing
if [ -z $entitlement ]; then
  echo {}
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
ibmroks=$(oc cluster-info | grep "cloud.ibm.com" | wc -l)
if [ ibmroks -gt 0 ]; then
  ROKS="true"
  ROKSREGION="us-south"
  ROKSZONE="dal13"
else
  ROKS="false"
fi

###########################
# CP4MCM Parameters
###########################
# ROKS defaults
# CP4MCM_BLOCK_STORAGECLASS="ibmc-block-gold"
# CP4MCM_FILE_STORAGECLASS="ibmc-file-gold"
# CP4MCM_FILE_GID_STORAGECLASS="ibmc-file-gold-gid"
#
# OpenShift - OCS Defaults
# CP4MCM_BLOCK_STORAGECLASS="ocs-storagecluster-ceph-rbd"
# CP4MCM_FILE_STORAGECLASS="ocs-storagecluster-cephfs"
# CP4MCM_FILE_GID_STORAGECLASS="ocs-storagecluster-cephfs"

if [ ROKS == "true" ]; then
  CP4MCM_BLOCK_STORAGECLASS="ibmc-block-gold"
  CP4MCM_FILE_STORAGECLASS="ibmc-file-gold"
  CP4MCM_FILE_GID_STORAGECLASS="ibmc-file-gold-gid"
else
  CP4MCM_BLOCK_STORAGECLASS="ocs-storagecluster-ceph-rbd"
  CP4MCM_FILE_STORAGECLASS="ocs-storagecluster-cephfs"
  CP4MCM_FILE_GID_STORAGECLASS="ocs-storagecluster-cephfs"
fi


running=$(oc get job ${name}-installer -n cpeir --no-headers 2>/dev/null | wc -l)

if [ $running -gt 0 ]; then
  /check/${fn}
  exit 0
fi

bash /script/1-common-services.sh
bash /script/cp4m/cp4mcm-core.sh
# Create the cp4mcm Namespace

# loop to check installation
# Install features

/check/$(basename $0)

## cleanup

#oc delete configmap cp4multicluster-1.3.0-configmap
#oc delete secret icr-io
exit
