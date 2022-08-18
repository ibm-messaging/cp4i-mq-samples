# Example: JMS application

This example shows how to connect from a JMS application. It is based on the [03-auth](../03-auth) example: the connection requires mutual TLS and user permissions are checked.

## Contents

Unlike the other examples in this repository, the sample programs and required jars are provided here.

### Sample programs

The MQ JMS Sample programs are in the [com/ibm/mq/samples/jms](./com/ibm/mq/samples/jms) folder. They have been downloaded from the [`mq-dev-samples` GitHub repository](https://github.com/ibm-messaging/mq-dev-samples/tree/master/gettingStarted/jms/com/ibm/mq/samples/jms). The sample programs are:

* `JMSPut.java`, to put a message to a queue.

* `JMSGet.java`, to get a message from a queue.

* `JMSPutGet.java`, to put a message to a queue, and then get it.

They have been tailored to this environment. Changes are tagged `@cp4i-mq`.

### Required jars

The prerequisite jars are in the [lib](./lib) folder. They are:

* `com.ibm.mq.allclient-9.2.4.0.jar`: the MQ CLient code for Java. It is the latest version at the time of writing. Use this link to download a newer version, if one is available: https://search.maven.org/search?q=a:com.ibm.mq.allclient (Group ID: `com.ibm.mq`, Artifact ID: `com.ibm.mq.allclient`).

* `javax.jms-api-2.0.1.jar`: the JMS API. Downloaded using this link: https://search.maven.org/search?q=a:javax.jms-api (Group ID: `javax.jms`, Artifact ID: `javax.jms-api`).

* `json-20211205.jar`: required for parsing JSON structures. Downloaded using this link: https://search.maven.org/search?q=g:org.json (Group ID: `json.org`, Artifact ID: `json`).

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/08-jms

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm8.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm8-qmgr.sh](./deploy-qm8-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm8.key -subj "/CN=qm8" -x509 -days 3650 -out qm8.crt

```

## Setup TLS for the MQ client application

### Create a private key and a self-signed certificate for the client application

```
openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

```

### Create the client JKS key store:

First, put the key (`app1.key`) and certificate (`app1.crt`) into a PKCS12 file. PKCS12 is a format suitable for importing into the client's JKS key store (`app1key.jks`), which we'll create next:

```
openssl pkcs12 -export -out app1.p12 -inkey app1.key -in app1.crt -password pass:password -name app1cert

```

Create the JKS key store and import certificate and key (ignore the warning about JKS proprietary format):

```
keytool -importkeystore \
        -deststorepass password -destkeypass password -destkeystore app1key.jks -deststoretype jks -alias app1cert -destalias app1cert \
        -srckeystore app1.p12 -srcstoretype PKCS12 -srcstorepass password

```

List the certificate
```
keytool -list -keystore app1key.jks -storepass password

```

Expected output:

```
Keystore type: JKS
Keystore provider: SUN

Your keystore contains 1 entry

app1cert, 16 Dec 2021, PrivateKeyEntry, 
Certificate fingerprint (SHA-256): 50:46:B3:1E:F9:07:A2:36:E8:E1...

```

(Ignore the warning about JKS proprietary format.)

### Create the client's JKS trust store

This also adds the queue manager certificate to the client's JKS trust store:

```
keytool -keystore trust.jks -storetype jks -importcert -file qm8.crt -alias qm8cert -storepass password -noprompt

```

List the certificate
```
keytool -list -keystore trust.jks -storepass password -alias qm8cert

```

Expected output:

```
qm8cert, 16 Dec 2021, trustedCertEntry, 
Certificate fingerprint (SHA-256): 83:E9:96:A2:9A:0C:25:63:B3:8E...

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-08-qm8-secret -n cp4i --key="qm8.key" --cert="qm8.crt"

```

### Create TLS Secret with the client's certificate

```
oc create secret generic example-08-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm8-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-08-qm8-configmap
data:
  qm8.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM8CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM8CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm8.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm8-configmap.yaml

```

#### Note:

For details about these settings, see the [03-auth](../03-auth) example.

#### Create the config map

```
oc apply -n cp4i -f qm8-configmap.yaml

```

### Create the required route for SNI

```
cat > qm8chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-08-qm8-route
spec:
  host: qm8chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm8-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm8chl-route.yaml

```

```
oc apply -n cp4i -f qm8chl-route.yaml

```

Check (ignore the `endpoints "qm8-ibm-mq" not found` error; it will go away after creating the queue manager):

```
oc describe route example-08-qm8-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm8-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm8
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM8
    ini:
      - configMap:
          name: example-08-qm8-configmap
          items:
            - qm8.ini
    mqsc:
    - configMap:
        name: example-08-qm8-configmap
        items:
        - qm8.mqsc
    storage:
      queueManager:
        type: ephemeral
  version: 9.3.0.0-r2
  web:
    enabled: false
  pki:
    keys:
      - name: example
        secret:
          secretName: example-08-qm8-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-08-app1-secret
        items:
          - app1.crt
EOF
#
cat qm8-qmgr.yaml

```

#### Create the queue manager

```
oc apply -n cp4i -f qm8-qmgr.yaml

```

# Set up and run the clients

We will run three JMS sample programs:
* Put a message to the `Q1` queue and then get it (this is the `JMSPutGet` sample).
* Put a message to the `Q1` queue (this is the `JMSPut` sample).
* Get a message frm the `Q1` queue (this is the `JMSGet` sample).

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm8-jms-put-get.sh](./run-qm8-jms-put-get.sh) to run `JMSPutGet` sample.
* [run-qm8-jms-put.sh](./run-qm8-jms-put.sh) to run `JMSPut` sample.
* [run-qm8-jms-get.sh](./run-qm8-jms-get.sh) to run `JMSGet` sample.

***Note:*** The sample programs have been compiled with a Java 12 compiler. If your Java runtime version is different, you may get this error:

```
Exception in thread "main" java.lang.UnsupportedClassVersionError: com/ibm/mq/samples/jms/JmsPutGet 
has been compiled by a more recent version of the Java Runtime (class file version 56.0), 
this version of the Java Runtime only recognizes class file versions up to 52.0
```

The solution is to re-compile the programs:

```
javac -cp lib/com.ibm.mq.allclient-9.2.4.0.jar:lib/javax.jms-api-2.0.1.jar com/ibm/mq/samples/jms/JmsPut.java
javac -cp lib/com.ibm.mq.allclient-9.2.4.0.jar:lib/javax.jms-api-2.0.1.jar com/ibm/mq/samples/jms/JmsGet.java
javac -cp lib/com.ibm.mq.allclient-9.2.4.0.jar:lib/javax.jms-api-2.0.1.jar com/ibm/mq/samples/jms/JmsPutGet.java

```
## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm8

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm8-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname

```

Test (optional):
```
ping -c 3 $qmhostname

```

### Test 1: Put then get a message

Run the JMS Put+Get Sample:

```
java -Djavax.net.ssl.keyStoreType=jks -Djavax.net.ssl.keyStore=app1key.jks -Djavax.net.ssl.keyStorePassword=password \
     -Djavax.net.ssl.trustStoreType=jks -Djavax.net.ssl.trustStore=trust.jks -Djavax.net.ssl.trustStorePassword=password \
     -Dcom.ibm.mq.cfg.useIBMCipherMappings=false \
     -cp ./lib/com.ibm.mq.allclient-9.2.4.0.jar:./lib/javax.jms-api-2.0.1.jar:./lib/json-20211205.jar:. \
     com.ibm.mq.samples.jms.JmsPutGet


```
You should see (the "lucky number" will vary):

```
Sent message:

  JMSMessage class: jms_text
  JMSType:          null
  JMSDeliveryMode:  2
  JMSDeliveryDelay: 0
  JMSDeliveryTime:  1642690052536
  JMSExpiration:    0
  JMSPriority:      4
  JMSMessageID:     ID:414d5120514d382020202020202020207373e96101470040
  JMSTimestamp:     1642690052536
  JMSCorrelationID: null
  JMSDestination:   queue:///Q1
  JMSReplyTo:       null
  JMSRedelivered:   false
    JMSXAppID: JmsPutGet (JMS)             
    JMSXDeliveryCount: 0
    JMSXUserID: app1        
    JMS_IBM_PutApplType: 28
    JMS_IBM_PutDate: 20220120
    JMS_IBM_PutTime: 14473284
Your lucky number today is 514

Received message:
Your lucky number today is 514
SUCCESS
```

### Test 2: Put a message to the queue

Run the JMS Put sample:

```
java -Djavax.net.ssl.keyStoreType=jks -Djavax.net.ssl.keyStore=app1key.jks -Djavax.net.ssl.keyStorePassword=password \
     -Djavax.net.ssl.trustStoreType=jks -Djavax.net.ssl.trustStore=trust.jks -Djavax.net.ssl.trustStorePassword=password \
     -Dcom.ibm.mq.cfg.useIBMCipherMappings=false \
     -cp ./lib/com.ibm.mq.allclient-9.2.4.0.jar:./lib/javax.jms-api-2.0.1.jar:./lib/json-20211205.jar:. \
     com.ibm.mq.samples.jms.JmsPut

```
You should see:

```
Sent message:

  JMSMessage class: jms_text
  JMSType:          null
  JMSDeliveryMode:  2
  JMSDeliveryDelay: 0
  JMSDeliveryTime:  1642690348524
  JMSExpiration:    0
  JMSPriority:      4
  JMSMessageID:     ID:414d5120514d382020202020202020207373e96101530040
  JMSTimestamp:     1642690348524
  JMSCorrelationID: null
  JMSDestination:   queue:///Q1
  JMSReplyTo:       null
  JMSRedelivered:   false
    JMSXAppID: JmsPutGet (JMS)             
    JMSXDeliveryCount: 0
    JMSXUserID: app1        
    JMS_IBM_PutApplType: 28
    JMS_IBM_PutDate: 20220120
    JMS_IBM_PutTime: 14522881
Your lucky number today is 496
SUCCESS
```

### Test 3: Get a message from the queue

Run the JMS Get sample:

```
java -Djavax.net.ssl.keyStoreType=jks -Djavax.net.ssl.keyStore=app1key.jks -Djavax.net.ssl.keyStorePassword=password \
     -Djavax.net.ssl.trustStoreType=jks -Djavax.net.ssl.trustStore=trust.jks -Djavax.net.ssl.trustStorePassword=password \
     -Dcom.ibm.mq.cfg.useIBMCipherMappings=false \
     -cp ./lib/com.ibm.mq.allclient-9.2.4.0.jar:./lib/javax.jms-api-2.0.1.jar:./lib/json-20211205.jar:. \
     com.ibm.mq.samples.jms.JmsGet

```
You should see:

```
Received message:
Your lucky number today is 496
SUCCESS
```

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm8.sh

```

This is the end of the JMS example.
