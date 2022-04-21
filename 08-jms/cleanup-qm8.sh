#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm8
rm qm8-qmgr.yaml

# delete config map
oc delete -n cp4i cm example-08-qm8-configmap
rm qm8-configmap.yaml

# delete route
oc delete -n cp4i route example-08-qm8-route
rm qm8chl-route.yaml

# delete secrets
oc delete -n cp4i secret example-08-qm8-secret
oc delete -n cp4i secret example-08-app1-secret

# delete files
rm app1.crt app1.key app1.p12 app1key.jks qm8.crt qm8.key trust.jks
