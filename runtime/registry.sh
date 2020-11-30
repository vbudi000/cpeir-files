#!/bin/bash
#set -x
# check registry operator

mgmtState=$(oc get config cluster -o custom-columns=mgmt:spec.managementState --no-headers)
if [ $mgmtState = "Managed" ]; then
  config="true"
  storage=$(oc get config cluster -o custom-columns=storage:spec.storage)
  if [[ "$storage" == *"pvc"* ]]; then
    regpod=$(oc get pod -n openshift-image-registry -o custom-columns=name:metadata.name | grep image-registry | grep -v operator)
    regsize=$(oc exec ${regpod} -n openshift-image-registry -- df -k  | grep \/registry | awk '{print $4}')
  else
    regsize="999999999"
  fi
  cap=$regsize

  regpub=$(oc registry info --public 2>/dev/null | wc -l)
  if [[ $regpub<1 ]]; then
    external="false"
  else
    external="true"
  fi

else
  cap=0
  config="false"
  external="false"
fi

echo "{\"configured\":${config},\"external\":${external},\"capacity\":\"${cap}Ki\"}"

exit
