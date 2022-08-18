#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Create a private key and a self-signed certificate for the queue manager

openssl req -newkey rsa:2048 -nodes -keyout qm2.key -subj "/CN=qm2" -x509 -days 3650 -out qm2.crt

# Create a private key and a self-signed certificate for the client application

openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

# Create the client key database:

runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

# Add the queue manager public key to the client key database:

runmqakm -cert -add -db app1key.kdb -label qm2cert -file qm2.crt -format ascii -stashed

# Add the client's certificate and key to the client key database:

# First, put the key (`app1.key`) and certificate (`app1.crt`) into a PKCS12 file. PKCS12 is a format suitable for importing into the client key database (`app1key.kdb`):

openssl pkcs12 -export -out app1.p12 -inkey app1.key -in app1.crt -password pass:password

# Next, import the PKCS12 file. The label **must be** `ibmwebspheremq<your userid>`:

label=ibmwebspheremq`id -u -n`
runmqakm -cert -import -target app1key.kdb -file app1.p12 -target_stashed -pw password -new_label $label

# Check. List the database certificates:

runmqakm -cert -list -db app1key.kdb -stashed

# Create TLS Secret for the Queue Manager

oc create secret tls example-02-qm2-secret -n cp4i --key="qm2.key" --cert="qm2.crt"

# Create TLS Secret with the client's certificate

oc create secret generic example-02-app1-secret -n cp4i --from-file=app1.crt=app1.crt

# Create a config map containing MQSC commands

cat > qm2-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-02-qm2-configmap
data:
  qm2.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM2CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    SET CHLAUTH(QM2CHL) TYPE(BLOCKUSER) USERLIST('nobody') ACTION(ADD)
EOF

oc apply -n cp4i -f qm2-configmap.yaml

# Create the required route for SNI

cat > qm2chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-02-qm2-route
spec:
  host: qm2chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm2-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF

oc apply -n cp4i -f qm2chl-route.yaml

# Deploy the queue manager

cat > qm2-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm2
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM2
    mqsc:
    - configMap:
        name: example-02-qm2-configmap
        items:
        - qm2.mqsc
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
          secretName: example-02-qm2-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-02-app1-secret
        items:
          - app1.crt
EOF

oc apply -n cp4i -f qm2-qmgr.yaml

# wait 5 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes, but just in case)
for i in {1..60}
do
  phase=`oc get qmgr -n cp4i qm2 -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for qm2...$i"
  oc get qmgr -n cp4i qm2
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager qm2 is ready; 
   exit; 
fi

echo "*** Queue Manager qm2 is not ready ***"
exit 1
