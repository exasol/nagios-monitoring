ServerView CIM indication-trap configurations
=============================================

Check indication-traps inside the snmptt configuration file and add
EXEC directives for those you want to  monitor.

To add the configuration into snmptt configurations follow the hints of
snmptt itself

	Here one extract of the documentation below http://www.snmptt.org/docs/snmptt.shtml:

	Add the file names to the snmptt_conf_files section in the snmptt.ini file.

	For example:

	snmptt_conf_files = <<END
	/etc/snmp/snmptt.conf.generic
	/etc/snmp/snmptt.conf.compaq
	/etc/snmp/snmptt.conf.cisco
	/etc/snmp/snmptt.conf.hp
	/etc/snmp/snmptt.conf.3com
	END
