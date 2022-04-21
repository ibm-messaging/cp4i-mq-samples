#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete amqsphac/amqsghac clients
kill $(ps -e | grep -v grep | grep amqsphac | awk '{print $1}')
kill $(ps -e | grep -v grep | grep amqsghac | awk '{print $1}')

# delete queue manager
oc delete -n cp4i qmgr qm6
rm qm6-qmgr.yaml

# delete persistent volume claims
oc delete -n cp4i pvc data-qm6-ibm-mq-0 data-qm6-ibm-mq-1 data-qm6-ibm-mq-2

# delete config map
oc delete -n cp4i cm example-06-qm6-configmap
rm qm6-configmap.yaml

# delete route
oc delete -n cp4i route example-06-qm6-route
rm qm6chl-route.yaml

# delete secrets
oc delete -n cp4i secret example-06-qm6-secret
oc delete -n cp4i secret example-06-app1-secret
oc delete -n cp4i secret example-06-app2-secret

# delete files
rm qm6.crt qm6.key app1key.* app1.* app2key.* app2.* ccdt.json 
