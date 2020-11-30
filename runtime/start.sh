#!/bin/bash

## Start up script for the cpeir runtime
name=$1
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

# Step 2: Download scripts from GIT

mkdir /files
cd /files
filesRepo=${CPEIR_FILES_GIT:-"https://github.com/vbudi000/cpeir-files"}
cpscriptRepo=${CPSCRIPT_GIT:-"https://github.com/vbudi000/cpeir-scripts"}
filesRepoFolder=${filesRepo##*/}
cpscriptRepoFolder=${cpscriptRepo##*/}
git clone ${filesRepo}
git clone ${cpscriptRepo}

mv -T /files/${filesRepoFolder}/check /check
mv -T /files/${filesRepoFolder}/install /install
mv /files/${filesRepoFolder}/config/* /cfgdata
mv -T /files/${cpscriptRepoFolder} /script

chmod -R a+x /check
chmod -R a+x /install
chmod -R a+x /script

cd /app

rm -rf /files

# Step 3: Start the nodejs server

node  app.js
