#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Create a private key and a self-signed certificate for the queue manager

openssl req -newkey rsa:2048 -nodes -keyout qm8.key -subj "/CN=qm8" -x509 -days 3650 -out qm8.crt

# Create a private key and a self-signed certificate for the client application

openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

# Create the client JKS key store:

# First export the client key and certificate to a pkcs12 repository...
openssl pkcs12 -export -out app1.p12 -inkey app1.key -in app1.crt -password pass:password -name app1cert

# ...next create jks key store and import pcks12
keytool -importkeystore -deststorepass password -destkeypass password -destkeystore app1key.jks -deststoretype jks -alias app1cert -destalias app1cert -srckeystore app1.p12 -srcstoretype PKCS12 -srcstorepass password

# Create the client's JKS trust store and import queue manager certificate

keytool -keystore trust.jks -storetype jks -importcert -file qm8.crt -alias qm8cert -storepass password -noprompt

# Create TLS Secret for the Queue Manager

oc create secret tls example-08-qm8-secret -n cp4i --key="qm8.key" --cert="qm8.crt"

# Create TLS Secret with the client's certificate

oc create secret generic example-08-app1-secret -n cp4i --from-file=app1.crt=app1.crt

# Create a config map containing MQSC commands

cat > qm8-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-08-qm8-configmap
data:
  qm8.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM8CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM8CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm8.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF

oc apply -n cp4i -f qm8-configmap.yaml

# Create the required route for SNI

cat > qm8chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-08-qm8-route
spec:
  host: qm8chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm8-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF

oc apply -n cp4i -f qm8chl-route.yaml

# Deploy the queue manager

cat > qm8-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm8
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM8
    ini:
      - configMap:
          name: example-08-qm8-configmap
          items:
            - qm8.ini
    mqsc:
    - configMap:
        name: example-08-qm8-configmap
        items:
        - qm8.mqsc
    storage:
      queueManager:
        type: ephemeral
  version: 9.3.0.0-r2
  web:
    enabled: false
  pki:
    keys:
      - name: example
        secret:
          secretName: example-08-qm8-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-08-app1-secret
        items:
          - app1.crt
EOF

oc apply -n cp4i -f qm8-qmgr.yaml

# wait 5 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes, but just in case)
for i in {1..60}
do
  phase=`oc get qmgr -n cp4i qm8 -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for qm8...$i"
  oc get qmgr -n cp4i qm8
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager qm8 is ready; 
   exit; 
fi

echo "*** Queue Manager qm8 is not ready ***"
exit 1
