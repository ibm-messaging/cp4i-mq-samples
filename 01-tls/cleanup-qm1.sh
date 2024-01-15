#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#
# delete queue manager
oc delete -n cp4i qmgr qm1
rm qm1-qmgr.yaml

# delete config map
oc delete -n cp4i cm example-01-qm1-configmap
rm qm1-configmap.yaml

# delete route
oc delete -n cp4i route example-01-qm1-route
rm qm1chl-route.yaml

# delete secret
oc delete -n cp4i secret example-01-qm1-secret

# delete files
rm qm1.crt qm1.key app1key.* ccdt.json app.pem
