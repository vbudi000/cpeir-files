#!/bin/bash

#
# Create management-infrastructure-management namespace.
#
echo "Creating CloudPak for MultiCloud Management - Infrastructure management"

echo "Step 1 - Create management-infrastructure-management namespace."
CP4MCM_IM_NAMESPACE="management-infrastructure-management"
oc new-project ${CP4MCM_IM_NAMESPACE}

echo "Step 2 - Modifying installation object - setting installation parameters"
#
# Updating Installation config with CAM config.
#
if [ $ROKS != "true" ];
then
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
            "license": {"accept": true}
            }
        }
  }
]";
else

#
# Updating Installation config with CAM config with ROKS.
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
            "roks": true,
            "roksRegion": "$ROKSREGION",
            "roksZone": "$ROKSZONE"
            }
        }
  }
]"
fi

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
