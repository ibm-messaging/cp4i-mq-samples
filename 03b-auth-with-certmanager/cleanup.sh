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
oc delete issuers -n ${NAMESPACE} ${QMNAME}-ca ${QMNAME}-cert
oc delete certificates -n ${NAMESPACE} ${QMNAME}-ca ${QMNAME}-cert-client ${QMNAME}-cert-server
oc delete configmaps -n ${NAMESPACE} ${QMNAME}
oc delete queuemanagers -n ${NAMESPACE} ${QMNAME}

# Delete files TODO
# rm qm3.crt qm3.key app1key.* app1.* ccdt.json 
