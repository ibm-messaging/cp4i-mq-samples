# Example: MQ REST API - Token Authentication

This example is a variation on [10-rest-idpw](../10-rest-idpw). Instead of authenticating requests with userid and password, users obtain a token at login, which they use on subsequent calls.

For details, see [Using token-based authentication with the REST API](https://www.ibm.com/docs/en/ibm-mq/9.3?topic=security-using-token-based-authentication-rest-api) in the MQ documentation.

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/12-rest-token

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm12.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm12-qmgr.sh](./deploy-qm12-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm12-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-12-qm12-configmap
data:
  qm12.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm12.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm12-configmap.yaml

```

#### Create the config map

```
oc apply -n cp4i -f qm12-configmap.yaml

```

### Create a config map for mqwebuser.xml

```
cat > qm12-web-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-12-qm12-web-configmap
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

    <sslDefault sslRef="mqDefaultSSLConfig"/>

    <variable name="managementMode" value="externallyprovisioned"/>

    </server>
EOF
#
cat qm12-web-configmap.yaml

```

```
oc apply -n cp4i -f qm12-web-configmap.yaml

```

### Create service and route for MQ REST server

```
cat > qm12-svc-route.yaml << EOF
kind: Service
apiVersion: v1
metadata:
  name: example-12-qm12-rest-svc
spec:
  ports:
    - name: qmgr
      protocol: TCP
      port: 9443
      targetPort: 9443
  selector:
    app.kubernetes.io/component: integration
    app.kubernetes.io/instance: qm12
    app.kubernetes.io/name: ibm-mq
  type: ClusterIP
  sessionAffinity: None
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-12-qm12-rest-route
spec:
  to:
    kind: Service
    name: example-12-qm12-rest-svc
  port:
    targetPort: 9443
  tls:
    termination: passthrough
  wildcardPolicy: None
EOF
#
cat qm12-svc-route.yaml

```

```
oc apply -n cp4i -f qm12-svc-route.yaml

```

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm12-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm12
spec:
  license:
    accept: true
    license: L-RJON-CD3JKX
    use: NonProduction
  queueManager:
    name: QM12
    ini:
      - configMap:
          name: example-12-qm12-configmap
          items:
            - qm12.ini
    mqsc:
    - configMap:
        name: example-12-qm12-configmap
        items:
        - qm12.mqsc
    storage:
      queueManager:
        type: ephemeral
  version: 9.3.0.0-r1
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
          name: qmgr
      volumes:
        - name: mqwebuser
          configMap:
            name: example-12-qm12-web-configmap
            items:
              - key: mqwebuser.xml
                path: mqwebuser.xml
            defaultMode: 420
  web:
    enabled: false
EOF
#
cat qm12-qmgr.yaml

```

#### Create the queue manager

```
oc apply -n cp4i -f qm12-qmgr.yaml

```

# Set up and run the tests

We will perform the following tests:

* Access the MQ Console in a browser.

* Access the Swagger MQ REST API Explorer in a browser.

* Basic admin (similar to the `dspmq` command).

* Put, browse and get messages.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [open-qm12-console.sh](./open-qm12-console.sh) to open the MQ Console for this queue manager (login with `mqadmin` and `passw0rd`). *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#open-the-console)). 
* [open-qm12-api-explorer.sh](./open-qm12-api-explorer.sh) to open the Swagger MQ REST API Explorer. Login with `mqadmin` and `passw0rd` to test administrative APIs, or with `app1` and `passw0rd` to test messaging APIs. *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#Open-the-MQ-API-Explorer)). 
* [login-qm12-rest-mqadmin.sh](./run-qm12-rest-dspmq.sh) to login as `mqadmin` and obtain a token.
* [run-qm12-rest-dspmq.sh](./run-qm12-rest-dspmq.sh) to display the queue manager, authenticating with the token.
* [login-qm12-rest-app1.sh](./run-qm12-rest-dspmq.sh) to login as `app1` and obtain a token.
* [run-qm12-rest-put.sh](./run-qm12-rest-put.sh) to put two test messages to the queue `Q1`, authenticating with the token.
* [run-qm12-rest-browse.sh](./run-qm12-rest-browse.sh) to browse a message (read it but leave it on the queue), authenticating with the token.
* [run-qm12-rest-get.sh](./run-qm12-rest-get.sh) to get a message (read it and remove it from the queue), authenticating with the token.

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm12

```

### Confirm that the web server is running

Run `dspmqweb` on the container:
```
oc exec qm12-ibm-mq-0 -- dspmqweb

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
  https://qm12-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/console/
  https://qm12-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/rest/
```

### Find the queue manager host name for the REST route

```
rest_hostname=`oc get route -n cp4i example-12-qm12-rest-route -o jsonpath="{.spec.host}"`
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

### Login as `mqadmin` and obtain a token

```
idpw='{"username":"mqadmin","password":"passw0rd"}'
curl -k -i https://$rest_hostname/ibmmq/rest/v2/login -X POST -H "Content-Type: application/json" --data "$idpw" -c mqadmin-cookie.txt

```

You should see:
```
HTTP/1.1 204 No Content
X-XSS-Protection: 1;mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'
X-Frame-Options: DENY
Cache-Control: no-cache, no-store, must-revalidate
Content-Language: en-US
Content-Length: 0
Set-Cookie: LtpaToken2_1648032846462470073=+SOZOoXCVkmNan+csG1llE8rvw54Tod/.../QbFzRpcm3wzXZQbHZyYsV; Path=/; Secure; HttpOnly; SameSite=Strict
Date: Wed, 23 Mar 2022 13:32:40 GMT
Expires: Thu, 01 Dec 1994 16:00:00 GMT
```

#### Note:

The `login` REST API call returns a token, which we save in a file (`mqadmin-cookie.txt`). This will be used to authenticate the `mqadmin` user instead of userid and password. 

### Display the queue manager

To display the running queue manager, presenting the token:

```
curl -k https://$rest_hostname/ibmmq/rest/v2/admin/qmgr -b mqadmin-cookie.txt

```

You should see:
```
{"qmgr": [{
  "name": "QM12",
  "state": "running"
}]}
```

#### Note:
The token is valid, by default, for 2 hours. After the token expires, you will see:
```
{"error": [{
  "msgId": "MQWB0112E",
  "action": "Login to the REST API to obtain a valid authentication cookie.",
  "completionCode": 0,
  "reasonCode": 0,
  "type": "rest",
  "message": "MQWB0112E: The 'LtpaToken2_1648032846462470073' authentication token cookie failed verification.",
  "explanation": "The REST API request cannot be completed because the authentication token failed verification."
}]}
```

### Login as `app1` and obtain a token

```
idpw='{"username":"app1","password":"passw0rd"}'
curl -k -i https://$rest_hostname/ibmmq/rest/v2/login -X POST -H "Content-Type: application/json" --data "$idpw" -c app1-cookie.txt

```

You should see:
```
HTTP/1.1 204 No Content
X-XSS-Protection: 1;mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'
X-Frame-Options: DENY
Cache-Control: no-cache, no-store, must-revalidate
Content-Language: en-US
Content-Length: 0
Set-Cookie: LtpaToken2_1648032846462470073=ewndKB82nScrScT3e6ENjXj+u7NKZ/.../eh7zkulso20Iw0c83Rr7K89E; Path=/; Secure; HttpOnly; SameSite=Strict
Date: Wed, 23 Mar 2022 13:38:41 GMT
Expires: Thu, 01 Dec 1994 16:00:00 GMT
```

#### Note:

The `login` REST API call returns a token, which we save in a file (`app1-cookie.txt`). This will be used to authenticate the `mqadmin` user instead of userid and password. 

### Put messages to the queue

Put a test message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 1 - put using MQ REST API with Token authentication'

```
You should see:

```
HTTP/1.1 201 Created
Content-Language: en-US
Content-Length: 0
Content-Type: text/plain; charset=utf-8
ibm-mq-md-messageId: 414d5120514d39202020202020202020c21e2a6201350140
Date: Thu, 10 Mar 2022 17:02:33 GMT
```
If you omit `-i`, the command (if it works) does not return anything.

Put another message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 2 - put using MQ REST API with Token authentication'

```
You should see:

```
HTTP/1.1 201 Created
Content-Language: en-US
Content-Length: 0
Content-Type: text/plain; charset=utf-8
ibm-mq-md-messageId: 414d5120514d39202020202020202020c21e2a62013a0140
Date: Thu, 10 Mar 2022 17:05:36 GMT
```

### Browse a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 1 - put using MQ REST API with Token authentication'
```

### Get a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -X DELETE -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 1 - put using MQ REST API with Token authentication'
```

### Browse and get again

#### Browse:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 2 - put using MQ REST API with Token authentication'
```

#### Get:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -X DELETE -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 2 - put using MQ REST API with Token authentication'
```

#### Get (queue is empty now):
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM12/queue/Q1/message  -X DELETE -b app1-cookie.txt -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see a blank response.

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm12.sh

```

This is the end of the MQ REST API Token Authentication example.
