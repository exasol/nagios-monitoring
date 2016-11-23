# nagios-monitoring

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
!pic4.png|thumbnail!

### Grant read-only access to all volumes
Add that user to all available EXAStorage volumes. Having read-only access to all volumes is necessary to be able to calculate the free, available space for the databases. A full explanation about calculating the free disk space can be found in SOL-366.

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
Thats all! Now you have a running Nagios3 enviroment. The login for the Nagios3 web interface is "nagiosadmin" and its default password is "admin". The container uses self-signed SSL certificates which will be automatically created.
![Nagios3 - Up and Running](/images/pic16.png)

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
*** successfully created Nagios3 Configuration file '/etc/nagios3/conf.d/exa_cluster25.cfg'
```
After adding the cluster, all monitoring services are added to Nagios. You can check by opening the "Services" page:
![Nagios3 - Services](/images/pic17.png)

### Other operations
To mange the Nagios system, there exist a few additional methods:

Command                                                                     | Purpose
----------------------------------------------------------------------------|---------------------------------------------------------------
docker exec -ti <container id> nagios-addcluster                            | adding a cluster to the monitoring system
docker exec -ti <container id> nagios-listcluster                           | list all clusters added by the configuration wizard
docker exec -ti <container id> nagios-removecluster                         | remove a cluster from the monitoring system
docker exec -ti <container id> nagios-passwd                                | changes the password for the Nagios webinterface
docker exec <container id> nagios-getconfig \|base64 -di >config.tar.gz     | (Linux only!) download the Nagios configuration and plugins

You can download the generated configuration files using the Nagios web interface (see "Download Configuration" link in the navigation pane on the left side).

## Troubleshooting / Known problems
* on Windows docker hosts you need to start your command line prompt (CMD.EXE) with administrator privileges, otherwise pulling the image won't work properly


## Sources
All sources to create the docker image can be found on GitHub: https://github.com/EXASOL/nagios-monitoring
