#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm3
rm qm3-qmgr.yaml

# delete config map
oc delete -n cp4i cm example-03-qm3-configmap
rm qm3-configmap.yaml

# delete route
oc delete -n cp4i route example-03-qm3-route
rm qm3chl-route.yaml

# delete secrets
oc delete -n cp4i secret example-03-qm3-secret
oc delete -n cp4i secret example-03-app1-secret

# delete files
rm qm3.crt qm3.key app1key.* app1.* ccdt.json 
