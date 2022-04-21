# Example: MQ Explorer

This example shows how to connect MQ Explorer. It is based on the [03-auth](../03-auth) example: the connection requires mutual TLS and user permissions are checked. The user identity is `mqx1` instead of `app1`.

***Note:*** at the time of writing, this example doesn't work on MacOS.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.ibm.com/EGarza/cp4i-mq.git

```

```
cd cp4i-mq/07-mqx

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm7.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm7-qmgr.sh](./deploy-qm7-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the queue manager

### Create a private key and a self-signed certificate for the queue manager

```
openssl req -newkey rsa:2048 -nodes -keyout qm7.key -subj "/CN=qm7" -x509 -days 3650 -out qm7.crt

```

## Setup TLS for MQ Explorer

MQ Explorer is a Java application. Java applications use a different type of key store, called `JKS`. In JKS, there are two stores:

* Trust store: this will contain the queue manager's signer (CA) certificate. In this case, as the queue manager's certificate is self-signed, the trust store will contain the queue manager's certificate itself.

* Key store: this will contain the client's (that is, MQ Explorer's) certificate and private key.

### Import the Queue Manager's certificate into a JKS trust store

This will create a file called `mqx1-truststore.jks`.

```
keytool -importcert -file qm7.crt -alias qm7cert -keystore mqx1-truststore.jks -storetype jks -storepass password -noprompt

```

List the trust store certificate:

```
keytool -list -keystore mqx1-truststore.jks -alias qm7cert -storepass password

```

Output should be similar to this (truncated for readability; ignore the warning about proprietary format):

```
qm7cert, 7 Dec 2021, trustedCertEntry, 
Certificate fingerprint (SHA-256): 96:62:71:B8:46:AE:48:A0:02:E0:74:BD...

```

### Create a private key and a self-signed certificate for MQ Explorer

```
openssl req -newkey rsa:2048 -nodes -keyout mqx1.key -subj "/CN=mqx1" -x509 -days 3650 -out mqx1.crt

```

#### Add MQ Explorer's certificate and key to a JKS key store

First, put the key (`mqx1.key`) and certificate (`mqx1.crt`) into a PKCS12 file. PKCS12 is a format suitable for importing into the JKS key store (`mqx1-keystore.jks`):

```
openssl pkcs12 -export -out mqx1.p12 -inkey mqx1.key -in mqx1.crt -name mqx1 -password pass:password

```

Next, import the PKCS12 file into a JKS store (this creates the key store; ignore the warning about proprietary format):

```
keytool -importkeystore -deststorepass password -destkeypass password -destkeystore mqx1-keystore.jks -deststoretype jks -srckeystore mqx1.p12 -srcstoretype PKCS12 -srcstorepass password -alias mqx1

```

List the key store certificate:

```
keytool -list -keystore mqx1-keystore.jks -alias mqx1 -storepass password

```

Output should be similar to this (truncated for readability; ignore the warning about proprietary format):

```
mqx1, 7 Dec 2021, PrivateKeyEntry, 
Certificate fingerprint (SHA-256): 95:17:91:9C:09:A1:64:5D:23:AF:66:BA...

```

### Create TLS Secret for the Queue Manager

```
oc create secret tls example-07-qm7-secret -n cp4i --key="qm7.key" --cert="qm7.crt"

```

### Create TLS Secret with the client's certificate

```
oc create secret generic example-07-mqx1-secret -n cp4i --from-file=mqx1.crt=mqx1.crt

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm7-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-07-qm7-configmap
data:
  qm7.mqsc: |
    DEFINE CHANNEL(QM7CHL) CHLTYPE(SVRCONN) TRPTYPE(TCP) SSLCAUTH(REQUIRED) SSLCIPH('ANY_TLS12_OR_HIGHER')
    ALTER AUTHINFO(SYSTEM.DEFAULT.AUTHINFO.IDPWOS) AUTHTYPE(IDPWOS) CHCKCLNT(OPTIONAL)
    SET CHLAUTH('QM7CHL') TYPE(SSLPEERMAP) SSLPEER('CN=mqx1') USERSRC(MAP) MCAUSER('mqx1') ACTION(ADD)
    SET AUTHREC PROFILE('SYSTEM.ADMIN.COMMAND.QUEUE')    OBJTYPE(QUEUE) PRINCIPAL('mqx1') AUTHADD(DSP, INQ, PUT)
    SET AUTHREC PROFILE('SYSTEM.MQEXPLORER.REPLY.MODEL') OBJTYPE(QUEUE) PRINCIPAL('mqx1') AUTHADD(DSP, INQ, GET, PUT)
    SET AUTHREC PROFILE('**') OBJTYPE(AUTHINFO) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(CHANNEL)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(CLNTCONN) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(COMMINFO) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(LISTENER) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(NAMELIST) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(PROCESS)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(QUEUE)    PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT, ALLMQI)
    SET AUTHREC               OBJTYPE(QMGR)     PRINCIPAL('mqx1') AUTHADD(ALLADM, CONNECT, INQ)
    SET AUTHREC PROFILE('**') OBJTYPE(RQMNAME)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(SERVICE)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(TOPIC)    PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT, ALLMQI)
  qm7.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm7-configmap.yaml

```

#### Note:

* SET AUTHREC commands

```
    SET AUTHREC PROFILE('SYSTEM.ADMIN.COMMAND.QUEUE')    OBJTYPE(QUEUE) PRINCIPAL('mqx1') AUTHADD(DSP, INQ, PUT)
    SET AUTHREC PROFILE('SYSTEM.MQEXPLORER.REPLY.MODEL') OBJTYPE(QUEUE) PRINCIPAL('mqx1') AUTHADD(DSP, INQ, GET, PUT)
    SET AUTHREC PROFILE('**') OBJTYPE(AUTHINFO) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(CHANNEL)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(CLNTCONN) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(COMMINFO) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(LISTENER) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(NAMELIST) PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(PROCESS)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(QUEUE)    PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT, ALLMQI)
    SET AUTHREC               OBJTYPE(QMGR)     PRINCIPAL('mqx1') AUTHADD(ALLADM, CONNECT, INQ)
    SET AUTHREC PROFILE('**') OBJTYPE(RQMNAME)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(SERVICE)  PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT)
    SET AUTHREC PROFILE('**') OBJTYPE(TOPIC)    PRINCIPAL('mqx1') AUTHADD(ALLADM, CRT, ALLMQI)
```

These commands give user `mqx1` full administrative rights. They are based on the `setmqaut` commands documented in [Granting full administrative access to all resources on a queue manager](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=grar-granting-full-administrative-access-all-resources-queue-manager).

#### Create the config map

```
oc apply -n cp4i -f qm7-configmap.yaml

```

### Create the required route for SNI

```
cat > qm7chl-route.yaml << EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-07-qm7-route
spec:
  host: qm7chl.chl.mq.ibm.com
  to:
    kind: Service
    name: qm7-ibm-mq
  port:
    targetPort: 1414
  tls:
    termination: passthrough
EOF
#
cat qm7chl-route.yaml

```

```
oc apply -n cp4i -f qm7chl-route.yaml

```

Check:

```
oc describe route example-07-qm7-route

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm7-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm7
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM7
    ini:
      - configMap:
          name: example-07-qm7-configmap
          items:
            - qm7.ini
    mqsc:
    - configMap:
        name: example-07-qm7-configmap
        items:
        - qm7.mqsc
    storage:
      queueManager:
        type: ephemeral
  version: 9.2.4.0-r1
  web:
    enabled: true
  pki:
    keys:
      - name: example
        secret:
          secretName: example-07-qm7-secret
          items: 
          - tls.key
          - tls.crt
    trust:
    - name: mqx1
      secret:
        secretName: example-07-mqx1-secret
        items:
          - mqx1.crt
EOF
#
cat qm7-qmgr.yaml

```
#### Create the queue manager

```
oc apply -n cp4i -f qm7-qmgr.yaml

```

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm7

```

## Create the Channel Table (CCDT) for MQ Explorer

### Find the queue manager host name

```
qmhostname=`oc get route -n cp4i qm7-ibm-mq-qm -o jsonpath="{.spec.host}"`
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
            "name": "QM7CHL",
            "clientConnection":
            {
                "connection":
                [
                    {
                        "host": "$qmhostname",
                        "port": 443
                    }
                ],
                "queueManager": "QM7"
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

# Connect MQ Explorer

1. Start MQ Explorer.

1. Right-click on `Queue Managers` (top left) and select `Add Remote Queue Manager...`

1. Enter the queue manager name (`QM7`, case sensitive) and select the `Connect using a client channel definition table` radio button. Click `Next`.

1. On the next pane (`Specify new connection details`), click `Browse...` and select the file `ccdt.json` just created. Click `Next`.

1. On `Specify SSL certificate key repository details, tick `Enable SSL key repositories`.

1. On `Trusted Certificate Store` click on `Browse...` and select the file `mqx1-truststore.jks`.

1. Select `Enter password...` and enter the trust store password (in our case, `password`).

1. On `Personal Certificate Store` click on `Browse...` and select the file `mqx1-keystore.jks`.

1. Select `Enter password...` and enter the key store password (in our case, `password`).

Click `Finish`.

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm7.sh

```

This is the end of the MQ Explorer example.
