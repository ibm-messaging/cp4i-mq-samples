#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm5
rm qm5-qmgr.yaml

# delete persistent volume claim
oc delete -n cp4i pvc data-qm5-ibm-mq-0

# delete config map
oc delete -n cp4i cm example-05-qm5-configmap
rm qm5-configmap.yaml

# delete route
oc delete -n cp4i route example-05-qm5-route
rm qm5chl-route.yaml

# delete secrets
oc delete -n cp4i secret example-05-qm5-secret
oc delete -n cp4i secret example-05-app1-secret
oc delete -n cp4i secret example-05-app2-secret

# delete files
rm qm5.crt qm5.key app1key.* app1.* app2key.* app2.* ccdt.json 
