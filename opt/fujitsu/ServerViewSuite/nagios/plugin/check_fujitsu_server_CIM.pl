#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2012, 2013, 2014, 2015, 2016
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.01
# Date:		2016-08-03

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
#use Getopt::Long qw(GetOptionsFromString); ... requires Perl 5.10 or higher
#		This is not available on all systems !
use Pod::Usage;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

#------ This Script uses as default wbemcli -------#

#### EXTERN HELPER  ####################################

our $wsmanPerlBindingScript = "fujitsu_server_wsman.pl";
#   ... see option -UW

#### HELP ##############################################
=head1 NAME

check_fujitsu_server_CIM.pl - Monitor server using ServerView CIM-Provider information

=head1 SYNOPSIS

check_fujitsu_server_CIM.pl 
  {  -H|--host=<host> [-A|--admin=<host>]
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      [-U|--use=<mode>]
      [-S|--service=<mode>]
      [--cacert=<cafile>]
      [--cert=<certfile> --privkey=<keyfile>] 
      { -u|--user=<username> -p|--password=<pwd> 
      } |
      -I|--inputfile=<filename>
    }
    { [--chkidentify] | [--systeminfo] |
      {   { [--chksystem] 
            {[--chkenv] | 
              [--chkenv-fan|--chkfan] [--chkenv-temp|--chktemp]}
            [--chkpower] 
            {[--chkhardware] | 
              [--chkcpu] [--chkvoltage] [--chkmemmodule]}
            [--chkstorage] 
            [--chkupdate [{--difflist|--instlist} [-O|--outputdir=<dir>]]]
          }
      }
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Checks a Fujitsu server reading ServerView CIM provider information.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>  [-A|--admin=<ip>]

Host address as DNS name or ip address of the server.
With optional option -A an administrative ip address can be specified.
This might be the address of iRMC as an example.
The communication is done via the admin address if specified.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>]

CIM service port number and transport type and the selection of wbemcli versus wsman Perl binding. 

WBEMCLI USAGE: The program wbemcli uses a default port 5989 for the calls - It is not 
necessary to enter this number.

WS-MAN USAGE: The port number must be set because there exists no common default 
for corresponding WS-MAN services. For some known port numbers the transport type is automatic set.

In the transport type 'http' or 'https' can be specified. 'https' is default for wbemcli.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [-U|--use=<mode>] [-S|--service=<mode>]

To select WS-MAN usage enter "W" as use mode - "C" is default and is meant for "CIM-XML" usage.

For experts: With the service mode can be specified which kind of system is listenting. 
If this option is set an internal "service identification" is prevented for all calls 
beside "--chkidentify". 
Use "E" for ESXi, "L" for Linux, "W" for Windows and "I" for iRMC.

=item -u|--user=<username> -p|--password=<pwd>

Authentication data. 
For use in cim-xml protocol (wbemcli) the password must not contain any '.'.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [--cacert=<cafile>]

For wbemcli: CA certificate file. If not set -noverify will be used.
    See wbemcli parameter -cacert

For WS-MAN protocol: CA certificate file. See wsman option -c, --cacert=

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [--cert=<certfile> --privkey=<keyfile>]

For wbemcli: Client certificate file and Client private key file.
    wbemcli requires both file names if this should be used.
    It depends on configuration on the host side if these 
    certificates are verified or not !
    See wbemcli parameter -clientcert and -clientkey

For WS-MAN protocol: Client certificate file and Client private key file.
    See wsman options -A, --cert= and -K, --sslkey=

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.

=item --chkidentify

Tool option to check the access to the CIM provider by reading the service "Identification".
This option can not be combined with other check options

=item --systeminfo

Only print available system information (dependent on server type).
This option can not be combined with other check options

=item --chksystem 

=item --chkenv | [--chkenv-fan|--chkfan] [--chkenv-temp|--chktemp]

=item --chkpower

=item --chkhardware | [--chkcpu] [--chkvoltage] [--chkmemmodule]

Select range of system information: System meaning anything other than
Environment (Fan, Temperature) or Power (Supply units and consumption).

Options chkenv and chkhardware can be split to select only parts of the above mentioned
ranges.

=item --chkstorage

For PRIMERGY server these options can be used to monitor only "Hardware" or only "MassStorage" parts.
These areas are part of the Primergy System Information

=item --chkupdate [{--difflist|--instlist}  [-O|--outputdir=<dir>]]

For PRIMERGY server: monitor "Update Agent" status.

difflist:
Fetch Update component difference list and print the first 10 ones of these and store
all of these in an host specific output file in directory <dir> if specified.

instlist:
Fetch Update installed component list and print the first 10 ones of these and store
all of these in an  host specific output file in directory <dir> if specified.

=item -t|--timeout=<timeout in seconds>

Timeout for the script processing.

=item -v|--verbose=<verbose mode level>

Enable verbose mode (levels: 1,2).
Generates Multi-line output with verbose level 2.

=item -V|--version

Print version information and help text.

=item -h|--help

Print help text.

=cut


=begin COMMENT
            [--chkdrvmonitor]

######item --chkdrvmonitor

For PRIMERGY server: monitor "DriverMonitor" parts.
    
    
    [-E|--encryptfile=<filename>]

######item -E|--encryptfile=<filename>

Options which values need to be decrypted before use, 
read from <filename>. Only a limited set of options can be used here: 

    -H|--host=<name-or-ip>
    -P|--port=<port>
    -u|--user=<username>
    -p|--password=<pwd>

These options overwrite options set on command line and in 'inputfile'.

=end COMMENT
=cut


#### GLOBAL OPTIONS ###################################

# init main options
our $argvCnt = $#ARGV + 1;
our $optHost = '';
our $optTimeout = 0;
our $optShowVersion = undef;
our $optHelp = undef;
our $optPort = undef;
our $optAdminHost = undef;

# CIM authentication
our $optUserName = undef; 
our $optPassword = undef; 
our $optCert = undef; 
our $optPrivKey = undef; 
our $optCacert = undef;
our $optAuthDigest = undef;

# CIM specific option
our $optTransportType = undef;
our $optTransportPrefix = '/wsman';
our $optChkClass = undef;
our $optClass = undef; 
our $optUseMode = undef;
our $optServiceMode = undef;	# E ESXi, L Linux, W Windows

# init additional check options
our $optChkSystem = undef;
our $optChkEnvironment = undef;
our	$optChkEnv_Fan = undef;
our	$optChkEnv_Temp = undef;
our $optChkPower = undef;
our $optChkHardware = undef;
our	$optChkCPU = undef;
our	$optChkVoltage = undef;
our	$optChkMemMod = undef;
our $optChkStorage = undef;
our $optChkDrvMonitor = undef;
our $optChkUpdate = undef;
our $optChkCpuLoadPerformance	= undef;
our $optChkMemoryPerformance	= undef;
our $optChkFileSystemPerformance = undef;
our $optChkNetworkPerformance	= undef;
our $optChkFanPerformance	= undef;

our $optChkIdentify = undef;
our $optSystemInfo = undef;
our $optAgentInfo = undef;
our $optUseDegree = undef;

our     $optChkUpdDiffList	= undef;
our	$optChkUpdInstList	= undef;
our	$optOutdir		= undef;

# special sub options
our $optWarningLimit = undef;
our $optCriticalLimit = undef;
our $optInputFile = undef;
#our $optEncryptFile = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::scriptPath = undef;

#### GLOBAL DATA BESIDE OPTIONS
# global control definitions
our $skipInternalNamesForNotifies = 1;	    # suppress print of internal product or model names

# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# option cross check result
our $setOverallStatus = undef;	# no chkoptions
our $setOnlySystem = undef;	# only --chksystem
our $requiresNoSummary = undef;	# if only chkupdate

our $noSummaryStatus = 1;
our $oldAgentException = 0;	# exception for WS-MAN and older Agent which 
				# have no summary component status values

# init output data
our $exitCode = 3;
our $error = '';
our $msg = '';
our $notifyMessage = '';
our $longMessage = '';
our $variableVerboseMessage = '';
our $performanceData = '';

# init some multi used processing variables (CIM)
our $clientSession = undef;
our $serverID = undef;
our $useDegree = 0;

# CIM
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
# MAYBE TODO "is old or new ESXi"
our $is2014Profile = undef;

# CIM central ClassEnumerations to be used by multiple functions:
our @cimSvsComputerSystem = ();
our @cimSvsChassis = ();
our @cimSvsIPs = ();
our @cimSvsOperatingSystem = ();

our $cimOS = undef;
our $cimOSDescription = undef;

# HashTable-References: ! --- Collection out of SVS_PGYHealthStateComponent
our $cimSvsRAIDAdapters = undef; 
our $cimSvsDrvMonAdapters = undef; 
our $cimSvsFanAdapters = undef;
our $cimSvsTempAdapters = undef;
our $cimSvsPSUAdapters = undef;
our $cimSvsVoltAdapters = undef;
our $cimSvsOtherSystemBoardAdapters = undef;
our $cimSvsOtherPowerAdapters = undef; # for iRMC

our $statusOverall		= undef;
our   $statusEnv		= undef;  
our     $allFanStatus		= undef;
our     $allTempStatus		= undef;
our   $statusPower		= undef; 
our     $statusPowerLevel	= undef; # CIM HealthStateComponent
our   $statusSystemBoard	= undef; 
our     $allVoltageStatus	= undef;
our     $allCPUStatus		= undef;
our     $allMemoryStatus	= undef;
our   $statusMassStorage	= undef;
our   $statusDrvMonitor		= undef;

our $allHealthFanStatus		= undef;
our $allHealthTempStatus	= undef;
our $allHealthPowerStatus	= undef;
our $allHealthVoltageStatus	= undef;
our $allHealthCPUStatus		= undef;
our $allHealthMemoryStatus	= undef;

#### PRINT / FORMAT FUNCTIONS ##########################################
#----------- 
  sub finalize {
	my $tmpExitCode = shift;
	#$|++; # for unbuffered stdout print (due to Perl documentation)
	my $string = "@_";
	print "$string" if ($string);
	print "\n";
	alarm(0); # stop timeout
	exit($tmpExitCode);
  }
#----------- miscelaneous helpers 
  sub addExitCode {
	my $addCode = shift;
	if (defined $addCode) {
		if ($exitCode == 3) {
			$exitCode = $addCode;
		} else {
			$exitCode = $addCode if ($addCode < 3 and $addCode > $exitCode);
		}
	}
  } #addExitCode

  sub addTmpExitCode {
	my $addCode = shift;
	my $tmpCode = shift;
	if (defined $addCode) {
		if ($tmpCode == 3) {
			$tmpCode = $addCode;
		} else {
			$tmpCode = $addCode if ($addCode < 3 and $addCode > $tmpCode);
		}
	}
	return $tmpCode;
  } #addTmpExitCode

  sub negativeValueCheck { 
		my $val = shift;
		my $maxval = 0xFFFFFFFF;
		return undef if (!defined $val);
		return $val if ($val < 0x7FFFFFFF);
		#return 0 if ($val == 4294967295); # -0 ... for Perl::Net::SNMP
		return -1 if ($val == 4294967295); # -0 ... for CIM

		#my $diffval = $maxval - $val; #... for Perl::Net::SNMP
		my $diffval = $maxval - $val +1; #... for CIM
		my $newval = "-" . "$diffval";
		return $newval;
  } #negativeValueCheck

  sub utf8tohex {
	my $maxlen = shift;
	my $string = shift;
	my $result = "";
	my $rest = $string;
	# maxlen is required because length could not be calculated if there are
	# control bytes inside like \0 or \f
	for (my $i=0;$i<=$maxlen;$i++) { 
		if ($rest) {
			for (my $t=0;$t<=255;$t++) {
				my $subs  = sprintf("%02X", $t);
				if ($rest =~ m/^\x$subs/) { # found hex value
					$result = $result . "$subs";
					$rest =~ s/^\x$subs//; # cut with care
					#print ">>>$rest\n";
					$t = 256; # ... break loop
				}
			}
		} # rest is not empty 
		else {
			$i = $maxlen + 1;
		}
	} #for
	return $result;
  }
#----------- performance data functions
  sub addTemperatureToPerfdata {
	my $name = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	#my $min = shift;
	#my $max = shift;

	if (defined $name and $current) {
		$performanceData .= ' ' . $name . '=' if ($name);
		$performanceData .= $current;
		$performanceData .= "\xc2\xb0" if ($useDegree);
		$performanceData .= 'C';
		$performanceData .= ';' if ($warning or $critical);
		$performanceData .= "$warning" if ($warning);
		$performanceData .= ';' if ($critical);
		$performanceData .= "$critical" if ($critical);
	}
  } #addTemperatureToPerfdata

  our $PSConsumptionBTUH = 0;
  sub addPowerConsumptionToPerfdata {
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;

	$current = 0 if (defined $current and $current == 4294967295); # -0
	$current = undef if (defined $current and $current == -1);

	if (defined $current) {
		$current = negativeValueCheck($current);
		$warning = undef	if (defined $warning and ($warning == 0 or $warning ==-1));
		$critical = undef	if (defined $critical and ($critical == 0 or $critical ==-1));
		$min = undef		if (defined $min and ($min == 0 or $min == -1));
		$max = undef		if (defined $max and ($max == 0 or $max == -1));
		$warning = negativeValueCheck($warning);
		$critical = negativeValueCheck($critical);
		$min = negativeValueCheck($min);
		$max = negativeValueCheck($max);

		$warning = ''		if (!defined $warning and (defined $critical or defined $min or defined $max));
		$critical = ''		if (!defined $critical and (defined $min or defined $max));
		$min = ''		if (!defined $min and defined $max);

		my $unit = "Watt";
		$unit = "Btu/h" if ($PSConsumptionBTUH);

		$performanceData .= " PowerConsumption=$current" . $unit;
		$performanceData .= ";$warning" if (defined $warning);
		$performanceData .= ";$critical" if (defined $critical);
		$performanceData .= ";$min" if (defined $min);
		$performanceData .= ";$max" if (defined $max);
	}
  } #addPowerConsumptionToPerfdata

  sub addPercentageToPerfdata {
	my $name = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;

	return if (!defined $current and !defined $warning and !defined $critical);
	$current = 0 if ($current and $current == 4294967295);
	$warning = 0 if ($warning and $warning == 4294967295);
	$critical = 0 if ($critical and $critical == 4294967295);

	$performanceData .= ' ' . $name if ($name);
	$performanceData .= '=' . $current . '%' if (defined $current);
	$performanceData .= ';' if ($warning or $critical);
	$performanceData .= "$warning" if ($warning);
	$performanceData .= ';' if ($critical);
	$performanceData .= "$critical" if ($critical);
  } #addPercentageToPerfdata

  sub addKBsecToPerfdata {
	my $name = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;

	$performanceData .= ' ' . $name if ($name);
	$performanceData .= '=' . $current . 'KB/sec' if (defined $current);
	$performanceData .= ';' if ($warning or $critical);
	$performanceData .= "$warning" if ($warning);
	$performanceData .= ';' if ($critical);
	$performanceData .= "$critical" if ($critical);
  } #addKBsecToPerfdata

  sub addRpmToPerfdata {
	my $name = shift;
	my $speed = shift;
	my $warning = shift;
	my $critical = shift;
	$speed = undef if (defined $speed and $speed == -1);
	return if (!$name or !defined $speed);
	$performanceData .= ' ' . $name . '=' . $speed . 'rpm' if (defined $speed);
	$performanceData .= ';' if ($warning or $critical);
	$performanceData .= "$warning" if ($warning);
	$performanceData .= ';' if ($critical);
	$performanceData .= "$critical" if ($critical);
  }
#----------- output format functions
sub addMessage {
	my $container = shift;
	my $string = "@_";
	$string =~ s/\x00(.)/$1/g;
	if ($string) {
		$msg .= $string				if ($container =~ m/.*m.*/);
		$notifyMessage .= $string		if ($container =~ m/.*n.*/);
		$longMessage .= $string			if ($container =~ m/.*l.*/);
		$variableVerboseMessage .= $string	if ($container =~ m/.*v.*/);
	}
}

sub addTopicInLine {
	my $container = shift;
	my $topic = shift;
	my $tmp = '';
	return if (!$topic);
	$tmp .= " - $topic:";
	addMessage($container, $tmp);
}

sub addComponentStatus {
	my $container = shift;
	my $comp = shift;
	my $status = shift;
	my $tmp = '';
	$tmp .= " $comp($status)" if ($comp and defined $status);
	addMessage($container, $tmp);
}

sub addTopicStatusCount {
	my $container = shift;
	my $topic = shift;
	my $tmp = '';
	return if (!$topic);
	$tmp .= " $topic";
	addMessage($container, $tmp);
}

sub addStatusCount {
	my $container = shift;
	my $status = shift;
	my $count = shift;
	my $tmp = '';
	return if (!$status or !$count);
	$tmp .= "-$status($count)";
	addMessage($container, $tmp);
}

sub addStatusTopic {
	my $container = shift;
	my $status = shift;
	my $topic = shift;
	my $index = shift;
	my $tmp = '';
	$tmp .= "$status:" if (defined $status);
	$tmp .= " " if (defined $status and ($topic or $index));
	$tmp .= "$topic" if ($topic);
	$tmp .= "[$index]" if (defined $index);
	$tmp .= " -" if (!defined $status and ($topic or $index));
	addMessage($container,$tmp);
}

sub addTableHeader {
	my $container = shift;
	my $header = shift;
	my $tmp = '';
	$tmp .= "* $header:\n" if ($header);
	addMessage($container,$tmp);
}

sub addKeyValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= " $key=$value" if ($value);
	addMessage($container, $tmp);
}

sub addKeyLongValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= " $key=\"$value\"" if ($value);
	addMessage($container, $tmp);
}

sub addKeyIntValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= " $key=$value" if (defined $value);
	addMessage($container, $tmp);
}

sub addKeyUnsignedIntValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= " $key=..undef.." if (!defined $value and $main::verbose > 9);
	$value = undef if (defined $value and $value < 0);
	$tmp .= " $key=$value" if (defined $value);
	addMessage($container, $tmp);
}

sub addKeyValueUnit {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $addon = shift;
	my $tmp = '';
	if ($value) {
		$tmp .= " $key=$value";
		$tmp .= "$addon";
		addMessage($container, $tmp);
	}
}

sub addKeyIntValueUnit {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $addon = shift;
	my $tmp = '';
	if (defined $value) {
		$tmp .= " $key=$value";
		$tmp .= "$addon";
		addMessage($container, $tmp);
	}
}

#
sub addKeyPercent {
	my $container = shift;
	my $key = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	$current = 0 if ($current and $current == 4294967295);
	$warning = 0 if ($warning and $warning == 4294967295);
	$critical = 0 if ($critical and $critical == 4294967295);
	$min = 0 if ($min and $min == 4294967295);
	$max = 0 if ($max and $max == 4294967295);
	$tmp .= " $key=$current" . "%" if (defined $current and $current != -1);
	$tmp .= " Warning=$warning" . "%" if (defined $warning and $warning != -1);
	$tmp .= " Critical=$critical" . "%" if (defined $critical and $critical != -1);
	$tmp .= " Min=$min" . "%" if (defined $min and $min != -1);
	$tmp .= " Max=$max" . "%" if (defined $max and $max != -1);
	addMessage($container, $tmp);
}

sub addKeyMB {
	my $container = shift;
	my $key = shift;
	my $mbytes = shift;
	my $tmp = '';
	$mbytes = undef if (defined $mbytes and $mbytes < 0);
	$tmp .= " $key=$mbytes" . "MB" if (defined $mbytes);
	addMessage($container, $tmp);
}

#
sub addSerialIDs {
	my $container = shift;
	my $id = shift;
	my $id2 = shift;
	my $tmp = '';
	if ((defined $id) && ($id =~ m/00000000000/)) {
		$id = undef;
	}
	if ((defined $id) && ($id =~ m/0xffffffff/)) {
		$id = undef;
	}
	$id = "\"" . $id . "\"" if ($id and $id =~ m/\s/);
	$id = "" if (!$id and $container =~ m/.*m.*/);
	$tmp .= " ID=$id" if ($id);
	$tmp .= " ID2=$id2" if ($id2);
	addMessage($container, $tmp);
}

sub addLocationContact {
	my $container = shift;
	my $location = shift;
	my $contact = shift;
	my $tmp = '';
	$location = undef if(defined $location and $location eq '');
	$contact = undef if(defined $contact and $contact eq '');
	$tmp .= " Location=\"$location\"" if ($location);
	$tmp .= " Contact=\"$contact\"" if ($contact);
	addMessage($container, $tmp);
}

sub addAdminURL {
	my $container = shift;
	my $admURL = shift;
	my $tmp = '';
	$admURL = undef if ($admURL and ($admURL !~ m/http/));
	$admURL = undef if ($admURL and ($admURL =~ m/0\.0\.0\.0/));
	$admURL = undef if ($admURL and ($admURL =~ m/255\.255\.255\.255/));
	$admURL = undef if ($admURL and ($admURL =~ m/\/\/127\./));
	$tmp .= " AdminURL=$admURL" if ($admURL);
	addMessage($container, $tmp);
}

sub addIP {
	my $container = shift;
	my $ip = shift;
	my $tmp = '';
	$ip = undef if (($ip) and ($ip =~ m/0\.0\.0\.0/));
	$ip = undef if (($ip) and ($ip =~ m/::/));

	$tmp .= " IP=$ip" if ($ip);
	addMessage($container, $tmp);
}

sub addProductModel {
	my $container = shift;
	my $product = shift;
	my $model = shift;
	my $tmp = '';
	if ((defined $product) 
	&& ($product =~ m/0xffffffff/)
	) {
		$product = undef;
	}
	if ($container =~ m/.*n.*/ and defined $product and $skipInternalNamesForNotifies
	and ($product =~ m/^D\d{4}$/)
	) {
		$product = undef;
	}
	if ((defined $model) 
	&& ($model =~ m/0xfffffff/)) {
		$model = undef;
	}
	if ($container =~ m/.*n.*/ and defined $model and $skipInternalNamesForNotifies
	and ($model =~ m/A3C\d{8}/)) {
		$model = undef;
	}
	$tmp .= " Product=\"$product\"" if ($product);
	$tmp .= " Model=\"$model\"" if ($model);
	addMessage($container, $tmp);
}

sub addName {
	my $container = shift;
	my $name = shift;
	my $tmp = '';
	$name = undef if (defined $name and $name eq '');
	$name = "\"$name\"" if ($name and $name =~ m/.* .*/);
	$tmp .= " Name=$name" if ($name);
	addMessage($container,$tmp);
}

sub addHostName {
	my $container = shift;
	my $hostname = shift;
	my $tmp = '';
	$tmp .= " Hostname=$hostname" if ($hostname);
	addMessage($container,$tmp);
}

our $internBeautifyMAC = 1;
sub addMAC { #1.20
	my $container = shift;
	my $mac = shift;
	my $tmp = '';
	$mac = undef if (!$mac);
	if (defined $mac and $mac and $mac =~ m/[^\w:]/) {
		my $newMac = utf8tohex(6,$mac);
		$mac = $newMac if ($newMac);
	}
	if ($internBeautifyMAC and defined $mac and $mac and $mac !~ m/[:]/) {
		$mac =~ tr/a-f/A-F/ if ($mac =~ m/^0x/); # ... all to UPPER case
		$mac =~ s/0x//;		# ... remove prefix 0x
		$mac =~ s/(..)/$1:/g;	# ... add : inside
		$mac =~ s/:$//;		# ... remove last :
	}
	$tmp .= " MAC=$mac" if ($mac);
	addMessage($container,$tmp);
}

sub addSlotID {
	my $container = shift;
	my $slot = shift;
	my $tmp = '';
	$tmp .= " Slot=$slot" if (defined $slot);
	addMessage($container,$tmp);
}

  sub addCelsius {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $tmp = '';
	my $suf = undef;
	$suf .= "\xc2\xb0" if ($useDegree);
	$suf .= "C";
	if ($current) {
		$tmp .= " Temperature=$current" . $suf;
		$tmp .= " Warning=$warning" . $suf if (defined $warning and $warning !~ m/:/);
		$tmp .= " Critical=$critical" . $suf if (defined $critical and $critical !~ m/:/);
		$tmp .= " WarningRange=$warning" . $suf if (defined $warning and $warning =~ m/:/);
		$tmp .= " CriticalRange=$critical" . $suf if (defined $critical and $critical =~ m/:/);
	}
	addMessage($container,$tmp);
  }

sub addmVolt {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	$current = negativeValueCheck($current);
	$warning = negativeValueCheck($warning);
	$critical = negativeValueCheck($critical);
	$min = negativeValueCheck($min);
	$max = negativeValueCheck($max);
	$tmp .= " Current=$current" . "mV" if (defined $current and $current != -1);
	$tmp .= " Warning=$warning" . "mV" if (defined $warning and $warning != -1);
	$tmp .= " Critical=$critical" . "mV" if (defined $critical and $critical != -1);
	$tmp .= " Min=$min" . "mV" if (defined $min and $min != -1);
	$tmp .= " Max=$max" . "mV" if (defined $max and $max != -1);
	addMessage($container,$tmp);
}

sub addVolt {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	$current = negativeValueCheck($current);
	$warning = negativeValueCheck($warning);
	$critical = negativeValueCheck($critical);
	$min = negativeValueCheck($min);
	$max = negativeValueCheck($max);
	$tmp .= " Current=$current" . "V" if (defined $current and $current != -1);
	$tmp .= " Warning=$warning" . "V" if (defined $warning and $warning != -1);
	$tmp .= " Critical=$critical" . "V" if (defined $critical and $critical != -1);
	$tmp .= " Min=$min" . "V" if (defined $min and $min != -1);
	$tmp .= " Max=$max" . "V" if (defined $max and $max != -1);
	addMessage($container,$tmp);
}

sub addKeyRpm {
	my $container = shift;
	my $key = shift;
	my $speed = shift;
	my $tmp = '';
	$speed = undef if (defined $speed and $speed == -1);
	$tmp .= " $key=$speed" . "rpm" if ($speed);
	addMessage($container,$tmp);
}

sub addKeyMHz {
	my $container = shift;
	my $key = shift;
	my $speed = shift;
	my $tmp = '';
	$speed = undef if (defined $speed and $speed == -1);
	$tmp .= " $key=$speed" . "MHz" if ($speed);
	addMessage($container,$tmp);
}

sub addKeyGB {
	my $container = shift;
	my $key = shift;
	my $gbytes = shift;
	my $tmp = '';
	$gbytes = undef if (defined $gbytes and $gbytes < 0);
	$tmp .= " $key=$gbytes" . "GB" if (defined $gbytes);
	addMessage($container,$tmp);
}

sub addKeyWatt {
	my $container = shift;
	my $key = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	my $unit = "Watt";
	$unit = "Btu/h" if ($PSConsumptionBTUH);
	$tmp .= " $key=$current" . $unit if ($current and $current != -1);
	$tmp .= " Warning=$warning" . $unit if ($warning and $warning != -1);
	$tmp .= " Critical=$critical" . $unit if ($critical and $critical != -1);
	$tmp .= " Min=$min" . $unit if ($min and $min != -1);
	$tmp .= " Max=$max" . $unit if ($max and $max != -1);
	addMessage($container,$tmp);
}

  sub addKeyThresholdsUnit { # container, first-named-key, unit-string and than all thresholds 
	my $container = shift;
	my $key = shift;
	my $unit = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	$unit = '???' if (!defined $unit);
	$current = negativeValueCheck($current);
	$warning = negativeValueCheck($warning);
	$critical = negativeValueCheck($critical);
	$min = negativeValueCheck($min);
	$max = negativeValueCheck($max);
	if (defined $current) {
		$tmp .= " $key=$current" . $unit if (defined $current);
		$tmp .= " Warning=$warning" . $unit if (defined $warning);
		$tmp .= " Critical=$critical" . $unit if (defined $critical);
		$tmp .= " Min=$min" . $unit if (defined $min);
		$tmp .= " Max=$max" . $unit if (defined $max);
		addMessage($container, $tmp);
	}
  } #addKeyThresholdsUnit

#### CIM helper functions
  sub healthStateString {
	my $healthState = shift;
	my @healthStateText = ( "unknown", 
		"ok", "degraded", "minorfailure", "majorfailure", "criticalfailure",
		"nonrecoverableerror", "..undefined..",
	);
	return "..undefined.." if (!defined $healthState);
	return $healthStateText[7] if ($healthState % 5 or $healthState < 0 or $healthState > 30);
	my $newState = $healthState / 5;
	return $healthStateText[$newState];
  } #healthStateString

  sub healthStateExitCode {
	my $healthState = shift;
	return 3 if (!defined $healthState);
	return 3 if ($healthState % 5 or $healthState < 0 or $healthState > 30);
	my $newState = $healthState / 5;
	return 3 if (!$newState);
	return 2 if ($newState > 3);
	return 1 if ($newState > 1);
	return 0;
  } #healthStateExitCode

  sub currentStateHealthState {
	my $currentState = shift;
  	return 0 if (!$currentState);
	return 5 if ($currentState eq "Normal");
	return 10 if ($currentState eq "Non-Critical");
	return 10 if ($currentState eq "Upper Non-Critical");
	return 20 if ($currentState eq "Critical");
	return 20 if ($currentState eq "Upper Critical");
	return 20 if ($currentState eq "Lower Critical");
	return 0 if ($currentState eq "Unknown");
	return 0 if ($currentState eq "Not Applicable");
	return 0;
} # currentStateHealthState

=begin COMMENT
  sub currentStateExitCode { #UNUSED
	my $currentState = shift;
	return 3 if (!$currentState);
	return 0 if ($currentState eq "Normal");
	return 1 if ($currentState eq "Non-Critical");
	return 1 if ($currentState eq "Upper Non-Critical");
	return 2 if ($currentState eq "Critical");
	return 2 if ($currentState eq "Upper Critical");
	return 2 if ($currentState eq "Lower Critical");
	return 3 if ($currentState eq "Unknown");
	return 3 if ($currentState eq "Not Applicable");
	return 3;
  } # currentStateExitCode
=end COMMENT
=cut

  sub memoryTypeString {
	my $memtype = shift;
	return undef if (!defined $memtype);

	# http://schemas.dmtf.org/wbem/cim-html/2.41.0/CIM_MemoryCapacity.html
	my @memTypeStrings = ( "Unknown",
	    "Other", "DRAM", "Synchronous DRAM", "Cache DRAM", "EDO", 
	    "EDRAM", "VRAM", "SRAM", "RAM", "ROM", 
	    "Flash", "EEPROM", "FEPROM", "EPROM", "CDRAM", 
	    "3DRAM", "SDRAM", "SGRAM", "RDRAM", "DDR", 
	    "DDR-2", "BRAM", "FB-DIMM", "DDR3", "FBD2", 
	    "DDR4", "LPDDR", "LPDDR2", "LPDDR3", "LPDDR4",
	    "..undefined..",
	);
	# "31..32567" -> DMTF
	# "32568..65535"  -> VENDOR
	if ($memtype > 32568) {
	    my $out = "VENDOR" . $memtype;
	    return $out;
	}
	if ($memtype > 31) {
	    my $out = "DMTF" . $memtype;
	    return $out;
	}
	if ($memtype < 0) {
	    return "..undefined..";
	}
	return $memTypeStrings[$memtype];
  } #memoryTypeString

  sub osString {
	my $osType = shift;
	my $osVersion = shift;
	return undef if (!defined $osType);

	# http://schemas.dmtf.org/wbem/cim-html/2.34.0/CIM_OperatingSystem.html
	# http://schemas.dmtf.org/wbem/cim-html/2.41.0/CIM_OperatingSystem.html
	my @osTypeStrings = ( 
		"Unknown", "Other", "MACOS", "ATTUNIX", "DGUX", 
		"DECNT", "Tru64 UNIX", "OpenVMS", "HPUX", "AIX",
		"MVS", "OS400", "OS/2", "JavaVM", "MSDOS", 
		"WIN3x", "WIN95", "WIN98", "WINNT", "WINCE", 
		"NCR3000", "NetWare", "OSF", "DC/OS", "Reliant UNIX", 
		"SCO UnixWare", "SCO OpenServer", "Sequent", "IRIX", "Solaris", 
		"SunOS", "U6000", "ASERIES", "HP NonStop OS", "HP NonStop OSS", 
		"BS2000", "LINUX", "Lynx", "XENIX", "VM", 
		"Interactive UNIX", "BSDUNIX", "FreeBSD", "NetBSD", "GNU Hurd", 
		"OS9", "MACH Kernel", "Inferno", "QNX", "EPOC", 
		"IxWorks", "VxWorks", "MiNT", "BeOS", "HP MPE", 
		"NextStep", "PalmPilot", "Rhapsody", "Windows 2000", "Dedicated", 
		"OS/390", "VSE", "TPF", "Windows (R) Me", "Caldera Open UNIX", 
		"OpenBSD", "Not Applicable", "Windows XP", "z/OS", "Microsoft Windows Server 2003",
		"Microsoft Windows Server 2003 64-Bit", "Windows XP 64-Bit", "Windows XP Embedded", "Windows Vista", "Windows Vista 64-Bit", 
		"Windows Embedded for Point of Service", "Microsoft Windows Server 2008", "Microsoft Windows Server 2008 64-Bit", "FreeBSD 64-Bit", "RedHat Enterprise Linux", 
		"RedHat Enterprise Linux 64-Bit", "Solaris 64-Bit", "SUSE", "SUSE 64-Bit", "SLES", 
		"SLES 64-Bit", "Novell OES", "Novell Linux Desktop", "Sun Java Desktop System", "Mandriva",	   
		"Mandriva 64-Bit", "TurboLinux", "TurboLinux 64-Bit", "Ubuntu", "Ubuntu 64-Bit", 
		"Debian", "Debian 64-Bit", "Linux 2.4.x", "Linux 2.4.x 64-Bit", "Linux 2.6.x",
		"Linux 2.6.x 64-Bit", "Linux 64-Bit", "Other 64-Bit", "Microsoft Windows Server 2008 R2", "VMware ESXi", 
		"Microsoft Windows 7", "CentOS 32-bit", "CentOS 64-bit", "Oracle Linux 32-bit", "Oracle Linux 64-bit",  
		"eComStation 32-bitx", "Microsoft Windows Server 2011",	"Microsoft Windows Server 2012", "Microsoft Windows 8", "Microsoft Windows 8 64-bit",
		"Microsoft Windows Server 2012 R2", 
	    	"..undefined..",
	);

	if ($osType < 0 || $osType > 115) {
	    return "..undefined..";
	}

	my $out = $osTypeStrings[$osType];
	$out = $out . " " . $osVersion if ($osVersion && $osVersion ne '');

	# print "osString: osType = $osType, out = $out\n";

	return $out;
  } #osString

  sub cpuModelString {
	my $cpuModel = shift;
	return undef if (!defined $cpuModel);

	my %cpuModelStrings = (
		0 => "..undefined..", 
		1 => "Other", 2 => "Unknown", 3 => "8086", 
		4 => "80286", 5 => "80386", 6 => "80486", 7 => "8087", 
		8 => "80287", 9 => "80387", 10 => "80487", 
		11 => "Pentium(R) brand", 12 => "Pentium(R) Pro", 
		13 => "Pentium(R) II", 
		14 => "Pentium(R) processor with MMX(TM) technology", 
		15 => "Celeron(TM)", 16 => "Pentium(R) II Xeon(TM)", 
		17 => "Pentium(R) III", 
		18 => "M1 Family", 19 => "M2 Family", 
		20 => "Intel(R) Celeron(R) M processor", 
		21 => "Intel(R) Pentium(R) 4 HT processor", 
		22 => "Reserved", 23 => "Reserved", 
		24 => "K5 Family", 25 => "K6 Family", 26 => "K6-2", 
		27 => "K6-3", 28 => "AMD Athlon(TM) Processor Family", 
		29 => "AMD(R) Duron(TM) Processor", 30 => "AMD29000 Family", 
		31 => "K6-2+", 32 => "Power PC Family", 
		33 => "Power PC 601", 34 => "Power PC 603", 
		35 => "Power PC 603+", 36 => "Power PC 604", 
		37 => "Power PC 620", 38 => "Power PC X704", 
		39 => "Power PC 750", 40 => "Intel(R) Core(TM) Duo processor", 
		41 => "Intel(R) Core(TM) Duo mobile processor", 
		42 => "Intel(R) Core(TM) Solo mobile processor", 
		43 => "Intel(R) Atom(TM) processor", 
		44 => "Reserved", 45 => "Reserved", 46 => "Reserved", 
		47 => "Reserved", 
		48 => "Alpha Family", 49 => "Alpha 21064", 50 => "Alpha 21066", 
		51 => "Alpha 21164", 52 => "Alpha 21164PC", 
		53 => "Alpha 21164a", 54 => "Alpha 21264", 55 => "Alpha 21364", 
		56 => "AMD Turion(TM) II Ultra Dual-Core Mobile M Processor Family", 
		57 => "AMD Turion(TM) II Dual-Core Mobile M Processor Family", 
		58 => "AMD Athlon(TM) II Dual-Core Mobile M Processor Family", 
		59 => "AMD Opteron(TM) 6100 Series Processor", 
		60 => "AMD Opteron(TM) 4100 Series Processor", 
		61 => "AMD Opteron(TM) 6200 Series Processor", 
		62 => "AMD Opteron(TM) 4200 Series Processor", 
		63 => "AMD FX(TM) Series Processor", 64 => "MIPS Family", 
		65 => "MIPS R4000", 
		66 => "MIPS R4200", 67 => "MIPS R4400", 68 => "MIPS R4600", 
		69 => "MIPS R10000", 
		70 => "AMD C-Series Processor", 71 => "AMD E-Series Processor", 
		72 => "AMD A-Series Processor", 73 => "AMD G-Series Processor", 
		74 => "AMD Z-Series Processor", 
		75 => "Reserved", 76 => "Reserved",
		77 => "Reserved", 78 => "Reserved", 79 => "Reserved", 
		80 => "SPARC Family", 81 => "SuperSPARC", 
		82 => "microSPARC II", 83 => "microSPARC IIep", 
		84 => "UltraSPARC", 85 => "UltraSPARC II", 
		86 => "UltraSPARC IIi", 
		87 => "UltraSPARC III", 88 => "UltraSPARC IIIi", 
		89 => "Reserved", 90 => "Reserved", 91 => "Reserved", 
		92 => "Reserved", 93 => "Reserved", 94 => "Reserved", 
		95 => "Reserved", 
		96 => "68040", 97 => "68xxx Family", 98 => "68000", 
		99 => "68010", 100 => "68020", 101 => "68030", 
		102 => "Reserved", 103 => "Reserved", 104 => "Reserved", 
		105 => "Reserved", 106 => "Reserved", 107 => "Reserved", 
		108 => "Reserved", 109 => "Reserved", 110 => "Reserved", 
		111 => "Reserved", 
		112 => "Hobbit Family", 
		113 => "Reserved", 114 => "Reserved", 115 => "Reserved", 
		116 => "Reserved", 117 => "Reserved", 118 => "Reserved", 
		119 => "Reserved", 
		120 => "Crusoe(TM) TM5000 Family", 
		121 => "Crusoe(TM) TM3000 Family", 
		122 => "Efficeon(TM) TM8000 Family", 
		123 => "Reserved", 124 => "Reserved", 125 => "Reserved", 
		126 => "Reserved", 127 => "Reserved", 
		128 => "Weitek", 129 => "Reserved", 
		130 => "Itanium(TM) Processor", 
		131 => "AMD Athlon(TM) 64 Processor Family", 
		132 => "AMD Opteron(TM) Processor Family", 
		133 => "AMD Sempron(TM) Processor Family", 
		134 => "AMD Turion(TM) 64 Mobile Technology", 
		135 => "Dual-Core AMD Opteron(TM) Processor Family", 
		136 => "AMD Athlon(TM) 64 X2 Dual-Core Processor Family", 
		137 => "AMD Turion(TM) 64 X2 Mobile Technology", 
		138 => "Quad-Core AMD Opteron(TM) Processor Family", 
		139 => "Third-Generation AMD Opteron(TM) Processor Family", 
		140 => "AMD Phenom(TM) FX Quad-Core Processor Family", 
		141 => "AMD Phenom(TM) X4 Quad-Core Processor Family", 
		142 => "AMD Phenom(TM) X2 Dual-Core Processor Family", 
		143 => "AMD Athlon(TM) X2 Dual-Core Processor Family", 
		144 => "PA-RISC Family", 145 => "PA-RISC 8500", 
		146 => "PA-RISC 8000", 
		147 => "PA-RISC 7300LC", 148 => "PA-RISC 7200", 
		149 => "PA-RISC 7100LC", 150 => "PA-RISC 7100", 
		151 => "Reserved", 152 => "Reserved", 153 => "Reserved", 
		154 => "Reserved", 155 => "Reserved", 156 => "Reserved", 
		157 => "Reserved", 158 => "Reserved", 159 => "Reserved", 
		160 => "V30 Family", 
		161 => "Quad-Core Intel(R) Xeon(R) processor 3200 Series", 
		162 => "Dual-Core Intel(R) Xeon(R) processor 3000 Series", 
		163 => "Quad-Core Intel(R) Xeon(R) processor 5300 Series", 
		164 => "Dual-Core Intel(R) Xeon(R) processor 5100 Series", 
		165 => "Dual-Core Intel(R) Xeon(R) processor 5000 Series", 
		166 => "Dual-Core Intel(R) Xeon(R) processor LV", 
		167 => "Dual-Core Intel(R) Xeon(R) processor ULV", 
		168 => "Dual-Core Intel(R) Xeon(R) processor 7100 Series", 
		169 => "Quad-Core Intel(R) Xeon(R) processor 5400 Series", 
		170 => "Quad-Core Intel(R) Xeon(R) processor", 
		171 => "Dual-Core Intel(R) Xeon(R) processor 5200 Series", 
		172 => "Dual-Core Intel(R) Xeon(R) processor 7200 Series", 
		173 => "Quad-Core Intel(R) Xeon(R) processor 7300 Series", 
		174 => "Quad-Core Intel(R) Xeon(R) processor 7400 Series", 
		175 => "Multi-Core Intel(R) Xeon(R) processor 7400 Series", 
		176 => "Pentium(R) III Xeon(TM)", 
		177 => "Pentium(R) III Processor with Intel(R) SpeedStep(TM) Technology", 
		178 => "Pentium(R) 4", 179 => "Intel(R) Xeon(TM)", 
		180 => "AS400 Family", 181 => "Intel(R) Xeon(TM) processor MP", 
		182 => "AMD Athlon(TM) XP Family", 
		183 => "AMD Athlon(TM) MP Family", 
		184 => "Intel(R) Itanium(R) 2", 
		185 => "Intel(R) Pentium(R) M processor", 
		186 => "Intel(R) Celeron(R) D processor", 
		187 => "Intel(R) Pentium(R) D processor", 
		188 => "Intel(R) Pentium(R) Processor Extreme Edition", 
		189 => "Intel(R) Core(TM) Solo Processor", 190 => "K7", 
		191 => "Intel(R) Core(TM)2 Duo Processor", 
		192 => "Intel(R) Core(TM)2 Solo processor", 
		193 => "Intel(R) Core(TM)2 Extreme processor", 
		194 => "Intel(R) Core(TM)2 Quad processor", 
		195 => "Intel(R) Core(TM)2 Extreme mobile processor", 
		196 => "Intel(R) Core(TM)2 Duo mobile processor", 
		197 => "Intel(R) Core(TM)2 Solo mobile processor", 
		198 => "Intel(R) Core(TM) i7 processor", 
		199 => "Dual-Core Intel(R) Celeron(R) Processor", 
		200 => "S/390 and zSeries Family", 201 => "ESA/390 G4", 
		202 => "ESA/390 G5", 203 => "ESA/390 G6", 
		204 => "z/Architectur base", 
		205 => "Intel(R) Core(TM) i5 processor", 
		206 => "Intel(R) Core(TM) i3 processor", 
		207 => "Reserved", 208 => "Reserved", 209 => "Reserved", 
		210 => "VIA C7(TM)-M Processor Family", 
		211 => "VIA C7(TM)-D Processor Family", 
		212 => "VIA C7(TM) Processor Family", 
		213 => "VIA Eden(TM) Processor Family", 
		214 => "Multi-Core Intel(R) Xeon(R) processor", 
		215 => "Dual-Core Intel(R) Xeon(R) processor 3xxx Series", 
		216 => "Quad-Core Intel(R) Xeon(R) processor 3xxx Series", 
		217 => "VIA Nano(TM) Processor Family", 
		218 => "Dual-Core Intel(R) Xeon(R) processor 5xxx Series", 
		219 => "Quad-Core Intel(R) Xeon(R) processor 5xxx Series", 
		220 => "Reserved", 
		221 => "Dual-Core Intel(R) Xeon(R) processor 7xxx Series", 
		222 => "Quad-Core Intel(R) Xeon(R) processor 7xxx Series", 
		223 => "Multi-Core Intel(R) Xeon(R) processor 7xxx Series", 
		224 => "Multi-Core Intel(R) Xeon(R) processor 3400 Series", 
		225 => "Reserved", 226 => "Reserved", 227 => "Reserved", 
		228 => "AMD Opteron(TM) 3000 Series Processor", 
		229 => "AMD Sempron(TM) II Processor Family", 
		230 => "Embedded AMD Opteron(TM) Quad-Core Processor Family", 
		231 => "AMD Phenom(TM) Triple-Core Processor Family", 
		232 => "AMD Turion(TM) Ultra Dual-Core Mobile Processor Family", 
		233 => "AMD Turion(TM) Dual-Core Mobile Processor Family", 
		234 => "AMD Athlon(TM) Dual-Core Processor Family", 
		235 => "AMD Sempron(TM) SI Processor Family", 
		236 => "AMD Phenom(TM) II Processor Family", 
		237 => "AMD Athlon(TM) II Processor Family", 
		238 => "Six-Core AMD Opteron(TM) Processor Family", 
		239 => "AMD Sempron(TM) M Processor Family", 
		240 => "Reserved", 241 => "Reserved", 242 => "Reserved", 
		243 => "Reserved", 244 => "Reserved", 245 => "Reserved", 
		246 => "Reserved", 247 => "Reserved", 248 => "Reserved", 
		249 => "Reserved", 
		250 => "i860", 251 => "i960", 
		252 => "Reserved", 253 => "Reserved", 
		254 => "Reserved (SMBIOS Extension)", 
		255 => "Reserved (Un-initialized Flash Content - Lo)", 
		256 => "Reserved", 257 => "Reserved", 
		258 => "Reserved", 259 => "Reserved", 
		260 => "SH-3", 261 => "SH-4", 
		262 => "Reserved", 263 => "Reserved", 264 => "Reserved", 
		265 => "Reserved", 266 => "Reserved", 267 => "Reserved", 
		268 => "Reserved", 269 => "Reserved", 270 => "Reserved", 
		271 => "Reserved", 272 => "Reserved", 273 => "Reserved", 
		274 => "Reserved", 275 => "Reserved", 276 => "Reserved", 
		277 => "Reserved", 278 => "Reserved", 279 => "Reserved", 
		280 => "ARM", 281 => "StrongARM", 
		282 => "Reserved", 283 => "Reserved", 284 => "Reserved", 
		285 => "Reserved", 286 => "Reserved", 287 => "Reserved", 
		288 => "Reserved", 289 => "Reserved", 290 => "Reserved", 
		291 => "Reserved", 292 => "Reserved", 293 => "Reserved", 
		294 => "Reserved", 295 => "Reserved", 296 => "Reserved", 
		297 => "Reserved", 298 => "Reserved", 299 => "Reserved", 
		300 => "6x86", 301 => "MediaGX", 302 => "MII", 
		303 => "Reserved", 304 => "Reserved", 305 => "Reserved", 
		306 => "Reserved", 307 => "Reserved", 308 => "Reserved", 
		309 => "Reserved", 310 => "Reserved", 311 => "Reserved", 
		312 => "Reserved", 313 => "Reserved", 314 => "Reserved", 
		315 => "Reserved", 316 => "Reserved", 317 => "Reserved", 
		318 => "Reserved", 319 => "Reserved", 
		320 => "WinChip", 
		321 => "Reserved", 322 => "Reserved", 323 => "Reserved", 
		324 => "Reserved", 325 => "Reserved", 326 => "Reserved", 
		327 => "Reserved", 328 => "Reserved", 329 => "Reserved", 
		330 => "Reserved", 331 => "Reserved", 332 => "Reserved", 
		333 => "Reserved", 334 => "Reserved", 335 => "Reserved", 
		336 => "Reserved", 337 => "Reserved", 338 => "Reserved", 
		339 => "Reserved", 340 => "Reserved", 341 => "Reserved", 
		342 => "Reserved", 343 => "Reserved", 344 => "Reserved", 
		345 => "Reserved", 346 => "Reserved", 347 => "Reserved", 
		348 => "Reserved", 349 => "Reserved", 
		350 => "DSP", 
		351 => "Reserved", 	
		500 => "Video Processor", 
		501 => "Reserved", 
		65534 => "Reserved (For Future Special Purpose Assignment)", 
		65535 => "Reserved (Un-initialized Flash Content - Hi)");


	# "351..499"    -> Reserved
	# "501..65533"  -> Reserved
	if ( ($cpuModel >= 351 && $cpuModel <= 499) ||
		($cpuModel >= 501 && $cpuModel <= 65533) ) {
	    my $out = "Reserved";
	    return $out;
	}
	if ($cpuModel < 0 || $cpuModel > 65535) {
	    return "..undefined..";
	}
	return $cpuModelStrings{$cpuModel};
  } #cpuModelString

  sub esxiSubSystemStatusString {
	my $subState = shift;
	my @subStateText = ( "notdefined", 
		"ok", "degraded", "error", "failed", "unknown",
		"..undefined..",
	);
	return $subStateText[6] if (!defined $subState);
	return $subStateText[6] if ($subState < 0 or $subState > 5);
	return $subStateText[$subState];
  } # esxiSubSystemStatusString

  sub esxiSubSystemStatusExitCode {
  	my $subState = shift;
	return 3 if (!defined $subState);
	return 3 if ($subState < 0 or $subState > 5);
	return 3 if (!$subState or $subState >4);
	return 2 if ($subState > 2);
	return 1 if ($subState > 1);
	return 0;
} # esxiSubSystemStatusExitCode

# # # # #

  sub baseUnits2String {
	my $baseUnits = shift;
	my $unitModifier = shift;
	#---- http://schemas.dmtf.org/wbem/cim-html/2.36.0/CIM_NumericSensor.html
	return undef if (!defined $baseUnits or $baseUnits <= 1 or $baseUnits > 66);
	my @baseText = ( undef,
		"???", "C", "F", "K", "V", 
	 	"Amp", "Watt", "Joules", "Coulombs", "VA", 
	 	"Nits", "Lumens", "Lux", "Candelas", "kPa", 
	 	"PSI", "Newtons", "CFM", "rpm", "Hzt", 
	 	"sec", "min", "h", "d", "Weeks", 
	 	"Mils", "Inches", "Feet", "CubicInches", "CubicFeet", 
	 	"m", "CubicCentimeters", "CubicMeters", "L", "FluidOunces", 
	 	"Radians", "Steradians", "Revolutions", "Cycles", "Gravities", 
	 	"Ounces", "Pounds2", "Foot-Pounds", "Ounce-Inches", "Gauss", 
	 	"Gilberts", "Henries", "Farad", "Ohm", "Siemens", 
	 	"Moles", "Becquerels", "PPM", "Decibels", "DbA", 
	 	"DbC", "Grays", "Sieverts", "Color-Temperature-Degrees-K", "Bits", 
	 	"B", "Word", "DoubleWord", "QuadWord", "%", 
	 	"Pascal", "..undefined..",
	);
	return undef if ($baseUnits > 4); # now
	return $baseText[$baseUnits] if ($baseUnits <=4 and $unitModifier == 0); # Temperatures
	return undef;
	#---- ValueMap	
	#---- string	0, 
	#---- 	1, 2, 3, 4, 5, 
	#---- 	6, 7, 8, 9, 10, 
	#---- 	11, 12, 13, 14, 15, 
	#---- 	16, 17, 18, 19, 20, 
	#---- 	21, 22, 23, 24, 25, 
	#---- 	26, 27, 28, 29, 30, 
	#---- 	31, 32, 33, 34, 35, 
	#---- 	36, 37, 38, 39, 40, 
	#---- 	41, 42, 43, 44, 45, 
	#---- 	46, 47, 48, 49, 50, 
	#---- 	51, 52, 53, 54, 55, 
	#---- 	56, 57, 58, 59, 60, 
	#---- 	61, 62, 63, 64, 65, 
	#---- 	66
	#---- Values	
	#---- string	Unknown, 
	#---- 	Other, Degrees C, Degrees F, Degrees K, Volts, 
	#---- 	Amps, Watts, Joules, Coulombs, VA, 
	#---- 	Nits, Lumens, Lux, Candelas, kPa, 
	#---- 	PSI, Newtons, CFM, RPM, Hertz, 
	#---- 	Seconds, Minutes, Hours, Days, Weeks, 
	#---- 	Mils, Inches, Feet, Cubic Inches, Cubic Feet, 
	#---- 	Meters, Cubic Centimeters, Cubic Meters, Liters, Fluid Ounces, 
	#---- 	Radians, Steradians, Revolutions, Cycles, Gravities, 
	#---- 	Ounces, Pounds, Foot-Pounds, Ounce-Inches, Gauss, 
	#---- 	Gilberts, Henries, Farads, Ohms, Siemens, 
	#---- 	Moles, Becquerels, PPM (parts/million), Decibels, DbA, 
	#---- 	DbC, Grays, Sieverts, Color Temperature Degrees K, Bits, 
	#---- 	Bytes, Words (data), DoubleWords, QuadWords, Percentage, 
	#---- 	Pascals
	return undef;
  } # baseUnits2String



#### OPTION FUNCTION ######
#
# handleOptions(): get command-line parameters
#
# Options can be set:
#	- as command line options
#	- in filename set for '-I|--inputfile'
#	- in filename set for '-E|--encryptfile'
#
# Each option on command line can be set more than once, the last value
# for such an option is used then. In <filename> options from command line 
# can be set resp. reset. With '-I' all options from command line can be set
# with the exception of '-I' which must not be used within the file again.
# With '-E' only a restricted set of options can be set.
#
# The priority of these options is the following:
#
#    - Options from 'inputfile' overwrite command line options and 
#    - Options from 'encryptfile' overwrite both command line options 
#      and options from 'inputfile'.	
#    - Options from '-E' set in 'inputfile' overwrites '-E' from command line
#
# Option values are stored in 'global variables' which are already defined
# in main script.
#
# Use of options is checked and usage message printed by 'pod2usage' which
# implicitly exits the script, so no return value is necessary to indicate
# success or failure of this function.
#
# HINT for developer: $main::verbose is not set as default
  sub readDataFile {
	my( $fileName ) = shift;

	if (! $fileName) {
		$exitCode = 10;	
		print "readDataFile: no filename \n" if ($main::verbose >= 60);
		return undef;
	}

	print "readDataFile [$fileName] \n" if ($main::verbose >= 60);

	if (! -r $fileName) {
		$exitCode = 11;
		print "readDataFile: [$fileName] not found \n" if ($main::verbose >= 60);
		return undef;
	}
	
	my $fileText = undef;
	open (my $infile, "<", $fileName);
	if (!$infile) {
	    $exitCode = 12;
	    return undef;
	} else {
	    $fileText = join('', <$infile> );
	    close $infile;
	    print "readDataFile: fileText [$fileText]\n" if ($main::verbose >= 60);
	}

	return ( $fileText );
  } #readDataFile

  sub getScriptOpts {	# script specific

	my $stringInput = shift;
	my $inputType = shift;

	my %options = ();

	print "getScriptOpts: stringInput = $stringInput\n" if ($stringInput && $main::verbose >= 60);
	print "getScriptOpts: inputType = $inputType\n" if ($inputType && $main::verbose >= 60);

	if (! $stringInput) {
    		GetOptions(\%options, 
	   		"V|version", 
	   		"h|help", 
	   		"H|host=s", 
		        "A|admin=s", 
	   		"P|port=i", 
	   		"T|transport=s", 
	   		"C|class=s", 
		        "U|use=s",
		       	"S|service=s",	
	   		"t|timeout=i", 
			    "vtab=i",
	   		"v|verbose=i", 
	   		"w|warning=i", 
	   		"c|critical=i", 
			"degree!",

			"chkclass", 
	   		"chkidentify", 
	   		"systeminfo",
			"agentinfo", 
	   		"chksystem", 
	   		"chkenv", 
	   		"chkenv-fan|chkfan|chkcooling", 
	   		"chkenv-temp|chktemp", 
	   		"chkpower", 
	   		"chkhardware|chkboard", 
	   		"chkcpu", 
	   		"chkvoltage", 
	   		"chkmemmodule", 
	   		"chkdrvmonitor", 
	   		"chkstorage", 
			"chkupdate",
	   		"chkfanperf", 

			"difflist",
			"instlist",
			  "O|outputdir=s",

	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
			"adigest",
	   		"I|inputfile=s", 
			"inputdir=s",
		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
	   	#	"E|encryptfile=s",
		#	"encryptdir=s",
	}
	else {
	    if ($inputType && $inputType == 1) {	#inputFile
		# same options as above, but without '-I'

		# @ARGV = split(/\s/,$stringInput);
		require Text::ParseWords;
		my $argsRef = [ Text::ParseWords::shellwords($stringInput)];
		@ARGV = @{$argsRef};

    		#GetOptionsFromString($stringInput, \%options, 
   		GetOptions(\%options, 
	   		"V|version", 
	   		"h|help", 
	   		"H|host=s",
			"A|admin=s", 
	   		"P|port=i", 
	   		"T|transport=s", 
	   		"C|class=s", 
		        "U|use=s",
		       	"S|service=s",	
	   		"t|timeout=i", 
	   		"v|verbose=i", 
	   		"w|warning=i", 
	   		"c|critical=i", 
			"degree!",

	   		"chkidentify", 
	   		"chkclass", 
	   		"systeminfo",
		        "agentinfo",
	   		"chksystem", 
	   		"chkenv", 
	   		"chkenv-fan|chkfan", 
	   		"chkenv-temp|chktemp", 
	   		"chkpower", 
	   		"chkhardware|chkboard", 
	   		"chkcpu", 
	   		"chkvoltage", 
	   		"chkmemmodule", 
	   		"chkdrvmonitor", 
	   		"chkstorage", 
			"chkupdate",
	   		"chkfanperf", 

			"difflist",
			"instlist",
			  "O|outputdir=s",

	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
			"adigest",
		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
	   	#	"E|encryptfile=s"
	    } # type = 1 
=begin COMMENT
	    else {	# encryptFile
		# limited set of options only
  		# @ARGV = split(/\s/,$stringInput);
		require Text::ParseWords;
		my $argsRef = [ Text::ParseWords::shellwords($stringInput)];
		@ARGV = @{$argsRef};

  		GetOptions(\%options, 
	   		"P|port=i", 
	   		"T|transport=s", 
		        "U|use=s",
		       	"S|service=s",	
	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
	    }
=end COMMENT
=cut
	} # inputstring

    	return ( %options );
  } #getScriptOpts

  sub getOptionsFromFile {
	my $filename = shift;
	my $inputType = shift;
	my %options = ();


    	my $infileString = readDataFile( $filename);
	if (defined $infileString) {
		%options = getScriptOpts($infileString, $inputType);

		#foreach my $ent (sort keys %options) {
			#print "getOptionsFromFile: $ent = $options{$ent}\n";
		#}
	}
	else {
		print "+++getOptionsFromFile: no data read from [$filename]" if ($main::verbose >= 60);
	}

    	return ( %options );
  } #getOptionsFromFile

  sub readOptions {

	my %mainOptions;	# command line optiond
	my %ifileOptions;	# -I inputfile options (command line)
	#my %efileOptions;	# -E encryptfile options (command line)
	#my %iefileOptions;	# -E encryptfile options (from -I inputfile)

	#my $mainEncFilename = undef;	# -E encryptfilename from command line
	#my $ifileEncFilename = undef;	# -E encryptfilename from -I inputfile


	#
	# command line options first
	#
	%mainOptions = getScriptOpts();

	my $ibasename = $mainOptions{"I"};
	my $idirname = $mainOptions{"inputdir"};
	
	if ($ibasename) {
		my $chkFileName = "";
		$chkFileName .= $idirname . "/" if ($idirname 
		    and $ibasename and $ibasename !~ m/^\//);
		$chkFileName .= $ibasename;
		$optInputFile = $chkFileName;
		%ifileOptions = getOptionsFromFile($chkFileName, 1);
		if ($exitCode == 10 or $exitCode == 11 or $exitCode == 12 and $chkFileName) {
			pod2usage(
				-msg		=> "\n" . "-I $chkFileName: filename empty !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 10);
			pod2usage(
				-msg		=> "\n" . "-I $chkFileName: file not existing or readable !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 11);
			pod2usage(
				-msg		=> "\n" . "-I $chkFileName: error reading file !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 12);
		}
	} # ibasename
=begin COMMENT
	my $ebasename = $mainOptions{"E"};
	my $edirname = $mainOptions{"encryptdir"};
	if ($ebasename) {
		my $chkFileName = "";
		$chkFileName .= $edirname . "/" if ($edirname);
		$chkFileName .= $ebasename;
		%efileOptions = getOptionsFromFile($chkFileName, 2);
		if ($exitCode == 10 or $exitCode == 11 or $exitCode == 12 and $chkFileName) {
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: filename empty !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 10);
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: file not existing or readable !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 11);
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: error reading file !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 12);
		}
	} # ebasename
=end COMMENT
=cut
=begin COMMENT
	my $iebasename = $ifileOptions{"E"};
	my $iedirname = $ifileOptions{"encryptdir"};
	if ($iebasename) {
		my $chkFileName = "";
		$chkFileName .= $iedirname . "/" if ($iedirname);
		$chkFileName .= $iebasename;
		%iefileOptions = getOptionsFromFile($chkFileName, 2);
		if ($exitCode == 10 or $exitCode == 11 or $exitCode == 12 and $chkFileName) {
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: filename empty !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 10);
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: file not existing or readable !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 11);
			pod2usage(
				-msg		=> "\n" . "-E $chkFileName: error reading file !" . "\n",
				-verbose	=> 0,
				-exitval	=> 3
			) if ($exitCode == 12);
		}
	} # iebasename
=end COMMENT
=cut

=begin COMMENT3
	######### FIRST IMPLEMENTATIONS ... newer ones above
	foreach my $ent (sort keys %mainOptions) {
		print "main: mainOptions: $ent = $mainOptions{$ent}\n" if ($main::verbose >= 60);
		my $chkFileName = undef;
		$exitCode = 3;

		#
		# -I from command line 
		#
		if ($ent eq 'I') {	# inputFile command line
			print "+++ inputFile: $ent = $mainOptions{$ent}\n" if ($main::verbose >= 60);
			%ifileOptions = getOptionsFromFile($mainOptions{$ent}, 1);
			$chkFileName = $mainOptions{$ent};

			foreach my $ent_i (sort keys %ifileOptions) {
				print "inputfile: $ent_i = $ifileOptions{$ent_i}\n" if ($main::verbose >= 60);
				#
				# -E from -I file, check if filename
				# already processed from command line
				#
				if ($ent_i eq 'E') { #encryptFile infile 
					if (!$mainEncFilename || $ifileOptions{$ent_i} ne $mainEncFilename) {
						$chkFileName = $ifileOptions{$ent_i};
						print "+++ inputFile 'E': from $ifileOptions{$ent_i} \n" if ($main::verbose >= 60);
						$ifileEncFilename = $ifileOptions{$ent_i};
						%iefileOptions = getOptionsFromFile($ifileOptions{$ent_i}, 2);

						pod2usage(
							-msg		=> "\n" . "-E $ifileOptions{$ent_i}: file not found !" . "\n",
							-verbose	=> 1,
							-exitval	=> 3
						) if (! %iefileOptions && ($exitCode == 10 || $exitCode == 11));
					}
					else {
						print "+++ inputFile 'E' [$mainEncFilename] already set on command line\n" if ($mainEncFilename && $main::verbose >= 60);
					}
				}
			}
		} # -I
		#
		# -E from command line 
		#
		if ($ent eq 'E') {	#encryptFile command line
			if (!$ifileEncFilename || $mainOptions{$ent} ne $ifileEncFilename) {
				print "+++ encryptFile: $ent = $mainOptions{$ent}\n" if ($main::verbose >= 60);
				$mainEncFilename = $mainOptions{$ent};
				$chkFileName = $mainOptions{$ent};
				%efileOptions = getOptionsFromFile($mainOptions{$ent}, 2);

				pod2usage(
					-msg		=> "\n" . "-E $mainOptions{$ent}: file not found !" . "\n",
					-verbose	=> 1,
					-exitval	=> 3
				) if (! %mainOptions && ($exitCode == 10 || $exitCode == 11));
			}
			else {
				print "+++ inputFile 'E' [$ifileEncFilename] already set in -I input file\n" if ($ifileEncFilename && $main::verbose >= 60);
			}
		}
	} # for mainoptions - scan file options
=end COMMENT3
=cut

	#
	# store all read options in %mainOptions
	# options from -I inputFile overwrite command line options and
	# options from -E encFile overwrite both, command line and input file
	# 
	print "\n+++mainOptions before merge with file contents\n" if ($main::verbose >= 60);
	foreach my $key_m (sort keys %mainOptions) {
		print " $key_m = $mainOptions{$key_m}\n" if ($main::verbose >= 60);
	}
	print "+++\n" if ($main::verbose >= 60);

	foreach my $key_i (sort keys %ifileOptions) {
		print "inputfile: $key_i = $ifileOptions{$key_i}\n" if ($main::verbose >= 60);
		$mainOptions{$key_i} = $ifileOptions{$key_i};
	}

=begin COMMENT
	#
	# overwrite with options from -E encFile then
	#
	# 1. efileOptions from -E command line 
	#
	foreach my $key_e (sort keys %efileOptions) {
		print "encfile: $key_e = $efileOptions{$key_e}\n" if ($main::verbose >= 60);
		$mainOptions{$key_e} = $efileOptions{$key_e};
	}

	#
	# 2. iefileOptions from -E inside -I last
	#
	foreach my $key_ie (sort keys %iefileOptions) {
		print "inputfile -E: $key_ie = $iefileOptions{$key_ie}\n" if ($main::verbose >= 60);
		$mainOptions{$key_ie} = $iefileOptions{$key_ie};
	}
=end COMMENT
=cut

	print "\n+++mainOptions at the end\n" if ($main::verbose >= 60);
	foreach my $key_m (sort keys %mainOptions) {
		print " $key_m = $mainOptions{$key_m}\n" if ($main::verbose >= 60);
	}
	print "+++\n" if ($main::verbose >= 60);

	return ( %mainOptions);
  } #readOptions

  sub setOptions { # script specific
	my $refOptions = shift;
	my %options =%$refOptions;
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="A";		$optAdminHost = $options{$k}		if (defined $options{$k});
	$k="adigest";	$optAuthDigest= $options{$k}		if (defined $options{$k});
	$k="agentinfo";	$optAgentInfo = $options{$k}		if (defined $options{$k});
	$k="degree";	$optUseDegree		= $options{$k} if (defined $options{$k});
	$k="vtab";	$main::verboseTable = $options{$k}	if (defined $options{$k});
	$k="difflist";	$optChkUpdDiffList	= $options{$k} if (defined $options{$k});
	$k="instlist";	$optChkUpdInstList	= $options{$k} if (defined $options{$k});
	$k="O";		$optOutdir		= $options{$k} if (defined $options{$k});
	    # ... the loop below is not realy necessary ...
	foreach my $key (sort keys %options) {
		#print "options: $key = $options{$key}\n";

		$optShowVersion = $options{$key}              	if ($key eq "V"			); 
		$optHelp = $options{$key}	               	if ($key eq "h"			);
		$optHost = $options{$key}                     	if ($key eq "H"			);
		$optPort = $options{$key}                     	if ($key eq "P"		 	);
		$optTransportType = $options{$key}            	if ($key eq "T"			);
		$optClass = $options{$key}                    	if ($key eq "C"		 	);
		$optUseMode = $options{$key}			if ($key eq "U"			);
		$optServiceMode = $options{$key}		if ($key eq "S"			);
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 
		$optWarningLimit = $options{$key}             	if ($key eq "w"			); 
		$optCriticalLimit = $options{$key}            	if ($key eq "c"		 	); 
		$optChkIdentify = $options{$key}              	if ($key eq "chkidentify"	);	 
		$optChkClass = $options{$key}                 	if ($key eq "chkclass"	 	);	 
		$optSystemInfo = $options{$key}               	if ($key eq "systeminfo"	); 
		$optChkSystem = $options{$key}                	if ($key eq "chksystem"	 	);
		$optChkEnvironment = $options{$key}           	if ($key eq "chkenv"		); 
		$optChkEnv_Fan = $options{$key}               	if ($key eq "chkenv-fan"	); 
		$optChkEnv_Temp = $options{$key}              	if ($key eq "chkenv-temp"	); 
		$optChkPower = $options{$key}                 	if ($key eq "chkpower"		);
		$optChkHardware = $options{$key}              	if ($key eq "chkhardware"	); 
		$optChkCPU = $options{$key}                   	if ($key eq "chkcpu"		); 
		$optChkVoltage = $options{$key}               	if ($key eq "chkvoltage"	); 
		$optChkMemMod = $options{$key}                	if ($key eq "chkmemmodule"	); 
		$optChkDrvMonitor = $options{$key}            	if ($key eq "chkdrvmonitor"	);
		$optChkStorage = $options{$key}               	if ($key eq "chkstorage"	); 
		$optChkUpdate = $options{$key}               	if ($key eq "chkupdate"		);
		$optChkFanPerformance = $options{$key}        	if ($key eq "chkfanperf"	); 
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		$optCert = $options{$key}             		if ($key eq "cert"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey" 		);
		$optCacert = $options{$key}             	if ($key eq "cacert"	 	);
		#$optInputFile = $options{$key}                	if ($key eq "I"			); # this is already set !
		#$optEncryptFile = $options{$key}              	if ($key eq "E"		 	);
		
	}
  } #setOptions

  sub evaluateOptions {	# script specific
	my $wrongCombination = undef;

	if (!$optUseMode) {
	    $optUseMode = "C"; # CIM-XML
	}

	# check command-line parameters
	pod2usage(
		-verbose => 2,
		-exitval => 0,
	) if ((defined $optHelp) || !$argvCnt);

	pod2usage(
		-msg		=> "\n$0" . ' - version: ' . $version . "\n",
		-verbose	=> 0,
		-exitval	=> 0,
	) if (defined $optShowVersion);

	pod2usage(
		-msg		=> "\n" . 'Missing host address !' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if ((!$optHost or $optHost eq '') and (!$optAdminHost or $optAdminHost eq ''));

	pod2usage(
		-msg		=> "\n" . 'Missing user name!' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if (!$optUserName);

	pod2usage(
		-msg		=> "\n" . 'Missing password!' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if (!$optPassword);

	pod2usage(
		-msg		=> "\n" . 'Missing port number!' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if ($optUseMode and $optUseMode =~ m/^W/ and !$optPort);

	pod2usage(
		-msg		=> "\n" . 'Invalid password: password must not contain any . !' . "\n",
		-verbose	=> 1,
		-exitval	=> 3
	) if ($optPassword and $optPassword =~ m/\./ and $optUseMode =~ m/^C/);

	# required combination tests
	pod2usage(
		-msg     => "\n" . "argument --cert requires argument --privkey !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if (($optCert and !$optPrivKey) or (!$optCert and $optPrivKey));

	# wrong combination tests
 	#pod2usage({
	#	-msg     => "\n" . "Invalid argument combination \"$wrongCombination\"!" . "\n",
	#	-verbose => 0,
	#	-exitval => 3
	#}) if ($wrongCombination);

	# after readin of options set defaults
	$optTransportType = "https" if (!defined $optTransportType and $optUseMode =~ m/^C/);
	$optTransportType = "http" if (!defined $optTransportType and $optUseMode =~ m/^W/ and $optPort and ($optPort eq "5985" or $optPort eq "8889" or $optPort eq "80"));
	$optTransportType = "https" if (!defined $optTransportType and $optUseMode =~ m/^W/ and $optPort and ($optPort eq "5986" or $optPort eq "8888" or $optPort eq "443"));


	if (!defined $optChkUpdate and ($optChkUpdDiffList or $optChkUpdInstList)) {
		$optChkUpdate = 999;
	}

	if (!defined $optChkClass and !defined $optChkIdentify and !defined $optSystemInfo
	and !defined $optAgentInfo) 
	{
	    if ((!defined $optChkSystem) and (!defined $optChkEnvironment) and (!defined $optChkPower)
	    and (!defined $optChkHardware) and (!defined $optChkStorage) 
	    and (!defined $optChkDrvMonitor)
	    and (!defined $optChkCpuLoadPerformance) and (!defined $optChkMemoryPerformance)
	    and (!defined $optChkEnv_Fan) and (!defined $optChkEnv_Temp) 
	    and (!defined $optChkCPU) and (!defined $optChkVoltage) and (!defined $optChkMemMod)
	    and (!defined $optChkUpdate)
	    ) {
		    $optChkSystem = 999;
		    $optChkEnvironment = 999;
		    $optChkPower = 999;
		    $optChkHardware = 999;
		    # exotic values if somebody needs to see if an optchk was explizit set via argv or if this 
		    # is default
		    $setOverallStatus = 1;
	    }
	    if ((defined $optChkSystem) and (!defined $optChkEnvironment) and (!defined $optChkPower)
	    and (!defined $optChkHardware) and (!defined $optChkStorage) 
	    and (!defined $optChkDrvMonitor)
	    and (!defined $optChkCpuLoadPerformance) and (!defined $optChkMemoryPerformance)
	    and (!defined $optChkEnv_Fan) and (!defined $optChkEnv_Temp) 
	    and (!defined $optChkCPU) and (!defined $optChkVoltage) and (!defined $optChkMemMod)
	    and (!defined $optChkUpdate)
	    ) {
		    $setOnlySystem = 1;
	    }
	    if ($optChkSystem) {
		    $optChkStorage = 999;
	    }
	} # not class, identify or systeminfo
	$requiresNoSummary = 1 if ($optChkUpdate
	    and (!defined $optChkSystem) and (!defined $optChkEnvironment) and (!defined $optChkPower)
	    and (!defined $optChkHardware) and (!defined $optChkStorage) and (!defined $optChkDrvMonitor)
	    and (!defined $optChkEnv_Fan) and (!defined $optChkEnv_Temp) 
	    and (!defined $optChkCPU) and (!defined $optChkVoltage) and (!defined $optChkMemMod));

	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}
	$useDegree = 1 if (defined $optUseDegree and $optUseDegree);
  } #evaluateOptions

  #
  # main routine to handle options from command line and -I/-E filename
  #
  sub handleOptions {
	# read all options and return prioritized
	my %options = readOptions();

	# assign to global variables
	setOptions(\%options);

	# evaluateOptions expects options set in global variables
	evaluateOptions();
  } #handleOptions
###############################################################################
# DIRECTORIES
  sub checkDirectory {
        my $dir = shift;
	my $modesDir = 0;
	$modesDir++ if ( -r $dir );
	$modesDir++ if ( -w $dir );
	$modesDir++ if ( -x $dir );
	$modesDir++ if ( -d $dir );
	if ($main::verbose >= 60) {
	    print ">>> Check directory $dir [";
	    print "r" if ( -r $dir );
	    print "w" if ( -w $dir );
	    print "x" if ( -x $dir );
	    print "d" if ( -d $dir );
	    print "] <<<\n";
	}
	return $modesDir;
  } #checkDirectory

  sub handleOutputDirectory {
	return if (!$optOutdir);
	my $modesOutDir = checkDirectory($optOutdir);
	if (!$modesOutDir) {
	    if (! mkdir $optOutdir, 0700) {
	    addMessage("m", 
		"ERROR - Can't create output directory $optOutdir");
	    $exitCode = 2;
	    return;
	    }
	} elsif ($modesOutDir < 4) {
	    addMessage("m", 
		"ERROR - output directory $optOutdir exists but has not enough access rights");
	    $exitCode = 2;
	    return;
	}
  } #handleOutputDirectory

###############################################################################
# FILE
  sub writeTxtFile {
	my $host = shift;
	my $type = shift;
	my $result = shift;
	return if (!$optOutdir);

	my $txt = undef;
	my $txtFileName = $optOutdir . "/$host" . "_$type.txt";
	open ($txt, ">", $txtFileName);
	print $txt $result if ($result and $txt);
	close $txt if ($txt);
  } #writeTxtFile

###############################################################################
use IO::Socket;
  sub socket_checkSCS {
	my $host = shift;
	return undef if (!$host);
	my $EOL = "\015\012";
	my $BLANK = $EOL x 2;
	my $document = "/cmd?t=connector.What&aid=svnagioscheck";
	my $remote = undef;

	$remote = IO::Socket::INET->new( 
		Proto => "tcp",
		PeerAddr => $host,
		PeerPort => "3172",
		Timeout => 10,
	);
	return undef if (!$remote); # no connection
	$remote->autoflush(1);
	print $remote "GET $document HTTP/1.0" . $BLANK;
	my $response = undef;
	while ( <$remote> ) { $response .= $_; }
	close $remote;
	undef $remote;
	if ($main::verbose >= 10 and $response) {
	    print $response;
	    print "___\n";
	}
	my $version = undef;
	if ($response and $response =~ m/HTTP.*200/) {
	    $version = $1 if ($response =~ m/<wcs version=\"([^\"]+)\"/m);
	}
	return $version;
  } #socket_checkSCS

  sub socket_checkSSM {
	my $host = shift;
	my $agentVersion = shift;
	return undef if (!$host);
	my $EOL = "\015\012";
	my $BLANK = $EOL x 2;
	my $ssmDocument = "/ssm/index.html";
	my $lt720document = "/ssm/desktop/index.html";
	my $versionDocument = "/ssm/version.txt";
	my $versionlt720Document = "/ssm/desktop/version.txt";
	my $remote = undef;
	# with IO::SOCKET we try only http

	$remote = IO::Socket::INET->new( 
		Proto => "tcp",
		PeerAddr => $host,
		PeerPort => "3172",
	);
	return undef if (!$remote); # no connection
	$remote->autoflush(1);
	print $remote "GET $versionDocument HTTP/1.0" . $EOL . "Host: $optHost:3172" . $BLANK;
	my $response = undef;
	while ( <$remote> ) { $response .= $_; }
	close $remote;
	undef $remote;
	if ($main::verbose >= 10 and $response) {
	    print $response;
	    print "\n";
	}
	my $address = undef;
	#### older version ( less than 7.20.10 )
	# TODO ... with 7.20.10 ssm/index.html is living ... check agent version
	if ( $response and $response !~ m/HTTP.*404/ 
	and ($response =~ m/HTTP.*301/ or $response =~ m/^\s*$/)) 
	{
	    my $isOld = 0;
	    if ($agentVersion =~ m/^(\d+)[^\d](\d+)/) {
		my $main = $1; 
		my $sec = $2;
		$isOld = 1 if ($main < 7);
		$isOld = 1 if (!$isOld and $main==7 and $sec < 20);
	    }
	    if (!$isOld) {
		$address = "https://$optHost:3172$ssmDocument" if ($optHost !~ m/:/);
		$address = "https://[$optHost]:3172$ssmDocument" if ($optHost =~ m/:/);
	    } else {
		$address = "https://$optHost:3172$lt720document" if ($optHost !~ m/:/);
		$address = "https://[$optHost]:3172$lt720document" if ($optHost =~ m/:/);
	    }
	}
	return $address;
  } #socket_checkSSM

  sub socket_getSSM_URL {
	my $agentVersion = shift;
	my $ssmAddress = undef;
	my $chkSSM = 0;
	if (!$isiRMC) {
	    my $scsVersion = socket_checkSCS($optHost);
	    $chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.0[4-9]/);
	    $chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.[1-9]/);
	    $chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.[1-9]/);
	    $chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V[3-9]/);

	}
	if ($chkSSM) {
		$ssmAddress = socket_checkSSM($optHost, $agentVersion);
	}
	return $ssmAddress;
  } #socket_getSSM_URL

##### WBEM CIM ACCESS ###################################################
#wbemcli ei -nl -t -noverify  'https://root:*****@172.17.167.139:5989/root/svs:SVS_PGYComputerSystem'

# TIP ... wbemcli ein -nl -t -noverify  'https://root:*****@10.172.130.2/root/interop:CIM_Namespace'

# -nl new line is required for the scan
our $wbemCall = "wbemcli ei -nl";
our $wbemCert = " -noverify";
our $wbemSvsForm = " '%s://%s:%s@%s/root/svs:%s'";	# SVS*
our $wbemLsi12Form = " '%s://%s:%s@%s/lsi/lsimr12:%s'";	# 12_LSIESG_
our $wbemLsiForm = " '%s://%s:%s@%s/lsi/lsimr13:%s'";	# LSIESG_
our $wbemCimv2Form = " '%s://%s:%s@%s/root/cimv2:%s'";	# CIM_ or other
our $wbemFlexibleForm = " '%s://%s:%s@%s/%s:%s'";	# 

#########################################################################
  sub cimWbemInitConnection {
	$clientSession = 1;
  } # cimWbemInitConnection

  sub cimWbemFinishConnection {
	$clientSession = 0;
  } # cimWbemFinishConnection

  sub cimWbemIdentify {
	# ATTENTION:
	#   The sequence of following class checks is important for the performance
	#   
	#   It is assumed that CIM-XML is used
	#   -	very often for ESXi ... OMC_
	#   -	followed by Linux ... Linux_ and PG_
	#   -	followed by iRMC ... SVS_iRMC
	#   -	last by Windows WIN32_
	my @classInstances = ();
	{
		@classInstances = cimWbemEnumerateClass("OMC_UnitaryComputerSystem");
		$isESXi = 1 if ($#classInstances >= 0);
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "- [ERROR] Couldn't connect to server");
		}
	}
	if ($notifyMessage and $notifyMessage =~ m/Invalid username\/password/) {
		    $exitCode = 2;
	    	addMessage("m", "- [ERROR] authentication error discovered.");
	}
	if ($exitCode != 2 and $notifyMessage and $notifyMessage =~ m/Http Exception.*SSL/) {
		    $exitCode = 2;
			addMessage("m", "- [ERROR] some connection error discovered.");
	}
	return if ($exitCode == 2);
	if (!$isESXi) {
		$notifyMessage = "";
		@classInstances = cimWbemEnumerateClass("Linux_ComputerSystem");
		$isLINUX = 1 if ($#classInstances >= 0);
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "ERROR - Couldn't connect to server");
		}
	}
	return if ($exitCode == 2);
	if (!$isESXi and !$isLINUX) {
		$notifyMessage = "";
		@classInstances = cimWbemEnumerateClass("PG_ComputerSystem");
		$isLINUX = 1 if ($#classInstances >= 0);
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "ERROR - Couldn't connect to server");
		}
	}
	return if ($exitCode == 2);
	if (!$isESXi and !$isLINUX) {
		$notifyMessage = "";
		@cimSvsComputerSystem = cimWbemEnumerateClass("SVS_iRMCBaseServer");
		$isiRMC = 1 if ($#cimSvsComputerSystem >= 0);
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "ERROR - Couldn't connect to server");
		}
	}
	return if ($exitCode == 2);
	if (!$isESXi and !$isLINUX and !$isiRMC) {
		$notifyMessage = "";
		@classInstances = cimWbemEnumerateClass("WIN32_ComputerSystem");
		$isWINDOWS = 1 if ($#classInstances >= 0);
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "ERROR - Couldn't connect to server");
		}
	}
	return if ($exitCode == 2);
	if (!$isESXi and !$isLINUX and !$isWINDOWS and !$isiRMC) {
		$notifyMessage = "";
		@classInstances = cimWbemEnumerateClass("CIM_ComputerSystem");
		if ($notifyMessage =~ m/Couldn\'t connect to server/) {
		    $exitCode = 2;
		    addMessage("m", "ERROR - Couldn't connect to server");
		} 
		elsif ($#classInstances >= 0) {
		    my $ref1stClass = $classInstances[0];
		    my %compSystem = %{$ref1stClass};
		    my $classname = $compSystem{"CreationClassName"};
		    addMessage("l", "CreationClassName=$classname\n")
			if ($classname);
		    $isLINUX = 1 if ($#classInstances >= 0); # assumed ...
		} elsif ($main::verbose >= 2) {
		    addMessage("v", "* ATTENTION: Unable to get any Standard CIM ComputerSystem information !\n");
		}
	}
	return if ($exitCode == 2);
	if (!$isESXi and !$isLINUX and !$isWINDOWS and !$isiRMC) {
		$notifyMessage = "";
		getOperatingSystem();
		if ($cimOS or $cimOSDescription) {
		    $isWINDOWS= 1 if ($cimOS and $cimOS =~ m/WIN/);
		    $isWINDOWS = 1 if ($cimOSDescription and $cimOSDescription =~ m/WIN/);
		    $isWINDOWS= 1 if ($cimOS and $cimOS =~ m/Windows/i);
		    $isWINDOWS = 1 if ($cimOSDescription and $cimOSDescription =~ m/Windows/i);
		    $isESXi= 1 if ($cimOS and $cimOS =~ m/ESXi/i);
		    $isESXi = 1 if ($cimOSDescription and $cimOSDescription =~ m/ESXi/i);
		    $isLINUX = 1 if (!$isWINDOWS and !$isESXi);
		}
	}
	if ($isESXi or $isLINUX or $isWINDOWS or $isiRMC) {
		$exitCode = 0;
	} else {
		$notifyMessage =~ s/CIM_ComputerSystem/\{OMC,Linux,PG,WIN32\}_ComputerSystem/;
		addMessage("m","- [ERROR] unable to get identify information of server.");
		$exitCode = 2;
	}
	if ($optChkIdentify and !$exitCode) {
	    $msg .= "-";
	    addKeyValue("m", "Type", "Windows") if ($isWINDOWS);
	    addKeyValue("m", "Type", "LINUX") if ($isLINUX);
	    addKeyValue("m", "Type", "ESXi") if ($isESXi);
	    addKeyValue("m", "Type", "iRMC") if ($isiRMC);
	    addKeyValue("m", "Protocol", "CIM-XML");
	    $notifyMessage = "";
	} 
	if ($isiRMC and $#cimSvsComputerSystem >= 0) {
	    my $ref1stClass = $cimSvsComputerSystem[0];
	    my %compSystem = %{$ref1stClass};
	    my $reqState = $compSystem{"RequestedState"};
	    if ($reqState and $reqState =~ m/3/) {
		addKeyValue("m", "PowerState", "off");
		$exitCode = 2;
	    }
	} # iRMC
  } # cimWbemIdentify

  sub cimWbemEnumerateClass {
	my $class = shift;
	return undef if (!$class);
	my $useFormAdd = undef;
	my $oneXML = undef;
	my @listXML = ();
	my @list = ();

	# host and port
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	$host = $host . ':' . $optPort if ($optPort);

	my $cmd = undef;
	my $debugCmd = undef;
	# class
	my $classDependentPart = undef;
	my $classDependentDebugPart = undef;
	if ($class =~ m/^SVS_.*/) {
	    $classDependentPart = sprintf( $wbemSvsForm, 
		    $optTransportType, $optUserName, $optPassword, $host, $class );
	    $classDependentDebugPart = sprintf( $wbemSvsForm, 
		    $optTransportType, $optUserName, "****", $host, $class );
	} elsif ($class =~ m/^LSIESG_.*/) {
	    $classDependentPart = sprintf( $wbemLsiForm, 
		    $optTransportType, $optUserName, $optPassword, $host, $class );
	    $classDependentDebugPart = sprintf( $wbemLsiForm, 
		    $optTransportType, $optUserName, "****", $host, $class );
	} elsif ($class =~ m/^12_LSIESG_.*/) {
	    $class =~ s/^12_//;
	    $classDependentPart = sprintf( $wbemLsi12Form, 
		    $optTransportType, $optUserName, $optPassword, $host, $class );
	    $classDependentDebugPart = sprintf( $wbemLsi12Form, 
		    $optTransportType, $optUserName, "****", $host, $class );
	} elsif ($class =~ m/^LSI_.*/) {
	    $classDependentPart = sprintf( $wbemLsiForm, 
		    $optTransportType, $optUserName, $optPassword, $host, $class );
	    $classDependentDebugPart = sprintf( $wbemLsiForm, 
		    $optTransportType, $optUserName, "****", $host, $class );
	} elsif ($class =~ m/\:/) { # USE FLEXIBLE FORM
	    my $ns = $class;
	    $ns =~ s/\:.*//;
	    $ns =~ s!^/!!;
	    $class =~ s!.*:!!;
	    $classDependentPart = sprintf( $wbemFlexibleForm, 
		    $optTransportType, $optUserName, $optPassword, $host, $ns, $class );
	    $classDependentDebugPart = sprintf( $wbemFlexibleForm, 
		    $optTransportType, $optUserName, "****", $host, $ns, $class );
	} else {
	    $classDependentPart = sprintf( $wbemCimv2Form, 
		    $optTransportType, $optUserName, $optPassword, $host, $class );
	    $classDependentDebugPart = sprintf( $wbemCimv2Form, 
		    $optTransportType, $optUserName, "****", $host, $class );
	}
	# -noverify versus -cacert
	if (!$optCacert) {
	    $cmd = $wbemCall . $wbemCert ;
	    $debugCmd = $wbemCall . $wbemCert ;
	} else {
	    $cmd = $wbemCall . " -cacert $optCacert";
	    $debugCmd = $wbemCall . " -cacert $optCacert";
	}
	# local certificates
	if ($optCert) {
	    $cmd .= " -clientcert $optCert";
	    $debugCmd .= " -clientcert $optCert";
	}
	if ($optPrivKey) {
	    $cmd .= " -clientkey $optPrivKey";
	    $debugCmd .= " -clientkey $optPrivKey";
	}
	# add class
	$cmd .= $classDependentPart;
	$debugCmd .= $classDependentDebugPart;
	

	print "**** enumerate Class $class\n" if ($main::verbose > 20); 
	print "cmd = `  $debugCmd `\n" if ($main::verbose >= 10);

	my $errCmd = $cmd;
	$cmd = $cmd . " 2>/dev/null"; 
		# There is a problem to catch stderr - 2>&1 does not work in open()
	
	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	print "**** read data ...\n" if ($main::verbose > 20); 
	while (<$pHandle>) {
		my $tmpStream = $_;
		if ($tmpStream =~ m/^$host/ and $oneXML) {
		    push @listXML, $oneXML;
		    $oneXML = '';
		} elsif ($tmpStream !~ m/^$host/) {
		    $oneXML .= $tmpStream; 
		}
		print if ($main::verbose >= 60); # $_

	}
	$oneXML = undef if (defined $oneXML and $oneXML eq "");
	#print "**** split into classes ...\n" if ($main::verbose > 20); 
	push (@listXML, $oneXML) if ($oneXML);
	if ($#listXML < 0) { ###### ERROR CASE
	    my $allStderr = `$errCmd 2>&1`;
	    addMessage("n", $allStderr);
	    print "$allStderr\n" if ($main::verbose > 10); 
	}
	#print "MaxIndexlistXML=" . $#listXML . "\n";
	my @PullItems = undef;
	print "**** split into classes ...\n" if ($main::verbose > 20); 
	foreach my $singleXML (@listXML) {
		if ($singleXML) {
			$singleXML =~ s/\r//mg;
			$singleXML =~ s/[\[\]\#\&]+=/=/mg; # unnecessary stuff at the left of '='
			push (@PullItems, $singleXML);
			#print $singleXML . "---\n";
		}
	} 
	#print "MaxIndexPullItems=" . $#PullItems . "\n";
	print "**** split class fields ...\n" if ($main::verbose > 20); 
	foreach my $singleClass (@PullItems) {
		my @tagArray = ();
		next if (!$singleClass);
		#print ">>>$singleClass<<<\n" if ($singleClass);
		while ($singleClass) { # split for CIM elements
		    # search next tag
		    $singleClass =~ m/^\-(.*)\n/;
		    my $tag = $1;
		    if ($tag) {
			#print "    ___ $tag ___\n" if ($tag);
			push (@tagArray, $tag);
			$singleClass =~ s/\-[^\n]*\n//;
		    }
		    #print "+++$singleClass+++\n" if ($singleClass);
		    $singleClass = undef if (!$singleClass or $singleClass eq "" or $singleClass eq "\n");

		    #$singleClass = undef if ($tag =~ m/ReleaseDate/);

		} # split into elements
		
		my $items = undef;
		for((my $cnt = 0) ; ($cnt<=$#tagArray) ; ($cnt++)) { # split key value
		    $tagArray[$cnt] =~ m/=(.*)/;
		    my $value = $1;
		    my $skipQuotes = 0;
		    $skipQuotes = 1 if ($value and $value =~ m/^\"/);
		    $skipQuotes = 0 if ($value and $value =~ m/\"\,\"/);
		    #$value =~ s/^\"// if ($value and $value !~ m/\"\,\"/);
		    #$value =~ s/\"$// if ($value and $value !~ m/\"\,\"/);
		    $value =~ s/^\"// if ($skipQuotes);
		    $value =~ s/\"$// if ($skipQuotes);
		    $value = undef if (defined $value and $value =~ m/^\s*$/);
		    $value =~ s/^\s+// if ($value);
		    $value =~ s/\s+$// if ($value);
		    $tagArray[$cnt] =~ m/([^=]+)=/;
		    my $key = $1;
		    $value = '' if (!defined $value);
		    #print "...key=$key value=$value\n";
		    next if (($value eq '') and !$main::verbose);
		    $items->{$key} = $value;
		} # for CIM elements
		#push (@list, [@tagArray]) if (@tagArray);
		push (@list, $items);
	} # for each class stream

	$exitCode = 0 if ($#PullItems >= 0 and $optChkClass);
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	return @list;
	
  } # cimWbemEnumerateClass

#########################################################################
#### WSMAN SCRIPT CALL ##################################################
  sub cimWsmanInitConnection {
	$clientSession = 1;
  } # cimWbemInitConnection

  sub cimWsmanFinishConnection {
	$clientSession = 0;
  } # cimWbemFinishConnection

  sub cimWsmanIdentify {
	my $script = $main::scriptPath . $wsmanPerlBindingScript;
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	my $cmd = $script . " --chkidentify -H$host -U $optUseMode";
	my $cmdPrint = undef;

	$cmd .= " -P $optPort";
	$cmd .= " -T $optTransportType" if ($optTransportType);
	$cmd .= " --adigest" if ($optAuthDigest);
	if ($optInputFile) {
	    $cmd .= " -I$optInputFile";
	    $cmdPrint = $cmd;
	} else {
	    $cmdPrint = $cmd . " -u **** -p ****";
	    $cmd .= " -u '$optUserName' -p '$optPassword'";
	}

	if ($optTransportType and $optTransportType =~ m/https/i) {
	    my $addSecureParams = '';
	    $addSecureParams .= " --cert $optCert" if ($optCert);
	    $addSecureParams .= " --cacert $optCert" if ($optCacert);
	    $addSecureParams .= " --privkey $optCert" if ($optPrivKey);
	    $cmd .= $addSecureParams;
	    $cmdPrint .= $addSecureParams;
	}

	print "**** ScriptCall = $cmdPrint\n" if ($main::verbose >= 10);

	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	my $out = "";
	while (<$pHandle>) {
		my $tmpStream = $_;
		$out .= $tmpStream;
		print if ($main::verbose >= 60); # $_

	}
	$out = undef if ($out eq "");
	my $prot_version = undef;
	my $prod_vendor = undef;
	my $prod_version = undef;
	if ($out) {
	    $out =~ m/Protocol=(.*) Vendor=\"(.*)\" Version=\"(.*)\"/;
	    $prot_version = $1 if ($1);
	    $prod_vendor = $2 if ($1 and $2);
	    $prod_version = $3 if ($1 and $2 and $3);
	}
	if ($prod_vendor and $prod_version) {
	    # "Openwsman Project" => LINUX
	    # "Microsoft Corporation" => WINDOOF
	    # "VMware Inc." ESXi - Version "VMware ESXi 5.0.0 ***"
	    $isWINDOWS = 1 if ($prod_vendor =~ m/Microsoft/i);
	    $isESXi = 1 if ($prod_vendor =~ m/VMware/i && $prod_version =~ m/ESXi/i);
	    $isLINUX = 1 if (!$isWINDOWS && !$isESXi);
	    # no $isiRMC
	}
	if ($isESXi or $isLINUX or $isWINDOWS) {
		$exitCode = 0;
	} else {
		my $err = undef;
		$out =~ m/.*(\[ERROR\].*)/ if ($out);
		$err = $1;
		addMessage("m","- $err ") if ($err);
		addMessage("m","- [ERROR] unable to get identify information of server.") if (!$err);
		$exitCode = 2;
	}
	if ($optChkIdentify and !$exitCode) {
	    $msg .= "-";
	    addKeyValue("m", "Type", "Windows") if ($isWINDOWS);
	    addKeyValue("m", "Type", "LINUX") if ($isLINUX);
	    addKeyValue("m", "Type", "ESXi") if ($isESXi);
	    addKeyValue("m", "Protocol", "WS-MAN");
	    # 
	    addKeyValue("l","ProtocolScheme",$prot_version ) if ($optChkIdentify);
	    addKeyLongValue("l","Vendor",$prod_vendor ) if ($optChkIdentify);
	    addKeyLongValue("l","Version",$prod_version ) if ($optChkIdentify);
	    $notifyMessage = "";
	} 
  } # cimWsmanIdentify

  sub cimWsmanEnumerateClass {
	my $class = shift;
	return undef if (!$class);
	my $useFormAdd = undef;
	my $oneXML = undef;
	my @listXML = ();
	my @list = ();

	my $script = $main::scriptPath . $wsmanPerlBindingScript;
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	my $cmd = $script . " --chkclass -C$class -H$host -U $optUseMode";
	my $cmdPrint = undef;

	$cmd .= " -P $optPort";
	$cmd .= " -T $optTransportType" if ($optTransportType);
	$cmd .= " -S $optServiceMode" if ($optServiceMode);
	$cmd .= " --adigest" if ($optAuthDigest);
	if ($optInputFile) {
	    $cmd .= " -I$optInputFile";
	    $cmdPrint = $cmd;
	} else {
	    $cmdPrint = $cmd . " -u *** -p ****";
	    $cmd .= " -u '$optUserName' -p '$optPassword'";
	}
	if ($optTransportType =~ m/https/i) {
	    my $addSecureParams = '';
	    $addSecureParams .= " --cert $optCert" if ($optCert);
	    $addSecureParams .= " --cacert $optCert" if ($optCacert);
	    $addSecureParams .= " --privkey $optCert" if ($optPrivKey);
	    $cmd .= $addSecureParams;
	    $cmdPrint .= $addSecureParams;
	}
	print "**** ScriptCall = $cmdPrint\n" if ($main::verbose >= 10);

	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	
	print "**** read data ...\n" if ($main::verbose > 20); 
	my $foundClass = 0;
	while (<$pHandle>) {
		my $tmpStream = $_;
		if ($tmpStream =~ m/^\{\-\-\-+/ and $oneXML) {
		    $foundClass = 1;
		    push @listXML, $oneXML if ($oneXML !~ m/MAXINDEX/m);
		    $oneXML = '';
		} elsif ($tmpStream !~ m/^.\-\-\-+/ and $tmpStream !~ m/^\s*$/) {
		    $oneXML .= $tmpStream; 
		}
		print if ($main::verbose >= 60); # $_

	}
	$oneXML = undef if (defined $oneXML and $oneXML eq "");
	push (@listXML, $oneXML) if ($oneXML);
	print "ClassCounter=$#listXML\n" if ($main::verbose >= 60);
	print "**** check error data ...\n" if ($main::verbose > 20); 
	if (!$foundClass) { ###### ERROR CASE
	    my $allStderr = $oneXML;
	    $allStderr =~ s/MAXINDEX.*//;
	    $allStderr =~ s/instances./instances of class $class/;
	    addMessage("n", $allStderr);
	    print "$allStderr" if ($main::verbose >= 10); 
	}
	if ($foundClass) {
		print "**** split class fields ...\n" if ($main::verbose > 20); 
		
		foreach my $singleClass (@listXML) {
			my @tagArray = ();
			next if (!$singleClass);
			#print ">>>$singleClass<<<\n" if ($singleClass);
			while ($singleClass) { # split for CIM elements
			    # search next tag
			    $singleClass =~ m/^([^\n]*)\n/;
			    my $tag = $1;
			    if ($tag) {
				#print "    ___ $tag ___\n" if ($tag);
				push (@tagArray, $tag);
				$singleClass =~ s/[^\n]*\n//;
			    }
			    #print "+++$singleClass+++\n" if ($singleClass);
			    $singleClass = undef if (!$singleClass or $singleClass eq "" or $singleClass eq "\n");

			} # split into elements
			#print "TagCounter=$#tagArray\n" if ($main::verbose >= 60);
			
			my $items = undef;
			for((my $cnt = 0) ; ($cnt<=$#tagArray) ; ($cnt++)) { # split key value
			    $tagArray[$cnt] =~ m/\: (.*)/;
			    my $value = $1;
			    #$value =~ s/^\"// if ($value);
			    #$value =~ s/\"$// if ($value);
			    $value = undef if (defined $value and $value =~ m/^\s*$/);
			    $value =~ s/^\s+// if ($value);
			    $value =~ s/\s+$// if ($value);
			    $tagArray[$cnt] =~ m/([^:]+)\:/;
			    my $key = undef;
			    $key = $1 if ($1);
			    $value = '' if (!defined $value);
			    #print "...key=$key value=$value\n";
			    next if ((($value eq '') and !$main::verbose) or !defined $key);
			    $items->{$key} = $value;
			} # for CIM elements
			push (@list, $items);
		} # for each class stream
	}
	$exitCode = 0 if ($foundClass and $optChkClass);
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	return @list;
  } # cimWsmanEnumerateClass

#########################################################################

#### ALL CIM VARIANTS ###################################################
  sub cimInitConnection {
	cimWbemInitConnection() if ($optUseMode =~ m/^C/);
	cimWsmanInitConnection() if ($optUseMode =~ m/^W/);
  } # cimInitConnection

  sub cimFinishConnection {
	cimWbemFinishConnection()  if ($optUseMode =~ m/^C/);
	cimWsmanFinishConnection()  if ($optUseMode =~ m/^W/);
  } # cimFinishConnection

  sub cimIdentify {
	if ($optServiceMode) {
		$isESXi = 1 if ($optServiceMode =~ m/^E/);
		$isWINDOWS = 1 if ($optServiceMode =~ m/^W/);
		$isLINUX = 1 if ($optServiceMode =~ m/^L/);
		$isiRMC = 1 if ($optServiceMode =~ m/^I/);
	} 
	if ($optChkIdentify or (!$isESXi and !$isWINDOWS and !$isLINUX and !$isiRMC)) {
		cimWbemIdentify()  if ($optUseMode =~ m/^C/);
		cimWsmanIdentify()  if ($optUseMode =~ m/^W/);
	}
	if (!$optServiceMode) {
		$optServiceMode = "E" if ($isESXi);
		$optServiceMode = "W" if ($isWINDOWS);
		$optServiceMode = "L" if ($isLINUX);
		$optServiceMode = "I" if ($isiRMC);
	}
 } #cimIdentify

  sub cimEnumerateClass {
      	my $class = shift;
	return cimWbemEnumerateClass($class)  if ($optUseMode =~ m/^C/);
	return cimWsmanEnumerateClass($class) if ($optUseMode =~ m/^W/);
  } #cimEnumerateClass

  sub cimPrintClass {
	my $refList = shift; # ATTENTION: Array Parameter always as reference !
	my $className = shift;
	my @list = @{$refList} if ($refList);
	my $printClass = '';
	return if ($main::verbose <= 5);
	$printClass = " CLASS: " . $className if ($className);
	# Print output.
	print "MAXINDEX: " . $#list . "$printClass\n";
	return if (!$refList or $#list < 0);
	foreach(@list) {
	    print "{---------------------------------------------------\n";
	    if ($_) {
		my %route = %$_;
		foreach my $key (keys %route) {
		    print $key,": ",$route{$key},"\n";
		}
	    }
	    print "}---------------------------------------------------\n";
	}
  } #cimPrintClass

#########################################################################
#### PROCESS FUNCTIONS ##################################################
  sub initCIMConnection {
	# Check Availability and Type:
	cimInitConnection();
	if ($clientSession && $exitCode != 2) {
		cimIdentify(); # ... silent for all other calls besides chkidentify
	} # session
  } # initCIMConnection

  sub finishCIMConnection {
	cimFinishConnection() if ($clientSession);
  } #finishCIMConnection

#########################################################################
  sub getOperatingSystem {
	# might be called from WBEM identify and is called for notify data
	# ATTENTION sets global data
	return if ($#cimSvsOperatingSystem >= 0);
	if (!$isiRMC) {
	    @cimSvsOperatingSystem = cimEnumerateClass("SVS_PGYOperatingSystem");
	    cimPrintClass(\@cimSvsOperatingSystem, "SVS_PGYOperatingSystem");
	} else { # iRMC
	    @cimSvsOperatingSystem = cimEnumerateClass("SVS_iRMCOperatingSystem");
	    cimPrintClass(\@cimSvsOperatingSystem, "SVS_PGYOperatingSystem");
	}
	$notifyMessage = "";
	if ($#cimSvsOperatingSystem >= 0) {
	    my $ref1stClass = $cimSvsOperatingSystem[0]; # There should be only one instance !
	    my %OSClass = %{$ref1stClass};
	    my $osDescr = $OSClass{"Description"};
	    my $osCaption = $OSClass{"Caption"};
	    my $osVersion = $OSClass{"Version"};
	    my $osType = $OSClass{"OSType"};
	    $osDescr = undef if (defined $osDescr and $osDescr =~ m/^\s*$/);
	    $osDescr = undef if (defined $osDescr and $osDescr =~ m/^\#.*/); # ESXi ... only build info
	    $osCaption = undef if (defined $osCaption and $osCaption =~ m/^\s*$/);
	    $osVersion = undef if (defined $osVersion and $osVersion =~ m/^\s*$/);
	    $osType = undef if (defined $osType and $osType =~ m/^\s*$/);
	    my $osTypeString = osString($osType, $osVersion);
	    $cimOS = $osDescr;
	    $cimOS = $osCaption if (!$cimOS);
	    if ($osTypeString and (!$cimOS or $cimOS !~ m/$osTypeString/)) { # ... different infos in Caption and OSType (not expected for ESXi)
		$cimOSDescription = $cimOS;
		$cimOS = $osTypeString;
	    }
	    if ($isiRMC) {
		$cimOS = $osCaption;
		$cimOSDescription = $osTypeString;
	    }
	} # data found
  } #getOperatingSystem

  sub getAllFanSensors {
	#
	# ATTENTION: On a Windows System with Agent 6.20 the SVS Fans CurrentState and HealthState are NOT identic
	#	     The hope is that with newer CIM-Provider this error is solved
	#
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $tmpCollectedHealthStatusString = undef;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allFanStatus and ($allFanStatus==1 or $allFanStatus==2));
	$searchNotifies = 1 if (!defined $allFanStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	# HealthStateComponent
	my %adapter = ();
	%adapter = %$cimSvsFanAdapters if ($cimSvsFanAdapters);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYFanSensor");
	    cimPrintClass(\@classInstances, "SVS_PGYFanSensor");
	} else { # iRMC
	    @classInstances = cimEnumerateClass("SVS_iRMCFanSensor");
	    cimPrintClass(\@classInstances, "SVS_iRMCFanSensor");
	}

	addTableHeader("v","Fans") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $elementName = $oneClass{"ElementName"}; # ... not ESXi
		my $name = $oneClass{"Name"};
		my $devid = $oneClass{"DeviceID"};
		my $curState = $oneClass{"CurrentState"}; # ... not ESXi
		my $healthState = $oneClass{"HealthState"};
		my $curValue = $oneClass{"CurrentReading"};
		my $baseUnits = $oneClass{"BaseUnits"};
		my $unitModifier = $oneClass{"UnitModifier"};
		my $quality = $oneClass{"Quality"};

		my $useName = $elementName;
		$useName = $name if (!defined $elementName || $elementName eq '');
		$devid = "" if (defined $devid and defined $useName
		    and $devid eq $useName); # iRMC S4

		next if (!$useName); # CIM Provider internal error

		my $adapterHealthState = undef;
		$adapterHealthState = $adapter{$useName} if ($cimSvsFanAdapters);

		$useName =~ s/[ ,;=]/_/g;
		$useName =~ s/_$//g;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$curState = undef if (defined $curState and $curState eq '');
		$curValue = undef if (defined $curValue and $curValue eq '');
		$healthState = undef if (defined $healthState and $healthState eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		# ... unify CIM output variants
		my $useState = $healthState;
		if ($curState) { # ATTENTION: CurrentState is a string !
		    my $currentHealthState = undef;
		    $currentHealthState = currentStateHealthState($curState);
		    $useState = $currentHealthState 
			if (defined $currentHealthState 
			    and (!defined $useState or $currentHealthState > $useState));
		    $useState = $currentHealthState
			if (defined $currentHealthState and $currentHealthState == 0
			and defined $curValue and $curValue == 0);
		}
		if ($adapterHealthState) {
		    $useState = $adapterHealthState 
			if (!defined $useState or $adapterHealthState > $useState);
		}
		
		# ... around health status
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus);

		my $isRPM = 0;
		$isRPM = 1 if ($baseUnits and $baseUnits==19 and !$unitModifier);

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"Fan",$devid);
			addName("v",$useName);	
			addKeyRpm("v", "Speed", $curValue) if ($isRPM);
			addKeyThresholdsUnit("v", "Speed", "???", $curValue) if (!$isRPM);
			addKeyIntValueUnit("v", "NominalRelation", $quality, "%");
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"Fan",$devid);
			addName("l",$useName);	
			addKeyRpm("l", "Speed", $curValue) if ($isRPM);
			addKeyThresholdsUnit("l", "Speed", "???", $curValue) if (!$isRPM);
			addKeyIntValueUnit("l", "NominalRelation", $quality, "%");
			$longMessage .= "\n";
		}

		# performance values
		if ($optChkFanPerformance) {
			if ($baseUnits and $baseUnits == 19 and !$unitModifier) {
		    	    addRpmToPerfdata($useName, $curValue, undef, undef)
			    	if (!$main::verboseTable);
			} # else TODO ... baseUnits2String();
        	}
	} # foreach class

	addExitCode($tmpExitCode) if ($setExitCode);
	if (!defined $allHealthFanStatus) {
	    $allHealthFanStatus = $tmpCollectedHealthStatus;
	}
  } # getAllFanSensors

  sub getAllTemperatureSensors {
	# This is (hopefully) for ALL SVS CIM Provider !
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allTempStatus and ($allTempStatus==1 or $allTempStatus==2));
	$searchNotifies = 1 if (!defined $allTempStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYTemperatureSensor");
	    cimPrintClass(\@classInstances, "SVS_PGYTemperatureSensor");
	} else { # iRMC
	    @classInstances = cimEnumerateClass("SVS_iRMCTemperatureSensor");
	    cimPrintClass(\@classInstances, "SVS_iRMCTemperatureSensor");
	}

	# HealthStateComponent
	my %adapter = ();
	%adapter = %$cimSvsTempAdapters if ($cimSvsTempAdapters);

	addTableHeader("v","Temperature Sensors") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $devid = $oneClass{"DeviceID"};
		my $curState = $oneClass{"CurrentState"}; # ... not ESXi
		my $healthState = $oneClass{"HealthState"};
		my $curValue = $oneClass{"CurrentReading"};
		my $warnValue = $oneClass{"UpperThresholdNonCritical"}; # not ESXi
		my $critValue = $oneClass{"UpperThresholdCritical"};
		my $fatalValue = $oneClass{"UpperThresholdFatal"};
		# ESXi knows "critical" and "fatal"
		my $baseUnits = $oneClass{"BaseUnits"};
		my $unitModifier = $oneClass{"UnitModifier"};

		next if (!$name); # CIM Provider internal error

		my $adapterHealthState = undef;
		$adapterHealthState = $adapter{$name} if ($cimSvsTempAdapters);

		$devid = "" if (defined $devid and defined $name
		    and $devid eq $name); # iRMC S4

		$name =~ s/[ ,;=]/_/g;
		$name =~ s/_$//;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$curState = undef if (defined $curState and $curState eq '');
		$healthState = undef if (defined $healthState and $healthState eq '');
		$warnValue = undef if (defined $warnValue and $warnValue eq '');
		$critValue = undef if (defined $critValue and $critValue eq '');
		$fatalValue = undef if (defined $fatalValue and $fatalValue eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		# ... unify CIM output variants
		my $useState = $healthState;
		if ($curState) { # ATTENTION: CurrentState is a string !
		    my $currentHealthState = undef;
		    $currentHealthState = currentStateHealthState($curState);
		    $useState = $currentHealthState 
			if (defined $currentHealthState and $currentHealthState > $useState);
		    $useState = $currentHealthState
			if (defined $currentHealthState and $currentHealthState == 0
			and defined $curValue and $curValue == 0);
		}		
		if ($adapterHealthState) {
		    $useState = $adapterHealthState 
			if ($adapterHealthState > $useState);
		}
		my $useWarnLevel = $warnValue;
		$useWarnLevel = $critValue if (!defined $warnValue and defined $fatalValue);
		my $useCriticalLevel = $critValue;
		$useCriticalLevel = $fatalValue if (!defined $warnValue and defined $fatalValue);

		my $isCelsius = 0;
		$isCelsius = 1 if ($baseUnits==2 and !$unitModifier);

		# ... around health status
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus);

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"Sensor",$devid);
			addName("v",$name);
			addCelsius("v",$curValue, $useWarnLevel,$useCriticalLevel) if ($isCelsius);
			addKeyThresholdsUnit("v", "Temperature", "???", 
			    $curValue, $useWarnLevel,$useCriticalLevel) if (!$isCelsius);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"Sensor",$devid);
			addName("l",$name);
			addCelsius("l",$curValue, $useWarnLevel,$useCriticalLevel) if ($isCelsius);
			addKeyThresholdsUnit("l", "Temperature", "???", 
			    $curValue, $useWarnLevel,$useCriticalLevel) if (!$isCelsius);
			$longMessage .= "\n";
		}

		# performance values
		if ($baseUnits == 2 and !$unitModifier) {
		    addTemperatureToPerfdata($name, $curValue, $useWarnLevel, $useCriticalLevel)
			    if (!$main::verboseTable);
		} # else TODO ... baseUnits2String();
	} # foreach class
	addExitCode($tmpExitCode) if ($setExitCode);
	if (! defined $allHealthTempStatus) {
	    $allHealthTempStatus = $tmpCollectedHealthStatus;
	}
  } # getAllTemperatureSensors

  sub getAllPowerSupplies {
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusPower and ($statusPower==1 or $statusPower==2));
	$searchNotifies = 1 if ($setExitCode);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	# ... CIM SVS_PGYPowerProductionSensor
	my $classnm = undef;
	if (!$isiRMC) {
	    $classnm = "SVS_PGYPowerProductionSensor";
	    @classInstances = cimEnumerateClass("SVS_PGYPowerProductionSensor"); 
	    $classnm = "SVS_PGYPowerSupply" if ($#classInstances < 0);
	    @classInstances = cimEnumerateClass("SVS_PGYPowerSupply") if ($#classInstances < 0); # ... ESXi
	} else { #iRMC
	    $classnm = "SVS_iRMCPowerProductionSensor";
	    @classInstances = cimEnumerateClass("SVS_iRMCPowerProductionSensor"); 
	}
	cimPrintClass(\@classInstances, $classnm) if ($classnm);

	# HealthStateComponent
	my %adapter = ();
	%adapter = %$cimSvsPSUAdapters if ($cimSvsPSUAdapters);

	addTableHeader("v","Power Supplies") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $devid = $oneClass{"DeviceID"};
		my $curState = $oneClass{"CurrentState"};		# ... not ESXi, not Agent6.21
		my $healthState = $oneClass{"HealthState"};
		my $curValue = $oneClass{"CurrentReading"};		# ... not ESXi
		my $nomValue = $oneClass{"NominalReading"};		# ... not ESXi
		my $critValue = $oneClass{"UpperThresholdCritical"};	# ... not ESXi
		# ESXi knows "totalOutputPower" (milliWatts)
		my $totalOutMWatt = $oneClass{"TotalOutputPower"};	# ... ESXi
		my $baseUnits = $oneClass{"BaseUnits"};			# ... not ESXi
		my $unitModifier = $oneClass{"UnitModifier"};		# ... not ESXi

		next if (!$name); # CIM provider internal error

		my $adapterHealthState = undef;
		$adapterHealthState = $adapter{$name} if ($cimSvsPSUAdapters);

		$devid = "" if (defined $devid and defined $name
		    and $devid eq $name); # iRMC S4

		$name =~ s/[ ,;=]/_/g;
		$name =~ s/_$//;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$curState = undef if (defined $curState and $curState eq '');
		$healthState = undef if (defined $healthState and $healthState eq '');
		$curValue = undef if (defined $curValue and $curValue eq '');
		$nomValue = undef if (defined $nomValue and $nomValue eq '');
		$critValue = undef if (defined $critValue and $critValue eq '');
		$totalOutMWatt = undef if (defined $totalOutMWatt and $totalOutMWatt eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		# ... unify CIM output variants
		my $useState = $healthState;
		if ($curState) { # ATTENTION: CurrentState is a string !
		    my $currentHealthState = undef;
		    $currentHealthState = currentStateHealthState($curState);
		    $useState = $currentHealthState 
			if (defined $currentHealthState) and $currentHealthState > $useState;
		    $useState = $currentHealthState
			if (defined $currentHealthState and $currentHealthState == 0
			and defined $curValue and $curValue == 0);
		}	
		if ($adapterHealthState) {
		    $useState = $adapterHealthState 
			if ($adapterHealthState > $useState);
		}
		my $useCurValue = $curValue;
		$totalOutMWatt = $totalOutMWatt/1000 if ($totalOutMWatt); # ... ESXi, milli watts
		my $useWarnLevel = $critValue;

		# Units ?
		$unitModifier = 0 if ($unitModifier and $baseUnits == 7); #ERROR in Agents !!!
		if ($baseUnits and $unitModifier and $baseUnits == 7 and $unitModifier == 2) { 
		    # ATTENTION: There is an error in Win-Agent 6.20 ... with wrong unitModifier
		    $useCurValue = $curValue * 100 if ($curValue);
		    $critValue = $critValue * 100 if ($critValue);
		}
		my $isWatt = 0;
		$isWatt = 1 if (!defined $baseUnits or $baseUnits == 7); # ESXi has no baseUnits

		# ... around health status
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus);

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"PSU",$devid);
			addName("v",$name);
			addKeyWatt("v", "CurrentLoad", $useCurValue, undef, undef, undef, $critValue)
			    if ($isWatt);
			addKeyThresholdsUnit("v", "CurrentLoad", "???", 
			    $useCurValue, undef, undef, undef, $critValue) if (!$isWatt);
			addKeyWatt("v", "Max", $totalOutMWatt, undef, undef, undef, undef) 
			    if (!$useCurValue); # ESXi
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"PSU",$devid);
			addName("l",$name);
			addKeyWatt("l", "CurrentLoad", $useCurValue, undef, undef, undef, $critValue)
			    if ($isWatt);
			addKeyThresholdsUnit("l", "CurrentLoad", "???", 
			    $useCurValue, undef, undef, undef, $critValue) if (!$isWatt);
			addKeyWatt("l", "Max", $totalOutMWatt, undef, undef, undef, undef)
			    if (!$useCurValue); # ESXi
			$longMessage .= "\n";
		}

	} # foreach class
	if (! defined $allHealthPowerStatus) {
	    $allHealthPowerStatus = $tmpCollectedHealthStatus;
	}
	if ($setExitCode and !$isiRMC) {
	    addComponentStatus("m", "PSU",healthStateString($tmpCollectedHealthStatus));
	}
	addExitCode($tmpExitCode) if ($setExitCode);
  } # getAllPowerSupplies

  sub getAllPowerConsumption {
	#
	# ATTENTION:	Win6.20 has in "Total Power" a different value than in "Total Power Out"
	#		The "Total Power" value is there the same as the SNMP value
	#		on a Win6.30.2 no "Total Power Out" was set
	#
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	my $verbose = 0;
	$searchNotifies = 1 if (defined $statusPower and ($statusPower==1 or $statusPower==2));
	$searchNotifies = 1 if ($setExitCode);
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYPowerConsumptionSensor"); 
	    cimPrintClass(\@classInstances, "SVS_PGYPowerConsumptionSensor");
	} else { # iRMC
	    @classInstances = cimEnumerateClass("SVS_iRMCPowerConsumptionSensor"); 
	    cimPrintClass(\@classInstances, "SVS_iRMCPowerConsumptionSensor");
	}

	if ($#classInstances < 0) {
	    addPowerConsumptionToPerfdata(0, undef, undef, undef, undef)
		if ($is2014Profile and $optChkPower == 999); # if this is just a temporary unavailability
	    return;
	}

	# HealthStateComponent
	#[3 00] $statusPowerLevel ??? ... this is only one value
	if (($searchNotifies or $verbose) and defined $statusPowerLevel) {
	    my $localStateString = healthStateString($statusPowerLevel);
	    addTableHeader("v","Power Level");
	    if ($verbose) {
		addStatusTopic("v",$localStateString,"PowerLevel",undef);
		$variableVerboseMessage .= "\n";
	    } else { # searchNotifies
		addStatusTopic("l",$localStateString,"PowerLevel",undef);
		$longMessage .= "\n";
	    }
	}

	addTableHeader("v","Power Consumption") if ($verbose and $#classInstances >= 0);
	my $totalPower = undef;
	my $totalPowerOut = undef;
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $isTotal = 0;
		my $isTotalOut = 0;
		my $devid = $oneClass{"DeviceID"};
		my $curState = $oneClass{"CurrentState"};		
		my $healthState = $oneClass{"HealthState"};
		my $curValue = $oneClass{"CurrentReading"};
		my $baseUnits = $oneClass{"BaseUnits"};		
		my $unitModifier = $oneClass{"UnitModifier"};	

		$isTotalOut = 1 if ($name and $name eq "Total Power Out");
		$isTotal = 1 if ($name and $name eq "Total Power");

		next if (!$name or ($name and !$isTotal and $isTotalOut and !$verbose));
		    # empty name is a CIM provider internal error

		$devid = "" if (defined $devid and defined $name
		    and $devid eq $name); # iRMC S4

		$name =~ s/[ ,;=]/_/g;
		$name =~ s/_$//;
		$totalPower = $curValue if ($isTotal);
		$totalPowerOut = $curValue if ($isTotalOut);

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$curState = undef if (defined $curState and $curState eq '');
		$healthState = undef if (defined $healthState and $healthState eq '');
		$curValue = undef if (defined $curValue and $curValue eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		# states 
		my $useState = $healthState;
		if ($curState) { # ATTENTION: CurrentState is a string !
		    my $currentHealthState = undef;
		    $currentHealthState = currentStateHealthState($curState);
		    $useState = $currentHealthState 
			if (defined $currentHealthState) and $currentHealthState > $useState;
		    $useState = $currentHealthState
			if (defined $currentHealthState and $currentHealthState == 0
			and defined $curValue and $curValue == 0);
		    $useState = 0 if ($isiRMC and defined $curValue and $curValue == 0);
		}	

		# units
		my $isWatt = 0;
		$isWatt = 1 if ($baseUnits == 7 and !$unitModifier);

		# ... around health status
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode and ($isTotal or $isTotalOut));
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus and ($isTotal or $isTotalOut));

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"PowerCons",$devid);
			addName("v",$name);
			addKeyWatt("v", "CurrentReading", $curValue, undef, undef, undef, undef)
			    if ($isWatt);
			addKeyThresholdUnit("v", "CurrentReading", "???", $curValue, undef, undef, undef, undef)
			    if (!$isWatt);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"PowerCons",$devid);
			addName("l",$name);
			addKeyWatt("l", "CurrentReading", $curValue, undef, undef, undef, undef)
			    if ($isWatt);
			addKeyThresholdUnit("l", "CurrentReading", "???", $curValue, undef, undef, undef, undef)
			    if (!$isWatt);
			$longMessage .= "\n";
		}

	} # foreach class
	if ($totalPower or $totalPowerOut) {
		my $curValue = $totalPower;
		$curValue = $totalPowerOut if (!$totalPower 
		    or ($totalPowerOut and $totalPowerOut > $totalPower));
		addPowerConsumptionToPerfdata($curValue, undef, undef, undef, undef);
	}
	if ($isiRMC and $noSummaryStatus) {
	    $allHealthPowerStatus = $tmpCollectedHealthStatus
		if (!defined $allHealthPowerStatus 
		or $allHealthPowerStatus < $tmpCollectedHealthStatus);
	}
	if ($setExitCode  and !$isiRMC) {
	    addComponentStatus("m", "PowerConsumption",healthStateString($tmpCollectedHealthStatus));
	}
	addExitCode($tmpExitCode) if ($setExitCode);

  } # getAllPowerConsumption

  sub getAllCPU {
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allCPUStatus and ($allCPUStatus==1 or $allCPUStatus==2));
	$searchNotifies = 1 if (!defined $allCPUStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYProcessor");
	    cimPrintClass(\@classInstances, "SVS_PGYProcessor");
	} else { # iRMC
	    @classInstances = cimEnumerateClass("SVS_iRMCProcessor");
	    cimPrintClass(\@classInstances, "SVS_iRMCProcessor");
	}
	addTableHeader("v","CPU Table") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $elementName = $oneClass{"ElementName"};
		my $devid = $oneClass{"DeviceID"};
		my $healthState = $oneClass{"HealthState"};
		my $name = $oneClass{"Name"}; # ... not ESXi
		my $family = $oneClass{"Family"}; # ... ESXi
		my $curClockSpeed = $oneClass{"CurrentClockSpeed"}; #MHz
		my $maxClockSpeed = $oneClass{"MaxClockSpeed"}; #MHz
		my $extBusClockSpeed = $oneClass{"ExternalBusClockSpeed"}; #MHz
		my $baseUnits = $oneClass{"BaseUnits"}; # ?? not found
		my $unitModifier = $oneClass{"UnitModifier"}; #  ?? not found

		next if (!$elementName); # CIM provider internal error

		$devid = "" if (defined $devid and defined $elementName
		    and $devid eq $elementName); # iRMC S4

		$elementName =~ s/[ ,;=]/_/g;
		$elementName =~ s/_$//;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$healthState = undef if (defined $healthState and $healthState eq '');
		$name = undef if (defined $name and $name eq '');
		$family = undef if (defined $family and $family eq '');
		$curClockSpeed = undef if (defined $curClockSpeed and $curClockSpeed eq '');
		$maxClockSpeed = undef if (defined $maxClockSpeed and $maxClockSpeed eq '');
		$extBusClockSpeed = undef if (defined $extBusClockSpeed and $extBusClockSpeed eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		# ... unify CIM output variants
		my $useState = $healthState;
		my $useModel = $name;
		$useModel = $family if (!defined $name);
		my $useModelString = undef;
		$useModelString = $name;
		$useModelString = cpuModelString($useModel) if (!defined $name);

		# ... around health status
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus);

		# units ... There are no baseUnits and no unitModifier

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"CPU",$devid);
			addName("v",$elementName);
			addProductModel("v", undef, $useModelString);
			addKeyMHz("v", "Speed", $curClockSpeed);
			addKeyMHz("v", "MaxClockSpeed", $maxClockSpeed);
			addKeyMHz("v", "ExternalBusClockSpeed", $extBusClockSpeed);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"CPU",$devid);
			addName("l",$elementName);
			addProductModel("l", undef, $useModelString);
			addKeyMHz("l", "Speed", $curClockSpeed);
			$longMessage .= "\n";
		}

	} # foreach class
	addExitCode($tmpExitCode) if ($setExitCode);
	if (!defined $allHealthCPUStatus) {
	    $allHealthCPUStatus = $tmpCollectedHealthStatus;
	}
  } # getAllCPU

  sub getAllVoltages {
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allVoltageStatus and ($allVoltageStatus==1 or $allVoltageStatus==2));
	$searchNotifies = 1 if (!defined $allVoltageStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYVoltageSensor");
	    cimPrintClass(\@classInstances, "SVS_PGYVoltageSensor");
	} else {
	    @classInstances = cimEnumerateClass("SVS_iRMCVoltageSensor");
	    cimPrintClass(\@classInstances, "SVS_iRMCVoltageSensor");
	}

	# HealthStateComponent
	my %adapter = ();
	%adapter = %$cimSvsVoltAdapters if ($cimSvsVoltAdapters);

	addTableHeader("v","Voltages") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $devid = $oneClass{"DeviceID"};
		my $curState = $oneClass{"CurrentState"}; # ... not ESXi
		my $healthState = $oneClass{"HealthState"};
		my $curValue = $oneClass{"CurrentReading"};
		my $lowerValue = $oneClass{"LowerThresholdCritical"}; # ... not ESXi
		my $upperValue = $oneClass{"UpperThresholdCritical"}; # ... not ESXi
		my $nomValue = $oneClass{"NominalReading"};	     # ... not ESXi
		my $baseUnits = $oneClass{"BaseUnits"};
		my $unitModifier = $oneClass{"UnitModifier"};

		next if (!$name); # CIM provider interal error

		my $adapterHealthState = undef;
		$adapterHealthState = $adapter{$name} if ($cimSvsVoltAdapters);

		$devid = "" if (defined $devid and defined $name
		    and $devid eq $name); # iRMC S4

		$name =~ s/[ ,;=]/_/g;
		$name =~ s/_$//;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$curState = undef if (defined $curState and $curState eq '');
		$healthState = undef if (defined $healthState and $healthState eq '');
		$curValue = undef if (defined $curValue and $curValue eq '');
		$nomValue = undef if (defined $nomValue and $nomValue eq '');
		$lowerValue = undef if (defined $lowerValue and $lowerValue eq '');
		$upperValue = undef if (defined $upperValue and $upperValue eq '');
		$baseUnits = undef if (defined $baseUnits and $baseUnits eq '');
		$unitModifier = undef if (defined $unitModifier and $unitModifier eq '');

		$unitModifier = negativeValueCheck($unitModifier);
		# OPEN - LINUX Agent V6.30.04 error ... unsigned int instead of -2
		my $isVolt = 0;
		my $ismVolt = 0;
		$isVolt = 1 if ($baseUnits==5 and $unitModifier and $unitModifier==-2);
		$ismVolt = 1 if ($baseUnits==5 and $unitModifier and $unitModifier==-3);

		# ... unify CIM output variants
		my $useState = $healthState;
		if ($curState) { # ATTENTION: CurrentState is a string !
		    my $currentHealthState = undef;
		    $currentHealthState = currentStateHealthState($curState);
		    $useState = $currentHealthState 
			if (defined $currentHealthState) and $currentHealthState > $useState;
		}	
		if ($adapterHealthState) {
		    $useState = $adapterHealthState 
			if ($adapterHealthState > $useState);
		}

		# 
		my $localState = healthStateExitCode($useState);
		my $localStateString = healthStateString($useState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $useState if ($useState > $tmpCollectedHealthStatus);

		if ($baseUnits == 5 and $unitModifier == -2 ) {
		    # value * 10^-2
		    $curValue = $curValue / 100 if ($curValue);
		    $lowerValue = $lowerValue / 100 if ($lowerValue);
		    $upperValue = $upperValue / 100 if ($upperValue);
		    $nomValue = $nomValue / 100 if ($nomValue);
		}

		my $maxValue = $nomValue;
		$maxValue = $upperValue if (!defined $maxValue or ($upperValue and $upperValue > $maxValue));

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"Voltage",$devid);
			addName("v",$name);
			addVolt("v", $curValue, undef, $lowerValue, undef, $maxValue)
				if ($isVolt);
			addmVolt("v", $curValue, undef, $lowerValue, undef, $maxValue)
				if ($ismVolt);
			addKeyThresholdsUnit("v", "Current", "???", 
				$curValue, undef, $lowerValue, undef, $maxValue) if (!$isVolt and !$ismVolt);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"Voltage",$devid);
			addName("l",$name);
			addVolt("l", $curValue, undef, $lowerValue, undef, $maxValue)
				if ($isVolt);
			addmVolt("l", $curValue, undef, $lowerValue, undef, $maxValue)
				if ($ismVolt);
			addKeyThresholdsUnit("l", "Current", "???", 
				$curValue, undef, $lowerValue, undef, $maxValue) if (!$isVolt and !$ismVolt);
			$longMessage .= "\n";
		}

	} # foreach class
	addExitCode($tmpExitCode) if ($setExitCode);
	if (!defined $allHealthVoltageStatus) {
	    $allHealthVoltageStatus = $tmpCollectedHealthStatus;
	}
  } # getAllVoltages

  sub getAllMemoryModules {
	my $setExitCode = shift;
	my $tmpExitCode = 3;
	my $tmpCollectedHealthStatus = 0;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allMemoryStatus and ($allMemoryStatus==1 or $allMemoryStatus==2));
	$searchNotifies = 1 if (!defined $allMemoryStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	my @classInstances = ();
	if (!$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYPhysicalMemory");
	    cimPrintClass(\@classInstances, "SVS_PGYPhysicalMemory");
	} else { # iRMC
	    @classInstances = cimEnumerateClass("SVS_iRMCPhysicalMemory");
	    cimPrintClass(\@classInstances, "SVS_iRMCPhysicalMemory");
	}

	addTableHeader("v","Memory Modules Table") if ($verbose);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $tag = $oneClass{"Tag"};
		my $type = $oneClass{"MemoryType"};
		
		#my $curState = $oneClass{"CurrentState"}; # ... not ESXi
		my $healthState = $oneClass{"HealthState"};
		my $capacityBytes = $oneClass{"Capacity"};
		my $frequenzy = $oneClass{"MemModuleFrequency"}; # not ESXi
		my $maxfrequenzy = $oneClass{"MemModuleMaxFrequency"}; # not ESXi
		my $serial = $oneClass{"SerialNumber"};
		# This class has NO BaseUnit and UnitModifier !!!

		next if (!$name); # CIM provider internal error
		
		$name =~ s/[ ,;=]/_/g;
		$name =~ s/_$//;
		$serial =~ s/\s+$// if ($serial); # remove blanks at the end

		$tag =~ m/.*([0-9])$/;
		my $devid = $1;

		# ... reset empty numeric values (disadvantage of perl-hash-tables)
		$healthState = undef if (defined $healthState and $healthState eq '');
		$type = undef if (defined $type and $type eq '');
		$capacityBytes = undef if (defined $capacityBytes and $capacityBytes eq '');
		$frequenzy = undef if (defined $frequenzy and $frequenzy eq '');
		$maxfrequenzy = undef if (defined $maxfrequenzy and $maxfrequenzy eq '');

		my $capacity = 0;
		if ($capacityBytes) {
		    if (!$isiRMC) {
			$capacity = ($capacityBytes - $capacityBytes%1024) / 1024; # for KB
			$capacity = ($capacity - $capacity%1024) / 1024 if ($capacity); # for MB
		    } else { # iRMC
			$capacity = $capacityBytes; # 2014-04: MB guess for iRMC S4 - checked in UI
			if ($capacityBytes > 1024*1024) { # future
			    $capacity = ($capacityBytes - $capacityBytes%1024) / 1024; # for KB
			    $capacity = ($capacity - $capacity%1024) / 1024 if ($capacity); # for MB
			}
		    }
		} #capacityBytes

		# ... around health status
		my $localState = healthStateExitCode($healthState);
		my $localStateString = healthStateString($healthState);
		$tmpExitCode = addTmpExitCode($localState, $tmpExitCode) if ($setExitCode);
		$tmpCollectedHealthStatus = $healthState if ($healthState > $tmpCollectedHealthStatus);

		my $typeString = memoryTypeString($type);

		# verbose
		if ($verbose) {
			addStatusTopic("v",$localStateString,"Memory",$devid);
			addName("v",$name);
			addKeyLongValue("v","Type", $typeString);
			addSerialIDs("v", $serial, undef);
			addKeyMB("v","Capacity", $capacity);
			addKeyMHz("v","Frequency", $frequenzy);
			addKeyMHz("v","Frequency-Max", $maxfrequenzy);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",$localStateString,"Memory",$devid);
			addName("l",$name);
			addKeyLongValue("l","Type", $typeString);
			addSerialIDs("l", $serial, undef);
			addKeyMB("l","Capacity", $capacity);
			addKeyMHz("l","Frequency", $frequenzy);
			addKeyMHz("l","Frequency-Max", $maxfrequenzy);
			$longMessage .= "\n";
		}
	} # foreach class
	addExitCode($tmpExitCode) if ($setExitCode);
	if (!defined $allHealthMemoryStatus) {
	    $allHealthMemoryStatus = $tmpCollectedHealthStatus;
	}
  } # getAllMemoryModules

  sub getAllStorageAdapter {
	return if (!defined $statusMassStorage or !$optChkStorage or !$cimSvsRAIDAdapters);
	my %adapter = %$cimSvsRAIDAdapters;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusMassStorage and ($statusMassStorage==1 or $statusMassStorage==2));
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	addTableHeader("v","Mass Storage Adapter");
	foreach my $key (keys %adapter) {
		#print $key,": ",$adapter{$key},"\n";
		my $localState = healthStateExitCode($adapter{$key});
		if ($verbose) {
			addStatusTopic("v",healthStateString($adapter{$key}),"Storage",'');
			addName("v",$key);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",healthStateString($adapter{$key}),"Storage",'');
			addName("l",$key);
			$longMessage .= "\n";
		}
	}
  } #getAllStorageAdapter

  sub getAllDrvMonAdapter {
	return if (!defined $statusDrvMonitor or !$optChkDrvMonitor or !$cimSvsDrvMonAdapters);
	my %adapter = %$cimSvsDrvMonAdapters;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusDrvMonitor and ($statusDrvMonitor==1 or $statusDrvMonitor==2));
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);

	addTableHeader("v","Driver Monitor Adapter");
	foreach my $key (keys %adapter) {
		#print $key,": ",$adapter{$key},"\n";
		my $localState = healthStateExitCode($adapter{$key});
		if ($verbose) {
			addStatusTopic("v",healthStateString($adapter{$key}),"Driver",'');
			addName("v",$key);
			$variableVerboseMessage .= "\n";
		} elsif ($searchNotifies and ($localState == 1 or $localState == 2)) {
			addStatusTopic("l",healthStateString($adapter{$key}),"Driver",'');
			addName("l",$key);
			$longMessage .= "\n";
		}
	}
  } #getAllDrvMonAdapter
  sub getUpdateDiffTable {
	my @classInstances = ();

	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;

	@classInstances = cimEnumerateClass("SVS_PGYUpdateDiff");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateDiff");
	my $printLimit = 10;
	my $printIndex = 0;
	$printLimit = 0 if ($main::verbose >= 3);
	my @severityText = ( "optional",
	     "recommended", "mandatory", "..unexpected..",
	);
	my @rebootText = ( "no", 
	    "immediate", "asConfigured", "dynamic", "..unexpected..",
	);
	my $save_variableVerboseMessage = $variableVerboseMessage;
	$variableVerboseMessage = '';
	foreach my $refClass (@classInstances) {
	    next if !$refClass;
	    my %oneClass = %{$refClass};
	    my $componentPath = $oneClass{"ComponentPath"};
	    my $componentVersion = $oneClass{"ComponentVersion"};
	    my $installedVersion = $oneClass{"InstalledVersion"};
	    my $repos2InstRanking = $oneClass{"Repos2InstRanking"};
	    #
	    next if (!$componentVersion or !$installedVersion);
	    next if ($repos2InstRanking and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );
	    #
	    my $updateVendorSeverity = $oneClass{"UpdateVendorSeverity"};
	    my $isMandatoryComponent = $oneClass{"IsMandatoryComponent"};
	    my $downloadSize = $oneClass{"DownloadSize"};
	    my $installDuration = $oneClass{"InstallDuration"};
	    my $rebootRequired = $oneClass{"RebootRequired"};
	    my $vendor = $oneClass{"Vendor"};
	    $updateVendorSeverity = 3 
		if (!defined $updateVendorSeverity or $updateVendorSeverity < 0 or $updateVendorSeverity > 2);
	    $rebootRequired = 4 if (!defined $rebootRequired or $rebootRequired < 0 or $rebootRequired > 3);
	    #addExitCode($updateVendorSeverity);

	    #
	    if (!$printLimit or $printIndex < $printLimit) { # stdout
		addStatusTopic("l",$severityText[$updateVendorSeverity], "",undef);
		    addKeyLongValue("l", "Path", $componentPath);
		addMessage("l", "\n");
		addMessage("l", "#\t");
		    addKeyLongValue("l", "Installed", $installedVersion);
		addMessage("l", "\n");
		addMessage("l", "#\t");
		    addKeyLongValue("l", "Available", $componentVersion);
		addMessage("l", "\n");
		if ($main::verbose >= 2) {
		    addMessage("l", "#\t");
			addKeyLongValue("l", "Vendor", $vendor);
		    addMessage("l", "\n");
		    addMessage("l", "#\t");
			addKeyValue("l", "Mandatory", $isMandatoryComponent);
			addKeyValue("l", "Severity", $severityText[$updateVendorSeverity]);
		    addMessage("l", "\n");
		    addMessage("l", "#\t");
			addKeyMB("l", "Size", $downloadSize);
			addKeyValueUnit("l", "Duration", $installDuration, "sec");
			addKeyValue("l", "RebootMode", $rebootText[$rebootRequired]);
		    addMessage("l", "\n");
		}
		$printIndex++;
	    }
	    if ($optOutdir) { # file
		addMessage("v",$componentPath);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Installed", $installedVersion);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Available", $componentVersion);
		addMessage("v", "\n");
		
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Vendor", $vendor);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyValue("v", "Mandatory", $isMandatoryComponent);
		    addKeyValue("v", "Severity", $severityText[$updateVendorSeverity]);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyMB("v", "Size", $downloadSize);
		    addKeyValueUnit("v", "Duration", $installDuration, "sec");
		    addKeyValue("v", "RebootMode", $rebootText[$rebootRequired]);
		addMessage("v", "\n");		
	    }
	} # foreach
	addMessage("l", "#...\n") if ($printLimit and $printLimit == $printIndex);

	if ($optOutdir) {
	    writeTxtFile($fileHost, "DIFF", $variableVerboseMessage);
	}
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # getUpdateDiffTable

  sub getUpdateInstTable {
	my @classInstances = ();

	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;

	@classInstances = cimEnumerateClass("SVS_PGYUpdateDiff");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateDiff");
	my $printLimit = 10;
	my $printIndex = 0;
	$printLimit = 0 if ($main::verbose >= 3);
	my @severityText = ( "optional",
	     "recommended", "mandatory", "..unexpected..",
	);
	my @rebootText = ( "no", 
	    "immediate", "asConfigured", "dynamic", "..unexpected..",
	);
	my $save_variableVerboseMessage = $variableVerboseMessage;
	$variableVerboseMessage = '';
	foreach my $refClass (@classInstances) {
	    next if !$refClass;
	    my %oneClass = %{$refClass};
	    my $componentPath = $oneClass{"ComponentPath"};
	    my $componentVersion = $oneClass{"ComponentVersion"};
	    my $installedVersion = $oneClass{"InstalledVersion"};
	    my $repos2InstRanking = $oneClass{"Repos2InstRanking"};
	    #
	    next if (!$installedVersion);
	    my $uptodate = 0;
	    $uptodate = 1 if ($repos2InstRanking and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );
	    #
	    my $updateVendorSeverity = $oneClass{"UpdateVendorSeverity"};
	    my $isMandatoryComponent = $oneClass{"IsMandatoryComponent"};
	    my $downloadSize = $oneClass{"DownloadSize"};
	    my $installDuration = $oneClass{"InstallDuration"};
	    my $rebootRequired = $oneClass{"RebootRequired"};
	    my $vendor = $oneClass{"Vendor"};
	    $updateVendorSeverity = 3 
		if (!defined $updateVendorSeverity or $updateVendorSeverity < 0 or $updateVendorSeverity > 2);
	    $rebootRequired = 4 if (!defined $rebootRequired or $rebootRequired < 0 or $rebootRequired > 3);
	    #addExitCode($updateVendorSeverity);
	    #

	    if (!$printLimit or $printIndex < $printLimit) { # stdout
		addStatusTopic("l",$severityText[$updateVendorSeverity], "",undef) if (!$uptodate);
		addStatusTopic("l","uptodate", "",undef) if ($uptodate);
		    addKeyLongValue("l", "Path", $componentPath);
		addMessage("l", "\n");
		addMessage("l", "#\t");
		    addKeyLongValue("l", "Installed", $installedVersion);
		addMessage("l", "\n");
		addMessage("l", "#\t");
		    addKeyLongValue("l", "Available", $componentVersion);
		addMessage("l", "\n");
		if ($main::verbose >= 2) {
		    addMessage("l", "#\t");
			addKeyLongValue("l", "Vendor", $vendor);
		    addMessage("l", "\n");
		    addMessage("l", "#\t");
			addKeyValue("l", "Mandatory", $isMandatoryComponent);
			addKeyValue("l", "Severity", $severityText[$updateVendorSeverity]);
		    addMessage("l", "\n");
		    addMessage("l", "#\t");
			addKeyMB("l", "Size", $downloadSize);
			addKeyValueUnit("l", "Duration", $installDuration, "sec");
			addKeyValue("l", "RebootMode", $rebootText[$rebootRequired]);
		    addMessage("l", "\n");
		}
		$printIndex++;
	    }
	    if ($optOutdir) { # file
		addMessage("v",$componentPath);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyValue("v", "UpToDate", "yes") if ($uptodate);
		    addKeyValue("v", "UpToDate", "no") if (!$uptodate);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Installed", $installedVersion);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Available", $componentVersion);
		addMessage("v", "\n");
		
		addMessage("v", "#\t");
		    addKeyLongValue("v", "Vendor", $vendor);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyValue("v", "Mandatory", $isMandatoryComponent);
		    addKeyValue("v", "Severity", $severityText[$updateVendorSeverity]);
		addMessage("v", "\n");
		addMessage("v", "#\t");
		    addKeyMB("v", "Size", $downloadSize);
		    addKeyValueUnit("v", "Duration", $installDuration, "sec");
		    addKeyValue("v", "RebootMode", $rebootText[$rebootRequired]);
		addMessage("v", "\n");
		
	    }
	} # foreach
	addMessage("l", "#...\n") if ($printLimit and $printLimit == $printIndex);

	if ($optOutdir) {
	    writeTxtFile($fileHost, "INST", $variableVerboseMessage);
	}
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # getUpdateInstTable

  sub getUpdateStatus {
	if ($#cimSvsComputerSystem < 0 and !$isiRMC ) {
	    @cimSvsComputerSystem = cimEnumerateClass("SVS_PGYComputerSystem");
	    if (!@cimSvsComputerSystem) {
		    addMessage("m", "Unable to get ServerView CIM Classes\n");
		    return 2;
	    }
	    cimPrintClass(\@cimSvsComputerSystem, "SVS_PGYComputerSystem");
	} 
	if ($#cimSvsComputerSystem < 0 and $isiRMC ) {
	    @cimSvsComputerSystem = cimEnumerateClass("SVS_iRMCBaseServer");
	    if (!@cimSvsComputerSystem) {
		    addMessage("m", "Unable to get ServerView CIM Classes\n");
		    return 2;
	    }
	    cimPrintClass(\@cimSvsComputerSystem, "SVS_iRMCBaseServer");
	} 
	my $updStatus = 3;
	if ($#cimSvsComputerSystem >= 0) {
	    my $ref1stClass = $cimSvsComputerSystem[0]; # There should be only one instance !
	    my %compSystem = %{$ref1stClass};
	    $updStatus = $compSystem{"ServerUpdateStatus"};
	    $updStatus = undef if (defined $updStatus and $updStatus =~ m/^\s*$/);
	}
	my $tmpExitCode = 3;
	$updStatus = 3 if (!defined $updStatus or $updStatus > 3 or $updStatus < 0);
	if (defined $updStatus) {
	    $tmpExitCode = $updStatus; #TOBECHECKED in Agent - Value 3 should be unknown
	    addComponentStatus("m", "UpdateStatus",$state[$tmpExitCode]);
	}
	addExitCode($tmpExitCode);
	if ((!$isiRMC and $updStatus and $updStatus != 3 and $optChkUpdDiffList) 
	or  (!$isiRMC and defined $updStatus and $updStatus != 3 and $optChkUpdInstList)) {
	    getUpdateDiffTable() if ($optChkUpdDiffList);
	    getUpdateInstTable() if ($optChkUpdInstList);
	}
  } #getUpdateStatus

#########################################################################
  sub getEnvironment {
	return if (!defined $statusEnv and !$oldAgentException);
	# FanSensors
	#	if chkenv-fans is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-Fans-Status !!!
	#
	#	Enter into details only if system ,env or env-fan is selected AND the status of
	#	All-Fans is not-ok !
	if ($optChkEnvironment or $optChkEnv_Fan) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allFanStatus) { # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkEnv_Fan and !$optChkEnvironment);
			$setExitCode = 1 if ($isiRMC and $noSummaryStatus);
			$setExitCode = 1 if ($isiRMC and defined $statusEnv); # corrupt HealthStateComponent 7.6x
			$getInfos = 1 if ($optChkEnv_Fan and !$optChkEnvironment); 
			$getInfos = 1 if (!defined $statusEnv or $statusEnv==1 or $statusEnv==2);
		}
		$getInfos = 1 if (defined $allFanStatus and ($allFanStatus==1 or $allFanStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		$getInfos = 1 if (!$optChkEnvironment and $optChkEnv_Fan and $optChkFanPerformance);
		getAllFanSensors($setExitCode) if ($getInfos);
		addComponentStatus("m", "Fans",healthStateString($allHealthFanStatus)) 
			if (!$optChkEnvironment and defined $allHealthFanStatus);
	}
	# TemperatureSensors
	#	if chkenv-temp is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-Temp-Status !!!
	#
	#	Enter into details only if system ,env or env-temp is selected.
	#	This is independent on status since the performance values should be fetched everytime.
	if ($optChkEnvironment or $optChkEnv_Temp) {
		my $setExitCode = 0;
		if (!defined $allTempStatus) { # # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkEnv_Temp and !$optChkEnvironment);
			$setExitCode = 1 if ($isiRMC and $noSummaryStatus);
		}
		getAllTemperatureSensors($setExitCode);
		addComponentStatus("m", "TemperatureSensors",healthStateString($allHealthTempStatus)) 
			if (!$optChkEnvironment and defined $allHealthTempStatus);
	}
  } #getEnvironment

  sub getPower {
	return if (!defined $statusPower and !$oldAgentException);
	# PowerSupplies
	#	if chkmemmod is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-PSU-Status !!!
	#
	#	Enter into details only if the status of All-PSU is not-ok !
	if ($optChkPower) {
		my $getInfos = 0;
		my $setExitCode = 0;
		$getInfos = 1 if (!defined $statusPower or $statusPower==1 or $statusPower==2);
		$getInfos = 1 if ($main::verbose >= 2);
		$setExitCode = 1 if (!defined $statusPower); # older ESXi, iRMC S4
		getAllPowerSupplies($setExitCode) if ($getInfos);
	}
	# PowerConsumption
	#	always
	if ($optChkPower) {
		my $setExitCode = 0;
		$setExitCode = 1 if (!defined $statusPower); # older ESXi, iRMC S4
		getAllPowerConsumption($setExitCode);
	}
	my $notify = 0;
	$notify = 1 if (defined $statusPower
	    and ($statusPower == 1 or $statusPower == 2) );
	if ($cimSvsOtherPowerAdapters and   ($main::verbose >= 2 or $notify) 
	and $optChkPower)
	{
		my %adapter = %$cimSvsOtherPowerAdapters;
		addTableHeader("v","Other Power Components") if ($main::verbose >=2);
		foreach my $key (keys %adapter) {
			#print $key,": ",$adapter{$key},"\n";
			next if (!$key); # never reached point
			my $useState = $adapter{$key};
			my $localStateString = healthStateString($useState);
			my $localState = healthStateExitCode($adapter{$key});
			if ($main::verbose >= 2) {
			    addStatusTopic("v",$localStateString,"PowerComponent",'');
			    addName("v",$key);
			    $variableVerboseMessage .= "\n";
			}
			elsif ($localState == 1 or $localState == 2) {
			    addStatusTopic("l",$localStateString,"PowerComponent",'');
			    addName("l",$key);
			    $longMessage .= "\n";
			} # warn, error
		} # loop
	} # other adapters
  } #getPower

  sub getSystemBoard {
	return if (!defined $statusSystemBoard  and !$oldAgentException);
	# CPU
	#	if chkcpu is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-CPU-Status !!!
	#
	#	Enter into details only if the status of All-CPU is not-ok !
	if ($optChkSystem or $optChkHardware or $optChkCPU) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allCPUStatus) { # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkCPU and !$optChkHardware and !$optChkSystem);
			$setExitCode = 1 if ($isiRMC and $noSummaryStatus);
			$getInfos = 1 if ($optChkCPU and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allCPUStatus and ($allCPUStatus==1 or $allCPUStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllCPU($setExitCode) if ($getInfos);
		addComponentStatus("m", "CPU",healthStateString($allHealthCPUStatus))
			if (!$optChkSystem and !$optChkHardware and defined $allHealthCPUStatus);

	}
	# Voltage
	#	if chkvoltage is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-Volt-Status !!!
	#
	#	Enter into details only if the status of All-Votl is not-ok !
	if ($optChkSystem or $optChkHardware or $optChkVoltage) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allVoltageStatus) { # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkVoltage and !$optChkHardware and !$optChkSystem);
			$setExitCode = 1 if ($isiRMC and $noSummaryStatus);
			$getInfos = 1 if ($optChkVoltage and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allVoltageStatus and ($allVoltageStatus==1 or $allVoltageStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllVoltages($setExitCode) if ($getInfos);
		addComponentStatus("m", "Voltages",healthStateString($allHealthVoltageStatus))
			if (!$optChkSystem  and !$optChkHardware and defined $allHealthVoltageStatus);
	}
	# MemoryModules
	#	if chkmemmod is entered and it is "old" ESXi provider than the exitcode
	#	nust be calculated to get All-Mem-Status !!!
	#
	#	Enter into details only if the status of All-MemMod is not-ok !
	if ($optChkSystem or $optChkHardware or $optChkMemMod) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allMemoryStatus) { # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkMemMod and !$optChkHardware and !$optChkSystem);
			$setExitCode = 1 if ($isiRMC and $noSummaryStatus);
			$getInfos = 1 if ($optChkMemMod and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allMemoryStatus and ($allMemoryStatus==1 or $allMemoryStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllMemoryModules($setExitCode) if ($getInfos);
		addComponentStatus("m", "MemoryModules",healthStateString($allHealthMemoryStatus))
			if (!$optChkSystem  and !$optChkHardware and defined $allHealthMemoryStatus);
	}
	# Other SystemBoard Adapters ?
	my $notify = 0;
	$notify = 1 if (defined $statusSystemBoard 
	    and ($statusSystemBoard == 1 or $statusSystemBoard == 2)
	    and !$allVoltageStatus and !$allCPUStatus and !$allMemoryStatus);
	if ($cimSvsOtherSystemBoardAdapters and   ($main::verbose >= 2 or $notify) 
	and ($optChkSystem or $optChkHardware))
	{
		my %adapter = %$cimSvsOtherSystemBoardAdapters;
		addTableHeader("v","Other  System Board Adapters") if ($main::verbose >=2);
		foreach my $key (keys %adapter) {
			#print $key,": ",$adapter{$key},"\n";
			next if (!$key); # never reached point
			my $useState = $adapter{$key};
			my $localStateString = healthStateString($useState);
			my $localState = healthStateExitCode($adapter{$key});
			if ($main::verbose >= 2) {
			    addStatusTopic("v",$localStateString,"SystemBoardAdapter",'');
			    addName("v",$key);
			    $variableVerboseMessage .= "\n";
			}
			elsif ($localState == 1 or $localState == 2) {
			    addStatusTopic("l",$localStateString,"SystemBoardAdapter",'');
			    addName("l",$key);
			    $longMessage .= "\n";
			} # warn, error
		} # loop
	} # other adapters
  } #getSystemBoard

  sub getStorage {
	return if (!defined $statusMassStorage or !$optChkStorage or !$cimSvsRAIDAdapters);

	getAllStorageAdapter();
  } #getStorage
  sub getDrvMonitor {
	return if (!defined $statusDrvMonitor or !$optChkDrvMonitor or !$cimSvsDrvMonAdapters);
	getAllDrvMonAdapter();
  } #getDrvMonitor

#########################################################################
  sub getMainStateSerialID {
	my $printNM = undef;
	if (!$isiRMC) {
	    @cimSvsComputerSystem = cimEnumerateClass("SVS_PGYComputerSystem");
	    if (!@cimSvsComputerSystem and $optUseMode =~ m/^W/) {
		    $notifyMessage = '';
		    $optServiceMode .= "621";
		    print "**** try another namespace of a different Agentsversion\n" 
			if ($main::verbose >3);
		    @cimSvsComputerSystem = cimEnumerateClass("SVS_PGYComputerSystem");
	    }
	    $printNM = "SVS_PGYComputerSystem";
	} else { # iRMC
	    @cimSvsComputerSystem = cimEnumerateClass("SVS_iRMCBaseServer");
	    $printNM = "SVS_iRMCBaseServer";
	}
	if (!$#cimSvsComputerSystem < 0) {
		    addMessage("m", "Unable to get ServerView CIM Classes");
		    $notifyMessage = "WS-MAN script detail:\n" . $notifyMessage;
		    return 2;
	}
	cimPrintClass(\@cimSvsComputerSystem, $printNM);
	# Name + HealthState
	my $ref1stClass = $cimSvsComputerSystem[0]; # There should be only one instance !
	my %compSystem = ();
	%compSystem = %{$ref1stClass} if ($ref1stClass);
	my $healthState = $compSystem{"HealthState"};
		# ATTENTION with this syntax we are case-sensitiv
	addComponentStatus("m", "ComputerSystem", healthStateString($healthState))
		if ($healthState and $optSystemInfo); 
		# should this be printed for chksystem ???
	my $localExitCode = healthStateExitCode($healthState);
	addExitCode($localExitCode) if ($optChkSystem or $optSystemInfo);
	$statusOverall = $localExitCode;

	# get Chassis Infos
	$serverID = undef;
	if (!$isiRMC) {
	    @cimSvsChassis = cimEnumerateClass("SVS_PGYChassis");
	    cimPrintClass(\@cimSvsChassis, "SVS_PGYChassis");
	} else { # iRMC
	    @cimSvsChassis = cimEnumerateClass("SVS_iRMCChassis");
	    cimPrintClass(\@cimSvsChassis, "SVS_iRMCChassis");
	}
	# SerialNumber
	if ($#cimSvsChassis >= 0) {
	    $ref1stClass = $cimSvsChassis[0]; # There should be only one instance !
	    my %firstChassis = %{$ref1stClass};
	    $serverID = $firstChassis{"SerialNumber"};
	    # Serial ID for MainMessage
	    if ($optChkSystem or $optChkHardware) {
		addMessage("m", "-"); # separator
		addSerialIDs("m", $serverID, undef);
		addMessage("m", " -"); # separator
	    }
	}
	$notifyMessage = '';

	# Notify Data
	addSerialIDs("n", $serverID, undef);
	addKeyValue("n", "ComputerSystemState", healthStateString($healthState)) 
	    if (!$optChkSystem and $healthState); 
	$notifyMessage .= "\n" if ($serverID or !$optChkSystem);

	return 0;
  } #getMainStateSerialID

  our $svAgentVersion = undef;
  sub getSystemNotifyInformation { # ... this should be the last called functions because of $notifyMessage

	my $admURL = undef;
	my $printNM = undef;
	if ($#cimSvsComputerSystem < 0) {
	    if (!$isiRMC) {
		@cimSvsComputerSystem = cimEnumerateClass("SVS_PGYComputerSystem");
		$printNM = "SVS_PGYComputerSystem";
	    } else { # iRMC
		@cimSvsComputerSystem = cimEnumerateClass("SVS_iRMCBaseServer");
		$printNM = "SVS_iRMCBaseServer";
	    }
	    if (!@cimSvsComputerSystem) {
		    addMessage("m", "Unable to get ServerView CIM Classes\n");
		    return 2;
	    }
	    cimPrintClass(\@cimSvsComputerSystem, $printNM);
	}
	$notifyMessage = "";
	my $name = undef;
	my $location = undef;
	my $contact = undef;
	if ($#cimSvsComputerSystem >= 0) {
	    # Name, are there other interessting information ?
	    # , , , (new) UnitLocation
	    my $ref1stClass = $cimSvsComputerSystem[0]; # There should be only one instance !
	    my %compSystem = %{$ref1stClass};
	    $name = $compSystem{"ElementName"};					# ... not ESXi
	    $name = $compSystem{"Name"} if (!$name);
	    $location = $compSystem{"UnitLocation"};				# ... not ESXi
	    $contact = $compSystem{"PrimaryOwnerContact"};
	    $admURL = $compSystem{"AdminUrlIPv4"};				# ... not ESXi
	    $admURL = $compSystem{"AdminUrlIPv6"} if (!$admURL);		# ... not ESXi
	    $admURL = $compSystem{"ManagementIPAddress"} if (!$admURL);		# ... not ESXi
	    $name = undef if (defined $name and $name =~ m/^\s*$/);
	    $location = undef if (defined $location and $location =~ m/^\s*$/);
	    $contact = undef if (defined $contact and $contact =~ m/^\s*$/);
	    #$contact = undef if ($contact and $contact =~ m/root\@localhost/);
	}
	if ($isiRMC and $name and $serverID and $name eq $serverID) {
	    $name = undef;
	}
	if ($isiRMC and $name and $name =~m/ unknown /) { # no agent and no customer value
	    $name = undef;
	}

	if ($#cimSvsChassis < 0) {
	    @cimSvsChassis = cimEnumerateClass("SVS_PGYChassis");
	    cimPrintClass(\@cimSvsChassis, "SVS_PGYChassis");
	}
	$notifyMessage = "";
	my $descr = undef;
	my $model = undef;
	my $housing = undef;
	if ($#cimSvsChassis >= 0) {
	    my $ref1stClass = $cimSvsChassis[0]; # There should be only one instance !
	    my %firstChassis = %{$ref1stClass};
	    $descr = $firstChassis{"OtherIdentifyingInfo"};
	    $model = $firstChassis{"Model"};
	    $housing = $firstChassis{"CabinetHousingType"};
	    $descr = undef if (defined $descr and $descr =~ m/^\s*$/);
	    $model = undef if (defined $model and $model =~ m/^\s*$/);
	    if ($isiRMC and $model and $model =~ m/.*\-.*\-.*/) {
		my $tmpModel = $firstChassis{"Name"};
		my $tmpHousing = $firstChassis{"Description"};
		$model = $tmpModel;
		$housing = $tmpHousing if (!$housing);
	    }
	} # cimSvsChassis

	my $mmbAddress = undef;
	if (!$isiRMC) {
	    if ($#cimSvsIPs < 0) {
		@cimSvsIPs = cimEnumerateClass("SVS_PGYIPProtocolEndpoint");
		cimPrintClass(\@cimSvsIPs, "SVS_PGYIPProtocolEndpoint");
	    }
	    $notifyMessage = "";
	    if ($#cimSvsIPs >= 0) {
		    my $gotOneIRMC = 0;
		    my $gotOneMMB = 0;
		    foreach my $refClass (@cimSvsIPs) {
			    next if !$refClass;
			    my %oneClass = %{$refClass};
			    my $createClass = $oneClass{"SystemCreationClassName"};
			    my $ipv4 = $oneClass{"IPv4Address"};
			    my $ipv6 = $oneClass{"IPv6Address"};
			    if (!$admURL and $createClass and $createClass eq "SVS_PGYManagementController" and !$gotOneIRMC) {
				# iRMC
				if ($ipv4 or $ipv6) {
				    $gotOneIRMC = 1;
				    $admURL = "http://" . $ipv4 if ($ipv4);
				    $admURL = "http://[" . $ipv6 . "]" if (!$admURL and $ipv6);
				}
			    } # iRMC
			    elsif ($createClass and $createClass eq "SVS_PGYChassisController" and !$gotOneMMB) {
				# Parent MMB
				if ($ipv4 or $ipv6) {
				    $gotOneMMB = 1;
				    $mmbAddress = $ipv4 if ($ipv4);
				    $mmbAddress = $ipv6 if (!$mmbAddress and $ipv6);
				}
			    }
		    } # for
	    } # cimSvsIPs
	} # not-iRMC

	getOperatingSystem();

	my $ssmURL = socket_getSSM_URL($svAgentVersion) if (!$isiRMC); #TODO agentVersion

	addSerialIDs("n", $serverID, undef) if ($serverID);
	addName("n", $name);
	addKeyValue("n", "SpecifiedAddress", $optHost) 
	    if ($optHost and $optAdminHost);
	addKeyLongValue("n", "Description", $descr);
	addProductModel("n", undef, $model);
	addKeyLongValue("n", "Housing", $housing);
	addLocationContact("n", $location, $contact);
	addAdminURL("n",$admURL);
	addKeyValue("n","MonitorURL", $ssmURL);
	addKeyValue("n","AdminAddress", $optAdminHost) 
	    if ($optHost and $optAdminHost);
	addKeyValue("n","ParentMMB", $mmbAddress);
	addKeyLongValue("n","OS",$cimOS);
	addKeyLongValue("n","OSDescription",$cimOSDescription);

	return 0;
  } #getSystemNotifyInformation

  sub getSystemInventoryInfo {
	my $print = shift;
	#### Provider Version info
	my @classInstances = ();
	if (!$isiRMC) {   
	    @classInstances = cimEnumerateClass("SVS_PGYCIMProviderIdentity");
	    cimPrintClass(\@classInstances, "SVS_PGYCIMProviderIdentity");
	}
	if ($#classInstances >= 0) {
	    my $ref1stClass = $classInstances[0]; # There should be only one instance !
	    my %first = %{$ref1stClass};

	    my $caption = $first{"Caption"};
	    my $version = $first{"VersionString"};
	    my $manu = $first{"Manufacturer"};
	    $svAgentVersion = $version; # for SSM check

	    $caption = undef if (defined $caption and $caption =~ m/^\s*$/);
	    $version = undef if (defined $version and $version =~ m/^\s*$/);
	    $manu = undef if (defined $manu and $manu =~ m/^\s*$/);

	    $caption = "ServerView CIM Provider" if ($caption and $caption =~ m/svs_cimprovider/);
	    if ($caption and $version and $print) {
		if (!$optAgentInfo) {
		    addStatusTopic("v",undef,"AgentInfo", undef);
		    addName("v",$caption);
		    addKeyValue("v","Version",$version);
		    addKeyLongValue("v","Company",$manu);
		    $variableVerboseMessage .= "\n";
		} else {
		    addKeyValue("m","Version",$version);

		    addStatusTopic("l",undef,"AgentInfo", undef);
		    addName("l",$caption);
		    addKeyValue("l","Version",$version);
		    addKeyLongValue("l","Company",$manu);
		    $longMessage .= "\n";
		}
	    }
	} #SVS_PGYCIMProviderIdentity

	return if (!$print);

	@classInstances = ();
	if ($isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_iRMCSoftwareIdentity");
	    cimPrintClass(\@classInstances, "SVS_iRMCSoftwareIdentity");
	}
	if ($#classInstances >= 0) {
	    my $versionString = "";
	    foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $name = $oneClass{"ElementName"};
		my $ident = $oneClass{"InstanceID"};
		my $pversion = $oneClass{"VersionString"};
		next if (!$name or !$ident or !$pversion);
		if (($name =~ m/iRMC/ and $ident =~ m/iRMC/)
		or   $name =~ m/Service Processor Firmware/) 
		{
		    if ($pversion and $pversion ne $versionString) {
			$versionString .= ", " if ($versionString and $versionString ne "");
			$versionString .= $pversion;
		    }
		}
	    }
	    if ($versionString and $versionString ne "") {
		if (!$optAgentInfo) {
		    addStatusTopic("v",undef,"ProviderFirmwareInfo", undef);
		    addKeyLongValue("v","Version",$versionString);
		    $variableVerboseMessage .= "\n";
		} else {
		    addKeyLongValue("m","Version",$versionString);

		    addStatusTopic("l",undef,"ProviderFirmwareInfo", undef);
		    addKeyLongValue("l","Version",$versionString);
		    $longMessage .= "\n";
		    $exitCode = 0;
		}
	    }
	} #SVS_iRMCSoftwareIdentity

	#### Systemboard info
	@classInstances = ();
	if (!$optAgentInfo and !$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYSystemboardCard");
	    cimPrintClass(\@classInstances, "SVS_PGYSystemboardCard");
	} elsif (!$optAgentInfo and $isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_iRMCSystemboardCard");
	    cimPrintClass(\@classInstances, "SVS_iRMCSystemboardCard");
	}
	if ($#classInstances >= 0) {
		addTableHeader("v","System Board Table");
		foreach my $refClass (@classInstances) {
			next if !$refClass;
			my %oneClass = %{$refClass};
			my $name = $oneClass{"ElementName"};
			my $serial = $oneClass{"SerialNumber"};
			my $model = $oneClass{"Model"};
			my $product = $oneClass{"PartNumber"};
			my $manu = $oneClass{"Manufacturer"};
			$name = undef if (defined $name and $name =~ m/^\s*$/);
			$serial = undef if (defined $serial and $serial =~ m/^\s*$/);
			$model = undef if (defined $model and $model =~ m/^\s*$/);
			$product = undef if (defined $product and $product =~ m/^\s*$/);
			$manu = undef if (defined $manu and $manu =~ m/^\s*$/);
			
			addStatusTopic("v",undef,"SystemBoard", '');
			addSerialIDs("v",$serial, undef);
			addName("v",$name);
			addProductModel("v",$product, $model);
			addKeyLongValue("v","Manufacturer", $manu);
			$variableVerboseMessage .= "\n";
		} # for
	} # SVS_*SystemboardCard

	#### IPs
	if ($#cimSvsIPs < 0 and !$optAgentInfo and !$isiRMC) {
	    @cimSvsIPs = cimEnumerateClass("SVS_PGYIPProtocolEndpoint");
	    cimPrintClass(\@cimSvsIPs, "SVS_PGYIPProtocolEndpoint");
	}
	elsif ($#cimSvsIPs < 0 and !$optAgentInfo and $isiRMC) {
	    @cimSvsIPs = cimEnumerateClass("SVS_iRMCIPProtocolEndpoint");
	    cimPrintClass(\@cimSvsIPs, "SVS_iRMCIPProtocolEndpoint");
	}
	if ($#cimSvsIPs >= 0 and !$optAgentInfo) {
		addTableHeader("v","IP Addresses");
		foreach my $refClass (@cimSvsIPs) {
			next if !$refClass;
			my %oneClass = %{$refClass};
			#my $instance = $oneClass{"InstanceID"};
			my $createClass = $oneClass{"SystemCreationClassName"};
			my $ipv4 = $oneClass{"IPv4Address"};
			my $ipv6 = $oneClass{"IPv6Address"};
			my $name = $oneClass{"Name"};
			# ProtocolIFType
			#$instance = undef if (defined $instance and $instance =~ m/^\s*$/);
			$createClass = undef if (defined $createClass and $createClass =~ m/^\s*$/);
			$ipv4 = undef if (defined $ipv4 and $ipv4 =~ m/^\s*$/);
			$ipv6 = undef if (defined $ipv6 and $ipv6 =~ m/^\s*$/);
			$name = undef if (defined $name and $name =~ m/^\s*$/);
			
			$createClass =~ m/SVS_PGY(.*)/ if ($createClass);
			my $assoc = undef;
			$assoc = $1 if ($createClass);
			addStatusTopic("v",undef,"IPProtocol", '');
			addIP("v", $ipv4);
			addIP("v", $ipv6);
			addName("v", $name);
			addKeyValue("v", "AssignedTo", $assoc);
			$variableVerboseMessage .= "\n";
		} # for
	} # cimSvsIPs

	#### MAC
	@classInstances = ();
	if (!$optAgentInfo and !$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYLANEndpoint");
	    cimPrintClass(\@classInstances, "SVS_PGYLANEndpoint");
	}
	elsif (!$optAgentInfo and $isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_iRMCLANEndpoint");
	    cimPrintClass(\@classInstances, "SVS_iRMCLANEndpoint");
	}
	if ($#classInstances >= 0) {
		addTableHeader("v","MAC Addresses");
		foreach my $refClass (@classInstances) {
			next if !$refClass;
			my %oneClass = %{$refClass};
			my $createClass = $oneClass{"SystemCreationClassName"};
			my $mac = $oneClass{"MACAddress"};
			my $descr = $oneClass{"Description"};
			my $name = $oneClass{"Name"};
			$createClass = undef if (defined $createClass and $createClass =~ m/^\s*$/);
			$mac = undef if (defined $mac and $mac =~ m/^\s*$/);
			$descr = undef if (defined $descr and $descr =~ m/^\s*$/);
			$name = undef if (defined $name and $name =~ m/^\s*$/);
			
			$createClass =~ m/SVS_PGY(.*)/ if ($createClass);
			my $assoc = undef;
			$assoc = $1 if ($createClass);
			$name = $descr if ($descr); # ... ESXi ... must be checked for Not-ESXi

			addStatusTopic("v",undef,"LAN", '');
			addMAC("v", $mac);
			addName("v", $name);
			addKeyValue("v", "AssignedTo", $assoc);
			$variableVerboseMessage .= "\n";
		} # for
	} #SVS_PGYLANEndpoint

	#### UUID
	@classInstances = ();
	if (!$optAgentInfo and !$isiRMC) {
	    @classInstances = cimEnumerateClass("SVS_PGYComputerSystemChassis");
	    cimPrintClass(\@classInstances, "SVS_PGYComputerSystemChassis");
	}
	if ($#classInstances >= 0) {
		addTableHeader("v","Chassis UUID");
		foreach my $refClass (@classInstances) {
			next if !$refClass;
			my %oneClass = %{$refClass};
			my $createClass = $oneClass{"Dependent"};
			my $uuid = $oneClass{"PlatformGUID"};
			$createClass = undef if (defined $createClass and $createClass =~ m/^\s*$/);
			$uuid = undef if (defined $uuid and $uuid =~ m/^\s*$/);
			
			$createClass =~ m/.*SVS_PGY(.*)/ if ($createClass);
			my $assoc = undef;
			$assoc = $1 if ($createClass);
			if ($uuid) {
			    addStatusTopic("v",undef,"Chassis", '');
			    addKeyValue("v","UUID",$uuid);
			    addKeyValue("v", "AssignedTo", $assoc);
			    $variableVerboseMessage .= "\n";
			}
		} # for
	} #SVS_PGYComputerSystemChassis
	if (!$optAgentInfo and $isiRMC) {
	    if ($#cimSvsComputerSystem < 0) {
		{ # iRMC
		    @cimSvsComputerSystem = cimEnumerateClass("SVS_iRMCBaseServer");
		    cimPrintClass(\@cimSvsComputerSystem, "SVS_iRMCBaseServer");
		}
		
	    }
	    if ($#cimSvsComputerSystem >= 0) {
		my $ref1stClass = $cimSvsComputerSystem[0]; # There should be only one instance !
		my %compSystem = %{$ref1stClass};
		my $descriptions = $compSystem{"OtherIdentifyingInfo"};	
		my @arrDescription = split(/,/, $descriptions);
		my $uuid = undef;
		foreach my $des (@arrDescription) {
		    next if ($des !~ m/.*\-.*\-.*\-.*\-.*/);
		    $uuid = $des;
		    $uuid =~ s/^\"//;
		    $uuid =~ s/\"$//;
		    last if ($uuid);
		}
		if ($uuid) {
		    addStatusTopic("v",undef,"Chassis", '');
		    addKeyValue("v","UUID",$uuid);
		    $variableVerboseMessage .= "\n";
		}

	    }
	} # iRMC

  } #getSystemInventoryInfo

  sub scanOverallStatusValuesESXi {
	my $refClassInstances = shift;
	my @classInstances = undef;
	@classInstances = @{$refClassInstances} if ($refClassInstances);
	{
		cimPrintClass(\@classInstances, "SVS_PGYSubsystem");

		foreach my $refClass (@classInstances) {
		    my %oneClass = %{$refClass};
		    my $name = $oneClass{"ElementName"};
		    my $subStatus = $oneClass{"SubsystemStatus"};
		    my $subString = esxiSubSystemStatusString($subStatus);
		    my $subCode = esxiSubSystemStatusExitCode($subStatus);
		    if ($name) {
			if ($name =~ m/Enviro.*ment/i) { # "Enviroment" - write error is in CIM provider !
			    addComponentStatus("m", "Environment", $subString)
				if ($optChkEnvironment);
			    $statusEnv = $subCode;
			} elsif ($name =~ m/PowerSupply/i) {
			    addComponentStatus("m", "PowerSupplies", $subString)
				if ($optChkPower);
			    $statusPower = $subCode;
			} elsif ($name =~ m/Systemboard/i) {
			    addComponentStatus("m", "Systemboard", $subString)
				if ($optChkSystem or $optChkHardware);
			    $statusSystemBoard = $subCode;
			} elsif ($name =~ m/MassStorage/i) {
			    addComponentStatus("m", "MassStorage", $subString)
				if ($optChkStorage and $subStatus != 0);
			    $statusMassStorage = $subCode;
			} else {
			    my $printThis = 0;
			    $printThis = 1 if ($statusOverall != 0 
				and ($subCode ==1 or $subCode ==2)
				and $statusEnv==0 and $statusPower==0 and $statusSystemBoard==0
				and $statusMassStorage==0);
			    $printThis = 1 if ($main::verbose >= 1);
			    addComponentStatus("m", $name, $subString)
				if ($optChkSystem and $printThis);
			}
		    } # name
		} #foreach class instances
	} # ESXi
  } #scanOverallStatusValuesESXi

  sub scanOverallStatusValuesiRMC {
	my $refClassInstances = shift;
	my @classInstances = ();
	return if (!$refClassInstances);
	@classInstances = @{$refClassInstances};
	{
		cimPrintClass(\@classInstances, "SVS_iRMCHealthStateComponent");
		# ATTENTION: For FW V7.6x less than 7.69F there are multiple instances of one element !!! 
		# It seems to be so that the HealthState of the last one is the to-be-used one
		# (if it is not 0) !
		my $lastStatusSystem		= undef;
		my $lastStatusEnv		= undef; my $lastStatusEnvString	= undef;
		my $lastStatusPower		= undef; my $lastStatusPowerString	= undef;
		my $lastStatusSystemBoard	= undef; my $lastStatusSystemBoardString= undef;
		my $lastStatusMassStorage	= undef; my $lastStatusMassStorageString= undef;
		my $lastStatusDrvMonitor	= undef; my $lastStatusDrvMonitorString	= undef;
		my %last1stLayer		= ();    my %last1stLayerString = ();

		my $lastAllFanStatus		= undef; my $lastAllHealthFanStatus	= undef;
		my $lastAllTempStatus		= undef; my $lastAllHealthTempStatus	= undef;
		my $lastStatusPowerLevel	= undef;
		my $lastAllVoltageStatus	= undef; my $lastAllHealthVoltageStatus	= undef;
		my $lastAllMemoryStatus		= undef; my $lastAllHealthMemoryStatus	= undef;
		my $lastAllCPUStatus		= undef; my $lastAllHealthCPUStatus	= undef;

		$noSummaryStatus = 0;

		foreach my $refClass (@classInstances) {
		    my %oneClass = %{$refClass};
		    my $name = $oneClass{"ElementName"};
		    my $ID = $oneClass{"InstanceID"};
		    my $subStatus = $oneClass{"HealthState"};
		    my $subString = healthStateString($subStatus);
		    my $subCode = healthStateExitCode($subStatus);
		    next if (!$ID or !$name); # ERROR on WSMAN-Service Side
		    if ($ID =~ m/^System$/) { # InstanceID : System
			$lastStatusSystem = $subCode if ($subStatus != 0);
		    }
		    if ($ID =~ m/^System\-[^\-]+$/) { # InstanceID : System-*
			if    ($name =~ m/^Environment Subsystem$/i) {
				$lastStatusEnv		= $subCode if ($subStatus != 0);
				$lastStatusEnvString	= $subString if ($subStatus != 0);
			}
			elsif ($name =~ m/^Power Supply Subsystem$/i) {
				$lastStatusPower	= $subCode if ($subStatus != 0);
				$lastStatusPowerString	= $subString if ($subStatus != 0);
			}
			elsif ($name =~ m/^System Board Subsystem$/i) {
				$lastStatusSystemBoard		= $subCode if ($subStatus != 0);
				$lastStatusSystemBoardString	= $subString if ($subStatus != 0);
			}
			elsif ($name =~ m/^Mass Storage Subsystem$/i) {
				$lastStatusMassStorage		= $subCode if ($subStatus != 0);
				$lastStatusMassStorageString	= $subString if ($subStatus != 0);
			}
			elsif ($name =~ m/^Driver Monitor$/i) {
				$lastStatusDrvMonitor		= $subCode if ($subStatus != 0);
				$lastStatusDrvMonitorString	= $subString if ($subStatus != 0);
			}
			elsif ($subStatus != 0) {
				my $tmp_name = $name;
				$tmp_name =~ s/\s//g;
				$tmp_name =~ s/\.//g; # SystemMgmt.Software
				$last1stLayer{$tmp_name}	= $subCode;
				$last1stLayerString{$tmp_name}	= $subString;
			}
		    } # System-***
		    if ($ID =~ m/^System\-[^\-]+\-[^\-]+$/) { # InstanceID : System-*-*
			# Fans, Temperature
			if ($name =~ m/Fans/i) {			
				$lastAllFanStatus = $subCode if ($subStatus != 0); 
				$lastAllHealthFanStatus = $subStatus if ($subStatus != 0);
			}
			elsif ($name =~ m/Temperature/i) {		
				$lastAllTempStatus = $subCode; 
				$lastAllHealthTempStatus = $subStatus;
			}
			# System Board Voltages, Memory Modules, System Processors, BIOS Selftest, PCI Slots, Trusted Platform Module
			elsif ($name =~ m/System Board Voltages/i) {			
				$lastAllVoltageStatus = $subCode; 
				$lastAllHealthVoltageStatus = $subStatus; 
			}
			elsif ($name =~ m/Memory\s*Modules/i) {		
				$lastAllMemoryStatus = $subCode; 
				$lastAllHealthMemoryStatus = $subStatus; 
			}
			elsif ($name =~ m/System\s*Processors/i) {	
				$lastAllCPUStatus = $subCode; 
				$lastAllHealthCPUStatus = $subStatus; 
			}
			elsif ($ID =~ m/^System\-System Board Subsystem\-*/) {
				# BIOS Selftest, ...
				$cimSvsOtherSystemBoardAdapters->{$name} = $subStatus;
			}
			elsif ($ID =~ m/^System\-Power Supply Subsystem\-*/) {
				# Power Configuration, ...
				$cimSvsOtherPowerAdapters->{$name} = $subStatus
				    if ($name and $name ne "Power Supply");
			}
			# Mass Storage ...
			elsif ($ID =~ m/^System\-Mass Storage Subsystem\-*/) {
				# Mass Storage Adapters, ServerView RAID System, RAID Adapters, 
				# RAID Logical drives, RAID Physical disks, S.M.A.R.T. (RAID), S.M.A.R.T.
				$cimSvsRAIDAdapters->{$name} = $subStatus;
			}
			#else { ... ignore the rest
			#}
		    } # System-*-*
		    if ($ID =~ m/^System\-[^\-]+\-[^\-]+\-[^\-]+$/) { # InstanceID : System-*-*-*
			if ($ID =~ m/\-Fans\-[^\-]+$/) {
			    $cimSvsFanAdapters->{$name} = $subStatus if ($subStatus);
			}
			elsif ($ID =~ m/\-Temperature\-[^\-]+$/) {
			    $cimSvsTempAdapters->{$name} = $subStatus if ($subStatus);
			}
			elsif ($ID =~ m/\-Power Supply\-[^\-]+$/) {
			    $cimSvsPSUAdapters->{$name} = $subStatus if ($subStatus);
			}
			elsif ($ID =~ m/\-System Board Voltages\-[^\-]+$/) {
			    $cimSvsVoltAdapters->{$name} = $subStatus if ($subStatus);
			}
		    } # System-*-*-*
		} # foreach instance
		$noSummaryStatus = 1 if (!defined $lastStatusSystem 
		    or !defined $lastStatusEnv or !defined $lastStatusPower 
		    or !defined $lastStatusSystemBoard);
		return if ($noSummaryStatus);

		{ # evaluations 1st layer - component groups
		    my $printThis = 0;
		    $printThis = 1 if (
			($statusOverall != 0 or $lastStatusSystem != 0)
			and $lastStatusEnv==0 and $lastStatusPower==0 and $lastStatusSystemBoard==0
			and $lastStatusMassStorage==0);
		    $printThis = 1 if ($main::verbose >= 1);
		    if (defined $lastStatusSystem and defined $statusOverall and $statusOverall != $lastStatusSystem) {
			    $longMessage .= "- Hint: There are differences of overall status values for the system in the fetched data - check firmware version - \n" if ($optChkSystem);
		    }
		    if (defined $lastStatusEnv) {
			    addComponentStatus("m", "Environment", $lastStatusEnvString)
				if ($optChkEnvironment);
			    $statusEnv = $lastStatusEnv;
		    }
		    if (defined $lastStatusPower) {
			    addComponentStatus("m", "PowerSupplies", $lastStatusPowerString)
				if ($optChkPower);
			    $statusPower = $lastStatusPower;
		    }
		    if (defined $lastStatusSystemBoard) {
			    addComponentStatus("m", "Systemboard", $lastStatusSystemBoardString)
				if ($optChkSystem or $optChkHardware);
			    $statusSystemBoard = $lastStatusSystemBoard;
		    }
		    if (defined $lastStatusMassStorage) {
			    addComponentStatus("m", "MassStorage", $lastStatusMassStorageString)
				if ($optChkStorage);
			    $statusMassStorage = $lastStatusMassStorage;
		    }
		    if (defined $lastStatusDrvMonitor) {
			    addComponentStatus("m", "DrvMonitor", $lastStatusDrvMonitorString)
				if ($optChkDrvMonitor or ($optChkSystem and $printThis));
			    $statusDrvMonitor = $lastStatusDrvMonitor;
		    }
		    if ($optChkSystem and $printThis) {
			foreach my $compGroup (sort keys %last1stLayerString) {
				addComponentStatus("m", $compGroup, $last1stLayerString{$compGroup});
			}
		    }
		} # eval 1st layer
		{ # evaluations 2nd layer - single component
		    if (defined $lastAllFanStatus) {
			$allFanStatus = $lastAllFanStatus;
			$allHealthFanStatus = $lastAllHealthFanStatus 
			    if (defined $lastAllHealthFanStatus);
		    }
		    if (defined $lastAllTempStatus) {
			$allTempStatus = $lastAllTempStatus;
			$allHealthTempStatus = $lastAllHealthTempStatus 
			    if (defined $lastAllHealthTempStatus);
		    }
		    if (defined $lastStatusPowerLevel) {
			$statusPowerLevel = $lastStatusPowerLevel;
		    }
		    if (defined $lastAllVoltageStatus) {
			$allVoltageStatus = $lastAllVoltageStatus;	    
			$allHealthVoltageStatus = $lastAllHealthVoltageStatus
			    if (defined $lastAllHealthVoltageStatus);
		    }
		    if (defined $lastAllMemoryStatus) {
			$allMemoryStatus	= $lastAllMemoryStatus; 
			$allHealthMemoryStatus  = $lastAllHealthMemoryStatus
			     if (defined $lastAllHealthMemoryStatus);
		    }
		    if (defined $lastAllCPUStatus) {
			$allCPUStatus	    = $lastAllCPUStatus; 
			$allHealthCPUStatus = $lastAllHealthCPUStatus
			     if (defined $lastAllHealthCPUStatus);
		    }
	        } # eval 2nd layer
	} # scan Instances
  } #scanOverallStatusValuesiRMC

  sub getOverallStatusValues {
	my $foundPGYSubsystem = 0;
	my $foundHealthStateComponent = 0;
	my $foundiRMCHealthStateComponent = 0;
	my @classInstances = ();
	if ($isESXi) {
		@classInstances = cimEnumerateClass("SVS_PGYSubsystem");
		$foundPGYSubsystem = 1 if ($#classInstances >= 0);

	}
	if (!$foundPGYSubsystem and !defined $isiRMC) {
		@classInstances = cimEnumerateClass("SVS_PGYHealthStateComponent");
		$foundHealthStateComponent = 1 if ($#classInstances >= 0);
		$is2014Profile = 1 if ($#classInstances >= 0); 
	}
	if (!$foundPGYSubsystem and !$foundHealthStateComponent and $isiRMC) 
	{
		@classInstances = cimEnumerateClass("SVS_iRMCHealthStateComponent");
		if ($#classInstances >= 0) {
			my $refClass = $classInstances[0];
			my %oneClass = ();
			%oneClass = %{$refClass} if ($refClass);
			if ($refClass) { # ignore too old FirmwareVersions
				my $name = $oneClass{"ElementName"};
				my $ID = $oneClass{"InstanceID"};
				my $subStatus = $oneClass{"HealthState"};
				$foundiRMCHealthStateComponent = 1 if (defined $ID and defined $subStatus);
			}
		}
	} # iRMC

	if (!$foundPGYSubsystem and !$foundHealthStateComponent and !$foundiRMCHealthStateComponent) {
		addMessage("m", " Unable to get ServerView subsystem summary status CIM information");
		return 2;
	} elsif ($#classInstances == 0) { # only one base class instance
		addMessage("m", " Corrupt ServerView subsystem summary status CIM information");
		return 2;
	} else {
		$noSummaryStatus = 0; # older LX, Win Agents
	}
	if ($foundPGYSubsystem) {
		scanOverallStatusValuesESXi(\@classInstances);
	} # ESXi
	if ($foundiRMCHealthStateComponent ) {
		#my $skipStatus = 1;
		#$skipStatus = 0 if ($main::verboseTable == 400);
		scanOverallStatusValuesiRMC(\@classInstances);
		#$noSummaryStatus = 1 if ($skipStatus);
		#return 2 if ($skipStatus);
	}
	if ($foundHealthStateComponent) { 
		cimPrintClass(\@classInstances, "SVS_PGYHealthStateComponent");

		my $idMassStorage = undef;
		my $idDrvMon = undef;
		my $idFans = undef;
		my $idTemp = undef;
		my $idPSU = undef;
		my $idVolt = undef;
		my $idSystemBoard = undef;
		my $baseNr = undef;
		foreach my $refClass (@classInstances) {
		    my %oneClass = %{$refClass};
		    my $name = $oneClass{"ElementName"};
		    my $ID = $oneClass{"InstanceID"};
		    my $subStatus = $oneClass{"HealthState"};
		    my $subString = healthStateString($subStatus);
		    my $subCode = healthStateExitCode($subStatus);
		    if (!defined $baseNr) {
			$baseNr = $1 if ($ID and $ID =~ m/^(\d+)/);
		    }
		    $baseNr = 0 if (!defined $baseNr);
		    next if (!$ID or !$name); # ERROR on WSMAN-Service Side
		    if ($ID =~ m/^$baseNr\-\d+$/) { # InstanceID : 0-n
			if ($name =~ m/Environment/i) {
				addComponentStatus("m", "Environment", $subString)
				    if ($optChkEnvironment);
				$statusEnv = $subCode;
			} elsif ($name =~ m/Power\s*Supply/i) {
				addComponentStatus("m", "PowerSupplies", $subString)
				    if ($optChkPower);
				$statusPower = $subCode;
			} elsif ($name =~ m/System\s*Board/i) {
				addComponentStatus("m", "Systemboard", $subString)
				    if ($optChkSystem or $optChkHardware);
				$statusSystemBoard = $subCode;
				$idSystemBoard = $ID;
			} elsif ($name =~ m/Mass\s*Storage/i) {
				addComponentStatus("m", "MassStorage", $subString)
				    if ($optChkStorage);
				$statusMassStorage = $subCode;
				$idMassStorage = $ID;
			} else {
				my $printThis = 0;
				$printThis = 1 if ($statusOverall != 0 
				    and ($subCode ==1 or $subCode ==2)
				    and $statusEnv==0 and $statusPower==0 and $statusSystemBoard==0
				    and $statusMassStorage==0);
				$printThis = 1 if ($main::verbose >= 1);
				if ($name =~ m/Driver\s*Monitor/i) {
					addComponentStatus("m", "DriverMonitor", $subString)
						if ($optChkDrvMonitor or ($optChkSystem and $printThis));
					$statusDrvMonitor = $subCode;
					$idDrvMon = $ID;
				} else {
					addComponentStatus("m", $name, $subString)
						if ($optChkSystem and $printThis);
				}
			}
		    } # 0-n
		    elsif ($ID =~ m/^$baseNr\-\d+\-\d+$/) { # InstanceID : 0-n-n
			# Fans, Temperature
			   if ($name =~ m/Fans/i) {			
				$allFanStatus = $subCode; 
				$allHealthFanStatus = $subStatus; 
				$idFans = $ID;
			}
			elsif ($name =~ m/Temperature/i) {		
				$allTempStatus = $subCode; 
				$allHealthTempStatus = $subStatus;
				$idTemp = $ID;
			}
			# Power Supply, Power Level
			elsif ($name =~ m/Power\s*Supply/i) {			
				$idPSU = $ID;
			}
			elsif ($name =~ m/Power\s*Level/i) {			
				$statusPowerLevel = $subStatus;
			}
			# System Board Voltages, Memory Modules, System Processors, BIOS Selftest, PCI Slots, Trusted Platform Module
			elsif ($name =~ m/Voltages/i) {			
				$allVoltageStatus = $subCode; 
				$allHealthVoltageStatus = $subStatus; 
				$idVolt = $ID;
			}
			elsif ($name =~ m/Memory\s*Modules/i) {		
				$allMemoryStatus = $subCode; 
				$allHealthMemoryStatus = $subStatus; 
			}
			elsif ($name =~ m/System\s*Processors/i) {	
				$allCPUStatus = $subCode; 
				$allHealthCPUStatus = $subStatus; 
			}
			elsif ($idMassStorage and $ID =~ m/^$idMassStorage/) {
				# Mass Storage Adapters, ServerView RAID System, RAID Adapters, 
				# RAID Logical drives, RAID Physical disks, S.M.A.R.T. (RAID), S.M.A.R.T.
				$cimSvsRAIDAdapters->{$name} = $subStatus;
			}
			elsif ($idDrvMon and $ID =~ m/^$idDrvMon/) {
				# ...
				#$cimSvsDrvMonAdapters->{$name} = $subStatus;
			}
			elsif ($idSystemBoard and $ID =~ m/^$idSystemBoard/) {
				# BIOS Selftest, ...
				$cimSvsOtherSystemBoardAdapters->{$name} = $subStatus;
			}
		    } # 0-n-n
		    elsif ($ID =~ m/^$baseNr\-\d+\-\d+\-\d+$/) { # InstanceID : 0-n-n-n
			if ($idFans and $ID =~ m/^$idFans\-\d+$/) {
			    $cimSvsFanAdapters->{$name} = $subStatus;
			}
			elsif ($idTemp and $ID =~ m/^$idTemp\-\d+$/) {
			    $cimSvsTempAdapters->{$name} = $subStatus;
			}
			elsif ($idPSU and $ID =~ m/^$idPSU\-\d+$/) {
			    $cimSvsPSUAdapters->{$name} = $subStatus;
			}
			elsif ($idVolt and $ID =~ m/^$idVolt\-\d+$/) {
			    $cimSvsVoltAdapters->{$name} = $subStatus;
			}
			elsif ($idDrvMon and $ID =~ m/^$idDrvMon\-\d+\-\d+$/) {
			    $cimSvsDrvMonAdapters->{$name} = $subStatus;
			    # ... no real data existing with SvAgents-Win-V6.30.03
			    # TODO ... Driver Monitor must be checked with Agent > 6.30.03
			}
		    } # 0-n-n-n
		} #foreach class instances
	} # foundHealthStateComponent
	# Status evaluations
	{	
		if (!$optChkSystem) {
			addExitCode($statusEnv) if ($optChkEnvironment);
			addExitCode($statusPower) if ($optChkPower);
			addExitCode($statusSystemBoard) if ($optChkHardware);
			addExitCode($statusMassStorage) if ($optChkStorage);
			addExitCode($statusDrvMonitor)  if ($optChkDrvMonitor);
		}
		# ATTENTION:
		# ESXi CIM provider do not support 3rd level component status values 
		# (e.g for "all Fans" or "all Memory Modules")
		# these status values must be collected during read of each single sensor :-(
		# --- Optimization:
		if (defined $statusEnv and $statusEnv == 0 
		    and !defined $allFanStatus and !defined $allTempStatus) 
		{ # environment optimization for old ESXi
		    $allFanStatus		= 0;
		    $allTempStatus		= 0;
		} 
		if (defined $statusSystemBoard and $statusSystemBoard==0
		    and !defined $allCPUStatus and !defined $allVoltageStatus and !defined $allMemoryStatus) 
		{ # system board optimization
		    $allCPUStatus		= 0 ;
		    $allVoltageStatus		= 0 ;
		    $allMemoryStatus		= 0 ;
		} 
		if (!$optChkSystem) {
			addExitCode($allFanStatus) if ($optChkEnv_Fan);
			addExitCode($allTempStatus) if ($optChkEnv_Temp);
			addExitCode($allCPUStatus) if ($optChkCPU);
			addExitCode($allVoltageStatus) if ($optChkVoltage);
			addExitCode($allMemoryStatus) if ($optChkMemMod);
		}
	} # ... status evaluations
  } #getOverallStatusValues

  sub getComponentInformation {
	if (!$requiresNoSummary and $optUseMode =~ m/^W/ 
	    and !$setOverallStatus
	    and !$optChkEnvironment and !$optChkSystem and !$optChkHardware
	    and $noSummaryStatus) 
	{	
		$oldAgentException = 1; # Windows 6.20 Agent
		$msg =~ s/\- [^-]+$//; # skip error hint
		#$msg .= "-";
	}
	if ($isiRMC and $noSummaryStatus and !$requiresNoSummary) {
		$oldAgentException = 1; # iRMC S4
		$msg =~ s/\- [^-]+$//; # skip error hint
		#$msg .= "-";
	}
	#$main::verboseTable = undef if ($isiRMC and $main::verboseTable == 400);
	getEnvironment()	if ($optChkEnvironment or $optChkEnv_Fan or $optChkEnv_Temp);
	getSystemBoard()	if ($optChkSystem or $optChkHardware or $optChkCPU or $optChkVoltage or $optChkMemMod);
	getPower()		if ($optChkPower);
	getUpdateStatus()	if ($optChkUpdate);
	getStorage()		if ($optChkStorage);
	getDrvMonitor()		if ($optChkDrvMonitor);
	if ($isiRMC and $noSummaryStatus) {
	    my $subStatus = 0;
	    my $subString = undef;
	    if ($optChkEnvironment) {
		$subStatus = $allHealthFanStatus if ($allHealthFanStatus);
		$subStatus = $allHealthTempStatus 
		    if ($allHealthTempStatus and $allHealthTempStatus > $subStatus);
		$subString = healthStateString($subStatus);
		addComponentStatus("m", "Environment", $subString);
	    }
	    $subStatus = 0;
	    $subString = undef;
	    if ($optChkPower) {
		$subStatus = $allHealthPowerStatus if ($allHealthPowerStatus);
		$subString = healthStateString($subStatus);
		addComponentStatus("m", "PowerSupplies", $subString);
	    }
	    $subStatus = 0;
	    $subString = undef;
	    if ($optChkSystem or $optChkHardware) {
		$subStatus = $allHealthVoltageStatus if ($allHealthVoltageStatus);
		$subStatus = $allHealthCPUStatus 
		    if ($allHealthCPUStatus and $allHealthCPUStatus > $subStatus);
		$subStatus = $allHealthMemoryStatus 
		    if ($allHealthMemoryStatus and $allHealthMemoryStatus > $subStatus);
		$subString = healthStateString($subStatus);
		addComponentStatus("m", "Systemboard", $subString);
	    }	    
	} # iRMC
  } #getComponentInformation

  sub getAllCheckData {
	my $testSVSrc  = getMainStateSerialID();
	return if ($testSVSrc);
	my $print = 0;
	$print = 1 if (($main::verbose == 3 and $optChkSystem) 
	    or ($main::verbose == 3 and $optSystemInfo) 
	    or $main::verboseTable==200 
	    or $optAgentInfo);
	getSystemInventoryInfo($print); # always AgentVersion !
	getOverallStatusValues() if (!$optSystemInfo and !$optAgentInfo and !$requiresNoSummary);
	if ($optChkSystem and $exitCode
	and !$allVoltageStatus 
	and !$allCPUStatus 
	and !$allMemoryStatus) 
	{
		$longMessage .= "- Hint: Please check the status on the system itself or via administrative url - \n";
	}
	getComponentInformation() if (!$optSystemInfo and !$optAgentInfo);
	getSystemNotifyInformation() if (!$optAgentInfo 
	    and ($optSystemInfo or $exitCode > 0 or $main::verbose));
	$main::verbose = 1 if ($optSystemInfo and !$main::verbose);
	$notifyMessage = undef if ($optAgentInfo); 
	$exitCode = 0 if ($optAgentInfo and $longMessage =~ m/AgentInfo/);
  } #getAllCheckData
#########################################################################
sub processData {

	# Check Availability and Type:
	if (!$optTimeout) {
	    alarm(60);
	}
	initCIMConnection(); # includes Identify
	my $maxTimeout = 0;
	$maxTimeout = 120 if (!$optTimeout and $isESXi); # catch corrupt ESXi-CIM-Provider
		# TODO - WSMAN Timeout-Default ?
	$maxTimeout = 240 if (!$optTimeout and $optUseMode =~ m/^W/); # SA233525744
	$maxTimeout = 240 if ($isiRMC);

	if ($maxTimeout and !$optTimeout) {
	    alarm($maxTimeout);
	}

	if ($exitCode != 2 and $optChkClass) {
		$exitCode = 3 if (!$optChkIdentify); # not only identify
		my @classInstances = cimEnumerateClass($optClass);
		$main::verbose = 6;
		cimPrintClass(\@classInstances, $optClass);
	} elsif ($exitCode != 2 and !$optChkIdentify) {
		if (!$isESXi and !$isLINUX and !$isWINDOWS and !$isiRMC
		and $main::verbose <= 10) 
		{
		    $exitCode = 3;
		    $msg .= "- ";
		    addMessage("m", "[ERROR] Server Type could not be evaluated");
		} else {
		    $exitCode = 3;
		    #$msg .= "- ";
		    getAllCheckData();
		}
	} # Get All Data
	finishCIMConnection();
} # processData

#### MAIN ################################################################

# store script path
my $path = $0;

handleOptions();
$exitCode = 3;

$main::scriptPath = $path;
$main::scriptPath =~ s/[^\/]+$//;
#print "... scriptPath = $main::scriptPath\n";

#### set timeout
local $SIG{ALRM} = sub {
	print 'UNKNOWN: Timeout' . "\n";
        open ( my $psp, '-|', "ps --ppid $$");
        my $cid = undef;
        while (<$psp>) {
                $cid .= $_;
        }
        close $psp if ($psp);
        my $shpid = $1 if ($cid && $cid =~ m/^(\d+)[^\n]*sh$/m);
        if ($shpid) {
                open ( my $psp, '-|', "ps --ppid $shpid" );
                my $cid = undef;
                while (<$psp>) {
                        $cid .= $_;
                }
		close $psp if ($psp);
                my $wbemclipid = $1 if ($cid && $cid =~ m/^(\d+)[^\n]*wbemcli$/m);
                if ($wbemclipid) {
			#system ( "kill -9 $wbemclipid >/dev/null" );
			open ( my $psp, '-|', "sh - c \"kill -9 $wbemclipid\" >/dev/null 2>&1");
			my $cid = undef;
			while (<$psp>) {
				$cid .= $_;
			}
			close $psp if ($psp);
                }
        }

	exit(3);
};
#local $SIG{PIPE} = "IGNORE";
alarm($optTimeout);

##### DO SOMETHING

$exitCode = 3;

$|++; # for unbuffered stdout print (due to Perl documentation)

processData();

#### 

# output to nagios
#$|++; # for unbuffered stdout print (due to Perl documentation)
if ($msg) {
    $msg =~ s/^\s*//gm; # remove leading blanks
    $msg =~ s/^\-\s*/- /gm; # remove leading blanks
}
if ($notifyMessage) {
    $notifyMessage =~ s/^\s*//gm; # remove leading blanks
    $notifyMessage =~ s/\s*$//m; # remove last blanks
    $notifyMessage =~ s/\n$//m; # remove last break
}
$notifyMessage = undef if ($main::verbose < 1 and ($exitCode==0));
if ($longMessage) {
    $longMessage =~ s/^\s*//m; # remove leading blanks
    $longMessage =~ s/\s*$//m; # remove last blanks
    $longMessage =~ s/\n$//m; # remove last break
}
if ($variableVerboseMessage) {
    $variableVerboseMessage =~ s/^\s*//m; # remove leading blanks
    $variableVerboseMessage =~ s/\n$//m; # remove last break
}
$variableVerboseMessage = undef if ($main::verbose < 2 and !$main::verboseTable);
$longMessage = undef if ($longMessage and $longMessage eq '');


my $stateString = '';
$stateString = $state[$exitCode] if ($state[$exitCode]);
finalize(
	$exitCode, 
	$stateString, 
	$msg,
	(! $notifyMessage	? '': "\n" . $notifyMessage),
	(! $longMessage		? '' : "\n" . $longMessage),
	($variableVerboseMessage ? "\n" . $variableVerboseMessage : ""),
	($performanceData	? "\n |" . $performanceData : ""),
);
################ EOSCRIPT


