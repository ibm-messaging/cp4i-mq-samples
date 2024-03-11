#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Find the queue manager host name
NAMESPACE=cp4i
QMNAME=qmadmin

qmhostname=`oc get route -n ${NAMESPACE} ${QMNAME}-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname


# Test:

ping -c 3 $qmhostname

# Create ccdt.json

cat > ccdt.json << EOF
{
    "channel":
    [
        {
            "name": "MTLS.SVRCONN",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "${QMNAME}"
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
export MQSSLKEYR=app1
# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL
echo MQSSLKEYR=$MQSSLKEYR
ls -l $MQSSLKEYR.*
export MQCLNTCF=$(pwd)/client.ini

# Put messages to the queue

echo "Test message 1" | amqsputc Q1 ${QMNAME}
echo "Test message 2" | amqsputc Q1 ${QMNAME}

