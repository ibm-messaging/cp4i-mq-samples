# Example: Adding user authentication

This example deploys a queue manager that requires client authentication.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/03-auth

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm3.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm3-qmgr.sh](./deploy-qm3-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm3.key -subj "/CN=qm3" -x509 -days 3650 -out qm3.crt

```

## Setup TLS for the MQ client application

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
runmqakm -cert -add -db app1key.kdb -label qm3cert -file qm3.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm3cert

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
!	qm3cert
-	ibmwebspheremqemir

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-03-qm3-secret -n cp4i --key="qm3.key" --cert="qm3.crt"

```

### Create TLS Secret with the client's certificate

```
oc create secret generic example-03-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm3-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-03-qm3-configmap
data:
  qm3.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM3CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM3CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1') ACTION(ADD)
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm3.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm3-configmap.yaml

```

#### Notes:

* AUTHINFO 
```
AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) TYPE(IDPWOS)
```
This is used by the queue manager (queue manager's `CONNAUTH` parameter) and means that client identities will be checked using userids and passwords defined to the operating system.

* CHCKCLNT
```
CHCKCLNT(OPTIONAL)
```
Clients do not provide userid and password (the userid is mapped by the CHLAUTH record from the TLS certificate).

* User mapping
```
SET CHLAUTH('QM3CHL') TYPE(SSLPEERMAP) SSLPEER('CN=app1') USERSRC(MAP) MCAUSER('app1')
```
This means that, if the client presents a certificate with `CN=app1`, the program will run under userid `app1`. Recall our client's certificate does specify `CN=app1`.

* Permission to connect
```
SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
```
User `app1` is allowed to connect to the queue manager (and also to query queue manager attributes).

* Permission to put/get
```
SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
```
User `app1` is allowed to put to and get from `Q1` (also to browse messages and query queue attributes).

* Authorization service
```
qm3.ini: |-
  Service:
    Name=AuthorizationService
    EntryPoints=14
    SecurityPolicy=UserExternal
```
This is new with MQ 9.2.1 and addresses the problem of dealing with identities in containers. It allows programs to run under userids without having to define them to the operating system. [This blog post by Mark Taylor](https://marketaylor.synology.me/?p=782) provides a very good explanation.

#### Create the config map

```
oc apply -n cp4i -f qm3-configmap.yaml

```

### Create the required route for SNI

```
cat > qm3chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-03-qm3-route
spec:
  host: qm3chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm3-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm3chl-route.yaml

```

```
oc apply -n cp4i -f qm3chl-route.yaml

```

Check:

```
oc describe route example-03-qm3-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm3-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm3
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM3
    ini:
      - configMap:
          name: example-03-qm3-configmap
          items:
            - qm3.ini
    mqsc:
    - configMap:
        name: example-03-qm3-configmap
        items:
        - qm3.mqsc
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
          secretName: example-03-qm3-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-03-app1-secret
        items:
          - app1.crt
EOF
#
cat qm3-qmgr.yaml

```
#### Notes:

* Queue manager ini file
```
  queueManager:
    name: QM3
    ini:
      - configMap:
          name: example-03-qm3-configmap
          items:
            - qm3.ini
```
This specifies the `qm3.ini` portion (the authorization service) of the config map created earlier. It it used to populate the queue manager ini file.

#### Create the queue manager

```
oc apply -n cp4i -f qm3-qmgr.yaml

```

# Set up and run the clients

We will put, browse and get messages to test the queue manager we just deployed.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm3-client-put.sh](./run-qm3-client-put.sh) to put two test messages to the queue `Q1`.
* [run-qm3-client-browse.sh](./run-qm3-client-browse.sh) to browse the messages (read them but leave them on the queue).
* [run-qm3-client-get.sh](./run-qm3-client-get.sh) to get messages (read them and remove them from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm3

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm3-ibm-mq-qm -o jsonpath="{.spec.host}"`
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
            "name": "QM3CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM3"
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

### Set environment variables for the client

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
echo "Test message 1" | amqsputc Q1 qm3
echo "Test message 2" | amqsputc Q1 qm3

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
### Get messages from the queue

The program gets the messages and waits for more. Ends if no more messages after 15 seconds:

```
amqsgetc Q1 qm3

```
You should see:

```
Sample AMQSGET0 start
message <Test message 1>
message <Test message 2>
no more messages
Sample AMQSGET0 end
```

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example: 

```
./cleanup-qm3.sh

```

## Next steps

This example runs with a single user, `app1`, which can put to and get from the `Q1` queue. We'll expand the example by adding a second user, `app2` so that `app1` can put (but not get) and `app2` can get (but not put). See [04-app2](../04-app2).
