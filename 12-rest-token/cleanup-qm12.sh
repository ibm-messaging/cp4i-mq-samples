#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# delete queue manager
oc delete -n cp4i qmgr qm12
rm qm12-qmgr.yaml

# delete config maps
oc delete -n cp4i cm example-12-qm12-configmap example-12-qm12-web-configmap
rm qm12-configmap.yaml qm12-web-configmap.yaml

# delete service and routes
oc delete -n cp4i svc example-12-qm12-rest-svc
oc delete -n cp4i route example-12-qm12-rest-route
rm qm12-svc-route.yaml

# delete files
rm mqadmin-cookie.txt app1-cookie.txt
