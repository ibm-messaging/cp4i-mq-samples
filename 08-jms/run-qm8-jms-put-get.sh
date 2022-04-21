#!/bin/bash
#
#  (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Not for Production use. For demo and training only.
#

# Find the queue manager host name
export qmhostname=`oc get route -n cp4i qm8-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname

# Test:
ping -c 3 $qmhostname

# Run the JMS Put/Get sample program
java -Djavax.net.ssl.keyStoreType=jks -Djavax.net.ssl.keyStore=app1key.jks -Djavax.net.ssl.keyStorePassword=password -Djavax.net.ssl.trustStoreType=jks -Djavax.net.ssl.trustStore=trust.jks -Djavax.net.ssl.trustStorePassword=password -Dcom.ibm.mq.cfg.useIBMCipherMappings=false -cp ./lib/com.ibm.mq.allclient-9.2.4.0.jar:./lib/javax.jms-api-2.0.1.jar:./lib/json-20211205.jar:. com.ibm.mq.samples.jms.JmsPutGet


