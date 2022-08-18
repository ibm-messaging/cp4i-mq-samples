# Example: Adding a second user

This example adds a second user, so we have `app1` and `app2`:
* `app1` is authorised to put to the `Q1` queue, but not to get.
* `app2` is authorised to get from the queue, but not to put.


## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/04-app2

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm4.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm4-qmgr.sh](./deploy-qm4-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm4.key -subj "/CN=qm4" -x509 -days 3650 -out qm4.crt

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
runmqakm -cert -add -db app1key.kdb -label qm4cert -file qm4.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm4cert

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
!	qm4cert
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
runmqakm -cert -add -db app2key.kdb -label qm4cert -file qm4.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app2key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm4cert

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
!	qm4cert
-	ibmwebspheremqemir

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-04-qm4-secret -n cp4i --key="qm4.key" --cert="qm4.crt"

```

### Create TLS Secret with the client's certificate (`app1`)

```
oc create secret generic example-04-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

### Create TLS Secret with the client's certificate (`app2`)

```
oc create secret generic example-04-app2-secret -n cp4i --from-file=app2.crt=app2.crt

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands

#### Create the config map yaml file

```
cat > qm4-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-04-qm4-configmap
data:
  qm4.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM4CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM4CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(INQ,PUT)
    SET CHLAUTH('QM4CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app2') USERSRC(MAP) MCAUSER('app2') ACTION(ADD)
    SET AUTHREC PRINCIPAL('app2') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app2') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ)
  qm4.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm4-configmap.yaml

```

#### Notes:

* User mapping
```
SET CHLAUTH('QM4CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1')
SET CHLAUTH('QM4CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app2') USERSRC(MAP) MCAUSER('app2')
```
If the client presents a certificate with `CN=app1`, the program will run under userid `app1`. If the client presents a certificate with `CN=app2`, the program will run under userid `app2`.

* Permission to connect
```
SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
SET AUTHREC PRINCIPAL('app2') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
```
Users `app1` and `app2` are allowed to connect to the queue manager (and also to query queue manager attributes).

* Permission to put/get
```
SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(INQ,PUT)
SET AUTHREC PROFILE('Q1') PRINCIPAL('app2') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ)
```
User `app1` is allowed to put to `Q1` (also to query queue attributes).
User `app2` is allowed to get from `Q1` (also to browse messages and query queue attributes).

#### Create the config map

```
oc apply -n cp4i -f qm4-configmap.yaml

```

### Create the required route for SNI

```
cat > qm4chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-04-qm4-route
spec:
  host: qm4chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm4-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm4chl-route.yaml

```

```
oc apply -n cp4i -f qm4chl-route.yaml

```

Check:

```
oc describe route example-04-qm4-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm4-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm4
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM4
    ini:
      - configMap:
          name: example-04-qm4-configmap
          items:
            - qm4.ini
    mqsc:
    - configMap:
        name: example-04-qm4-configmap
        items:
        - qm4.mqsc
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
          secretName: example-04-qm4-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-04-app1-secret
        items:
          - app1.crt
    - name: app2
      secret:
        secretName: example-04-app2-secret
        items:
          - app2.crt
EOF
#
cat qm4-qmgr.yaml

```
#### Notes:

* `app2` certificate
```
    - name: app2
      secret:
        secretName: example-04-app2-secret
        items:
          - app2.crt
```
We added the certificate for `app2` to the `trust` section. Same as for `app1`, it points to the secret created earlier. This enables the queue manager to validate the certificate presented by `app2`.

#### Create the queue manager

```
oc apply -n cp4i -f qm4-qmgr.yaml

```

# Set up and run the clients

We will put, browse and get messages to test the queue manager we just deployed.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm4-client-put.sh](./run-qm4-client-put.sh) to put two test messages to the queue `Q1`.
* [run-qm4-client-browse.sh](./run-qm4-client-browse.sh) to browse the messages (read them but leave them on the queue).
* [run-qm4-client-get.sh](./run-qm4-client-get.sh) to get messages (read them and remove them from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm4

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm4-ibm-mq-qm -o jsonpath="{.spec.host}"`
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
            "name": "QM4CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM4"
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
echo "Test message 1" | amqsputc Q1 QM4
echo "Test message 2" | amqsputc Q1 QM4

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
### Try to get messages from the queue (this will fail)

With `MQSSLKEYR` pointing to `app1key`, the program runs as userid `app1`, which is not allowed to get messages from the queue.

```
amqsgetc Q1 QM4

```
You should see:

```
Sample AMQSGET0 start
MQOPEN ended with reason code 2035
unable to open queue for input
Sample AMQSGET0 end
```
If we check the reason code:
```
mqrc 2035

      2035  0x000007f3  MQRC_NOT_AUTHORIZED
```

We can get more details from the log:
```
oc logs qm4-ibm-mq-0 --tail=5
```
You should see:
```
...
2021-08-04T14:24:29.610Z AMQ8077W: Entity 'app1' has insufficient authority to access object Q1 [queue]. [CommentInsert1(app1), CommentInsert2(Q1 [queue]), CommentInsert3(get)]
```

Also, from `AMQERR01.LOG`:
```
oc exec qm4-ibm-mq-0 -- tail /var/mqm/qmgrs/QM4/errors/AMQERR01.LOG
```
You should see:
```
AMQ8077W: Entity 'app1' has insufficient authority to access object Q1 [queue].

EXPLANATION:
The specified entity is not authorized to access the required object. The
following requested permissions are unauthorized: get
ACTION:
Ensure that the correct level of authority has been set for this entity against
the required object, or ensure that the entity is a member of a privileged
group.
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

### Get messages from the queue

```
amqsgetc Q1 QM4

```
You should see:

```
Sample AMQSGET0 start
message <Test message 1>
message <Test message 2>
no more messages
Sample AMQSGET0 end
```
### Try to put messages to the queue (this will fail)

With `MQSSLKEYR` pointing to `app2key`, the program runs as userid `app2`, which is not allowed to put messages to the queue.

```
echo "Test message 1" | amqsputc Q1 QM4

```
You should see:

```
Sample AMQSPUT0 start
target queue is Q1
MQOPEN ended with reason code 2035
unable to open queue for output
Sample AMQSPUT0 end
```

We can get more details from the log:
```
oc logs qm4-ibm-mq-0 --tail=5
```
You should see:
```
...
2021-08-04T14:37:00.713Z AMQ8077W: Entity 'app2' has insufficient authority to access object Q1 [queue]. [CommentInsert1(app2), CommentInsert2(Q1 [queue]), CommentInsert3(put)]
```

Also, from `AMQERR01.LOG`:
```
oc exec qm4-ibm-mq-0 -- tail /var/mqm/qmgrs/QM4/errors/AMQERR01.LOG

```

You should see:
```
AMQ8077W: Entity 'app2' has insufficient authority to access object Q1 [queue].

EXPLANATION:
The specified entity is not authorized to access the required object. The
following requested permissions are unauthorized: put
ACTION:
Ensure that the correct level of authority has been set for this entity against
the required object, or ensure that the entity is a member of a privileged
group.
```

## (Optional) Try this:

1. `run-qm4-client-put.sh`. This will put two messages on `Q1`.

1. `run-qm4-client-browse.sh`. This will show that the messages are **persistent** (`Persistence : 1`): they should survive a queue manager restart.

1. `oc delete pod qm4-ibm-mq-0`. This will delete the queue manager pod. After about 30 seconds, a new pod will be running.

1. `oc get qmgr -n cp4i qm4`. Wait until the queue manager is `Running`.

1. `run-qm4-client-browse.sh`. This will show that *the queue is empty*: the supposedly persistent messages did not survive the queue manager restart!

This is because the queue manager runs with *ephemeral storage*. In the next example, we'll use persistent storage. 

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example: 

```
./cleanup-qm4.sh

```

## Next steps

As mentioned above, we'll use persistent storage in the next example. See [05-pvc](../05-pvc).
