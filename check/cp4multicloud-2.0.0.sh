#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)
mcm=$(oc get deployment -l app.kubernetes.io/instance=multicluster-hub -A --no-headers 2>/dev/null | wc -l)
if  [[ $mcm -gt 20 ]]; then
  inst="true"
  depname=$(oc get deployment -l app.kubernetes.io/instance=multicluster-hub -A --no-headers -o custom-columns=name:metadata.name | head -n 1)
  version=$(oc label deployment ${depname} -n kube-system --list | grep helm.sh | cut -d- -f2)
else
  inst="false"
fi

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
