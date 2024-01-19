#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

NAMESPACE=cp4i
QMNAME=qmadmin

CLIENT_CERTIFICATE_SECRET=${QMNAME}-cert-client
echo "CLIENT_CERTIFICATE_SECRET=${CLIENT_CERTIFICATE_SECRET}"
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > ca.crt
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > tls.crt
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > tls.key

# Different for Mac arm
if [[ $(uname -m) == 'arm64' ]]; then
    # Create pem file
    echo "TODO!!!"
else
    # Create .kdb/.sth files

    openssl pkcs12 -export -out application.p12 -inkey tls.key -in tls.crt -passout pass:password
    runmqakm -keydb -create -db application.kdb -pw password -type cms -stash
    runmqakm -cert -add -db application.kdb -label qm1cert -file ca.crt -format ascii -stashed
    runmqakm -cert -import -target application.kdb -file application.p12 -target_stashed -pw password -new_label aceclient
    ls -al
    rm ca.crt tls.crt tls.key application.pem application.p12 application.rdb
    ls -al
fi





