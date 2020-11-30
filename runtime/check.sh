#!/bin/bash
OBJID=$1
CPARG=$2

res=""
if [ -f /check/${CPARG}.sh ]; then
  res=$(/bin/bash /check/${CPARG}.sh ${OBJID})
fi

if [ -z "$res" ]; then
  res="{}"
fi

echo ${res}

exit 0
