ServerView CIM indication listener service
==========================================

ABOUT
-----------
This service is intended to receive CIM indications and translate them to
SNMP traps.

IMPORTANT: Now the daemon uses threads, so be sure your Perl interpreter has
threads support.


INSTALLATION
------------
A) Scripted installation (For RHEL like distributions)
   The script 'fujitsu/ServerViewSuite/cimindication/listener/sv_install.sh'
   provides an easy method to:
   - check prerequisites
   - install the necessary listener files
   - configure the listener daemon
   - start the listener
   - installation logging
   Running the script with -h option will display the available options.

B) Manual installation
1. Copy fujitsu/ServerViewSuite/cimindication/listener/svcimlistenerd to appropriate system 
   'bin' folder: /usr/bin or /usr/local/bin or extend system PATH variable so that 
   svcimlistenerd is found by the service initializations.
2. Copy 'fujitsu/ServerViewSuite/cimindication/listener/svcimlistenerd.conf' 
   to '/etc/svcimlistenerd.conf/'.  
   You may use different location to store config file (use --config CMD option).
3. On Linux system you may need to install following packages (available in
   SUSE/SLES/RedHat RPM repositories):
     * perl-IO-Socket-INET6
     * perl-NetAddr-IP
     * perl-IO-Socket-SSL
     * perl-Net-SSLeay
     * perl-XML-Twig
     * perl-Time-HiRes

WARNING
------------

Some distributions supply older versions of perl-Net-SSLeay module which was not
thread-safe up to version 1.43. Having these versions will cause listener
to fail when using SSL connections. To fix that you should update Net::SSLeay
to more recent version using your distribution package manager, or from CPAN.
Version 1.58 (latest at the moment of this writing) was used for tests.


USAGE
------------

See svcimlistenerd -h for help text

For starting the daemon type:

# svcimlistenerd -c /etc/svcimlistenerd.conf start

To stop the service:

# svcimlistenerd stop

In order to restart with one command:

# svcimlistenerd restart

All the diagnostic information is stored in /var/log/svcimlistener/svcimlistenerd.log
By default, server will start listening on IPv4 and IPv6 port 3169 .

In order to receive CIM indications set up your listener to use the
following URL:

http://<ip-of-the-machine>:3169/ or https://<ip-of-the-machine>:3169/

	Recommended is https usage if the indication sending CIM service
	enables SSL for indications.

Received indications are parsed by svcimlistenerd on the fly.
The indications are migrated to SNMP traps and snmptt is called
for these traps if available (see configuration entry for this)

For debug purposes all incoming traffic and the migrated indication-traps 
can be stored. To enable indications saving debug level should be raised 
to 4 in configuration file. After that, resulting files will 
be available in specified location (/var/log/svcimlistenerd/data by default).

----
END
