#!/bin/bash

filename=$(basename $0)
name="${filename%.*}"
version=$(echo ${name} | cut -d- -f2)
echo "{\"installed\": true, \"name\": \"${name}\", \"version\": \"${version}\"}"
exit 0
