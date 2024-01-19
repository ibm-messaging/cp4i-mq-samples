#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Find the queue manager host name

qmhostname=`oc get route -n cp4i qm2-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname


# Test:

ping -c 3 $qmhostname

# Create ccdt.json

cat > ccdt.json << EOF
{
    "channel":
    [
        {
            "name": "QM2CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM2"
            },
            "transmissionSecurity":
            {
              "cipherSpecification": "ANY_TLS12_OR_HIGHER"
            },
            "type": "clientConnection"
        }
   ]
}
EOF

# Set environment variables for the client

export MQCCDTURL=ccdt.json

# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL

if [[ $(uname -m) == 'arm64' ]]; then
    export MQSSLTRUSTSTORE=$(pwd)/trust.pem
    export MQSSLKEYR=$(pwd)/app.pem
    # export MQSSLKEYRPWD=password
    echo MQSSLKEYR=$MQSSLKEYR
    ls -l $MQSSLKEYR
else
    export MQSSLKEYR=app1key
    echo MQSSLKEYR=$MQSSLKEYR
    ls -l $MQSSLKEYR.*
fi
export MQCLNTCF=$(pwd)/client.ini

# Get messages from the queue

amqsbcgc Q1 QM2
