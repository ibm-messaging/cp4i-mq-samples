#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#
NAMESPACE=cp4i

# Make sure the following name is good for both a CR and and MQ name
MS_NAME=test

# Delete CRs
oc delete queuemanagers -n ${NAMESPACE} ${MS_NAME}
oc delete certificates -n ${NAMESPACE} ms-${MS_NAME}-ca ms-${MS_NAME}-server ms-${MS_NAME}-app1-client ms-${MS_NAME}-cp4iadmin-client
oc delete configmaps -n ${NAMESPACE} ms-${MS_NAME}-default ms-${MS_NAME}-queues
oc delete secrets -n ${NAMESPACE} ms-${MS_NAME}-ca ms-${MS_NAME}-server ms-${MS_NAME}-app1-client ms-${MS_NAME}-cp4iadmin-client
oc delete pvc -n ${NAMESPACE} data-${MS_NAME}-ibm-mq-0

# Delete files TODO
# rm qm3.crt qm3.key app1key.* app1.* ccdt.json 
