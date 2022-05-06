# Example: Configuring one-way TLS

Even with all security disabled, an MQ client cannot access a queue manager on CP4I without  at least one-way TLS.

This example shows how to set up one-way TLS and deploy a queue manager to OpenShift. To test, we use the MQ sample clients `amqsputc` and `amqsgetc` to put and get messages from a queue.

Source: This is based on https://www.ibm.com/docs/en/ibm-mq/9.2?topic=manager-example-configuring-tls

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

Clone this repository and navigate to this directory:

```
git clone https://github.ibm.com/EGarza/cp4i-mq.git

```

```
cd cp4i-mq/01-tls

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm1.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm1-qmgr.sh](./deploy-qm1-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm1.key -subj "/CN=qm1" -x509 -days 3650 -out qm1.crt

```
This creates two files:

* Privaye key: `qm1.key`

* Certificate: `qm1.crt`

Check:

```
ls qm1.*

```

You should see:

```
qm1.crt	qm1.key
```

You can also inspect the certificate:

```
openssl x509 -text -noout -in qm1.crt

```

You'll see (truncated for redability):

```
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 13882868190759648755 (0xc0a9db109dcc7df3)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=qm1
        Validity
            Not Before: Jul 21 09:15:33 2021 GMT
            Not After : Jul 19 09:15:33 2031 GMT
        Subject: CN=qm1
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
...
```

Note this is a self-signed certificate (Issuer is the same as Subject).

### Add the server public key to a client key database

#### Create the client key database:

The client key database will contain the queue manager certificate, so the client can verify the certificate that the queue manager sends during the TLS handshake.

```
runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

```

This creates 4 files:

* Key database: `app1key.kdb`

* Revocation list: `app1key.crl`

* Certificate requests: `app1key.rdb`

* Password stash: `app1key.sth`. Used to pass the password (`"password"`) in commands instead of promting the user.

#### Add the queue manager's certificate to the client key database:

```
runmqakm -cert -add -db app1key.kdb -label qm1cert -file qm1.crt -format ascii -stashed

```

To check, list the database certificates:

```
runmqakm -cert -list -db app1key.kdb -stashed

```

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm1cert
```

You can also get certificate details:

```
runmqakm -cert -details -db app1key.kdb -stashed -label qm1cert

```

### Configure TLS Certificates for Queue Manager

We create a kubernetes secret with the queue manager's certificate and private key. The secret will be used, when creating the queue manager, to populate the queue manager's key database. 

```
oc create secret tls example-01-qm1-secret -n cp4i --key="qm1.key" --cert="qm1.crt"

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands

#### Create the config map yaml file
```
cat > qm1-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-01-qm1-configmap
data:
  qm1.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM1CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(OPTIONAL) SSLCIPH('ANY_TLS12_OR_HIGHER')
    SET CHLAUTH(QM1CHL) TYPE(BLOCKUSER) USERLIST('nobody') ACTION(ADD)
EOF
#
cat qm1-configmap.yaml

```

#### Notes:

The MQSC statements above will run when the queue manager is created:

* Create a local queue called `Q1`. When testing, clients will put to and get from this queue.

* Create a Server Connection channel called `QM1CHL` with a TLS cipherspec (`ANY_TLS12_OR_HIGHER`) and optional TLS client authentication (`SSLCAUTH(OPTIONAL)`).

`SSLCAUTH(OPTIONAL)` makes the TLS connection one-way: the queue manager must send its certificate but the client doesn't have to.

* A Channel Authentication record that allows clients to connect to `QM1CHL` ("block nobody" reverses the CHLAUTH setting that blocks channels connections by default). 

#### Create the config map

```
oc apply -n cp4i -f qm1-configmap.yaml

```

### Create the required route for SNI

MQ Clients use [Server Name Indication](https://datatracker.ietf.org/doc/html/rfc3546#section-3.1) (SNI) to connect to queue managers on OpenShift. This requires a route with a host name in the form `<lowercase channel name>.chl.mq.ibm.com`. We create that route below.

It is easier to only use uppercase letters and numbers for the channel name. This makes the route's host name easier to determine. Other characters are converted according to rules described [here](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=requirements-how-mq-provides-multiple-certificates-capability).

For example:

* Channel `TO.QMGR1` maps to an SNI address of `to2e-qmgr1.chl.mq.ibm.com`.

* Channel `to.qmgr1` maps to an SNI address of `74-6f-2e-71-6d-67-72-1.chl.mq.ibm.com`.

* Channel `QM1CHL` maps to an SNI address of `qm1chl.chl.mq.ibm.com`. ***Much more readable!***

```
cat > qm1chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-01-qm1-route
spec:
  host: qm1chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm1-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm1chl-route.yaml

```

```
oc apply -n cp4i -f qm1chl-route.yaml

```

Check:

```
oc describe route example-01-qm1-route

```

You should see:

```
Name:			example-01-qm1-route
Namespace:		cp4i
Created:		15 seconds ago
Labels:			<none>
Annotations:		...
			
Requested Host:		qm1chl.chl.mq.ibm.com
			   exposed on router default (host ...
Path:			<none>
TLS Termination:	passthrough
Insecure Policy:	<none>
Endpoint Port:		1414

Service:	qm1-ibm-mq
Weight:		100 (100%)
Endpoints:	<error: endpoints "qm1-ibm-mq" not found>
```

Note the `Endpoints` error at the end. This is because the route points to a service (the queue manager's) that does not exist yet. It will be created with the queue manager.

### Deploy the queue manager

#### Create the queue manager's yaml file:

```
cat > qm1-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm1
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM1
    mqsc:
    - configMap:
        name: example-01-qm1-configmap
        items:
        - qm1.mqsc
    storage:
      queueManager:
        type: ephemeral
  template:
    pod:
      containers:
        - env:
            - name: MQSNOAUT
              value: 'yes'
          name: qmgr
  version: 9.2.4.0-r1
  web:
    enabled: true
  pki:
    keys:
      - name: example
        secret:
          secretName: example-01-qm1-secret
          items: 
          - tls.key
          - tls.crt
EOF
#
cat qm1-qmgr.yaml

```

#### Notes:

* Version:

```
  version: 9.2.4.0-r1

```

The MQ version depends on the OpenShift MQ Operator version. To find out your MQ Operator version:
```
oc get sub -n cp4i

```

In this case, the result is (formatted for readbility; your output may differ):
```
NAME                                                      PACKAGE   SOURCE                CHANNEL
...
ibm-mq-v1.7-ibm-operator-catalog-openshift-marketplace    ibm-mq    ibm-operator-catalog  v1.7
```

See [Release history for IBM MQ Operator](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=openshift-release-history-mq-operator) for a list of MQ versions supported by each MQ Operator version.

* License:

```
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
```

The license is correct for the MQ version. If you are installing a different MQ version, you'll find the correct license in [Licensing reference for mq.ibm.com/v1beta1](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=mqibmcomv1beta1-licensing-reference).

* MQSC statements:

```
    mqsc:
    - configMap:
        name: example-01-qm1-configmap
        items:
        - qm1.mqsc
```

The above points to the configmap with MQSC statements we created earlier. The MQSC statements will run when the queue manager is deployed.

* No user authentication:

```
        - env:
            - name: MQSNOAUT
              value: 'yes'
```

Setting the environment variable `MQSNOAUT=yes` disables user authentication (clients don't have to provide userid and password when connecting, and user authority to access resources is not checked). In CP4I, non-production queue managers have this setting by default.

* Queue manager key and certificate:

```
  pki:
    keys:
      - name: example
        secret:
          secretName: example-01-qm1-secret
          items: 
          - tls.key
          - tls.crt
```

The `pki` section points to the secret (created earlier) containing the queue manager's certificate and private key.

#### Create the queue manager

```
oc apply -n cp4i -f qm1-qmgr.yaml

```

# Set up and run the clients

We will put, browse and get messages to test the queue manager we just deployed.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm1-client-put.sh](./run-qm1-client-put.sh) to put two test messages to the queue `Q1`.
* [run-qm1-client-browse.sh](./run-qm1-client-browse.sh) to browse the messages (read them but leave them on the queue).
* [run-qm1-client-get.sh](./run-qm1-client-get.sh) to get messages (read them and remove them from the queue).

## Test the connection

### Confirm that the queue manager is running

It takes 2-5 minutes for the queue manager state to go from "Pending" to "Running".

```
oc get qmgr -n cp4i qm1

```

### Find the queue manager host name

The client needs this to specify the host to connec to.

```
qmhostname=`oc get route -n cp4i qm1-ibm-mq-qm -o jsonpath="{.spec.host}"`
echo $qmhostname

```

Test (optional):
```
ping -c 3 $qmhostname

```

### Create `ccdt.json` (Client Channel Definition Table)

The CCDT tells the client where the queue manager is (host and port), the channel name, and the TLS cipher (encryption and signing algorithms) to use.

For details, see [Configuring a JSON format CCDT](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=tables-configuring-json-format-ccdt).

```
cat > ccdt.json << EOF
{
    "channel":
    [
        {
            "name": "QM1CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM1"
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
#### Note:

```
            "transmissionSecurity":
            {
              "cipherSpecification": "ANY_TLS12_OR_HIGHER"
            },
```

The above enables TLS on the connection. It sets a cipher specification (`ANY_TLS12_OR_HIGHER`) that negotiates the highest level of security that the remote end will allow but will only connect using a TLS 1.2 or higher protocol. For details, see [Enabling CipherSpecs](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=messages-enabling-cipherspecs).

### Export environment variables

We set two environment variables:

* `MQCCDTURL` points to `ccdt.json`.

* `MQSSLKEYR` points to the key database. ***Note this must be the file name without the `.kdb` extension***.

```
export MQCCDTURL=ccdt.json
export MQSSLKEYR=app1key
# check:
echo MQCCDTURL=$MQCCDTURL
ls -l $MQCCDTURL
echo MQSSLKEYR=$MQSSLKEYR
ls -l $MQSSLKEYR.*

```

#### Notes

For `MQCCDTURL`, we use the simplest form that works in this situation (the CCDT is in the directory where the clients run). Other valid forms are:

* Full path:

```
export MQCCDTURL=`pwd`/ccdt.json
```

* Full path (resolving symlinks):

```
thisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export MQCCDTURL="${thisDir}/ccdt.json"
```

* File URL format

```
export MQCCDTURL=file://`pwd`/ccdt.json
```

Same for `MQSSLKEYR`. It is also possible to use the full path to the key database:

```
export MQSSLKEYR=`pwd`/app1key
```

### Put messages to the queue

```
echo "Test message 1" | amqsputc Q1 QM1
echo "Test message 2" | amqsputc Q1 QM1

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

The program gets and displays the messages and waits for more. Ends after 15 seconds if no more messages:

```
amqsgetc Q1 QM1

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
./cleanup-qm1.sh

```

## Next steps

Next we'll try to implement mutual TLS. See [02-mtls](../02-mtls).

