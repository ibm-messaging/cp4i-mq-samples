#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Open MQ Web Console

# Find the route's hostname for the MQ REST service (also the Web Server)
rest_hostname=`oc get route -n cp4i example-12-qm12-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname


# Test:

ping -c 3 $rest_hostname


# Open the MQ Console with the default Browser

open https://$rest_hostname/ibmmq/console
