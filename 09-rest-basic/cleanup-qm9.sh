#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm9
rm qm9-qmgr.yaml

# delete config maps
oc delete -n cp4i cm example-09-qm9-configmap example-09-qm9-web-configmap
rm qm9-configmap.yaml qm9-web-configmap.yaml

# delete service and routes
oc delete -n cp4i svc example-09-qm9-rest-svc
oc delete -n cp4i route example-09-qm9-rest-route
rm qm9-svc-route.yaml
