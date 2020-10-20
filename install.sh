#!/bin/bash

OBJID=$1
CPARG=$2


res=""
if [ -f /install/${CPARG}.sh ]; then
  res=$(/bin/bash /install/${CPARG}.sh ${OBJID})
fi

if [ -z "$res" ]; then
  res="{}"
fi

echo ${res}

exit 0
