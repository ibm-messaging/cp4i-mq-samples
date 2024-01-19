#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# TODO Requires cert manager to be installed

NAMESPACE=cp4i
QMNAME=qmadmin

cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${QMNAME}-ca
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${QMNAME}-ca
spec:
  commonName: ca
  isCA: true
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ${QMNAME}-ca
  secretName: ${QMNAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${QMNAME}-cert
spec:
  ca:
    secretName: ${QMNAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${QMNAME}-cert-client
spec:
  commonName: cp4i.ddd-dev
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ${QMNAME}-cert
  secretName: ${QMNAME}-cert-client
  subject:
    organizationalUnits:
    - my-team
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${QMNAME}-cert-server
spec:
  commonName: cert
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ${QMNAME}-cert
  secretName: ${QMNAME}-cert-server
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${QMNAME}
data:
  myqm.ini: "Service:\n\tName=AuthorizationService\n\tEntryPoints=14\n\tSecurityPolicy=UserExternal"
  myqm.mqsc: |-
    DEFINE CHANNEL('MTLS.SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER') REPLACE
    ALTER QMGR CONNAUTH(' ')
    REFRESH SECURITY
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=*') USERSRC(NOACCESS) ACTION(REPLACE)
    SET CHLAUTH('*') TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(NOACCESS) ACTION(REPLACE)
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=cp4i.ddd-dev,OU=my-team') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    DEFINE QLOCAL('Q1') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
    REFRESH SECURITY
    ALTER QMGR DEADQ(SYSTEM.DEAD.LETTER.QUEUE)
---
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${QMNAME}
spec:
  version: 9.3.4.1-r1
  license:
    accept: true
    license: L-VTPK-22YZPK
    use: NonProduction
  queueManager:
    ini:
    - configMap:
        items:
        - myqm.ini
        name: ${QMNAME}
    mqsc:
    - configMap:
        items:
        - myqm.mqsc
        name: ${QMNAME}
  pki:
    keys:
    - name: default
      secret:
        items:
        - tls.key
        - tls.crt
        - ca.crt
        secretName: ${QMNAME}-cert-server
  web:
    enabled: true
EOF

# wait 5 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes, but just in case)
for i in {1..60}
do
  phase=`oc get qmgr -n ${NAMESPACE} ${QMNAME} -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for ${QMNAME}...$i"
  oc get qmgr -n ${NAMESPACE} ${QMNAME}
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager ${QMNAME} is ready; 
   exit; 
fi

echo "*** Queue Manager ${QMNAME} is not ready ***"
exit 1
