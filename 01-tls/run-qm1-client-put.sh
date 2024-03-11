#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Find the queue manager host name

qmhostname=`oc get route -n cp4i qm1-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname


# Test:

ping -c 3 $qmhostname

# Create ccdt.json

cat > ccdt.json << EOF
{
    "channel":
    [
        {
            "name": "QM1CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM1"
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
    export MQSSLKEYR=$(pwd)/app.pem
    echo MQSSLKEYR=$MQSSLKEYR
    ls -l $MQSSLKEYR
else
    export MQSSLKEYR=app1key
    echo MQSSLKEYR=$MQSSLKEYR
    ls -l $MQSSLKEYR.*
fi

export MQCLNTCF=$(pwd)/client.ini

# Put messages to the queue

echo "Test message 1" | amqsputc Q1 QM1
echo "Test message 2" | amqsputc Q1 QM1

