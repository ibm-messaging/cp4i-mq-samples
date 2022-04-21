#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Browse message using the MQ REST API

# Find the route's hostname for the MQ REST service
rest_hostname=`oc get route -n cp4i example-09-qm9-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname

# Test:

ping -c 3 $rest_hostname


# Browse message (if one exists)

echo Browsing Q1
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo
