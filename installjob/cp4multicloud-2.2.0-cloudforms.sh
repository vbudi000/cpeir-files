#!/bin/bash

echo "Creating CloudPak for MultiCloud Management - CloudForms feature"

counter=0
mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.2.5 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)

until [ "$mcmcsvphase" = "Succeeded" ]; do
  ((counter++))
  if [ $counter -gt 100 ]; then
     echo "Timeout waiting for MCM core"
     exit 999
  fi
  sleep 60
  mcmcsvphase=$(oc get csv ibm-management-hybridapp.v2.2.5 -n kube-system --no-headers -o custom-columns=mcm:status.phase 2>/dev/null)
  now=$(date)
  echo "${now} - Checking whether MCM core is installed; step ${counter} of 100"
done
now=$(date)
echo "${now} - MCM core is installed "

echo "Step 1 - getting necessary setup"

CLIENT_ID=$(echo There is a huge white elephant in LA zoo | base64)
CLIENT_SECRET=$(echo 12345678901234567890123456789012345 | base64)
CP4MCM_ROUTE=$(oc -n ibm-common-services get route cp-console --template '{{.spec.host}}')
IM_HTTPD_ROUTE=$(echo $CP4MCM_ROUTE | sed s/cp-console/inframgmtinstall/)
CP_PASSWORD=$(oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d)

echo CLIENT_ID = $CLIENT_ID
echo CLIENT_SECRET = $CLIENT_SECRET
echo CP4MCM_ROUTE = $CP4MCM_ROUTE
echo IM_HTTPD_ROUTE = $IM_HTTPD_ROUTE
echo CP_PASSWORD = $CP_PASSWORD
echo ENTITLED_REGISTRY_SECRET = $ENTITLED_REGISTRY_SECRET

curl -kLo cloudctl https://${CP4MCM_ROUTE}/api/cli/cloudctl-linux-amd64
chmod a+x cloudctl

./cloudctl login -a $CP4MCM_ROUTE --skip-ssl-validation -u admin -p $CP_PASSWORD -n ibm-common-services

#
# Register IAM OAUTH client
#
echo "Step 2 - Registering IAM OAUTH client."
cat << EOF > registration.json
{
    "token_endpoint_auth_method": "client_secret_basic",
    "client_id": "$CLIENT_ID",
    "client_secret": "$CLIENT_SECRET",
    "scope": "openid profile email",
    "grant_types": [
        "authorization_code",
        "client_credentials",
        "password",
        "implicit",
        "refresh_token",
        "urn:ietf:params:oauth:grant-type:jwt-bearer"
    ],
    "response_types": [
        "code",
        "token",
        "id_token token"
    ],
    "application_type": "web",
    "subject_type": "public",
    "post_logout_redirect_uris": [
        "https://$CP4MCM_ROUTE"
    ],
    "preauthorized_scope": "openid profile email general",
    "introspect_tokens": true,
    "trusted_uri_prefixes": [
        "https://$CP4MCM_ROUTE/"
    ],
    "redirect_uris": ["https://$CP4MCM_ROUTE/auth/liberty/callback", "https://$IM_HTTPD_ROUTE/oidc_login/redirect_uri"]
}
EOF

./cloudctl iam oauth-client-register -f registration.json

#
# Create imconnectionsecret
#
echo "Step 3 - Creating imconnectionsecret."
oc create -f - <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: imconnectionsecret
  namespace: management-infrastructure-management
stringData:
  oidc.conf: |-
    LoadModule          auth_openidc_module modules/mod_auth_openidc.so
    ServerName          https://$IM_HTTPD_ROUTE
    LogLevel            debug
    OIDCCLientID                   $CLIENT_ID
    OIDCClientSecret               $CLIENT_SECRET
    OIDCRedirectURI                https://$IM_HTTPD_ROUTE/oidc_login/redirect_uri
    OIDCCryptoPassphrase           alphabeta
    OIDCOAuthRemoteUserClaim       sub
    OIDCRemoteUserClaim            name
    # OIDCProviderMetadataURL missing
    OIDCProviderIssuer                  https://127.0.0.1:443/idauth/oidc/endpoint/OP
    OIDCProviderAuthorizationEndpoint   https://$CP4MCM_ROUTE/idprovider/v1/auth/authorize
    OIDCProviderTokenEndpoint           https://$CP4MCM_ROUTE/idprovider/v1/auth/token
    OIDCOAuthCLientID                   $CLIENT_ID
    OIDCOAuthClientSecret               $CLIENT_SECRET
    OIDCOAuthIntrospectionEndpoint      https://$CP4MCM_ROUTE/idprovider/v1/auth/introspect
    # ? OIDCOAuthVerifyJwksUri          https://$CP4MCM_ROUTE/oidc/endpoint/OP/jwk
    OIDCProviderJwksUri                 https://$CP4MCM_ROUTE/oidc/endpoint/OP/jwk
    OIDCProviderEndSessionEndpoint      https://$CP4MCM_ROUTE/idprovider/v1/auth/logout
    OIDCScope                        "openid email profile"
    OIDCResponseMode                 "query"
    OIDCProviderTokenEndpointAuth     client_secret_post
    OIDCOAuthIntrospectionEndpointAuth client_secret_basic
    OIDCPassUserInfoAs json
    OIDCSSLValidateServer off
    OIDCHTTPTimeoutShort 10
    OIDCCacheEncrypt On

    <Location /oidc_login>
      AuthType  openid-connect
      Require   valid-user
      LogLevel   debug
    </Location>
    <LocationMatch ^/api(?!\/(v[\d\.]+\/)?product_info$)>
      SetEnvIf Authorization '^Basic +YWRtaW46'     let_admin_in
      SetEnvIf X-Auth-Token  '^.+$'                 let_api_token_in
      SetEnvIf X-MIQ-Token   '^.+$'                 let_sys_token_in
      SetEnvIf X-CSRF-Token  '^.+$'                 let_csrf_token_in
      AuthType     oauth20
      AuthName     "External Authentication (oauth20) for API"
      Require   valid-user
      Order          Allow,Deny
      Allow from env=let_admin_in
      Allow from env=let_api_token_in
      Allow from env=let_sys_token_in
      Allow from env=let_csrf_token_in
      Satisfy Any
      LogLevel   debug
    </LocationMatch>
    OIDCSSLValidateServer      Off
    OIDCOAuthSSLValidateServer Off
    RequestHeader unset X_REMOTE_USER
    RequestHeader set X_REMOTE_USER           %{OIDC_CLAIM_PREFERRED_USERNAME}e env=OIDC_CLAIM_PREFERRED_USERNAME
    RequestHeader set X_EXTERNAL_AUTH_ERROR   %{EXTERNAL_AUTH_ERROR}e           env=EXTERNAL_AUTH_ERROR
    RequestHeader set X_REMOTE_USER_EMAIL     %{OIDC_CLAIM_EMAIL}e              env=OIDC_CLAIM_EMAIL
    RequestHeader set X_REMOTE_USER_FIRSTNAME %{OIDC_CLAIM_GIVEN_NAME}e         env=OIDC_CLAIM_GIVEN_NAME
    RequestHeader set X_REMOTE_USER_LASTNAME  %{OIDC_CLAIM_FAMILY_NAME}e        env=OIDC_CLAIM_FAMILY_NAME
    RequestHeader set X_REMOTE_USER_FULLNAME  %{OIDC_CLAIM_NAME}e               env=OIDC_CLAIM_NAME
    RequestHeader set X_REMOTE_USER_GROUPS    %{OIDC_CLAIM_GROUPS}e             env=OIDC_CLAIM_GROUPS
    RequestHeader set X_REMOTE_USER_DOMAIN    %{OIDC_CLAIM_DOMAIN}e             env=OIDC_CLAIM_DOMAIN
EOF


#
# Create IMInstall
#
echo "Step 4 - Creating CloudForms IMInstall"
oc create -f - <<EOF
apiVersion: infra.management.ibm.com/v1alpha1
kind: IMInstall
metadata:
  labels:
    app.kubernetes.io/instance: ibm-infra-management-install-operator
    app.kubernetes.io/managed-by: ibm-infra-management-install-operator
    app.kubernetes.io/name: ibm-infra-management-install-operator
  name: im-iminstall
  namespace: management-infrastructure-management
spec:
  applicationDomain: $IM_HTTPD_ROUTE
  imagePullSecret: $ENTITLED_REGISTRY_SECRET
  httpdAuthenticationType: openid-connect
  httpdAuthConfig: imconnectionsecret
  enableSSO: true
  initialAdminGroupName: operations
  license:
    accept: true
  orchestratorInitialDelay: '2400'
EOF

#
# Wait for IM
#
echo "Step 5 - Creating IM Connection Resource"

sleep 30

#
# Create Connection
#
oc create -f - <<EOF
 apiVersion: infra.management.ibm.com/v1alpha1
 kind: Connection
 metadata:
   annotations:
     BypassAuth: "true"
   labels:
    controller-tools.k8s.io: "1.0"
   name: imconnection
   namespace: "management-infrastructure-management"
 spec:
   cfHost: web-service.management-infrastructure-management.svc.cluster.local:3000
EOF

#
# Wait for install
#
echo "Step 6 - Waiting for installation to complete. (180 seconds)"
sleep 20
pendingcnt=$(oc get pod -n management-infrastructure-management --no-headers | grep -v "Running\|Completed" | wc -l)
counter=0
until [ $pendingcnt -le 0 ]; do
  ((counter++))
  sleep 40
  pendingcnt=$(oc get pod -n management-infrastructure-management --no-headers | grep -v "Running\|Completed" | wc -l)
  if [ $counter -gt 40 ]; then
    echo "counter too much"
    exit 999
  fi
done
#
# Create links in the UI
#
echo "Step 7 - Applying navigation UI updates."

curl -kLo jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod a+x jq
export PATH=$PATH:.
curl -kLo automation-navigation-updates.sh https://raw.githubusercontent.com/ibm-garage-tsa/cp4mcm-installer/master/cp4m/automation-navigation-updates.sh
bash ./automation-navigation-updates.sh -p

exit 0
