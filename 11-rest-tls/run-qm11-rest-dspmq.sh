#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Display queue manager using the MQ REST API

# Find the route's hostname for the MQ REST service
rest_hostname=`oc get route -n cp4i example-11-qm11-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname


# Test:

ping -c 3 $rest_hostname


# Display queue manager

curl -k https://$rest_hostname/ibmmq/rest/v2/admin/qmgr -u mqadmin:passw0rd ; echo
