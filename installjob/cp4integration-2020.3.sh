#!/bin/bash

echo "Step 1 - Creating CatalogSource for opencloud-operators"

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

OUTPUT="INITIAL"
counter=0
until [ $OUTPUT = "READY" ]; do
  ((counter++))
  if [ $counter -gt 20 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  OUTPUT=$(oc get -n openshift-marketplace catalogsource  opencloud-operators -o custom-columns=stat:status.connectionState.lastObservedState --no-headers)
  now=$(date)
  echo "${now} - Processing opencloud-operators step ${counter} of 20 - ${OUTPUT}"
done

echo "Step 2 - Creating project for CloudPak for Integration "

oc new-project $CP4I_NAMESPACE

oc create secret docker-registry $ENTITLED_REGISTRY_SECRET --docker-username=cp --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=$DOCKER_EMAIL --docker-server=$ENTITLED_REGISTRY -n $CP4I_NAMESPACE

#
# Import Catalog Source
#

echo "Step 3 - Creating CatalogSource for ibm-operator-catalog"

# CP4I CatalogSource
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: docker.io/ibmcom/ibm-operator-catalog
  updateStrategy:
    registryPoll:
      interval: 45m
EOF


OUTPUT="INITIAL"
counter=0
until [ $OUTPUT = "READY" ]; do
  ((counter++))
  if [ $counter -gt 20 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  OUTPUT=$(oc get -n openshift-marketplace catalogsource ibm-operator-catalog -o custom-columns=stat:status.connectionState.lastObservedState --no-headers)
  now=$(date)
  echo "${now} - Processing ibm-operator-catalog step ${counter} of 20 - ${OUTPUT}"
done

echo "Step 4 - Creating CP for Integration subscription"

#
# Create CP4I Subscription
#
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-cp-integration
  namespace: openshift-operators
spec:
  channel: v1.0
  installPlanApproval: Automatic
  name: ibm-cp-integration
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-cp-integration.v1.0.0
EOF

sleep 5

#
# Wait for CatalogSource to be created
#
# waiting for  CSV to be ready

now=$(date)
echo "${now} installation of cp for integration platform navigator initiated"

cscsvcnt=$(oc get csv -n ibm-common-services --no-headers | grep -v "Succeeded" | wc -l)
counter=0
until [ $cscsvcnt -le 0 ]; do
  ((counter++))
  if [ $counter -gt 80 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  cscsvcnt=$(oc get csv -n ibm-common-services --no-headers | grep -v Succeeded | wc -l)
  now=$(date)
  echo "${now} - Checking common services operators step ${counter} of 80 - Remaining CSV: ${cscsvcnt}"
done

mcmsvc=$(oc get csv -n openshift-operators | grep ibm-cp-integration | wc -l)
until [ "$mcmsvc" -gt 0 ]; do
  sleep 30
  echo "Waiting for ibm-cp-integration CSV"
  mcmsvc=$(oc get csv -n openshift-operators | grep ibm-cp-integration | wc -l)
done

mcmcsvcnt=$(oc get csv -n openshift-operators --no-headers | grep -v "Succeeded" | wc -l)
now=$(date)
echo "${now} - Checking cp for integration operators step ${counter} of 80 - Remaining CSV: ${mcmcsvcnt}"
until [ $mcmcsvcnt -le 0 ]; do
  ((counter++))
  if [ $counter -gt 120 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  mcmcsvcnt=$(oc get csv -n openshift-operators --no-headers | grep -v "Succeeded" | wc -l)
  now=$(date)
  echo "${now} - Checking mcm operators step ${counter} of 80 - Remaining CSV: ${mcmcsvcnt}"
done

echo "Step 5 - Creating Platform Navigator instance"

#
# Create the Installation of the Platform Navigator
#
cat << EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: cp4i-navigator
  namespace: $CP4I_NAMESPACE
spec:
  license:
    accept: true
  mqDashboard: true
  replicas: 3
  version: 2020.3.1
EOF

now=$(date)

numpods=$(oc get pod -n $CP4I_NAMESPACE | grep cp4i-navigator-ibm-integration-platform-navigator | grep Running | wc -l)
counter=0
until [ $numpods -ne 3 ]; do
  ((counter++))
  if [ $counter -gt 120 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  numpods=$(oc get pod -n $CP4I_NAMESPACE | grep cp4i-navigator-ibm-integration-platform-navigator | grep Running | wc -l)
  now=$(date)
  echo "${now} - Checking platform navigator step ${counter} of 80 - Number of pods: ${numpods}"
done
