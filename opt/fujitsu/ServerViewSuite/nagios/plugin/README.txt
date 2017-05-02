README.txt

Scripts: (alphabetic order)
===========================
	check_fujitsu_server.pl (SNMP)
	------------------------------
	This perl script requires Perl Net::SNMP.

	check_fujitsu_server_CIM.pl (CIM)
	---------------------------------
	This perl script uses as default the command wbemcli. If called 
	with option -UW for WS-MAN usage, this script calls 
	script fujitsu_server_wsman.pl

	check_fujitsu_server_REST.pl (REST)
	-----------------------------------
	This script uses the curl command.

	discover_fujitsu_server.pl (SNMP|CIM|REST)
	------------------------------------------
	This perl script calls tool_fujitsu_server.pl and tool_fujitsu_server_CIM.pl 
	and tool_fujitsu_server_REST.pl dependent of calling options.

	This script checks one or more host addresses if these systems can be monitored by
	the plugin check scripts. This script stores host specific information files and
	Nagios configuration files if the corresponding host can be monitored.

	fujitsu_server_wsman.pl (CIM WS-MAN protocol helper)
	----------------------------------------------------
	This perl script requires ::openwsman (OpenWSMAN Perl Binding)

	inventory_fujitsu_server.pl (SNMP)
	----------------------------------
	This perl script requires Perl Net::SNMP.

	The script is a tool to get inventory information of a system. This information 
	might be fetched unscheduled.
	
	tool_fujitsu_server.pl (SNMP)
	-----------------------------
	This perl script requires Perl Net::SNMP.

	The script is a tool to check the type of a server by testing
	the MIB access.

	tool_fujitsu_server_CIM.pl (CIM)
	--------------------------------
	This perl script calls check_fujitsu_server_CIM.pl.

	The script is a tool for connectivity tests.
	This script is able to get host informations needed to identify the type
	of the host. For this the ServerView CIM classes are searched and analysed.

	tool_fujitsu_server_REST.pl (REST)
	----------------------------------
	This perl script calls check_fujitsu_server_REST.pl.

	The script is a tool for connectivity tests.
	This script is able to get host informations needed to identify the type
	of the host. For this the ServerView REST services are searched.

	updmanag_fujitsu_server_CIM.pl (CIM)
	------------------------------------
	This script calls wbemcli or script fujitsu_server_wsman.pl dependent on calling options.

	Managing features around ServerView Update Management.

	updmanag_fujitsu_server_REST.pl (REST)
	--------------------------------------
	This script calls curl.

	Managing features around ServerView Update Management.

Installation for the usage:
===========================

	Copy Plugin content to Plugin directory
	---------------------------------------
	Please copy the check_* and fujitsu_* scripts into the plugin directory 
	referenced with 
		$USER1$ 
	in your Nagios system ($USER1$ see resources.cfg)
	(e.g. /usr/lib/nagios/plugins, /usr/local/nagios/libexec, …).

	ATENTION: Change access right and user and group assignment according to 
	other plugins !

