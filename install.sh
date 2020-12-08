#!/bin/bash

oc new-project cpeir
oc create serviceaccount cpeir -n cpeir
oc adm policy add-cluster-role-to-user cluster-admin -z cpeir -n cpeir

oc create -f cloud.ibm.com_cpeirs_crd.yaml
oc create secret generic entitlement -n cpeir --from-literal entitlementKey=$1
