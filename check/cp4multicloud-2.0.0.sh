#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)
OUT=`oc get po --no-headers=true -A | grep -v 'Running\|Completed\|gateway-kong' | grep 'kube-system\|ibm-common-services\|management-infrastructure-management\|management-monitoring\|management-operations\|management-security-services'`
WC=$(printf "%s\n" "$OUT" | wc | awk '{print $1}')

if  [[ $wc -le 0 ]]; then
  inst="true"
  depname=$(oc get deployment -l app.kubernetes.io/instance=multicluster-hub -A --no-headers -o custom-columns=name:metadata.name | head -n 1)
  version=$(oc label deployment ${depname} -n kube-system --list | grep helm.sh | cut -d- -f2)
else
  inst="false"
fi

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
