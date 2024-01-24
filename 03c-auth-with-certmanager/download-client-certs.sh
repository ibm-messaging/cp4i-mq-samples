#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

NAMESPACE=cp4i
USER=app1

# Make sure the following name is good for both a CR and and MQ name
MS_NAME=test

if [[ $# > 0 ]]; then
    USER=$1
fi

# Ensure we start fresh
rm -f ca.crt tls.crt tls.key ${USER}.*

CLIENT_CERTIFICATE_SECRET=ms-${MS_NAME}-${USER}-client
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
    echo "Create ${USER}.p12"
    openssl pkcs12 -export -out ${USER}.p12 -inkey tls.key -in tls.crt -passout pass:password

    echo "Create empty kdb"
    runmqakm -keydb -create -db ${USER}.kdb -pw password -type cms -stash

    echo "Add ca to kdb"
    runmqakm -cert -add -db ${USER}.kdb -file ca.crt -stashed

    echo "Add p12 to kdb"
    label=ibmwebspheremq`id -u -n`
    echo "Setting label to: ${label}"
    runmqakm -cert -import -target ${USER}.kdb -file ${USER}.p12 -target_stashed -pw password -new_label $label

    echo "Tidying up intermediate files"
    rm -f ca.crt tls.crt tls.key ${USER}.pem ${USER}.p12 ${USER}.rdb
fi
