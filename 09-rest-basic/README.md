# Example: MQ REST API

This example shows how to use the MQ REST API. The example is not suitable for Production; its purpose is to present the simplest possible configuration that allows a user to access a queue manager through the REST API. The queue manager created in this example does not have a Server Connection channel, nor does it have TLS certificates. It can't be accessed by MQI or Java clients.  

For information about the MQ REST API, see:

* IBM Developer article: [Get started with the IBM MQ messaging REST API](https://developer.ibm.com/tutorials/mq-develop-mq-rest-api/).

* IBM Documentation: [Getting started with the messaging REST API](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=api-getting-started-messaging-rest).

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.ibm.com/EGarza/cp4i-mq.git

```

```
cd cp4i-mq/09-rest-basic

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm9.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm9-qmgr.sh](./deploy-qm9-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm9-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-09-qm9-configmap
data:
  qm9.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm9.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm9-configmap.yaml

```

#### Notes:

There are no channels in this queue manager. We just create a queue, and give permissions to the user (`app1`) who will connect via the REST API.

#### Create the config map

```
oc apply -n cp4i -f qm9-configmap.yaml

```

### Create a config map for mqwebuser.xml

```
cat > qm9-web-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-09-qm9-web-configmap
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
    <user name="app1" password="passw0rd"/>
    <user name="mqadmin" password="passw0rd"/>
    <user name="mqreader" password="passw0rd"/>
        <group name="MQWebAdminGroup">
           <member name="mqadmin"/>
        </group>
        <group name="MQWebAdminROGroup">
           <member name="mqreader"/>
        </group>
    </basicRegistry>

    <variable name="httpHost" value="*"/>

    <sslDefault sslRef="mqDefaultSSLConfig"/>

    </server>
EOF
#
cat qm9-web-configmap.yaml

```

```
oc apply -n cp4i -f qm9-web-configmap.yaml

```

#### Notes:

The MQ REST API server uses the configuration file `mqwebuser.xml`. The full file path is `/var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml`.

The file we create is based on the MQ REST API sample `basic_registry.xml`, found in `/opt/mqm/web/mq/samp/configuration/`.

There are a few additions to the original sample:

* The Swagger API Explorer feature, which will let us examine and test the APIs in a browser:
```
    <featureManager>
        <feature>apiDiscovery-1.0</feature>
        ...
```
* The `app1` user (authorised to put to/get from Q1):
```
    <user name="app1" password="passw0rd"/>
    <user name="mqadmin" password="passw0rd"/>
    <user name="mqreader" password="passw0rd"/>
```
* Setting needed by the embedded web server (which processes the REST API requests). Without this, the web server only accepts REST API requests from `localhost`:
```
    <variable name="httpHost" value="*"/>
```

For simplicity, we leave the passwords in the clear. The [next example](./10-rest-idpw) shows how to encode the passwords.

### Create service and route for MQ REST server

```
cat > qm9-svc-route.yaml << EOF
kind: Service
apiVersion: v1
metadata:
  name: example-09-qm9-rest-svc
spec:
  ports:
    - name: qmgr
      protocol: TCP
      port: 9443
      targetPort: 9443
  selector:
    app.kubernetes.io/component: integration
    app.kubernetes.io/instance: qm9
    app.kubernetes.io/name: ibm-mq
  type: ClusterIP
  sessionAffinity: None
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-09-qm9-rest-route
spec:
  to:
    kind: Service
    name: example-09-qm9-rest-svc
  port:
    targetPort: 9443
  tls:
    termination: passthrough
  wildcardPolicy: None
EOF
#
cat qm9-svc-route.yaml

```

```
oc apply -n cp4i -f qm9-svc-route.yaml

```

The MQ REST API server listens on port 9443, but there is neither a service nor a route to connect to it. The step above creates the service, `example-09-qm9-rest-svc`, that points to the queue manager pod. The route, `example-09-qm9-rest-route`, exposes the service to the outside world. 

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm9-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm9
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM9
    ini:
      - configMap:
          name: example-09-qm9-configmap
          items:
            - qm9.ini
    mqsc:
    - configMap:
        name: example-09-qm9-configmap
        items:
        - qm9.mqsc
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
          name: qmgr
      volumes:
        - name: mqwebuser
          configMap:
            name: example-09-qm9-web-configmap
            items:
              - key: mqwebuser.xml
                path: mqwebuser.xml
            defaultMode: 420
  web:
    enabled: false
EOF
#
cat qm9-qmgr.yaml

```
#### Notes:

There are similarities and differences between this queue manager and, for example, `qm3` (see [03-auth](./03-auth)):

* Both queue managers give permission to a user, `app1`, to connect to the queue manager and put to/get from Q1. On `qm3`, the clients connect to a Server Connection channel, and authenticate by presenting a TLS certificate. On this queue manager, the client authenticates with userid and password, presented in a basic HTTP header.

* Same as on all previous examples, the queue manager was created with:
```
  web:
    enabled: false
```

With this setting, there is no MQ Web Console.

On this queue manager, we add:
```
        - env:
            - name: MQ_ENABLE_EMBEDDED_WEB_SERVER
              value: 'true'
          ports:
            - containerPort: 9443
              protocol: TCP
```
REST clients access an embedded Web Server in the container. This server listens on port 9443 (see above, where we create a service for this) and provides MQ Web Console and REST support. Below we'll see how to access the MQ Web Console on this queue manager.

* Configuration file (`mqwebuser.xml`)

This queue manager places the config map we created earlier on a path (`/etc/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml`) from which it will be copied, when the queue manager is created, to where the Web Server expects it (`/var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml`).
```
          volumeMounts:
            - name: mqwebuser
              readOnly: true
              mountPath: "/etc/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml"
              subPath: mqwebuser.xml
          name: qmgr
      volumes:
        - name: mqwebuser
          configMap:
            name: example-09-qm9-web-configmap
            items:
              - key: mqwebuser.xml
                path: mqwebuser.xml
            defaultMode: 420
```
You'll find details about how this works in [Using subPath](https://kubernetes.io/docs/concepts/storage/volumes/#using-subpath), in the Kubernetes documentation. The short explanation is: if you don't use `subPath`, the whole directory contents are replaced by the `mqwebuser.xml` file, and existing files (which are needed) are lost.

#### Create the queue manager

```
oc apply -n cp4i -f qm9-qmgr.yaml

```

# Set up and run the tests

We will perform the following tests:

* Access the MQ Console in a browser.

* Access the Swagger MQ REST API Explorer in a browser.

* Basic admin (similar to the `dspmq` command).

* Put, browse and get messages.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [open-qm9-console.sh](./open-qm9-console.sh) to open the MQ Console for this queue manager (login with `mqadmin` and `passw0rd`). *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#open-the-console)). 
* [open-qm9-api-explorer.sh](./open-qm9-api-explorer.sh) to open the Swagger MQ REST API Explorer. Login with `mqadmin` and `passw0rd` to test administrative APIs, or with `app1` and `passw0rd` to test messaging APIs. *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#Open-the-MQ-API-Explorer)). 
* [run-qm9-rest-dspmq.sh](./run-qm9-rest-dspmq.sh) to display the queue manager.
* [run-qm9-rest-put.sh](./run-qm9-rest-put.sh) to put two test messages to the queue `Q1`.
* [run-qm9-rest-browse.sh](./run-qm9-rest-browse.sh) to browse a message (read it but leave it on the queue).
* [run-qm9-rest-get.sh](./run-qm9-rest-get.sh) to get a message (read it and remove it from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm9

```

### Confirm that the web server is running

Run `dspmqweb` on the container:
```
oc exec qm9-ibm-mq-0 -- dspmqweb

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
  https://qm9-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/console/
  https://qm9-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/rest/
```

### Find the queue manager host name for the REST route

```
rest_hostname=`oc get route -n cp4i example-09-qm9-rest-route -o jsonpath="{.spec.host}"`
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

**Note:** Chrome will display "Your connection is not private" and refuse to accept the MQ Console's self-signed certificate. To accept the certificate and open the Console, type `thisisunsafe`.

You'll be presented with the login screen. Login with `mqadmin` and `passw0rd`.

To access the queue manager, navigate to `Manage` / `Local queue managers` / `QM9`.

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
  "name": "QM9",
  "state": "running"
}]}
```

#### Note:

On all REST API calls, you have to authenticate (with useris and password) using a basic HTTP header. The `curl` command converts `-u userid:password` to the appropriate header.

### Put messages to the queue

#### Note: the following REST API calls require that the HTTP header `"ibm-mq-rest-csrf-token"` be present. It can have any value. We are using `"ibm-mq-rest-csrf-token: blank"`, but any other value will also work (for example, `"ibm-mq-rest-csrf-token: xx"`).

Put a test message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 1 - put using MQ REST API'

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
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 2 - put using MQ REST API'

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
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Get a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Browse and get again

#### Browse:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get (queue is empty now):
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM9/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see a blank response.

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm9.sh

```

## Next steps

The next example follows recommended practice. It has the Registry passwords encoded and adjusts the MQ Console options to the use of an embedded web server. See [10-rest-idpw](../10-rest-idpw).
