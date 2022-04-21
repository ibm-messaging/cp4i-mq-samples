#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm10
rm qm10-qmgr.yaml

# delete config maps
oc delete -n cp4i cm example-10-qm10-configmap example-10-qm10-web-configmap
rm qm10-configmap.yaml qm10-web-configmap.yaml

# delete service and routes
oc delete -n cp4i svc example-10-qm10-rest-svc
oc delete -n cp4i route example-10-qm10-rest-route
rm qm10-svc-route.yaml
