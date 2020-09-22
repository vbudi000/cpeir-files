#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)
  inst="false"

echo "{\"installed\": ${inst}, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
