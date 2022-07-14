# Example: MQ REST API - TLS Authentication

In the previous example [10-idpw](../10-idpw) clients authenticate with userid and password.

In this example, the `app1` client authenticates using its TLS certificate.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/11-rest-tls

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm11.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm11-qmgr.sh](./deploy-qm11-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup TLS for the REST application

### Create a private key and a self-signed certificate for the client application

```
openssl req -newkey rsa:2048 -nodes -keyout app1.key -subj "/CN=app1" -x509 -days 3650 -out app1.crt

```

### Create a PKCS12 key repository for the REST client

```
openssl pkcs12 -export -out app1.p12 -inkey app1.key -in app1.crt -password pass:password

```


### Create JKS trust store for the REST API server

This will be installed in the queue manager's container. It is used by the REST API server to authenticate the client.

```
keytool -importcert -file app1.crt -alias app1 -keystore trust.jks -storetype jks -storepass password -noprompt

```
#### Create config map for the REST API trust store
```
oc create configmap example-11-app1-jks-configmap -n cp4i --from-file=trust.jks

```

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm11-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-11-qm11-configmap
data:
  qm11.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm11.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm11-configmap.yaml

```

#### Create the config map

```
oc apply -n cp4i -f qm11-configmap.yaml

```

### Create a config map for mqwebuser.xml

#### Create the config map yaml file
```
cat > qm11-web-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-11-qm11-web-configmap
  namespace: cp4i
data:
  mqwebuser.xml: |-
    <?xml version="1.0" encoding="UTF-8"?>
    <server>
    <featureManager>
        <feature>apiDiscovery-1.0</feature>
        <feature>appSecurity-2.0</feature>
        <feature>basicAuthenticationMQ-1.0</feature>
    </featureManager>

    <enterpriseApplication id="com.ibm.mq.console">
        <application-bnd>
            <security-role name="MQWebAdmin">
                <group name="MQWebAdminGroup" realm="defaultRealm"/>
            </security-role>
            <security-role name="MQWebAdminRO">
                <group name="MQWebAdminROGroup" realm="defaultRealm"/>
            </security-role>
            <security-role name="MQWebUser">
                <special-subject type="ALL_AUTHENTICATED_USERS"/>
            </security-role>
            <security-role name="MFTWebAdmin">
                <user name="mftadmin" realm="defaultRealm"/>
            </security-role>
            <security-role name="MFTWebAdminRO">
                <user name="mftreader" realm="defaultRealm"/>
            </security-role>
        </application-bnd>
    </enterpriseApplication>

    <enterpriseApplication id="com.ibm.mq.rest">
        <application-bnd>
            <security-role name="MQWebAdmin">
                <group name="MQWebAdminGroup" realm="defaultRealm"/>
            </security-role>
            <security-role name="MQWebAdminRO">
                <user name="mqreader" realm="defaultRealm"/>
            </security-role>
            <security-role name="MQWebUser">
                <special-subject type="ALL_AUTHENTICATED_USERS"/>
            </security-role>
            <security-role name="MFTWebAdmin">
                <user name="mftadmin" realm="defaultRealm"/>
            </security-role>
            <security-role name="MFTWebAdminRO">
                <user name="mftreader" realm="defaultRealm"/>
            </security-role>
        </application-bnd>
    </enterpriseApplication>

    <basicRegistry id="basic" realm="defaultRealm">
    <user name="app1" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
    <user name="mqadmin" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
    <user name="mqreader" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
        <group name="MQWebAdminGroup">
           <member name="mqadmin"/>
        </group>
        <group name="MQWebAdminROGroup">
           <member name="mqreader"/>
        </group>
    </basicRegistry>

    <variable name="httpHost" value="*"/>

    <keyStore id="defaultKeyStore" location="key.jks" type="JKS" password="{aes}AKrGXpGH6tiYd/ZMMwL3T5ERy39DrTTUYHVyx7CIwI2q"/>
    <keyStore id="defaultTrustStore" location="trust.jks" type="JKS" password="{aes}AKrGXpGH6tiYd/ZMMwL3T5ERy39DrTTUYHVyx7CIwI2q"/>
    <ssl id="thisSSLConfig" clientAuthenticationSupported="true" keyStoreRef="defaultKeyStore" serverKeyAlias="default" trustStoreRef="defaultTrustStore" sslProtocol="TLSv1.2"/>
    <sslDefault sslRef="thisSSLConfig"/>    

    <variable name="managementMode" value="externallyprovisioned"/>    
    
    </server>
EOF

```

#### Notes

As in the previous example, this is based on `basic_registry.xml`, with changes necessary to enable TLS authentication.

These lines from `basic_registry.xml` are uncommented:

```
    <keyStore id="defaultKeyStore" location="key.jks" type="JKS" password="{aes}AKrGXpGH6tiYd/ZMMwL3T5ERy39DrTTUYHVyx7CIwI2q"/>
    <keyStore id="defaultTrustStore" location="trust.jks" type="JKS" password="{aes}AKrGXpGH6tiYd/ZMMwL3T5ERy39DrTTUYHVyx7CIwI2q"/>
    <ssl id="thisSSLConfig" clientAuthenticationSupported="true" keyStoreRef="defaultKeyStore" serverKeyAlias="default" trustStoreRef="defaultTrustStore" sslProtocol="TLSv1.2"/>
    <sslDefault sslRef="thisSSLConfig"/>    
```

The default password for the trust and key stores is `password`, and has been encoded using the `securityUtility` command (for details, see [10-rest-idpw](../10-rest-idpw#Create-a-config-map-for-mqwebuser.xml)).

#### Create the config map
```
oc apply -f qm11-web-configmap.yaml

```

### Create service and route for MQ REST server

#### Create service and route yaml file
```
cat > qm11-svc-route.yaml << EOF
kind: Service
apiVersion: v1
metadata:
  name: example-11-qm11-rest-svc
spec:
  ports:
    - name: qmgr
      protocol: TCP
      port: 9443
      targetPort: 9443
  selector:
    app.kubernetes.io/component: integration
    app.kubernetes.io/instance: qm11
    app.kubernetes.io/name: ibm-mq
  type: ClusterIP
  sessionAffinity: None
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-11-qm11-rest-route
spec:
  to:
    kind: Service
    name: example-11-qm11-rest-svc
  port:
    targetPort: 9443
  tls:
    termination: passthrough
  wildcardPolicy: None
EOF
#
cat qm11-svc-route.yaml

```

#### Create service and route

```
oc apply -f qm11-svc-route.yaml

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm11-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm11
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM11
    ini:
      - configMap:
          name: example-11-qm11-configmap
          items:
            - qm11.ini
    mqsc:
    - configMap:
        name: example-11-qm11-configmap
        items:
        - qm11.mqsc
    storage:
      queueManager:
        type: ephemeral
  version: 9.2.4.0-r1
  template:
    pod:
      containers:
        - env:
            - name: MQ_ENABLE_EMBEDDED_WEB_SERVER
              value: 'true'
          ports:
            - containerPort: 9443
              protocol: TCP
          volumeMounts:
            - name: mqwebuser
              readOnly: true
              mountPath: "/etc/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml"
              subPath: mqwebuser.xml
            - name: trustjks
              readOnly: true
              mountPath: "/etc/mqm/web/installations/Installation1/servers/mqweb/resources/security/trust.jks"
              subPath: trust.jks
          name: qmgr
      volumes:
        - name: mqwebuser
          configMap:
            name: example-11-qm11-web-configmap
            items:
              - key: mqwebuser.xml
                path: mqwebuser.xml
            defaultMode: 420
        - name: trustjks
          configMap:
            name: example-11-app1-jks-configmap
            items:
              - key: trust.jks
                path: trust.jks
            defaultMode: 420
  web:
    enabled: false
EOF
#
cat qm11-qmgr.yaml

```

#### Create the queue manager

```
oc apply -n cp4i -f qm11-qmgr.yaml

```

# Set up and run the tests

We will perform the following tests:

* Access the MQ Console in a browser.

* Access the Swagger MQ REST API Explorer in a browser.

* Basic admin (similar to the `dspmq` command).

* Put, browse and get messages.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [open-qm11-console.sh](./open-qm11-console.sh) to open the MQ Console for this queue manager (login with `mqadmin` and `passw0rd`). *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#open-the-console)). 
* [open-qm11-api-explorer.sh](./open-qm11-api-explorer.sh) to open the Swagger MQ REST API Explorer. Login with `mqadmin` and `passw0rd` to test administrative APIs, or with `app1` and `passw0rd` to test messaging APIs. *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#Open-the-MQ-API-Explorer)). 
* [run-qm11-rest-dspmq.sh](./run-qm11-rest-dspmq.sh) to display the queue manager.
* [run-qm11-rest-put.sh](./run-qm11-rest-put.sh) to put two test messages to the queue `Q1`.
* [run-qm11-rest-browse.sh](./run-qm11-rest-browse.sh) to browse a message (read it but leave it on the queue).
* [run-qm11-rest-get.sh](./run-qm11-rest-get.sh) to get a message (read it and remove it from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm11

```

### Confirm that the web server is running

Run `dspmqweb` on the container:
```
oc exec qm11-ibm-mq-0 -- dspmqweb

```
You may see this for the first 1-2 minutes after the queue manager started:
```
MQWB1124I: Server 'mqweb' is running.
MQWB1123E: The status of the mqweb server applications cannot be determined.
A request was made to read the status of the deployed mqweb server applications, however the data appears corrupt. This may indicate that there is already an mqweb server started on this system, probably related to another IBM MQ instance.
Check the startup logs for the mqweb server, looking in particular for conflicting usage of network ports. Ensure that if you have multiple mqweb servers on a system, they are configured to use distinct network ports. Restart the mqweb server and ensure it started correctly. If the problem persists, seek assistance from IBM support.
command terminated with exit code 1
```

Try again until you see:
```
MQWB1124I: Server 'mqweb' is running.
URLS:
  https://qm11-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/console/
  https://qm11-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/rest/
```

### Find the queue manager host name for the REST route

```
rest_hostname=`oc get route -n cp4i example-11-qm11-rest-route -o jsonpath="{.spec.host}"`
echo $rest_hostname

```

Test (optional):
```
ping -c 3 $rest_hostname

```

### Open the console

The MQ Console URL is `https://$rest_hostname/ibmmq/console`.

On a Mac:
```
open https://$rest_hostname/ibmmq/console

```

On Windows:
```
start https://$rest_hostname/ibmmq/console

```

On Linux:
```
xdg-open https://$rest_hostname/ibmmq/console

```
The browser will complain about an untrusted certificate; accept it.

**Note:** Chrome will display "Your connection is not private" and refuse to accept the MQ Console's self-signed certificate.** To accept the certificate and open the Console, type 'thisisunsafe'.

You'll be presented with the login screen. Login with `mqadmin` and `passw0rd`.

### Open the MQ API Explorer

The MQ API Explorer URL is `https://$rest_hostname/ibm/api/explorer`.

On a Mac:
```
open https://$rest_hostname/ibm/api/explorer

```

On Windows:
```
start https://$rest_hostname/ibm/api/explorer

```

On Linux:
```
xdg-open https://$rest_hostname/ibm/api/explorer

```

You'll be presented with a login prompt:

* To try the adminstrative REST API (`.../admin/...` URLs), login with `mqadmin` and `passw0rd`.

* To try the messaging REST API (`.../messaging/...` URLs), login with `app1` and `passw0rd`.

### Display the queue manager

To display the running queue manager (this is similar to the `dspmq` command):
```
curl -k https://$rest_hostname/ibmmq/rest/v2/admin/qmgr -u mqadmin:passw0rd


```

You should see:
```
{"qmgr": [{
  "name": "QM11",
  "state": "running"
}]}
```

#### Note:

On all REST API calls, you have to authenticate (with useris and password) using a basic HTTP header. The `curl` command converts `-u userid:password` to the appropriate header.

### Put messages to the queue

#### Note: the following REST API calls require that the HTTP header `"ibm-mq-rest-csrf-token"` be present. It can have any value. We are using `"ibm-mq-rest-csrf-token: blank"`, but any other value will also work (for example, `"ibm-mq-rest-csrf-token: xx"`).

Put a test message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 1 - put using MQ REST API'

```
You should see:

```
HTTP/1.1 201 Created
X-XSS-Protection: 1;mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'
X-Frame-Options: DENY
Cache-Control: no-cache, no-store, must-revalidate
Content-Language: en-US
Content-Length: 0
Content-Type: text/plain; charset=utf-8
ibm-mq-md-messageId: 414d5120514d31312020202020202020eaa2346202650040
Set-Cookie: LtpaToken2_...; Path=/; Secure; HttpOnly; SameSite=Strict
Date: Fri, 18 Mar 2022 16:43:57 GMT
Expires: Thu, 01 Dec 1994 16:00:00 GMT
```
If you omit `-i`, the command (if it works) does not return anything.

Put another message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 2 - put using MQ REST API'

```
You should see:

```
HTTP/1.1 201 Created
X-XSS-Protection: 1;mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'
X-Frame-Options: DENY
Cache-Control: no-cache, no-store, must-revalidate
Content-Language: en-US
Content-Length: 0
Content-Type: text/plain; charset=utf-8
ibm-mq-md-messageId: 414d5120514d31312020202020202020eaa2346203650040
Set-Cookie: LtpaToken2_...; Path=/; Secure; HttpOnly; SameSite=Strict
Date: Fri, 18 Mar 2022 16:44:43 GMT
Expires: Thu, 01 Dec 1994 16:00:00 GMT
```

### Browse a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Get a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -X DELETE --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Browse and get again

#### Browse:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -X DELETE --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get (queue is empty now):
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM11/queue/Q1/message  -X DELETE --cert app1.p12:password --cert-type p12 -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see a blank response.

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm11.sh

```

## Next steps

The next example shows how to obtain a token at login. The token is then used for authentication on all subsequent calls. See [12-rest-token](../12-rest-token).
