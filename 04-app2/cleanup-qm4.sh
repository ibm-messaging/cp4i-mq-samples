#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm4
rm qm4-qmgr.yaml

# delete config map
oc delete -n cp4i cm  example-04-qm4-configmap
rm qm4-configmap.yaml

# delete route
oc delete -n cp4i route example-04-qm4-route
rm qm4chl-route.yaml

# delete secrets
oc delete -n cp4i secret example-04-qm4-secret
oc delete -n cp4i secret example-04-app1-secret
oc delete -n cp4i secret example-04-app2-secret

# delete files
rm qm4.crt qm4.key app1key.* app1.* app2key.* app2.* ccdt.json 
