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
IA_NAME=qmadmin
BLOCK_STORAGE_CLASS=rook-ceph-block

cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: qm-${QMNAME}-queues
data:
  myqm.mqsc: |
    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=cp4iadmin,OU=${NAMESPACE}.${QMNAME}') USERSRC(MAP) MCAUSER('cp4iadmin') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('cp4iadmin') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ,DSP)
    SET AUTHREC PROFILE('SYSTEM.ADMIN.COMMAND.QUEUE') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)
    SET AUTHREC PROFILE('SYSTEM.DEFAULT.MODEL.QUEUE') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)
    SET AUTHREC PROFILE('*') PRINCIPAL('cp4iadmin') OBJTYPE(QUEUE) AUTHADD(ALL)

    SET CHLAUTH('MTLS.SVRCONN') TYPE(SSLPEERMAP) SSLPEER('CN=app1,OU=${NAMESPACE}.${QMNAME}') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    DEFINE QLOCAL('Q1') DEFPSIST(YES) BOTHRESH(5) REPLACE
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)

    REFRESH SECURITY
---
apiVersion: integration.ibm.com/v1beta1
kind: IntegrationAssembly
metadata:
  name: ${IA_NAME}
  annotations:
    "operator.ibm.com/ia-managed-integrations-dry-run": "false"
spec:
  version: 2023.4.1
  license:
    accept: true
    license: L-VTPK-22YZPK
    use: CloudPakForIntegrationNonProduction
  storage:
    readWriteOnce:
      class: ${BLOCK_STORAGE_CLASS}
  managedInstances:
    list:
    - kind: QueueManager
      metadata:
        name: ${QMNAME}
      spec:
        queueManager:
          mqsc:
            - configMap:
                name: qm-${QMNAME}-default
                items:
                  - myqm.mqsc
            - configMap:
                name: qm-${QMNAME}-queues
                items:
                  - myqm.mqsc
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qm-${QMNAME}-app1-client
spec:
  commonName: app1
  subject:
    organizationalUnits:
    - ${NAMESPACE}.${QMNAME}
  secretName: qm-${QMNAME}-app1-client
  issuerRef:
    name: qm-${QMNAME}-issuer
    kind: Issuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: qm-${QMNAME}-cp4iadmin-client
spec:
  commonName: cp4iadmin
  subject:
    organizationalUnits:
    - ${NAMESPACE}.${QMNAME}
  secretName: qm-${QMNAME}-cp4iadmin-client
  issuerRef:
    name: qm-${QMNAME}-issuer
    kind: Issuer
    group: cert-manager.io
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
