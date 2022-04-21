#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Login admin user using the MQ REST API

# Find the route's hostname for the MQ REST service
rest_hostname=`oc get route -n cp4i example-12-qm12-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname


# Test:

ping -c 3 $rest_hostname


# Login and save the token
idpw='{"username":"app1","password":"passw0rd"}'
curl -k -i https://$rest_hostname/ibmmq/rest/v2/login -X POST -H "Content-Type: application/json" --data "$idpw" -c app1-cookie.txt



