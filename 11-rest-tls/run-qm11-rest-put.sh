#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Put messages using the MQ REST API

# Find the route's hostname for the MQ REST service
rest_hostname=`oc get route -n cp4i example-11-qm11-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname


# Test:

ping -c 3 $rest_hostname


# Put messages to queue

echo Putting test message 1 to Q1
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 1 - put using MQ REST API'

echo Putting test message 2 to Q1
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 2 - put using MQ REST API'


