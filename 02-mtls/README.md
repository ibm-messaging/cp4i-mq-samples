# Example: Configuring mutual TLS

This example deploys a queue manager that requires client TLS authentication.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/02-mtls

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm2.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm2-qmgr.sh](./deploy-qm2-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm2.key -subj "/CN=qm2" -x509 -days 3650 -out qm2.crt

```
This is the same as for one-way TLS. See previous example for details.

## Setup TLS for the MQ client application

### Create a private key and a self-signed certificate for the client application

```
openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

```
This creates two files:

* Private key: `app1.key`

* Certificate: `app1.crt`

Check:

```
ls app1.*

```

You should see:

```
app1.crt	app1.key
```

You can also inspect the certificate:

```
openssl x509 -text -noout -in app1.crt

```

You'll see (truncated for redability):

```
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 11959216796104839727 (0xa5f7ac503bb6d22f)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=app1
        Validity
            Not Before: Jul 26 15:29:37 2021 GMT
            Not After : Jul 24 15:29:37 2031 GMT
        Subject: CN=app1
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
...
```

Note this is a self-signed certificate (Issuer is the same as Subject).

### Set up the client key database

#### Create the client key database:

```
runmqakm -keydb -create -db app1key.kdb -pw password -type cms -stash

```

#### Add the queue manager public key to the client key database:

```
runmqakm -cert -add -db app1key.kdb -label qm2cert -file qm2.crt -format ascii -stashed

```

To check, list the database certificates:

```

runmqakm -cert -list -db app1key.kdb -stashed

```

Expected output:

```
Certificates found
* default, - personal, ! trusted, # secret key
!	qm2cert

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
!	qm2cert
-	ibmwebspheremqemir

```

Get the certificate details:

```
runmqakm -cert -details -db app1key.kdb -stashed -label $label

```
You should see (truncated for readability):

```
Label : ibmwebspheremqemir
Key Size : 2048
Version : X509 V1
Serial : 00a5f7ac503bb6d22f
Issuer : CN=app1
Subject : CN=app1
Not Before : 26 July 2021 16:29:37 GMT+01:00

Not After : 24 July 2031 16:29:37 GMT+01:00

Public Key
    30 82 01 22...
Public Key Type : RSA (1.2.840.113549.1.1.1)
Fingerprint : SHA1 : 
    30 F4 BD 1F...
Fingerprint : MD5 : 
    6B 84 F1 B1...
Fingerprint : SHA256 : 
    66 94 F1 DF...
Fingerprint : HPKP : 
    R9zR4u5Q7Cz3we94Vzo5m/bwf3/zS7+Dmbm4NtYu99s=
Signature Algorithm : SHA256WithRSASignature (1.2.840.113549.1.1.11)
Value
    A5 09 B7 1C...
Trust Status : Enabled
```


### Create TLS Secret for the Queue Manager

```
oc create secret tls example-02-qm2-secret -n cp4i --key="qm2.key" --cert="qm2.crt"

```

### Create TLS Secret with the client's certificate

```
oc create secret generic example-02-app1-secret -n cp4i --from-file=app1.crt=app1.crt

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands

#### Create the config map yaml file

```
cat > qm2-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-02-qm2-configmap
data:
  qm2.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    DEFINE CHANNEL(QM2CHL) CHLTYPE(SVRCONN) REPLACE TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    SET CHLAUTH(QM2CHL) TYPE(BLOCKUSER) USERLIST('nobody') ACTION(ADD)
EOF
#
cat qm2-configmap.yaml

```

#### Note:

The only difference with one-way TLS is `SSLCAUTH(REQUIRED)`. This is what mandates mutual TLS (the client must present its certificate).

#### Create the config map

```
oc apply -n cp4i -f qm2-configmap.yaml

```

### Create the required route for SNI

```
cat > qm2chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-02-qm2-route
spec:
  host: qm2chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm2-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm2chl-route.yaml

```

```
oc apply -n cp4i -f qm2chl-route.yaml

```

Check:

```
oc describe route example-02-qm2-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm2-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm2
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM2
    mqsc:
    - configMap:
        name: example-02-qm2-configmap
        items:
        - qm2.mqsc
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
  version: 9.3.0.0-r2
  web:
    enabled: false
  pki:
    keys:
      - name: example
        secret:
          secretName: example-02-qm2-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: app1
      secret:
        secretName: example-02-app1-secret
        items:
          - app1.crt
EOF
#
cat qm2-qmgr.yaml

```
#### Note:

The only difference with one-way TLS is the `trust` section in the yaml file:

```
    trust:
    - name: app1
      secret:
        secretName: example-02-app1-secret
        items:
          - app1.crt
```
This adds the client certificate (from the secret we created earlier) to the queue manager's key database. It is what allows the queue manager to verify the client.

#### Create the queue manager

```
oc apply -n cp4i -f qm2-qmgr.yaml

```

# Set up and run the clients

We will put, browse and get messages to test the queue manager we just deployed.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [run-qm2-client-put.sh](./run-qm2-client-put.sh) to put two test messages to the queue `Q1`.
* [run-qm2-client-browse.sh](./run-qm2-client-browse.sh) to browse the messages (read them but leave them on the queue).
* [run-qm2-client-get.sh](./run-qm2-client-get.sh) to get messages (read them and remove them from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm2

```

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm2-ibm-mq-qm -o jsonpath="{.spec.host}"`
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
            "name": "QM2CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM2"
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
echo "Test message 1" | amqsputc Q1 QM2
echo "Test message 2" | amqsputc Q1 QM2

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
amqsgetc Q1 QM2

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
./cleanup-qm2.sh

```

## Next steps

Next, we'll enable user authentication. See [03-auth](../03-auth).



