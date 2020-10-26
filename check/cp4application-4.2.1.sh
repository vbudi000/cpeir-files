#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)

csvnum=$(oc get csv -n ta --no-headers 2>/dev/null | wc -l)
csvsuc=$(oc get csv -n ta --no-headers 2>/dev/null | grep -v "Succeeded" | wc -l)

if [ "$csvnum" .gt "0" ]; then
  if [ "$csvsuc" .eq "0" ]; then
    inst="true"
  else
    inst="false"
  fi
else
  inst="false"
fi

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
