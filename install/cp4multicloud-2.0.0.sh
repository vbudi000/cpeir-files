#!/bin/bash

fn=$(basename $0)
name="${fn%.*}"

entitlement=$1
# Installing
if [ -z $entitlement ]; then
  echo {}
  exit 9
fi

running=$(oc get job ${name}-installer -n cpeir --no-headers 2>/dev/null | wc -l)

if [ $running -gt 0 ]; then
  /check/${fn}
  exit 0
fi

# Create the cp4mcm Namespace
oc new-project cp4mcm

# Create entitelemt key -> imagePullSecrets
oc create secret docker-registry icr-io -n cp4mcm \
    --docker-username=cp \
    --docker-server="cp.icr.io" \
    --docker-password=${entitlement} \
    --docker-email="vbudi@us.ibm.com"

# Create cp4mcm CatalogSource
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-marketplace
spec:
  displayName: IBM Management Orchestrator Catalog
  publisher: IBM
  sourceType: grpc
  image: quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.0.0
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

# Create CommonServices CatalogSource

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

# Create an opeator group

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: <operatorgroup_name>
  namespace: <namespace>
spec:
  targetNamespaces:
  - <namespace>
EOF

# create subscription for common services

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: openshift-operators
spec:
  channel: stable-v1
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: operand-deployment-lifecycle-manager-app
  namespace: openshift-operators
spec:
  channel: stable-v1
  name: operand-deployment-lifecycle-manager-app
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF


# create subscription for mcm

oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-operators
spec:
  channel: 2.0-stable
  name: ibm-management-orchestrator
  source: ibm-management-orchestrator
  sourceNamespace: openshift-marketplace
EOF

# collect cluster info
sc=$(oc get sc --no-headers -o custom-columns=name:metadata.name | head -n 1)
workers=$(oc get node --no-headers -o  custom-columns=name:metadata.name -l node-role.kubernetes.io/worker | paste -s -d, -)
console=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}')
roks_url=${console#"console-openshift-console."}
if [[ $roks_url == apps* ]]; then
  roks="false"
else
  roks="true"
fi
cd /install
# Create configuration files
cat <<EOF | \
    sed "s/<entitlement>/${entitlement}/g" | \
    sed "s/<workers>/${workers}/g" | \
    sed "s/<sc>/${sc}/g" | \
    sed "s/<roks>/${roks}/g" | \
    sed "s/<roks_url>/${roks_url}/g"| oc create -f -
apiVersion: v1
kind: ConfigMap
metadata:
name: cp4multicloud-1.3.0-configmap
data:
config.yaml: |
  cluster_nodes:
    master: [<workers>]
    proxy: [<workers>]
    management: [<workers>]
  # Storage Class
  storage_class: <sc>
  roks_enabled: <roks>
  roks_url: <roks_url>
  roks_user_prefix: "IAM#"
  image_repo: cp.icr.io/cp/icp-foundation
  private_registry_enabled: true
  docker_username: cp
  docker_password: <entitlement>
  password_rules:
  - '(.*)'
  default_admin_password: passw0rd
  management_services:
    # Common services
    iam-policy-controller: enabled
    metering: enabled
    licensing: disabled
    monitoring: enabled
    nginx-ingress: enabled
    common-web-ui: enabled
    catalog-ui: enabled
    mcm-kui: enabled
    logging: disabled
    audit-logging: disabled
    system-healthcheck-service: disabled
    multitenancy-enforcement: disabled

    # mcm services
    multicluster-hub: enabled
    search: enabled
    key-management: enabled
    notary: disabled
    cis-controller: disabled
    vulnerability-advisor: disabled
    mutation-advisor: disabled
    sts: disabled
    secret-encryption-policy-controller: disabled
    image-security-enforcement: disabled
hosts: |
  [master]
  localhost ansible_connection=local

  [worker]
  localhost ansible_connection=local

  [proxy]
  localhost ansible_connection=local

  #[management]
  #localhost ansible_connection=local

  #[va]
  #localhost ansible_connection=local
EOF


# Create installation Job
cat <<EOF | oc create -f -
kind: Job
apiVersion: batch/v1
metadata:
  name: cp4multicloud-1.3.0-installer
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: cpeir
      imagePullSecrets:
        - name: icr-io
      securityContext: {}
      initContainers:
        - name: build-config
          image: busybox:1.28
          volumeMounts:
            - name: config
              mountPath: /config
            - name: file
              mountPath: /file
          command:
            - /bin/sh
            - '-c'
            - >-
              mkdir -p /config/misc/storage_class &&
              cp /file/config.yaml /config/config.yaml &&
              cp /file/hosts /config/hosts &&
              echo "done"
      containers:
        - resources: {}
          terminationMessagePath: /dev/termination-log
          name: installer
          args:
            - install-with-openshift
          env:
            - name: LICENSE
              value: accept
            - name: ANSIBLE_LOCAL_TEMP
              value: /tmp
          imagePullPolicy: Always
          volumeMounts:
            - name: config
              mountPath: /installer/cluster
            - name: cloudctl
              mountPath: /.cloudctl
          terminationMessagePolicy: File
          image: cp.icr.io/cp/icp-foundation/mcm-inception:3.2.5
      serviceAccount: cpeir
      volumes:
        - name: cloudctl
          emptyDir: {}
        - name: config
          emptyDir: {}
        - name: file
          configMap:
            name: cp4multicloud-1.3.0-configmap
EOF

# loop to check installation
# Install features

/check/$(basename $0)

## cleanup

#oc delete configmap cp4multicluster-1.3.0-configmap
#oc delete secret icr-io
exit
