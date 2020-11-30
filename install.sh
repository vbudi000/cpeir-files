#!/bin/bash

oc new-project cpeir
oc create serviceaccount cpeir -n cpeir
oc adm policy add-cluster-role-to-user -z cpeir -n cpeir

oc create -f cloud.ibm.com_cpeirs_crd.yaml
oc create secret entitlement -n cpeir --from-literal entitlementKey=$1
