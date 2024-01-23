#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#
NAMESPACE=cp4i
QMNAME=qmadmin

# Delete CRs
oc delete assemblies -n ${NAMESPACE} ${QMNAME}
oc delete certificates -n ${NAMESPACE} qm-${QMNAME}-app1-client qm-${QMNAME}-cp4iadmin-client
oc delete configmaps -n ${NAMESPACE} qm-${QMNAME}-queues
oc delete secrets -n ${NAMESPACE} ia-${NAMESPACE}-${QMNAME}-ca qm-${QMNAME}-app1-client qm-${QMNAME}-cp4iadmin-client qm-${QMNAME}-server
oc delete pvc -n ${NAMESPACE} data-${QMNAME}-ibm-mq-0

# Delete files TODO
# rm qm3.crt qm3.key app1key.* app1.* ccdt.json 
