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

CLIENT_CERTIFICATE_SECRET=qm-${QMNAME}-client
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
    echo "Create application.p12"
    openssl pkcs12 -export -out application.p12 -inkey tls.key -in tls.crt -passout pass:password

    echo "Create empty kdb"
    runmqakm -keydb -create -db application.kdb -pw password -type cms -stash

    echo "Add ca to kdb"
    runmqakm -cert -add -db application.kdb -file ca.crt -stashed

    echo "Add p12 to kdb"
#    runmqakm -cert -import -file application.p12 -pw password -type pkcs12 -target application.kdb -target_pw password -target_type cms -label "1" -new_label aceclient
    label=ibmwebspheremq`id -u -n`
    echo "Setting label to: ${label}"
    runmqakm -cert -import -target application.kdb -file application.p12 -target_stashed -pw password -new_label $label

    ls -al
    rm ca.crt tls.crt tls.key application.pem application.p12 application.rdb
    ls -al
fi
