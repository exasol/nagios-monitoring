README

Fujitsu Software ServerView Nagios-Core-Plugin to handle ServerView CIM indications
===================================================================================

Version:	3.30.02
Author:		Fujitsu Technology Solutions

The tgz contains following directory structure:

	./fujitsu/ServerViewSuite/cimindication/*

	In this directory are three sub-directories:
	-	listener
	-	snmptt
	-	subscribe

Directory listener:
-------------------
		listener service to receive ServerView indications and migrate
		these to traps and call a tool like snmptt for further actions

		it also contains an installation helper script for the listener

Directory snmptt:
-----------------
		this contains one snmptt config file for the migrated indication traps

Directory subscribe:
--------------------
		tool around subscriptions

More about these see corresponding README.txt inside the directories
