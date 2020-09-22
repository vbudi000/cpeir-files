#!/bin/sh
mcm=$(oc get deployment -n kube-system 2>/dev/null | grep multicluster-hub | wc -l)

if [[ mcm>0 ]]; then
  mcm=true
  mcmver=$(oc get deployment multicluster-hub-core-controller -n kube-system -o custom-columns=image:.spec.template.spec.containers.*.image --no-headers | cut -d: -f2)
  icam=$(oc get deployment -n kube-system 2>/dev/null | grep icam\- | wc -l)
  cam=$()
  endpoint=$(oc get deployment -n multicluster-endpoint 2>/dev/null | grep multicluster | wc -l)
else
  mcm=false
fi
icam=$(oc get deployment -n kube-system 2>/dev/null | grep icam\- | wc -l)
klusterlet=$(oc get deployment -n multicluster-endpoint 2>/dev/null | grep multicluster | wc -l)

## CP4A


echo "{" \
         "\"mcm\": ${mcm}," \
         "\"mcmver\": \"${mcmver}\","
         "\"icam\": ${icam}," \
         "\"klusterlet\": ${klusterlet}," \
         "\"done\": true"
     "}"
