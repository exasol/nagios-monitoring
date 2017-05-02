#!/bin/sh
#
#   Copyright (C) 2015 Fujitsu Technology Solutions GmbH. All Rights Reserved.
#

# version string
# Version:	3.30.02
# Version:	3.20.01
# Date:		2015-11-09

# svcimlistenerd default installation settings
	DIR_INIT="/etc/init.d"
	FILE_INIT="sv_cimlistenerd"
	DIR_LISTENER="/usr/bin"
	FILE_LISTENER="svcimlistenerd"
	FILE_LISTENER_CONF="svcimlistenerd.conf"
	FILE_LISTENER_LOG="svcimlistenerd.log"

	SV_PORT=3169
	DIR_CONF="/etc"
	DIR_SSL_CERT="$DIR_CONF/svcimlistenerd"
	FILE_LISTENER_CERT="server.crt"

	DIR_LOG_FJ="/var/log/fujitsu/svcimlistener"
	LOG_FILE_INSTALL="install.log"
	LOG_FILE_UNINSTALL="uninstall.log"
	LOG_FILE_CONFIGURE="$DIR_LOG_FJ/configure.log"
	LOG_FILE=$LOG_FILE_INSTALL

# common
	SCRIPTNAME=$(basename $0)
	MODE_PREREQ="TRUE"
	MODE_INSTALL="TRUE"
	MODE_UNINSTALL="FALSE"
	WARN_OCCURED="FALSE"
	ERR_OCCURED="FALSE"
	LICENSEAGREE="no"
	DIALOG="TRUE"

umask 0022

# functions
function usage()
{
	cat <<E_O_F

$SCRIPTNAME usage:
	
  Optional parameter:	
	-e|--erase|--uninstall         Mode Uninstallation
	-n|--noprereq                  Do not check for necessary installed packages
	-v|--verbose|--debug           Be verbose
	-s|--silent                    Unattended mode
	-h|--help|--?                  Displays this usage

E_O_F
}

function message()
{
	if [ "$VERBOSE" == "1" ]; then
		echo -e "$@" | tee -a $LOG
	else
		echo -e "$@" >> $LOG
	fi
}

function message_display()
{
	echo -e "$@" | tee -a $LOG
}

function warn_1()
{
	[ $WARN_OCCURED == "FALSE" ] && echo "Warning occured -- see $LOG"
	WARN_OCCURED="TRUE"
}

function err_1()
{
	[ $ERR_OCCURED == "FALSE" ] && echo "ERROR occured -- see $LOG"
	ERR_OCCURED="TRUE"
}

function check_prerequisites()
{
	message_display "* Check_prerequisites"
	ret=0
	FOUND=0
	SYSLOG=Syslog.pm
	PERL_LIST=`rpm -qa | grep perl`
	for i in $PERL_LIST
		do rpm -q --filesbypkg $i | grep $SYSLOG > /dev/null && message "   -$i (provides $SYSLOG)" && FOUND=1 && break || {
			FOUND=0
		}
	done
	[ $FOUND == 0 ] && message_display "ERROR: package providing \"$SYSLOG\" --- NOT FOUND" && ret=1
	
	
	for i in perl-IO-Socket-INET6 perl-NetAddr-IP perl-IO-Socket-SSL perl-Net-SSLeay perl-XML-Twig perl-Time-HiRes
		do rpm -q $i > /dev/null && message "   -$i" || {
			message_display "ERROR: $i --- NOT FOUND"
			ret=1
		}
	done

	message "   -SNMP Trap Handler"
	unset SELSNMPTT
	SELSNMPTT=`cat svcimlistenerd.conf | sed 's/^[ ]*//' | sed 's/[\x09]//g' | grep ^[^#] | grep '^SNMPTT_EXE' | awk -F "=" '{ print $2}'`
	if [ $SELSNMPTT ]; then
		message "    SNMPTT_EXE found in svcimlistenerd.conf:$SELSNMPTT"
		if [ ! -f $SELSNMPTT ]; then
			message_display "ERROR: SNMP Trap Handler $SELSNMPTT --- NOT FOUND"
			ret=1
		fi
	else
		message_display "ERROR: \"SNMPTT_EXE\" key not found in svcimlistenerd.conf"
		ret=1

	fi

	if [ $ret != 0 ]; then
		message_display "\nDo you want to continue with installation?"
		message_display "If you choose "yes", the installation will proceed <yes/no>"
		read ANSWER                     
		if [ "$ANSWER" != "Y" -a "$ANSWER" != "y" -a "$ANSWER" != "YES" -a "$ANSWER" != "Yes" -a "$ANSWER" != "yes" ]; then
			message_display "Installation aborted by user"
			cat $LOG >> $LOG_FILE_CONFIGURE
			exit 0					
		fi
	fi
	return $ret
}

function get_os_version
{
	local version_file=$1
	if [ -e $version_file ]; then
		local content=$(cat "$version_file")
		if [[ $content =~ [[:digit:]]{1,2} ]]; then
			echo "${BASH_REMATCH[0]}"
		fi
	fi
}
function set_srv_handling
{
	if [ "$redhat_version" == "7" ]; then
		Srv_Listener="service $FILE_LISTENER"
	else
		Srv_Listener=$DIR_INIT/$FILE_INIT
	fi

}
function set_os_type
{
	message_display "* Check distribution"
	if [ -f /etc/SuSE-release ]; then
		OS_NAME="suse"
		message "   OS: $(cat /etc/SuSE-release)"
	else
		if [ -f /etc/redhat-release ]; then
			OS_NAME="redhat"
			message "   OS: $(cat /etc/redhat-release)"
			redhat_version=$(get_os_version /etc/redhat-release)
		fi
	fi
}

function check_svom
{
	#check possible SVOM application server Installation
	message_display "* Check used ports"
	for i in ServerViewJBoss ServerViewTomee
	do rpm -qa | grep -i $i > /dev/null
		if [ "$?" == "0" ]; then
			message_display "   ServerView $i application server is installed."
				# Check svcimlistenerd.conf file for an alternate port to be used
				unset SELPORT
				SELPORT=`cat svcimlistenerd.conf | sed 's/^[ ]*//' | sed 's/[\x09]//g' | grep ^[^#] | grep '^PORT' | awk -F "=" '{ print $2}'`
				if [ $SELPORT ]; then
					message_display "   Alternate cimlistener port $SELPORT found in svcimlistenerd.conf"
					if [ $SELPORT == $SV_PORT ]; then
						message_display "ERROR: Port conflict detected. Please select a free port other than $SV_PORT."
						message_display "       Operation aborted\n"
						exit 1
					fi
				else
					message_display "ERROR: Port conflict detected."
					message_display "       Please select a free port for svcimlistener in svcimlistenerd.conf other than $SV_PORT."
					message_display "       Operation aborted\n"
					exit 1
				fi
			fi
	done
}

# Check commandline arguments
while [ $# -gt 0 ]; do
	case $1 in
	-e|--erase|--uninstall )
		MODE_INSTALL="FALSE"
		MODE_UNINSTALL="TRUE"
		LOG_FILE=$LOG_FILE_UNINSTALL
		LICENSEAGREE="yes"
		shift
	;;
	-v|--verbose|--debug )
		VERBOSE=1
		shift
	;;
	-n|--noprereq )
		MODE_PREREQ="FALSE"
		shift
	;;
	-s|--silent )
		DIALOG="FALSE"
		shift
	;;
	-h|--help|--? )
		usage
		exit 0
	;;
	* )
		usage
		exit 1
	;;
	esac
done

# Check appropriate permission
if [ $MODE_INSTALL == "TRUE" -o $MODE_UNINSTALL == "TRUE" ] && [ `id -u` != 0 ]; then
	echo "Permission denied"
	echo
	echo "FUJITSU Software ServerView Plug-in for Nagios Core -- Operation aborted"
	exit 1;
fi

# Eula
if [ "$LICENSEAGREE" != "yes" -a "$DIALOG" == "TRUE" ]; then
	echo ""
	more EULA.txt
	echo ""
	echo ""
	echo "If you agree please confirm with yes otherwise leave with no"
	read LICENSEAGREE                     
	[ "$LICENSEAGREE" != "YES" -a "$LICENSEAGREE" != "Yes" -a "$LICENSEAGREE" != "yes" -a "$LICENSEAGREE" != "Y" -a "$LICENSEAGREE" != "y" ] && exit 0
fi

# setup logging
[ -f  ${DIR_LOG_FJ}/${LOG_FILE} ]  && rm -f ${DIR_LOG_FJ}/${LOG_FILE}
[ -d $DIR_LOG_FJ ] || mkdir -p $DIR_LOG_FJ
LOG=${DIR_LOG_FJ}/${LOG_FILE}

echo
message_display "FUJITSU Software ServerView Plug-in for Nagios Core -- Operation started at $(date)"
message_display ""

# Detect distribution
	set_os_type
	
# Distribution specific service handling
	set_srv_handling

# Installation
if [ $MODE_INSTALL == "TRUE" ]; then
	# check for an existing SVOM installation
	check_svom

	# check necessary prerequisites
	[ $MODE_PREREQ == "TRUE" ] && check_prerequisites

	# stop exiting listener
	if [ -f $DIR_INIT/$FILE_INIT ]; then
		message_display "* Existing Service $FILE_LISTENER - Shut down"
		$Srv_Listener stop >> $LOG
		ret=$?
		if [ "$ret" != "0" ]; then
			message_display "ERROR: Stop existing $FILE_LISTENER service failed RC:$ret"
		else
			message "   - Existing Service $FILE_LISTENER - Stopped"
		fi
		$Srv_Listener status >> $LOG

		if [ "$OS_NAME" == "suse" ]; then
			/sbin/insserv -r  $DIR_INIT/$FILE_INIT
		else
			/sbin/chkconfig --del $DIR_INIT/$FILE_INIT
		fi
	fi
	
	# rename existing svcimlistenerd.log
	[ -f $DIR_LOG_FJ/$FILE_LISTENER_LOG ] && mv $DIR_LOG_FJ/$FILE_LISTENER_LOG $DIR_LOG_FJ/$( date "+%Y%m%d_%H%M%S" )_$FILE_LISTENER_LOG

	message_display "* Files Installation"
		# Init script
			cp -f -v $FILE_INIT $DIR_INIT/$FILE_INIT >>$LOG 2>&1 || err_1
			chmod 755 $DIR_INIT/$FILE_INIT >>$LOG 2>&1 || err_1

		# CIMListener Daemon
			cp -f -v $FILE_LISTENER $DIR_LISTENER/$FILE_LISTENER >>$LOG 2>&1 || err_1
			chmod 755 $DIR_LISTENER/$FILE_LISTENER >>$LOG 2>&1 || err_1
		
		# CIMListener Config
			cp -f -v $FILE_LISTENER_CONF $DIR_CONF/$FILE_LISTENER_CONF >>$LOG 2>&1 || err_1
			chmod 755 $DIR_CONF/$FILE_LISTENER_CONF >>$LOG 2>&1 || err_1

		# Certificate
			[ -d $DIR_SSL_CERT ] || mkdir $DIR_SSL_CERT
			cp -f -v $FILE_LISTENER_CERT $DIR_SSL_CERT/$FILE_LISTENER_CERT >>$LOG 2>&1 || err_1
	
	message_display "* Service $FILE_LISTENER - Installation"
		if [ "$OS_NAME" == "suse" ]; then
			/sbin/insserv $DIR_INIT/$FILE_INIT
		else
			/sbin/chkconfig --add $DIR_INIT/$FILE_INIT
		fi

	message_display "* Service $FILE_LISTENER - Start"
		$Srv_Listener start >> $LOG
		ret=$?
		sleep 2
		if [ "$ret" != "0" ]; then
			message_display "ERROR: Start $FILE_LISTENER service failed RC:$ret"
			err_1
		else
			message "   - Service $FILE_LISTENER - started"
		fi
		$Srv_Listener status >> $LOG
fi	

# Uninstallation
if [ $MODE_UNINSTALL == "TRUE" ]; then	
	if [ -f $DIR_INIT/$FILE_INIT ]; then
		message_display "* Service $FILE_LISTENER - Shut down"
		$Srv_Listener stop >> $LOG
		ret=$?
		$Srv_Listener status >> $LOG
		if [ "$ret" != "0" ]; then
			message_display "ERROR: Stop $FILE_LISTENER service failed RC:$ret"
		else
			message "   - Service $FILE_LISTENER - Stopped"
		fi

		if [ "$OS_NAME" == "suse" ]; then
			/sbin/insserv -r  $DIR_INIT/$FILE_INIT
		else
			/sbin/chkconfig --del $DIR_INIT/$FILE_INIT
		fi
	else
		message_display "Warning: Service $FILE_LISTENER - not found"
		warn_1
	fi
	
	message_display "* Files Uninstallation"
		[ -f "$DIR_INIT/$FILE_INIT" ] && rm -f "$DIR_INIT/$FILE_INIT" && message "   - $DIR_INIT/$FILE_INIT"
		[ -f "$DIR_LISTENER/$FILE_LISTENER" ] && rm -f "$DIR_LISTENER/$FILE_LISTENER" && message "   - $DIR_LISTENER/$FILE_LISTENER"
		[ -f "$DIR_CONF/$FILE_LISTENER_CONF" ] && rm -f "$DIR_CONF/$FILE_LISTENER_CONF" && message "   - $DIR_CONF/$FILE_LISTENER_CONF"
		[ -d $DIR_SSL_CERT ]&& rm -rf $DIR_SSL_CERT && message "   - Remove Directory: $DIR_SSL_CERT"
fi

echo 
if [ $ERR_OCCURED == "FALSE" -a $WARN_OCCURED == "FALSE" ]; then
	message_display "FUJITSU Software ServerView Plug-in for Nagios Core -- Operation finished"
	echo "Log saved in $LOG file."
	ret=0
else
	message_display "FUJITSU Software ServerView Plug-in for Nagios Core -- Operation ended with warnings / errors"
	echo "Log saved in $LOG file."
	ret=1
fi

cat $LOG >> $LOG_FILE_CONFIGURE
exit $ret

