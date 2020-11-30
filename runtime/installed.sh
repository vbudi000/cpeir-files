#!/bin/bash

## CP4MCM

mcm=$(oc get deployment -n kube-system 2>/dev/null | grep multicluster-hub | wc -l)
icam=$(oc get deployment -n kube-system 2>/dev/null | grep icam\- | wc -l)
klusterlet=$(oc get deployment -n multicluster-endpoint 2>/dev/null | grep multicluster | wc -l)

## CP4A


echo "{" \
         "\"mcm\": ${mcm}," \
         "\"icam\": ${icam}," \
         "\"klusterlet\": ${klusterlet}," \
         "\"done\": true"
     "}"

exit 0
