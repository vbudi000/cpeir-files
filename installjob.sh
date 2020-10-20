#!/bin/bash

## Start up script for the cpeir runtime

# Step 1: Check OC Client

occlient=$(oc version | grep Client | awk '{print $3}')
ocserver=$(oc version | grep Server | awk '{print $3}')

echo $ocserver

if [ occlient != ocserver ]; then
    curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${ocserver}/openshift-client-linux.tar.gz --output /tmp/client.tar.gz
    tar -xzf /tmp/client.tar.gz
    mv oc /usr/local/bin/oc
    mv kubectl /usr/local/bin/kubectl
    rm -f /tmp/client.tar.gz README.md
fi

# Step 2: Download scripts from GIT

mkdir /files
cd /files
filesRepo=${CPEIR_FILES_GIT:-"https://github.com/vbudi000/cpeir-files"}
filesRepoFolder=${filesRepo##*/}
git clone ${filesRepo}

mv -T /files/${filesRepoFolder}/installjob /install
chmod -R a+x /install


# Step 3: Start the nodejs server

bash /install/$1.sh
