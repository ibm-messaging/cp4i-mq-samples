# Example: MQ REST API - Userid Authentication

This example is a variation on the previous one, [09-rest-basic](../09-rest-basic).

There are two changes in this example:
1. The registry passwords are not in the clear.
1. The MQ Console option to create a queue manager has been removed (as any new queue manager would be created in the same container; which isn't recommended practice).  

## Preparation

Open a terminal and login to the OpenShift cluster where you installed the CP4I MQ Operator.

If not already done, clone this repository and navigate to this directory:

```
git clone https://github.com/ibm-messaging/cp4i-mq-samples.git

```

```
cd cp4i-mq-samples/10-rest-idpw

```

### Clean up if not first time

Delete the files and OpenShift resources created by this example:

```
./cleanup-qm10.sh

```

# Configure and deploy the queue manager

You can copy/paste the commands shown here, or run the script [deploy-qm10-qmgr.sh](./deploy-qm10-qmgr.sh).

**Remember you must be logged in to your OpenShift cluster.**

## Setup and deploy the queue manager

### Create a config map containing MQSC commands and qm.ini

#### Create the config map yaml file

```
cat > qm10-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-10-qm10-configmap
data:
  qm10.mqsc: |
    DEFINE QLOCAL('Q1') REPLACE DEFPSIST(YES) 
    SET AUTHREC PRINCIPAL('app1') OBJTYPE(QMGR) AUTHADD(CONNECT,INQ)
    SET AUTHREC PROFILE('Q1') PRINCIPAL('app1') OBJTYPE(QUEUE) AUTHADD(BROWSE,GET,INQ,PUT)
  qm10.ini: |-
    Service:
      Name=AuthorizationService
      EntryPoints=14
      SecurityPolicy=UserExternal
EOF
#
cat qm10-configmap.yaml

```

#### Create the config map

```
oc apply -n cp4i -f qm10-configmap.yaml

```

### Create a config map for mqwebuser.xml

```
cat > qm10-web-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-10-qm10-web-configmap
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
cat qm10-web-configmap.yaml

```

```
oc apply -n cp4i -f qm10-web-configmap.yaml

```

#### Notes:

* Encoded passwords

In the previous example, the registry looked like this:
```
    <user name="app1" password="passw0rd"/>
    <user name="mqadmin" password="passw0rd"/>
    <user name="mqreader" password="passw0rd"/>
```

In this example, the passwords are encoded:
```
    <user name="app1" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
    <user name="mqadmin" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
    <user name="mqreader" password="{hash}ATAAAAAIGH/rX4J8t/JAAAAAIJyjgH3qpIZ115Lj1lWJ6ds7Pyw2T8ri5pfB+PFqPohV"/>
```

The process for encoding passwords is documented in [Configuring a basic registry for the IBM MQ Console and REST API](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=roles-configuring-basic-registry-mq-console-rest-api) and [securityUtility command](https://www.ibm.com/docs/en/was-liberty/base?topic=applications-securityutility-command).

The password was encoded using this command:
```
<MQ installation path>/web/bin/securityUtility encode --encoding=hash passw0rd

```

**Optional:** If you want to use, instead of `passw0rd`, a stronger password, run this command (you must have MQ and Java installed in the machine where you run this):
```
<MQ installation path>/web/bin/securityUtility encode --encoding=hash <strong password>

```

***If you set the password to something different than `passw0rd`, remember to enter the new password wherever you see `"-u mqadmin:passw0rd"` and `"-u app1:passw0rd"`.***

If you want to change the password but don't have MQ installed in your machine, you can continue this deployment and then use the queue manager you just created. Once your queue manager is up and running:

1. Open a terminal session with the queue manager pod:

```
oc exec -it qm10-ibm-mq-0 -- sh

```

2. At the prompt (`sh-4.4$`), enter:
```
export PATH=$PATH:/opt/mqm/java/jre64/jre/bin
/opt/mqm/web/bin/securityUtility encode --encoding=hash th1s-1s-a-5tr0nger-passw0rd

```

You should see a response like this (the exact content varies each time):
```
{hash}ATAAAAAICh/FBDu5h/hAAAAAIDIQZEphr8V63VfcC1QqvCeDcCl6ZABo4ofzC2joSgAF
```

3. Copy the result and paste it to the registry section in `mqwebuser.xml`.

4. Close the terminal session:
```
exit

```

5. Update the config map:
```
oc apply -f qm10-web-configmap.yaml

```

6. Delete the queue manager pod - the queue manager will restart and pick up the new password:
```
oc delete pod qm10-ibm-mq-0

```

The queue manager's web server will be ready in 1-2 minutes.

7. Remember to change all instances of `"passw0rd"` to `"th1s-1s-a-5tr0nger-passw0rd"` in all the commands below.

* Console Management Mode

The setting `<variable name="managementMode" value="externallyprovisioned"/>` is optional, but recommended. It disables the `Create queue manager` option on the MQ Console (as creating additional queue managers in a container is not recommended).

### Create service and route for MQ REST server

```
cat > qm10-svc-route.yaml << EOF
kind: Service
apiVersion: v1
metadata:
  name: example-10-qm10-rest-svc
spec:
  ports:
    - name: qmgr
      protocol: TCP
      port: 9443
      targetPort: 9443
  selector:
    app.kubernetes.io/component: integration
    app.kubernetes.io/instance: qm10
    app.kubernetes.io/name: ibm-mq
  type: ClusterIP
  sessionAffinity: None
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: example-10-qm10-rest-route
spec:
  to:
    kind: Service
    name: example-10-qm10-rest-svc
  port:
    targetPort: 9443
  tls:
    termination: passthrough
  wildcardPolicy: None
EOF
#
cat qm10-svc-route.yaml

```

```
oc apply -n cp4i -f qm10-svc-route.yaml

```

The MQ REST API server listens on port 9443, but there is neither a service nor a route to connect to it. The step above creates the service, `example-10-qm10-rest-svc`, that points to the queue manager pod. The route, `example-10-qm10-rest-route`, exposes the service to the outside world. 

### Deploy the queue manager

#### Create the queue manager's yaml file

```
cat > qm10-qmgr.yaml << EOF
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: qm10
spec:
  license:
    accept: true
    license: L-RJON-C7QG3S
    use: NonProduction
  queueManager:
    name: QM10
    ini:
      - configMap:
          name: example-10-qm10-configmap
          items:
            - qm10.ini
    mqsc:
    - configMap:
        name: example-10-qm10-configmap
        items:
        - qm10.mqsc
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
            name: example-10-qm10-web-configmap
            items:
              - key: mqwebuser.xml
                path: mqwebuser.xml
            defaultMode: 420
  web:
    enabled: false
EOF
#
cat qm10-qmgr.yaml

```

#### Create the queue manager

```
oc apply -n cp4i -f qm10-qmgr.yaml

```

# Set up and run the tests

We will perform the following tests:

* Access the MQ Console in a browser.

* Access the Swagger MQ REST API Explorer in a browser.

* Basic admin (similar to the `dspmq` command).

* Put, browse and get messages.

You can copy/paste the commands shown below to a command line, or use these scripts:

* [open-qm10-console.sh](./open-qm10-console.sh) to open the MQ Console for this queue manager (login with `mqadmin` and `passw0rd`). *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#open-the-console)). 
* [open-qm10-api-explorer.sh](./open-qm10-api-explorer.sh) to open the Swagger MQ REST API Explorer. Login with `mqadmin` and `passw0rd` to test administrative APIs, or with `app1` and `passw0rd` to test messaging APIs. *Note:* the script is written for Mac; it must be changed for Linux or Windows (details [below](#Open-the-MQ-API-Explorer)). 
* [run-qm10-rest-dspmq.sh](./run-qm10-rest-dspmq.sh) to display the queue manager.
* [run-qm10-rest-put.sh](./run-qm10-rest-put.sh) to put two test messages to the queue `Q1`.
* [run-qm10-rest-browse.sh](./run-qm10-rest-browse.sh) to browse a message (read it but leave it on the queue).
* [run-qm10-rest-get.sh](./run-qm10-rest-get.sh) to get a message (read it and remove it from the queue).

## Test the connection

### Confirm that the queue manager is running

```
oc get qmgr -n cp4i qm10

```

### Confirm that the web server is running

Run `dspmqweb` on the container:
```
oc exec qm10-ibm-mq-0 -- dspmqweb

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
  https://qm10-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/console/
  https://qm10-ibm-mq-0.qm.cp4i.svc.cluster.local:9443/ibmmq/rest/
```

### Find the queue manager host name for the REST route

```
rest_hostname=`oc get route -n cp4i example-10-qm10-rest-route -o jsonpath="{.spec.host}"`
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
  "name": "QM10",
  "state": "running"
}]}
```

#### Note:

On all REST API calls, you have to authenticate (with useris and password) using a basic HTTP header. The `curl` command converts `-u userid:password` to the appropriate header.

### Put messages to the queue

#### Note: the following REST API calls require that the HTTP header `"ibm-mq-rest-csrf-token"` be present. It can have any value. We are using `"ibm-mq-rest-csrf-token: blank"`, but any other value will also work (for example, `"ibm-mq-rest-csrf-token: xx"`).

Put a test message:
```
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 1 - put using MQ REST API'

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
curl -k -i https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -H "Content-Type: text/plain;charset=utf-8" -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" --data 'Test message 2 - put using MQ REST API'

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
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Get a message

```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 1 - put using MQ REST API
```

### Browse and get again

#### Browse:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank"

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get:
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see:

```
...
Test message 2 - put using MQ REST API
```

#### Get (queue is empty now):
```
curl -k https://$rest_hostname/ibmmq/rest/v2/messaging/qmgr/QM10/queue/Q1/message  -X DELETE -u app1:passw0rd -H "ibm-mq-rest-csrf-token: blank" ; echo

```
You should see a blank response.

## Cleanup

This deletes the queue manager and other objects created on OpenShift, and the files created by this example:

```
./cleanup-qm10.sh

```

## Next steps

The next example shows how to authenticate with TLS certificates instead of userid and password. See [11-rest-tls](../11-rest-tls).
