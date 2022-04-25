# Example: Persistent Storage

In all the previous examples, the queue manager's storage was `ephemeral`. This meant that, even if messages were persistent, they would not survive a queue manager (pod) restart, because the queue manager's storage itself did not persist. This is clearly not acceptable for a production queue manager.

This example makes the queue manager's storage persistent; it uses Persistent Volume Claims.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.ibm.com/EGarza/cp4i-mq.git

```

```
cd cp4i-mq/05-pvc

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm5.sh

```

# Setup and deploy the queue manager

You can copy/paste comamnds from this section to a terminal, or run the script [deploy-qm5-qmgr.sh](./deploy-qm5-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm5.key -subj "/CN=qm5" -x509 -days 3650 -out qm5.crt

```

## Setup TLS for the MQ client `app1`

### Create a private key and a self-signed certificate for the client application

```
openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

```

### Set up the client key database

#### Create the client key database:

```
runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

```

#### Add the queue manager public key to the client key database:

```
runmqakm -cert -add -db app1key.kdb -label qm5cert -file qm5.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm5cert

```

#### Add the client's certificate and key to the client key database:

First, put the key (`app1.key`) and certificate (`app1.crt`) into a PKCS12 file. PKCS12 is a format suitable for importing into the client key database (`app1key.kdb`):

```
openssl pkcs12 -export -out app1.p12 -inkey app1.key -in app1.crt -password pass:password

```

Next, import the PKCS12 file. The label **must be** `ibmwebspheremq<your userid>`:

```
label=ibmwebspheremq`id -u -n`
runmqakm -cert -import -target app1key.kdb -file app1.p12 -target_stashed -pw password -new_label $label

```

List the database certificates:

```
runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm5cert
-	ibmwebspheremqemir

```

## Setup TLS for the MQ client `app2`

### Create a private key and a self-signed certificate for the client application

```
openssl req -newkey rsa:2048 -nodes -keyout app2.key -subj "/CN=app2" -x509 -days 3650 -out app2.crt

```

### Set up the client key database

#### Create the client key database:

```
runmqakm -keydb -create -db app2key.kdb -pw password -type cms -stash

```

#### Add the queue manager public key to the client key database:

```
runmqakm -cert -add -db app2key.kdb -label qm5cert -file qm5.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app2key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm5cert

```

#### Add the client's certificate and key to the client key database:

First, put the key (`app2.key`) and certificate (`app2.crt`) into a PKCS12 file. PKCS12 is a format suitable for importing into the client key database (`app2key.kdb`):

```
openssl pkcs12 -export -out app2.p12 -inkey app2.key -in app2.crt -password pass:password

```

Next, import the PKCS12 file. The label **must be** `ibmwebspheremq<your userid>`:

```
label=ibmwebspheremq`id -u -n`
runmqakm -cert -import -target app2key.kdb -file app2.p12 -target_stashed -pw password -new_label $label

```

List the database certificates:

```
runmqakm -cert -list -db app2key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm5cert
-	ibmwebspheremqemir

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-05-qm5-secret -n cp4i --key="qm5.key" --cert="qm5.crt"

```

### Create TLS Secret with the client's certificate (`app1`)

```
oc create secret generic example-05-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

### Create TLS Secret with the client's certificate (`app2`)

```
oc create secret generic example-05-app2-secret -n cp4i --from-file=app2.crt=app2.crt

```

### Create a config map with initial MQSC and ini

#### Create the config map yaml file

```
cat > qm5-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-05-qm5-configmap
data:
  qm5.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM5CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM5CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(INQ,PUT)
    SET CHLAUTH('QM5CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app2') USERSRC(MAP) MCAUSER('app2') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app2') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app2') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ)
    REFRESH SECURITY
  qm5.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm5-configmap.yaml

```

#### Create the config map

```
oc apply -n cp4i -f qm5-configmap.yaml

```

### Create the required OpenShift route

```
cat > qm5chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-05-qm5-route
spec:
  host: qm5chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm5-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm5chl-route.yaml

```

```
oc apply -n cp4i -f qm5chl-route.yaml

```

Check:

```
oc describe route example-05-qm5-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm5-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm5
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM5
    ini:
      - configMap:
          name: example-05-qm5-configmap
          items:
            - qm5.ini
    mqsc:
    - configMap:
        name: example-05-qm5-configmap
        items:
        - qm5.mqsc
    availability:
      type: SingleInstance
    storage:
      defaultClass: ibmc-block-gold
      persistedData:
        enabled: false
      queueManager:
        size: 2Gi
        type: persistent-claim
      recoveryLogs:
        enabled: false
  version: 9.2.4.0-r1
  web:
    enabled: true
  pki:
    keys:
      - name: example
        secret:
          secretName: example-05-qm5-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-05-app1-secret
        items:
          - app1.crt
    - name: app2
      secret:
        secretName: example-05-app2-secret
        items:
          - app2.crt
EOF
#
cat qm5-qmgr.yaml

```
#### Notes:

* Availability
```
    availability:
      type: SingleInstance
```
This is a single-instance queue manager (alternatives are Multi-instance and Native HA).

* Storage
```
    storage:
      defaultClass: ibmc-block-gold
      persistedData:
        enabled: false
      queueManager:
        size: 2Gi
        type: persistent-claim
      recoveryLogs:
        enabled: false
```
The default class for all persistent volumes is `ibmc-block-gold`. ***It must be block storage***. When I used file storage, the queue manager failed to start (`Error 71 creating queue manager: Permission denied attempting to access an INI file.`).

Note that `ibmc-block-gold` applies to IBM Cloud only. On other clouds, use a storage class that provides block storage.

We make the queue manager's storage a persistent claim. This creates a Persistent Volume Claim (`pvc`) the first time the queue manager is deployed. When the queue manager restarts or is recreated, the `pvc` (which contains messages and object definitions such as queues) is used if it exists.

We don't create separate volumes for data and logs (`enabled: false` settings for `persistedData` and `recoveryLogs`).


#### Create the queue manager

```
oc apply -n cp4i -f qm5-qmgr.yaml

```

# Set up and run the clients

We will put, browse and get messages to test the queue manager we just deployed.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm5-client-put.sh](./run-qm5-client-put.sh) to put two test messages to the queue `Q1`.
* [run-qm5-client-browse.sh](./run-qm5-client-browse.sh) to browse the messages (read them but leave them on the queue).
* [run-qm5-client-get.sh](./run-qm5-client-get.sh) to get messages (read them and remove them from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm5

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm5-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname

```

Test (optional):
```
ping -c 3 $qmhostname

```

### Create ccdt.json

```
cat > ccdt.json << EOF
{
    "channel":
    [
        {
            "name": "QM5CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM5"
            },
            "transmissionSecurity":
            {
              "cipherSpecification": "ANY_TLS12_OR_HIGHER"
            },
            "type": "clientConnection"
        }
   ]
}
EOF
#
cat ccdt.json

```

### Set environment variables for the putting client (`app1`)

```
export MQCCDTURL=ccdt.json
export MQSSLKEYR=app1key
# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL
echo MQSSLKEYR=$MQSSLKEYR
ls -l $MQSSLKEYR.*

```

### Put messages to the queue

```
echo "Test message 1" | amqsputc Q1 QM5
echo "Test message 2" | amqsputc Q1 QM5

```
You should see:

```
Sample AMQSPUT0 start
target queue is Q1
Sample AMQSPUT0 end
Sample AMQSPUT0 start
target queue is Q1
Sample AMQSPUT0 end
```
### Set environment variables for the getting client (`app2`)

You can open a second terminal, if you prefer.

```
export MQCCDTURL=ccdt.json
export MQSSLKEYR=app2key
# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL
echo MQSSLKEYR=$MQSSLKEYR
ls -l $MQSSLKEYR.*

```

### Browse messages from the queue

```
amqsbcgc Q1 QM5

```
You should see (truncated for redability):

```
AMQSBCG0 - starts here
**********************
 
 MQOPEN - 'Q1'
 
 
 MQGET of message number 1, CompCode:0 Reason:0
****Message descriptor****

  StrucId  : 'MD  '  Version : 2
  Report   : 0  MsgType : 8
  Expiry   : -1  Feedback : 0
  Encoding : 546  CodedCharSetId : 1208
  Format : 'MQSTR   '
  Priority : 0  Persistence : 1
  ...
 
****   Message      ****
 
 length - 14 of 14 bytes
 
00000000:  5465 7374 206D 6573 7361 6765 2031            'Test message 1  '
 
 
 MQGET of message number 2, CompCode:0 Reason:0
****Message descriptor****

  ...
 
****   Message      ****
 
 length - 14 of 14 bytes
 
00000000:  5465 7374 206D 6573 7361 6765 2032            'Test message 2  '

 No more messages 
 MQCLOSE
 MQDISC
```

**Note that the messages are persistent** (`Persistence : 1`), so they will survive a queue manager restart. *Let's test that assertion:*

Find the name of the queue manager's pod:
```
qmpod=`oc get pod -n cp4i -o name | grep qm5`
echo $qmpod

```

You should see:
```
$ qmpod=`oc get pod -n cp4i -o name | grep qm5`
$ echo $qmpod
pod/qm5-ibm-mq-0
```

Delete the queue manager pod:
```
oc delete $qmpod

```

Wait until the queue manager is `Running` again:
```
oc get qmgr -n cp4i qm5

```

### Get messages from the queue

```
amqsgetc Q1 QM5

```
You should see:

```
Sample AMQSGET0 start
message <Test message 1>
message <Test message 2>
no more messages
Sample AMQSGET0 end
```

## Test: delete and recreate the queue manager

If we delete and recreate the queue manager, the recreated queue manager will pick the private volume if it exists. Persistent messages will not be lost.

We'll test this using the scripts.

Put messages on the queue:
```
./run-qm5-client-put.sh 

```

You should see:
```
...
Sample AMQSPUT0 start
target queue is Q1
Sample AMQSPUT0 end
Sample AMQSPUT0 start
target queue is Q1
Sample AMQSPUT0 end
```

Delete the queue manager:
```
oc delete qmgr qm5 -n cp4i

```

Wait until there is no queue manager pod running. The next command should return nothing:
```
oc get pod -n cp4i | grep qm5

```

Recreate the queue manager:
```
oc apply -n cp4i -f qm5-qmgr.yaml

```

Wait until the queue manager is `Running`:
```
oc get qmgr -n cp4i qm5

```

Get the messages:
```
./run-qm5-client-get.sh 

```

You should see:
```
...
Sample AMQSGET0 start
message <Test message 1>
message <Test message 2>
no more messages
Sample AMQSGET0 end

```

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example: 

```
./cleanup-qm5.sh

```
## Next steps

In this example, the messages are protected (they survive a queue manager restart), *but the MQ service is not*. If the queue manager fails, the MQ service will be unavailable to clients.
The next example shows a queue manager configured with High Availability ("Native HA"). See [06-native-ha](../06-native-ha).
