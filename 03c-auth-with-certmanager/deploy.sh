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
BLOCK_STORAGE_CLASS=rook-ceph-block

# Make sure the following name is good for both a CR and and MQ name
MS_NAME=test

cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ms-${MS_NAME}-ca
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ms-${MS_NAME}-ca
spec:
  commonName: ca
  isCA: true
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ms-${MS_NAME}-ca
  secretName: ms-${MS_NAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ms-${MS_NAME}-issuer
spec:
  ca:
    secretName: ms-${MS_NAME}-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ms-${MS_NAME}-server
spec:
  commonName: cert
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ms-${MS_NAME}-issuer
  secretName: ms-${MS_NAME}-server
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms-${MS_NAME}-default
data:
  myqm.ini: "Service:\n\tName=AuthorizationService\n\tEntryPoints=14\n\tSecurityPolicy=UserExternal"
  myqm.mqsc: |-
    DEFINE CHANNEL('MTLS.SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER') REPLACE
    ALTER QMGR CONNAUTH(' ')
    REFRESH SECURITY
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=*') USERSRC(NOACCESS) ACTION(REPLACE)
    SET CHLAUTH('*') TYPE(ADDRESSMAP) ADDRESS('*') USERSRC(NOACCESS) ACTION(REPLACE)

    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=cp4iadmin,OU=${NAMESPACE}.${MS_NAME}') USERSRC(MAP) MCAUSER('cp4iadmin') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('cp4iadmin') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ,DSP)
    SET AUTHREC PROFILE('SYSTEM.ADMIN.COMMAND.QUEUE') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)
    SET AUTHREC PROFILE('SYSTEM.DEFAULT.MODEL.QUEUE') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)
    SET AUTHREC PROFILE('*') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms-${MS_NAME}-queues
data:
  myqm.mqsc: |
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=app1,OU=${NAMESPACE}.${MS_NAME}') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    DEFINE QLOCAL('Q1') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)

    REFRESH SECURITY
---
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  annotations:
    com.ibm.mq/write-defaults-spec: "false"
  name: ${MS_NAME}
spec:
  license:
    accept: true
    license: L-VTPK-22YZPK
    metric: VirtualProcessorCore
    use: NonProduction
  pki:
    keys:
    - name: default
      secret:
        items:
        - tls.key
        - tls.crt
        - ca.crt
        secretName: ms-${MS_NAME}-server
  queueManager:
    ini:
    - configMap:
        items:
        - myqm.ini
        name: ms-${MS_NAME}-default
    mqsc:
    - configMap:
        items:
        - myqm.mqsc
        name: ms-${MS_NAME}-default
    - configMap:
        items:
        - myqm.mqsc
        name: ms-${MS_NAME}-queues
    storage:
      defaultClass: ${BLOCK_STORAGE_CLASS}
  version: 9.3.4.1-r1
  web:
    enabled: true
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ms-${MS_NAME}-app1-client
spec:
  commonName: app1
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ms-${MS_NAME}-issuer
  secretName: ms-${MS_NAME}-app1-client
  subject:
    organizationalUnits:
    - ${NAMESPACE}.${MS_NAME}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ms-${MS_NAME}-cp4iadmin-client
spec:
  commonName: cp4iadmin
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: ms-${MS_NAME}-issuer
  secretName: ms-${MS_NAME}-cp4iadmin-client
  subject:
    organizationalUnits:
    - ${NAMESPACE}.${MS_NAME}
EOF

# wait 20 minutes for queue manager to be up and running
# (shouldn't take more than 2 minutes if keycloak is already setup, but just in case)
for i in {1..240}
do
  phase=`oc get qmgr -n ${NAMESPACE} ${MS_NAME} -o jsonpath="{.status.phase}"`
  if [ "$phase" == "Running" ] ; then break; fi
  echo "Waiting for ${MS_NAME}...$i"
  oc get qmgr -n ${NAMESPACE} ${MS_NAME}
  sleep 5
done

if [ $phase == Running ]
   then echo Queue Manager ${MS_NAME} is ready; 
   exit; 
fi

echo "*** Queue Manager ${MS_NAME} is not ready ***"
exit 1
