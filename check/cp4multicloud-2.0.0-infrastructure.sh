#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)


mcmcsvphase=$(oc get csv -n management-infrastructure-management --no-headers | grep -v "Succeeded" | wc -l)

if [ "$mcmcsvphase" -gt 0 ]; then
  inst="false"
else
  inst="true"
fi

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
