#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)

mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.0.0 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)

if [ "$mcmcsvphase" = "Succeeded" ]; then
  inst="true"
else
  inst="false"
fi


echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
