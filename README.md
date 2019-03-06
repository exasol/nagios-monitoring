# nagios-monitoring
[![Build Status](https://travis-ci.org/exasol/nagios-monitoring.svg?branch=master)](https://travis-ci.org/exasol/nagios-monitoring)

###### Please note that this is an open source project which is *not officially supported* by EXASOL. We will try to help you as much as possible, but can't guarantee anything since this is not an official EXASOL product.

Use https://github.com/EXASOL/nagios-monitoring to read the full manual since Docker Hub is not able to provide the images inside this git project.


## Introduction
The EXASOL nagios monitoring container provides users a simple starting point for setting up a monitoring system for your EXASOL database. By running the installation procedure, a fully working nagios monitoring container will be created and some initial services configured. Afterwards, you can either use this container as your monitoring solution, or extract the nagios configuration for your own monitoring tool. 

## Necessary preparations on EXASOL database clusters
* for using the XMLRPC API, you need an EXAoperation user having at least the supervisor role 
* this user needs to have read access on all EXAStorage volumes of the cluster
* a logservice with all relevant informations
* a database user for accessing the monitoring tables

### Creating the user
Log into EXAoperation web interface with a user which has Administrator or Master role. Under "Access Management" you can add users.
![Access Management](/images/pic2.png)
![Adding Users](/images/pic3.png)

### Assign Supervisor role
Assign the correct role to the new user by clicking "Roles". The default role for new users is "User", but not all XMLRPC functions used by the plugins can be used by this role. That's why you have to change the role to "Supervisor".
![Set up role](/images/pic4.png)

### Grant read-only access to all data and archive volumes 
Add that user to all available EXAStorage volumes - not including any temporary volumes (which are system-managed). Having read-only access to all volumes is necessary to be able to calculate the free, available space for the databases. A full explanation about calculating the free disk space can be found in SOL-366.

Granting access for a specific EXAStorage volume can be done by clicking on "EXAStorage" in the EXAoperation web interface and choosing the desired volume by clicking on the volume name. Now you can edit the volume settings, add the monitoring user to the "Read-only Users" list and apply the changes. This has to be done on all existing volumes.
![EXAStorage](/images/pic11.png)
![EXAStorage - Editing Volumes](/images/pic13.png)
![EXAStorage - Editing Volumes](/images/pic11.png)

### Creating the logservice
The nagios monitoring bundle also contains an event-based check for cluster log messages. This check needs a logservice with all the desired options and will notify you as soon as there is an entry with a log priority higher than "WARNING". Click on "Monitoring" on the navigation pane where you might already find an appropriate logservice. Otherwise we recommend to create a new logservice with the following options:

* Minimum Log Priority: Information
* EXAClusterOS Services: <All>
* Database Systems: <All>

![Monitoring - Logservices](/images/pic15.png)
![Monitoring - Logservices](/images/pic14.png)

To configure the plugin you need the "Service" id (like "logservice2").

### Creating the database monitoring user
If we want to use the performance plugin which uses the statistical system tables of EXASOL, you need a database user which is able to access thes tables. You can use the following snippet to create such a database user:

```sql
CREATE USER exa_monitor IDENTIFIED BY "secure password";
GRANT CREATE SESSION TO exa_monitor;
GRANT SELECT ANY DICTIONARY TO exa_monitor;
```

## Installing and managing the EXASOL nagios docker container
The first step for the installation procedure is to create a new docker instance with the EXASOL nagios image. This image is publicly available and you can find it using the command line options of docker:
```
root@demo ~ # docker search EXASOL
NAME                       DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
exasol/script-languages    Pluggable EXASOL UDF Scripts                    0                    [OK]
exasol/nagios-monitoring   lighttpd + nagios3 for EXASolution DB inst...   0                    [OK]
```

The nagios monitoring image needs a port for the nagios web interface. If your local port "443" isn't used yet, we suggest to use this port for the web interface. 
```
docker create -p<your local port>:443 --name <docker container name> --hostname <hostname inside container> exasol/nagios-monitoring:latest
```
Example for default HTTPS port 443 and "exasol-nagios" as name for the container:
```
docker create -p443:443 --name exasol-nagios --hostname exasol-nagios exasol/nagios-monitoring:latest
```
After creating the instance we are able to start it:
```
root@demo ~ # docker start exasol-nagios
exasol-nagios
```
Thats all! Now you have a running Nagios enviroment. The login for the Nagios web interface, navigate to `https://your_docker_ip:your_local_port`. The container uses a self-signed SSL certificate which will be automatically created. You will be prompted for login credentials. The default username is `nagiosadmin` and the default password is `admin`.
![Nagios - Up and Running](/images/pic16.png)

### Adding a cluster
Adding a cluster is quite simple: you just have to start the configuration wizard and fill out the necessary information. The Nagios configuration files will be generated automatically. The wizard can be started with the following docker command:
```
docker exec -ti <container name/id> nagios-addcluster
```
A full walkthrough for a cluster may look like this:
```
root@demo ~ # docker exec -ti exasol-nagios nagios-addcluster
Cluster name [A-Za-z0-9]: cluster25
License server IP address: 10.70.0.50
EXAoperation user (must have at least the supervisor role): monitor
EXAoperation password: 
Logservice number: 1
IP addresses of all cluster nodes (connection range): 10.70.0.51..59

*** trying to connect...
Do you want to monitor the database instance "db25_1"? (Y/n)y
Database monitoring user: exa_monitor
Password: 
Do you want to monitor the database instance "db25_2"? (Y/n)y
Database monitoring user: exa_monitor
Password: 
*** successfully created Nagios Configuration file '/etc/nagios3/conf.d/exa_cluster25.cfg'
```
After adding the cluster, all monitoring services are added to Nagios. You can check by opening the "Services" page:
![Nagios - Services](/images/pic17.png)

## Wiki
You can find more information about troubleshooting, known problems, plugin descriptions, SNMP plugins on our GitHub nagios-monitoring Wiki page:
https://github.com/EXASOL/nagios-monitoring/wiki

## Sources
All sources to create the docker image can be found on GitHub (https://github.com/EXASOL/nagios-monitoring).
If you want to build the container from scratch you can do by using the following lines:
```
git clone https://github.com/EXASOL/nagios-monitoring
docker build -t exasol/nagios-monitoring:latest -f Dockerfile .
```
