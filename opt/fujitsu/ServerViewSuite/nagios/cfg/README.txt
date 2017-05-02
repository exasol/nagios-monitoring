README.txt
Version: 3.30.02

These configuration files are created by Fujitsu Technology Solutions.

These configuration files are samples for a Nagios integration.
These may be copied or integrated into your Nagios configurations.

These configurations define hostgroups for Fujitsu PRIMERGY servers, 
PRIMERGY Blades and PRIMEQUEST servers and define services and assign these
to hostgroups.

If some parts are not needed the corresponding "register" field could be set 
to 0 (zero) or corresponding parts can be deleted in copies.

It might happen that new versions of this plugin is delivered with new 
hostgroups.
HINT:	If a hostgroup is defined but no server is assigned to it, an error 
	during start of icinga might occur (during the icinga configuration check).
	In this case, add “allow_empty_hostgroup_assignment=1” in main icinga 
	configuration file ‘icinga.cfg’.
	For more information, see comments there.

The configuration files uses following defines:
	- generic-host
	- generic-service
	- perfdata-service

	- $USER1$ = path of the plugins

If these host or service template definitions are not available
add corresponding templates or change the copied configuration files.

	"perfdata-service" is a template of pnp4nagios

ATTENTION:
	For host definitions it is assumed that one of the following 
	host templates is used for each host:
	- linux-server
	- windows-server

	Sample:
	define host {
		host_name                       ESXi-34
		address                         nnn.nnn.nnn.nnn
		hostgroups                      primergy-servers-CIM,linux-servers
		use                             linux-server
		_SV_CIM_OPTIONS                 -I .....
		register                        1
	}


ATTENTION: If you copy the files into an existing configuration directory then
	set access rights of the copied files according to existing ones !
