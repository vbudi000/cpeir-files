#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)
cpname=$(echo ${name} | cut -d- -f1)
feature=$(echo ${name} | cut -d- -f3)

mcmcsvphase=$(oc get csv ibm-management-monitoring.v2.1.5 -n management-monitoring --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)

if [ "$mcmcsvphase" = "Succeeded" ]; then
  inst="true"
else
  inst="false"
fi


echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
