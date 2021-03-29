#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)

sec1=$(helm list -n cp4security | wc -l)
sec2=$(helm list -n cp4security | grep -v deployed | wc -l)

if [ "$sec1" -eq "5" -a "$sec2" -eq "1" ]; then
  inst="true"
else
  inst="false"
fi

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
