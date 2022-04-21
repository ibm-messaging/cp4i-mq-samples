#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm11
rm qm11-qmgr.yaml

# delete config maps
oc delete -n cp4i cm example-11-qm11-configmap example-11-qm11-web-configmap example-11-app1-jks-configmap
rm qm11-configmap.yaml qm11-web-configmap.yaml

# delete services and routes
oc delete -n cp4i svc example-11-qm11-rest-svc
oc delete -n cp4i route example-11-qm11-rest-route
rm qm11-svc-route.yaml

# delete files
rm app1.* trust.jks
