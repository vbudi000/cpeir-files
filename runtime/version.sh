#!/bin/bash

version=$(oc get clusterversion --no-headers -o custom-columns=version:status.desired.version)
channel=$(oc get clusterversion --no-headers -o custom-columns=channel:spec.channel)

echo "{\"version\":\"${version}\",\"channel\":\"${channel}\"}"

exit
