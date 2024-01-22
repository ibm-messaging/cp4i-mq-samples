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

# Ensure we start fresh
rm -f ca.crt tls.crt tls.key application.*

CLIENT_CERTIFICATE_SECRET=qm-${QMNAME}-client
echo "CLIENT_CERTIFICATE_SECRET=${CLIENT_CERTIFICATE_SECRET}"
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["ca.crt"]' | base64 --decode > ca.crt
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.crt"]' | base64 --decode > tls.crt
oc get -n ${NAMESPACE} secret $CLIENT_CERTIFICATE_SECRET -o json | jq -r '.data["tls.key"]' | base64 --decode > tls.key

# Different for Mac arm
if [[ $(uname -m) == 'arm64' ]]; then
    echo "Cannot currently get mutual TLS working on Mac arm64."
    echo "In theory it should just be a case of putting the ca.crt and tls.crt into a pem and using it, but cannot get that working."
    echo "See https://community.ibm.com/community/user/integration/blogs/soheel-chughtai1/2023/03/28/messaging-on-apple-silicon"
    exit 1
else
    # Create .kdb/.sth files
    echo "Create application.p12"
    openssl pkcs12 -export -out application.p12 -inkey tls.key -in tls.crt -passout pass:password

    echo "Create empty kdb"
    runmqakm -keydb -create -db application.kdb -pw password -type cms -stash

    echo "Add ca to kdb"
    runmqakm -cert -add -db application.kdb -file ca.crt -stashed

    echo "Add p12 to kdb"
    label=ibmwebspheremq`id -u -n`
    echo "Setting label to: ${label}"
    runmqakm -cert -import -target application.kdb -file application.p12 -target_stashed -pw password -new_label $label

    echo "Tidying up intermediate files"
    rm -f ca.crt tls.crt tls.key application.pem application.p12 application.rdb
fi
