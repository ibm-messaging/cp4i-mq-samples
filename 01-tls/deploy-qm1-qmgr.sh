#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Create a private key and a self-signed certificate for the queue manager

openssl req -newkey rsa:2048 -nodes -keyout qm1.key -subj "/CN=qm1" -x509 -days 3650 -out qm1.crt

if [[ $(uname -m) == 'arm64' ]]; then
  # Copy the queue manager certificate into a pem for the client
  cat qm1.crt > app.pem
else
  # Create the client key database:

  runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

  # Add the queue manager public key to the client key database:

  runmqakm -cert -add -db app1key.kdb -label qm1cert -file qm1.crt -format ascii -stashed

  # Check. List the database certificates:

  runmqakm -cert -list -db app1key.kdb -stashed
fi




# Create TLS Secret for the Queue Manager

oc create secret tls example-01-qm1-secret -n cp4i --key="qm1.key" --cert="qm1.crt"

# Create a config map containing MQSC commands

cat > qm1-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-01-qm1-configmap
data:
  qm1.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM1CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(OPTIONAL) SSLCIPH('ANY_TLS12_OR_HIGHER')
    SET CHLAUTH(QM1CHL) TYPE(BLOCKUSER) USERLIST('nobody') ACTION(ADD)
EOF

oc apply -n cp4i -f qm1-configmap.yaml

# Deploy the queue manager

cat > qm1-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm1
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM1
    mqsc:
    - configMap:
        name: example-01-qm1-configmap
        items:
        - qm1.mqsc
    storage:
      queueManager:
        type: ephemeral
  template:
    pod:
      containers:
        - env:
            - name: MQSNOAUT
              value: 'yes'
          name: qmgr
  version: 9.3.0.0-r2
  web:
    enabled: false
  pki:
    keys:
      - name: example
        secret:
          secretName: example-01-qm1-secret
          items: 
          - tls.key
          - tls.crt
EOF

oc apply -n cp4i -f qm1-qmgr.yaml

# wait 5 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes, but just in case)
for i in {1..60}
do
  phase=`oc get qmgr -n cp4i qm1 -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for qm1...$i"
  oc get qmgr -n cp4i qm1
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager qm1 is ready; 
   exit; 
fi

echo "*** Queue Manager qm1 is not ready ***"
exit 1
