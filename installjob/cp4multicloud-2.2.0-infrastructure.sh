#!/bin/bash

#
# Create management-infrastructure-management namespace.
#
echo "Creating CloudPak for MultiCloud Management - Infrastructure management"
counter=0
mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.2.5 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)

until [ "$mcmcsvphase" = "Succeeded" ]; do
  ((counter++))
  if [ $counter -gt 100 ]; then
     echo "Timeout waiting for MCM core"
     exit 999
  fi
  sleep 60
  mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.2.5 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)
  now=$(date)
  echo "${now} - Checking whether MCM core is installed; step ${counter} of 100"
done
now=$(date)
echo "${now} - MCM core is installed "

echo "Step 0 - Downloading cloudctl cli"
CP4MCM_ROUTE=`oc -n ibm-common-services get route cp-console --template '{{.spec.host}}'`
CP_PASSWORD=`oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d`
curl -kLo cloudctl https://${CP4MCM_ROUTE}/api/cli/cloudctl-linux-amd64
chmod a+x cloudctl

echo "Step 1 - Create management-infrastructure-management namespace."
CP4MCM_IM_NAMESPACE="management-infrastructure-management"
oc new-project ${CP4MCM_IM_NAMESPACE}

serviceIDName="service-deploy"
serviceApiKeyName="service-deploy-api-key"
./cloudctl login -a ${CP4MCM_ROUTE} --skip-ssl-validation -u admin -p ${CP_PASSWORD} -n ${CP4MCM_IM_NAMESPACE}
./cloudctl iam service-id-create ${serviceIDName} -d 'Service ID for service-deploy'
./cloudctl iam service-policy-create ${serviceIDName} -r Administrator,ClusterAdministrator --service-name 'idmgmt'
./cloudctl iam service-policy-create ${serviceIDName} -r Administrator,ClusterAdministrator --service-name 'identity'
CAM_API_KEY=$(./cloudctl iam service-api-key-create ${serviceApiKeyName} ${serviceIDName} -d 'Api key for service-deploy' | grep "API Key" | cut -d" " -f9)

echo "Step 2 - Modifying installation object - setting installation parameters"
#
# Updating Installation config with CAM config.
#
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p="[
 {"op": "test",
  "path": "/spec/pakModules/0/name",
  "value": "infrastructureManagement" },
 {"op": "add",
  "path": "/spec/pakModules/0/config/3/spec",
  "value":
        { "manageservice": {
            "camMongoPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "camTerraformPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "camLogsPV": {"persistence": { "storageClassName": $CP4MCM_FILE_GID_STORAGECLASS}},
            "global": { "iam": { "deployApiKey": $CAM_API_KEY}},
            "license": {"accept": true},
            "roks": "$ROKS",
            "roksRegion": "$ROKSREGION",
            "roksZone": "$ROKSZONE"
            }
        }
  }
]"

echo "Step 3 - Modifying installation object - starting installation "

#
# Enable Infrastructure Management Module
#
oc patch installation.orchestrator.management.ibm.com ibm-management -n $CP4MCM_NAMESPACE --type=json -p='[
 {"op": "test",
  "path": "/spec/pakModules/0/name",
  "value": "infrastructureManagement" },
 {"op": "replace",
  "path": "/spec/pakModules/0/enabled",
  "value": true }
]'

echo "Step 4 - Waiting for installation to succeed"
#
# Wait for install
#
sleep 5
mcmcsvcnt=0
until [ $mcmcsvcnt -gt 0 ]; do
  mcmcsvcnt=$(oc get csv ibm-management-im-install.v2.2.5 -n ${CP4MCM_IM_NAMESPACE} --no-headers | wc -l)
  sleep 5
done

counter=0
mcmcsvcnt=$(oc get csv -n ${CP4MCM_IM_NAMESPACE} --no-headers | grep -v "Succeeded" | wc -l)
now=$(date)
echo "${now} - Checking mcm im operators step ${counter} of 100 - Remaining CSV: ${mcmcsvcnt}"
until [ $mcmcsvcnt -le 0 ]; do
  ((counter++))
  if [ $counter -gt 100 ]; then
     echo "Timeout waiting for ready"
     exit 999
  fi
  sleep 20
  mcmcsvcnt=$(oc get csv -n ${CP4MCM_IM_NAMESPACE} --no-headers | grep -v "Succeeded" | wc -l)
  now=$(date)
  echo "${now} - Checking mcm im operators step ${counter} of 100 - Remaining CSV: ${mcmcsvcnt}"
done

exit 0
