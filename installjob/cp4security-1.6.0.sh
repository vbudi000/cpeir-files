#!/bin/bash

echo "Step 1 - Downloading CLIs and setup openSSL"

# Download CloudCtl
export PATH=$PATH:.

curl -kLo cloudctl-linux-amd64.tar.gz https://github.com/IBM/cloud-pak-cli/releases/download/v3.7.0/cloudctl-linux-amd64.tar.gz
tar -xzf cloudctl-linux-amd64.tar.gz
chmod a+x cloudctl-linux-amd64
mv cloudctl-linux-amd64 cloudctl

cat <<EOF > ssl.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${APPDOMAIN}
EOF

openssl genrsa -passout pass:foobar -des3 -out myCA.key 2048
openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem -passin pass:foobar -subj /C=US/ST=TX/L=Austin/O=IBM/OU=CSM/CN=GTMAA
openssl genrsa -out cert.key 2048
openssl req -new -key cert.key -out cert.csr -subj /C=US/ST=TX/L=Austin/O=IBM/OU=CSM/CN=GTMAA
openssl x509 -req -in cert.csr -CA myCA.pem -CAkey myCA.key -passin pass:foobar -CAcreateserial -out cert.crt -days 999 -sha256 -extfile ssl.ext

echo "Step 2 - Downloading archive file and editing configuration "

cloudctl case save -t 1 --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-security-1.0.14.tgz --outputdir ./ && tar -xf ./ibm-cp-security-1.0.14.tgz
# Editing ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/adminUserId=""/adminUserId="admin"/' ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/storageClass=""/storageClass="'$STORAGECLASS'"/' ibm-cp-security/inventory/installProduct/files/values.conf
# cloudType="ocp"
sed -i 's/entitledRegistryPassword=""/entitledRegistryPassword="'$ENTITLED_REGISTRY_KEY'"/' ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/cp4sapplicationDomain=""/cp4sapplicationDomain="'$APPDOMAIN'"/' ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/cp4sdomainCertificatePath=""/cp4sdomainCertificatePath="cert.crt"/' ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/cp4sdomainCertificateKeyPath=""/cp4sdomainCertificateKeyPath="cert.key"/' ibm-cp-security/inventory/installProduct/files/values.conf
sed -i 's/cp4scustomcaFilepath=""/cp4scustomcaFilepath="myCA.pem"/' ibm-cp-security/inventory/installProduct/files/values.conf

echo "Step 3 - Running the installation"

cloudctl case launch -t 1 --case ibm-cp-security --namespace $NAMESPACE  --inventory installProduct --action install --args "--license accept --helm3 helm --inputDir ./"


exit 0
