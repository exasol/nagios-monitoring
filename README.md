# Quick Start Guide: icinga-monitoring
[![Build Status](https://travis-ci.org/exasol/nagios-monitoring.svg?branch=icinga2-satellite-host)](https://travis-ci.org/exasol/nagios-monitoring)
###### Please note that this is an open source project which is *not officially supported* by EXASOL. We will try to help you as much as possible, but can't guarantee anything since this is not an official EXASOL product.
###### The full documentation can be found in the [Wiki](https://github.com/exasol/icinga-monitoring/wiki) pages on this GitHub project. 

## Introduction
The EXASOL icinga monitoring container provides users a simple starting point for setting up a monitoring system for your EXASOL database. By running the installation procedure, a fully working icinga monitoring container will be created and some default services to monitor the created host. Afterwards, you can either use this container as your monitoring solution, or extract the icinga configuration for your own monitoring tool. 

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
The icinga2 monitoring bundle also contains an event-based check for cluster log messages. This check needs a logservice with all the desired options and will notify you as soon as there is an entry with a log priority higher than "WARNING". Click on "Monitoring" on the navigation pane where you might already find an appropriate logservice. Otherwise we recommend to create a new logservice with the following options:

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

## Installing and managing the EXASOL icinga docker container
The first step for the installation procedure is to create a new docker instance with the EXASOL icinga image. This image is publicly available and you can find it using the command line options of docker:
```
root@demo ~ # docker search EXASOL
NAME                       DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
exasol/script-languages    Pluggable EXASOL UDF Scripts                    0                    [OK]
exasol/icinga-monitoring   apache2 + icinga2 for EXASolution DB inst...    0                    [OK]
```

The icinga monitoring image needs a port for the icingaweb2 interface. If your local port "80" isn't used yet, we suggest to use this port for the web interface. 
```
docker create -p<your local port>:80 --name <docker container name> --hostname <hostname inside container> exasol/icinga-monitoring:latest
```
Example for default HTTPS port 80 and "exasol-icinga" as name for the container:
```
docker create -p80:80 --name exasol-icinga --hostname exasol-icinga exasol/icinga-monitoring:latest
```
After creating the instance we are able to start it:
```
root@demo ~ # docker start exasol-icinga
exasol-icinga
```
Thats all! Now you have a running Nagios enviroment. The login for the Nagios web interface, navigate to `http://your_docker_ip:your_local_port/icingaweb2`. 


## Wiki
You can find more information about troubleshooting, known problems, plugin descriptions, SNMP plugins on our GitHub icinga-monitoring Wiki page:
https://github.com/EXASOL/icinga-monitoring/wiki

## Sources
All sources to create the docker image can be found on GitHub (https://github.com/EXASOL/icinga-monitoring).
If you want to build the container from scratch you can do by using the following lines:
```
git clone -b icinga2-satellite-host https://github.com/EXASOL/nagios-monitoring
docker build -t exasol/icinga-monitoring:latest -f Dockerfile .
```
