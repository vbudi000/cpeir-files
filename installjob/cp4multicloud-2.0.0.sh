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

echo "Step 2 - Creating project for CloudPak for MultiCloud Manager "

oc new-project $CP4MCM_NAMESPACE

oc create secret docker-registry $ENTITLED_REGISTRY_SECRET --docker-username=cp --docker-password=$ENTITLED_REGISTRY_KEY --docker-email=$DOCKER_EMAIL --docker-server=$ENTITLED_REGISTRY -n $CP4MCM_NAMESPACE

now=$(date)
echo "${now} - Project ${CP4CP4MCM_NAMESPACE} created"

echo "Step 3 - Creating CatalogSource for CP4MCM"

# CP4MCM CatalogSource
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: management-installer-index
  namespace: openshift-marketplace
spec:
  displayName: CP4MCM Installer Catalog
  publisher: IBM CP4MCM
  sourceType: grpc
  image: quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.0.0
  updateStrategy:
    registryPoll:
      interval: 45m
  secrets:
   - $ENTITLED_REGISTRY_SECRET
EOF

OUTPUT="INITIAL"
counter=0
until [ $OUTPUT = "READY" ]; do
  ((counter++))
  if [ $counter -gt 40 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  OUTPUT=$(oc get -n openshift-marketplace catalogsource  management-installer-index -o custom-columns=stat:status.connectionState.lastObservedState --no-headers)
  now=$(date)
  echo "${now} - Processing management-installer-index step ${counter} of 40 - ${OUTPUT}"
done

echo "Step 4 - Creating MCM Subscription"

cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-operators
spec:
  channel: 2.0-stable
  installPlanApproval: Automatic
  name: ibm-management-orchestrator
  source: management-installer-index
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-management-orchestrator.v2.0.0
EOF

sleep 5

installPlan=$(oc get subscription -n openshift-operators ibm-management-orchestrator -o custom-columns=plan:status.installPlanRef.name --no-headers)

sleep 5

planObjects=$(oc get installplan -n openshift-operators ${installPlan} -o yaml | grep -v "\"" | grep "  status:" | grep "Created\|True" | wc -l)
until [ $planObjects -eq 0 ]; do
  ((counter++))
  if [ $counter -gt 30 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  planObjects=$(oc get installplan -n openshift-operators ${installPlan} -o yaml | grep -v "\"" | grep "  status:" | grep "Created\|True" | wc -l)
  now=$(date)
  echo "${now} - Processing installplan ${installPlan} step ${counter} of 30 - objects to be created ${planObjects}"
done

echo "Step 5 - Creating MCM Core installation"

cat << EOF | oc apply -f -
apiVersion: orchestrator.management.ibm.com/v1alpha1
kind: Installation
metadata:
  name: ibm-management
  namespace: $CP4MCM_NAMESPACE
spec:
  storageClass: $CP4MCM_BLOCK_STORAGECLASS
  imagePullSecret: $ENTITLED_REGISTRY_SECRET
  license:
    accept: true
  mcmCoreDisabled: false
  pakModules:
    - config:
        - enabled: true
          name: ibm-management-im-install
          spec: {}
        - enabled: true
          name: ibm-management-infra-grc
          spec: {}
        - enabled: true
          name: ibm-management-infra-vm
          spec: {}
        - enabled: true
          name: ibm-management-cam-install
          spec: {}
        - enabled: true
          name: ibm-management-service-library
          spec: {}
      enabled: false
      name: infrastructureManagement
    - config:
        - enabled: true
          name: ibm-management-monitoring
          spec:
            operandRequest: {}
            monitoringDeploy:
              global:
                environmentSize: size0
                persistence:
                  storageClassOption:
                    cassandrabak: none
                    cassandradata: default
                    couchdbdata: default
                    datalayerjobs: default
                    elasticdata: default
                    kafkadata: default
                    zookeeperdata: default
                  storageSize:
                    cassandrabak: 50Gi
                    cassandradata: 50Gi
                    couchdbdata: 5Gi
                    datalayerjobs: 5Gi
                    elasticdata: 5Gi
                    kafkadata: 10Gi
                    zookeeperdata: 1Gi
      enabled: false
      name: monitoring
    - config:
        - enabled: true
          name: ibm-management-notary
          spec: {}
        - enabled: true
          name: ibm-management-image-security-enforcement
          spec: {}
        - enabled: false
          name: ibm-management-mutation-advisor
          spec: {}
        - enabled: false
          name: ibm-management-vulnerability-advisor
          spec:
            controlplane:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
            annotator:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
            indexer:
              esSecurityEnabled: true
              esServiceName: elasticsearch.ibm-common-services
              esSecretName: logging-elk-certs
              esSecretCA: ca.crt
              esSecretCert: curator.crt
              esSecretKey: curator.key
      enabled: false
      name: securityServices
    - config:
        - enabled: true
          name: ibm-management-sre-chatops
          spec: {}
      enabled: false
      name: operations
    - config:
        - enabled: true
          name: ibm-management-manage-runtime
          spec: {}
      enabled: false
      name: techPreview
EOF

now=$(date)
echo "${now} installation of mcm core initiated"

sleep 10

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

mcmcsvcnt=$(oc get csv -n kube-system --no-headers | grep -v "Succeeded" | wc -l)
now=$(date)
echo "${now} - Checking mcm operators step ${counter} of 80 - Remaining CSV: ${mcmcsvcnt}"
until [ $mcmcsvcnt -le 0 ]; do
  ((counter++))
  if [ $counter -gt 120 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  mcmcsvcnt=$(oc get csv -n kube-system --no-headers | grep -v "Succeeded" | wc -l)
  now=$(date)
  echo "${now} - Checking mcm operators step ${counter} of 80 - Remaining CSV: ${mcmcsvcnt}"
done

exit 0
