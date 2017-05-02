#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2016
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.02
# Date:		2016-08-24

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

#------ This Script uses curl -------#

#### HELP ##############################################
=head1 NAME

check_fujitsu_server_REST.pl - Monitor server using ServerView REST interfaces

=head1 SYNOPSIS

check_fujitsu_server_REST.pl 
  {  -H|--host=<host> [-A|--admin=<host>]
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      [-S|--service=<type>]
      [-u|--user=<username> -p|--password=<pwd>]
      [--cert=<certfile> [--certpassword=<pwd>]]
      [--privkey=<keyfile> [--privkeypassword=<pwd>]]
      [--cacert=<cafile>]
    } |
    -I|--inputfile=<filename>
    { --chkidentify | --systeminfo | --agentinfo
    } |
    { [--chksystem] 
      {[--chkenv] | [--chkfan|--chkcooling] [--chktemp] }
      [--chkpower] 
      {[--chkboard|--chkhardware] |
         [--chkcpu] [--chkvoltage] [--chkmemmodule]}
      [--chkstorage] 
      [--chkdrvmonitor]
      [--chkupdate [{--difflist|--instlist}  [-O|--outputdir=<dir>]]]
    } |
    { [--chkmemperf [-w<percent>] [-c<percent>] ] |
      [--chkfsperf  [-w<percent>] [-c<percent>] ] |
      [--chkcpuperf]
    } |
    { -X|--rest={GET|POST|PUT|DELETE}
      [-R|--requesturl=<urlpath>]
      [-D|--data=<string>]
      [--headers=<headerlines-list>]
      [--ctimeout=<connection timeout in seconds>]
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Checks a Fujitsu server using ServerView REST interfaces.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>  [-A|--admin=<ip>]

Host address as DNS name or ip address of the server.
With optional option -A an administrative ip address can be specified.
This might be the address of iRMC as an example.
The communication is done via the admin address if specified.

These options are used for curl calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>]

REST service port number and transport type.
In the transport type 'http' or 'https' can be specified.

These options are used for curl calles without any preliminary checks.

=item [-S|--service=<type>]

Type of the REST Service.

"A", "Agent" - ServerView Server Control REST Service

"R", "REPORT" - iRMC Report (XML)

=item -u|--user=<username> -p|--password=<pwd>

Authentication data. 

These options are used for curl calles without any preliminary checks.

=item       [--cert=<certfile> [--certpassword=<pwd>]]
      [--privkey=<keyfile> [--privkeypassword=<pwd>]]
      [--cacert=<cafile>]

certfile|keyfile: 
Client certificate file and Client private key file with optional password.
The certfile should include the key information if privkey is not specified.

cafile: CA certificate file is for the verification of the REST service certificates.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.




=item --chkidentify

Tool option to check the access to the REST service.
This option can not be combined with other check options.
There are REST services which require and check no authentication for these requests.

=item --systeminfo

Only print available system information (dependent on server type).
This option can not be combined with other check options

=item --agentinfo

Only print available agent, provider or firmware version (dependent on server type).
This option can not be combined with other check options



=item --chksystem 

=item --chkenv | [--chkfan|--chkcooling] [--chktemp]

=item --chkpower

=item --chkboard|--chkhardware | [--chkcpu] [--chkvoltage] [--chkmemmodule]

=item --chkstorage

Select range of system monitoring information: "chksystem" meaning anything besides
Environment (Cooling Devices, Temperature) or Power (Supply units and consumption).

Options chkenv and chkboard can be splitted to select only single components of 
the above mentioned ranges.

Within functionality behind chkstorage is the monitoring of ServerView RAID data
if available and running.

Hint: --chkfan is an option available for compatibility reasons. 
The selected functionality is identic to chkcooling which supports the monitoring
for any cooling device: fans and liquid pumps





=item --chkdrvmonitor

For server where ServerView Agent is installed: monitor "DriverMonitor" parts.

=item --chkupdate [{--difflist|--instlist}  [-O|--outputdir=<dir>]]

For server where ServerView Agent is installed: monitor "Update Agent" status.

difflist:
Fetch Update component difference list and print the first 10 ones of these and store
all of these in an host specific output file in directory <dir> if specified.

instlist:
Fetch Update installed component list and print the first 10 ones of these and store
all of these in an  host specific output file in directory <dir> if specified.




=item Pure REST: -X|--rest={GET|POST|PUT|DELETE} [-R|--requesturl=<urlpath>] [-D|--data=<string>] 

=item Pure REST: [--headers=<headerlines-list>]

=item Pure REST: [--ctimeout=<connection timeout in seconds>]

REST calls - a wrapper around curl





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


#### GLOBAL OPTIONS ###################################

# init main options
our $argvCnt = $#ARGV + 1;
our $optHost = '';
our $optTimeout = 0;
our $optShowVersion = undef;
our $optHelp = undef;
our $optPort = undef;
our $optAdminHost = undef;
our $optTransportType = undef;

# Authentication
our $optUserName = undef; 
our $optPassword = undef; 
our $optCert = undef;
our $optCertPassword = undef;
our $optPrivKey = undef; 
our $optPrivKeyPassword = undef; 
our $optCacert = undef;

# special sub options
our $optWarningLimit = undef;
our $optCriticalLimit = undef;
our $optInputFile = undef;
#our $optEncryptFile = undef;

#### global option and data
$main::verbose = 0;
$main::verboseTable = 0;
$main::scriptPath = undef;

#### GLOBAL DATA BESIDE OPTIONS
# global control definitions
our $skipInternalNamesForNotifies = 1;	    # suppress print of internal product or model names
our $useDegree = 0;

# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# option cross check result
our $setOverallStatus = undef;	# no chkoptions
our $setOnlySystem = undef;	# only --chksystem

# pure REST options
our $optRestAction	= undef;
our $optRestData	= undef;
our $optRestUrlPath	= undef;
our $optRestHeaderLines	= undef;
our $optConnectTimeout	= undef;

# REST service specific options
our $optServiceType = undef;	# AGENT, REPORT, iRMC, ISM, SOA
our $optChkIdentify = undef;
our $optSystemInfo = undef;
our $optAgentInfo = undef;
our $optUseDegree = undef;

our $optChkSystem = undef;
our $optChkEnvironment = undef;
our	$optChkEnv_Fan = undef;
our       $optChkFanPerformance	= undef;
our	$optChkEnv_Temp = undef;
our $optChkPower = undef;
our $optChkHardware = undef;
our	$optChkCPU = undef;
our	$optChkVoltage = undef;
our	$optChkMemMod = undef;
our $optChkStorage = undef;
our $optChkDrvMonitor = undef;
#
our $optChkCpuLoadPerformance	= undef;
our $optChkMemoryPerformance	= undef;
our $optChkFileSystemPerformance = undef;
our $optChkNetworkPerformance	= undef;
#
our $optChkUpdate = undef;
our     $optChkUpdDiffList	= undef;
our	$optChkUpdInstList	= undef;
our	$optOutdir		= undef;

# init output data
our $exitCode = 3;
our $error = '';
our $msg = '';
our $notifyMessage = '';
our $longMessage = '';
our $variableVerboseMessage = '';
our $performanceData = '';
our $serverID = undef;

# Other Adapter Collection (SCCI) - reference on Hash
our $otherPowerAdapters = undef;
our $otherPowerAdaptersExitCode = undef;
our $otherSystemBoardAdapters = undef;
our $otherSystemBoardAdaptersExitCode = undef;
our $otherStorageAdapters = undef;
our $otherStorageAdaptersExitCode = undef;

our $noSummaryStatus = 0;
our $statusOverall		= undef;
our   $statusEnv		= undef;  
our     $allFanStatus		= undef;
our     $allTempStatus		= undef;
our   $statusPower		= undef; 
our   $statusSystemBoard	= undef; 
our     $allVoltageStatus	= undef;
our     $allCPUStatus		= undef;
our     $allMemoryStatus	= undef;
our   $statusMassStorage	= undef;
our	$raidCtrl		= undef;
our	$raidLDrive		= undef;
our	$raidPDevice		= undef;
our   $statusDrvMonitor		= undef;

#### PRINT / FORMAT FUNCTIONS ##########################################
#----------- 
  sub finalize {
	my $tmpExitCode = shift;
	my $tmpState = shift;
	#$|++; # for unbuffered stdout print (due to Perl documentation)
	my $string = "@_";
	$string = "$tmpState $string" if ($tmpState);
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	print "$string" if ($string);
	print "\n";
	alarm(0); # stop timeout
	close(STDOUT);
	close(STDERR);
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
		if ($tmpCode == 3 or !defined $tmpCode) {
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
  sub calcPercent {
	my $max = shift;
	my $current = shift;
	return undef if (!$max or !$current);
	return undef if ($max !~ m/^\d+$/ or $current !~ m/^\d+$/);
	return undef if ($current > $max);
	my $onePercent = $max / 100;
	my $percentFloat = $current / $onePercent;
	my $percent = undef;
	$percent = sprintf("%.2f", $percentFloat);
	return $percent;
  } # calcPercent
#----------- performance data functions
  sub addKeyUnitToPerfdata {
	my $name = shift;
	my $suffix = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;

	return if (!defined $current);

	if (defined $name and $current) {
		$performanceData .= ' ' . $name . '=' if ($name);
		$performanceData .= $current;
		$performanceData .= $suffix;
		$performanceData .= ';' 
		    if (defined $warning or defined $critical 
		    or  defined $min     or  defined $max);
		$performanceData .= "$warning" if ($warning);
		$performanceData .= ';' 
		    if (defined $critical 
		    or  defined $min     or  defined $max);
		$performanceData .= "$critical" if ($critical);
		$performanceData .= ';' 
		    if (defined $min     or  defined $max);
		$performanceData .= "$min" if (defined $min);
		$performanceData .= ';' 
		    if (defined $max);
		$performanceData .= "$max" if (defined $max);
	}
  } #addKeyUnitToPerfdata

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
  } #addRpmToPerfdata

  sub addTemperatureToPerfdata {
	my $name = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	#my $min = shift;
	#my $max = shift;

	if (defined $name and $current) {
		$name =~ s/[\(\)\.]/_/g;
		while ($name =~ m/__/) {
		    $name =~ s/__/_/g;
		} #while
		$name =~ s/_+$//;
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

#----------- output format functions -for special items
  sub addName {
	my $container = shift;
	my $name = shift;
	my $forcequotes = shift;
	my $tmp = '';
	$name = undef if (defined $name and $name eq '');
	$name = "\"$name\"" if ($name and ($forcequotes or $name =~ m/\s/));
	$tmp .= " Name=$name" if ($name);
	addMessage($container,$tmp);
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
	my $ip6 = shift;
	my $tmp = '';
	$ip = undef if (($ip) and ($ip =~ m/0\.0\.0\.0/));

	$tmp .= " IP=$ip" if ($ip);
	$tmp .= " IPv6=$ip6" if ($ip6);
	return if (!defined $ip and !defined $ip6);
	addMessage($container, $tmp);
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
  sub add100dthVolt {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $min = shift;
	my $max = shift;
	my $tmp = '';
	#
	$current = $current / 100 if ($current);
	$warning = $warning / 100 if ($warning and $warning !~ m/:/);
	$critical = $critical / 100 if ($critical and $critical !~ m/:/);
	$min = $min / 100 if ($min);
	$max = $max / 100 if ($max);
	#
	$current = sprintf("%.2f", $current) if ($current);
	$warning = sprintf("%.2f", $warning) if ($warning and $warning !~ m/:/);
	$critical = sprintf("%.2f", $critical) if ($critical and $critical !~ m/:/);
	$min = sprintf("%.2f", $min) if ($min);
	$max = sprintf("%.2f", $max) if ($max);
	if ($warning and $warning =~ m/^(\d*):(\d*)$/) {
	    my $min = $1;
	    my $max = $2;
	    $min = $min / 100 if ($min);
	    $max = $max / 100 if ($max);
	    $min = sprintf("%.2f", $min) if ($min);
	    $max = sprintf("%.2f", $max) if ($max);
	    $warning = "$min:$max";
	}
	if ($critical and $critical =~ m/^(\d*):(\d*)$/) {
	    my $min = $1;
	    my $max = $2;
	    $min = $min / 100 if ($min);
	    $max = $max / 100 if ($max);
	    $min = sprintf("%.2f", $min) if ($min);
	    $max = sprintf("%.2f", $max) if ($max);
	    $critical = "$min:$max";
	}
	#
	$tmp .= " Current=$current" . "V" if (defined $current);
	$tmp .= " Warning=$warning" . "V" if (defined $warning);
	$tmp .= " Critical=$critical" . "V" if (defined $critical);
	$tmp .= " Min=$min" . "V" if (defined $min);
	$tmp .= " Max=$max" . "V" if (defined $max);
	addMessage($container,$tmp);
  } # add100dthVolt

 sub addKey100dthVolt {
	my $container = shift;
	my $key = shift;
	my $current = shift;
	my $tmp = '';
	return if (!$key);
	#
	$current = $current / 100 if ($current);
	#
	$current = sprintf("%.2f", $current) if ($current);
	#
	$tmp .= " $key=$current" . "V" if (defined $current);
	addMessage($container,$tmp);
  } # addKey100dthVolt

 sub addKeyVolt {
	my $container = shift;
	my $key = shift;
	my $current = shift;
	my $tmp = '';
	return if (!$key);
	#
	$tmp .= " $key=$current" . "V" if (defined $current);
	addMessage($container,$tmp);
  } # addKeyVolt

  sub addKeyRpm {
	my $container = shift;
	my $key = shift;
	my $speed = shift;
	my $tmp = '';
	$speed = undef if (defined $speed and $speed == -1);
	$tmp .= " $key=$speed" . "rpm" if ($speed);
	addMessage($container,$tmp);
  }
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
  sub addKeyMHz {
	my $container = shift;
	my $key = shift;
	my $speed = shift;
	my $tmp = '';
	$speed = undef if (defined $speed and $speed == -1);
	$tmp .= " $key=$speed" . "MHz" if ($speed);
	addMessage($container,$tmp);
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
#### OPTION FUNCTION ######
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
	   		"t|timeout=i", 
			"vtab=i",
	   		"v|verbose=i", 
	   		"w|warning=i", 
	   		"c|critical=i", 
	   		"u|user=s", 
	   		"p|password=s", 
	   		"I|inputfile=s", 
			"inputdir=s",
			"adigest",
			"degree!",

	   		"cert=s", 
	   		"certpassword=s", 
	   		"privkey=s", 
	   		"privkeypassword=s", 
	   		"cacert=s", 

			"X|rest=s",
			"D|data=s",
			"R|requesturlpath=s",
			"headers=s",
			"ctimeout=i",	

			"S|service=s"		,
			"chkidentify"		,
			"systeminfo"		,
			"agentinfo"		,
			"chksystem"		,
			"chkenv"		,
			"chkenv-fan|chkfan|chkcooling"	,
			"chkenv-temp|chktemp"	,
			"chkpower"		,
			"chkhardware|chkboard"	,
			"chkcpu"		,
			"chkvoltage"		,
			"chkmemmodule"		,
			"chkdrvmonitor"		,
			"chkstorage"		,
			"chkfanperf"		,

			"chkupdate"		,
			"difflist",
			"instlist",
			  "O|outputdir=s",

			"chkcpuperf|chkcpuload"	,
			"chkmemperf"		,
			"chkfsperf"		,
			"chknetperf"		,

		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
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
	   		"t|timeout=i", 
	   		"v|verbose=i", 
	   		"w|warning=i", 
	   		"c|critical=i", 
	   		"u|user=s", 
	   		"p|password=s", 
			"adigest",
			"degree!",

	   		"cert=s", 
	   		"certpassword=s", 
	   		"privkey=s", 
	   		"privkeypassword=s", 
	   		"cacert=s", 

			"ctimeout=i",	

			"S|service=s",
			"chkidentify"		,
			"systeminfo"		,
			"agentinfo"		,
			"chksystem"		,
			"chkenv"		,
			"chkenv-fan|chkfan|chkcooling"	,
			"chkenv-temp|chktemp"	,
			"chkpower"		,
			"chkhardware|chkboard"	,
			"chkcpu"		,
			"chkvoltage"		,
			"chkmemmodule"		,
			"chkdrvmonitor"		,
			"chkstorage"		,
			"chkfanperf"		,

			"chkupdate"		,
			"difflist",
			"instlist",
			  "O|outputdir=s",

			"chkcpuperf|chkcpuload"	,
			"chkmemperf"		,
			"chkfsperf"		,
			"chknetperf"		,
		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
	   	#	"E|encryptfile=s"
	    } # type = 1 
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

	print "\n+++mainOptions at the end\n" if ($main::verbose >= 60);
	foreach my $key_m (sort keys %mainOptions) {
		print " $key_m = $mainOptions{$key_m}\n" if ($main::verbose >= 60);
	}
	print "+++\n" if ($main::verbose >= 60);

	return ( %mainOptions);
  } #readOptions

  sub setOptions {	# script specific
	my $refOptions = shift;
	my %options =%$refOptions;
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="A";		$optAdminHost = $options{$k}		if (defined $options{$k});
	$k="degree";	$optUseDegree		= $options{$k} if (defined $options{$k});
	$k="vtab";	$main::verboseTable = $options{$k}	if (defined $options{$k});
	# pure REST specific
	$k="D";		$optRestData = $options{$k}		if (defined $options{$k});
	$k="X";		$optRestAction = $options{$k}		if (defined $options{$k});
	$k="R";		$optRestUrlPath = $options{$k}		if (defined $options{$k});
	$k="ctimeout";	$optConnectTimeout = $options{$k}	if (defined $options{$k});
	$k="headers";	$optRestHeaderLines = $options{$k}	if (defined $options{$k});
	$k="cacert";		$optCacert = $options{$k}		if (defined $options{$k});
	$k="cert";		$optCert = $options{$k}			if (defined $options{$k});
	$k="certpassword";	$optCertPassword = $options{$k}		if (defined $options{$k});
	$k="privkey";		$optPrivKey = $options{$k}		if (defined $options{$k});
	$k="privkeypassword";	$optPrivKeyPassword = $options{$k}	if (defined $options{$k});
	# ACTIONS
	$k="S";			$optServiceType = $options{$k}	if (defined $options{$k});
	$k="agentinfo";		$optAgentInfo = $options{$k}	if (defined $options{$k});
	$k="systeminfo";	$optSystemInfo = $options{$k}	if (defined $options{$k});

	$k="chkidentify";	$optChkIdentify = $options{$k}	if (defined $options{$k});
	$k="chksystem";		$optChkSystem = $options{$k}	if (defined $options{$k});
	$k="chkenv";		$optChkEnvironment = $options{$k} if (defined $options{$k});
	$k="chkenv-fan";	$optChkEnv_Fan = $options{$k}	if (defined $options{$k});
	$k="chkenv-temp";	$optChkEnv_Temp = $options{$k}	if (defined $options{$k});
	$k="chkpower";		$optChkPower = $options{$k}	if (defined $options{$k});
	$k="chkhardware";	$optChkHardware = $options{$k}	if (defined $options{$k});
	$k="chkcpu";		$optChkCPU = $options{$k}	if (defined $options{$k});
	$k="chkvoltage";	$optChkVoltage = $options{$k}	if (defined $options{$k});
	$k="chkmemmodule";	$optChkMemMod = $options{$k}	if (defined $options{$k});
	$k="chkdrvmonitor";	$optChkDrvMonitor = $options{$k} if (defined $options{$k});
	$k="chkstorage";	$optChkStorage = $options{$k}	if (defined $options{$k});
	$k="chkfanperf";	$optChkFanPerformance = $options{$k}	if (defined $options{$k});

	$k="chkcpuperf";	$optChkCpuLoadPerformance = $options{$k}	if (defined $options{$k});
	$k="chkmemperf";	$optChkMemoryPerformance = $options{$k}		if (defined $options{$k});
	$k="chkfsperf";		$optChkFileSystemPerformance = $options{$k}	if (defined $options{$k});
	$k="chknetperf";	$optChkNetworkPerformance = $options{$k}	if (defined $options{$k});

	$k="chkupdate";	$optChkUpdate		= $options{$k} if (defined $options{$k});
	$k="difflist";	$optChkUpdDiffList	= $options{$k} if (defined $options{$k});
	$k="instlist";	$optChkUpdInstList	= $options{$k} if (defined $options{$k});
	$k="O";		$optOutdir		= $options{$k} if (defined $options{$k});

	    # ... the loop below is not realy necessary ... (kae)
	foreach my $key (sort keys %options) {
		#print "options: $key = $options{$key}\n";

		$optShowVersion = $options{$key}              	if ($key eq "V"			); 
		$optHelp = $options{$key}	               	if ($key eq "h"			);
		$optHost = $options{$key}                     	if ($key eq "H"			);
		$optPort = $options{$key}                     	if ($key eq "P"		 	);
		$optTransportType = $options{$key}            	if ($key eq "T"			);
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 
		$optWarningLimit = $options{$key}             	if ($key eq "w"			); 
		$optCriticalLimit = $options{$key}            	if ($key eq "c"		 	); 
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		#$optInputFile = $options{$key}                	if ($key eq "I"			); # this is already set !	
	}
  } #setOptions

  sub evaluateOptions {	# script specific
	my $wrongCombination = undef;

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

	#pod2usage(
	#	-msg		=> "\n" . 'Missing port number!' . "\n",
	#	-verbose	=> 0,
	#	-exitval	=> 3
	#) if (!$optPort and ($optRestAction or $optRestData or $optRestUrlPath));

	pod2usage(
		-msg		=> "\n" . 'Missing password!' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if (!$optPassword and $optUserName);

	pod2usage(
		-msg		=> "\n" . 'Missing PUT data!' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if (!$optRestData and $optRestAction and ($optRestAction eq "PUT"));

	# wrong combination tests
 	#pod2usage({
	#	-msg     => "\n" . "Invalid argument combination \"$wrongCombination\"!" . "\n",
	#	-verbose => 0,
	#	-exitval => 3
	#}) if ($wrongCombination);

	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}
	# after readin of options set defaults
	$optRestAction	    = "GET"	if (!defined $optRestAction and ($optRestData or $optRestUrlPath));
	#$optChkIdentify	    = 999	if (!defined $optRestAction and !defined $optChkIdentify 
	#				and !defined $optAgentInfo and !defined $optSystemInfo);
	$optTransportType   = "https"	if (!defined $optTransportType);
	if (!defined $optChkUpdate and ($optChkUpdDiffList or $optChkUpdInstList)) {
		$optChkUpdate = 999;
	}
	if (!defined $optRestAction and !defined $optChkIdentify 
	and !defined $optAgentInfo and !defined $optSystemInfo and (!defined $optChkUpdate)) 
	{
	    if ((!defined $optChkSystem) 
	    and (!defined $optChkEnvironment) and (!defined $optChkPower)
	    and (!defined $optChkHardware) and (!defined $optChkStorage) 
	    and (!defined $optChkDrvMonitor)
	    and (!defined $optChkCpuLoadPerformance) and (!defined $optChkMemoryPerformance)
	    and (!defined $optChkFileSystemPerformance) and (!defined $optChkNetworkPerformance)
	    and (!defined $optChkEnv_Fan) and (!defined $optChkEnv_Temp) 
	    and (!defined $optChkCPU) and (!defined $optChkVoltage) and (!defined $optChkMemMod)
	    and (!defined $optChkUpdate)
	    ) {
		    $optChkSystem = 999;
		    $optChkEnvironment = 999;
		    $optChkPower = 999;
		    # exotic values if somebody needs to see if an optchk was explizit set via argv or if this 
		    # is default
		    $setOverallStatus = 1;
	    }
	    if ((defined $optChkSystem) 
	    and (!defined $optChkEnvironment) and (!defined $optChkPower)
	    and (!defined $optChkHardware) and (!defined $optChkStorage) 
	    and (!defined $optChkDrvMonitor)
	    and (!defined $optChkCpuLoadPerformance) and (!defined $optChkMemoryPerformance)
	    and (!defined $optChkFileSystemPerformance) and (!defined $optChkNetworkPerformance)
	    and (!defined $optChkEnv_Fan) and (!defined $optChkEnv_Temp) 
	    and (!defined $optChkCPU) and (!defined $optChkVoltage) and (!defined $optChkMemMod)
	    and (!defined $optChkUpdate)
	    ) {
		    $setOnlySystem = 1;
	    }
	    if ($optChkSystem) {
		    $optChkStorage = 999;
	    }
	} # no REST action
	$useDegree = 1 if (defined $optUseDegree and $optUseDegree);
	#
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
#########################################################################
# HELPER
#########################################################################
  sub splitColonKeyValueOptionArray { # colon separated variant ! for HTTP header
	my $optionString = shift;
	my @keyValueArray = ();
	my %keyValues = ();
	return %keyValues if (!$optionString);

	my $rest = $optionString;
	while ($rest) {
	    my $key = undef;
	    my $value = undef;
	    $key = $1 if ($rest =~ m/^([^:]+):/);
	    $rest =~ s/^[^:]+:// if (defined $key); # strip key
	    if ($rest =~ m/^\s*[\"]/) {
		$value = $1 if ($rest =~ m/^(\s*\"[^\"]+\")/);
		$rest =~ s/^\s*\"[^\"]+\"// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\s*\"\"/);
		    $rest =~ s/^\s\"\"// if (defined $value);
		}
	    }
	    elsif ($rest =~ m/^\s*[\']/) {
		$value = $1 if ($rest =~ m/^(\s*\'[^\']+\')/);
		$rest =~ s/^\s*\'[^\']+\'// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\s*\'\'/);
		    $rest =~ s/^\s*\'\'// if (defined $value);
		}
	    }
	    else {
		$value = $1 if ($rest =~ m/^(\s*[^,]+)/);
		$rest =~ s/^\s*[^,]+// if (defined $value);
		if (!defined $value and $rest =~ m/^,/) {
		    $value = '';
		}
	    }
	    $value='' if (!defined $value);
	    $value=~ s/\'//g;
	    $value=~ s/\"//g;
	    $value = " $value" if ($value and $value !~ m/^\s+/);

	    my $oneKeyValue = undef;
	    $key =~ s/^\s*// if ($key);
	    $oneKeyValue .= "$key:" if ($key);
	    $oneKeyValue .= "$value";
	    push (@keyValueArray, $oneKeyValue);

	    $rest =~ s/^,// if ($rest);
	} # while
	if ($main::verbose >= 60) {
	    foreach my $keyValue (@keyValueArray) {
		print "SPLIT ARRAY - $keyValue\n";
	    }
	}
	return @keyValueArray;
  } #splitColonKeyValueOptionArray
#########################################################################
# Pure Socket
#########################################################################
use IO::Socket;
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



#########################################################################
# REST
#########################################################################
our $useRESTverbose = 0;
  sub restAuthenticationOptions {
	my $outoptions = undef;

	# ???? -K/--config <file> Specify which config file to read
	
	$outoptions .= " -u'$optUserName':'$optPassword'" if ($optUserName and $optPassword);

	return $outoptions if ($optTransportType and $optTransportType eq "http");

	#### Certificates
	# --cert <cert[:passwd]> Client certificate file and password (SSL)
	#   CITE: Note that this option assumes a "certificate" file that is the private 
	#   key and the private  certificate  concatenated!
	$outoptions .= " --cacert $optCacert" if ($optCacert);
	$outoptions .= " --cert $optCacert" if ($optCert);
	$outoptions .= ":$optCertPassword" if ($optCert and $optCertPassword);
	$outoptions .= " --key $optPrivKey" if ($optPrivKey);
	$outoptions .= " --pass $optPrivKeyPassword" if ($optPrivKeyPassword);
	
	# --capath ?
	# --cert-type <type> Certificate file type (DER/PEM/ENG) (SSL)
	# --key-type <type> Private key file type (DER/PEM/ENG) (SSL)
	# --egd-file <file> EGD socket path for random data (SSL)
	# --engine <eng>  Crypto engine to use (SSL). "--engine list" for list
	# --random-file <file> File for reading random data from (SSL)

	#### SSL Mode
	# --ciphers <list> SSL ciphers to use (SSL)
	# -2/--sslv2         Use SSLv2 (SSL)
	# -3/--sslv3         Use SSLv3 (SSL)
	# -1/--tlsv1         Use TLSv1 (SSL)
	# ... TLSv1.1 ??? , TLSV1.2 ???
	
	return $outoptions;
  } #restAuthenticationOptions
  our $pRestHandle = undef;
  sub restCall {
	my $action	= shift;
	my $url		= shift;
	my $data	= shift;
	# global optPort,optTransportType, optRestHeaderLines
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	#
	#### build the command
	my $cmd = undef;
	# -s -S ... ommit progrss bar or default statistic but print error messages
	# -w '\n' not used if -v is set
	# --no-keepalive or --keepalive-time nn does not result in corresponding HTTP Header part !
	{   $cmd = "curl --stderr - -s -S";
	    $cmd .= " -v" if ($useRESTverbose or $main::verbose >= 60 or $optRestAction);
	    $cmd .= " --insecure" if ($optTransportType and $optTransportType eq "https");
	    $cmd .= " --connect-timeout $optConnectTimeout" if ($optConnectTimeout);
	    $cmd .= " --max-time $optConnectTimeout" if ($optConnectTimeout);
	    $cmd .= " -X $action" if (!($action eq "GET" and !$data));
	    # ... URL
	    my $fullURL = $optTransportType . "://";
	    $fullURL .= "[$host]" if ($host =~ m/:/); # IPv6
	    $fullURL .= "$host" if ($host !~ m/:/);
	    $fullURL .= ":$optPort" if ($optPort);
	    $fullURL .= "$url" if ($url);
	    $cmd .= " --url \'$fullURL\'";
	    $cmd .= " -g -6" if ($host =~ m/:/); # IPv6
	    # ... Data
	    $cmd .= " --data \"$data\"" if ($data);
	    # ... HTTP Header Parts
	    $cmd .= " -H'Connection: close'";
    	    my @headerlines = splitColonKeyValueOptionArray($optRestHeaderLines);
	    foreach my $keyValue (@headerlines) {
		$cmd .= " -H\'$keyValue\'";
	    } # foreach
	    # ... Authentication
	    my $addon = restAuthenticationOptions();
	    $cmd .= $addon if ($addon);
	    # ...
	    if ($main::verbose >= 10) {
		my $printcmd = $cmd;
		$printcmd =~ s/ \-u[^\s]+/ \-u****:****/;
		print "**** cmd=` $printcmd `\n"; 
	    }
	} # build command
	#### CALL
	open ($pRestHandle, '-|', $cmd);
	print "**** read data ...\n" if ($main::verbose >= 20); 
	my $verboseText = undef;
	my $outHeader = undef
	my $outPayload = undef;
	my $inData = undef;
	my $errText = undef;
	while (<$pRestHandle>) {
		my $tmpStream = $_;
		$tmpStream =~ s/\r\n/\n/g;
		$tmpStream =~ s/\r/\n/g;
		print "$tmpStream" if ($main::verbose >= 60); # $_
		my $mergedVerbose = undef;
		if ($tmpStream =~ m/\* Connection.+to host/) {
			$mergedVerbose = $1 if ($tmpStream =~ /(\* Connection.+to host.*)/);
			$tmpStream =~ s/\* Connection.+to host.*//;
			$tmpStream =~ s/^\s*//;
		} elsif ($tmpStream =~ m/\* Closing connection/) {
			$mergedVerbose = $1 if ($tmpStream =~ /(\* Closing connection.*)/);
			$tmpStream =~ s/\* Closing connection.*//;
			$tmpStream =~ s/^\s*//;
		}

		my $donotuse = 0;
		$donotuse = 1 if ($tmpStream =~ m/data not shown/ or $tmpStream =~ m/^\s*$/);
		if (!$donotuse) {
		    if ($tmpStream =~ m/^\* /) { 
			#print "VERB\n";
			$verboseText .= $tmpStream; 
		    } elsif ($tmpStream =~ m/^> /) {
			#print "IN\n";
			$inData .= $tmpStream;
		    } elsif ($tmpStream =~ m/^< /) {
			#print "OUTH\n";
			$outHeader .= $tmpStream;
		    } elsif ($tmpStream =~ m/^curl:/) {
			#print "ERR\n";
			$errText .= $tmpStream;
		    } else {
			#print "OUTP\n";
			$outPayload .= $tmpStream;
		    }
		    if ($mergedVerbose) {
			$verboseText .= $mergedVerbose; 
			$verboseText .= "\n" if ($verboseText !~ m/\n$/);
		    }
		}
	}
	close $pRestHandle;
	undef $pRestHandle;
	####
	$outPayload =~ s/\s+$// if ($outPayload);
	#### print something for direct calls of REST actions
	if ($optRestAction) {
	    print "HEADER:\n$outHeader\nBODY: " if ($outHeader and $main::verbose);
	    addExitCode(0) if ($outPayload);
	    if (!$outPayload and $outHeader and $outHeader =~ m/HTTP.* 20/) {
		addExitCode(0);
	    }
	    addExitCode(2) if ($errText);
	    addMessage("l",$outPayload) if ($outPayload);
	    addMessage("l",$errText) if ($errText);
	    addMessage("v",$inData) if ($inData and $main::verboseTable == 100);
	    addMessage("v",$outHeader) if ($outHeader and $main::verboseTable == 100);
	} elsif ($main::verbose >= 20) {
	    print "**** RESPONSE: \n$outPayload\n" if ($outPayload);
	}
	####
	return ($outPayload,$outHeader,$errText);
  } #restCall
#########################################################################
# JSON HELPER
#########################################################################
  sub jsonUnescape {
	my $value = shift;
	return undef if (!$value);
	my $rest = $value;
	my $out = undef;
	while ($rest) {
	    my $noesc = undef;
	    $noesc = $1 if ($rest =~ m/^([^\\]*)/);
	    $out .= $noesc		if ($noesc);
	    $rest =~ s/^[^\\]*//	if ($noesc);
	    # \" \\ \/ \b \f \n \r \t \u
	    # skip \r in a special way
	    $out .= "\"" if ($rest =~ m/^\\\"/);
	    $out .= "\\" if ($rest =~ m/^\\\\/);
	    $out .= "/" if ($rest =~ m/^\\[\/]/);
	    #$out .= "\b" if ($rest =~ m/^\\b/);
	    $out .= "\f" if ($rest =~ m/^\\f/);
	    if ($rest =~ m/^\\r\\n/) {
		$out .= "";
	    } elsif ($rest =~ m/^\\r/) {
		$out .= "\n";
	    }
	    $out .= "\n" if ($rest =~ m/^\\n/);
	    $out .= "\t" if ($rest =~ m/^\\t/);
	    #$out .= "\u" if ($rest =~ m/^\\u/);
	    $rest =~ s/^\\.// if ($rest =~ m/^\\/);
	    $rest = undef if (!$rest or $rest =~ m/^\s*$/);
	} #while
	return $out;
  } # jsonUnescape
  sub jsonEscape {
	my $value = shift;
	return undef if (!$value);
	my $out = $value;
	$out =~ s/\\/\\\\\\\\/g;
	# \" \\ \/ \b \f \n \r \t \u
	$out =~ s/\"/\\\\\\\"/g;
	#$out =~ s/\b/\\\\\\b/g;
	$out =~ s/\f/\\\\\\f/g;
	$out =~ s/\n/\\\\\\n/g;
	$out =~ s/\r/\\\\\\r/g;
	$out =~ s/\t/\\\\\\t/g;
	#$out =~ s/\u/\\\\\\u/g;
	return $out;
  } # jsonEscape
  # ... "print" - build json stream
  sub jsonPrintSimpleKeyValue {
	my $key = shift;
	my $value = shift;
	my $stream = undef;
 	$stream .= "\\\"$key\\\":" if (defined $key);
	if (defined $value) {
	    if ($value =~ m/^\d+$/) {
		$stream .= "$value";
	    } elsif ($value =~ m/^true$/i or $value =~ m/^false$/i
	      or $value =~ m/^null$/i
	    ) { # boolean and null
		$stream .= "$value";
	    } else {
		if ($value =~ m/^[A-Z]\:[\\\/]/) { # Windows-File-Name
		    # ATTENTION: SCCI Update-Management uses mixed / and \ in filename
		    $value =~ s/[\\]+/\\/g;
		    $value =~ s/\\/\\\\\\\\/g;
		} elsif ($value =~ m/[\"\n\t\r\b\f\u\\]/) { # other escaped chars
		    $value = jsonEscape($value);
		}
		$stream .= "\\\"$value\\\"";
	    }
	}
	return $stream;
  } #jsonPrintSimpleKeyValue
  sub jsonPrintArray {
	my $key = shift;
	my $refArray = shift;
	return undef if (!$refArray);
	my @array = @{$refArray};
	my $stream = undef;
 	my $prefix = undef;
	$prefix = "\\\"$key\\\":" if (defined $key);
	foreach my $refkeyvalue (@array) {
	    next if (!$refkeyvalue);
	    $stream .= "," if ($stream); # be sequence aware: first , and than { check !
	    $stream .= "[" if (!$stream);
	    #
	    if ($refkeyvalue->{"TYPE"} eq "ELEMENT") {
		$stream .= $refkeyvalue->{"STREAM"};
	    }
	    elsif ($refkeyvalue->{"TYPE"} eq "ARRAY") {
		$stream .= jsonPrintArray($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
	    }
	    elsif ($refkeyvalue->{"TYPE"} eq "OBJECT") {
		$stream .= jsonPrintObject($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
	    }
	} # foreach
	$stream .= "]" if ($stream);
	$stream = $prefix . $stream if ($prefix and $stream);
	return $stream;
  } # jsonPrintArray
  sub jsonPrintObject {
	my $key = shift;
	my $refObject = shift;
	return undef if (!$refObject);
	my @array = @{$refObject};
	my $stream = undef;
 	my $prefix = undef;
	$prefix = "\\\"$key\\\":" if (defined $key);
	foreach my $refkeyvalue (@array) {
	    next if (!$refkeyvalue);
	    $stream .= "," if ($stream); # be sequence aware: first , and than { check !
	    $stream .= "{" if (!$stream);
	    #
	    if ($refkeyvalue->{"TYPE"} eq "ELEMENT") {
		$stream .= $refkeyvalue->{"STREAM"};
	    }
	    elsif ($refkeyvalue->{"TYPE"} eq "ARRAY") {
		$stream .= jsonPrintArray($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
	    }
	    elsif ($refkeyvalue->{"TYPE"} eq "OBJECT") {
		$stream .= jsonPrintObject($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
	    }
	}
	$stream .= "}" if ($stream);
	$stream = $prefix . $stream if ($prefix and $stream);
	return $stream;
  } # jsonPrintObject
  sub jsonPrintMain {
 	my $refObject = shift;
	my $quiet = shift;
	return undef if (!$refObject);
 	my $type = undef;
	my $value = undef;
	my $stream = undef;
	$type = $refObject->{"TYPE"};
	$value = $refObject->{"VALUE"};
	return undef if ($type ne "OBJECT" or !$value);
	my @objarray = @{$value};
	foreach my $refkeyvalue (@objarray) {
		$stream .= "," if ($stream);
		$stream .= "{" if (!$stream);
		if ($refkeyvalue->{"TYPE"} eq "ELEMENT") {
		    $stream .= $refkeyvalue->{"STREAM"};
		}
		elsif ($refkeyvalue->{"TYPE"} eq "ARRAY") {
		    $stream .= jsonPrintArray($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
		}
		elsif ($refkeyvalue->{"TYPE"} eq "OBJECT") {
		    $stream .= jsonPrintObject($refkeyvalue->{"KEY"},$refkeyvalue->{"VALUE"});
		}
	} # foreach
	$stream .= "}" if ($stream);
	print "**** JSON: $stream\n" if ($stream and !$quiet and $main::verbose >= 60);
	return $stream;
  } #jsonPrintMain
  # ... Create from the center to the outer object
  sub jsonCreateSimpleKeyValue {
	my $key = shift;
	my $value = shift;
	my %out = ();
	return %out if (!defined $key and !defined $value);
	$out{"KEY"} = $key if ($key);
	$out{"VALUE"} = $value if (defined $value);
	$out{"TYPE"} = "ELEMENT";
	my $stream = jsonPrintSimpleKeyValue($key,$value);
	$out{"STREAM"} = $stream if (defined $stream);
	return \%out;
  } #jsonCreateSimpleKeyValue
  sub jsonCreateArrayKeyValue {
	my $key = shift;
	my $refArray = shift;
	my %out = ();
	my @array = ();
	$refArray = \@array if (!$refArray);
	$out{"KEY"} = $key;
	$out{"VALUE"} = $refArray;
	$out{"TYPE"} = "ARRAY";
	return wantarray ? (\%out, $refArray) : \%out;
  } # jsonCreateArrayKeyValue
  sub jsonCreateObjectKeyValue {
	my $key = shift;
	my $refObject = shift;
	my %out = ();
	my @array = ();
	$refObject = \@array if (!$refObject);
	$out{"KEY"} = $key;
	$out{"VALUE"} = $refObject;
	$out{"TYPE"} = "OBJECT";
	return wantarray ? (\%out, $refObject) : \%out;
  } # jsonCreateObjectKeyValue
  our $jsonIndent = undef;
  # ... Create from the outer object to the center
  sub jsonAddElement {
	my $refArray = shift;
	my $refKeyValue = shift;
	return if (!$refArray or !$refKeyValue);
	push ( @{$refArray}, $refKeyValue);
  } # jsonAddElement
  sub jsonAddSimpleKeyValue {
	my $refArray = shift;
 	my $key = shift;
	my $value = shift;
	return if (!defined $value or !$refArray);
	my $refKeyValue = jsonCreateSimpleKeyValue($key, $value);
	jsonAddElement($refArray, $refKeyValue);
  } # jsonAddSimpleKeyValue
  sub jsonAddObject {
	my $refArray = shift;
 	my $key = shift;
	(my $refObject, my $refArrObjectParts) = jsonCreateObjectKeyValue($key);
	jsonAddElement($refArray, $refObject);
	return $refArrObjectParts;
  } # jsonAddObject
  sub jsonAddArray {
	my $refArray = shift;
 	my $key = shift;
	(my $refOutArray, my $refArrParts) = jsonCreateArrayKeyValue($key);
	jsonAddElement($refArray, $refOutArray);
	return $refArrParts;
  } # jsonAddArray
  # ... Split
  sub jsonSplitQuoted {
 	my $response = shift;
	my $rest = $response;
	my $value = undef;
	if ($rest =~ m/^\s*\"\"/) {
	    $value = "";
	    $rest =~ s/^\s*\"\"//;
	} else {
	    $value = $1 if ($rest =~ m/^\s*[\"]([^\"]*)\"/); # "..."
	    if ($value) {
		$rest =~ s/^\s*[\"][^\"]*\"//; # remove "..."
		# check inserted \" !!!
		if ($value =~ m/[\\]$/ and $value !~ m/[\\][\\]$/) { 
		    my $search = 1;
		    while ($search) {
			my $next = undef;
			$next = $1 if ($rest =~ m/^([^\"]*)\"/);
			if (defined $next and $next =~ m/^\s*$/) {
			    $search = 0;
			    $value .= "\"";
			    $rest =~ s/^\s*\"\s*//;
			} elsif ($next) {
			    $value .= "\"";
			    $value .= $next;
			    $rest =~ s/^[^\"]*\"//;
			} else {
			    $search  = 0;
			}
			$search = 0 if ($value !~ m/[\\]$/);
		    } #while
		} # if \"
	    }
	    $value = jsonUnescape($value) if ($value =~ m/\\/);
	} # string
	return ($rest, $value);
  } # jsonSplitQuoted
  sub jsonSplitUnQuoted {
 	my $response = shift;
	my $rest = $response;
	my $value = undef;
	$value = $1 if ($rest =~ m/^([^,\]\}]+)/);
	$rest =~ s/^[^,\]\}]+//;
	return ($rest, $value);
  } # jsonSplitUnQuoted
  sub jsonSplitObjectList {
	my $response = shift;
	my @objList = ();
	return \@objList if (!$response);
	$response =~ s/^\s*\{//;
	while ($response and $response !~ m/^\s*}/) {
	    my $key = undef;
	    my $value = undef;
	    my $type = undef;
	    my $refKeyValue = undef;
	    $key = $1 if ($response =~ m/^([^:]+):/);
	    $key =~ s/^\s*[\"\']// if ($key);
	    $key =~ s/[\"\']\s*$// if ($key);
	    $response =~ s/^[^:]+://;
	    if ($response =~ m/^\s*{/) { # OBJECT
		my $save_jsonIndent = $jsonIndent;
		$jsonIndent .= "  ";
		(my $rest, my $refObjList) = jsonSplitObjectList($response);
		$refKeyValue = jsonCreateObjectKeyValue($key,$refObjList);
		$response = $rest;
		$jsonIndent = $save_jsonIndent;
	    } elsif ($response =~ m/^\s*\[/) { # ARRAY
		my $save_jsonIndent = $jsonIndent;
		$jsonIndent .= "  ";
		(my $rest, my $refArrList) = jsonSplitArray($response);
		$refKeyValue = jsonCreateArrayKeyValue($key, $refArrList);
		$response = $rest;
		$jsonIndent = $save_jsonIndent;
	    } elsif ($response =~ m/^\s*[\"]/) { # ELEMENT (string)
		($response, $value) = jsonSplitQuoted($response);
		$refKeyValue = jsonCreateSimpleKeyValue($key,$value);
	    } else { # ELEMENT (unquoted types)
		($response, $value) = jsonSplitUnQuoted($response);
		$refKeyValue = jsonCreateSimpleKeyValue($key,$value);
	    }
	    if ($refKeyValue) {
		push (@objList, $refKeyValue);
		my $key = $refKeyValue->{"KEY"};
		my $type = $refKeyValue->{"TYPE"};
		my $value = $refKeyValue->{"VALUE"};
		print "OBJECTLIST$jsonIndent-$key-$type-$value-\n" if ($main::verbose >= 30);
	    }
	    $response =~ s/^\s*,\s*// if ($response);
	} # while
	$response =~ s/\}\s*//;
	return ($response, \@objList);
  } # jsonSplitObjectList
  sub jsonSplitArray {
	my $response = shift;
	my $rest = $response;
	my @arrList = ();
	return ($response, \@arrList) if (!$response);
	$rest =~ s/^\s*\[//;
	while ($rest and $rest !~ m/^\s*\]/) {
	    my $refKeyValue = undef;
	    if ($rest =~ m/^\s*{/) { # OBJECT
		my $save_jsonIndent = $jsonIndent;
		$jsonIndent .= "  ";
		($rest, my $refObj) = jsonSplitObjectList($rest);
		$refKeyValue = jsonCreateObjectKeyValue(undef,$refObj);
		$jsonIndent = $save_jsonIndent;
	    } elsif ($rest =~ m/^\s*\[/) { # ARRAY
		my $save_jsonIndent = $jsonIndent;
		$jsonIndent .= "  ";
		($rest, my $refArrList) = jsonSplitArray($response);
		$refKeyValue = jsonCreateArrayKeyValue(undef, $refArrList);
		$jsonIndent = $save_jsonIndent;
	    } elsif ($rest =~ m/^\s*[\"]/) { # ELEMENT (string)
		my $value = undef;
		($rest, $value) = jsonSplitQuoted($rest);
		$refKeyValue = jsonCreateSimpleKeyValue(undef,$value);
	    } else { # ELEMENT (unquoted types)
		my $value = undef;
		($rest, $value) = jsonSplitUnQuoted($rest);
		$refKeyValue = jsonCreateSimpleKeyValue(undef,$value);
	    }
	    if ($refKeyValue) {
		push (@arrList, $refKeyValue);
		my $type = $refKeyValue->{"TYPE"};
		my $value = $refKeyValue->{"VALUE"};
		print "OBJECTLIST$jsonIndent--$type-$value-\n" if ($main::verbose >= 30);
	    }
	    $rest =~ s/^\s*,\s*// if ($rest);
	} # while
	$rest =~ s/^\s*\]// if ($rest);
	return ($rest, \@arrList);
  } # jsonSplitArray
  sub jsonSplitResponse { # expects only one main object !
	my $response = shift;
	my $refKeyValueObject = undef;
	my $refKeyvalueMain = undef;
	return undef if (!$response or $response !~ m/^\s*{.*}\s*$/m);
	print "**** split response\n" if ($main::verbose >= 20);
	$jsonIndent="";
	(my $restnada, my $refArray) =  jsonSplitObjectList($response);
	$refKeyvalueMain = jsonCreateObjectKeyValue(undef, $refArray);
	return $refKeyvalueMain;
  } #jsonSplitResponse
  # ... search or walk through json data
  sub jsonGetSubKeyValue {
	my $refParentObject = shift;
	my $key = shift;
	return undef if (!$refParentObject);
	my $type = $refParentObject->{"TYPE"};
	my $value = $refParentObject->{"VALUE"};
	return undef if (!$value or $type eq "ELEMENT");
	#
	my @list = @{$value};
	foreach my $refKeyValue ( @list) {
	    next if (!$refKeyValue);
	    my $t=$refKeyValue->{"TYPE"};
	    my $k=$refKeyValue->{"KEY"};
	    my $v=$refKeyValue->{"VALUE"};
	    print "**** ... compare $key with $k $t $v\n" if ($main::verboseTable == 100);
	    return $refKeyValue if ($refKeyValue->{"KEY"} =~ m/$key/i);
	} # foreach
  } # jsonGetSubKeyValue
  sub jsonGetArrayList {
	my $refKeyValue = shift;
	return () if (!$refKeyValue);
	my $type = $refKeyValue->{"TYPE"};
	return () if ($type and $type ne "ARRAY");
	my $refArray = $refKeyValue->{"VALUE"};
	return @{$refArray};
  } # jsonGetArrayList
  sub jsonGetValue {
	my $refKeyValue = shift;
	return undef if (!$refKeyValue);
	my $type = $refKeyValue->{"TYPE"};
	return undef if ($type and $type ne "ELEMENT");
	return $refKeyValue->{"VALUE"};
  } #jsonGetValue
#########################################################################
# Simple XML Helper
#########################################################################
  sub sxmlSplitObjectTag {
	my $object = shift;
	my @array = (); # stream array
	return () if (!$object);
	my $maintag = undef;
	$maintag = $1 if ($object =~ m/\<*([^>\s]+)/); # main tag
	return () if (!$maintag);
	my $rest = $object;
	# attention: be aware that tags might contain expression relevant signs !
	$rest =~ s/^\<[^>]+\>//;
	$rest =~ s!\s*\<[^<]+\>\s*$!!;
	if ($rest !~ m/\</) { # simple content
	    push (@array, $rest);
	    return @array;
	}
	my $stream = undef;
	my $tag = undef;
	while ($rest) {
	    my $oneendtag = undef;
	    my $nextpart = undef;
	    $tag = $1 if (!$stream and $rest =~ m/^\s*\<([^>\s]+)/); # tag
	    #my $part = sprintf ("%.100s...", $rest);
	    if ($stream and $rest =~ m!^\s*\</!) {
		$oneendtag = $1 if ($rest =~ m!^\s*\</([^\>\s]+)!); # endtag
		if ($tag and $oneendtag and $tag eq $oneendtag) {
		    $nextpart = $1 if ($rest =~ m/^\s*([^\>]+\>)/);
		    $stream .= $nextpart;
		    $rest =~ s/^\s*([^\>]+\>)//;
		    push (@array, $stream);
		    $stream = undef;
		    $tag = undef;
		} else {
		    $nextpart = $1 if ($rest =~ m/^(\<[^\<]*)/);
		    $stream .= $nextpart if ($nextpart);
		    $rest =~ s/^\<[^\<]*//;
		}
	    } elsif (!$stream and $tag) {
		$stream = "<$tag";
		$rest =~ s/^\s*[^\>\s]+//;
	    } else {
		    $nextpart = $1 if ($rest =~ m/^(\<*[^\<]*)/);
		    $stream .= $nextpart if ($nextpart);
		    $rest =~ s/^\<*[^<]*//;
	    }
	    $rest =~ s/^\s+//;
	    #my $part = sprintf ("%.100s...", $rest);
	} #while
	return @array;
  } # sxmlSplitObjectTag
#########################################################################
# SvAgent SCS-REST - SCCI Provider 
#########################################################################
  # OC OperationCode
  # OE Operation ExtensionCode
  # OI Operation Index
  #	    0xE222 "IdentificationParentIpAddress" did not work !!!
  our $gAgentSCSversion = undef;
  our $gAgentSCCIversion = undef;
  our $gAgentSCCIcompany = undef;
  our @gAgentCabinetNumbers = ();
  our $gAgentHasMultiCabinets = undef;
  our $gAgentGotAllNumbers = undef;
  our	%gAgentCoolingNumber = ();
  our   %gAgentTemperatureNumber = ();
  our   %gAgentPSUNumber = ();
  our   %gAgentCPUNumber = ();
  our   %gAgentVoltageNumber = ();
  our   %gAgentMemModNumber = ();
  our   %gAgentDrvMonNumber = ();
  our $gAgentGotAllRAIDNumbers = undef;
  our   $gAgentRAIDCtrlNumber = undef;
  our   %gAgentRAIDPDeviceNumber = ();
  our   %gAgentRAIDLDriveNumber = ();
  our   %gAgentRAIDBatteryNumber = ();
  our   %gAgentRAIDPortNumber = ();
  our   %gAgentRAIDEnclosureNumber = ();
  our %gAgentOC = (
	"DetectedSECabinets"		=> 0x0220,

	"PowerConsumptionCurrentValue"			=> 0x0533,
	"PowerConsumptionLimitStatus"			=> 0x0534,
	"UtilizationNominalSystemPowerConsumption"	=> 0x0930,
	"UtilizationCurrentSystemPowerConsumption"	=> 0x0931,
	"UtilizationCurrentPerformanceControlStatus"	=> 0x0932,
	"UtilizationNominalMinSystemPowerConsumption"	=> 0x0933,
	"UtilizationPowerConsumptionRedundancyLimit"	=> 0x0934,

	#"ReadSystemInformation"	=> 0x0C00,
	"CabinetSerialNumber"		=> 0x0C00,
	"CabinetModel"			=> 0x0C00,
	"ChassisModel"			=> 0x0C00,

	"StatusTreeSubsystemStatus"		=> 0x2301,
	"StatusTreeSubsystemName"		=> 0x2302,
	"StatusTreeNumberSubsysComponents"	=> 0x2305,
	"StatusTreeSubsysComponentStatus"	=> 0x2306,
	"StatusTreeSubsysComponentName"		=> 0x2307,
	"StatusTreeSystemStatus"		=> 0x230F,

	"NumberFans"				=> 0x0300,
	"NumberTempSensors"			=> 0x0400,
	"NumberPowerSupplies"			=> 0x0500,
	"NumberVoltages"			=> 0x0520,
	"NumberCPUs"				=> 0x0600,
	"NumberMemoryModules"			=> 0x0700,
	"NetworkInfoNumberInterfaces"		=> 0x1700,
	"DrvMonNumberComponents"		=> 0x1800,

	"FanStatus"				=> 0x0301,
	"CurrentFanSpeed"			=> 0x0302,
	"FanDesignation"			=> 0x0304,
	"CoolingDeviceType"			=> 0x0306,
	"FanMaximumSpeed"			=> 0x0313,

	"TempSensorStatus"			=> 0x0401,
	"CurrentTemperature"			=> 0x0402,
	"TempSensorDesignation"			=> 0x0404,

	"PowerSupplyStatus"			=> 0x0501,
	"PowerSupplyDesignation"		=> 0x0504,
	"PowerSupplyLoad"			=> 0x0506,
	"PowerSupplyNominal"			=> 0x0507,
	
	"VoltageStatus"				=> 0x0521,
	"VoltageDesignation"			=> 0x0522,
	"VoltageThresholds"			=> 0x0523,
	"CurrentVoltage"			=> 0x0524,
	"VoltageOutputLoad"			=> 0x0525,
	"VoltageFrequency"			=> 0x0526,
	"VoltageNominal"			=> 0x0527,
	"VoltageWarningThresholds"		=> 0x052A,

	"CPUStatus"				=> 0x0601,
	"CPUSocketDesignation"			=> 0x0602,
	"CPUManufacturer"			=> 0x0604,
	"CPUModelName"				=> 0x0605,
	"CpuUsage"				=> 0x0612,
	"CPUFrequency"				=> 0x061D,
	"CPUInfo"				=> 0x0603,

	"CpuOverallUsage"			=> 0x0613,

	"MemoryModuleStatus"			=> 0x0701,
	"MemoryModuleSocketDesignation"		=> 0x0702,
	"MemoryModuleConfiguration"		=> 0x0707,
	"MemoryModuleFrequency"			=> 0x0709,
	"MemoryModuleSize"			=> 0x070A,
	"MemoryModuleType"			=> 0x070B,
	"MemoryModuleFrequencyMax"		=> 0x070E,
	"MemoryModuleVoltage"			=> 0x070F,
	"MemoryBoardDesignation"		=> 0x0752,
	"MemoryModuleInfo"			=> 0x0703,

	"UtilizationSystemMemory"		=> 0x0920,

	"FileSystemNumberVolumes"		=> 0x1510,
	"FileSystemVolumePathNames"		=> 0x1511,
	"FileSystemVolumeDevicePath"		=> 0x1512,
	"FileSystemVolumeTotalSize"		=> 0x1513,
	"FileSystemVolumeFreeSize"		=> 0x1514,
	"FileSystemVolumeFileSystemName"	=> 0x1515,
	"FileSystemVolumeSerialNumber"		=> 0x1516,
	"FileSystemVolumeLabel"			=> 0x1517,
	"FileSystemVolumeUsage"			=> 0x1518,
	"FileSystemVolumeType"			=> 0x1519,

	"NetworkInfoIfDescription"		=> 0x1702,
	"NetworkInfoIfIpAddress"		=> 0x1703,
	"NetworkInfoIfMacAddress"		=> 0x1707,
	"NetworkInfoIfConnectionName"		=> 0x170D,
	"NetworkInfoIfAdapterIndex"		=> 0x1720,

	"NetworkInfoAdapterNumber"		=> 0x1710,
	"NetworkInfoAdapterName"		=> 0x1712,
	"NetworkInfoAdapterDescription"		=> 0x1713,

	"NetworkInfoIfUsage"			=> 0x170B,
	"NetworkInfoIfSpeed"			=> 0x170C,
	"NetworkInfoUtilization"		=> 0x170E,

	"DrvMonComponentStatus"			=> 0x1801,
	"DrvMonComponentName"			=> 0x1803,
	"DrvMonComponentLocation"		=> 0x1804,
	"DrvMonComponentClass"			=> 0x1805,
	"DrvMonComponentDriverName"		=> 0x1807,

	"RaidOverallStatus"			=> 0x2120,
	"RaidAdapterOverallStatus"		=> 0x2121,
	"RaidLogicalDrivesOverallStatus"	=> 0x2122,
	"RaidPhysicalDrivesOverallStatus"	=> 0x2123,
	"RaidOverallSmartStatus"		=> 0x2125,

	"RaidNumberAdapters"			=> 0x2110,
	"RaidNumberPhysicalDrives"		=> 0x2130,
	"RaidNumberLogicalDrives"		=> 0x2150,
	"RaidNumberBatteryBackupUnits"		=> 0x2160,
	"RaidNumberAdapterPorts"		=> 0x2180,
	"RaidNumberEnclosures"			=> 0x2190,

	"RaidAdapterName"			=> 0x2111,
	"RaidAdapterType"			=> 0x2112,
	"RaidAdapterStatus"			=> 0x2116,
	"RaidAdapterProperty"			=> 0x211D,

	"RaidPhysicalDriveStatus"		=> 0x2131,
	"RaidPhysicalDriveSmartStatus"		=> 0x2132,
	"RaidPhysicalDriveName"			=> 0x2133,
	"RaidPhysicalDriveBusType"		=> 0x2134,
	"RaidPhysicalDrivePhysicalSize"		=> 0x2135,
	"RaidPhysicalDriveProperty"		=> 0x213D,
	"RaidPhysicalDriveEnclosureOid"		=> 0x213B,
	"RaidPhysicalDriveAdapterPortOid"	=> 0x213C,

	"RaidLogicalDriveStatus"		=> 0x2151,
	"RaidLogicalDriveName"			=> 0x2152,
	"RaidLogicalDriveLogicalSize"		=> 0x2153,
	"RaidLogicalDrivePhysicalSize"		=> 0x2154,
	"RaidLogicalDriveRaidLevel"		=> 0x2155,
	"RaidLogicalDriveProperty"		=> 0x215D,

	"RaidBatteryBackupUnitName"		=> 0x2161,
	"RaidBatteryBackupUnitStatus"		=> 0x2162,
	"RaidAdapterPortName"			=> 0x2181,
	"RaidAdapterPortStatus"			=> 0x2182,
	"RaidEnclosureName"			=> 0x2191,
	"RaidEnclosureStatus"			=> 0x2192,
	"RaidEnclosureAdapterPortOid"		=> 0x219C,

	"UmServerStatus"			=> 0x3330,
	"UmDiffNumberComponents"		=> 0x3300,
	"UmDiffComponentPath"			=> 0x3301,
	"UmDiffComponentVersion"		=> 0x3304,
	"UmDiffInstalledVersion"		=> 0x3305,
	"UmDiffRepos2InstRanking"		=> 0x3308,
	"UmDiffIsMandatoryComponent"		=> 0x3309,
	"UmDiffPreRequisitesText"		=> 0x330A,
	"UmDiffUpdateVendorSeverity"		=> 0x330B,
	"UmDiffRebootRequired"			=> 0x3310,
	"UmDiffInstallDuration"			=> 0x3311,
	"UmDiffDownloadSize"			=> 0x3312,
	"UmDiffVendor"				=> 0x3315,

	#"ReadConfigurationSpace"		=> 0xE001,
	"ConfCabinetLocation"			=> 0xE001,
	"ConfSystemDescription"			=> 0xE001,
	"ConfSystemContact"			=> 0xE001,
	"ConfSystemName"			=> 0xE001,
	"ConfServerChassisModel"		=> 0xE001,
	"ConfServerMgmtIpAddress"		=> 0xE001,
	"ConfWarningTempThresh"			=> 0xE001,
	"ConfCriticalTempThresh"		=> 0xE001,
	"ConfPowerLimitModeMaxUsage"		=> 0xE001,
	"ConfPowerLimitModeThreshold"		=> 0xE001,
	"ConfBMCIpAddr"				=> 0xE001,
	"ConfBmcIpv6Address"			=> 0xE001,
	"ConfBMCMACAddr"			=> 0xE001,
	"ConfBMCNetworkName"			=> 0xE001,

	"SystemHostName"			=> 0xE107,
	"SystemHostNameFQDN"			=> 0xE107,
	"IdentificationCabinetNumber"		=> 0xE204,
	"IdentificationPartitionId"		=> 0xE207,
	"IdentificationPartitionName"		=> 0xE208,
	"IdentificationChassisCabinetNumber"	=> 0xE209,
	"IdentificationUuid"			=> 0xE20B,
	"IdentificationUuidBigEndian"		=> 0xE20C,
	"IdentificationAdminURLasIP"		=> 0xE20D,
	"IdentificationParentIpAddress"		=> 0xE222,
	"IdentificationParentMacAddress"	=> 0xE226,
	"OsDesignation"				=> 0xE252,
	"OsVersion"				=> 0xE254,
  );
  our %gAgentOE = (
	"SystemHostName"	=> 0,
	"SystemHostNameFQDN"	=> 1,
	"IdentificationAdminURLasIP"		=> 0,
        "OsVersion"		=> 0,

	"ChassisModel"		=> 0x0108,
	"CabinetSerialNumber"	=> 0x0600,
	"CabinetModel"		=> 0x0608,

	"ConfServerMgmtIpAddress"	=> 0x000C,
	"ConfWarningTempThresh"		=> 0x0090,
	"ConfCriticalTempThresh"	=> 0x0091,
	"ConfCabinetLocation"		=> 0x0200,
	"ConfSystemName"		=> 0x0201,
	"ConfSystemDescription"		=> 0x0203,
	"ConfSystemContact"		=> 0x0204,
	"ConfServerChassisModel"	=> 0x0206,
	"ConfBMCIpAddr"			=> 0x1440,
	"ConfBMCMACAddr"		=> 0x1445,
	"ConfBMCNetworkName"		=> 0x1430,
	"ConfBmcIpv6Address"		=> 0x1A25,
	"ConfPowerLimitModeMaxUsage"	=> 0x1A06,
	"ConfPowerLimitModeThreshold"	=> 0x1A09,

  );
 ####
  sub agentJson_CreateJsonCmd {
	(my $refMain, my $refArrMainParts) = jsonCreateObjectKeyValue(undef);
	my $refArrSIPParts = jsonAddObject($refArrMainParts, "SIP");
	jsonAddSimpleKeyValue($refArrSIPParts,"V",1);
	my $refArrCmdParts = jsonAddArray($refArrSIPParts, "CMD");
	return ($refMain,$refArrCmdParts);
  } #agentJson_CreateJsonCmd
  sub agentJson_AddCmd {
	my $refCmdArray = shift;
	my $scci = shift;
	my $currentOE = shift;
	my $currentOI = shift;
	my $currentCA = shift;
	my $currentDA = shift;
	my $refArrParts = jsonAddObject($refCmdArray, undef);
	my $oc = undef;
	my $oe = $currentOE; # numeric OE
	$oe = $gAgentOE{$currentOE} if (defined $currentOE and $currentOE !~ m/^\d*$/); # named OE
	$oc = $gAgentOC{$scci};
	$oe = $gAgentOE{$scci} if (!defined $currentOE);
	return if (!$oc);

	jsonAddSimpleKeyValue($refArrParts,"OC",$oc);
	jsonAddSimpleKeyValue($refArrParts,"OE",$oe);
	jsonAddSimpleKeyValue($refArrParts,"OI",$currentOI);
	jsonAddSimpleKeyValue($refArrParts,"CA",$currentCA);
	jsonAddSimpleKeyValue($refArrParts,"DA",$currentDA);
  } #agentJson_AddCmd
  sub agentJson_CallCmd {
	my $refMain = shift;
      	my $stream = jsonPrintMain($refMain);
	(my $providerout, my $outheader, my $errtext) = 
		restCall("POST","/rest/scci/JsonRequest?aid=SvNagios",$stream);
	my $rc = agent_CheckError($providerout, $outheader, $errtext);
	return ($rc, undef) if ($rc == 2);
	return ($rc, $providerout);
  } # agentJson_CallCmd
  sub agentJson_ExtractCmd {
	my $providerout = shift;
	return undef if (!$providerout);
	my $refoutMain = undef;  
	$refoutMain = jsonSplitResponse($providerout);
	my $sipobj = jsonGetSubKeyValue($refoutMain, "SIP");
	return undef if (!$sipobj);
	my $refCmdarr = jsonGetSubKeyValue($sipobj, "CMD");
	return $refCmdarr;
  } # agentJson_ExtractCmd
  sub agentJson_GetCmdSimpleData { # this is for simple "DA" values !
	my $refCmdArray = shift;
	my $scci = shift;
	my $currentOE = shift;	
	my $currentOI = shift;
	my $currentCA = shift;
	return undef if (!$refCmdArray or!$scci);
	my @cmdKeyValues = jsonGetArrayList($refCmdArray);
	return undef if ($#cmdKeyValues < 0);
	my $oc = undef;
	my $oe = $currentOE; # numeric OE
	$oe = $gAgentOE{$currentOE} if (defined $currentOE and $currentOE !~ m/^\d*$/); # named OE
	$oc = $gAgentOC{$scci};
	$oe = $gAgentOE{$scci} if (!defined $currentOE);
	#	
	foreach my $refCmdKeyValue (@cmdKeyValues) {
	    next if (!$refCmdKeyValue);
	    my $responseOC = undef;
	    my $responseOE = undef;
	    my $responseOI = undef;
	    my $responseCA = undef;
	    my $responseDA = undef;
	    $responseOC = jsonGetSubKeyValue($refCmdKeyValue, "OC");
	    $responseOE = jsonGetSubKeyValue($refCmdKeyValue, "OE") if (defined $oe);
	    $responseOI = jsonGetSubKeyValue($refCmdKeyValue, "OI") if (defined $currentOI);
	    $responseCA = jsonGetSubKeyValue($refCmdKeyValue, "CA") if (defined $currentCA);
	    $responseDA = jsonGetSubKeyValue($refCmdKeyValue, "DA");
	    my $valueOC = undef;
	    my $valueOE = undef;
	    my $valueOI = undef;
	    my $valueCA = undef;
	    my $valueDA = undef;
	    $valueOC = jsonGetValue($responseOC) if (defined $responseOC);
	    $valueOE = jsonGetValue($responseOE) if ($oe and defined $responseOE);
	    $valueOI = jsonGetValue($responseOI) if (defined $currentOI and defined $responseOI);
	    $valueCA = jsonGetValue($responseCA) if (defined $currentCA and defined $responseDA);
	    $valueOE = 0 if (!defined $valueOE);
	    $valueOI = 0 if (!defined $valueOI);
	    $valueCA = 0 if (!defined $valueCA);
		# ... OI is ommited in JSON response if 0
	    next if (defined $oc and (!defined $valueOC or $valueOC ne $oc));
	    next if (defined $oe and ($valueOE ne $oe));
	    next if (defined $currentOI and ($valueOI ne $currentOI));
	    next if (defined $currentCA and ($valueCA ne $currentCA));
	    if ($responseDA) {
		if ($responseDA->{"TYPE"} eq "ELEMENT") {
		    $valueDA = jsonGetValue($responseDA);
		} elsif ($responseDA->{"TYPE"} eq "OBJECT") {
		    $valueDA = jsonPrintMain($responseDA,1);
		} elsif ($responseDA->{"TYPE"} eq "ARRAY") {
		    my $str = $responseDA->{"VALUE"};
		    my $k = $responseDA->{"KEY"};
		    #$valueDA = jsonPrintArray(undef, $responseDA);
		    $valueDA = jsonPrintArray(undef, $responseDA->{"VALUE"});
		}
	    }
	    #$valueDA = jsonUnescape($valueDA) if ($valueDA =~ m/[\\]/);
	    return $valueDA;
	} # foreach
	return undef;
  } # agentJson_GetCmdSimpleData
  sub agentJson_RawWordSplit {
	my $raw = shift;
	my @nrarr = ();
	return @nrarr if (!defined $raw or $raw !~ m/RAW/);
	#my @nrarr = ($raw =~ m/[^\d]*(\d+)[^\d]*/); ... not working :-(
	$raw =~ s/^.*\[//;
	$raw =~ s/\].*$//;
	@nrarr = split(/,/,$raw);
	my @outarr = ();
	for (my $i=0; $i <= $#nrarr; $i++) {
	    my $nr = $nrarr[$i];
	    $i++;
	    my $next = $nrarr[$i];
	    next if ($nr !~ m/^\d+$/ or $next !~ m/^\d+$/);
	    $nr += $next * 256;
	    push (@outarr, $nr);
	} # for
	return @outarr;
  } # agentJson_RawWordSplit
  sub agentJson_RawDWordSplit {
	my $raw = shift;
	my @nrarr = ();
	return @nrarr if (!defined $raw or $raw !~ m/RAW/);
	#my @nrarr = ($raw =~ m/[^\d]*(\d+)[^\d]*/); ... not working :-(
	$raw =~ s/^.*\[//;
	$raw =~ s/\].*$//;
	@nrarr = split(/,/,$raw);
	my @outarr = ();
	for (my $i=0; $i <= $#nrarr; ) {
	    last if ($i+3 >$#nrarr);
	    my $n1 = $nrarr[$i];
	    my $n2 = $nrarr[$i+1]; # 256
	    my $n3 = $nrarr[$i+2]; # 65536
	    my $n4 = $nrarr[$i+3]; # 16777216
	    next if ($n1 !~ m/^\d+$/ or $n2 !~ m/^\d+$/ or $n3 !~ m/^\d+$/ or $n4 !~ m/^\d+$/);
	    $n1 += $n2 * 256;
	    $n1 += $n3 * 65536;
	    $n1 += $n4 * 16777216;
	    push (@outarr, $n1);
	    $i += 4;
	} # for
	return @outarr;
  } # agentJson_RawDWordSplit
  sub agentJson_RawDWordLongSplit {
	my $raw = shift;
	my @nrarr = ();
	return @nrarr if (!defined $raw or $raw !~ m/RAW/);
	#my @nrarr = ($raw =~ m/[^\d]*(\d+)[^\d]*/); ... not working :-(
	$raw =~ s/^.*\[//;
	$raw =~ s/\].*$//;
	@nrarr = split(/,/,$raw);
	my @outarr = ();
	for (my $i=0; $i <= $#nrarr; ) {
	    last if ($i+7 >$#nrarr);
	    my $n1 = $nrarr[$i];
	    my $n2 = $nrarr[$i+1]; # 256
	    my $n3 = $nrarr[$i+2]; # 65536
	    my $n4 = $nrarr[$i+3]; # 16777216
	    my $n5 = $nrarr[$i+4]; # 
	    my $n6 = $nrarr[$i+5]; # 
	    my $n7 = $nrarr[$i+6]; # 
	    my $n8 = $nrarr[$i+7]; # 
	    if (!$n1 and !$n2 and !$n3 and !$n4 and !$n5 and !$n6 and !$n7 and !$n8) {
		push (@outarr, 0);
		$i += 8;
		next;
	    }
	    last if ($n1 !~ m/^\d+$/ or $n2 !~ m/^\d+$/ or $n3 !~ m/^\d+$/ or $n4 !~ m/^\d+$/
		or   $n5 !~ m/^\d+$/ or $n6 !~ m/^\d+$/ or $n7 !~ m/^\d+$/ or $n8 !~ m/^\d+$/);
	    if ($n1 == 255 and $n2 == 255 and $n3 == 255 and $n4 == 255
	    and $n5 == 255 and $n6 == 255 and $n7 == 255 and $n8 == 255) {
		push (@outarr, -1);
		$i += 8;
		next;
	    }
	    $n1 += $n2 * 256 if ($n2);
	    $n1 += ($n3* 256)* 256 if ($n3);
	    $n1 += (($n4* 256)* 256)* 256 if ($n4);
	    $n1 += ((($n5* 256)* 256)* 256)* 256 if ($n5);
	    $n1 += (((($n6* 256)* 256)* 256)* 256)* 256 if ($n6);
	    $n1 += ((((($n7* 256)* 256)* 256)* 256)* 256)*256 if ($n7);
	    push (@outarr, $n1);
	    $i += 8;
	} # for
	return @outarr;
  } # agentJson_RawDWordLongSplit
  sub agentJson_RawIPv4Address {
	my $raw = shift;
	return undef if (!defined $raw or $raw !~ m/RAW/);
	$raw =~ s/^.*\[//;
	$raw =~ s/\].*$//;
	my $ip = $raw;
	$ip =~ s/,/\./g if ($ip);
	return $ip;
  } # agentJson_RawIPv4Address
  sub agentJson_RawIPAddresses {
	my $raw = shift;
	return undef if (!defined $raw or $raw !~ m/RAW/);
	my $chk = $raw;
	$chk =~ s/^.*\[//;
	$chk =~ s/\].*$//;
	my @nrarr = ();
 	@nrarr = split(/,/,$chk);
	my $ipv4 = undef;
	my $ipv6 = undef;
	if ($#nrarr == 3) {
	    return (agentJson_RawIPv4Address($raw),undef);
	} elsif ($#nrarr == 15) {
	    for (my $i=0; $i <= $#nrarr; $i++) {
		my $nr = $nrarr[$i];
		next if (!defined $nr);
		my $hex = sprintf ("%02x", $nr);
		$ipv6 .= ":" if ($ipv6);
		$ipv6 .= "$hex";
		$i++;
		$nr = $nrarr[$i];
		$hex = sprintf ("%02x", $nr);
		$ipv6 .= "$hex";
	    } # for 
	} elsif ($#nrarr == 19) {
	    for (my $i=0; $i <= 3; $i++) {
		my $nr = $nrarr[$i];
		next if (!defined $nr);
		$ipv4 .= "." if ($ipv4);
		$ipv4 .= "$nr";
	    } # for
	    for (my $i=4; $i <= $#nrarr; $i++) {
		my $nr = $nrarr[$i];
		next if (!defined $nr);
		my $hex = sprintf ("%02x", $nr);
		$ipv6 .= ":" if ($ipv6);
		$ipv6 .= "$hex";
		$i++;
		$nr = $nrarr[$i];
		$hex = sprintf ("%02x", $nr);
		$ipv6 .= "$hex";
	    } # for 
	}
	return ($ipv4,$ipv6);
 } #agentJson_RawIPAddresses
  sub agentJson_RawMacAdresses {
	my $raw = shift;
	my @nrarr = ();
	return @nrarr if (!defined $raw or $raw !~ m/RAW/);
	$raw =~ s/^.*\[//;
	$raw =~ s/\].*$//;
	@nrarr = split(/,/,$raw);
	my $mac = undef;
	my $eui = undef;
	for (my $i=0; $i <= $#nrarr; $i++) {
	    my $nr = $nrarr[$i];
	    next if (!defined $nr);
	    my $hex = sprintf ("%02X", $nr);
	    if ($i < 6 and ($#nrarr == 5 or $#nrarr == 11)) {
		$mac .= ":" if ($mac);
		$mac .= "$hex";
	    } elsif ($#nrarr == 7 or ($i > 5 and $#nrarr == 11) ) {
		$eui .= ":" if ($eui);
		$eui .= "$hex";
	    }
	} # for
	return ( $mac, $eui );
  } # agentJson_RawMacAdresses
 ####
  sub agent_CheckError {
	my $providerout = shift;
	my $outheader = shift;
	my $errtext = shift;
	my $tmpExitCode = 3;
	if ($outheader and $outheader =~ m/HTTP.[\d\.]+ 401/) {
	    addMessage("m","- ") if (!$msg);
	    addMessage("m", "Authentication failed !");
	    addExitCode(2);
	    $tmpExitCode = 2;
	    if ($providerout and $providerout =~ m/faultdata=\"{/) {
		my $providererr = $providerout;
		$providererr =~ s/\n//g;
		$providererr =~ s/.*faultdata=\"//;
		$providererr =~ s/\" fault.receiver.url.*//;
		addMessage("l",$providererr);
	    } elsif ($providerout) {
		addMessage("l",$providerout);
	    }
	} # 401 
	elsif ($outheader and $outheader !~ m/HTTP.[\d\.]+ 20\d/) {
	    addMessage("m","- ") if (!$msg);
	    addMessage("m", "Failure response !");
	    addExitCode(2);
	    $tmpExitCode = 2;
	    if ($providerout and $providerout =~ m/faultdata=\"{/) {
		my $providererr = $providerout;
		$providererr =~ s/\n//g;
		$providererr =~ s/.*faultdata=\"//;
		$providererr =~ s/\" fault.receiver.url.*//;
		addMessage("l",$providererr);
	    } elsif ($providerout) {
		addMessage("l",$providerout);
	    }
	} elsif ($providerout and $providerout =~ m/\"error\"/) {
	    addMessage("m","- ") if (!$msg);
	    addMessage("m", "Some error !");
	    addMessage("l",$providerout);
	    addMessage("l","\n") if ($errtext);
	    addMessage("l",$errtext) if ($errtext);
	    addExitCode(2);
	    $tmpExitCode = 2;
	} elsif (!defined $providerout) {
	    addMessage("m","- ") if (!$msg);
	    addMessage("m", "Empty response !");
	    addMessage("l",$errtext) if ($errtext);
	    addExitCode(2);
	    $tmpExitCode = 2;
	}
	return $tmpExitCode;
  } # agent_CheckError
  sub agent_getNumberOfSensors {
	return if ($gAgentGotAllNumbers);
	# IDEA: get all numbers in ONE call
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"NumberFans");
	    agentJson_AddCmd($refArrayCmd,"NumberTempSensors");
	    agentJson_AddCmd($refArrayCmd,"NumberPowerSupplies");
	    agentJson_AddCmd($refArrayCmd,"NumberCPUs");
	    agentJson_AddCmd($refArrayCmd,"NumberVoltages");
	    agentJson_AddCmd($refArrayCmd,"NumberMemoryModules");
	    agentJson_AddCmd($refArrayCmd,"DrvMonNumberComponents");
	if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
	    foreach my $ca (@gAgentCabinetNumbers) {
		agentJson_AddCmd($refArrayCmd,"NumberFans",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"NumberTempSensors",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"NumberPowerSupplies",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"NumberCPUs",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"NumberVoltages",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"NumberMemoryModules",undef,undef,$ca);
	    }
	}
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $gAgentCoolingNumber{0}	= agentJson_GetCmdSimpleData($refCmd,"NumberFans");
	    $gAgentTemperatureNumber{0}	= agentJson_GetCmdSimpleData($refCmd,"NumberTempSensors");
	    $gAgentPSUNumber{0}		= agentJson_GetCmdSimpleData($refCmd,"NumberPowerSupplies");
	    $gAgentCPUNumber{0}		= agentJson_GetCmdSimpleData($refCmd,"NumberCPUs");
	    $gAgentVoltageNumber{0}	= agentJson_GetCmdSimpleData($refCmd,"NumberVoltages");
	    $gAgentMemModNumber{0}	= agentJson_GetCmdSimpleData($refCmd,"NumberMemoryModules");
	    $gAgentDrvMonNumber{0}	= agentJson_GetCmdSimpleData($refCmd,"DrvMonNumberComponents");
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    $gAgentCoolingNumber{$ca}	= 
			agentJson_GetCmdSimpleData($refCmd,"NumberFans",undef,undef,$ca);
		    $gAgentTemperatureNumber{$ca}= 
			agentJson_GetCmdSimpleData($refCmd,"NumberTempSensors",undef,undef,$ca);
		    $gAgentPSUNumber{$ca}	= 
			agentJson_GetCmdSimpleData($refCmd,"NumberPowerSupplies",undef,undef,$ca);
		    $gAgentCPUNumber{$ca}	= 
			agentJson_GetCmdSimpleData($refCmd,"NumberCPUs",undef,undef,$ca);
		    $gAgentVoltageNumber{$ca}	= 
			agentJson_GetCmdSimpleData($refCmd,"NumberVoltages",undef,undef,$ca);
		    $gAgentMemModNumber{$ca}	= 
			agentJson_GetCmdSimpleData($refCmd,"NumberMemoryModules",undef,undef,$ca);
		    # storage has fan, temp, psu
		}
	    }
	}
	$gAgentGotAllNumbers = 1;
  } # agent_getNumberOfSensors
  sub agent_getNumberforRAID {
	return if ($gAgentGotAllRAIDNumbers);
	# IDEA: get all numbers in TWO calls
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"RaidNumberAdapters");
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $gAgentRAIDCtrlNumber	= agentJson_GetCmdSimpleData($refCmd,"RaidNumberAdapters");
	}
	if (!$gAgentRAIDCtrlNumber) {
	    $gAgentGotAllRAIDNumbers = 1;
	    return;
	}
	#### BUILD
 	($refMain, $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0; $i<$gAgentRAIDCtrlNumber;$i++) {
	    agentJson_AddCmd($refArrayCmd,"RaidNumberPhysicalDrives",$i);
	    agentJson_AddCmd($refArrayCmd,"RaidNumberLogicalDrives",$i);  
	    if ($main::verbose >= 3) {
		agentJson_AddCmd($refArrayCmd,"RaidNumberBatteryBackupUnits",$i);  
		agentJson_AddCmd($refArrayCmd,"RaidNumberAdapterPorts",$i);  
		agentJson_AddCmd($refArrayCmd,"RaidNumberEnclosures",$i);  
	    }
	} # for
	#### CALL REST/JSON
	    ($rc, $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	for (my $i=0; $i<$gAgentRAIDCtrlNumber;$i++) {
	    $gAgentRAIDPDeviceNumber{$i}= agentJson_GetCmdSimpleData($refCmd,"RaidNumberPhysicalDrives",$i);
	    $gAgentRAIDLDriveNumber{$i}	= agentJson_GetCmdSimpleData($refCmd,"RaidNumberLogicalDrives",$i);
	    $gAgentRAIDBatteryNumber{$i} = agentJson_GetCmdSimpleData($refCmd,"RaidNumberBatteryBackupUnits",$i);
	    $gAgentRAIDPortNumber{$i} = agentJson_GetCmdSimpleData($refCmd,"RaidNumberAdapterPorts",$i);
	    $gAgentRAIDEnclosureNumber{$i} = agentJson_GetCmdSimpleData($refCmd,"RaidNumberEnclosures",$i);
	}
	$gAgentGotAllRAIDNumbers = 1;
  } # agent_getNumberforRAID
  sub agent_negativeCheck {
	my $current = shift;
	return undef if (!defined $current);
	if ($current >= 0x8000) {
	    $current = 65536 - $current;
	    $current = "-$current";
	}
	return $current;
  } # agent_negativeCheck
  sub agent_nextIFIPAddress {
	my $ifnr = shift;
	my $n = shift;
	my @ips = ();
	#### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfIpAddress", undef, ($n<<16) + $ifnr);
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return () if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	my $rawips = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfIpAddress", undef, ($n<<16) + $ifnr);
	@ips = agentJson_RawIPAddresses($rawips) if (defined $rawips);
	return @ips;
  } # agent_nextIFIPAddress
 ####
  sub agentConnectionTest {
	# initial tests with http is faster than https !
	my $save_optTransportType = $optTransportType;
	$optTransportType = "http"; $optPort = "3172"; $optRestHeaderLines = undef;
	my $save_optConnectTimeout = $optConnectTimeout;
	$optConnectTimeout  = 20 if (!defined $optConnectTimeout or $optConnectTimeout > 20);
	(my $scsout, my $outheader, my $errtext) = 
		restCall("GET","/cmd?t=connector.NumericVersion",undef);
	my $providerout = undef;
	$scsout = undef if ($scsout and $scsout !~ m/^\d+$/); # 3172-OLD-Remote-Manager
	$gAgentSCSversion = $scsout if ($scsout);
	my $oldAgent = 0;
	if ($scsout and $scsout >= 21000) {
	    ($providerout, $outheader, $errtext) = 
		restCall("GET","/rest/scci/JsonWhat?aid=SvNagios",undef);
	} elsif ($scsout) {
	    $oldAgent = 1;
	}
	# { "SVRemConSCCI": { "version":"7.10.16.04", "date":"Jul 15 2015 16:30:28", "company":"Fujitsu" }}
	if ($providerout) {
	    $gAgentSCCIversion = $providerout;
	    $gAgentSCCIversion =~ s/.*version\"\s*:\s*\"//;
	    $gAgentSCCIversion =~ s/\".*//;
	    $gAgentSCCIcompany = undef;
	    $gAgentSCCIcompany  = $1 if ($providerout =~ m/company.\:.([^\"]+)\"/);
	}
	#
	addExitCode(0) if ($scsout and $providerout);
	addExitCode(2) if (!$scsout or !$providerout); 
	if ($exitCode == 0 and $optChkIdentify) {
	    addMessage("m","- ") if (!$msg);
	    addKeyLongValue("m","REST-Service", "ServerView Server Control");
	}
	if ($exitCode == 2) {
	    if ($optServiceType) {
		addMessage("m","- ") if (!$msg);
		addMessage("m","[ERROR] Unable to connect to ServerView Server Control");
		addMessage("l", $errtext) if ($errtext);
	    } else {
		$errtext = "older ServerView Agent" if ($oldAgent and !defined $errtext);
		$errtext = "missing error hint" if (!defined $errtext);
		addMessage("l","[ERROR] Unable to connect to ServerView Server Control ($errtext)\n");
	    }
	}
	if ($exitCode == 0) {
	    $optServiceType = "Agent" if (!defined $optServiceType);
	    $optPort = "3172"; 
	} else {
	    $optPort = undef;
	}
	$optRestHeaderLines = undef;
	$optTransportType = $save_optTransportType;
	$optConnectTimeout = $save_optConnectTimeout;
  } #agentConnectionTest
  sub agentSerialID {
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"CabinetSerialNumber");
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $serialid = undef;
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $serialid = agentJson_GetCmdSimpleData($refCmd,"CabinetSerialNumber");
	}
	agentAllCabinetNumbers(); # may influence inventory and status monitoring !
	return $serialid;
  } # agentSerialID
  sub agentOverallStatusValues {
	my @statusText = ("Unknown",
	    "OK", "Warning", "Error", "Not present", "Not manageable",
	    "..unexpected..",
	);
	#### BUILD JSON
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"StatusTreeSystemStatus");
	    #agentJson_AddCmd($refArrayCmd,"StatusTreeNumberSubsystems");
	    for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		agentJson_AddCmd($refArrayCmd,"StatusTreeSubsystemStatus", $i);
		agentJson_AddCmd($refArrayCmd,"StatusTreeSubsystemName", $i);
		agentJson_AddCmd($refArrayCmd,"StatusTreeNumberSubsysComponents", $i);
	    } # for
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT REST/JSON
	my %statusTable = ();
	my %nameTable = ();
	my %numberTable = ();
	my $tmpStatusOverall = undef;
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $tmpStatusOverall = agentJson_GetCmdSimpleData($refCmd,"StatusTreeSystemStatus");
	    $tmpStatusOverall = 6 if (!defined $tmpStatusOverall or $tmpStatusOverall < 0 or $tmpStatusOverall > 4);
	    if (defined $tmpStatusOverall) {
		$statusOverall = 3;
		$statusOverall = 0 if ($tmpStatusOverall == 1);
		$statusOverall = 1 if ($tmpStatusOverall == 2);
		$statusOverall = 2 if ($tmpStatusOverall == 3);
	    }
	    
	    for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		my $status = agentJson_GetCmdSimpleData($refCmd,"StatusTreeSubsystemStatus", $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"StatusTreeSubsystemName", $i);
		my $number = agentJson_GetCmdSimpleData($refCmd,"StatusTreeNumberSubsysComponents", $i);
		$statusTable{$i}	= $status;
		$nameTable{$i}		= $name;
		$numberTable{$i}	= $number;
	    } # for
	}
	#### EVAL System
	if ($tmpStatusOverall == 6) {
	    addMessage("m","- ") if (!$msg);
	    addMessage("m", "ATTENTION: Missing system overall status");
	} elsif ($optChkSystem) {
	    addExitCode($statusOverall) if (defined $statusOverall);
	    #addMessage("m","-") if (!$msg);
	    addComponentStatus("m", "Overall", $statusText[$tmpStatusOverall]);
	}
	$noSummaryStatus = 0;
	#### EVAL Sub-Components 1st Level
	    my $iEnvironment = undef;
	    my $iPower = undef;
	    my $iSystemBoard = undef;
	    my $iStorage = undef;
	    my $iDrvMonitor = undef;
	    my $iNetwork = undef;
	    for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		my $printthis = 0;
		my $name   = $nameTable{$i};
		my $status = $statusTable{$i};
		my $tmpExitCode = 3;
		next if (!$name or !defined $status);
		$tmpExitCode = 2 if ($status == 3);
		$tmpExitCode = 1 if ($status == 2);
		$tmpExitCode = 0 if ($status == 1);
		if ($name =~ m/Environment/i) {
		    $iEnvironment = $i;
		    $statusEnv = $tmpExitCode;
		    $printthis = 1 if ($optChkEnvironment);
		    addExitCode($tmpExitCode) if ($optChkEnvironment and $optChkEnvironment != 999);
		} elsif ($name =~ m/PowerSupply/i) {
		    $iPower = $i;
		    $statusPower = $tmpExitCode;
		    $printthis = 1 if ($optChkPower);
		    addExitCode($tmpExitCode) if ($optChkPower and $optChkPower != 999);
		} elsif ($name =~ m/MassStorage/i) {
		    $iStorage = $i;
		    $statusMassStorage = $tmpExitCode;
		    $printthis = 1 if ($optChkStorage);
		    addExitCode($tmpExitCode) if ($optChkStorage and $optChkStorage != 999);
		} elsif ($name =~ m/Systemboard/i) {
		    $iSystemBoard = $i;
		    $statusSystemBoard = $tmpExitCode;
		    $printthis = 1 if ($optChkSystem);
		    addExitCode($tmpExitCode) if ($optChkSystem or $optChkHardware);
		} elsif ($name =~ m/Deployment/i) {
		    $printthis = 1 if ($optChkSystem and $main::verbose and $tmpExitCode != 3);
		} elsif ($name =~ m/Network/i) {
		    $iNetwork = $i;
		    $printthis = 1 if ($optChkSystem and $main::verbose and $tmpExitCode != 3);
		} elsif ($name =~ m/DrvMonitor/i) {
		    $iDrvMonitor = $i;
		    $statusDrvMonitor = $tmpExitCode;
		    $printthis = 1 if ($optChkDrvMonitor);
		    addExitCode($tmpExitCode) if ($optChkDrvMonitor and $optChkDrvMonitor != 999);
		}
		#addMessage("m","-") if (!$msg);
		addComponentStatus("m", $name,$statusText[$status]) if ($printthis);
	    } # for
	    $allFanStatus = 0	if (defined $iEnvironment 
		and defined $statusEnv and $statusEnv ==0);
	    $allTempStatus = 0	if (defined $iEnvironment 
		and defined $statusEnv and $statusEnv == 0);
	    $allVoltageStatus = 0	if (defined $iSystemBoard 
		and defined $statusSystemBoard and $statusSystemBoard == 0);
	    $allCPUStatus = 0	if (defined $iSystemBoard 
		and defined $statusSystemBoard and $statusSystemBoard == 0);
	    $allMemoryStatus = 0	if (defined $iSystemBoard 
		and defined $statusSystemBoard and $statusSystemBoard == 0);
	    my $tmpAllFanStatus = undef;
	    my $tmpAllTempStatus = undef;
	    my $tmpAllVoltageStatus = undef;
	    my $tmpAllCPUStatus = undef;
	    my $tmpAllMemoryStatus = undef;
	#### Sub-Components 2nd Level
	{
	    #### BUILD JSON
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    #agentJson_AddCmd($refArrayCmd,"StatusTreeSystemStatus");
	    my $addedCmd = 0;
	    for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		my $status = $statusTable{$i};
		my $number = $numberTable{$i};
		my $getPartCmds = 0;
		next if (!defined $number or !defined $status or !$status);
		if (defined $iEnvironment and $iEnvironment  == $i) {
		    next if (!$optChkEnvironment and !$optChkEnv_Fan and !$optChkEnv_Temp);
		    $getPartCmds  = 1 if ($optChkEnv_Fan or $optChkEnv_Temp);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		} elsif (defined $iPower and $iPower  == $i) {
		    next if (!$optChkPower);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		} elsif (defined $iStorage and $iStorage == $i) {
		    next if (!$optChkStorage);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		} elsif (defined $iSystemBoard and $iSystemBoard == $i) {
		    next if (!$optChkSystem and !$optChkHardware 
			and !$optChkCPU and !$optChkVoltage and !$optChkMemMod);
		    $getPartCmds  = 1 if ($optChkHardware or $optChkCPU or $optChkVoltage or $optChkMemMod);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		} elsif (defined $iNetwork and $iNetwork == $i) {
		    next if (!$optChkSystem);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		} elsif (defined $iDrvMonitor and $iDrvMonitor == $i) {
		    next if (!$optChkDrvMonitor);
		    $getPartCmds  = 1 if ($status == 2 or $status == 3);
		    $getPartCmds  = 1 if ($main::verbose >= 2);
		}
		if ($getPartCmds) {
		    $addedCmd = 1;
		    for (my $i2nd=0; $i2nd < $number; $i2nd++) {
			agentJson_AddCmd($refArrayCmd,"StatusTreeSubsysComponentStatus", $i, $i2nd);
			agentJson_AddCmd($refArrayCmd,"StatusTreeSubsysComponentName", $i, $i2nd);
		    } # for 2nd Level
		}
	    } #for 1st Level
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain) if ($addedCmd);
		 return if ($addedCmd and defined $rc and $rc == 2);
	    #### SPLIT REST/JSON
	    my %statusTable2nd = ();
	    my %nameTable2nd = ();
	    if ($addedCmd) {
		my $refCmd = agentJson_ExtractCmd($providerout);
		for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		    my $number = $numberTable{$i};
		    next if (!defined $number);
		    for (my $i2nd=0; $i2nd < $number; $i2nd++) {
			my $status = agentJson_GetCmdSimpleData($refCmd,
			    "StatusTreeSubsysComponentStatus", $i, $i2nd);
			next if (!defined $status);
			my $name = agentJson_GetCmdSimpleData($refCmd,
			    "StatusTreeSubsysComponentName", $i, $i2nd);
			$status = 0 if (!defined $name and !defined $name);
			$name = '..undefined..' if (!defined $name);
			$statusTable2nd{"$i-$i2nd"}	= $status;
			$nameTable2nd{"$i-$i2nd"}	= $name;
		    } # for 2nd Level
		} # for
	    } # get 2nd level data
	    #### EVAL 2nd Level
	    if ($addedCmd) {
		for (my $i=0; $i < 7; $i++) { # no more than seven Subsystems
		    my $status = $statusTable{$i};
		    my $number = $numberTable{$i};
		    my $name = $nameTable{$i};
		    my $printPartCmds = 0;
		    my $getOtherAdapter = 0;
		    my $searchNotOK = 0;
		    my $getSingleComponent = 0;
		    next if (!defined $number or !defined $status or !$status);
		    if (defined $iEnvironment and $iEnvironment  == $i) {
			next if (!$optChkEnvironment and !$optChkEnv_Fan and !$optChkEnv_Temp);
			$searchNotOK  = 1 if ($status == 2 or $status == 3);
			$getSingleComponent = 1 if ($optChkEnv_Fan or $optChkEnv_Temp);
		    } elsif (defined $iPower and $iPower  == $i) {
			next if (!$optChkPower);
			$searchNotOK  = 1 if ($status == 2 or $status == 3);
			$getOtherAdapter  = 1;
		    } elsif (defined $iStorage and $iStorage == $i) {
			next if (!$optChkStorage);
			$searchNotOK  = 1 if ($status == 2 or $status == 3);
			$getOtherAdapter  = 1;
		    } elsif (defined $iSystemBoard and $iSystemBoard == $i) {
			next if (!$optChkSystem and !$optChkHardware 
			    and !$optChkCPU and !$optChkVoltage and !$optChkMemMod);
			$searchNotOK  = 1 if ($status == 2 or $status == 2);
			$getSingleComponent = 1 if ($optChkCPU or $optChkVoltage or $optChkMemMod);
			$getOtherAdapter  = 1;
		    } elsif (defined $iNetwork and $iNetwork == $i) {
			next if (!$optChkSystem);
			$searchNotOK  = 1 if ($status == 2 or $status == 3);
		    } elsif (defined $iDrvMonitor and $iDrvMonitor == $i) {
			next if (!$optChkDrvMonitor);
			$searchNotOK  = 1 if ($status == 2 or $status == 3);
		    }
		    if ($searchNotOK or $getOtherAdapter or $getSingleComponent) {
			addTableHeader("v", $name . " Adapters") if ($main::verbose >= 2
			    and $printPartCmds);
			for (my $i2nd=0; $i2nd < $number; $i2nd++) {
			    my $status2nd = $statusTable2nd{"$i-$i2nd"};
			    my $name2nd = $nameTable2nd{"$i-$i2nd"};
			    next if (!defined $status2nd or !defined $name2nd);
			    # set global 2nd Level Status
			    my $tmpExitCode = 3;
			    $tmpExitCode = 2 if ($status2nd == 3);
			    $tmpExitCode = 1 if ($status2nd == 2);
			    $tmpExitCode = 0 if ($status2nd == 1);

			    if ($getOtherAdapter) {
				if (defined $iPower and $i == $iPower
				and $name2nd !~ m/SvPowerSupplies/) 
				{				    
				    my $adaptername = $name2nd;
				    $adaptername =~ s/^Sv//;
				    $adaptername =~ s/^Oem//;
				    $otherPowerAdapters->{$adaptername} = 
					$statusText[$status2nd];
				    $otherPowerAdaptersExitCode->{$adaptername} = 
					$tmpExitCode;
				} elsif (defined $iSystemBoard and $iSystemBoard == $i
				and $name2nd !~ m/SvVoltages/
				and $name2nd !~ m/SvMemModules/
				and $name2nd !~ m/SvCPUs/)
				{
				    my $adaptername = $name2nd;
				    $adaptername =~ s/^Sv//;
				    $adaptername =~ s/^Oem//;
				    $otherSystemBoardAdapters->{$adaptername} = 
					$statusText[$status2nd];
				    $otherSystemBoardAdaptersExitCode->{$adaptername} = 
					$tmpExitCode;
				} elsif (defined $iStorage and $iStorage == $i
				and $name2nd !~ m/SvRaid/)
				{
				    my $adaptername = $name2nd;
				    $adaptername =~ s/^Sv//;
				    $adaptername =~ s/^Oem//;
				    $otherStorageAdapters->{$adaptername} = 
					$statusText[$status2nd];
				    $otherStorageAdaptersExitCode->{$adaptername} = 
					$tmpExitCode;
				}
			    } # other Adapter
			    if (defined $iEnvironment and $i == $iEnvironment) {
				if ($name2nd =~ m/SvFans/) {
				    $allFanStatus = $tmpExitCode;
				    $tmpAllFanStatus = $status2nd;
				}
				elsif ($name2nd =~ m/SvTemp/) {
				    $allTempStatus = $tmpExitCode;
				    $tmpAllTempStatus = $status2nd;
				}
			    }
			    if (defined $iSystemBoard and $i == $iSystemBoard) {
				if ($name2nd =~ m/SvVoltages/) {
				    $allVoltageStatus = $tmpExitCode;
				    $tmpAllVoltageStatus = $status2nd;
				}
				elsif ($name2nd =~ m/SvCPUs/) {
				    $allCPUStatus = $tmpExitCode;
				    $tmpAllCPUStatus = $status2nd;
				}
				elsif ($name2nd =~ m/SvMemModules/) {
				    $allMemoryStatus = $tmpExitCode;
				    $tmpAllMemoryStatus = $status2nd;
				}
			    }
			    #
			    if ($main::verbose >= 2 and $printPartCmds) {
				if (defined $status2nd or $main::verbose >= 5) {
				    addStatusTopic("v",$statusText[$status2nd],"Adapter",'');
				    addName("v",$name2nd);
				    addMessage("v","\n");
				}
			    }
			    elsif ($searchNotOK and ($status2nd == 2 or $status2nd == 3)) {
				addStatusTopic("l",$statusText[$status2nd],"Adapter",'');
				addName("l",$name2nd);
				addMessage("l","\n");
			    } # warn, error
			} # for 2nd Level
		    }
		} # for 1st Level
	    } # print 2nd Level
	} # 2ndLevel
	addComponentStatus("m", "Cooling", $statusText[$tmpAllFanStatus])
		if (defined $allFanStatus and $optChkEnv_Fan);
	addComponentStatus("m", "TemperatureSensors", $statusText[$tmpAllTempStatus])
		if (defined $allTempStatus and $optChkEnv_Temp);
	addComponentStatus("m", "Voltages", $statusText[$tmpAllVoltageStatus])
		if (defined $allVoltageStatus and ($optChkHardware or $optChkVoltage));
	addComponentStatus("m", "CPUs", $statusText[$tmpAllCPUStatus])
		if (defined $allCPUStatus and ($optChkHardware or $optChkCPU));
	addComponentStatus("m", "MemoryModules", $statusText[$tmpAllMemoryStatus])
		if (defined $allMemoryStatus and ($optChkHardware or $optChkMemMod));
  } # agentOverallStatusValues
  sub agentSystemInventoryInfo {
	#### AGENT INFO
	if ($gAgentSCCIversion) {
	    my $scsversion = undef;
	    if ($gAgentSCSversion) {
		my $first = $1 if ($gAgentSCSversion =~ m/(\d+)\d\d\d\d$/);
		my $second = $1 if ($gAgentSCSversion =~ m/\d+(\d\d)\d\d$/);
		my $third = $1 if ($gAgentSCSversion =~ m/\d+\d\d(\d\d)$/);
		$scsversion = "V$first.$second.$third";
	    }
	    if ($optAgentInfo) {
		addKeyValue("m","Version",$gAgentSCCIversion);

		addStatusTopic("l",undef,"AgentInfo", undef);
		addName("l","SrvView Agent Server Control");
		addKeyValue("l","Version",$gAgentSCCIversion);
		addKeyLongValue("l","Base-REST-Service","ServerView Remote Connector $scsversion")
		    if ($scsversion);
		addMessage("l","\n");
		$exitCode = 0;
	    } elsif ($main::verbose >= 3) {
		addStatusTopic("v",undef,"AgentInfo", undef);
		addName("v","SrvView Agent Server Control");
		addKeyValue("v","Version",$gAgentSCCIversion) if ($gAgentSCCIversion !~ m/\s/);
		addKeyLongValue("v","Version",$gAgentSCCIversion) if ($gAgentSCCIversion =~ m/\s/);
		addKeyLongValue("v","Company",$gAgentSCCIcompany);
		addKeyLongValue("v","Base-REST-Service","ServerView Remote Connector $scsversion")
		    if ($scsversion);
		addMessage("v","\n");
	    }
	}
	#### Other System infos beside IP and MAC
	my $agentNetworkNumber = undef;
	my $agentNetworkAdapterNumber = undef;
	    #### BUILD JSON
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    agentJson_AddCmd($refArrayCmd,"IdentificationUuid");
	    agentJson_AddCmd($refArrayCmd,"IdentificationUuidBigEndian");
	    agentJson_AddCmd($refArrayCmd,"IdentificationParentIpAddress");
	    agentJson_AddCmd($refArrayCmd,"IdentificationParentMacAddress");
	    agentJson_AddCmd($refArrayCmd,"ConfBMCIpAddr");
	    agentJson_AddCmd($refArrayCmd,"ConfBMCMACAddr");		
	    agentJson_AddCmd($refArrayCmd,"ConfBMCNetworkName");
	    agentJson_AddCmd($refArrayCmd,"ConfBmcIpv6Address");
	    agentJson_AddCmd($refArrayCmd,"NetworkInfoNumberInterfaces");
	    agentJson_AddCmd($refArrayCmd,"NetworkInfoAdapterNumber") 
		if ($main::verbose >= 3);

	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    {
		$agentNetworkNumber	= 
		    agentJson_GetCmdSimpleData($refCmd,"NetworkInfoNumberInterfaces");
		$agentNetworkAdapterNumber	= 
		    agentJson_GetCmdSimpleData($refCmd,"NetworkInfoAdapterNumber")
		    if ($main::verbose >= 3);
		#### 
		my $uuid = agentJson_GetCmdSimpleData($refCmd,"IdentificationUuid");
		my $biguuid = agentJson_GetCmdSimpleData($refCmd,"IdentificationUuidBigEndian");
		addStatusTopic("v",undef,"ServerInfo", undef);
		addKeyValue("v","Uuid",$uuid);
		addKeyValue("v","Uuid-BigEndian",$biguuid);
		addMessage("v","\n");
		####
		my $mmbIP = agentJson_GetCmdSimpleData($refCmd,"IdentificationParentIpAddress");
		my $mmbMAC = agentJson_GetCmdSimpleData($refCmd,"IdentificationParentMacAddress");
		$mmbIP = agentJson_RawIPv4Address($mmbIP);
		my @macs = agentJson_RawMacAdresses($mmbMAC);
		if ($mmbIP or $#macs >= 0) {
		    addStatusTopic("v",undef,"ParentInfo",undef);
		    addKeyValue("v","IP",$mmbIP);
		    addKeyValue("v","MAC",$macs[0]);
		    addKeyValue("v","EUI",$macs[1]) if ($#macs >= 1);
		    addMessage("v","\n");
		}
		####
		my $bmcIP = agentJson_GetCmdSimpleData($refCmd,"ConfBMCIpAddr");
		my $bmcIP6raw = agentJson_GetCmdSimpleData($refCmd,"ConfBmcIpv6Address");
		my $bmcMAC = agentJson_GetCmdSimpleData($refCmd,"ConfBMCMACAddr");		
		my $bmcName = agentJson_GetCmdSimpleData($refCmd,"ConfBMCNetworkName");
		$bmcIP = agentJson_RawIPv4Address($bmcIP);
		@macs = agentJson_RawMacAdresses($bmcMAC);
		my @ips = agentJson_RawIPAddresses($bmcIP6raw);
		my $ip6 = undef;
		$ip6 = $ips[1] if ($#ips >= 1);
		if ($bmcIP or $bmcIP6raw or $#macs >= 0) {
		    addStatusTopic("v",undef,"BMCInfo",undef);
		    addName("v",$bmcName);
		    addIP("v",$bmcIP, $ip6);
		    addKeyValue("v","MAC",$macs[0]);
		    addKeyValue("v","EUI",$macs[1]) if ($#macs >= 1);
		    addMessage("v","\n");
		}
	    }
	#### Network parts
	return if (!$agentNetworkNumber);
	    #### BUILD
		($refMain, $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$agentNetworkNumber;$i++) {
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfDescription", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfIpAddress", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfMacAddress", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfConnectionName", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfAdapterIndex", undef, $i)
			if ($main::verbose >= 3);
		} # for
	    #### CALL REST/JSON
		($rc, $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    $refCmd = agentJson_ExtractCmd($providerout);
	    addTableHeader("v","Network Nodes");
	    for (my $i=0;$i<$agentNetworkNumber;$i++) {
		my $name = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfDescription", undef, $i);
		my $rawips = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfIpAddress", undef, $i);
		my $rawmac = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfMacAddress", undef, $i);
		my $conn = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfConnectionName", undef, $i);
		my $adapter = undef;
		   $adapter = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfAdapterIndex", undef, $i)
		    if ($main::verbose >= 3);
		my @macs = agentJson_RawMacAdresses($rawmac);
		my @ips = agentJson_RawIPAddresses($rawips);
		my $ip4 = undef;
		my $ip6 = undef;
		$ip4 = $ips[0] if ($#ips >=0);
		$ip6 = $ips[1] if ($#ips >=1);
		addStatusTopic("v",undef, "Node", $i);
		addName("v",$conn,1);
		addKeyLongValue("v","Description",$name) if ($name and (!$conn or $conn ne $name));
		    # ... in Linux is $conn == $name
		addIP("v",$ip4,$ip6);
		if ($ip4 or $ip6) {
		    my @nextIP = ();
		    my $n = 1;
		    while ($n==1 or $#nextIP >= 0) {
			$ip4 = undef; $ip6 = undef;
			@nextIP = agent_nextIFIPAddress($i,$n);
			$ip4 = $nextIP[0] if ($#nextIP >=0);
			$ip6 = $nextIP[1] if ($#nextIP >=1);
			addIP("v",$ip4,$ip6);
			$n++;
		    } #while
		}
		addKeyValue("v","MAC",$macs[0]) if ($#macs >=0);
		addKeyValue("v","EUI",$macs[1]) if ($#macs >=1);
		addKeyIntValue("v","NICID", $adapter) if ($main::verbose >= 3);
		addMessage("v","\n");
	    } # for
	#
	#### Network Adapter (NIC)
	return if (!$agentNetworkAdapterNumber or $main::verbose < 3);
	    #### BUILD
		($refMain, $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$agentNetworkAdapterNumber;$i++) {
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoAdapterName", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoAdapterDescription", undef, $i);
		} # for
	    #### CALL REST/JSON
		($rc, $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    $refCmd = agentJson_ExtractCmd($providerout);
	    addTableHeader("v","Network Adapter NIC");
	    for (my $i=0;$i<$agentNetworkAdapterNumber;$i++) {
		my $name = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoAdapterName", undef, $i);
		my $descr = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoAdapterDescription", undef, $i);
		addStatusTopic("v",undef, "NetAdapter", $i);
		addName("v",$name,1);
		addKeyLongValue("v","Description",$descr);
		addMessage("v","\n");
	    } # for
  } # agentSystemInventoryInfo
  sub agentSystemNotifyInformation {
	my $multiChassisNr = undef;
	#### BUILD JSON
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	agentJson_AddCmd($refArrayCmd,"CabinetModel");
	agentJson_AddCmd($refArrayCmd,"SystemHostName");
	agentJson_AddCmd($refArrayCmd,"SystemHostNameFQDN");
	agentJson_AddCmd($refArrayCmd,"ConfCabinetLocation");
	agentJson_AddCmd($refArrayCmd,"ConfSystemDescription");
	agentJson_AddCmd($refArrayCmd,"ConfSystemContact");
	agentJson_AddCmd($refArrayCmd,"ConfServerChassisModel");
	agentJson_AddCmd($refArrayCmd,"IdentificationAdminURLasIP");
	agentJson_AddCmd($refArrayCmd,"ConfServerMgmtIpAddress");	
	agentJson_AddCmd($refArrayCmd,"OsDesignation");	
	agentJson_AddCmd($refArrayCmd,"OsVersion");
	agentJson_AddCmd($refArrayCmd,"IdentificationParentIpAddress");
	agentJson_AddCmd($refArrayCmd,"IdentificationChassisCabinetNumber");
	agentJson_AddCmd($refArrayCmd,"IdentificationPartitionId");
	agentJson_AddCmd($refArrayCmd,"IdentificationPartitionName");
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT REST/JSON
	my $gotSomeInfos = 0;
	my $refCmd = agentJson_ExtractCmd($providerout);
	{
	    my $sysname =	agentJson_GetCmdSimpleData($refCmd,"SystemHostName");
	    my $fqdn =		agentJson_GetCmdSimpleData($refCmd,"SystemHostNameFQDN");
	    my $model =		agentJson_GetCmdSimpleData($refCmd,"CabinetModel");
	    my $location =	agentJson_GetCmdSimpleData($refCmd,"ConfCabinetLocation");
	    my $descr =		agentJson_GetCmdSimpleData($refCmd,"ConfSystemDescription");
	    my $contact =	agentJson_GetCmdSimpleData($refCmd,"ConfSystemContact");
	    my $housing =	agentJson_GetCmdSimpleData($refCmd,"ConfServerChassisModel");
	    my $admURL =	agentJson_GetCmdSimpleData($refCmd,"IdentificationAdminURLasIP");
	    my $manIp =		agentJson_GetCmdSimpleData($refCmd,"ConfServerMgmtIpAddress");
	    my $osdescr =	agentJson_GetCmdSimpleData($refCmd,"OsDesignation");	
	    my $osversion =	agentJson_GetCmdSimpleData($refCmd,"OsVersion");
	    my $parent =	agentJson_GetCmdSimpleData($refCmd,"IdentificationParentIpAddress");
	    $multiChassisNr =	agentJson_GetCmdSimpleData($refCmd,"IdentificationChassisCabinetNumber");
	    my $partID = agentJson_GetCmdSimpleData($refCmd,"IdentificationPartitionId");
	    my $partName =  agentJson_GetCmdSimpleData($refCmd,"IdentificationPartitionName");
	    #
	    $osversion =~ s/\s+$// if ($osversion);
	    $parent = agentJson_RawIPv4Address($parent);
	    $gotSomeInfos = 1 if ($sysname or $model);
	    #
	    my $ssmURL = socket_checkSSM($optHost, $gAgentSCCIversion);

	    addName("n", $sysname);
	    addKeyLongValue("n", "Description", $descr);
	    addProductModel("n", undef, $model);
	    addKeyLongValue("n", "Housing", $housing);
	    addLocationContact("n", $location, $contact);
	    addKeyValue("n","MonitorURL", $ssmURL);
	    addAdminURL("n",$admURL);
	    addKeyValue("v","ManagementIP", $manIp);
	    addKeyValue("n","ParentMMB", $parent);
	    addKeyLongValue("n","OS",$osdescr);
	    addKeyLongValue("n","OS-Revision",$osversion);
	    if ($fqdn) {
		    $fqdn = undef if ($sysname and ($sysname eq $fqdn));
		    $fqdn = undef if ($fqdn and $sysname and ($sysname =~ m/$fqdn/i));
		    addKeyLongValue("n","FQDN",$fqdn);
	    }
	    if (defined $partID or $partName) {
		addKeyIntValue("n","PartitionID",$partID);
		addKeyLongValue("n","PartitionName",$partName);
	    }
	} # get parts
	if (defined $multiChassisNr) { # MultiNode CX series
	    #### BUILD JSON
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		agentJson_AddCmd($refArrayCmd,"CabinetModel",undef,undef,$multiChassisNr);
		agentJson_AddCmd($refArrayCmd,"CabinetSerialNumber",undef,undef,$multiChassisNr);
		agentJson_AddCmd($refArrayCmd,"ChassisModel",undef,undef,$multiChassisNr);
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT REST/JSON
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    {
		my $model =	agentJson_GetCmdSimpleData($refCmd,"CabinetModel",
		    undef,undef,$multiChassisNr);
		my $serial =	agentJson_GetCmdSimpleData($refCmd,"CabinetSerialNumber",
		    undef,undef,$multiChassisNr);
		my $name =	agentJson_GetCmdSimpleData($refCmd,"ChassisModel",
		    undef,undef,$multiChassisNr);
		addMessage("n","\n");
		addStatusTopic("n", undef,"Multi Node System", undef);
		addSerialIDs("n", $serial, undef);
		addName("n", $name);
		addProductModel("n",undef, $model);
	    }
	} # MultiNode
	if ($gAgentHasMultiCabinets) { # Additional Storage Cabinets
	    #our @gAgentCabinetNumbers = ();
	    #### BUILD JSON
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0; $i<=$#gAgentCabinetNumbers ; $i++) {
		my $ca = $gAgentCabinetNumbers[$i];
		next if (!defined $ca);
		agentJson_AddCmd($refArrayCmd,"CabinetModel",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"CabinetSerialNumber",undef,undef,$ca);
		agentJson_AddCmd($refArrayCmd,"ChassisModel",undef,undef,$ca);
	    } # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT REST/JSON
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0; $i<=$#gAgentCabinetNumbers ; $i++) {
		my $ca = $gAgentCabinetNumbers[$i];
		next if (!defined $ca);
		my $model =	agentJson_GetCmdSimpleData($refCmd,"CabinetModel",
		    undef,undef,$ca);
		my $serial =	agentJson_GetCmdSimpleData($refCmd,"CabinetSerialNumber",
		    undef,undef,$ca);
		my $name =	agentJson_GetCmdSimpleData($refCmd,"ChassisModel",
		    undef,undef,$ca);
		addMessage("n","\n");
		addStatusTopic("n", undef,"Storage Cabinet", $ca);
		addSerialIDs("n", $serial, undef);
		addName("n", $name);
		addProductModel("n",undef, $model);
	    }
	} # # Additional Storage Cabinets
	addExitCode(0) if ($optSystemInfo and ($serverID or $gotSomeInfos));
	if ($optSystemInfo and !$serverID and !$gotSomeInfos) {
	    addMessage("m"," - ATTENTION: Missing system information");
	}
  } #agentSystemNotifyInformation
 ####
  sub agentPrintOneFan {
	my $notify = shift;
	my $verbose = shift;
	my $i = shift;
	my $status = shift;
	my $speed = shift;
	my $name = shift;
	my $type = shift;
	my $maxarr = shift;

	my @statusFanText = ( "disabled",
	    "ok", "failed", "predicted-failure", "redundant-failed", "not-managable",
	    "not-installed", "..unexpected..",
	);
	$status = 7 if (!defined $status or $status !~ m/^\d+$/ 
	    or $status < 0 or $status > 6);
	#
	my @maxvalues = agentJson_RawWordSplit($maxarr);
	my $percent = undef;
	if ($#maxvalues >= 1) {
	    $percent = calcPercent($maxvalues[1], $speed);
	}
	my $medium = undef;
	$medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	$medium = "l" if ($notify and $status > 1 and $status < 4);
	if ($medium) {
	    addStatusTopic($medium,$statusFanText[$status], "Fan", $i)
		if (!$type);
	    addStatusTopic($medium,$statusFanText[$status], "Liquid",$i)
		if ($type);
	    addName($medium,$name);
	    addKeyRpm($medium,"Speed", $speed);
	    addKeyPercent($medium,"NominalPercent", $percent);
	    addMessage($medium,"\n");
	} 
	if ($optChkFanPerformance) {
	    $name =~ s/[\s\,\.\$\(\)]+/_/g;
	    $name =~ s/_+/_/g;
	    if ($i =~ m/([\d]+)\./) {
		$name .= $1;
	    }
	    addRpmToPerfdata($name, $speed, undef, undef);
	}
  } # agentPrintOneFan
  sub agentPrintOneTemperature {
	my $notify = shift;
	my $verbose = shift;
	my $i = shift;
	my $status = shift;
	my $current = shift;
	my $name = shift;
	my $warn = shift;
	my $crit = shift;
	my @statusTempText = ( "not-available",
	    "OK", "..unexpected..", "failed", "warning-hot", "critical-hot",
	    "normal", "warning", "..unexpected..",
	);
	$status = 8 if (!defined $status or $status !~ m/^\d+$/ 
	    or $status < 0 or $status > 7);
	#
	my $medium = undef;
	$medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	$medium = "l" if ($notify and $status >=3 and $status <= 7 and $status != 6 );
	if ($medium) {
		addStatusTopic($medium,$statusTempText[$status], "Sensor", $i);
		addName($medium,$name);
		addCelsius($medium,$current, $warn, $crit);
		addMessage($medium,"\n");
	}
	#... Performance
	$name =~ s/[\s\,\.\$\(\)]+/_/g;
	$name =~ s/_+/_/g;
	if ($i =~ m/([\d]+)\./) {
	    $name .= $1;
	}
	addTemperatureToPerfdata($name, $current, $warn, $crit)
		if (!$main::verboseTable);
  } # agentPrintOneTemperature
  sub agentPrintOnePSU {
	my $notify = shift;
	my $verbose = shift;
	my $i = shift;
	my $status = shift;
	my $current = shift;
	my $name = shift;
	my $nominal = shift;
	my @statusPSUText = ( "not-present",
	    "ok", "failed", "AC-fail", "DC-fail","temperature-critical",
	    "not-manageable","fan-failure-prediction","fan-failure","power-save-mode",
	    "non-redundant-DC-fail","non-redundant-AC-fail","..unexpected..",
	);
	$status = 12 if (!defined $status or $status !~ m/^\d+$/ 
	    or $status < 0 or $status > 11);
	#
	my $medium = undef;
	$medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	$medium = "l" if ($notify and $status > 1 and $status <= 11  
	    and $status != 5 and $status != 9);
	if ($medium) {
		addStatusTopic($medium,$statusPSUText[$status], "PSU", $i);
		addName($medium,$name);
		addKeyWatt($medium,"CurrentLoad", $current, undef, undef, undef, $nominal);
		addMessage($medium,"\n");
	}
  } # agentPrintOnePSU
 ####
  sub agentAllCabinetNumbers {
	#   our @gAgentCabinetNumbers = ();
	#### BUILD
 	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();    
	    agentJson_AddCmd($refArrayCmd,"DetectedSECabinets");
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my $allCabinetsStream = agentJson_GetCmdSimpleData($refCmd,"DetectedSECabinets");
	    $gAgentHasMultiCabinets = 0 if (!defined $allCabinetsStream);
	    return if (!defined $allCabinetsStream);
	    @gAgentCabinetNumbers = agentJson_RawWordSplit($allCabinetsStream);
	    if ($#gAgentCabinetNumbers >= 0) {
		$gAgentHasMultiCabinets = 1;
		print "**** detect system with multiple cabinets\n" if ($main::verbose >=20);
	    }
  } # agentAllCabinetNumbers
  sub agentAllFanSensors {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentCoolingNumber{0});
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<$gAgentCoolingNumber{0};$i++) {
		agentJson_AddCmd($refArrayCmd,"FanStatus", undef, $i);
		agentJson_AddCmd($refArrayCmd,"CurrentFanSpeed", undef, $i);
		agentJson_AddCmd($refArrayCmd,"FanDesignation", undef, $i);
		agentJson_AddCmd($refArrayCmd,"CoolingDeviceType", undef, $i);
		agentJson_AddCmd($refArrayCmd,"FanMaximumSpeed", undef, $i);
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentCoolingNumber{$ca};$i++) {
			agentJson_AddCmd($refArrayCmd,"FanStatus", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"CurrentFanSpeed", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"FanDesignation", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"CoolingDeviceType", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"FanMaximumSpeed", undef, $i,$ca);
		    } # for
		} # foreach
	    } # cabinets
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	addTableHeader("v","Cooling Devices") if ($verbose);
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    # TODO - Multi Cabinet
	    for (my $i=0;$i<$gAgentCoolingNumber{0};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"FanStatus", undef, $i);
		my $speed = agentJson_GetCmdSimpleData($refCmd,"CurrentFanSpeed", undef, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"FanDesignation", undef, $i);
		my $type = agentJson_GetCmdSimpleData($refCmd,"CoolingDeviceType", undef, $i);
		my $maxarr = agentJson_GetCmdSimpleData($refCmd,"FanMaximumSpeed", undef, $i);
		agentPrintOneFan($notify,$verbose,"$i",$status,$speed,$name,$type,$maxarr);
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentCoolingNumber{$ca};$i++) {
			my $status = agentJson_GetCmdSimpleData($refCmd,"FanStatus", undef, $i,$ca);
			my $speed = agentJson_GetCmdSimpleData($refCmd,"CurrentFanSpeed", undef, $i,$ca);
			my $name = agentJson_GetCmdSimpleData($refCmd,"FanDesignation", undef, $i,$ca);
			my $type = agentJson_GetCmdSimpleData($refCmd,"CoolingDeviceType", undef, $i,$ca);
			my $maxarr = agentJson_GetCmdSimpleData($refCmd,"FanMaximumSpeed", undef, $i,$ca);
			agentPrintOneFan($notify,$verbose,"$ca.$i",$status,$speed,$name,$type,$maxarr);
		    } # for
		} # foreach
	    } # cabinets
	}
  } # agentAllFanSensors
  sub agentAllTemperatureSensors {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentTemperatureNumber{0});
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<$gAgentTemperatureNumber{0};$i++) {
		agentJson_AddCmd($refArrayCmd,"TempSensorStatus", undef, $i);
		agentJson_AddCmd($refArrayCmd,"CurrentTemperature", undef, $i);
		agentJson_AddCmd($refArrayCmd,"TempSensorDesignation", undef, $i);
		agentJson_AddCmd($refArrayCmd,"ConfWarningTempThresh", undef, $i);
		agentJson_AddCmd($refArrayCmd,"ConfCriticalTempThresh", undef, $i);
		# TODO - Multi Cabinet
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentTemperatureNumber{$ca};$i++) {
			agentJson_AddCmd($refArrayCmd,"TempSensorStatus", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"CurrentTemperature", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"TempSensorDesignation", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"ConfWarningTempThresh", undef, $i,$ca);
			agentJson_AddCmd($refArrayCmd,"ConfCriticalTempThresh", undef, $i,$ca);
		    } # for
		} # foreach
	    } # cabinets
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	addTableHeader("v","Temperature Sensors") if ($verbose);
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    # TODO - Multi Cabinet
	    for (my $i=0;$i<$gAgentTemperatureNumber{0};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"TempSensorStatus", undef, $i);
		my $current = agentJson_GetCmdSimpleData($refCmd,"CurrentTemperature", undef, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"TempSensorDesignation", undef, $i);
		my $warn = agentJson_GetCmdSimpleData($refCmd,"ConfWarningTempThresh", undef, $i);
		my $crit = agentJson_GetCmdSimpleData($refCmd,"ConfCriticalTempThresh", undef, $i);
		agentPrintOneTemperature($notify,$verbose,$i,$status,$current,$name,$warn,$crit);
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentTemperatureNumber{$ca};$i++) {
			my $status = agentJson_GetCmdSimpleData($refCmd,"TempSensorStatus", undef, $i,$ca);
			my $current = agentJson_GetCmdSimpleData($refCmd,"CurrentTemperature", undef, $i,$ca);
			my $name = agentJson_GetCmdSimpleData($refCmd,"TempSensorDesignation", undef, $i,$ca);
			my $warn = agentJson_GetCmdSimpleData($refCmd,"ConfWarningTempThresh", undef, $i,$ca);
			my $crit = agentJson_GetCmdSimpleData($refCmd,"ConfCriticalTempThresh", undef, $i,$ca);
			agentPrintOneTemperature($notify,$verbose,"$ca.$i",$status,$current,$name,$warn,$crit);
		    } # for
		} # foreach
	    } # cabinets
	}
  } # agentAllTemperatureSensors
  sub agentAllPowerSupplies {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentPSUNumber{0});
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<$gAgentPSUNumber{0};$i++) {
		agentJson_AddCmd($refArrayCmd,"PowerSupplyStatus", undef, $i);
		agentJson_AddCmd($refArrayCmd,"PowerSupplyDesignation", undef, $i);
		agentJson_AddCmd($refArrayCmd,"PowerSupplyLoad", undef, $i);
		agentJson_AddCmd($refArrayCmd,"PowerSupplyNominal", undef, $i);
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentPSUNumber{$ca};$i++) {
		    agentJson_AddCmd($refArrayCmd,"PowerSupplyStatus", undef, $i,$ca);
		    agentJson_AddCmd($refArrayCmd,"PowerSupplyDesignation", undef, $i,$ca);
		    agentJson_AddCmd($refArrayCmd,"PowerSupplyLoad", undef, $i,$ca);
		    agentJson_AddCmd($refArrayCmd,"PowerSupplyNominal", undef, $i,$ca);
		    } # for
		} # foreach
	    } # cabinets
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	addTableHeader("v","Power Supplies") if ($verbose);
	{
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    # TODO - Multi Cabinet
	    for (my $i=0;$i<$gAgentPSUNumber{0};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyStatus", undef, $i);
		my $current = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyLoad", undef, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyDesignation", undef, $i);
		my $nominal = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyNominal", undef, $i);
		agentPrintOnePSU($notify,$verbose,$i,$status,$current,$name,$nominal);
	    } # for
	    if ($gAgentHasMultiCabinets and $#gAgentCabinetNumbers >= 0) {
		foreach my $ca (@gAgentCabinetNumbers) {
		    for (my $i=0;$i<$gAgentPSUNumber{$ca};$i++) {
			my $status = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyStatus", undef, $i,$ca);
			my $current = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyLoad", undef, $i,$ca);
			my $name = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyDesignation", undef, $i,$ca);
			my $nominal = agentJson_GetCmdSimpleData($refCmd,"PowerSupplyNominal", undef, $i,$ca);
			agentPrintOnePSU($notify,$verbose,"$ca.$i",$status,$current,$name,$nominal);
		    } # for
		} # foreach
	    } # cabinets
	}
  } # agentAllPowerSupplies
  sub agentAllPowerConsumption {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	#### BUILD
 	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    # explizit 0xE0 for "Total Power"
	    agentJson_AddCmd($refArrayCmd,"PowerConsumptionCurrentValue",0xE0);
	    agentJson_AddCmd($refArrayCmd,"PowerConsumptionLimitStatus",0xE0);
	    agentJson_AddCmd($refArrayCmd,"UtilizationNominalSystemPowerConsumption");
	    agentJson_AddCmd($refArrayCmd,"UtilizationCurrentSystemPowerConsumption"); # double
	    agentJson_AddCmd($refArrayCmd,"UtilizationCurrentPerformanceControlStatus");
	    agentJson_AddCmd($refArrayCmd,"UtilizationNominalMinSystemPowerConsumption");
	    agentJson_AddCmd($refArrayCmd,"UtilizationPowerConsumptionRedundancyLimit");
	    agentJson_AddCmd($refArrayCmd,"ConfPowerLimitModeMaxUsage");
	    agentJson_AddCmd($refArrayCmd,"ConfPowerLimitModeThreshold");
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	    my @statusConsText = ( "ok",
		"warning","critical","no-limit","undefined","..unexpected.."
	    );
	    my @controlStatusText = ( "Power management disabled",
		"Best performance", "Minimum power consumption", "Automatic mode",
		    "Scheduled",
		"Power limit", "Low noise", "..unexpected..",
	    );
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my $status = agentJson_GetCmdSimpleData($refCmd,"PowerConsumptionLimitStatus", 0xE0);
	    my $current = agentJson_GetCmdSimpleData($refCmd,"PowerConsumptionCurrentValue", 0xE0);
	    my $nominal = agentJson_GetCmdSimpleData($refCmd,"UtilizationNominalSystemPowerConsumption");
	    my $nominalmin = agentJson_GetCmdSimpleData($refCmd,"UtilizationNominalMinSystemPowerConsumption");
	    my $ctrl = agentJson_GetCmdSimpleData($refCmd,"UtilizationCurrentPerformanceControlStatus");
	    my $crit = agentJson_GetCmdSimpleData($refCmd,"UtilizationPowerConsumptionRedundancyLimit");
	    my $warnlimit = agentJson_GetCmdSimpleData($refCmd,"ConfPowerLimitModeMaxUsage");
	    my $warnpercent = agentJson_GetCmdSimpleData($refCmd,"ConfPowerLimitModeThreshold");
	    #
	    $status = 4 if (!defined $status);
	    $status = 5 if ($status < 0 or $status > 4);
	    $ctrl = 7 if (!defined $ctrl or $ctrl < 0 or $ctrl > 6);
	    my $medium = undef;
	    $medium = "v" if ($verbose);
	    $medium = "l" if ($notify and $status > 0 and $status < 3);
	    if ($medium) {
		    addTableHeader($medium,"Power Consumption");
		    addStatusTopic($medium,$statusConsText[$status],"PowerConsumption","");
		    addKeyWatt($medium,"Current", $current,
			    $warnlimit,$crit);
		    addKeyLongValue($medium,"PowerControl",$controlStatusText[$ctrl]);
		    addKeyPercent($medium,"WarningLimit",$warnpercent);
		    addKeyWatt($medium,"Nominal", $nominal);
		    addKeyWatt($medium,"NominalMin", $nominalmin);
		    addMessage($medium,"\n");
	    } 
	    addPowerConsumptionToPerfdata($current, $warnlimit,$crit)
		    if (!$main::verboseTable);
  } # agentAllPowerConsumption
  sub agentAllCPU {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentCPUNumber{0});
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0;$i<$gAgentCPUNumber{0};$i++) {
	    agentJson_AddCmd($refArrayCmd,"CPUStatus", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CPUSocketDesignation", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CPUManufacturer", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CPUModelName", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CPUFrequency", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CPUInfo", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CpuUsage", 0, $i);
	} # for
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusCPUText = ( "not-inserted",
	    "ok", "disabled", "error", "failed", "..obsolete..",
	    "prefailure-warning", "..unexpected..",
	); 
	my $refCmd = agentJson_ExtractCmd($providerout);
	addTableHeader("v","CPU Table") if ($verbose);
	for (my $i=0;$i<$gAgentCPUNumber{0};$i++) {
	    my $status = agentJson_GetCmdSimpleData($refCmd,"CPUStatus", undef, $i);
	    my $name = agentJson_GetCmdSimpleData($refCmd,"CPUSocketDesignation", undef, $i);
	    my $current = agentJson_GetCmdSimpleData($refCmd,"CPUFrequency", undef, $i);
	    my $manufact = agentJson_GetCmdSimpleData($refCmd,"CPUManufacturer", undef, $i);
	    my $model = agentJson_GetCmdSimpleData($refCmd,"CPUModelName", undef, $i);
	    my $infoobject = agentJson_GetCmdSimpleData($refCmd,"CPUInfo", undef, $i);
	    my $usage = agentJson_GetCmdSimpleData($refCmd,"CpuUsage", 0, $i);
	    $status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 6);
	    #
	    if (!$current) {
		my @nr = agentJson_RawWordSplit($infoobject);
		if ($#nr >= 1) {
		    $current = $nr[1];
		}
	    }
	    my $medium = undef;
	    $medium = "v" if ($verbose 
		and (($status and $status != 2) or $main::verbose >= 3));
	    $medium = "l" if ($notify and $status >= 3 and $status <= 5);
	    if ($medium) {
		    addStatusTopic($medium,$statusCPUText[$status], "CPU", $i);
		    addName($medium,$name);
		    addKeyMHz($medium, "Frequency", $current);
		    addKeyPercent($medium,"Usage",$usage);
		    addProductModel($medium,undef,$model);
		    addKeyLongValue($medium,"Manufacturer", $manufact);
		    addMessage($medium,"\n");
	    }
	} # for
  } # agentAllCPU
  sub agentAllVoltages {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentVoltageNumber{0});
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0;$i<$gAgentVoltageNumber{0};$i++) {
	    agentJson_AddCmd($refArrayCmd,"VoltageStatus", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageDesignation", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageThresholds", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"CurrentVoltage", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageOutputLoad", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageFrequency", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageNominal", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"VoltageWarningThresholds", undef, $i);
	    # TODO - Multi Cabinet
	} # for
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusVoltageText = ( "not-available",
	    "ok", "too-low", "too-high", "out-of-range", "warning-battery",
	     "..unexpected..",
	); 
	my $refCmd = agentJson_ExtractCmd($providerout);
	addTableHeader("v","Voltages") if ($verbose);
	for (my $i=0;$i<$gAgentVoltageNumber{0};$i++) {
	    my $status = agentJson_GetCmdSimpleData($refCmd,"VoltageStatus", undef, $i);
	    my $name = agentJson_GetCmdSimpleData($refCmd,"VoltageDesignation", undef, $i);
	    my $current = agentJson_GetCmdSimpleData($refCmd,"CurrentVoltage", undef, $i);
	    my $critthres = agentJson_GetCmdSimpleData($refCmd,"VoltageThresholds", undef, $i);
	    my $warnthres = agentJson_GetCmdSimpleData($refCmd,"VoltageWarningThresholds", undef, $i);
	    my $nominal = agentJson_GetCmdSimpleData($refCmd,"VoltageNominal", undef, $i);
	    my $outload = agentJson_GetCmdSimpleData($refCmd,"VoltageOutputLoad", undef, $i);
	    my $frequenzy = agentJson_GetCmdSimpleData($refCmd,"VoltageFrequency", undef, $i);
	    #
	    $status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 6);
	    #
	    $current = agent_negativeCheck($current);
	    $nominal = agent_negativeCheck($nominal);
	    #
	    my @thres = ();
	    @thres = agentJson_RawWordSplit($warnthres);
	    my $warn = undef;
	    if ($#thres>=0) {
		my $min = undef;
		my $max = undef;
		$min = $thres[0];
		$max = $thres[1] if ($#thres > 0);
		$min = agent_negativeCheck($min);
		$max = agent_negativeCheck($max);
		$warn = "$min" if (defined $min);
		$warn .= ":" if (defined $min and defined $max);
		$warn .= "$max";
	    }
	    @thres = agentJson_RawWordSplit($critthres);
	    my $crit = undef;
	    if ($#thres>=0) {
		my $min = undef;
		my $max = undef;
		$min = $thres[0];
		$max = $thres[1] if ($#thres > 0);
		$min = agent_negativeCheck($min);
		$max = agent_negativeCheck($max);
		$crit = "$min" if (defined $min);
		$crit .= ":" if (defined $min and defined $max);
		$crit .= "$max";
	    }
	    # 
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and $status > 1);
	    if ($medium) {
		    addStatusTopic($medium,$statusVoltageText[$status], "Voltage", $i);
		    addName($medium,$name);
		    add100dthVolt($medium,$current,$warn,$crit);
		    addKey100dthVolt($medium,"Nominal", $nominal);
		    addKeyIntValueUnit($medium,"Frequency",$frequenzy,"Hz");
		    addKeyPercent($medium,"OutputLoad", $outload);
		    addMessage($medium,"\n");
	    }
	} # for
  } # agentAllVoltages
  sub agentAllMemoryModules {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentMemModNumber{0});
	my @memModIndex = (); # TODO: Multi Cabinet
	#### BUILD
	(my $crefMain, my $crefArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0;$i<$gAgentMemModNumber{0};$i++) {
	    agentJson_AddCmd($crefArrayCmd,"MemoryModuleStatus", undef, $i);
	    # TODO - Multi Cabinet
	} # for
	#### CALL REST/JSON
	(my $crc, my $cproviderout) = agentJson_CallCmd($crefMain);
	return if ($crc == 2);
	#### SPLIT
	my $crefCmd = agentJson_ExtractCmd($cproviderout);
	for (my $i=0;$i<$gAgentMemModNumber{0};$i++) {
	    my $status = agentJson_GetCmdSimpleData($crefCmd,"MemoryModuleStatus", undef, $i);
	    next if (!defined $status);
	    $status = 10 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 9);
	    next if (!$status); # empty slots
	    push (@memModIndex, $i);
	} # for

	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	#for (my $i=0;$i<$gAgentMemModNumber{0};$i++) {
	for (my $j=0;$j<=$#memModIndex;$j++) {
	    my $i = $memModIndex[$j];
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleStatus", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleSocketDesignation", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleConfiguration", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleFrequency", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleSize", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleType", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleFrequencyMax", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleVoltage", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleVoltage", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryModuleVoltage", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"MemoryBoardDesignation", undef, $i);
	    #agentJson_AddCmd($refArrayCmd,"MemoryModuleInfo", undef, $i);
	    # TODO - Multi Cabinet
	} # for
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusMemModText = ( "empty-slot",
	    "ok", "disabled", "error", "failed", "prefailure-warning",
	    "hot-spare", "mirrored", "raid", "hidden",  "..unexpected..",
	); 
	my @configMemModText = ( "normal",
	    "manually disabled", "hotspare", "mirror", "raid", "not usable",
	    "configuration error", "..unexpected..",
	);
	my $refCmd = agentJson_ExtractCmd($providerout);
	addTableHeader("v","Memory Modules Table") if ($verbose);
	#for (my $i=0;$i<$gAgentMemModNumber{0};$i++) {
	for (my $j=0;$j<=$#memModIndex;$j++) {
	    my $i = $memModIndex[$j];
	    my $status = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleStatus", undef, $i);
	    my $name = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleSocketDesignation", undef, $i);
	    my $confnr = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleConfiguration", undef, $i);
	    my $frequency = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleFrequency", undef, $i);
	    my $size = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleSize", undef, $i);
	    my $type = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleType", undef, $i);
	    my $max = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleFrequencyMax", undef, $i);
	    my $volt = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleVoltage", undef, $i);
	    my $board = agentJson_GetCmdSimpleData($refCmd,"MemoryBoardDesignation", undef, $i);
	    #my $info = agentJson_GetCmdSimpleData($refCmd,"MemoryModuleInfo", undef, $i);
	    #
	    next if (!defined $status and !defined $name);
	    $status = 10 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 9);
	    $confnr = 6 if (!defined $confnr or $confnr !~ m/^\d+$/ 
		or $confnr < 0 or $confnr > 6);
	    my $conf = undef;
	    $conf = $configMemModText[$confnr] if ($confnr);
	    # 
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and $status > 2 and $status < 5);
	    if ($medium) {
		    addStatusTopic($medium,$statusMemModText[$status], "Memory", $i);
		    addName($medium,$name);
		    addKeyLongValue($medium,"Board", $board);
		    addKeyLongValue($medium,"Type", $type);
		    addKeyLongValue($medium,"Config", $conf);
		    addKeyMB($medium,"Capacity", $size);
		    addKeyMHz($medium,"Frequency", $frequency);
		    addKeyMHz($medium,"Frequency-Max", $max);
		    addKeyValue($medium,"Voltage", $volt);
		    addMessage($medium,"\n");
	    }
	} # for
  } # agentAllMemoryModules
  sub agentAllDrvMonAdapter {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agent_getNumberOfSensors();
	return if (!$gAgentDrvMonNumber{0});
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0;$i<$gAgentDrvMonNumber{0};$i++) {
	    agentJson_AddCmd($refArrayCmd,"DrvMonComponentStatus", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"DrvMonComponentName", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"DrvMonComponentLocation", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"DrvMonComponentClass", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"DrvMonComponentDriverName", undef, $i);
	    # TODO - Multi Cabinet
	} # for
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusDrvCompText = ( "unknown",
	    "ok", "warning","error", "not-present", "not-manageable",
 	     "..unexpected..",
	); 
	my @classDrvCompText = ( "Unknown",
	    "Software", "Network", "Storage",
	    "..unexpected..",
	); # + 0xFF "Other"
	my $refCmd = agentJson_ExtractCmd($providerout);
	addTableHeader("v","Driver Monitor Component Table") if ($verbose);
	for (my $i=0;$i<$gAgentDrvMonNumber{0};$i++) {
	    my $status = agentJson_GetCmdSimpleData($refCmd,"DrvMonComponentStatus", undef, $i);
	    my $name = agentJson_GetCmdSimpleData($refCmd,"DrvMonComponentName", undef, $i);
	    my $location = agentJson_GetCmdSimpleData($refCmd,"DrvMonComponentLocation", undef, $i);
	    my $classnr = agentJson_GetCmdSimpleData($refCmd,"DrvMonComponentClass", undef, $i);
	    my $driver = agentJson_GetCmdSimpleData($refCmd,"DrvMonComponentDriverName", undef, $i);
	    #
	    $status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 6);
	    $classnr = 4 if (!defined $classnr or $classnr !~ m/^\d+$/ 
		or $classnr < 0 or ($classnr > 4 and $classnr != 255));
	    my $class = undef;
	    $class = "Other" if ($classnr == 255);
	    $class = $classDrvCompText[$classnr] if ($classnr != 255);
	    # 
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and $status > 1 and $status < 4);
	    if ($medium) {
		    addStatusTopic($medium,$statusDrvCompText[$status], "DrvMon", $i);
		    addName($medium,$name);
		    addKeyLongValue($medium,"Location",$location);
		    addKeyLongValue($medium,"Driver", $driver);
		    addKeyValue($medium,"Class", $class);
		    addMessage($medium,"\n");
	    }
	} # for
	# OPEN: There are additional Information about DrvMon-Drivers
  } # agentAllDrvMonAdapter
  sub agentAllStorageAdapter {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	agentRAID($setExitCode,$notify,$verbose);
  } # agentAllStorageAdapter
 ####
  sub agentRAIDStatus {
	my $notify = shift;
	my $verbose = shift;
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	{
	    agentJson_AddCmd($refArrayCmd,"RaidOverallStatus");
	    agentJson_AddCmd($refArrayCmd,"RaidAdapterOverallStatus");
	    agentJson_AddCmd($refArrayCmd,"RaidLogicalDrivesOverallStatus");
	    agentJson_AddCmd($refArrayCmd,"RaidPhysicalDrivesOverallStatus");
	    agentJson_AddCmd($refArrayCmd,"RaidOverallSmartStatus");
	}
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @raidCompStatusText = ( "Unknown", 
	    "OK", "Warning", "Error", "..unexpected..",
	);
	my @raidSMARTText = ( "OK",
	    "Failure", "Unknown", "..unexpected..",
	);
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $overall = agentJson_GetCmdSimpleData($refCmd,"RaidOverallStatus");
	    my $stCtrl = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterOverallStatus");
	    my $stLDrive = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDrivesOverallStatus");
	    my $stPDevice = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDrivesOverallStatus");
	    my $smart = agentJson_GetCmdSimpleData($refCmd,"RaidOverallSmartStatus");
	    #
	    $overall = 4 if (!defined $overall or $overall !~ m/^\d+$/ 
		or $overall < 0 or $overall > 4);
	    $stCtrl = 4 if (!defined $stCtrl or $stCtrl !~ m/^\d+$/ 
		or $stCtrl < 0 or $stCtrl > 4);
	    $stLDrive = 4 if (!defined $stLDrive or $stLDrive !~ m/^\d+$/ 
		or $stLDrive < 0 or $stLDrive > 4);
	    $stPDevice = 4 if (!defined $stPDevice or $stPDevice !~ m/^\d+$/ 
		or $stPDevice < 0 or $stPDevice > 4);
	    $smart = 2 if (defined $smart and $smart =~ m/^\d+$/ and $smart == 255); 
	    $smart = 3 if (!defined $smart or $smart !~ m/^\d+$/ 
		or $smart < 0 or $smart > 3);

	#### PRINT
	addTableHeader("v","RAID Overview") if ($verbose);
	my $medium = undef;
	$medium = "v" if ($verbose);
	$medium = "l" if (!$medium and $notify);
	if ($medium) {
		#$variableVerboseMessage .= "\n";
		addStatusTopic($medium,$raidCompStatusText[$overall],
			"RAID -", undef);
		addComponentStatus($medium,"Controller", $raidCompStatusText[$stCtrl])
			if (defined $stCtrl);
		addComponentStatus($medium,"PhysicalDevice", $raidCompStatusText[$stPDevice])
			if (defined $stPDevice);
		addComponentStatus($medium,"LogicalDrive", $raidCompStatusText[$stLDrive])
			if (defined $stLDrive);
		addComponentStatus($medium,"S.M.A.R.T", $raidSMARTText[$smart])
			if (defined $smart);
		addMessage($medium,"\n");
	}
	$raidCtrl = 3 if (defined $stCtrl);
	$raidCtrl = $stCtrl - 1 if ($stCtrl and $stCtrl <= 3);
	$raidLDrive = 3 if (defined $stLDrive);
	$raidPDevice = $stLDrive - 1 if ($stLDrive and $stLDrive <= 3);
	$raidPDevice = 3 if (defined $stPDevice);
	$raidPDevice = $stPDevice - 1 if ($stPDevice and $stPDevice <= 3);
  } # agentRAIDStatus
  sub agentRAIDCtrlTable {
	my $notify = shift;
	my $verbose = shift;
	return if (!$gAgentRAIDCtrlNumber);
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $i=0;$i<$gAgentRAIDCtrlNumber;$i++) {
	    agentJson_AddCmd($refArrayCmd,"RaidAdapterStatus", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"RaidAdapterName", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"RaidAdapterType", undef, $i);
	    agentJson_AddCmd($refArrayCmd,"RaidAdapterProperty", undef, $i);
	} # for
 	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusText = ( "ok",
	    "warning","error","unknown","..unexpected..",
	); # + 255:  StatusUnknown
	my @typeText = ( "SCSI",
	    "ATAPI","PATA","Firewire IEEE 1394","SSA","Fibre",
	    "USB","SATA","SAS","RAID","MMC",
	    "SD card bus","..unexpected..",
	); # + 0xFF "Uknown"
	addTableHeader("v","RAID Controller") if ($verbose);
	my $refCmd = agentJson_ExtractCmd($providerout);
	for (my $i=0;$i<$gAgentRAIDCtrlNumber;$i++) {
	    my $status = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterStatus", undef, $i);
	    my $name = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterName", undef, $i);
	    my $typenr = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterType", undef, $i);
	    my $prop = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterProperty", undef, $i);
	    
	    #
	    $status = 3 if ($status and $status =~ m/^\d+$/ and $status == 255);
	    $status = 4 if (!defined $status or $status !~ m/^\d+$/ 
		or $status < 0 or $status > 4);
	    $typenr = 12 if (!defined $typenr or $typenr !~ m/^\d+$/ 
		or $typenr < 0 or ($typenr > 12 and $typenr != 255));
	    my $type = undef;
	    $type = "Other" if ($typenr == 255);
	    $type = $typeText[$typenr] if ($typenr != 255);
	    # 
	    my $medium = undef;
	    $medium = "v" if ($verbose);
	    $medium = "l" if ($notify and $status > 0 and $status < 3);
	    if ($medium) {
		    addStatusTopic($medium,$statusText[$status], "RAIDCtrl", $i);
		    addName($medium,$name);
		    addKeyLongValue($medium,"Type",$type);
		    addKeyLongValue($medium,"Property", $prop);
		    addMessage($medium,"\n");
	    }
	} # for
  } # agentRAIDCtrlTable
  sub agentRAIDPhysicalDeviceTable {
	# TODO --- agentRAIDPhysicalDeviceTable - calculate GB instead of MB ?
	my $notify = shift;
	my $verbose = shift;
	my $addedCmd = 0;
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    $addedCmd = 1 if ($gAgentRAIDPDeviceNumber{$c});
	    for (my $i=0;$i<$gAgentRAIDPDeviceNumber{$c};$i++) {
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveStatus", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveSmartStatus", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveName", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveBusType", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDrivePhysicalSize", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveProperty", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveEnclosureOid", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidPhysicalDriveAdapterPortOid", $c, $i);
	    } # for 
	} # for ctrl
	return if (!$addedCmd);
 	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusText = ( "Operational",
	    "Copyback","Available-not-configured","Unconfigured-failed","Dedicated-hot-spare","Global-hot-spare",
	    "Rebuilding","Rebuild-necessary","Rebuild-failed","JBOD disk","Migrating",
	    "Failed","Failed-missing","Offline","Shielded","Unknown", "..unexpected..",
	); # + 255:  Unknown
	my @smartText = ( "ok",
	    "failure","unknown","..unexpected..",
	); # + 255: S.M.A.R.T. status unknown
	my @typeText = ( "SCSI",
	    "ATAPI","PATA","Firewire IEEE 1394","SSA","Fibre",
	    "USB","SATA","SAS","RAID","MMC",
	    "SD card bus","..unexpected..",
	); # + 0xFF "Uknown"
	addTableHeader("v","RAID Physical Device")	if ($verbose);
	my $refCmd = agentJson_ExtractCmd($providerout);
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    for (my $i=0;$i<$gAgentRAIDPDeviceNumber{$c};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveStatus", $c, $i);
		my $smart = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveSmartStatus", $c, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveName", $c, $i);
		my $typenr = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveBusType", $c, $i);
		my $prop = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveProperty", $c, $i);
		my $size = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDrivePhysicalSize", $c, $i);
		my $encID = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveEnclosureOid", $c, $i);
		my $portID = agentJson_GetCmdSimpleData($refCmd,"RaidPhysicalDriveAdapterPortOid", $c, $i);
		
		#
		$status = 15 if ($status and $status =~ m/^\d+$/ and $status == 255);
		$status = 16 if (!defined $status or $status !~ m/^\d+$/ 
		    or $status < 0 or $status > 16);
		$smart = 2 if ($smart and $smart =~ m/^\d+$/ and $smart == 255);
		$smart = 2 if (!defined $smart or $smart !~ m/^\d+$/ 
		    or $smart < 0 or $smart > 2);
		$typenr = 12 if (!defined $typenr or $typenr !~ m/^\d+$/ 
		    or $typenr < 0 or ($typenr > 12 and $typenr != 255));
		my $type = undef;
		$type = "Other" if ($typenr == 255);
		$type = $typeText[$typenr] if ($typenr != 255);
		# 
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status > 0);
		if ($medium) {
			if (defined $smart and $smart < 2) {
				addStatusTopic($medium,$smartText[$smart], undef, undef);
			}
			addStatusTopic($medium,$statusText[$status], "RAIDPhysicalDevice", "$c.$i");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$c);
			addKeyLongValue($medium,"Type",$type);
			addKeyMB($medium,"Capacity", $size);
			addKeyUnsignedIntValue($medium,"EnclosureNr",$encID) if (defined $encID);
			addKeyUnsignedIntValue($medium,"PortNr",$portID) if (defined $portID);
			addKeyLongValue($medium,"Property", $prop);
			addMessage($medium,"\n");
		}
	    } # for 
	} # for ctrl
  } # agentRAIDPhysicalDeviceTable
  sub agentRAIDLogicalDriveTable {
	# TODO --- agentRAIDLogicalDriveTable - calculate GB instead of MB ?
	my $notify = shift;
	my $verbose = shift;
	my $addedCmd = 0;
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    $addedCmd = 1 if ($gAgentRAIDLDriveNumber{$c});
	    for (my $i=0;$i<$gAgentRAIDLDriveNumber{$c};$i++) {
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDriveStatus", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDriveName", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDriveLogicalSize", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDrivePhysicalSize", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDriveRaidLevel", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidLogicalDriveProperty", $c, $i);
	    } # for 
	} # for ctrl
 	return if (!$addedCmd);
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusText = ( "Operational",
	    "Degraded","Partially-Degraded","Failed","Impacted","Unknown", 
	    "..unexpected..",
	); # + 255:  Unknown
	addTableHeader("v","RAID Logical Drive")	if ($verbose);
	my $refCmd = agentJson_ExtractCmd($providerout);
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    for (my $i=0;$i<$gAgentRAIDLDriveNumber{$c};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDriveStatus", $c, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDriveName", $c, $i);
		my $prop = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDriveProperty", $c, $i);
		my $size = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDrivePhysicalSize", $c, $i);
		my $lsize = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDriveLogicalSize", $c, $i);
		my $level = agentJson_GetCmdSimpleData($refCmd,"RaidLogicalDriveRaidLevel", $c, $i);
		
		#
		$status = 5 if ($status and $status =~ m/^\d+$/ and $status == 255);
		$status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		    or $status < 0 or $status > 6);
		# 
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status > 0);
		if ($medium) {
			addStatusTopic($medium,$statusText[$status], "LogicalDrive", "$c.$i");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$c);
			addKeyLongValue($medium,"Level", $level);
			addKeyMB($medium,"LogicalSize", $lsize);
			addKeyMB($medium,"Capacity", $size);
			addKeyLongValue($medium,"Property", $prop);
			addMessage($medium,"\n");
		}
	    } # for 
	} # for ctrl
  } # agentRAIDLogicalDriveTable
  sub agentRAIDAdditional {
	my $notify = shift;
	my $verbose = shift;
	my $addedCmd = 0;
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    $addedCmd = 1 if ($gAgentRAIDBatteryNumber{$c});
	    $gAgentRAIDBatteryNumber{$c} = 0 if (!defined $gAgentRAIDBatteryNumber{$c});
	    for (my $i=0;$i<$gAgentRAIDBatteryNumber{$c};$i++) {
		agentJson_AddCmd($refArrayCmd,"RaidBatteryBackupUnitName", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidBatteryBackupUnitStatus", $c, $i);
	    };# for 
	    $addedCmd = 1 if ($gAgentRAIDPortNumber{$c});
	    $gAgentRAIDPortNumber{$c} = 0 if (!defined $gAgentRAIDPortNumber{$c});
	    for (my $i=0;$i<$gAgentRAIDPortNumber{$c};$i++) {
		agentJson_AddCmd($refArrayCmd,"RaidAdapterPortName", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidAdapterPortStatus", $c, $i);
	    } # for 
	    $addedCmd = 1 if ($gAgentRAIDEnclosureNumber{$c});
	    $gAgentRAIDEnclosureNumber{$c} = 0 if (!defined $gAgentRAIDEnclosureNumber{$c});
	    for (my $i=0;$i<$gAgentRAIDEnclosureNumber{$c};$i++) {
		agentJson_AddCmd($refArrayCmd,"RaidEnclosureName", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidEnclosureStatus", $c, $i);
		agentJson_AddCmd($refArrayCmd,"RaidEnclosureAdapterPortOid", $c, $i);
	    } # for 
	} # for ctrl
 	return if (!$addedCmd);
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	return if ($rc == 2);
	#### SPLIT
	my @statusBatteryText = ( "online",
	    "on-battery","battery-low","charging","discharging","Warning",
	    "failed","relearn-required","temperature-failure","Unknown", 
	    "..unexpected..",
	); # + 255:  Unknown
	my @statusText = ( "unknown",
	    "ok","warning","error","not-present","not-manageable",
 	    "undefined", "..unexpected..",
	);
	my $refCmd = agentJson_ExtractCmd($providerout);
	my $printedHeader = 0;
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    for (my $i=0;$i<$gAgentRAIDBatteryNumber{$c};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"RaidBatteryBackupUnitStatus", $c, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"RaidBatteryBackupUnitName", $c, $i);
		#
		next if (!defined $status and !defined $name);
		if ($verbose and !$printedHeader) {
		    addTableHeader("v","RAID Battery");
		    $printedHeader = 1;
		}
		$status = 9 if ($status and $status =~ m/^\d+$/ and $status == 255);
		$status = 10 if (!defined $status or $status !~ m/^\d+$/ 
		    or $status < 0 or $status > 10);
		# 
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status > 1);
		if ($medium) {
			addStatusTopic($medium,$statusBatteryText[$status], "RAIDBattery", "$c.$i");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$c);
			addMessage($medium,"\n");
		}
	    } # for 
	} # for ctrl
	$printedHeader = 0;
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    for (my $i=0;$i<$gAgentRAIDPortNumber{$c};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterPortStatus", $c, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"RaidAdapterPortName", $c, $i);
		#
		next if (!defined $status and !defined $name);
		if ($verbose and !$printedHeader) {
		    addTableHeader("v","RAID Port");
		    $printedHeader = 1;
		}
		$status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		    or $status < 0 or $status > 6);
		# 
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status > 1);
		if ($medium) {
			my $printStatus = undef;
			$printStatus  = $statusText[$status] if ($notify);
			addStatusTopic($medium,$printStatus, "RAIDPort", "$c.$i");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$c);
			addMessage($medium,"\n");
		}
	    } # for 
	} # for ctrl
	$printedHeader = 0;
	for (my $c=0;$c<$gAgentRAIDCtrlNumber;$c++) {
	    for (my $i=0;$i<$gAgentRAIDEnclosureNumber{$c};$i++) {
		my $status = agentJson_GetCmdSimpleData($refCmd,"RaidEnclosureStatus", $c, $i);
		my $name = agentJson_GetCmdSimpleData($refCmd,"RaidEnclosureName", $c, $i);
		my $portID = agentJson_GetCmdSimpleData($refCmd,"RaidEnclosureAdapterPortOid", $c, $i);
		#
		next if (!defined $status and !defined $name);
		if ($verbose and !$printedHeader) {
		    addTableHeader("v","RAID Enclosure");
		    $printedHeader = 1;
		}
		$status = 6 if (!defined $status or $status !~ m/^\d+$/ 
		    or $status < 0 or $status > 6);
		# 
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status > 1);
		if ($medium) {
			addStatusTopic($medium,$statusText[$status], "RAIDEnclosure", "$c.$i");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$c);
			addKeyUnsignedIntValue($medium,"PortNr",$portID) if (defined $portID);
			addMessage($medium,"\n");
		}
	    } # for 
	} # for ctrl
  } # agentRAIDAdditional
  sub agentRAID {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	if ($optChkSystem or $optChkStorage) {
		agentRAIDStatus($notify,$verbose);
		return if (!$verbose and !$notify and !$setExitCode);
		agent_getNumberforRAID();
		if ($verbose and !$gAgentRAIDCtrlNumber and defined $statusMassStorage
		and $statusMassStorage != 3) 
		{
		    	addTableHeader("v","RAID Controller");
			addMessage("v","MISSING: - There is no control adapter information available !\n");
		}
		return if (!$gAgentRAIDCtrlNumber);
		my $componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidCtrl and $raidCtrl < 3);
		agentRAIDCtrlTable($componentNotify,$verbose);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidPDevice and $raidPDevice < 3);
		agentRAIDPhysicalDeviceTable($componentNotify,$verbose);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidLDrive and $raidLDrive < 3);
		agentRAIDLogicalDriveTable($componentNotify,$verbose);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidPDevice and $raidPDevice < 3);
		if ($main::verbose >= 3 or $componentNotify) {
		    agentRAIDAdditional($componentNotify,$verbose);
		}
	} #optChkSystem
  } # agentRAID
 ####
  sub agentPerfCPU {
	#### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<6;$i++) {
		agentJson_AddCmd($refArrayCmd,"CpuOverallUsage", $i);
	    } # for
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $totalaverage = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 0);
	    my $totalcurrent = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 1);
	    my $kernelaverage = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 2);
	    my $kernelcurrent = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 3);
	    my $useraverage = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 4);
	    my $usercurrent = agentJson_GetCmdSimpleData($refCmd,"CpuOverallUsage", 5);

	if (defined $totalaverage) {
	    $exitCode = 0;
	    addKeyPercent("m", "TotalAverage", $totalaverage, undef,undef, undef,undef);
	    addKeyPercent("m", "Total", $totalcurrent, undef,undef, undef,undef);
	    addKeyPercent("m", "KernelAverage", $kernelaverage, undef,undef, undef,undef);
	    addKeyPercent("m", "Kernel", $kernelcurrent, undef,undef, undef,undef);
	    addKeyPercent("m", "UserAverage", $useraverage, undef,undef, undef,undef);
	    addKeyPercent("m", "User", $usercurrent, undef,undef, undef,undef);

	    addPercentageToPerfdata("CPUTotalAverage", $totalaverage, $optWarningLimit, $optCriticalLimit)
		    if (!$main::verboseTable);
	    if ($totalaverage and $optWarningLimit and $totalaverage > $optWarningLimit) {
		    $exitCode = 1 if ($exitCode != 2);
	    }
	    if ($totalaverage and $optCriticalLimit and $totalaverage > $optCriticalLimit) {
		    $exitCode = 2;
	    }
	}
  } # agentPerfCPU
  sub agentPerfPhysicalMemory {
	#### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<3;$i++) {
		agentJson_AddCmd($refArrayCmd,"UtilizationSystemMemory", undef, $i);
	    } # for
	#### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $rawPhysMem = agentJson_GetCmdSimpleData($refCmd,"UtilizationSystemMemory", undef, 0);
	    my $rawVirtMem = agentJson_GetCmdSimpleData($refCmd,"UtilizationSystemMemory", undef, 1);
	    my $rawPagedMem = agentJson_GetCmdSimpleData($refCmd,"UtilizationSystemMemory", undef, 2);
	
	    my @physMem = agentJson_RawDWordSplit($rawPhysMem);
	    my @virtMem = agentJson_RawDWordSplit($rawVirtMem);
	    my @pagedMem = agentJson_RawDWordSplit($rawPagedMem);
	if ($#physMem >= 0) {
	    $exitCode = 0;
	    my $percent = undef;
	    $percent = calcPercent($physMem[1], $physMem[0]) if ($#physMem > 0);
	    addKeyPercent("m","PhysicalPercent", $percent);
	    addKeyValueUnit("m", "PhysicalMem", $physMem[0], "KB");
	    addKeyValueUnit("m", "PhysicalMax", $physMem[1], "KB") if ($#physMem > 0);
	    # TODO ... MB calc

	    addPercentageToPerfdata("PhysicalMemory", $percent,$optWarningLimit,$optCriticalLimit)
		    if (!$main::verboseTable);
	    
	    if ($percent and $optWarningLimit and $percent > $optWarningLimit) {
		    $exitCode = 1 if ($exitCode != 2);
	    }
	    if ($percent and $optCriticalLimit and $percent > $optCriticalLimit) {
		    $exitCode = 2;
	    }
	}
	if ($#virtMem >= 0) {
	    addKeyValueUnit("m", "VirtualMem", $virtMem[0], "KB");
	    addKeyValueUnit("m", "VirtualMax", $virtMem[1], "KB");
	}
	if ($#pagedMem >= 0) {
	    addKeyValueUnit("m", "PagedMem", $pagedMem[0], "KB");
	    addKeyValueUnit("m", "PagedMax", $pagedMem[1], "KB");
	}
  } # agentPerfPhysicalMemory
  sub agentPerfFileSystem {
	my $nrFileSystems = 0;
	{ # nr FS
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"FileSystemNumberVolumes");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $nrFileSystems = agentJson_GetCmdSimpleData($refCmd,"FileSystemNumberVolumes");   
	}
	return if (!$nrFileSystems);
	$exitCode = 0;
	{ # get data
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    for (my $i=0;$i<$nrFileSystems;$i++) {
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumePathNames",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeDevicePath",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeTotalSize",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeFreeSize",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeFileSystemName",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeSerialNumber",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeLabel",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeUsage",undef,$i);
		agentJson_AddCmd($refArrayCmd,"FileSystemVolumeType",undef,$i);
	    } # for
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my @typeText = ( "fixed",
		"CDROM/DVDROM", "removable", "remote", "RAM","unknown",
		"..unexpected..",
	    );
	    my $all_notify = 0;
	    my $is_linux = 0;
	    for (my $i=0;$i<$nrFileSystems;$i++) {
		my $rawpath = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumePathNames", undef, $i); 
		    # string or multi string !!!
		my $device = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeDevicePath", undef, $i); 
		my $size = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeTotalSize", undef, $i); 
		my $free = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeFreeSize", undef, $i); 
		my $tname = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeFileSystemName", 
		    undef, $i); 
		my $serial = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeSerialNumber", undef, $i); 
		my $label = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeLabel", undef, $i); 
 		my $usage = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeUsage", undef, $i); 
		my $type = agentJson_GetCmdSimpleData($refCmd,"FileSystemVolumeType", undef, $i);
		$type = 5 if ($type and $type == 15);
		$type = 6 if (!defined $type or $type < 0 or $type > 6);

		my $firstname = $rawpath;
		my @allnames = ();
		if ($rawpath =~ m/^\[/) { # array
		    #TODO FileSystemVolumePathNames: what to do with the rest of names ?
		    $rawpath =~ s/\\\"/\"/g;

		    (my $rest, my $refallnames) = jsonSplitArray($rawpath);
		    @allnames = @{$refallnames};
		    my $refKeyValue = undef;
		    $refKeyValue = $allnames[0] if ($#allnames >= 0);
		    $firstname = $refKeyValue->{"VALUE"} if ($#allnames >= 0);
		}
		
		addStatusTopic("v",undef, "FS", $i);
		addName("v",$firstname,1);
		addKeyLongValue("v","Label", $label);
		addKeyPercent("v","Usage",$usage);
		addKeyValueUnit("v","Size",$size,"B");
		addKeyValueUnit("v","FreeSpace",$free,"B");
		addKeyValue("v","FSType", $tname);
		addKeyValue("v","VolumeType", $typeText[$type]) if ($type); # ignore 0
		addSerialIDs("v",$serial);
		addKeyLongValue("v","DevicePath", $device) if ($main::verbose >= 4);
		addMessage("v","\n");

		### performance ?
		if ($usage) {
		    my $name = $firstname;
		    $name = "FS_$i" if (!$name);
		    if ($name =~ m/([A-Z]+):\\/) { # windows
			$name = $1;
			$name .= "_$label" if ($label);
		    }
		    if ($name =~ m/^[\/]$/) { # linux
			$name = "ROOT";
			$is_linux = 1;
		    }
		    $name =~ s/[ ,;=]/_/g;
		    $name =~ s/[:()]//g;
		    $name =~ s/_[_]+/_/;

		    $usage = undef if ($is_linux and $usage == 100 and $type != 0);
			# mounted types or other have aleays usage 100%

		    addPercentageToPerfdata($name,$usage,
			    $optWarningLimit,$optCriticalLimit) if (defined $usage);
		    my $notify = 0;
		    if ($usage and $optWarningLimit 
			    and $usage > $optWarningLimit) {
			    $exitCode = 1 if ($exitCode != 2);
			    $notify = 1;
			    $all_notify = 1;
		    }
		    if ($usage and $optCriticalLimit and $usage > $optCriticalLimit) {
			    $exitCode = 2;
			    $notify = 1;
			    $all_notify = 1;
		    }
		    $notify = 0 if ($main::verbose >= 2); # allready printed
		    if ($notify and $usage) {
			    addStatusTopic("l",undef, "FS", $i);
			    addName("l",$rawpath,1);
			    addKeyLongValue("l","Label", $label);
			    addKeyLongValue("l","Type", $type);
			    addKeyIntValueUnit("l","Use",$usage,"%");
			    addMessage("l","\n");
		    }
		} # usage not 0

	    } # for
	    $msg .= "- file system limit reached" if ($all_notify); 
	} # data
  } # agentPerfFileSystem
  sub agentPerfNetwork {
	my $nrNetwork = 0;
	{ # nr FS
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"NetworkInfoNumberInterfaces");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $nrNetwork = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoNumberInterfaces");   
	}
	return if (!$nrNetwork);
	$exitCode = 0;
	{ # get data
	    #### BUILD
		(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$nrNetwork;$i++) {
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfConnectionName", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfUsage", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoIfSpeed", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"NetworkInfoUtilization", undef, $i)
			if ($main::verbose >=3);
		} # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    addTableHeader("v","Network Performance");
	    for (my $i=0;$i<$nrNetwork;$i++) {
		my $conn = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfConnectionName", undef, $i);
		my $usage = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfUsage", undef, $i);
		my $speed = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoIfSpeed", undef, $i);
		my $rawUtil = agentJson_GetCmdSimpleData($refCmd,"NetworkInfoUtilization", undef, $i);

		
		my $interfaceSpeed = undef;
		my $maxTransfer = undef;
		my $iTransfer = undef;
		my $oTransfer = undef;
		if ($main::verboseTable == 250) {
		    my @util = agentJson_RawDWordLongSplit($rawUtil); # seen for LINUX
		    $interfaceSpeed = $util[0]	if ($#util >= 0);
		    $maxTransfer = $util[1]		if ($#util >= 1);
		    $iTransfer = $util[2]		if ($#util >= 2);
		    $oTransfer = $util[3]		if ($#util >= 3);
		}

		addStatusTopic("v",undef, "Node", $i);
		addName("v",$conn,1);
		addKeyPercent("v","Usage",$usage);
		addKeyValueUnit("v","Speed", $speed, "Kbit/sec");
		addKeyLongValue("v","UtilRAW", $rawUtil) if ($main::verboseTable == 250);
		if ($rawUtil and $main::verboseTable == 250) {
		    addKeyValueUnit("v","InterfaceSpeed",$interfaceSpeed,"B/sec");
		    addKeyValueUnit("v","MaxTransfer",$maxTransfer,"B/sec");
		    addKeyValueUnit("v","InputTransfer",$iTransfer,"B/sec");
		    addKeyValueUnit("v","OutputTransfer",$oTransfer,"B/sec");
		}
		addMessage("v","\n");
	    } # for
	} # data
  } # agentPerfNetwork
  sub agentPerformanceInformation {
	agentPerfCPU() if ($optChkCpuLoadPerformance);
	agentPerfPhysicalMemory() if ($optChkMemoryPerformance);
	agentPerfFileSystem() if ($optChkFileSystemPerformance);
	agentPerfNetwork() if ($optChkNetworkPerformance);
  } # agentPerformanceInformation
 ####
  sub agentUpdateSystemStatus {
	#"UmServerStatus"			=> 0x3330,
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmServerStatus");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $updStatus = agentJson_GetCmdSimpleData($refCmd,"UmServerStatus");  
	    my @updText = ("ok",
		"recommended", "mandatory","unknown","undefined","..unexpected..");
	    $updStatus = 4 if (!defined $updStatus);
	    $updStatus = 5 if ($updStatus < 0 or $updStatus > 3);
	    addExitCode($updStatus) if ($updStatus < 3);
	    addComponentStatus("m", "UpdateStatus",$updText[$updStatus]);
  } # agentUpdateSystemStatus
  sub agentUpdateDiffTable {
	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g if ($fileHost);
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
	####
	my $nrComponent = 0;
	{ # nr of Update Components
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmDiffNumberComponents");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $nrComponent = agentJson_GetCmdSimpleData($refCmd,"UmDiffNumberComponents");   
	}
	if (!$nrComponent) {
	    addMessage("m", " - ") if ($msg);
	    addMessage("m","No update difference list available") if (!$nrComponent);
	    return if (!$nrComponent);
	}
	{ # get components
	    #### BUILD
		(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$nrComponent;$i++) {
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentPath", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentVersion", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffInstalledVersion", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRepos2InstRanking", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffIsMandatoryComponent", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffPreRequisitesText", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffUpdateVendorSeverity", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRebootRequired", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffInstallDuration", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffDownloadSize", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffVendor", undef, $i);
		} # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $componentVersion = agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentVersion", undef, $i);
		my $installedVersion = agentJson_GetCmdSimpleData($refCmd,"UmDiffInstalledVersion", undef, $i);
		my $repos2InstRanking = agentJson_GetCmdSimpleData($refCmd,"UmDiffRepos2InstRanking", undef, $i);
		
		next if (!$componentVersion or !$installedVersion);
		next if ($repos2InstRanking and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );

		my $componentPath	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentPath", undef, $i);
		my $updateVendorSeverity= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffUpdateVendorSeverity", undef, $i); 
		my $isMandatoryComponent= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffIsMandatoryComponent", undef, $i);
		my $downloadSize	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffDownloadSize", undef, $i);
		my $installDuration	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffInstallDuration", undef, $i);
		my $rebootRequired	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffRebootRequired", undef, $i);
		my $vendor		= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffVendor", undef, $i);
		my $prereq		= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffPreRequisitesText", undef, $i);
		$updateVendorSeverity = 3 
		    if (!defined $updateVendorSeverity or $updateVendorSeverity < 0 or $updateVendorSeverity > 2);
		$rebootRequired = 4 if (!defined $rebootRequired or $rebootRequired < 0 or $rebootRequired > 3);
		#### PRINT
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
			addMessage("l", "#\t");
			    addKeyLongValue("l", "Prerequisites", $prereq);
			addMessage("l", "\n");
		    }
		    $printIndex++;
		} #... print next
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
		    addMessage("v", "#\t");
			addKeyLongValue("v", "Prerequisites", $prereq);
		    addMessage("v", "\n");
		}#outdir
	    } # for
	} # components
	####
	addMessage("l", "#...\n") if ($printLimit and $printLimit == $printIndex);
	if ($optOutdir) {
	    writeTxtFile($fileHost, "DIFF", $variableVerboseMessage);
	}
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # agentUpdateDiffTable
  sub agentUpdateInstTable {
	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g if ($fileHost);
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
	####
	my $nrComponent = 0;
	{ # nr of Update Components
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmDiffNumberComponents");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $nrComponent = agentJson_GetCmdSimpleData($refCmd,"UmDiffNumberComponents");   
	}
	if (!$nrComponent) {
	    addMessage("m", " - ") if ($msg);
	    addMessage("m","No update installation list available") if (!$nrComponent);
	    return if (!$nrComponent);
	}
	{ # get components
	    #### BUILD
		(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$nrComponent;$i++) {
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentPath", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentVersion", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffInstalledVersion", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRepos2InstRanking", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffIsMandatoryComponent", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffPreRequisitesText", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffUpdateVendorSeverity", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRebootRequired", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffInstallDuration", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffDownloadSize", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffVendor", undef, $i);
		} # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $componentVersion = agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentVersion", undef, $i);
		my $installedVersion = agentJson_GetCmdSimpleData($refCmd,"UmDiffInstalledVersion", undef, $i);
		my $repos2InstRanking = agentJson_GetCmdSimpleData($refCmd,"UmDiffRepos2InstRanking", undef, $i);
		
		next if (!$installedVersion);
		my $uptodate = 0;
		$uptodate = 1 if ($repos2InstRanking 
		    and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );

		my $componentPath	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentPath", undef, $i);
		my $updateVendorSeverity= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffUpdateVendorSeverity", undef, $i); 
		my $isMandatoryComponent= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffIsMandatoryComponent", undef, $i);
		my $downloadSize	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffDownloadSize", undef, $i);
		my $installDuration	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffInstallDuration", undef, $i);
		my $rebootRequired	= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffRebootRequired", undef, $i);
		my $vendor		= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffVendor", undef, $i);
		my $prereq		= 
		    agentJson_GetCmdSimpleData($refCmd,"UmDiffPreRequisitesText", undef, $i);
		$updateVendorSeverity = 3 
		    if (!defined $updateVendorSeverity or $updateVendorSeverity < 0 or $updateVendorSeverity > 2);
		$rebootRequired = 4 if (!defined $rebootRequired or $rebootRequired < 0 or $rebootRequired > 3);
		#### PRINT
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
			addMessage("l", "#\t");
			    addKeyLongValue("l", "Prerequisites", $prereq);
			addMessage("l", "\n");
		    }
		    $printIndex++;
		} #... print next
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
		    addMessage("v", "#\t");
			addKeyLongValue("v", "Prerequisites", $prereq);
		    addMessage("v", "\n");
		}#outdir
	    } # for
	} # components
	####
	addMessage("l", "#...\n") if ($printLimit and $printLimit == $printIndex);
	if ($optOutdir) {
	    writeTxtFile($fileHost, "INST", $variableVerboseMessage);
	}
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # agentUpdateInstTable
  sub agentUpdateStatus {
	agentUpdateSystemStatus();
	return if ($exitCode == 3);
	agentUpdateDiffTable() if ($optChkUpdDiffList);
	agentUpdateInstTable() if ($optChkUpdInstList);
  } # agentUpdateStatus
#########################################################################
# iRMC Report.xml
#########################################################################
our $iRMCFullReport = undef;
our $iRMCStatusOverallString = undef;
our $iRMCReportIDPROMS = undef;
  sub iRMCReport_ScanIPROMS {
	my $searchClass = shift;
	my $searchValueName = shift;
	my $refClass = shift;
	my $out = undef;
	return undef if (!$refClass or !$searchClass or !$searchValueName);
	my @class = @{$refClass};
	for (my $i=0; $i<=$#class; $i++) {
	    my $classStream = $class[$i];
	    my $search = undef;
	    if ($classStream =~ m/\"$searchClass\"/ and $classStream =~ m/$searchValueName/) {
		$search = $searchValueName;
	    }
	    next if (!$search);
	    # perl has sometimes trouble with < and > in expressions
	    $out = $1 if ($classStream =~ m/($search[^<]+)/);
	    $out =~ s/^.*\>// if ($out);
	    last if ($out);
	} # for
	return $out;
  } # iRMCReport_ScanIPROMS
  #
  my $iRMCConnectedAgent = undef;
  sub iRMCReportConnectionTest {
	# initial tests with http is faster than https !
	$optRestHeaderLines = undef;
	my $save_optConnectTimeout = $optConnectTimeout;
	$optConnectTimeout  = 20 if (!defined $optConnectTimeout or $optConnectTimeout > 20);
	$useRESTverbose = 1; # for 401 discovery
	(my $out, my $outheader, my $errtext) = 
		restCall("GET","/report.xml?Item=System/Status",undef);
	#
	$useRESTverbose = 0;
	my $chkOut = $out;
	$chkOut =~ s/[\r\n]//g if ($chkOut);
	my $gotOverall = 0;
	if ($chkOut and $chkOut =~ m/xml.*Root.*SystemStatus/ ) {
	    addExitCode(0);
	    my $tmpStatusOverall = $1 if ($chkOut =~ m/SystemStatus(.*)SystemStatus/);
	    #next if (!defined $tmpStatusOverall);
	    if (defined $tmpStatusOverall) {
		$gotOverall = 1;
		$iRMCStatusOverallString = $1 if ($tmpStatusOverall =~ m/Description=\"([^\"]*)\"/);
		$tmpStatusOverall =~s/.*>//;
		$tmpStatusOverall =~s/<.*//;
		$statusOverall = 3;
		$statusOverall = 0 if ($tmpStatusOverall =~ m/^1$/);
		$statusOverall = 1 if ($tmpStatusOverall =~ m/^2$/);
		$statusOverall = 2 if ($tmpStatusOverall =~ m/^3$/);
	    }
	    # ... iRMC says this is SCCI status
	    #my @statusText = ("Unknown",
		#"OK", "Warning", "Error", "Not present", "Not manageable",
		#"..unexpected..",
	    #);
	    $iRMCConnectedAgent = $1 if ($chkOut =~ m/AgentConnected(.*)AgentConnected/);
	    $iRMCConnectedAgent =~ s/^>// if ($iRMCConnectedAgent);
	    $iRMCConnectedAgent =~ s!</$!! if ($iRMCConnectedAgent);
	    if ($chkOut and $chkOut =~ m/xml.*Root.*Summary/) { # older Firmware
		$out =~ s/\s+/ /gm if ($out);
		$iRMCFullReport = $out;
	    }
	} elsif ($chkOut and $chkOut =~ m/xml.*Root.*Summary/) { # older Firmware
	    addExitCode(0);
	    $out =~ s/\s+/ /gm if ($out);
	    $iRMCFullReport = $out;
	} else {
	    addExitCode(2); 
	}
	$gotOverall = 1 if ($main::verboseTable == 900); # try to use old fw
	if ($exitCode == 0 and $gotOverall and $optChkIdentify) {
	    addMessage("m","- ") if (!$msg);
	    addKeyLongValue("m","REST-Service", "ServerView iRMC Report");
	}
	if ($exitCode == 2) {
	    if ($optServiceType) {
		if ($outheader and $outheader =~ m/401/) {
		    addMessage("m","- ") if (!$msg);
		    addMessage("m","[ERROR] Authentication fault for ServerView iRMC Report");
		    addMessage("l", $errtext) if ($errtext);
		    $exitCode = 1;
		} else {
		    addMessage("m","- ") if (!$msg);
		    addMessage("m","[ERROR] Unable to connect to ServerView iRMC Report");
		    addMessage("l", $errtext) if ($errtext);
		}
	    } else {
		if ($outheader and $outheader =~ m/401/) {
		    addMessage("l","[ERROR] Authentication fault for ServerView iRMC Report");
		    addMessage("l", $errtext) if ($errtext);
		    $exitCode = 1;
		} else {
		    $errtext = '' if (!defined $errtext);
		    addMessage("l","[ERROR] Unable to connect to ServerView iRMC Report ($errtext)\n");
		}
	    }
	}
	if (!$gotOverall and $exitCode != 2 and $exitCode != 1) {
	    if ($optServiceType) {
		addMessage("m","- ") if (!$msg);
		addMessage("m","[ERROR] Too old firmware of ServerView iRMC Report");
	    } else {
		addMessage("l","[ERROR] Too old firmware of ServerView iRMC Report\n");
	    }
	    $exitCode = 1;
	}
	$optServiceType = "REPORT" if ($exitCode == 0 and !defined $optServiceType);
	$optRestHeaderLines = undef;
	$optConnectTimeout = $save_optConnectTimeout;
  } # iRMCReportConnectionTest
  sub iRMCReportSerialID {
	my $stream = undef;
	my $serialid = undef;
=begin NOFULLIRMCREPORT
	if (!$iRMCFullReport and $setOverallStatus) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $iRMCFullReport = $out;
	}
=end NOFULLIRMCREPORT
=cut
	$stream = $iRMCFullReport;
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/IDPROMS",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	    $iRMCReportIDPROMS = $stream; # Multi used part
	}
	return undef if (!$stream);
	my $idproms = undef;
	$idproms = $1 if ($stream =~ m/(\<IDPROMS.*IDPROMS\>)/);
	return undef if (!$idproms);
	my @class = sxmlSplitObjectTag($idproms);
	$serialid = iRMCReport_ScanIPROMS("Product","Product Serial Number", \@class);
	$serialid = iRMCReport_ScanIPROMS("System Board","System Board Serial Number", \@class)
	    if (!$serialid);
	return $serialid;
  } # iRMCReportSerialID
  sub iRMCReportOverallStatusValues {
	$noSummaryStatus = 1;
	#### System
	if ($optChkSystem) {
	    addExitCode($statusOverall) if (defined $statusOverall);
	    #addMessage("m","-") if (!$msg);
	    addComponentStatus("m", "Overall", $iRMCStatusOverallString);
	}
	#
=begin NOFULLIRMCREPORT
	if (!$iRMCFullReport and $setOverallStatus) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $iRMCFullReport = $out;
	}
=end NOFULLIRMCREPORT
=cut
  } # iRMCReportOverallStatusValues
  sub iRMCReportSystemInventoryInfo {
	#return if (!$optAgentInfo and $main::verbose < 3);
	#### AGENT INFO
	{
	    my $stream = undef;
	    $stream = $iRMCFullReport;
	    if (!$stream) {
		(my $out, my $outheader, my $errtext) = 
			restCall("GET","/report.xml?Item=System/ManagementControllers",undef);
		$out =~ s/\s+/ /gm if ($out);
		$stream = $out;
	    }
	    return undef if (!$stream);
	    my $ctrls = undef;
	    $ctrls = $1 if ($stream =~ m/(\<ManagementControllers.*ManagementControllers\>)/);
	    return undef if (!$ctrls);
	    my $iRMC = undef;
	    $iRMC = $1 if ($ctrls =~ m/(\<iRMC.*iRMC\>)/);
	    return undef if (!$iRMC);
	    my $fwversion = undef;
	    my $name = undef;
	    $fwversion = $1 if ($iRMC =~ m/Firmware[^\>]*\>([^\<]*)\<.Firmware/);
	    $name = $1	    if ($iRMC =~ m/Name=\"([^\"]*)\"/);
	    if ($fwversion and $optAgentInfo) {
		addKeyValue("m","Version",$fwversion);
		addStatusTopic("l",undef,"AgentInfo", undef);
		addName("l",$name);
		addKeyValue("l","Version",$fwversion);
		addKeyLongValue("l","ConnectedAgent", $iRMCConnectedAgent);
		addMessage("l","\n");
		$exitCode = 0;
	    } elsif ($main::verbose >= 3) {
		addStatusTopic("v",undef,"AgentInfo", undef);
		addName("v",$name);
		addKeyValue("v","Version",$fwversion) if ($fwversion !~ m/\s/);
		addKeyLongValue("v","Version",$fwversion) if ($fwversion =~ m/\s/);
		addKeyLongValue("v","ConnectedAgent", $iRMCConnectedAgent);
		#addKeyLongValue("v","Company",$company);
		addMessage("v","\n");
	    } #verbose
	} # agent
  } # iRMCReportSystemInventoryInfo
  sub iRMCReportSystemNotifyInformation {
	my $stream = undef;
	$stream = $iRMCReportIDPROMS;
	$stream = $iRMCFullReport if (!$stream);
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/IDPROMS",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	    $iRMCReportIDPROMS = $stream; # Multi used part
	}
	return undef if (!$stream);
	my $idproms = undef;
	$idproms = $1 if ($stream =~ m/(\<IDPROMS.*IDPROMS\>)/);
	return undef if (!$idproms);
	#### iRMC Name
	my $iRMCName = undef;
	if ($iRMCFullReport) {
	    my $summary = undef;
	    $summary = $1 if ($stream =~ m/(\<Summary.*Summary\>)/);
	    $iRMCName = $1 if ($summary and $summary =~ m/Computer(.*)Computer/);
	    $iRMCName =~ s/^[^\>]*\>// if ($iRMCName);
	    $iRMCName =~ s/\<.*// if ($iRMCName);
	}
	#### MODEL
	my $model = undef;
	my @class = sxmlSplitObjectTag($idproms);
	$model = iRMCReport_ScanIPROMS("Product","Product Model", \@class);
	$model = iRMCReport_ScanIPROMS("System Board","System Board Model", \@class)
	    if (!$model);
	####
	if ($model or $iRMCName) {
	    addKeyLongValue("n","iRMC-Name", $iRMCName);
	    addProductModel("n", undef, $model);
	}
	addExitCode(0) if ($optSystemInfo);
  } # iRMCReportSystemNotifyInformation
 ####
  sub iRMCReportAllFanSensors {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/Fans",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	my $fans = undef;
	$fans = $1 if ($stream =~ m/(\<Fans.*Fans\>)/);
	return undef if (!$fans); # no fan collection available
	#
	my @fanArray = sxmlSplitObjectTag($fans);
	#   <Fan Name="FAN1 SYS" CSS="true">
	#    <Status Description="ok">1</Status>
	#    <CurrSpeed>5160</CurrSpeed>
	#    <CurrMaxSpeed>5100</CurrMaxSpeed>
	#    <NomMaxSpeed>5100</NomMaxSpeed>
	#   </Fan>
	#define CMV_FANSTAT_DISABLE (BYTE) 0
	#define CMV_FANSTAT_OK (BYTE) 1
	#define CMV_FANSTAT_FAIL (BYTE) 2
	#define CMV_FANSTAT_PREFAIL (BYTE) 3
	#define CMV_FANSTAT_REDUND_FAIL (BYTE) 4
	#define CMV_FANSTAT_NOT_MANAGE (BYTE) 5
	#define CMV_FANSTAT_NOT_PRESENT (BYTE) 6
	addTableHeader("v","Fans") if ($verbose and $#fanArray > 0);
	for (my $i=0;$i <= $#fanArray; $i++) {
	    my $sensor = $fanArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $speed = undef;
	    $name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $speed = $1		if ($sensor =~ m/CurrSpeed[^\>]*\>([\d]+)/);
	    #$statusdescr =~ s/\"//g;
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status
		and ($status == 2 or $status == 3 or $status == 4 ));
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "Fan", $i);
		    addName($medium,$name);
		    addKeyRpm($medium,"Speed", $speed);
		    addMessage($medium,"\n");
	    }
	    if ($optChkFanPerformance) {
		    $name =~ s/[\s\,\.\$\(\)]+/_/g;
		    $name =~ s/_+/_/g;
		    addRpmToPerfdata($name, $speed, undef, undef);
	    }
	    if ($setExitCode and defined $status) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1);
		$localExitCode = 1 if ($status == 3 or $status == 4);
		$localExitCode = 2 if ($status == 2);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $allFanStatus = $tmpExitCode if (!defined $allFanStatus);
	    if ($allFanStatus and $allFanStatus < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$allFanStatus = $statusOverall if ($statusOverall < $allFanStatus);
	    }
	    if ($optChkEnv_Fan and !$optChkEnvironment) {
		addComponentStatus("m", "Fans",$state[$allFanStatus]);
	    }
	}
  } # iRMCReportAllFanSensors
  sub iRMCReportAllTemperatureSensors {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	#
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/Temperatures",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	my $sensors = undef;
	$sensors = $1 if ($stream =~ m/(\<Temperatures.*Temperatures\>)/);
	return undef if (!$sensors); # no sensors collection available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	    #   <Temperature Name="Ambient" CSS="false">
	    #    <Status Description="ok">6</Status>
	    #    <CurrValue>30</CurrValue>
	    #    <WarningThreshold>37</WarningThreshold>
	    #    <CriticalThreshold>42</CriticalThreshold>
	    #   </Temperature>
	    #define CMV_SENSSTAT_NOTAVAIL (BYTE) 0
	    #define CMV_SENSSTAT_OK (BYTE) 1
	    #define CMV_SENSSTAT_FAIL (BYTE) 3
	    #define CMV_SENSSTAT_TEMPWARN (BYTE) 4
	    #define CMV_SENSSTAT_TEMPCRIT (BYTE) 5
	    #define CMV_SENSSTAT_TEMPOK (BYTE) 6
	    #define CMV_SENSSTAT_TEMPPREWARN (BYTE) 7
	addTableHeader("v","Temperature Sensors") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $current = undef;
	    my $warn = undef;
	    my $crit = undef;
	    $name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $current = $1	if ($sensor =~ m/CurrValue[^\>]*\>([\d]+)/);
	    $warn = $1		if ($sensor =~ m/WarningThreshold[^\>]*\>([\d]+)/);
	    $crit = $1		if ($sensor =~ m/CriticalThreshold[^\>]*\>([\d]+)/);
	    $status = 0 if (!defined $status);
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status 
		and $status >= 3 and $status <= 7 and $status != 6);
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "Sensor", $i);
		    addName($medium,$name);
		    addCelsius($medium,$current, $warn, $crit);
		    addMessage($medium,"\n");
	    }
	    { # performance
		    $name =~ s/[\s\,\.\$\(\)]+/_/g;
		    $name =~ s/_+/_/g;
		    addTemperatureToPerfdata($name, $current, $warn, $crit)
				if (!$main::verboseTable);	    
	    }
	    if ($setExitCode and defined $status) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1 or $status == 6);
		$localExitCode = 1 if ($status == 4 or $status == 7);
		$localExitCode = 2 if ($status == 3 or $status == 5);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $allTempStatus = $tmpExitCode if (!defined $allTempStatus);
	    if ($allTempStatus and $allTempStatus < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$allTempStatus = $statusOverall if ($statusOverall < $allTempStatus);
	    }
	    if ($optChkEnv_Temp and !$optChkEnvironment) {
		addComponentStatus("m", "TemperatureSensors",$state[$allTempStatus]);
	    }
	}
  } # iRMCReportAllTemperatureSensors
  sub iRMCReportAllPowerSupplies {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/PowerSupplies",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	my $sensors = undef;
	$sensors = $1 if ($stream =~ m/(\<PowerSupplies.*PowerSupplies\>)/);
	return undef if (!$sensors); # no sensors collection available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	#   <PowerSupply Name="PSU1" CSS="true">
	#    <Status Description="ok">1</Status>
	#    <Load>110</Load>
	#   </PowerSupply>
	#define CMV_PSSTAT_NOT_PRES (BYTE) 0
	#define CMV_PSSTAT_OK (BYTE) 1
	#define CMV_PSSTAT_FAIL (BYTE) 2
	#define CMV_PSSTAT_AC_FAIL (BYTE) 3
	#define CMV_PSSTAT_DC_FAIL (BYTE) 4
	#define CMV_PSSTAT_TEMPCRIT (BYTE) 5
	#define CMV_PSSTAT_NOTMANAGE (BYTE) 6
	#define CMV_PSSTAT_FAN_PREFAIL (BYTE) 7
	#define CMV_PSSTAT_FAN_FAIL (BYTE) 8
	#define CMV_PSSTAT_PWR_SAVE_MODE (BYTE) 9
	#define CMV_PSSTAT_NONRED_DC_FAIL (BYTE) 10
	#define CMV_PSSTAT_NONRED_AC_FAIL (BYTE) 11
	addTableHeader("v","Power Supplies") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $load = undef;
	    $name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $load = $1		if ($sensor =~ m/Load[^\>]*\>([\d]+)/);
	    $status = 0 if (!defined $status);
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status 
		and $status >= 2 and $status <= 11 and $status != 6);
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "PSU", $i);
		    addName($medium,$name);
		    addKeyWatt($medium, "CurrentLoad", $load);
		    addMessage($medium,"\n");
	    }
	    if ($setExitCode and defined $status) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1);
		$localExitCode = 1 if ($status == 7);
		$localExitCode = 2 if ($status >= 2 and $status <= 11
		    and $status != 6 and $status != 7);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $statusPower = $tmpExitCode if (!defined $statusPower);
	    if ($statusPower and $statusPower < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$statusPower = $statusOverall if ($statusOverall < $statusPower);
	    }
	}
  } # iRMCReportAllPowerSupplies
  sub iRMCReportAllPowerConsumption {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/PowerConsumption",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	my $allconsumption = undef;
	$allconsumption = $1 if ($stream =~ m/(\<PowerConsumption.*PowerConsumption\>)/);
	return undef if (!$allconsumption); # no data available
	#
	my $sensors = undef;
	$sensors = $1 if ($allconsumption =~ m/(\<Sensors.*Sensors\>)/);
	return undef if (!$sensors); # no data available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	addTableHeader("v","Power Consumption") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
		my $name = undef;
		my $current = undef;
		my $warn = undef;
		my $crit = undef;
		my $status = undef;
		my $statusdescr = undef;
		$name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
		if ($name =~ m/Total Power Out/) {
			$current = $1		if ($sensor =~ m/CurrentValue[^\>]*\>([\d]+)/);
			$statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
		} elsif ($name =~ m/Total Power/) {
			#$status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
				# MISSING description of status numbers !!!
			$statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
			$current = $1		if ($sensor =~ m/CurrentValue[^\>]*\>([\d]+)/);
			$warn = $1			if ($sensor =~ m/WarningThreshold[^\>]*\>([\d]+)/);
			$crit = $1			if ($sensor =~ m/CriticalThreshold[^\>]*\>([\d]+)/);
			$status = 0 if ($warn and $current < $warn);
			$status = 1 if ($crit and !defined $status and $current < $crit);
			$status = 2 if ($crit and !defined $status);
			addPowerConsumptionToPerfdata($current, $warn,$crit)
				if (!$main::verboseTable);
		}
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and $status);
	    if ($medium and defined $current) {
		    addStatusTopic($medium,$statusdescr, "PSCons", $i);
		    addName($medium,$name);
		    addKeyWatt($medium, "Current", $current, $warn, $crit);
		    addMessage($medium,"\n");
	    }
	} # end for

  } # iRMCReportAllPowerConsumption
  sub iRMCReportAllCPU {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	#
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/Processor",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	my $sensors = undef;
	$sensors = $1 if ($stream =~ m/(\<Processor.*Processor\>)/);
	return undef if (!$sensors); # no sensors collection available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	    #<CPU Boot="true">
	    #	<SocketDesignation>CPU1</SocketDesignation>
	    #	<Manufacturer>Intel</Manufacturer>
	    #	<Model>
	    #	 <Version>Intel(R) Xeon(R) CPU E7-4850 v3 @ 2.20GHz</Version>
	    #	 <BrandName>Intel(R) Xeon(R) CPU E7-4850 v3 @ 2.20GHz</BrandName>
	    #	</Model>
	    #	<Speed>2200</Speed>
	    #	<Status Description="ok">1</Status>
	    #	<CoreNumber>14</CoreNumber>
	    #	<LogicalCpuNumber>28</LogicalCpuNumber>
	    #	<QPISpeed Unit="MT/s">8000</QPISpeed>
	    #	<Level1CacheSize Unit="KByte">896</Level1CacheSize>
	    #	<Level2CacheSize Unit="KByte">3584</Level2CacheSize>
	    #	<Level3CacheSize Unit="MByte">35</Level3CacheSize>
	    #</CPU>
	    #define CMV_CPUSTAT_EMPTYSOCK (BYTE) 0
	    #define CMV_CPUSTAT_OK (BYTE) 1
	    #define CMV_CPUSTAT_DISABLE (BYTE) 2
	    #define CMV_CPUSTAT_ERROR (BYTE) 3
	    #define CMV_CPUSTAT_FAIL (BYTE) 4
	    #define CMV_CPUSTAT_NOTERMINATE (BYTE) 5
	    #define CMV_CPUSTAT_PREFAIL (BYTE) 6
	addTableHeader("v","CPU Table") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $model = undef;
	    my $manufact = undef;
	    my $speed = undef;
	    $name = $1		if ($sensor =~ m/SocketDesignation[^\>]*\>([^\<]+)/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $speed = $1		if ($sensor =~ m/Speed[^\>]*\>([\d]+)/);
	    $model = $1		if ($sensor =~ m/Version[^\>]*\>([^\<]+)/);
	    $manufact = $1	if ($sensor =~ m/Manufacturer[^\>]*\>([^\<]+)/);
	    $status = 0 if (!defined $status);
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status and $status >= 3 and $status <= 6);
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "CPU", $i);
		    addName($medium,$name);
		    addKeyMHz($medium, "Speed", $speed);
		    addProductModel($medium,undef,$model);
		    addKeyLongValue($medium,"Manufacturer", $manufact);
		    addMessage($medium,"\n");
	    } 
	    if ($setExitCode and defined $status) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1);
		$localExitCode = 1 if ($status == 3 or $status == 6);
		$localExitCode = 2 if ($status == 4 or $status == 5);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $allCPUStatus = $tmpExitCode if (!defined $allCPUStatus);
	    if ($allCPUStatus and $allCPUStatus < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$allCPUStatus = $statusOverall if ($statusOverall < $allCPUStatus);
	    }
	    if (($optChkCPU or $optChkHardware) and !$optChkSystem) {
		addComponentStatus("m", "CPUs",$state[$allCPUStatus]);
	    }
	}
  } # iRMCReportAllCPU
  sub iRMCReportAllVoltages {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	#
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/Voltages",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	my $sensors = undef;
	$sensors = $1 if ($stream =~ m/(\<Voltages.*Voltages\>)/);
	return undef if (!$sensors); # no sensors collection available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	    #  <Voltage Name="BATT 3.0V" CSS="false">
	    #   <Status Description="ok">1</Status>
	    #   <CurrValue>2.79</CurrValue>
	    #   <NomValue>3.00</NomValue>
	    #   <Thresholds>
	    #    <MinValue>1.50</MinValue>
	    #    <MaxValue>3.50</MaxValue>
	    #   </Thresholds>
	    #  </Voltage>	    
	    #define CMV_VOLTAGE_NOTAVAIL (BYTE) 0
	    #define CMV_VOLTAGE_OK (BYTE) 1
	    #define CMV_VOLTAGE_TOO_LOW (BYTE) 2
	    #define CMV_VOLTAGE_TOO_HIGH (BYTE) 3
	    #define CMV_VOLTAGE_NOT_OK (BYTE) 4
	    #define CMV_VOLTAGE_PREFAILURE (BYTE) 5
	addTableHeader("v","Voltages") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $current = undef;
	    my $nominal = undef;
	    my $critmin = undef;
	    my $critmax = undef;
	    $name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $current = $1	if ($sensor =~ m/CurrValue[^\>]*\>([\d\.]+)/);
	    $nominal = $1	if ($sensor =~ m/NomValue[^\>]*\>([\d\.]+)/);
	    $critmin = $1	if ($sensor =~ m/MinValue[^\>]*\>([\d\.]+)/);
	    $critmax = $1	if ($sensor =~ m/MaxValue[^\>]*\>([\d\.]+)/);
	    #
	    $status = 0 if (!defined $status);
	    my $crit = undef;
	    if (defined $critmin and defined $critmax and $critmin != $critmax) {
		$crit = "$critmin:$critmax";
	    } elsif (defined $critmin and defined $critmax and $critmin == $critmax) {
		$crit = "$critmin";
	    } elsif (defined $critmin and !defined $critmax) {
		$crit = "$critmin";
	    } elsif (!defined $critmin and defined $critmax) {
		$crit = "$critmax";
	    }
	    #
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status and $status > 1 and $status < 6);
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "Voltage", $i);
		    addName($medium,$name);
		    addKeyIntValueUnit($medium,"Current",$current,"V");
		    addKeyIntValueUnit($medium,"Critical",$crit,"V");
		    addKeyIntValueUnit($medium,"Nominal",$nominal,"V");
		    addMessage($medium,"\n");
	    }
	    if ($setExitCode) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1);
		$localExitCode = 1 if ($status == 5);
		$localExitCode = 2 if ($status >= 2 and $status <= 4);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $allVoltageStatus = $tmpExitCode if (!defined $allVoltageStatus);
	    if ($allVoltageStatus and $allVoltageStatus < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$allVoltageStatus = $statusOverall if ($statusOverall < $allVoltageStatus);
	    }
	    if (($optChkVoltage or $optChkHardware) and !$optChkSystem) {
		addComponentStatus("m", "Voltages",$state[$allVoltageStatus]);
	    }
	}
  } # iRMCReportAllVoltages
  sub iRMCReportAllMemoryModules {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	#
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=System/Memory",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	#
	#  <Memory Schema="2">
	#       <Installed>32768</Installed>
	#       <Modules Count="96"> ...
	my $sensors = undef;
	$sensors = $1 if ($stream =~ m/(\<Modules.*Modules\>)/);
	return undef if (!$sensors); # no sensors collection available
	#
	my @sensorArray = sxmlSplitObjectTag($sensors);
	    #<Module Name="MEM3_DIMM-A1" CSS="true">
	    #     <Status Description="ok">1</Status>
	    #     <Approved>false</Approved>
	    #     <Size>8192</Size>
	    #     <Type>DDR4</Type>
	    #     <BusFrequency Unit="MHz">1333</BusFrequency>
	    #     <SPD Size="512" Revision="1.0" Checksum="true">
	    #      <Checksum>
	    #       <Data>4751</Data>
	    #       <Calculated>4751</Calculated>
	    #      </Checksum>
	    #      <ModuleManufacturer>Samsung</ModuleManufacturer>
	    #      <ModuleManufacturingDate>2014,26</ModuleManufacturingDate>
	    #      <ModulePartNumber>M393A1G40DB0-CPB    </ModulePartNumber>
	    #      <ModuleRevisionCode>0</ModuleRevisionCode>
	    #      <ModuleSerialNumber AsString="B1550602">-1319827966</ModuleSerialNumber>
	    #      <ModuleType>RDIMM</ModuleType>
	    #      <DeviceType>DDR4</DeviceType>
	    #      <DeviceTechnology>1Gx4/16x10x4</DeviceTechnology>
	    #      <BusFrequency Unit="MHz">2133</BusFrequency>
	    #      <VoltageInterface>1.2V</VoltageInterface>
	    #      <CASLatencies>10;11;12;13;14;15;16;</CASLatencies>
	    #      <DataWith>72</DataWith>
	    #      <NumberRanks>1</NumberRanks>
	    #     </SPD>
	    #     <ConfigStatus Description="Normal">0</ConfigStatus>
	    #</Module>
	    #define CMV_MEMSTAT_EMPTYSLOT (BYTE) 0
	    #define CMV_MEMSTAT_OK (BYTE) 1
	    #define CMV_MEMSTAT_DISABLE (BYTE) 2
	    #define CMV_MEMSTAT_ERROR (BYTE) 3
	    #define CMV_MEMSTAT_FAIL (BYTE) 4
	    #define CMV_MEMSTAT_PREFAIL (BYTE) 5
	    #define CMV_MEMSTAT_HOT_SPARE (BYTE) 6
	    #define CMV_MEMSTAT_MIRROR (BYTE) 7
	    #define CMV_MEMSTAT_RAID (BYTE) 8
	    #define CMV_MEMSTAT_HIDDEN (BYTE) 9
	addTableHeader("v","Memory Modules Table") if ($verbose and $#sensorArray > 0);
	for (my $i=0;$i <= $#sensorArray; $i++) {
	    my $sensor = $sensorArray[$i];
	    next if (!$sensor);
	    my $name = undef;
	    my $status = undef;
	    my $statusdescr = undef;
	    my $size = undef;
	    my $sizeunit = undef;
	    my $type = undef;
	    my $frequency = undef;
	    my $volt = undef;
	  
	    $name = $1		if ($sensor =~ m/Name=\"([^\"]*)\"/);
	    $status = $1	if ($sensor =~ m/Status[^\>]*\>([\d]+)/);
	    $statusdescr = $1	if ($sensor =~ m/Status Description=\"([^\"]+)\"/);
	    $size = $1		if ($sensor =~ m/Size[^\>]*\>([\d]+)/);
	    $sizeunit = $1		if ($sensor =~ m/\<Size Unit=\"([^\"]+)\"/);
	    $frequency = $1	if ($sensor =~ m/BusFrequency[^\>]*\>([\d]+)/);
	    $type = $1		if ($sensor =~ m/Type[^\>]*\>([^\<]+)/);
	    $volt = $1		if ($sensor =~ m/VoltageInterface[^\>]*\>([^\<]+)/);
	    #
	    $status = 0 if (!defined $status);
	    #
	    if ($sizeunit and $size and $sizeunit =~ m/GByte/i) {
		$size *= 1000;
	    }
	    my $max = undef;
	    if ($status) {
		my $spd = undef;
		$spd = $1 if ($stream =~ m/(\<SPD.*SPD\>)/);
		$max = $1 if ($spd and $spd =~ m/BusFrequency[^\>]*\>([\d]+)/);
	    }
	    my $medium = undef;
	    $medium = "v" if ($verbose and ($status or $main::verbose >= 3));
	    $medium = "l" if ($notify and defined $status and $status > 2 and $status < 9);
	    if ($medium) {
		    addStatusTopic($medium,$statusdescr, "Memory", $i);
		    addName($medium,$name);
		    addKeyLongValue($medium,"Type", $type);
		    addKeyMB($medium,"Capacity", $size);
		    addKeyMHz($medium,"Frequency", $frequency);
		    addKeyMHz($medium,"Frequency-Max", $max);
		    addKeyValue($medium,"Voltage", $volt);		
		    addMessage($medium,"\n");
	    }
	    if ($setExitCode) {
		my $localExitCode = 3;
		$localExitCode = 0 if ($status == 1);
		$localExitCode = 1 if ($status == 5);
		$localExitCode = 2 if ($status >= 2 and $status <= 4);
		$tmpExitCode = addTmpExitCode($localExitCode,$tmpExitCode);
	    }
	} # for
	if ($setExitCode) {
	    $allMemoryStatus = $tmpExitCode if (!defined $allMemoryStatus);
	    if ($allMemoryStatus and $allMemoryStatus < 3 
	    and defined $statusOverall and $statusOverall != 3) 
	    {
		$allMemoryStatus = $statusOverall if ($statusOverall < $allMemoryStatus);
	    }
	    if (($optChkMemMod or $optChkHardware) and !$optChkSystem) {
		addComponentStatus("m", "MemoryModules",$state[$allMemoryStatus]);
	    }
	}
  } # iRMCReportAllMemoryModules
  sub iRMCReportAllStorageAdapter {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	iRMCReportRAID($setExitCode,$notify,$verbose);
  } # iRMCReportAllStorageAdapter
 ####
  sub iRMCReportRAID_ExitCode {
	my $stString = shift;
	return undef if (!defined $stString);
	my $tmpExitCode = 3;
	$tmpExitCode = 0 if ($stString and $stString =~ m/ok/i);
	$tmpExitCode = 1 if ($tmpExitCode == 3 and $stString and ($stString =~ m/warning/i) );
	$tmpExitCode = 2 if ($tmpExitCode == 3 and $stString and ($stString =~ m/failed/i) );
	return $tmpExitCode;
  } # iRMCReportRAID_ExitCode
  sub iRMCReportRAIDStatus {
 	my $stream = shift;
 	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	my $part = undef;
	$part = $1 if ($stream =~ m/(\<Multiplexer.*Multiplexer\>)/);
	return if (!$part);
	#      <Multiplexer>
	#       <Status>Operational</Status>
	#       <StatusOverall>OK</StatusOverall>
	#       <StatusAdapters>OK</StatusAdapters>
	#       <StatusLogicalDrives>OK</StatusLogicalDrives>
	#       <StatusDisks>OK</StatusDisks>
	#      </Multiplexer>
	my $stringOverall = undef;
	my $stringCtrl = undef;
	my $stringPDevice = undef;
	my $stringLDrive = undef;
	$stringOverall = $1		if ($part =~ m/StatusOverall[^\>]*\>([^\<]+)/);
	$stringCtrl = $1		if ($part =~ m/StatusAdapters[^\>]*\>([^\<]+)/);
	$stringPDevice = $1		if ($part =~ m/StatusDisks[^\>]*\>([^\<]+)/);
	$stringLDrive = $1		if ($part =~ m/StatusLogicalDrives[^\>]*\>([^\<]+)/);
	#### PRINT
	addTableHeader("v","RAID Overview") if ($verbose);
	my $tmpExitCode = iRMCReportRAID_ExitCode($stringOverall);
	my $medium = undef;
	$medium = "v" if ($verbose);
	$medium = "l" if (!$medium and $notify and $tmpExitCode and $tmpExitCode < 3);
	if ($medium and defined $stringOverall) {
		addStatusTopic($medium,$stringOverall,
			"RAID -", undef);
		addComponentStatus($medium,"Controller", $stringCtrl)
			if (defined $stringCtrl);
		addComponentStatus($medium,"PhysicalDevice", $stringPDevice)
			if (defined $stringPDevice);
		addComponentStatus($medium,"LogicalDrive", $stringLDrive)
			if (defined $stringLDrive);
		addMessage($medium,"\n");
	}
	$raidCtrl	= iRMCReportRAID_ExitCode($stringCtrl);
	$raidLDrive	= iRMCReportRAID_ExitCode($stringLDrive);
	$raidPDevice	= iRMCReportRAID_ExitCode($stringPDevice);
	if ($setExitCode) {
	    $statusMassStorage = 3;
	    $statusMassStorage = addTmpExitCode($tmpExitCode, $statusMassStorage)
	}
  } # iRMCReportRAIDStatus
 ###
  our %gHashiRMCAdapter = ();
  sub iRMCReportRAIDCtrlTable {
	my $notify = shift;
	my $verbose = shift;
	my $refadapter = shift;
	my @adapter = @$refadapter;
	addTableHeader("v","RAID Controller") if ($verbose);
	# Split next layer
	for (my $a=0;$a<=$#adapter;$a++) {
	    my $oneAdapter = $adapter[$a];
	    next if (!defined $oneAdapter);
	    my @adapterElemArray = sxmlSplitObjectTag($oneAdapter);
	    $gHashiRMCAdapter{$a} = \@adapterElemArray;
	} # for
	#
	my $status = undef;
	my $serial = undef;
	my $name = undef;
	my $size = undef;
	my $prot = undef;
	my $drvname = undef;
	my $drvversion = undef;
	for (my $a=0;$a<=$#adapter;$a++) {
	    my $refadapter = $gHashiRMCAdapter{$a};
	    my @adapterElemArray = @$refadapter;
	    for (my $e=0;$e<=$#adapterElemArray;$e++) {
		my $adapterElement = $adapterElemArray[$e];
		next if (!defined $adapterElement);
		$status = $1	if (!defined $status and $adapterElement =~ m/Status[^\>]*\>([^\<]+)/);
		$serial = $1	if (!defined $serial and $adapterElement =~ m/SerialNumber[^\>]*\>([^\<]+)/);
		$name = $1	if (!defined $name and $adapterElement =~ m/Name[^\>]*\>([^\<]+)/);
		$size = $1	if (!defined $size and $adapterElement =~ m/MemorySize[^\>]*\>([\d]+)/);
		$prot = $1	if (!defined $prot and $adapterElement =~ m/Protocol[^\>]*\>([^\<]+)/);
		$drvname = $1	if (!defined $drvname and $adapterElement =~ m/DriverName[^\>]*\>([^\<]+)/);
		$drvversion = $1 if (!defined $drvversion and $adapterElement =~ m/DriverVersion[^\>]*\>([^\<]+)/);
		last if (defined $size);
	    } # for
	    #
	    my $statusNr = iRMCReportRAID_ExitCode($status);
	    my $medium = undef;
	    $medium = "v" if ($verbose);
	    $medium = "l" if (!$medium and $notify and $statusNr and $statusNr < 3);
	    if ($medium) {
		addStatusTopic($medium,$status,"RAIDCtrl", $a);
		addSerialIDs($medium,$serial, undef);
		addKeyLongValue($medium,"Name", $name);
		addKeyMB($medium,"Cache", $size);
		addKeyLongValue($medium,"Protocol", $prot);
		addKeyValue($medium,"Driver", $drvname);
		addKeyLongValue($medium,"DriverVersion", $drvversion);
		addMessage($medium,"\n");
	    }

	} # for adapter
	# TODO --- hostname of the <System>
  } # iRMCReportRAIDCtrlTable
  sub iRMCReportRAIDPhysicalDeviceTable {
	my $notify = shift;
	my $verbose = shift;
	my $refadapter = shift;
	my @adapter = @$refadapter;
	my $printedHeader = 0;
	my %physicalDriveStreams = ();
	for (my $a=0;$a<=$#adapter;$a++) {
	    my $adapterStream = $adapter[$a];
	    my $ports = undef;
	    $ports = $1 if ($adapterStream =~ m/(\<Ports.*Ports\>)/);
	    next if (!$ports);
	    my @portArray = sxmlSplitObjectTag($ports);
	    my @driveArray = ();
	    for (my $p=0;$p<=$#portArray;$p++) {
		my $portStream = $portArray[$p];
		next if (!defined $portStream);
		my @portElemArray = sxmlSplitObjectTag($portStream);
		for (my $e=0;$e<=$#portElemArray;$e++) {
		    my $portElemStream = $portElemArray[$e];
		    if ($portElemStream =~ m/^\s*\<PhysicalDrive/) {
			push(@driveArray, $portElemStream);
		    } elsif ($portElemStream =~ m/^\s*\<Enclosure/) {
			my @enclosureElemArray = sxmlSplitObjectTag($portElemStream);
			next if ($#enclosureElemArray < 0);
			for (my $ence=0;$ence<=$#enclosureElemArray;$ence++) {
			    my $encElemStream = $enclosureElemArray[$ence];
			    if ($encElemStream =~ m/^\s*\<PhysicalDrive/) {
				push(@driveArray, $encElemStream);
			    }
			} # for
		    } 
		} # for
	    
	    } # for
	    $physicalDriveStreams{$a} = \@driveArray;
	} # for adapter
	addTableHeader("v","RAID Physical Device")	if ($verbose);
	for (my $a=0;$a<=$#adapter;$a++) {
	    my $refDriver = $physicalDriveStreams{$a};
	    my @driveArray = @$refDriver;
	    for (my $d=0;$d<=$#driveArray;$d++) {
		my $oneStream = $driveArray[$d];
		my $compstatus = undef;
		my $status = undef;
		my $name = undef;
		my $devnr = undef;
		my $portID = undef;
		my $encID = undef;
		my $slotnr = undef;
		my $size = undef;
		my $interface = undef;
		my $serial = undef;
		$devnr = $1		if ($oneStream =~ m/DeviceNumber=\"([^\"]+)/);
		$name = $1		if ($oneStream =~ m/Name=\"([^\"]+)/);
		$compstatus = $1	if ($oneStream =~ m/ComponentStatus=\"([^\"]+)/);
		$status = $1		if ($oneStream =~ m/\<Status[^\>]*\>([^\<]+)/);
		$portID = $1		if ($oneStream =~ m/\<PortNumber[^\>]*\>([^\<]+)/);
		$encID = $1		if ($oneStream =~ m/\<EnclosureNumber[^\>]*\>([^\<]+)/);
		$slotnr = $1		if ($oneStream =~ m/\<Slot[^\>]*\>([^\<]+)/);
		$size = $1		if ($oneStream =~ m/\<PhysicalSize[^\>]*\>([^\<]+)/);
		$interface = $1		if ($oneStream =~ m/\<Type[^\>]*\>([^\<]+)/);
		$serial = $1		if ($oneStream =~ m/\<SerialNumber[^\>]*\>([^\<]+)/);
		#
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $compstatus and $compstatus > 1);
		if ($medium) {
			addStatusTopic($medium,$status, "RAIDPhysicalDevice", "$a.$devnr");
			addName($medium,$name);
			addSerialIDs($medium,$serial);
			addKeyUnsignedIntValue($medium,"Slot",$slotnr) if (defined $slotnr);
			addKeyUnsignedIntValue($medium,"Ctrl",$a);
			addKeyMB($medium,"Capacity", $size);
			addKeyLongValue($medium,"Interface",$interface);
			addKeyUnsignedIntValue($medium,"EnclosureNr",$encID) if (defined $encID);
			addKeyUnsignedIntValue($medium,"PortNr",$portID) if (defined $portID);
			addMessage($medium,"\n");
		}
	    } # for
	} # for adapter
 } # iRMCReportRAIDPhysicalDeviceTable
  sub iRMCReportRAIDLogicalDriveTable {
	my $notify = shift;
	my $verbose = shift;
	my $maxadapterindex = shift;
	my $printedHeader = 0;
	for (my $a=0;$a<=$maxadapterindex;$a++) {
	    my $refadapter = $gHashiRMCAdapter{$a};
	    my @adapterElemArray = @$refadapter;
	    my @logicalDriveStream = ();
	    for (my $e=0;$e<=$#adapterElemArray;$e++) {
		push (@logicalDriveStream, $adapterElemArray[$e])
		    if ($adapterElemArray[$e] =~ m/^\s*\<LogicalDrive/);
	    } # for
	    if ($verbose and $#logicalDriveStream >= 0 and !$printedHeader) {
		addTableHeader("v","RAID Logical Drive");
		$printedHeader = 1;
	    }
	    for (my $l=0;$l<=$#logicalDriveStream;$l++) {
		my $oneStream = $logicalDriveStream[$l];
		next if (!defined $oneStream);
		my $status = undef;
		my $name = undef;
		my $size = undef;
		my $lsize = undef;
		my $level = undef;
		my $osdev = undef;
		$name = $1	if ($oneStream =~ m/Name=\"([^\"]+)/);
		$status = $1	if ($oneStream =~ m/Status[^\>]*\>([^\<]+)/);
		$size = $1	if ($oneStream =~ m/PhysicalSize[^\>]*\>([\d]+)/);
		$lsize = $1	if ($oneStream =~ m/LogicalSize[^\>]*\>([\d]+)/);
		$level = $1	if ($oneStream =~ m/RAIDLevel[^\>]*\>([^\<]+)/);
		$osdev = $1	if ($oneStream =~ m/OSDevice[^\>]*\>([^\<]+)/);
		#
		my $medium = undef;
		$medium = "v" if ($verbose);
		$medium = "l" if ($notify and $status and $status !~ m/Operation/);
		if ($medium) {
			addStatusTopic($medium,$status, "LogicalDrive", "$a.$l");
			addName($medium,$name);
			addKeyUnsignedIntValue($medium,"Ctrl",$a);
			addKeyLongValue($medium,"Level", $level);
			addKeyMB($medium,"LogicalSize", $lsize);
			addKeyMB($medium,"Capacity", $size);
			addKeyLongValue($medium,"OSDeviceName", $osdev);
			addMessage($medium,"\n");
		}
	    } # for
	} # for adapter
  } # iRMCReportRAIDLogicalDriveTable
  sub iRMCReportRAIDSensors {
	my $notify = shift;
	my $verbose = shift;
	my $refadapter = shift;
	my @adapter = @$refadapter;
	my %fanStreamArray = ();
	my %temperatureStreamArray = ();
	my %psuStreamArray = ();
	#### SPLIT
	for (my $a=0;$a<=$#adapter;$a++) {
	    my $adapterStream = $adapter[$a];
	    my $oneAdapter = $adapter[$a];
	    next if (!defined $oneAdapter);
	    my @adapterElemArray = sxmlSplitObjectTag($oneAdapter);
	    #### SPLIT
	    my $portsStream = undef;
	    for (my $e=0;$e<=$#adapterElemArray;$e++) {
		my $aelem = $adapterElemArray[$e];
		next if (!defined $aelem);
		$portsStream = $1 if ($aelem =~ m/(\<Ports.*Ports\>)/);
		last if (defined $portsStream);
	    } # for
	    next if (!defined $portsStream);
	    my @portArray = ();
	    @portArray = sxmlSplitObjectTag($portsStream);
	    next if ($#portArray < 0);
	    my %enclosureStream = ();
	    for (my $p=0;$p<=$#portArray;$p++) {
		my $onePort = $portArray[$p];
		next if (!$onePort);
		my @portElemArray = ();
		@portElemArray = sxmlSplitObjectTag($onePort);
		for (my $e=0;$e<=$#portElemArray;$e++) {
		    my $oneElem = $portElemArray[$e];
		    next if (!defined $oneElem);
		    $enclosureStream{"$a.$p"} = $oneElem if ($oneElem =~ m/^\s*\<Enclosure/);
		} # for
	    } # for
	    my %processorStream = ();
	    foreach my $key (keys %enclosureStream) {
		my $oneEnclosure = $enclosureStream{$key};
		next if (!defined $oneEnclosure);
		my @encElemArray = ();
		@encElemArray = sxmlSplitObjectTag($oneEnclosure);
		next if ($#encElemArray < 0);
		for (my $e=0;$e<=$#encElemArray;$e++) {
		    my $oneElem = $encElemArray[$e];
		    next if (!defined $oneElem);
		    $processorStream{"$key"} = $oneElem if ($oneElem =~ m/^\s*\<Processor/);
		} # for
	    } # foreach enclosure
	    foreach my $key (keys %processorStream) {
		my $oneProcessor = $processorStream{$key};
		next if (!defined $oneProcessor);
		my @elemArray = ();
		@elemArray = sxmlSplitObjectTag($oneProcessor);
		next if ($#elemArray < 0);
		my @fanArray = ();
		my @temperatureArray = ();
		my @psuArray = ();
		for (my $e=0;$e<=$#elemArray;$e++) {
		    my $oneElem = $elemArray[$e];
		    next if (!defined $oneElem);
		    push (@fanArray, $oneElem)	if ($oneElem =~ m/^\s*\<Fan/);
		    push (@temperatureArray, $oneElem) if ($oneElem =~ m/^\s*\<TemperatureSensor/);
		    push (@psuArray, $oneElem)	if ($oneElem =~ m/^\s*\<PowerSupply/);
		} # for
		$fanStreamArray{"$key"} = \@fanArray		if ($#fanArray >= 0);
		$temperatureStreamArray{"$key"} = \@temperatureArray if ($#temperatureArray >= 0);
		$psuStreamArray{"$key"} = \@psuArray		if ($#psuArray >= 0);
	    } # foreach processor
	} # for adapters
	#### EVAL
	my $printedHeader = 0;
	if ($notify or $verbose) {
	    foreach my $key (keys %fanStreamArray) {
		    
		    my $refArray = $fanStreamArray{$key};
		    next if (!defined $refArray);
		    my @fanArray = @$refArray;
		    next if (!defined $#fanArray < 0);
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Fan Sensors");
			$printedHeader = 1;
		    }
		    for (my $i=0;$i<=$#fanArray;$i++) {
			my $oneStream = $fanArray[$i];
			my $name = undef;
			my $status = undef;
			my $speed = undef;
			$name = $1		if ($oneStream =~ m/Name=\"([^\"]+)/);
			$status = $1	if ($oneStream =~ m/\<Status[^\>]*\>([^\<]+)/);
			$speed = $1		if ($oneStream =~ m/\<FanSpeed[^\>]*\>([^\<]+)/);
			my $statuscode = iRMCReportRAID_ExitCode($status);
			$statuscode = 3 if (!defined $statuscode);
			my $portID = $1	if ($key =~ m/\d+.(\d+)/);
			my $ctrlID = $1	if ($key =~ m/(\d+).\d+/);
			#
			my $medium = undef;
			$medium = "v" if ($verbose and ($statuscode != 3 or $main::verbose >= 3));
			$medium = "l" if ($notify and ($statuscode == 1 or $statuscode == 2));
			if ($medium) {
				addStatusTopic($medium,$status, "Fan", "$key.$i");
				addName($medium,$name);
				addKeyValue($medium,"SpeedLevel", $speed);
				addKeyIntValue($medium,"Ctrl", $ctrlID);
				addKeyIntValue($medium,"Port", $portID);
				addMessage($medium,"\n");
			}
		    } # for
	    } # foreach fan stream 
	}
	$printedHeader = 0;
	{ # always
	    foreach my $key (keys %temperatureStreamArray) {
		    my $refArray = $temperatureStreamArray{$key};
		    next if (!defined $refArray);
		    my @temperatureStreamArray = @$refArray;
		    next if (!defined $#temperatureStreamArray < 0);
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Temperature Sensors");
			$printedHeader = 1;
		    }
		    for (my $i=0;$i<=$#temperatureStreamArray;$i++) {
			my $oneStream = $temperatureStreamArray[$i];
			my $name = undef;
			my $status = undef;
			my $location = undef;
			my $current = undef; my $warn = undef; my $crit = undef;
			$name = $1		if ($oneStream =~ m/Name=\"([^\"]+)/);
			$status = $1	if ($oneStream =~ m/\<Status[^\>]*\>([^\<]+)/);
			$location = $1	if ($oneStream =~ m/\<Location[^\>]*\>([^\<]+)/);
			$current = $1	if ($oneStream =~ m/\<Temperature\>([^\<]+)/);
			$warn = $1	if ($oneStream =~ m/\<WarningTemperatureH[^\>]*\>([^\<]+)/);
			$crit = $1	if ($oneStream =~ m/\<CriticalTemperatureH[^\>]*\>([^\<]+)/);
			my $statuscode = iRMCReportRAID_ExitCode($status);
			$statuscode = 3 if (!defined $statuscode);
			my $portID = $1	if ($key =~ m/\d+.(\d+)/);
			my $ctrlID = $1	if ($key =~ m/(\d+).\d+/);
			#
			my $medium = undef;
			$medium = "v" if ($verbose and ($statuscode != 3 or $main::verbose >= 3));
			$medium = "l" if ($notify and ($statuscode == 1 or $statuscode == 2));
			if ($medium) {
				addStatusTopic($medium,$status, "Sensor", "$key.$i");
				addName($medium,$name);
				addCelsius($medium,$current, $warn, $crit);
				addKeyLongValue($medium,"Location",$location);
				addKeyIntValue($medium,"Ctrl", $ctrlID);
				addKeyIntValue($medium,"Port", $portID);
				addMessage($medium,"\n");
			}
			{ # performance
				$name =~ s/[\s\,\.\$\(\)]+/_/g;
				$name =~ s/_+/_/g;
				$name .= "_$key";
				addTemperatureToPerfdata($name, $current, $warn, $crit)
					    if (!$main::verboseTable);	    
			}
		    } # for
	    } # foreach temperature stream
	}
	$printedHeader = 0;
	if ($notify or $verbose) {
	    foreach my $key (keys %psuStreamArray) {
		    my $refArray = $psuStreamArray{$key};
		    next if (!defined $refArray);
		    my @psuArray = @$refArray;
		    next if (!defined $#psuArray < 0);
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Power Supplies");
			$printedHeader = 1;
		    }
		    for (my $i=0;$i<=$#psuArray;$i++) {
			my $oneStream = $psuArray[$i];
			my $name = undef;
			my $status = undef;
			$name = $1		if ($oneStream =~ m/Name=\"([^\"]+)/);
			$status = $1	if ($oneStream =~ m/\<Status[^\>]*\>([^\<]+)/);
			my $statuscode = iRMCReportRAID_ExitCode($status);
			$statuscode = 3 if (!defined $statuscode);
			my $portID = $1	if ($key =~ m/\d+.(\d+)/);
			my $ctrlID = $1	if ($key =~ m/(\d+).\d+/);
			#
			my $medium = undef;
			$medium = "v" if ($verbose and ($statuscode != 3 or $main::verbose >= 3));
			$medium = "l" if ($notify and ($statuscode == 1 or $statuscode == 2));
			if ($medium) {
				addStatusTopic($medium,$status, "PSU", "$key.$i");
				addName($medium,$name);
				addKeyIntValue($medium,"Ctrl", $ctrlID);
				addKeyIntValue($medium,"Port", $portID);
				addMessage($medium,"\n");
			}
		    } # for
	    } # foreach psu stream
	}
  } # iRMCReportRAIDSensors
  sub iRMCReportRAIDAdditional {
	my $notify = shift;
	my $verbose = shift;
	my $maxadapterindex = shift;
	# TODO ... RAID Additional and sort for "header prints"
	for (my $a=0;$a<=$maxadapterindex;$a++) {
	    my $refadapter = $gHashiRMCAdapter{$a};
	    my @adapterElemArray = @$refadapter;
	    #### SPLIT
		my @batteryStream = ();
		my $portsStream = undef;
		for (my $e=0;$e<=$#adapterElemArray;$e++) {
		    my $aelem = $adapterElemArray[$e];
		    next if (!defined $aelem);
		    push (@batteryStream, $aelem)
			if ($aelem =~ m/^\s*\<Battery/);
		    $portsStream = $1 if ($aelem =~ m/(\<Ports.*Ports\>)/);
		    last if (defined $portsStream);
		} # for
		my @portArray = ();
		@portArray = sxmlSplitObjectTag($portsStream);
		my %enclosureStream = ();
		for (my $p=0;$p<=$#portArray;$p++) {
		    my $onePort = $portArray[$p];
		    next if (!$onePort);
		    my @portElemArray = ();
		    @portElemArray = sxmlSplitObjectTag($onePort);
		    for (my $e=0;$e<=$#portElemArray;$e++) {
			my $oneElem = $portElemArray[$e];
			$enclosureStream{"$a.$p"} = $oneElem if ($oneElem =~ m/^\s*\<Enclosure/);
		    } # for
		} # for
	    #### EVAL
		my $printedHeader = 0;
		for (my $b=0;$b<=$#batteryStream;$b++) { # will be only one battery 
		    my $oneBattery = $batteryStream[$b];
		    next if (!defined $oneBattery);
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Battery");
			$printedHeader = 1;
		    }
		    my $name = undef;
		    my $status = undef;
		    my $nomVoltage = undef;
		    my $curVoltage = undef;
		    my $capacitance = undef;
		    my $temp = undef;
		    $name = $1		if ($oneBattery =~ m/\<Name[^\>]*\>([^\<]+)/);
		    $status = $1	if ($oneBattery =~ m/\<Status[^\>]*\>([^\<]+)/);
		    $nomVoltage = $1	if ($oneBattery =~ m/\<DesignVoltage[^\>]*\>([^\<]+)/);
		    $curVoltage = $1	if ($oneBattery =~ m/\<Voltage[^\>]*\>([^\<]+)/);
		    $capacitance = $1	if ($oneBattery =~ m/\<Capacitance[^\>]*\>([^\<]+)/);
		    $temp = $1		if ($oneBattery =~ m/\<Temperature[^\>]*\>([^\<]+)/);
		    my $statuscode = iRMCReportRAID_ExitCode($status);
		    #
		    my $medium = undef;
		    $medium = "v" if ($verbose);
		    $medium = "l" if ($notify and $statuscode > 1);
		    if ($medium) {
			    addStatusTopic($medium,$status, "RAIDBattery", "$a.$b");
			    addName($medium,$name);
			    addKeyVolt($medium,"Voltage",$curVoltage);
			    addKeyVolt($medium,"NominalVoltage",$nomVoltage);
			    addKeyPercent($medium,"Capacitance",$capacitance);
			    addCelsius($medium,$temp);
			    addKeyUnsignedIntValue($medium,"Ctrl",$a);
			    addMessage($medium,"\n");
		    }
		} # for
		$printedHeader = 0;
		for (my $p=0;$p<=$#portArray;$p++) {
		    my $onePort = $portArray[$p];
		    next if !defined $onePort;
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Port");
			$printedHeader = 1;
		    }
		    my $pnr = undef;
		    my $name = undef;
		    $pnr = $1	if ($onePort =~ m/Nr=\"([^\"]+)/);
		    $name = $1	if ($onePort =~ m/Name=\"([^\"]+)/);
		    my $medium = undef;
		    $medium = "v" if ($verbose);
		    if ($medium) {
			    addStatusTopic($medium,undef, "RAIDPort", "$a.$pnr");
			    addName($medium,$name);
			    addKeyUnsignedIntValue($medium,"Ctrl",$a);
			    addMessage($medium,"\n");
		    }
		} # for
		$printedHeader = 0;
		foreach my $key (keys %enclosureStream) {
		    my $oneEnclosure = $enclosureStream{$key};
		    next if (!defined $oneEnclosure);
		    if ($verbose and !$printedHeader) {
			addTableHeader("v","RAID Enclosure");
			$printedHeader = 1;
		    }
		    my $portID = undef;
		    my $encnr = undef;
		    my $status = undef;
		    my $name = undef;
		    $portID = $1	if ($key =~ m/\d+.(\d+)/);
		    $name = $1		if ($oneEnclosure =~ m/Name=\"([^\"]+)/);
		    $encnr = $1		if ($oneEnclosure =~ m/EnclosureNumber[^\>]*\>([^\<]+)/);
		    $status = $1	if ($oneEnclosure =~ m/Status[^\>]*\>([^\<]+)/);
		    my $statuscode = iRMCReportRAID_ExitCode($status);
		    #
		    my $medium = undef;
		    $medium = "v" if ($verbose);
		    $medium = "l" if ($notify and $statuscode > 1);
		    if ($medium) {
			    addStatusTopic($medium,$status, "RAIDEnclosure", $encnr);
			    addName($medium,$name);
			    addKeyUnsignedIntValue($medium,"PortNr",$portID) if (defined $portID);
			    addKeyUnsignedIntValue($medium,"Ctrl",$a);
			    addMessage($medium,"\n");
		    }
		} # foreach
	} # for adapters
  } # iRMCReportRAIDAdditional
  sub iRMCReportRAID {
	my $setExitCode = shift;
	my $notify = shift;
	my $verbose = shift;
	#
	my $stream = undef;
	my $tmpExitCode = 3;
	$stream = $iRMCFullReport;
	#
	if (!$stream) {
	    (my $out, my $outheader, my $errtext) = 
		    restCall("GET","/report.xml?Item=Software/ServerView/ServerViewRaid",undef);
	    $out =~ s/\s+/ /gm if ($out);
	    $stream = $out;
	}
	return undef if (!$stream);
	my $RAID = undef;
	$RAID = $1 if ($stream =~ m/(\<ServerViewRaid.*ServerViewRaid\>)/);
	return undef if (!$RAID);
	my $system = undef;
	$system = $1 if ($RAID =~ m/(\<System.*System\>)/);
	return undef if (!$system);
	iRMCReportRAIDStatus($system,$setExitCode,$notify,$verbose);
	$notify = 0;
	$notify = 1 if ($statusMassStorage and $statusMassStorage < 3);
	my @adapterArray = ();
	my @systemElemArray = sxmlSplitObjectTag($system);
	for (my $i=0;$i<=$#systemElemArray;$i++) {
	    my $onepart = $systemElemArray[$i];
	    next if (!$onepart);
	    push (@adapterArray,$onepart) if ($onepart =~ m/^\s*\<Adapter/);
	} # for
	if ($notify or $verbose) {
		my $componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidCtrl and $raidCtrl < 3);
		iRMCReportRAIDCtrlTable($componentNotify,$verbose,\@adapterArray);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidPDevice and $raidPDevice < 3);
		iRMCReportRAIDPhysicalDeviceTable($componentNotify,$verbose,\@adapterArray);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidLDrive and $raidLDrive < 3);
		iRMCReportRAIDLogicalDriveTable($componentNotify,$verbose,$#adapterArray);
		$componentNotify = 0;
		$componentNotify = 1 if ($notify and $raidPDevice and $raidPDevice < 3);
		if ($main::verbose >= 3 or $componentNotify) {
		    # Ports have no status
		    iRMCReportRAIDAdditional($componentNotify,$verbose,$#adapterArray);
		}
	}
	my $componentNotify = 0;
	$componentNotify = 1 if ($notify and $raidCtrl and $raidCtrl < 3);
	iRMCReportRAIDSensors($componentNotify,$verbose,\@adapterArray);
	    # There are performance checks for temperatures !
  } # iRMCReportRAID
#########################################################################
# iRMC REST
#########################################################################
  # provisoric ! This version does not support Status Monitoring
  sub iRMCRestConnectionTest { 
	$optRestHeaderLines = "Accept: application/json";
	my $save_optConnectTimeout = $optConnectTimeout;
	$optConnectTimeout  = 20 if (!defined $optConnectTimeout or $optConnectTimeout > 20);
	(my $out, my $outheader, my $errtext) = 
		restCall("GET","/sessionInformation",undef);
	#
	if ($out and $out =~ m/^\s*\{/) { # must be a JSON answer
	    $optServiceType = "iREST" if ($out and !$optServiceType);
	    addExitCode(0);
	}
	if ($out and $out =~ m/ServerView Remote Management/) {
	    addMessage("l","[ERROR] Detected iRMC - but no REST service available\n");
	    addExitCode(1); # prevent SCS test
	}
	if ($exitCode == 0 and $optChkIdentify) {
	    addMessage("m","- ") if (!$msg);
	    addKeyLongValue("m","REST-Service", "iRMC REST Service");
	}
	$optRestHeaderLines = undef;
	$optConnectTimeout = $save_optConnectTimeout;
  } # iRMCRestConnectionTest
  sub iRMCRedfishConnectionTest { 
	$optRestHeaderLines = "Accept: application/json";
	my $save_optConnectTimeout = $optConnectTimeout;
	$optConnectTimeout  = 20 if (!defined $optConnectTimeout or $optConnectTimeout > 20);
	$useRESTverbose = 1; # for 401 or 503 discovery
	(my $out, my $outheader, my $errtext) = 
		restCall("GET","/redfish",undef);
	#
	$useRESTverbose = 0;
	my $mustwait = 0;
	if ($out and $out =~ m/^\s*\{/) { # must be a JSON answer
	    $optServiceType = "iRed" if ($out and !$optServiceType);
	    addExitCode(0);
	} elsif ($outheader and $outheader =~ m/ 503 /) {
	    $optServiceType = "iRedWAIT" if ($out and !$optServiceType);
	    $mustwait = 1;
	    addExitCode(0);
	}
	if ($out and $out =~ m/ServerView Remote Management/) {
	    addMessage("l","[ERROR] Detected iRMC - but no REST service available\n");
	    addExitCode(1); # prevent SCS test
	}
	if ($exitCode == 0 and $optChkIdentify) {
	    addMessage("m","- ") if (!$msg);
	    addKeyLongValue("m","REST-Service", "iRMC Redfish Service") if (!$mustwait);
	    addKeyLongValue("m","REST-Service", "iRMC Redfish Service (Uninitialized)") if ($mustwait);
	}
	$optRestHeaderLines = undef;
	$optConnectTimeout = $save_optConnectTimeout;
  } # iRMCRedfishConnectionTest
#########################################################################
# ANY REST Provider 
#########################################################################
  sub getAllFanSensors {
	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allFanStatus and ($allFanStatus==1 or $allFanStatus==2));
	$searchNotifies = 1 if (!defined $allFanStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllFanSensors($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllFanSensors($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllFanSensors
  sub getAllTemperatureSensors {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allTempStatus and ($allTempStatus==1 or $allTempStatus==2));
	$searchNotifies = 1 if (!defined $allTempStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllTemperatureSensors($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllTemperatureSensors($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllTemperatureSensors
  sub getAllPowerSupplies {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusPower and ($statusPower==1 or $statusPower==2));
	$searchNotifies = 1 if (!defined $statusPower);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllPowerSupplies($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllPowerSupplies($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllPowerSupplies
  sub getAllPowerConsumption {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusPower and ($statusPower==1 or $statusPower==2));
	$searchNotifies = 1 if (!defined $statusPower);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllPowerConsumption($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllPowerConsumption($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllPowerConsumption
  sub getAllCPU {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allCPUStatus and ($allCPUStatus==1 or $allCPUStatus==2));
	$searchNotifies = 1 if (!defined $allCPUStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllCPU($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllCPU($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllCPU
  sub getAllVoltages {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allVoltageStatus and ($allVoltageStatus==1 or $allVoltageStatus==2));
	$searchNotifies = 1 if (!defined $allVoltageStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllVoltages($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllVoltages($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllVoltages
  sub getAllMemoryModules {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $allMemoryStatus and ($allMemoryStatus==1 or $allMemoryStatus==2));
	$searchNotifies = 1 if (!defined $allMemoryStatus);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllMemoryModules($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportAllMemoryModules($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getAllMemoryModules
  sub getAllDrvMonAdapter {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusDrvMonitor 
	    and ($statusDrvMonitor==1 or $statusDrvMonitor==2));
	$searchNotifies = 1 if (!defined $statusDrvMonitor);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllDrvMonAdapter($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
  } # getAllDrvMonAdapter
  sub getAllStorageAdapter {
 	my $setExitCode = shift;
	my $searchNotifies = 0;
	$searchNotifies = 1 if (defined $statusMassStorage 
	    and ($statusMassStorage==1 or $statusMassStorage==2));
	$searchNotifies = 1 if (!defined $statusMassStorage);
	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2);
	return agentAllStorageAdapter($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
=begin NOIRMCSTORAGE
	return iRMCReportAllStorageAdapter($setExitCode, $searchNotifies, $verbose) 
	    if ($optServiceType and $optServiceType =~ m/^R/i);
=end NOIRMCSTORAGE
=cut
  } # getAllStorageAdapter
  sub getOtherPowerAdapter {
	my $notify = 0;
	$notify = 1 if ($statusPower and $statusPower < 3);
	if ($otherPowerAdapters and   ($main::verbose >= 2 or $notify)) {
	    my %adapter = %$otherPowerAdapters;
	    addTableHeader("v","Other Power Components") if ($main::verbose >=2);
	    foreach my $key (keys %adapter) {
		    next if (!$key); # never reached point
		    my $localStateString = $adapter{$key};
		    my $localState = $otherPowerAdaptersExitCode->{$key};
		    my $medium = undef;
		    $medium = "v" if ($main::verbose >= 2 and ($localState != 3 or $main::verbose >= 3));
		    $medium = "l" if (!$medium and ($localState == 1 or $localState == 2));
		    if ($medium) {
			addStatusTopic($medium,$localStateString,"PowerComponent",'');
			addName($medium,$key);
			addMessage($medium,"\n");
		    }
	    } # loop
	} # Adapter
  } # getOtherPowerAdapter
  sub getOtherSystemBoardAdapter {
	my $notify = 0;
	$notify = 1 if ($statusSystemBoard and $statusSystemBoard < 3);
	if ($otherSystemBoardAdapters and   ($main::verbose >= 2 or $notify)) {
	    my %adapter = %$otherSystemBoardAdapters;
	    addTableHeader("v","Other System Board Components") if ($main::verbose >=2);
	    foreach my $key (keys %adapter) {
		    next if (!$key); # never reached point
		    my $localStateString = $adapter{$key};
		    my $localState = $otherSystemBoardAdaptersExitCode->{$key};
		    my $medium = undef;
		    $medium = "v" if ($main::verbose >= 2 and ($localState != 3 or $main::verbose >= 3));
		    $medium = "l" if (!$medium and ($localState == 1 or $localState == 2));
		    if ($medium) {
			addStatusTopic($medium,$localStateString,"SystemBoardComponent",'');
			addName($medium,$key);
			addMessage($medium,"\n");
		    }
	    } # loop
	} # Adapter
  } # getOtherSystemBoardAdapter
  sub getOtherStorageAdapter {
	my $notify = 0;
	$notify = 1 if ($statusMassStorage and $statusMassStorage < 3);
	if ($otherStorageAdapters and   ($main::verbose >= 2 or $notify)) {
	    my %adapter = %$otherStorageAdapters;
	    addTableHeader("v","Other Storage Components") if ($main::verbose >=2);
	    foreach my $key (keys %adapter) {
		    next if (!$key); # never reached point
		    my $localStateString = $adapter{$key};
		    my $localState = $otherStorageAdaptersExitCode->{$key};
		    my $medium = undef;
		    $medium = "v" if ($main::verbose >= 2 and ($localState != 3 or $main::verbose >= 3));
		    $medium = "l" if (!$medium and ($localState == 1 or $localState == 2));
		    if ($medium) {
			addStatusTopic($medium,$localStateString,"StorageComponent",'');
			addName($medium,$key);
			addMessage($medium,"\n");
		    }
	    } # loop
	} # Adapter
  } # getOtherStorageAdapter
 ####
  sub getEnvironment {
	return if (!defined $statusEnv and !$noSummaryStatus);
	my $setExitCode = 0;
	# FanSensors
	#	if chkenv-fans is entered and it is "iRMC Report" than the exitcode
	#	nust be calculated to get All-Fans-Status !!!
	#
	#	Enter into details only if system ,env or env-fan is selected AND the status of
	#	All-Fans is not-ok !
	if ($optChkEnvironment or $optChkEnv_Fan) {
		my $getInfos = 0;
		$setExitCode = 0;
		if (!defined $allFanStatus) { # iRMC Report
			$setExitCode = 1 if ($optChkEnv_Fan and !$optChkEnvironment);
			$setExitCode = 1 if ($noSummaryStatus);
			$getInfos = 1 if ($optChkEnv_Fan and !$optChkEnvironment); 
			$getInfos = 1 if (!defined $statusEnv or $statusEnv==1 or $statusEnv==2);
		}
		$getInfos = 1 if (defined $allFanStatus and ($allFanStatus==1 or $allFanStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		$getInfos = 1 if (!$optChkEnvironment and $optChkEnv_Fan and $optChkFanPerformance);
		getAllFanSensors($setExitCode) if ($getInfos);
		if (defined $allFanStatus and $setExitCode and $noSummaryStatus) {
		    $statusEnv  = 3 if (!defined $statusEnv);
		    $statusEnv = addTmpExitCode($allFanStatus,$statusEnv);
		    addExitCode($allFanStatus);
		} elsif (!$optChkEnvironment and $optChkEnv_Fan) {
		    addExitCode($allFanStatus);
		}
	}
	# TemperatureSensors
	#	if chkenv-temp is entered and it is "iRMC Report" than the exitcode
	#	nust be calculated to get All-Temp-Status !!!
	#
	#	Enter into details only if system ,env or env-temp is selected.
	#	This is independent on status since the performance values should be fetched everytime.
	if ($optChkEnvironment or $optChkEnv_Temp) {
		$setExitCode = 0;
		if (!defined $allTempStatus) { # 
			$setExitCode = 1 if ($optChkEnv_Temp and !$optChkEnvironment);
			$setExitCode = 1 if ($noSummaryStatus);
		}
		getAllTemperatureSensors($setExitCode);
		if (defined $allTempStatus and $setExitCode and $noSummaryStatus) {
		    $statusEnv  = 3 if (!defined $statusEnv);
		    $statusEnv = addTmpExitCode($allTempStatus,$statusEnv);
		    addExitCode($allTempStatus);
		} elsif (!$optChkEnvironment and $optChkEnv_Temp) {
		    addExitCode($allTempStatus);
		}
	}

	if ($optChkEnvironment and $noSummaryStatus and defined $statusEnv) {
		addComponentStatus("m", "Environment",$state[$statusEnv]);
	}
  } # getEnvironment
  sub getPower {
	return if (!$optChkPower);
	return if (!defined $statusPower and !$noSummaryStatus);
	# PowerSupplies
	#	if chkmemmod is entered and it is "iRMC Report" than the exitcode
	#	nust be calculated to get All-PSU-Status !!!
	#
	#	Enter into details only if the status of All-PSU is not-ok !
	{
		my $getInfos = 0;
		my $setExitCode = 0;
		$getInfos = 1 if (!defined $statusPower 
		    or $statusPower==1 or $statusPower==2);
		$getInfos = 1 if ($main::verbose >= 2);
		$setExitCode = 1 if (!defined $statusPower); #
		getAllPowerSupplies($setExitCode) if ($getInfos);
		if (defined $statusPower and $setExitCode and $noSummaryStatus) {
		    addExitCode($statusPower);
		}
	}
	# PowerConsumption
	#	always
	{
		my $setExitCode = 0;
		$setExitCode = 1 if (!defined $statusPower); # 
		getAllPowerConsumption($setExitCode);
	}
	if ($optChkPower and $noSummaryStatus and defined $statusPower) {
		addComponentStatus("m", "PowerSupplies",$state[$statusPower]);
	}
	# Other Power Adapters
	getOtherPowerAdapter();
  } # getPower
  sub getSystemBoard {
	return if (!defined $statusSystemBoard  and !$noSummaryStatus);
	# CPU
	#	if chkcpu is entered and it is "iRMC Report" than the exitcode
	#	nust be calculated to get All-CPU-Status !!!
	#
	#	Enter into details only if the status of All-CPU is not-ok !
	if ($optChkSystem or $optChkHardware or $optChkCPU) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allCPUStatus) { #
			$setExitCode = 1 if ($optChkCPU and !$optChkHardware and !$optChkSystem);
			$setExitCode = 1 if ($noSummaryStatus);
			$getInfos = 1 if ($optChkCPU and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allCPUStatus and ($allCPUStatus==1 or $allCPUStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllCPU($setExitCode) if ($getInfos);
		if (defined $allCPUStatus and $setExitCode and $noSummaryStatus) {
		    $statusSystemBoard  = 3 if (!defined $statusSystemBoard);
		    $statusSystemBoard = addTmpExitCode($allCPUStatus,$statusSystemBoard);
		    addExitCode($allCPUStatus);
		} elsif (!$optChkHardware and !$optChkSystem and $optChkCPU) {
		    addExitCode($allCPUStatus);
		}
	}
	# Voltage
	#	if chkvoltage is entered and it is "iRMC Report" than the exitcode
	#	nust be calculated to get All-Volt-Status !!!
	#
	#	Enter into details only if the status of All-Votl is not-ok !
	if ($optChkSystem or $optChkHardware or $optChkVoltage) {
		my $getInfos = 0;
		my $setExitCode = 0;
		if (!defined $allVoltageStatus) { # older ESXi, iRMC S4
			$setExitCode = 1 if ($optChkVoltage and !$optChkHardware and !$optChkSystem);
			$setExitCode = 1 if ($noSummaryStatus);
			$getInfos = 1 if ($optChkVoltage and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allVoltageStatus and ($allVoltageStatus==1 or $allVoltageStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllVoltages($setExitCode) if ($getInfos);
		if (defined $allVoltageStatus and $setExitCode and $noSummaryStatus) {
		    $statusSystemBoard  = 3 if (!defined $statusSystemBoard);
		    $statusSystemBoard = addTmpExitCode($allVoltageStatus,$statusSystemBoard);
		    addExitCode($allVoltageStatus);
		} elsif (!$optChkHardware and !$optChkSystem and $optChkVoltage) {
		    addExitCode($allVoltageStatus);
		}
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
			$setExitCode = 1 if ($noSummaryStatus);
			$getInfos = 1 if ($optChkMemMod and !$optChkHardware and !$optChkSystem); 
			$getInfos = 1 if (!defined $statusSystemBoard or $statusSystemBoard==1 or $statusSystemBoard==2);
		}
		$getInfos = 1 if (defined $allMemoryStatus and ($allMemoryStatus==1 or $allMemoryStatus==2));
		$getInfos = 1 if ($main::verbose >= 2);
		getAllMemoryModules($setExitCode) if ($getInfos);
		if (defined $allMemoryStatus and $setExitCode and $noSummaryStatus) {
		    $statusSystemBoard  = 3 if (!defined $statusSystemBoard);
		    $statusSystemBoard = addTmpExitCode($allMemoryStatus,$statusSystemBoard);
		    addExitCode($allMemoryStatus);
		} elsif (!$optChkHardware and !$optChkSystem and $optChkMemMod) {
		    addExitCode($allMemoryStatus);
		}
	}
	# Other SystemBoard Adapters ?
	getOtherSystemBoardAdapter() if ($optChkSystem or $optChkHardware);
	if ($optChkSystem and $noSummaryStatus and defined $statusSystemBoard) {
		addComponentStatus("m", "SystemBoard",$state[$statusSystemBoard]);
	}
  } # getSystemBoard
  sub getStorage {
	return if (!defined $statusMassStorage and !$noSummaryStatus);
	return if (!$optChkStorage);
	# Mass Storage Adapters ... RAID ?
	{
		my $getInfos = 0;
		my $setExitCode = 0;
		$getInfos = 1 if (!defined $statusMassStorage 
		    or $statusMassStorage==1 or $statusMassStorage==2);
		$getInfos = 1 if ($main::verbose >= 2);
		$setExitCode = 1 if (!defined $statusMassStorage); 
		getAllStorageAdapter($setExitCode) if ($getInfos);
		if (defined $statusMassStorage and $setExitCode and $noSummaryStatus) {
		    addExitCode($statusMassStorage);
		}
	}
	# Other Adapters
	getOtherStorageAdapter();
	#
	if ($optChkStorage and $noSummaryStatus and defined $statusMassStorage) {
	    if ($optServiceType and $optServiceType =~ m/^R/i 
	    and !defined $raidCtrl and !defined $raidLDrive and !defined $raidPDevice) 
	    {
		addComponentStatus("m", "MassStorage","MISSING"); # older FW
	    } else {
		addComponentStatus("m", "MassStorage",$state[$statusMassStorage]);
	    }
	}
  } # getStorage
  sub getDrvMonitor {
	return if (!defined $statusDrvMonitor and !$noSummaryStatus);
	return if (!$optChkDrvMonitor);
	getAllDrvMonAdapter();
  } # getDrvMonitor
  sub getUpdateStatus {
	return agentUpdateStatus() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
  } # getUpdateStatus
 ####
  sub connectionTest {
	my $checknext = 1;
	$exitCode = 3;
	iRMCReportConnectionTest() if (!$optServiceType or $optServiceType =~ m/^R/i);
	$checknext = 0 if ($exitCode == 1); # too old iRMC FW
	$exitCode = 2 if ($exitCode == 1);
	if ($checknext) {
	    $exitCode = 3 if ($exitCode != 0);
	    iRMCRestConnectionTest()	if (!$optServiceType or $optServiceType =~ m/^irest/i
		or ($optServiceType =~ m/report/i and $optChkIdentify and $main::verboseTable==100));
	    $checknext = 0 if ($exitCode == 1); # iRMC FW REST
	}
	if ($checknext) {
	    $exitCode = 3 if ($exitCode != 0);
	    iRMCRedfishConnectionTest()	if (!$optServiceType or $optServiceType =~ m/^ired/i
		or ($optServiceType =~ m/report/i and $optChkIdentify and $main::verboseTable==100));
	    $checknext = 0 if ($exitCode == 1); # iRMC FW REDFISH
	}
	if ($checknext) {
	    $exitCode = 3 if ($exitCode != 0);
		# check of 3172 after iRMC because of bad Remote Manager on 3172
	    agentConnectionTest()	if (!$optServiceType or $optServiceType =~ m/^A/i);
	}
	# reset longMessage if an additional REST type is added ....
	if (!$optServiceType) {
	    	addMessage("m","- ") if (!$msg);
		addMessage("m","[ERROR] Unable to detect REST Service");
		addExitCode(2);
	} else {
	    $longMessage = undef;
	}
  } # connectionTest
  sub getSerialID {
	$serverID = agentSerialID() if (!$optServiceType or $optServiceType =~ m/^A/i);
	$serverID = iRMCReportSerialID() if (!$optServiceType or $optServiceType =~ m/^R/i);
	if ($serverID and ($optChkSystem or $optChkHardware)) {
	    addMessage("m", "-"); # separator
	    addSerialIDs("m", $serverID, undef);
	    addMessage("m", " -"); # separator
	    addExitCode(0);
	}	
	addSerialIDs("n", $serverID, undef);
  } # getSerialID
  sub getOverallStatusValues {
	return agentOverallStatusValues()	if ($optServiceType and $optServiceType =~ m/^A/i);
	return iRMCReportOverallStatusValues()	if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getOverallStatusValues
  sub getComponentInformation {
	getEnvironment()	if ($optChkEnvironment or $optChkEnv_Fan or $optChkEnv_Temp);
	getPower()		if ($optChkPower);
	getSystemBoard()	if ($optChkSystem or $optChkHardware or $optChkCPU or $optChkVoltage or $optChkMemMod);
	getDrvMonitor()		if ($optChkDrvMonitor);
	getStorage()		if ($optChkStorage);
	getUpdateStatus()	if ($optChkUpdate);
  } # getComponentInformation
  sub getPerformanceInformation {
	return agentPerformanceInformation()	if ($optServiceType and $optServiceType =~ m/^A/i);
  } # getPerformanceInformation
  sub getSystemInventoryInfo {
	agentSystemInventoryInfo() if ($optServiceType and $optServiceType =~ m/^A/i);
	iRMCReportSystemInventoryInfo() if ($optServiceType and $optServiceType =~ m/^R/i);
  } # getSystemInventoryInfo
  sub getSystemNotifyInformation {
	agentSystemNotifyInformation() if (!$optServiceType or $optServiceType =~ m/^A/i);
	iRMCReportSystemNotifyInformation() if (!$optServiceType or $optServiceType =~ m/^R/i);
  } # getSystemNotifyInformation
  sub getAllCheckData {
	$useRESTverbose = 1;
	getSerialID(); # always
	return if ($exitCode == 2);
	$useRESTverbose = 0; # optimization
	$exitCode = 3;
	my $onlyPerformance = 0;
	$onlyPerformance = 1 if ($optChkCpuLoadPerformance or $optChkMemoryPerformance 
	         or $optChkFileSystemPerformance or $optChkNetworkPerformance);
	getSystemInventoryInfo() if (($main::verbose == 3 and $optChkSystem) 
	    or ($main::verbose == 3 and $optSystemInfo)
	    or $main::verboseTable==200 
	    or $optAgentInfo);	
	getOverallStatusValues() if (!$optSystemInfo and !$optAgentInfo and !$onlyPerformance);
	if ($optChkSystem and $exitCode and $exitCode != 3
	and !$allVoltageStatus 
	and !$allCPUStatus 
	and !$allMemoryStatus) 
	{
		$longMessage .= "- Hint: Please check the status on the system itself or via administrative url - \n";
	}
	getComponentInformation() if (!$optSystemInfo and !$optAgentInfo and !$onlyPerformance);
	getPerformanceInformation() if ($onlyPerformance);
	getSystemNotifyInformation() if (!$optAgentInfo 
	    and ($optSystemInfo or $exitCode > 0 or $main::verbose));
	$main::verbose = 1 if ($optSystemInfo and !$main::verbose);
	$notifyMessage = undef if ($optAgentInfo); 
	$exitCode = 0 if ($optAgentInfo and $longMessage and $longMessage =~ m/AgentInfo/); 
  } # getAllCheckData
#########################################################################
sub processData {
	$exitCode = 3;
	if ($optRestAction) {
	    restCall($optRestAction, $optRestUrlPath, $optRestData);
	    return;
	}
	connectionTest(); # includes --chkidentify
	return if ($exitCode != 0);
	if (!$optTimeout and $optServiceType and $optServiceType =~ m/R/) {
	    alarm(300);
	} elsif (!$optTimeout and $optServiceType and $optServiceType =~ m/A/) {
	    alarm(300);
	}
	getAllCheckData() if (!$optChkIdentify);
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
	if (defined $pRestHandle) { # this might need some time :-( !
	    close $pRestHandle;
	    undef $pRestHandle;
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


