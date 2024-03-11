# Overview
Run `deploy.sh` to create a QueueManager with:
- A local queue named 'Q1'
- A user named 'cp4iadmin' that is able to run PCF/MQSC commands and has access to all queues
- A user named 'app1' that can connect and access the 'Q1' queue
- Certificates to connect as the above users in secrets named 'qm-qmadmin-app1-client' and 'qm-qmadmin-cp4iadmin-client'

Run `download-client-certs.sh` to download the certs for the app1 user.

Run `run-client-*.sh` to act on the 'Q1' queue as the 'app1' user. The certs must be downloaded first.

Run `download-client-certs.sh cp4iadmin` to download the certs for the cp4iadmin user.