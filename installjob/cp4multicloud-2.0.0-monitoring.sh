#!/bin/bash

echo "Creating CloudPak for MultiCloud Management - Advanced monitoring"

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


#
# Adding Monitoring Storage Config.
#
echo "Step 0 - Setup namespace"
CP4MCM_MON_NAMESPACE="management-monitoring"
oc new-project ${CP4MCM_MON_NAMESPACE}

echo "Step 1 - Adding Monitoring Storage Config to Installation"
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p="[
 {"op": "test",
  "path": "/spec/pakModules/1/name",
  "value": "monitoring" },
 {"op": "replace",
  "path": "/spec/pakModules/1/config/0/spec",
  "value":
    {
      "monitoringDeploy": {
        "cnmonitoringimagesource": {
          "deployMCMResources": true
        },
        "global": {
          "environmentSize": size0,
          "persistence": {
            "storageClassOption": {
              "cassandrabak": none,
              "cassandradata": $CP4MCM_BLOCK_STORAGECLASS,
              "couchdbdata": $CP4MCM_BLOCK_STORAGECLASS,
              "datalayerjobs": $CP4MCM_BLOCK_STORAGECLASS,
              "elasticdata": $CP4MCM_BLOCK_STORAGECLASS,
              "kafkadata": $CP4MCM_BLOCK_STORAGECLASS,
              "zookeeperdata": $CP4MCM_BLOCK_STORAGECLASS
            },
            "storageSize": {
              "cassandrabak": 50Gi,
              "cassandradata": 50Gi,
              "couchdbdata": 5Gi,
              "datalayerjobs": 5Gi,
              "elasticdata": 5Gi,
              "kafkadata": 10Gi,
              "zookeeperdata": 1Gi
            }
          }
        }
      }
    }
  }
]"

#
# Updating Installation config with CAM config.
#
echo "Step 2 - Enabling Monitoring Module"
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p='[
 {"op": "test",
  "path": "/spec/pakModules/1/name",
  "value": "monitoring" },
 {"op": "replace",
  "path": "/spec/pakModules/1/enabled",
  "value": true }
]'

echo "Step 3 - Waiting for installation to complete"
sleep 5
mcmcsvcnt=0
until [ $mcmcsvcnt -gt 0 ]; do
  mcmcsvcnt=$(oc get csv ibm-management-monitoring.v2.0.0 -n ${CP4MCM_MON_NAMESPACE} --no-headers | wc -l)
  sleep 5
done

counter=0
mcmcsvcnt=$(oc get csv -n ${CP4MCM_MON_NAMESPACE} --no-headers | grep -v "Succeeded" | wc -l)
now=$(date)
echo "${now} - Checking mcm im operators step ${counter} of 100 - Remaining CSV: ${mcmcsvcnt}"
until [ $mcmcsvcnt -le 0 ]; do
  ((counter++))
  if [ $counter -gt 100 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  mcmcsvcnt=$(oc get csv -n ${CP4MCM_MON_NAMESPACE} --no-headers | grep -v "Succeeded" | wc -l)
  now=$(date)
  echo "${now} - Checking mcm im operators step ${counter} of 100 - Remaining CSV: ${mcmcsvcnt}"
done

sleep 10

echo "Step 4 - Setting up image pull secret for monitoring"

echo "Docker config for SECRET=$ENTITLED_REGISTRY_SECRET in NAMESPACE=$CP4MCM_NAMESPACE"
ENTITLED_REGISTRY_DOCKERCONFIG=$(oc get secret $ENTITLED_REGISTRY_SECRET -n $CP4MCM_NAMESPACE -o jsonpath='{.data.\.dockerconfigjson}')
oc patch deployable.app.ibm.com/cnmon-pullsecret-deployable -p $(echo {\"spec\":{\"template\":{\"data\":{\".dockerconfigjson\":\"$ENTITLED_REGISTRY_DOCKERCONFIG\"}}}}) --type merge -n ${CP4MCM_MON_NAMESPACE}

echo "Step 5 - Make sure all pods are running in $CP4CP4MCM_MON_NAMESPACE"
mcmpodcnt=$(oc get pod -n $CP4MCM_MON_NAMESPACE --no-headers | grep -v "Running\|Completed" | wc -l)
counter=0
until [ $mcmpodcnt -eq 0 ]; do
  ((counter++))
  if [ $counter -gt 40 ]; then
    echo "Pod are not yet all running - here are the left over"
    oc get pod -n $CP4MCM_MON_NAMESPACE | grep -v "Running\|Completed"
    exit 999
  fi
  sleep 20
  mcmpodcnt=$(oc get pod -n $CP4MCM_MON_NAMESPACE --no-headers | grep -v "Running\|Completed" | wc -l)
  now=$(date)
  echo "${now} - Checking pod that are not running step ${counter} of 40 - Remaining pod: ${mcmpodcnt}"
done
exit 0
