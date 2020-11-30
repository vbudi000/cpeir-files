#!/bin/bash
#set -x

normcpu () {
  local value=$1
  local val1=${value//[!0-9]/}
  local val2=${value//[0-9]/}

  if [ $val2 = "m" ]; then
    result=${val1}
  elif [ $val2 = "" ]; then
    result=$(( val1 * 1000 ))
  elif [ $val2 = "k" ]; then
    result=$(( val1*1000000 ))
  else
    result=${val1}
  fi
  echo $result
}

normmem () {
  local value=$1
  local val1=${value//[!0-9]/}
  local val2=${value//[0-9]/}

  if [ $val2 = "Ki" ]; then
    result=${val1}
  elif [ $val2 = "Mi" ]; then
    result=$(( val1*1024 ))
  elif [ $val2 = "Gi" ]; then
    result=$(( val1*1024*1024 ))
  elif [ $val2 = "" ]; then
    result=$(( val1/1024 ))
  else
    result=${val1}
  fi
  echo $result
}

totcpu=0
totmem=0
maxcpu=0
maxmem=0
archlist=""
numnode=0
# Get capacity of the cluster
for node in $(oc get node -l node-role.kubernetes.io/worker,cluster.ocs.openshift.io/openshift-storage!="" --no-headers -o custom-columns=name:metadata.name)
do
  numnode=$(( numnode+1 ))
  alloc=$(oc get node ${node} --no-headers -o custom-columns=cpu:status.allocatable.cpu,memory:status.allocatable.memory,arch:status.nodeInfo.architecture,kubelet:status.nodeInfo.kubeletVersion)
  used=$(oc adm top node ${node} --no-headers | awk '{print $2 " " $4}')
  cpualloc=$(echo $alloc | cut -d' ' -f1)
  memalloc=$(echo $alloc | cut -d' ' -f2)
  arch=$(echo $alloc | cut -d' ' -f3)
  kubelet=$(echo $alloc | cut -d' ' -f4)
  cpuused=$(echo $used | cut -d ' ' -f1)
  memused=$(echo $used | cut -d ' ' -f2)

  if [[ "$archlist" != *"$arch"* ]]; then
    archlist="$archlist $arch"
  fi
  # normalize memory to Ki
  # normalize cpu to m
  ncpualloc=$(normcpu $cpualloc)
  ncpuused=$(normcpu $cpuused)
  nmemalloc=$(normmem $memalloc)
  nmemused=$(normmem $memused)

  cpuavail=$(( ncpualloc-ncpuused ))
  memavail=$(( nmemalloc-nmemused ))

  # echo $node $cpuavail $memavail

  if [[ $maxcpu < $cpuavail ]]; then
     maxcpu=$cpuavail
  fi
  if [[ $maxmem < $memavail ]]; then
     maxmem=$memavail
  fi
  totcpu=$(( totcpu+cpuavail ))
  totmem=$(( totmem+memavail ))
done

archlist=$(echo $archlist | xargs)

echo "{\"totcpu\":\"${totcpu}m\",\"totmem\":\"${totmem}Ki\"," \
      "\"maxcpu\":\"${maxcpu}m\",\"maxmem\":\"${maxmem}Ki\"," \
      "\"arch\":\"${archlist}\",\"numnode\":${numnode},\"kubelet\":\"${kubelet}\"}"

exit 0
