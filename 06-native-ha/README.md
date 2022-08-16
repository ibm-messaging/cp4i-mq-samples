# Example: Native HA

The previous example implemented persistent storage for the queue manager. This ensures persistent messages are not lost.

This example implements Native HA: three instances of the queue manager keep a synchronised replica of the data so that, if one fails, the MQ service is not interrupted.

For a very good description of MQ Native HA, see this [IBM MQ Community blog post](https://community.ibm.com/community/user/integration/blogs/david-ware1/2021/03/23/native-ha-cloud-native-high-availability) by Dave Ware.


## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/06-native-ha

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm6.sh

```

# Setup and deploy the queue manager

You can copy/paste comamnds from this section to a terminal, or run the script [deploy-qm6-qmgr.sh](./deploy-qm6-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm6.key -subj "/CN=qm6" -x509 -days 3650 -out qm6.crt

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
runmqakm -cert -add -db app1key.kdb -label qm6cert -file qm6.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm6cert

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
!	qm6cert
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
runmqakm -cert -add -db app2key.kdb -label qm6cert -file qm6.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app2key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm6cert

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
!	qm6cert
-	ibmwebspheremqemir

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-06-qm6-secret -n cp4i --key="qm6.key" --cert="qm6.crt"

```

### Create TLS Secret with the client's certificate (`app1`)

```
oc create secret generic example-06-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

### Create TLS Secret with the client's certificate (`app2`)

```
oc create secret generic example-06-app2-secret -n cp4i --from-file=app2.crt=app2.crt

```

### Deploy the queue manager

### Create a config map containing MQSC commands

#### Create the config map yaml file

```
cat > qm6-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-06-qm6-configmap
data:
  qm6.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM6CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM6CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(INQ,PUT)
    SET CHLAUTH('QM6CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app2') USERSRC(MAP) MCAUSER('app2') ACTION(REPLACE)
    SET AUTHREC PRINCIPAL('app2') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app2') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ)
    REFRESH SECURITY
  qm6.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm6-configmap.yaml

```

#### Create the config map

```
oc apply -n cp4i -f qm6-configmap.yaml

```

### Create the required route for SNI

```
cat > qm6chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-06-qm6-route
spec:
  host: qm6chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm6-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm6chl-route.yaml

```

```
oc apply -n cp4i -f qm6chl-route.yaml

```

Check:

```
oc describe route example-06-qm6-route

```

(Ignore `error: endpoints "qm6-ibm-mq" not found`. The endpoint will be created when the queue manager is deployed.)

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm6-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm6
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM6
    ini:
      - configMap:
          name: example-06-qm6-configmap
          items:
            - qm6.ini
    mqsc:
    - configMap:
        name: example-06-qm6-configmap
        items:
        - qm6.mqsc
    availability:
      type: NativeHA
    storage:
      defaultClass: ibmc-block-gold
      persistedData:
        enabled: false
      queueManager:
        size: 2Gi
        type: persistent-claim
      recoveryLogs:
        enabled: false
  version: 9.3.0.0-r1
  web:
    enabled: false
  pki:
    keys:
      - name: example
        secret:
          secretName: example-06-qm6-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-06-app1-secret
        items:
          - app1.crt
    - name: app2
      secret:
        secretName: example-06-app2-secret
        items:
          - app2.crt
EOF
#
cat qm6-qmgr.yaml

```
#### Notes:

* Availability
```
    availability:
      type: NativeHA
```
This is a Native HA queue manager.

* Storage
```
    storage:
      defaultClass: ibmc-block-gold
```

Note that `ibmc-block-gold` applies to IBM Cloud only. On other clouds, use a storage class that provides block storage.

#### Create the queue manager

```
oc apply -n cp4i -f qm6-qmgr.yaml

```

# Set up and run the clients

We will put and get messages to test the queue manager we just deployed. We will also delete the active queue manager pod to verify that another queue manager instance takes over and the clients reconnect to it.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [ha-qm6-put.sh](./ha-qm6-put.sh) to put two test messages to the queue `Q1`.
* [ha-qm6-get.sh](./ha-qm6-get.sh) to get messages from `Q1`.

Run the scripts in separate terminal sessions.

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm6

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm6-ibm-mq-qm -o jsonpath="{.spec.host}"`
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
            "name": "QM6CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM6"
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

This time we'll test with the `amqsphac` (MQ HA Put) sample client. This program puts messages at 2-second intervals. If the queue manager it is connected to fails, the program reconnects automatically to the queue manager instance that becomes active.

```
amqsphac Q1 QM6

```
You should see:

```
Sample AMQSPHAC start
target queue is Q1
message <Message 1>
message <Message 2>
message <Message 3>
message <Message 4>
...
```

At the end of this test, the [cleanup script](./cleanup-qm6.sh) will end the program. If you want to end the program before, press CTRL+C (but not yet, we need it to test reconnection after a failure.)

### Set environment variables for the getting client (`app2`)

**Open another terminal to get messages while the putting program is running.**

Remember to `cd` to this repository's directory (`06-native-ha`).

```
export MQCCDTURL=ccdt.json
export MQSSLKEYR=app2key
# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL
echo MQSSLKEYR=$MQSSLKEYR
ls -l $MQSSLKEYR.*

```

### Get messages from the queue

We'll use the `amqsghac` (MQ HA Get) sample client. This program gets messages from the queue. If the queue manager it is connected to fails, the program reconnects automatically to the queue manager instance that becomes active.

```
amqsghac Q1 QM6

```
You should see:

```
Sample AMQSGHAC start
message <Message 1>
message <Message 2>
message <Message 3>
message <Message 4>
...
```

At the end of this test, the [cleanup script](./cleanup-qm6.sh) will end the program. If you want to end the program before, press CTRL+C (but not yet, we need it to test reconnection after a failure.)

## Test a queue manager failure

**Open a third terminal.** At this point, you have a terminal running a putting client and another running a getting client.

As we deployed a Native HA queue manager, there are three queue manager instances running (that is, three pods):
```
oc get pod -n cp4i

```
You should see:
```
NAME                      READY   STATUS      RESTARTS   AGE
...
qm6-ibm-mq-0              1/1     Running     0          5m16s
qm6-ibm-mq-1              0/1     Running     0          4m43s
qm6-ibm-mq-2              0/1     Running     0          5m8s
...
```

The pod showing `1/1` is the active instance. The others, with `0/1`, are replicas.

Another way to identify the active instance is with the `dspmq` command:
```
oc exec qm6-ibm-mq-0 -- dspmq -o nativeha -x

```
You should see (abridged for readability; active queue manager could be different):
```
QMNAME(QM6)             ROLE(Active) INSTANCE(qm6-ibm-mq-0) INSYNC(yes) QUORUM(3/3)
 INSTANCE(qm6-ibm-mq-0) ROLE(Active) ...
 INSTANCE(qm6-ibm-mq-2) ROLE(Replica) ...
 INSTANCE(qm6-ibm-mq-1) ROLE(Replica) ...
```

Our get and put clients are connected to the active instance. We can check by running `runmqsc` on the active instance and displaying the channel status:

```
echo "dis chstatus(*)" | oc exec -i qm6-ibm-mq-0 -- runmqsc

```

You will see the two connections:
```
5724-H72 (C) Copyright IBM Corp. 1994, 2021.
Starting MQSC for queue manager QM6.


     1 : dis chstatus(*)
AMQ8417I: Display Channel Status details.
   CHANNEL(QM6CHL)                         CHLTYPE(SVRCONN)
   CONNAME(172.30.93.252)                  CURRENT
   STATUS(RUNNING)                         SUBSTATE(RECEIVE)
AMQ8417I: Display Channel Status details.
   CHANNEL(QM6CHL)                         CHLTYPE(SVRCONN)
   CONNAME(172.30.93.252)                  CURRENT
   STATUS(RUNNING)                         SUBSTATE(RECEIVE)
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.
```

We will test what happens if the active instance fails. Delete the active instance pod:
```
oc delete pod qm6-ibm-mq-0

```

The terminals with the running clients will show:
```
message <Message 391>
09:59:13 : EVENT : Connection Reconnecting (Reason: 2161, Delay: 102ms)
09:59:13 : EVENT : Connection Reconnecting (Reason: 2161, Delay: 831ms)
09:59:14 : EVENT : Connection Reconnecting (Reason: 2161, Delay: 2262ms)
09:59:17 : EVENT : Connection Reconnecting (Reason: 2161, Delay: 3984ms)
09:59:21 : EVENT : Connection Reconnected
message <Message 392>
```

The applications reconnected, in this case, within 8 seconds.

If we check the pods, we'll see that there is a new active instance:
```
oc get pod -n cp4i | grep qm6
```

```
qm6-ibm-mq-0            0/1     Running
qm6-ibm-mq-1            1/1     Running
qm6-ibm-mq-2            0/1     Running
```

## Cleanup

This script stops the client applications and deletes the queue manager, the persistent volumes, other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm6.sh

```
