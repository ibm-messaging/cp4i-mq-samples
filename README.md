# Connecting to a queue manager running on Cloud Pak for Integration

I documented here the steps I needed to connect an MQ client application to a queue manager running on an OpenShift container in Cloud Pak for Integration (CP4I).

Connecting to a test queue manager running on your laptop is trivial: you turn off all security and set the `MQSERVER` environment variable. This is not possible with a queue manager running on CP4I: at a minimum, you have to implement one-way TLS.

The following examples show how to connect to a queue manager running on CP4I on OpenShift, in increasingly complex configurations, from just one-way TLS and ephemeral storage to mutual TLS, user authentication, and Native HA.

There also examples that show how to connect using MQ Explorer, JMS clients, and the MQ REST API.

To test the connections, the examples use:

* Examples 01 to 06: The MQI Put/Get sample clients (`amqsputc` and `amqsgetc`, and their HA counterparts, `amqsphac` and `amqsghac`).

* Example 07: MQ Explorer.

* Example 08: The JMS sample clients (`JMSPut`, `JMSGet`, and `JMSPutGet`).

* Examples 09 to 12: `curl`.

## Acknowledgments

**I want to thank Callum Jackson, from MQ Development, for his help and guidance when producing this repository.**

**Thanks also to Arnauld Desprets, IBM Integration Architect, for reviewing this repository and providing insightful feedback.**

## Further reading

Max Kahan wrote a set of tutorials on MQ and TLS. They are not based on OpenShift/CP4I, but will give you a very good understanding of the subject:

* [Secure communication between IBM MQ endpoints with TLS](https://developer.ibm.com/tutorials/mq-secure-msgs-tls/)

* [Configuring mutual TLS authentication for a messaging application](https://developer.ibm.com/tutorials/configuring-mutual-tls-authentication-java-messaging-app/).


[TLS for Beginners and more](https://github.com/ADesprets/TLS) is an excellent introduction to the fundamentals of Encryption and TLS.

## Disclaimer

The main aim of this repository is to make the process of connecting to MQ on CP4I easy to learn and understand. Because of that, the way the instructions and scripts are structured is not optimised, and there's a lot of redundancy.

For example, all `deploy...` scripts create a private key and a certificate for the queue manager. The scripts could invoke another that takes the necessary arguments. The resulting, more efficient structure, would be harder to understand, so I opted for scripts that don't call other scripts.

These samples are provided "AS IS", with no warranty of any kind.

# Prerequisites

To run these examples, you need:

* MQI Client

  * If using Mac: [MQ MacOS Toolkit](https://developer.ibm.com/tutorials/mq-macos-dev/)
  
  * If using Linux/Windows: [MQ Redistributable Clients](https://www.ibm.com/links?url=https%3A%2F%2Fibm.biz%2Fmq92redistclients)

* Open SSL (https://www.openssl.org/)

* If trying the MQ Explorer or JMS examples: `keytool` (it is provided with your JDK/JRE).

* For the MQ REST API: `curl` (if not present, download it from https://curl.se/download.html).

* The MQ Operator installed on OpenShift.

These examples were tested on MacOS and Red Hat Linux (RHEL8), with CP4I running on [IBM Cloud](https://cloud.ibm.com).

The examples should work on other clouds, but you will need to change the storage class when running with persistent storage ([Persistent Volume Claims](./05-pvc) and [Native HA](./06-native-ha) examples).

***Note:*** at the time of writing, the [MQ Explorer example](./06-mqx) doesn't work on MacOS.

I haven't tested this extensively on Windows, but most commands shown here should work unchanged if you use [Git Bash](https://git-scm.com/downloads).

*Windows notes:*
1. You must issue `export MSYS_NO_PATHCONV=1` in Git Bash before running any command.

1. To run the client programs (`amqsputc`...) use `cmd.exe` instead of Git Bash.

# Instructions

Before running these examples, open a terminal and login to the OpenShift cluster where you installed the MQ Operator.

To implement the examples, follow the `README.md` found on each folder. Copy/paste the commands shown to a terminal session.

Instead of performing copy/paste of individual commands, you can run the scripts provided in each folder:

`deploy-qm<x>-qmgr.sh` to set up and deploy the queue manager.

`run-qm<x>-client-put.sh` to set up and run the clients that put messages.

`run-qm<x>-client-get.sh` to set up and run the clients that get messages.

`ha-qm<x>-put.sh` to put messages when testing HA.

`ha-qm<x>--get.sh` to get messages when testing HA.

`run-qm<x>-rest-put.sh` to put messages using the MQ REST API.

`run-qm<x>-rest-get.sh` to get messages using the MQ REST API.

# Assumptions

* You installed the MQ Operator in an OpenShift project / Kubernetes namespace called `cp4i`. If that is not the case, perform these global changes:

  * Change all instances of `-n cp4i` to `-n <your namespace>`

  * Change all instances of `Namespace:		cp4i` to `Namespace:		<your namespace>`

* These examples were tested on [IBM Cloud](https://cloud.ibm.com). On other clouds:

  * Change all instances of `ibmc-block-gold` to a storage class that provides block storage.

# Examples

## One-way TLS

[01-tls](./01-tls) shows the minimum that a client needs to connect to a queue manager on CP4I. TLS is set up so that the queue manager presents its certificate, but the client doesn't need to. User Authentication is disabled (queue manager created with `MQSNOAUT=yes`).

## Mutual TLS

[02-mtls](./02-mtls) adds mutual TLS to the previous example. Both queue manager and client must present certificates. User Authentication remains disabled.

## User authentication

[03-auth](./03-auth) adds user authentication. The queue manager is no longer created with `MQSNOAUT=yes`, so clients are authenticated and their permissions to access queues are checked.

## Two users

[04-app2](./04-app2) adds a second user. The first user is allowed to put, but not get. The second user can get, but not put.

## Persistent storage

[05-pvc](./05-pvc) adds persistent storage. In all the previous examples, a queue manager restart resulted in message loss, as queue manager storage was *ephemeral*. In this example, the queue manager uses persistent volume claims (`PVCs`), so that the queue manager data survives a restart.

## Native HA

[06-native-ha](./06-native-ha) implements native HA, introduced with MQ version 9.2. This runs three instances of the queue manager (one active and two replicas) to minimise outages due to the loss of the active instance.

## MQ Explorer

[07-mqx](./07-mqx) shows how to connect MQ Explorer. As MQ Explorer is a Java application, this shows, more generally, how to connect non-JMS Java applications.

## JMS

[08-jms](./08-jms) shows how to connect a JMS client.

## MQ REST API

[09-rest-basic](./09-rest-basic) shows how to set up and use the MQ REST API, the MQ Console, and the Swagger MQ API Explorer. This implements the minimum necessary to test the MQ REST API. Clients authenticate by presenting userid and password.

[10-rest-idpw](./10-rest-idpw) expands the previous example. It has better security (passwords are encoded) and has MQ Console options better suited for a container environment. Clients authenticate by presenting userid and password.

[11-rest-tls](./11-rest-tls) is similar to the previous example, with clients authenticating with a TLS certificate instead of userid and password.

[12-rest-token](./12-rest-token) shows how clients can obtain a token for authentication.
