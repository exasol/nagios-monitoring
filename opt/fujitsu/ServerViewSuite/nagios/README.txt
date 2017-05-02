README.txt

Fujitsu Software ServerView Nagios-Core-Plugin To Monitor Fujitsu Servers
=========================================================================

Version:	3.30.02
Author:		Fujitsu Technology Solutions
Usable For:	Nagios Core V3 or higher

This is usable for all Nagios Core V3 compatible systems shortened as
"Nagios" in all subsequent texts. 

The tgz contains following directory structure:

	./fujitsu/ServerViewSuite/nagios/*

	In this directory are three sub-directories:
	-	plugin
	-	cfg
	-	images_logos
	-	trap

Directory plugin:
-----------------
	Directory with perl scripts. 
	DO NOT CHANGE THESE FILES (Copyright FTS)
	
	***_fujitsu_server.pl require
		Net::SNMP !
	***_fujitsu_server_CIM.pl requires
		wbemcli (executable) or fujitsu_server_wsman.pl
		(... dependent on options)
	***_fujitsu_server_REST.pl requires
		curl (executable) 
	fujitsu_server_wsman.pl requires
		Perl ::openwsman
	discover_fujitsu_server.pl requires
		all above named scripts (... dependent on options)

	MONITORING SCRIPTS:
	The script with name 'check_fujitsu_server.pl' is a script to monitor 
	Fujitsu servers. This can be used as check plugin in Nagios environments
	or as standalone script.
	This plugin can monitor
	-	Fujitsu PRIMERGY Servers if ServerView SNMP Agents are installed
	-	Fujitsu PRIMERGY Blades
	-	Fujitsu PRIMEQUEST Servers
	-	Any Servers where Fujitsu ServerView SNMP Agents are installed
	-	Monitor via iRMC address (Firmware Version 7.32 or higher)

	ServerView SNMP Agents Version:
		V5 or higher

	The script with name 'check_fujitsu_server_CIM.pl' is a script to monitor 
	Fujitsu servers where ServerView CIM providers are installed. 
	This can be used as check plugin in Nagios environments
	or as standalone script.
	This plugin can monitor
	-	ESXi where ServerView CIM providers are installed
		ServerView SNMP Agents Version: V6.21 or higher
		Enhanced CIM information are available with V6.31.01 or higher
	-	LINUX where ServerView CIM providers are installed
		ServerView SNMP Agents Version: V6.30.08 or higher
	-	WINDOWS where ServerView CIM providers are installed
		ServerView SNMP Agents Version: V6.30.06 or higher
	-	Monitor via iRMC address (Firmware Version 7.32 or higher)
	The protocol to be used can be selected - CIM-XML or WS-MAN.

	The script with name 'check_fujitsu_server_REST.pl' is a script to monitor 
	Fujitsu servers. This can be used as check plugin in Nagios environments
	or as standalone script.
	This plugin can monitor
	-	Fujitsu PRIMERGY Servers if ServerView SNMP Agents are installed
	-	Any Servers where Fujitsu ServerView SNMP Agents are installed
	-	Monitor via iRMC address (Firmware Version 8.24 or higher)

	TOOL SCRIPTS:
	The tool scripts are tools to check the connection and the type of 
	a server by testing the	accesses (File name starts with tool_*).

	The discover script enables the check of connection with SNMP, CIM and REST and is
	able to generate Nagios-Core compatible host definition configuration files.
	This can be called for one address or multiple addresses (e.g. IPv4 ranges)
	(File name: discover_fujitsu_server.pl)

	The inventory script enables to get enhanced system information. The inventory
	data are data without status and performance values and might be called unscheduled.
	Following data are searched:
	-	Enhanced system information
	-	Information about network addresses
	-	Firmware information
	-	PRIMEQUEST unit information
	-	PRIMERGY information about running processes


Directory cfg:
--------------
	Sample configuration files for Nagios systems. These may be copied or 
	imported into your Nagios configuration files and directories.

Directory images_logos:
-----------------------
	Some ServerView icons (Copyright FTS) which may be used as icons for
	Fujitsu server representations.

Directory trap:
---------------
	In subdirectory trapconf are trap information files which could be read by customer
	tools for own trap handlers.
	The subdirectory snmpttconf contains SNMPTT configuration files which can be integrated
	in the snmptt environment.

= = = = = = = = = 
SHORT CHANGE LOG
V3.30	- New Support of REST services for monitoring.
	  Available REST services are (inband) ServerView Agents and component Server Control (SCCI) 
	  and (out-of-band) ServerView iRMC Report. 
	- SNMP: Handle multiple cabinet units with own fans and temperature sensors 
	  and PSUs

V3.20	- New inventory tool to get additional system informations - usable
	  for unscheduled calls - more about this see additional documents
	- New support (SNMP) for RackCDU(TM) Monitoring
	- New tools for ServerView Update Management (CIM)
	- New tools to handle ServerView CIM indications
	- Updated SNMP trap configurations
V3.10	- Discovery and import of ServerView Operation Manager server list
	- Support ServerView System Monitor URL discovery
	- Support Liquid Cooling Devices
	- Enhance ServerView Update Status to fetch the update difference list
	- Discovery: enable additional control options and more
	- rearange sample configuration hostgroups and their configuration files
V3.00	- Support of monitoring via iRMC address instead of host address
	- Additional discovery tool to discover hosts and generate Nagios
	  configuration files
V2.10	- Support of Windows and LINUX CIM
	- CIM tool to test connectivity and server type
	- Better SNMPv3 support: Enable Input-Option-File to hide credentials
V2.00	- New SNMP Trap support
	- Support of ServerView Update Agent Status
	- New ESXi CIM support via executable wbemcli:
	  check_fujitsu_server_CIM.pl and corresponding sample configurations

V1.20	- Add Operating System Information in notify data
	- Enable File System monitoring and performance check for PRIMERGY server
	- Enable Network Interface monitoring and performance check for PRIMERGY server
	- Support of PRIMEQUEST 2000 series
	- Allow option for any SNMP Transport Domain Type
	- Enable IPv6 SNMP connections (for Perl Net::SNMP V6 or higher) 
V1.10	- Some smaller enhancements and changes for stability and unified printouts
	- Enable variable SNMP port
	- Support standalone monitoring for ServerView RAID
