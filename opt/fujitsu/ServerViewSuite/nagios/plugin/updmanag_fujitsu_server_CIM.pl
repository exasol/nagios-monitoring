#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2014, 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.20.01
# Date:		2015-11-17

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage;
#use Time::localtime 'ctime';
use Time::gmtime 'gmctime';
use utf8;

#------ This Script uses as default wbemcli -------#

#### EXTERN HELPER  ####################################

our $wsmanPerlBindingScript = "fujitsu_server_wsman.pl";
#   ... see option -UW

#### HELP ##############################################
# HIDDEN:
#	Split of startjob: --cleanupjob, --addjob=s,--listjob,--startjoblist
#	missing componentpath information in: --getjobcomponentlog
#	    
#
=head1 NAME

updmanag_fujitsu_server_CIM.pl - Update Manager Administration for server with installed ServerView CIM-Provider

=head1 SYNOPSIS

updmanag_fujitsu_server_CIM.pl 
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
    { 
        { [--status] | 
          {--updstatus | --updcheckstatus | --updjobstatus } 
        } |
        { --getconfig [-O|--outputdir=<dir>] |
          --setconfig=<file> |
          --setconfigarg --arguments=<keyvalue-list>
        } |
        { --startcheck |
          --getchecklog
        } |
        { --difflist [-O|--outputdir=<dir>] |
          --instlist [-O|--outputdir=<dir>] |
          --getreleasenotes | --getdiffreleasenotes | 
          --getonereleasenote=<comp>
        }
        { { --startjoball | --startjob=<file>]
            [--jobstarttime=<timestampinseconds>] 
          } |
          --getjoblogfile
          --canceljob
        }
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Update Manager Administration for Fujitsu server with installed ServerView CIM provider.

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






=item [--status] | {--updstatus | --updcheckstatus | --updjobstatus }

Get status values. "status" tries to get three values. This can be splitted with
the alternative options.

There are "Update summary status of the host", "Status of the Update check",
"Status of the Update job"

=item --getconfig [-O|--outputdir=<dir>]

Get Update configuration information. These will be printed with the exception of
the repository password. If outputdir is specified all information (including password)
will be printed in a key=value list.

File: <dir>/<host>_CFG.txt

=item --setconfig=<file>

Set Update configuration. <file> might be a copy of above mentioned getconfig 
file with modified (commented) lines.

=item --setconfigarg --arguments=<keyvalue-list>

For experts only: Set Update configuration specifying single configuration items. 

=item --startcheck

Start Update Check immediately. This returns hints on the asynchron check start.
Use --updcheckstatus to monitor the progress and result.

=item --getchecklog

Get update-check log file content: Format is specified by the Update Manager.

=item --difflist [-O|--outputdir=<dir>]

Fetch Update component difference list and print the first 10 ones of these and store
all of these in an output file in directory <dir> if specified.

File: <dir>/<host>_DIFF.txt

=item --instlist [-O|--outputdir=<dir>]

Fetch Update installed component list and print the first 10 ones of these and store
all of these in an output file in directory <dir> if specified.

File: <dir>/<host>_INST.txt

=item --getreleasenotes | --getdiffreleasenotes | --getonereleasenote=<comp>

Get Release notes of all components in the installed component list resp.
get release notes of components of the difference list (option --getdiffreleasenotes) resp.
get one release note for one component path.
ATTENTION: The format of release notes vary very much.

Format for multiple release notes: 
blocks for each component with one line for hint on a component name 
followed by line area <ReleaseNotes>...</ReleaseNotes>
with the relase note inbetween - \r is substituted in the release output.

=item --startjoball | --startjob=<file>] [--jobstarttime=<timestampinseconds>]

Start Update Job immediately or for the specified start time (seconds relative to 1970-01-01). 
This returns hints on the asynchron job start.
Use --updjobstatus to monitor the progress and result.

The input file <file> might be a modified difference output file to select the components
to be updated.

=item --getjoblogfile

Get XML update job logfile. Hint: In the path of the xml (see -updjobstatus data) is a XSL file
which can be used to view these kind of XML update job logfiles more comfortable.

-item --canceljob

Cancel update job. This returns OKand a cancel return code if the action could be started.







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

# CIM authentication
our $optUserName = undef; 
our $optPassword = undef; 
our $optCert = undef; 
our $optPrivKey = undef; 
our $optCacert = undef;

# CIM specific option
our $optTransportType = undef;
our $optTransportPrefix = '/wsman';
our $optChkClass = undef;
our $optClass = undef; 
our $optUseMode = undef;
our $optServiceMode = undef;	# E ESXi, L Linux, W Windows

# special sub options
our $optInputFile	= undef;

# init additional check options
our $optChkIdentify = undef;
our $optUpdate		= undef;    # ... default
our   $optUpdStatus	= undef;
our     $optUpdSysStatus	= undef;
our     $optUpdCheckStatus	= undef;
our	$optUpdJobStatus	= undef;
our   $optUpdGetConfig	= undef;
our   $optUpdSetConfig	= undef;
our     $optUpdSetConfigArg	= undef;
our     $optUpdRepUser		= undef;
our     $optUpdRepPassword	= undef;
our   $optStartUpdCheck	= undef;
our     $optGetUpdCheckLog	= undef;
our   $optUpdDiffList	= undef;
our   $optUpdInstList	= undef;
our	$optOutdir	= undef;
our   $optGetAllReleaseNotes	= undef;
our   $optGetDiffReleaseNotes	= undef;
our   $optGetOneReleaseNote	= undef;
our   $optStartUpdJobAll= undef;
our   $optStartUpdJob	= undef;
our     $optUpdJobStartTime = undef;
our	$optCleanupUpdJob   = undef;	# split of optStartUpdJob
our	$optUpdJobAdd	    = undef;	# split of optStartUpdJob
our	$optUpdJobList	    = undef;	# split of optStartUpdJob
our	$optStartUpdJobList = undef;	# split of optStartUpdJob
our   $optCancelUpdJob	= undef;
our   $optUpdJobLogFile = undef;
our   $optUpdJobComponentLog = undef;
our $optInvoke = undef;
our $optModify = undef;
our	$optKeys	= undef;
our	$optArguments	= undef;
our	$optMethod	= undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::scriptPath = undef;

#### GLOBAL DATA BESIDE OPTIONS
# global control definitions
our $skipInternalNamesForNotifies = 1;	    # suppress print of internal product or model names
our $PSConsumptionBTUH = 0;

# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

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

# CIM
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
our $is2014Profile = undef;

# CIM central ClassEnumerations to be used by multiple functions:
our @cimSvsComputerSystem = ();
our @cimSvsOperatingSystem = ();
our $cimOS = undef;
our $cimOSDescription = undef;
our @expectedOutParameter = ();
our $hasArrayParameter = undef;	# wbemcli requres special array syntax

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

  sub addKeyGB {
	my $container = shift;
	my $key = shift;
	my $gbytes = shift;
	my $tmp = '';
	$gbytes = undef if (defined $gbytes and $gbytes < 0);
	$tmp .= " $key=$gbytes" . "GB" if (defined $gbytes);
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

	   		"chkclass", 
	   		"chkidentify", 
			"invoke",
			"modify",
			  "method=s",
			  "keys=s",
			  "arguments=s",

	   		"upd",
			  "O|outputdir=s",
			  "getconfig",
			  "setconfig=s",
			  "setconfigarg",
			  "updrepuser=s",
			  "updreppassword=s",
			  "status",
			  "updstatus",
			  "updcheckstatus",
			  "updjobstatus",
			  "startcheck",
			  "getchecklog",
			  "difflist",
			  "instlist",
			  "getreleasenotes",
			  "getdiffreleasenotes",
			  "getonereleasenote=s",
			  "startjoball",
			  "startjob=s",
			  "canceljob",
			  "jobstarttime=i",
			  "getjoblogfile",
			  "getjobcomponentlog",
			  "cleanupjob",
			  "addjob=s",
			  "listjob",
			  "startjoblist",
			  

	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
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

	   		"chkidentify", 
	   		"chkclass", 
			"invoke",
			"modify",
			  "method=s",
			  "keys=s",
			  "arguments=s",

	   		"upd",
			  "O|outputdir=s",
			  "getconfig",
			  "setconfig=s",
			  "setconfigarg",
			  "updrepuser=s",
			  "updreppassword=s",
			  "status",
			  "updstatus",
			  "updcheckstatus",
			  "updjobstatus",
			  "startcheck",
			  "getchecklog",
			  "difflist",
			  "instlist",
			  "getreleasenotes",
			  "getdiffreleasenotes",
			  "getonereleasenote=s",
			  "startjoball",
			  "startjob=s",
			  "canceljob",
			  "jobstarttime=i",
			  "getjoblogfile",
			  "getjobcomponentlog",
			  "cleanupjob",
			  "addjob=s",
			  "listjob",
			  "startjoblist",

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

  sub setOptions { 	# script specific
	my $refOptions = shift;
	my %options =%$refOptions;
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="A";		$optAdminHost = $options{$k}		if (defined $options{$k});
	$k="vtab";	$main::verboseTable = $options{$k}	if (defined $options{$k});

	$k="upd";		$optUpdate	= $options{$k}		if (defined $options{$k});
	$k="addjob";		$optUpdJobAdd	= $options{$k}		if (defined $options{$k});
	$k="canceljob";		$optCancelUpdJob= $options{$k}		if (defined $options{$k});
	$k="cleanupjob";	$optCleanupUpdJob= $options{$k}		if (defined $options{$k});
	$k="difflist";		$optUpdDiffList	= $options{$k}		if (defined $options{$k});
	$k="getchecklog";	$optGetUpdCheckLog= $options{$k}	if (defined $options{$k});
	$k="getconfig";		$optUpdGetConfig= $options{$k}		if (defined $options{$k});
	$k="getdiffreleasenotes";	$optGetDiffReleaseNotes= $options{$k}	if (defined $options{$k});
	$k="getjobcomponentlog";	$optUpdJobComponentLog= $options{$k}		if (defined $options{$k});
	$k="getjoblogfile";	$optUpdJobLogFile= $options{$k}		if (defined $options{$k});
	$k="getonereleasenote";	$optGetOneReleaseNote= $options{$k}	if (defined $options{$k});
	$k="getreleasenotes";	$optGetAllReleaseNotes= $options{$k}	if (defined $options{$k});
	$k="instlist";		$optUpdInstList	= $options{$k}		if (defined $options{$k});
	$k="jobstarttime";	$optUpdJobStartTime = $options{$k}	if (defined $options{$k});
	$k="listjob";		$optUpdJobList	= $options{$k}		if (defined $options{$k});
	$k="O";			$optOutdir	= $options{$k}		if (defined $options{$k});
	$k="setconfig";		$optUpdSetConfig= $options{$k}		if (defined $options{$k});
	$k="setconfigarg";	$optUpdSetConfigArg= $options{$k}	if (defined $options{$k});
	$k="startcheck";	$optStartUpdCheck= $options{$k}		if (defined $options{$k});
	$k="startjob";		$optStartUpdJob= $options{$k}		if (defined $options{$k});
	$k="startjoball";	$optStartUpdJobAll= $options{$k}	if (defined $options{$k});
	$k="startjoblist";	$optStartUpdJobList= $options{$k}	if (defined $options{$k});
	$k="status";		$optUpdStatus= $options{$k}		if (defined $options{$k});
	$k="updrepuser";	$optUpdRepUser= $options{$k}		if (defined $options{$k});
	$k="updreppassword";	$optUpdRepPassword= $options{$k}	if (defined $options{$k});
	$k="updstatus";		$optUpdSysStatus= $options{$k}		if (defined $options{$k});
	$k="updcheckstatus";	$optUpdCheckStatus= $options{$k}	if (defined $options{$k});
	$k="updjobstatus";	$optUpdJobStatus= $options{$k}		if (defined $options{$k});

	$k="invoke";	$optInvoke	= $options{$k}		if (defined $options{$k});
	$k="keys";	$optKeys	= $options{$k}		if (defined $options{$k});
	$k="modify";	$optModify	= $options{$k}		if (defined $options{$k});
	$k="method";	$optMethod	= $options{$k}		if (defined $options{$k});
	$k="arguments";	$optArguments	= $options{$k}		if (defined $options{$k});

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
		$optChkClass = $options{$key}                 	if ($key eq "chkclass"	 	);	 
		$optChkIdentify = $options{$key}                if ($key eq "chkidentify" 	);	 
		
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		$optCert = $options{$key}             		if ($key eq "cert"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey" 		);
		$optCacert = $options{$key}             	if ($key eq "cacert"	 	);		
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
	pod2usage(
		-msg     => "\n" . "action argument --invoke requires argument -C <class> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optInvoke and !$optClass);
	pod2usage(
		-msg     => "\n" . "action argument --invoke requires argument --method <method> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optInvoke and !$optMethod);
	pod2usage(
		-msg     => "\n" . "action argument --modify requires argument --arguments <keyvaluelist> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optModify and !$optArguments);
	pod2usage(
		-msg     => "\n" . "action argument --setconfigarg requires argument --arguments <keyvaluelist> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optUpdSetConfigArg and !$optArguments);

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

	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}

	# Defaults ...
	if (!defined $optInvoke and !defined $optModify 
	and !defined $optChkIdentify and !defined $optChkClass) 
	{
	    $optUpdate = 999 if (!defined $optUpdate);
	    $optUpdStatus = 999 if (!defined $optUpdGetConfig 
		and !defined $optUpdSetConfig 	and !defined $optUpdSetConfigArg 
		and !defined $optUpdSysStatus	and !defined $optUpdCheckStatus
		and !defined $optUpdJobStatus	and !defined $optStartUpdCheck
		and !defined $optGetUpdCheckLog
		and !defined $optUpdDiffList	and !defined $optUpdInstList
		and !defined $optGetAllReleaseNotes
		and !defined $optGetDiffReleaseNotes
		and !defined $optGetOneReleaseNote
		and !defined $optStartUpdJobAll	and !defined $optStartUpdJob
		and !defined $optUpdJobAdd	and !defined $optUpdJobList
		and !defined $optCancelUpdJob	and !defined $optStartUpdJobList
		and !defined $optCleanupUpdJob
		and !defined $optUpdJobLogFile	and !defined $optUpdJobComponentLog
		and !$optUpdJobStartTime
		);
	}
	if ($optUpdStatus) {
	    $optUpdSysStatus	= 999;
	    $optUpdCheckStatus	= 999;
	    $optUpdJobStatus	= 999;
	}
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

  sub splitKeyValueOption {
	my $optionString = shift;
	my %keyValues = ();
	return %keyValues if (!$optionString);

	my $rest = $optionString;
	while ($rest) {
	    my $key = undef;
	    my $value = undef;
	    $key = $1 if ($rest =~ m/^([^=]+)=/);
	    $rest =~ s/^[^=]+=// if (defined $key);
	    $rest = undef if (!$key); # wrong syntax (TODO - warn user ???)
	    next if (!defined $rest); # ATTENTION In $rest might be the number 0 - a "defined" check is necessary
	    if ($rest =~ m/^[\"]/) {
		$value = $1 if ($rest =~ m/^\"([^\"]+)\"/);
		$rest =~ s/^\"[^\"]+\"// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\"\"/);
		    $rest =~ s/^\"\"// if (defined $value);
		}
	    }
	    elsif ($rest =~ m/^[\']/) {
		$value = $1 if ($rest =~ m/^\'([^\']+)\'/);
		$rest =~ s/^\'[^\']+\'// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\'\'/);
		    $rest =~ s/^\'\'// if (defined $value);
		}
	    }
	    else {
		$value = $1 if ($rest =~ m/^([^,]+)/);
		$rest =~ s/^[^,]+// if (defined $value);
		if (!defined $value and $rest =~ m/^,/) {
		    $value = '';
		}
	    }
	    $value='' if (!defined $value);

	    if (defined $key) {
		my $existValue = $keyValues{$key};
		if (!defined $existValue) {
		    $keyValues{$key}    = $value;
		} else {
		    $keyValues{$key}	= "$existValue ,, " . $value;
		}
	    }
	    $rest =~ s/^,// if ($rest);
	} # while
	if ($main::verbose >= 60) {
	    foreach my $key (keys %keyValues) {
		my $value = undef;
		$value = $keyValues{$key};
		$value = "" if (!defined $value);
		print "SPLIT - $key=$value\n";
	    }
	}
	return %keyValues;
  } #splitKeyValueOption

  sub stripArrayKeysOption {
	my $optionString = shift;
	my $outArguments = undef;
	return $outArguments if (!$optionString);

	my $rest = $optionString;
	my $formerKey = undef;
	my $hasArray = 0;
	while ($rest) {
	    my $key = undef;
	    my $value = undef;
	    $key = $1 if ($rest =~ m/^([^=]+)=/);
	    $rest =~ s/^[^=]+=// if (defined $key);
	    $rest = undef if (!$key); # wrong syntax (TODO - warn user ???)
	    next if (!defined $rest); # ATTENTION In $rest might be the number 0 - a "defined" check is necessary
	    if ($rest =~ m/^[\"]/) {
		$value = $1 if ($rest =~ m/^(\"[^\"]+\")/);
		$rest =~ s/^\"[^\"]+\"// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\"\"/);
		    $rest =~ s/^\"\"// if (defined $value);
		}
	    }
	    elsif ($rest =~ m/^[\']/) {
		$value = $1 if ($rest =~ m/^\'([^\']+)\'/);
		$rest =~ s/^\'[^\']+\'// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\'\'/);
		    $rest =~ s/^\'\'// if (defined $value);
		}
	    }
	    else {
		$value = $1 if ($rest =~ m/^([^,]+)/);
		$rest =~ s/^[^,]+// if (defined $value);
		if (!defined $value and $rest =~ m/^,/) {
		    $value = '';
		}
	    }
	    $value='' if (!defined $value);

	    if (defined $key) {
		$outArguments .= "," if ($outArguments);
		$hasArray = 1 if ($formerKey and $formerKey eq $key);
		$outArguments .= "$key=" if (!$formerKey or ($key ne $formerKey));
		$outArguments .= "$value";
		$formerKey = $key;
	    }
	    $rest =~ s/^,// if ($rest);
	} # while
	if ($main::verbose >= 60) {
		print "STRIPPED - $outArguments\n";
	}
	return wantarray ? ($hasArray, $outArguments) : $outArguments;
  } #stripArrayKeysOption

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
  sub readCommentedTxtFile {
	my $file = shift;
	return undef if (!$file);
	my $alldata = readDataFile($file);
	if (defined $alldata) {
	    $alldata =~ s/^\s*\#[^\n]*\n//gm; # remove all commented lines
	}
	return $alldata;
  } #readCommentedTxtFile
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

##### WBEM CIM HELPER ###################################################
  sub cimWbem_multiParamInOneLine {
	my $stream = shift;
	my $foundMulti = 0;
	my $count = 0;
	foreach my $outparam (@expectedOutParameter) {
	    if ($stream =~m/$outparam:/) {
		$count++;
	    }
	    $foundMulti = 1 if ($count > 1);
	    last if ($foundMulti);
	} # foreach
	return $foundMulti;
  } #cimWbem_multiParamInOneLine

  sub cimWbem_splitParamInOneLine {
	my $stream = shift;
	my $output = $stream;
	foreach my $outparam (@expectedOutParameter) {
	    if ($stream =~m/$outparam:/) {
		$stream =~ s/$outparam:/>$outparam:/;
		# the sign '>' should not be inside any XML element !
	    }
	} # foreach
	$output = undef;
	foreach my $outparam (@expectedOutParameter) {
	    if ($stream =~m/[>\s]*$outparam:/) {
		my $inbetween = $stream;
		$stream =~ s/>$outparam:[^>]*//;
		$inbetween =~ s/.*>$outparam://;
		$inbetween =~ s/>.*$//;
		$inbetween =~ s/^\s+//;
		$inbetween =~ s/\s+$//;
		$output .= "<$outparam>" . $inbetween . "</$outparam>\n";
	    }
	} # foreach
	return $output;
  } #cimWbem_splitParamInOneLine

##### WBEM CIM ACCESS ###################################################
#wbemcli ei -nl -t -noverify  'https://root:*****@172.17.167.139:5989/root/svs:SVS_PGYComputerSystem'

# TIP ... wbemcli ein -nl -t -noverify  'https://root:*****@10.172.130.2/root/interop:CIM_Namespace'

# -nl new line is required for the scan
our $wbemCall = "wbemcli ei -nl";
our $wbemInvokeCall = "wbemcli cm -nl";
our $wbemModifyCall = "wbemcli mi -nl";
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
		    addMessage("m", "ERROR - Couldn't connect to server");
		}
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

  sub cimWbemParams {
	my $class = shift;
	my $wbemCmdSelected = shift;

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
	#
	$cmd = $wbemCmdSelected;
	$debugCmd = $wbemCmdSelected;
	# -noverify versus -cacert
	if (!$optCacert) {
	    $cmd .= $wbemCert ;
	    $debugCmd .= $wbemCert ;
	} else {
	    $cmd .= " -cacert $optCacert";
	    $debugCmd .= " -cacert $optCacert";
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
	return ($host, $cmd, $debugCmd);
  }

  sub cimWbemEnumerateClass {
	my $class = shift;
	return undef if (!$class);
	my $oneXML = undef;
	my @listXML = ();
	my @list = ();

	my ($host, $cmd, $debugCmd) = cimWbemParams($class, $wbemCall); 

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

  sub cimWbemInvoke {
	# $ a.pl -SI -H 172.17.53.86 -I AUTH/ABG/IRMC0.txt -C SVS_iRMCBaseServer 
	# --invoke --meth StartFanTest --sele CreationClassName=\"SVS_iRMCBaseServer\",Name=\"S#1240064\" -v60
	my $class = shift;
	my $method = shift;
	return undef if (!$class or !$method);
	my $retCode = undef;
	my $stream = undef;

	my ($host, $cmd, $debugCmd) = cimWbemParams($class, $wbemInvokeCall); 

	# selector keys
	if ($optKeys) {
	    $debugCmd =~ s/\'$//;
	    $debugCmd .= "\.$optKeys\'";
	    $cmd =~ s/\'$//;
	    $cmd .= "\.$optKeys\'";
	}

	# arguments
	if ($hasArrayParameter) { # rearange for arrays
	    my $saveArg = $optArguments;
	    my $hasArray = 0;
	    ($hasArray, $optArguments) = stripArrayKeysOption($optArguments);
	    $optArguments = $saveArg if (!$hasArray);
	}
	#method & arg
	my $cmdRest = " $method";
	$cmdRest .= ".$optArguments" if ($optArguments);
	$debugCmd .= $cmdRest;
	$cmd .= $cmdRest;
	
	print "**** invoke Method $method of Class $class\n" if ($main::verbose > 20); 
	print "cmd = `  $debugCmd `\n" if ($main::verbose >= 10);

	my $errCmd = $cmd;
	$cmd = $cmd . " 2>/dev/null"; 
		# There is a problem to catch stderr - 2>&1 does not work in open()
	
	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	print "**** read data ...\n" if ($main::verbose > 20); 
	my $currentOutParam = undef;
	while (<$pHandle>) {
		my $tmpStream = $_;
		print if ($main::verbose >= 60); # $_
		if (!defined $retCode and $tmpStream =~ m/^$host/) {
		    $retCode = $1 if ($tmpStream =~ m/($method.*)/);
		    $retCode =~ s/$method:\s+// if (defined $retCode);
		} elsif ($tmpStream =~ m/^[^\s]+ \(.*\):/) {
		    foreach my $outparam (@expectedOutParameter) {
			if ($tmpStream =~m/^$outparam \(.*\):/) {
			    $stream .= "</$currentOutParam>" 
				if ($currentOutParam);
			    $tmpStream =~ s/^$outparam \(.*\): //;
			    $tmpStream =~ s/^\s+//;
			    $tmpStream = "<$outparam>" . $tmpStream;
			    $currentOutParam = $outparam;
			}
		    } # foreach
		    $stream .= $tmpStream;
		} elsif ($tmpStream =~ m/^[^\s]+:/) {
		    my $foundThis = 0;
		    foreach my $outparam (@expectedOutParameter) {
			if ($tmpStream =~m/^$outparam:/) {
			    # ... check wbemcli newline error
			    my $multiParamInOneLine = cimWbem_multiParamInOneLine($tmpStream);
			    if ($multiParamInOneLine) {
				print "**** ... discovered wbemcli newline error\n"  if ($main::verbose >= 20);
				$tmpStream = cimWbem_splitParamInOneLine($tmpStream);
				$foundThis = 1;
				last;
			    } else {
				$stream .= "</$currentOutParam>" 
				    if ($currentOutParam);
				$tmpStream =~ s/^$outparam://;
				$tmpStream =~ s/^\s+//;
				$tmpStream = "<$outparam>" . $tmpStream;
				$currentOutParam = $outparam;
				$foundThis = 1;
			    }
			}
		    } # foreach
		    $stream .= $tmpStream;
		} else {
		    $stream .= $tmpStream;
		}
	} # while input
	$stream =~ s/\s+$// if ($stream);
	$stream .= "</$currentOutParam>" if ($currentOutParam);
	if (($main::verbose > 10 and $main::verbose < 60) or ! defined $retCode) { ###### ERROR CASE
	    print "**** second call to get stderr ...\n" if ($main::verbose > 20); 
	    my $allStderr = `$errCmd 2>&1`;
	    addMessage("n", $allStderr) if (!defined $notifyMessage or $notifyMessage =~ m/^\s*$/);
	    print "$allStderr\n" if ($main::verbose > 10); 
	}
	if ($optInvoke and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "- ");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	    addMessage("l", $stream);
	    addMessage("l", "\n");
	}
	if ($stream and $stream =~ m/&\#\d+;/) {
	    print "**** change &#..; into signs\n" if ($main::verbose >= 20);
	    $stream =~ s/&\#9;/\t/gm;
	    $stream =~ s/&\#10;/\n/gm;
	    $stream =~ s/&\#32;/ /gm;

	    $stream =~ s/&\#13;//gm;
	}
	print "**** close pipe ...\n" if ($main::verbose >= 20); 
	close $pHandle;

	$stream = $retCode if (!defined $stream);
	$stream = undef if ($stream and $stream =~ m/^\s*$/);
	return wantarray ? ($retCode, $stream) : $stream;
  } # cimWbemInvoke

  sub cimWbemModify {
	# $ u.pl -I AUTH/ABG/LXSWp.txt -H 172.17.51.2 -SL --modify -CSVS_PGYUpdateConfigSettings --arg UpdDownloadProtocol=0 \
	# --sel InstanceID=SVS:SVS_PGYUpdateConfigSettings -v60
	my $class = shift;
	return undef if (!$class);
	#my $oneXML = undef;
	#my @listXML = ();
	#my @list = ();
	my $retCode = undef;

	my ($host, $cmd, $debugCmd) = cimWbemParams($class, $wbemModifyCall); 

	# selector keys
	if ($optKeys) {
	    $debugCmd =~ s/\'$//;
	    $debugCmd .= "\.$optKeys\'";
	    $cmd =~ s/\'$//;
	    $cmd .= "\.$optKeys\'";
	}

	# arguments
	my $cmdRest = "";
	$cmdRest .= " $optArguments" if ($optArguments);
	$debugCmd .= $cmdRest;
	$cmd .= $cmdRest;
	
	print "**** modify instance for Class $class\n" if ($main::verbose > 20); 
	print "cmd = `  $debugCmd `\n" if ($main::verbose >= 10);

	my $errCmd = $cmd;
	$cmd = $cmd . " 2>/dev/null"; 
		# There is a problem to catch stderr - 2>&1 does not work in open()
	
	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	print "**** read data ...\n" if ($main::verbose > 20); 
	$retCode = 0;
	while (<$pHandle>) {
		my $tmpStream = $_;
		$retCode = 3 if ($tmpStream !~ m/\s+/);
		print if ($main::verbose >= 60); # $_
	}
	if ($retCode == 3) { ###### ERROR CASE
	    my $allStderr = `$errCmd 2>&1`;
	    addMessage("n", $allStderr);
	    print "$allStderr\n" if ($main::verbose > 10); 
	}
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	$exitCode = 0 if (!$retCode and $optModify);
	return $retCode;
  } # cimWbemModify

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
	$cmd .= " -v60" if ($main::verbose and $main::verbose == 60);
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
		addMessage("m","- $err") if ($err);
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

  our $globalGetEmptyFields = undef;
  sub cimWsmanEnumerateClass {
	my $class = shift;
	return undef if (!$class);
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
	$cmd .= " -v1" if ($globalGetEmptyFields);
	$cmd .= " -v60" if ($main::verbose and $main::verbose == 60);
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

  sub cimWsmanInvoke {
	my $class = shift;
	my $method = shift;
	return undef if (!$class or !$method);

	#my $oneXML = undef;
	#my @listXML = ();
	#my @list = ();
	my $outstream = undef;

	my $script = $main::scriptPath . $wsmanPerlBindingScript;
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	my $cmd = $script . " --invoke -C$class --method $method -H$host -U $optUseMode";
	my $cmdPrint = undef;

	$cmd .= " -P $optPort";
	$cmd .= " -T $optTransportType" if ($optTransportType);
	$cmd .= " -S $optServiceMode" if ($optServiceMode);
	$cmd .= " -v60" if ($main::verbose and $main::verbose == 60);
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
	# selector keys
	if ($optKeys) {
	    if ($optKeys =~ m/\'/) {
		$cmd		.= " --keys \"$optKeys\"";
		$cmdPrint	.= " --keys \"$optKeys\"";
	    } elsif ($optKeys =~ m/\"/) {
		$cmd		.= " --keys '$optKeys'";
		$cmdPrint	.= " --keys '$optKeys'";
	    } else {
		$cmd		.= " --keys $optKeys";
		$cmdPrint	.= " --keys $optKeys";
	    }
	}
	# arguments
	if ($optArguments) {
	    if ($optArguments =~ m/\'/) {
		$cmd		.= " --arguments \"$optArguments\"";
		$cmdPrint	.= " --arguments \"$optArguments\"";
	    } elsif ($optArguments =~ m/\"/) {
		$cmd		.= " --arguments '$optArguments'";
		$cmdPrint	.= " --arguments '$optArguments'";
	    } else {
		$cmd		.= " --arguments $optArguments";
		$cmdPrint	.= " --arguments $optArguments";
	    }
	}
	print "**** ScriptCall = $cmdPrint\n" if ($main::verbose >= 10);

	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	
	print "**** read data ...\n" if ($main::verbose > 20); 
	my $foundClass = 0;
	my $retCode = undef;
	while (<$pHandle>) {
		my $tmpStream = $_;
		$tmpStream = '' if ($tmpStream =~ m/^OriginClass/); # verbose
		if (defined $retCode) { # any text after first ReturnCode line
		    $outstream .= $tmpStream;
		}
		$retCode = $1 if (!$retCode and $tmpStream =~ m/ReturnCode=(\d+)/);
		print if ($main::verbose >= 60); # $_
	}
	if ($optInvoke and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "- ");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	    addMessage("l", $outstream) if ($outstream);
	}
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	$outstream = undef if ($outstream and $outstream =~ m/^\s*$/);
	$outstream = $retCode if (!defined $outstream);
	return wantarray ? ($retCode, $outstream) : $outstream;
  } # cimWsmanInvoke

  sub cimWsmanModify {
	my $class = shift;
	return undef if (!$class);

	#my $oneXML = undef;
	#my @listXML = ();
	#my @list = ();
	my $outstream = undef;

	my $script = $main::scriptPath . $wsmanPerlBindingScript;
	my $host = $optHost;
	$host = $optAdminHost if ($optAdminHost);
	my $cmd = $script . " --modify -C$class -H$host -U $optUseMode";
	my $cmdPrint = undef;

	$cmd .= " -P $optPort";
	$cmd .= " -T $optTransportType" if ($optTransportType);
	$cmd .= " -S $optServiceMode" if ($optServiceMode);
	$cmd .= " -v60" if ($main::verbose and $main::verbose == 60);
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
	# selector keys
	if ($optKeys) {
	    if ($optKeys =~ m/\'/) {
		$cmd		.= " --keys \"$optKeys\"";
		$cmdPrint	.= " --keys \"$optKeys\"";
	    } elsif ($optKeys =~ m/\"/) {
		$cmd		.= " --keys '$optKeys'";
		$cmdPrint	.= " --keys '$optKeys'";
	    } else {
		$cmd		.= " --keys $optKeys";
		$cmdPrint	.= " --keys $optKeys";
	    }
	}
	# arguments
	if ($optArguments) {
	    if ($optArguments =~ m/\'/) {
		$cmd		.= " --arguments \"$optArguments\"";
		$cmdPrint	.= " --arguments \"$optArguments\"";
	    } elsif ($optArguments =~ m/\"/) {
		$cmd		.= " --arguments '$optArguments'";
		$cmdPrint	.= " --arguments '$optArguments'";
	    } else {
		$cmd		.= " --arguments $optArguments";
		$cmdPrint	.= " --arguments $optArguments";
	    }
	}
	print "**** ScriptCall = $cmdPrint\n" if ($main::verbose >= 10);

	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	
	print "**** read data ...\n" if ($main::verbose > 20); 
	my $foundClass = 0;
	my $retCode = undef;
	while (<$pHandle>) {
		my $tmpStream = $_;
		if (defined $retCode) { # any text after first ReturnCode line
		    $outstream .= $tmpStream;
		}
		$retCode = $1 if (!$retCode and $tmpStream =~ m/ReturnCode=(\d+)/);
		print if ($main::verbose >= 60); # $_
	}
	if ($optModify and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "- ");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	}
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	#return $outstream;
	$outstream = $retCode if (!defined $outstream);
	$outstream = undef if ($outstream and $outstream =~ m/^\s*$/);
	return wantarray ? ($retCode, $outstream) : $outstream;
  } # cimWsmanModify

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

  sub cimInvoke {
	my $class = shift;
	my $method = shift;
	return cimWbemInvoke($class, $method) if ($optUseMode =~ m/^C/);
	return cimWsmanInvoke($class, $method) if ($optUseMode =~ m/^W/);
  } #cimInvoke

  sub cimModify {
	my $class = shift;
	return cimWbemModify($class) if ($optUseMode =~ m/^C/);
	return cimWsmanModify($class) if ($optUseMode =~ m/^W/);
  } #

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
#########################################################################
# UPDATE HELPERS							#
#########################################################################
  sub getUpdateService_SystemNameKey {
	my $systemName = undef;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYSoftwareUpdateService");
	cimPrintClass(\@classInstances, "SVS_PGYSoftwareUpdateService");
	if ($#classInstances < 0) {
	    return undef;
	}
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		$systemName = $oneClass{"SystemName"}; 
	} #foreach instance (should be only one)
	return $systemName;
  } #getUpdateService_SystemNameKey
  sub storeUpdateService_Keys {
	# keys CIM_Service: SystemCreationClassName, SystemName, CreationClassName, Name
	$optKeys = undef;
	my $systemName = undef;
	$systemName = getUpdateService_SystemNameKey();
	if (!defined $systemName) {
	    return 3;
	}
	$optKeys = "SystemCreationClassName=SVS_PGYComputerSystem";
	$optKeys .= ",SystemName=$systemName";
	$optKeys .= ",CreationClassName=SVS_PGYSoftwareUpdateService";
	$optKeys .= ",Name=SVS:UpdateService";
	return 0;
  } #storeUpdateService_Keys
  sub getUpdService_JobStartTime {
	storeUpdateService_Keys();
	return undef if (!$optKeys);
	# SVS_PGYSoftwareUpdateService.GetJobStartTime
	# OUT: StartTime (time_t)
	$optArguments = undef;
	@expectedOutParameter = ();
	push (@expectedOutParameter, "StartTime");
	my $response = cimInvoke("SVS_PGYSoftwareUpdateService", "GetJobStartTime");
	$response =~ s/^<StartTime>// if ($response);
	$response =~ s!</StartTime>!! if ($response);
	return $response;
  } #getUpdService_JobStartTime

#########################################################################
# UPDATE								#
#########################################################################
  sub getUpdateSystemStatus {
	#return if ($isiRMC);
	if ($#cimSvsComputerSystem < 0) {
	    @cimSvsComputerSystem = cimEnumerateClass("SVS_PGYComputerSystem");
	    if (!@cimSvsComputerSystem) {
		    return 4;
	    }
	    cimPrintClass(\@cimSvsComputerSystem, "SVS_PGYComputerSystem");
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
	    addComponentStatus("m", "UpdateStatus",$state[$tmpExitCode])
		if ($optUpdSysStatus);
	}
	addExitCode($tmpExitCode) if ($optUpdSysStatus or $optUpdDiffList or $optUpdInstList);
	return $tmpExitCode;
  } #getUpdateSystemStatus
  sub getUpdateCheckStatus {
	my $sysstatus = shift;
	my $rc = -1;
	if ($sysstatus and $sysstatus == 4) {
	    addMessage("m", "Unable to get ServerView CIM Classes\n")
		if ($optUpdCheckStatus == 1);
	    return -1;
	}
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYCheckData");
	cimPrintClass(\@classInstances, "SVS_PGYCheckData");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "UpdateCheckStatus","UNAVAILABLE")
		if ($optUpdCheckStatus);
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal at the beginning
	    return -1;
	}
	my @statusText = ("Done - OK", "Done - Error", "Downloading", "Checking",);
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $status = $oneClass{"UpdateCheckStatus"}; 
		my $lastcheck = $oneClass{"LastCheckTime"}; 
		my $lastcode = $oneClass{"UpdateCheckErrorCode"}; 
		$rc = $status if (defined $status and $status >= 0 and $status <= 3);
		addComponentStatus("m", "UpdateCheckStatus",$statusText[$rc])
		    if ($optUpdCheckStatus and $rc >= 0);
		if ($optUpdStatus or $optUpdCheckStatus) {
		    addStatusTopic("l","Update Check");
		    addKeyLongValue("l", "LastCheckTime", gmctime($lastcheck)) if ($lastcheck  and $lastcheck > 0);
		    addKeyValue("l", "UpdateCheckErrorCode", $lastcode); # ignore 0
		    addMessage("l","\n");
		    addExitCode(0) if ($optUpdCheckStatus and $optUpdCheckStatus==1 and $rc == 0);
		    addExitCode(1) if ($optUpdCheckStatus and $optUpdCheckStatus==1  and $rc == 1);
		}
	} #foreach instance (should be only one)
	return $rc;
  } #getUpdateCheckStatus
  sub getUpdateJobStatus {
	my $sysstatus = shift;
	my $rc = -1;
	if ($sysstatus and $sysstatus == 4) {
	    addMessage("m", "Unable to get ServerView CIM Classes\n")
		if ($optUpdJobStatus==1);
	    return -1;
	}
	my $topicPrinted = 0;
	{
	    my $save_notifyMessage = $notifyMessage;
	    my $jobtime = getUpdService_JobStartTime();
	    $jobtime =~ s/\s+$// if ($jobtime);
	    if ($jobtime and $jobtime !~ m/^[\s0]*$/) {
		addStatusTopic("l","Update Job");
		addKeyLongValue("l", "UpdateJobStartTime", gmctime($jobtime));
		addMessage("l","\n");
		$topicPrinted = 1;
	    }
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	}
	#
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYUpdateJob");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateJob");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "UpdateJobStatus","UNAVAILABLE")
		if ($optUpdJobStatus);
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	    return -1;
	}
	my @statusText = ("Waiting", 
	    "Downloading", "Downloaded", "Updating", "Updated", "Done - OK", 
	    "Done - Error",
	);
	foreach my $refClass (@classInstances) {
		next if (!$refClass);
		my %oneClass = %{$refClass};
		my $statusString = $oneClass{"JobStatus"}; 
		my $starttime = $oneClass{"ScheduledStartTime"}; 
		    # This is a GMTIME string !
		my $logfile = $oneClass{"LogFileName"}; 
		my $status = undef;
		for (my $i=0;$i <=6 and !defined $status;$i++) {
		    $status = $i if ($statusString eq $statusText[$i]);
		}
		$rc = $status if (defined $status and $status >= 0 and $status <= 6);
		addComponentStatus("m", "UpdateJobStatus",$statusString)
		    if ($optUpdJobStatus and $rc >= 0);
		if ($optUpdStatus or $optUpdJobStatus) {
		    #addKeyValue("l", "UpdateStartTime", $starttime);
		    addStatusTopic("l","Update Job") if (!$topicPrinted); #unexpected
		    addKeyLongValue("l", "LogFile", $logfile);
		    addMessage("l","\n");
		    addExitCode(0) if ($optUpdJobStatus and $optUpdJobStatus==1 and $rc == 5);
		    addExitCode(1) if ($optUpdJobStatus and $optUpdJobStatus==1 and $rc == 6);
		}
	} #foreach instance (should be only one)
	# SVS_PGYUpdateJob
	#   LogFileName
	#   PercentComplete 0,50,100
	return $rc;
  } #getUpdateJobStatus
  sub getUpdateStatus {
	my $sysstatus = 4;
	$sysstatus = getUpdateSystemStatus();
	getUpdateCheckStatus($sysstatus) if ($optUpdCheckStatus);
	getUpdateJobStatus($sysstatus) if ($optUpdJobStatus);
	return $sysstatus;
  } #getUpdateStatus

  sub getUpdateConfigSettings {
	my @classInstances = ();
	$globalGetEmptyFields = 1;
	@classInstances = cimEnumerateClass("SVS_PGYUpdateConfigSettings");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateConfigSettings");

	my @serverClassInstances = ();
	@serverClassInstances = cimEnumerateClass("SVS_PGYServerConfigSettings");
	cimPrintClass(\@serverClassInstances, "SVS_PGYServerConfigSettings");

	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;

	if ($#classInstances < 0) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}
	$exitCode = 0;
	addMessage("m", "Update Config Settings available");
	my $save_variableVerboseMessage = $variableVerboseMessage;
	$variableVerboseMessage = '';
	if ($optOutdir) {
	    addMessage("v","#\tUpdAlertJobFinished (uint16) - (0=disable,1=enable)\n");
	    addMessage("v","#\tUpdAlertNewUpdates (uint16) - (0=disable,1=enable)\n");
	    addMessage("v","#\tUpdAutomaticInstall (boolean)\n");
	    addMessage("v","#\tUpdDeleteBinaryAfterUpdate (boolean)\n");
	    addMessage("v","#\tUpdDownloadMode (uint16) - (0=no,1=aftercheck)\n");
	    addMessage("v","#\tUpdDownloadProtocol (uint16) - (0=http,1=https)\n");
	    addMessage("v","#\tUpdDownloadRepositoryPath (string)\n");
	    addMessage("v","#\t    (Default=DownloadManager/Globalflash)\n");
	    addMessage("v","#\tUpdDownloadServerAddress (string)\n");
	    addMessage("v","#\t    (Default=support.ts.fujitsu.com)\n");
	    addMessage("v","#\tUpdRepositoryAccess (uint16) - (0=local_RO,1=local_RW,2=remote_RO,3=iRMC_RO)\n");
	    addMessage("v","#\t    (Default=1)\n");
	    addMessage("v","#\tUpdRepositoryPassword (string)\n");
	    addMessage("v","#\tUpdRepositoryPath (string)\n");
	    addMessage("v","#\t    (Default=/opt/fujitsu/ServerViewSuite/EM_UPDATE/UpdateRepository)\n");
	    addMessage("v","#\tUpdRepositoryUserId (string)\n");
	    addMessage("v","#\tUpdScheduleDate (uint64) - (time_t)\n");
	    addMessage("v","#\tUpdScheduleFrequency (uint64) - number of days\n");
	    addMessage("v","#\tUpdUpdateCheckMode (uint16) - (0=manually,1=aftermodification,2=scheduler)\n");
	    addMessage("v","#\tConfHttpProxyServerUsage (uint16) - (0=no,1=systemconfig,2=userconfig)\n");
	    addMessage("v","#\tConfHttpProxyServerPort (uint32)\n");
	    addMessage("v","#\tConfHttpProxyServerAddress (string)\n");
	    addMessage("v","#\tConfHttpProxyServerId (string)\n");
	    addMessage("v","#\tConfHttpProxyServerPasswd (string)\n");
	}
	addStatusTopic("l","Update Config Settings");
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		foreach my $key (sort keys %oneClass) {
		    if ($key and $key =~ m/^Upd/) {
			my $value = $oneClass{$key};
			$value = undef if (!defined $value or $value eq "");
			addKeyIntValue("l",$key, $oneClass{$key}) if (defined $value
				and $key ne "UpdRepositoryPassword" and $key ne "UpdScheduleDate"
				and $key ne "UpdRepositoryPath");
			addKeyLongValue("l",$key, $oneClass{$key}) if (defined $value
				and $key eq "UpdRepositoryPath");
			addKeyIntValue("l",$key, "****") if (defined $value
				and $key eq "UpdRepositoryPassword");
			addKeyLongValue("l",$key, gmctime($value)) if ($value
				and $key eq "UpdScheduleDate");
			if ($optOutdir) {
			    if ($key eq "UpdRepositoryPath" and !defined $oneClass{"UpdRepositoryPassword"}) {
				addKeyIntValue("v","#UpdRepositoryPassword", "");
				addMessage("v","\n");
			    }
			    addKeyIntValue("v",$key, $oneClass{$key}) if (defined $value);
			    addKeyIntValue("v","#" . $key, "") if (!defined $value);
			    addMessage("v","\n") if ($key);
			    if ($key eq "UpdRepositoryPath" and !defined $oneClass{"UpdRepositoryUserId"}) {
				addKeyIntValue("v","#UpdRepositoryUserId", "");
				addMessage("v","\n");
			    }
			}
		    } # Upd... elements
		} # for elements
	} #foreach instance (should be only one)
	foreach my $refClass (@serverClassInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		foreach my $key (sort keys %oneClass) {
		    if ($key and $key =~ m/^ConfHttpProxy/) {
			my $value = $oneClass{$key};
			$value = undef if (!defined $value or $value eq "");
			addKeyIntValue("l",$key, $oneClass{$key}) if (defined $value
				and $key ne "ConfHttpProxyServerPasswd");
			addKeyIntValue("l",$key, "****") if (defined $value
				and $key eq "ConfHttpProxyServerPasswd");
			if ($optOutdir) {
			    addKeyIntValue("v",$key, $oneClass{$key}) if (defined $value);
			    addKeyIntValue("v","#" . $key, "") if (!defined $value);
			    addMessage("v","\n");
			} # outdir
		    } # ConfHttpProxy ... elements
		} # for elements
		if (!defined $oneClass{"ConfHttpProxyServerPasswd"}) {
			addKeyIntValue("v","#ConfHttpProxyServerPasswd", "");
			addMessage("v","\n");
		}
		if (!defined $oneClass{"ConfHttpProxyServerId"}) {
			addKeyIntValue("v","#ConfHttpProxyServerId", "");
			addMessage("v","\n");
		}
	} #foreach instance (should be only one)
	if ($optOutdir) {
	    $variableVerboseMessage =~ s/^\s+//gm;
	    writeTxtFile($fileHost, "CFG", $variableVerboseMessage);
	} # print file
	$variableVerboseMessage = $save_variableVerboseMessage
  } #getUpdateConfigSettings
  sub setUpdateConfigSettingsInvoke {
	my $class=shift;
	my $useModify = 0;
	my $rc = undef;
	if ($optArguments) {
	    my $saveOptArguments = $optArguments;
	    my $saveNotifyMessage = $notifyMessage;

	    # ..... Rearange Arguments
	    my @propertyName = ();
	    my @propertyValue = ();
	    my %properties = splitKeyValueOption($optArguments);
	    foreach my $key (keys %properties) {
		my $value = undef;
		next if (!defined $key);
		$value = $properties{$key};
		$value = '' if (!defined $value);
		push(@propertyName, $key);
		push(@propertyValue, $value);
	    } # foreach argument
	    $optArguments = '';
	    foreach my $pName (@propertyName) {
		$optArguments .= "," if ($optArguments);
		$optArguments .= "PropertyNames=$pName";
	    } # foreach prop name
	    foreach my $pValue (@propertyValue) {
		$optArguments .= "," if ($optArguments);
		$optArguments .= "PropertyValues=$pValue";
	    } # foreach prop name
	    @expectedOutParameter = ();
	    $hasArrayParameter = 1; # hint for wbemcli
	    ($rc, my $response) = cimInvoke($class, "ModifyConfigSettings");
	    $useModify = 1 if (!defined $response);
	    $optArguments = $saveOptArguments;
	    $notifyMessage = $saveNotifyMessage;
	    $hasArrayParameter = undef;
	}
	return ($useModify, $rc);
  } #setUpdateConfigSettingsInvoke
  sub setUpdateConfigSettings {
 	#SVS_PGYUpdateConfigSettings
	# Key is InstanceID (Schuster Ruediger)
	my $retCode = undef;
	my @classInstances = ();	
	@classInstances = cimEnumerateClass("SVS_PGYUpdateConfigSettings");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateConfigSettings");
	if ($#classInstances < 0) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}

	# SVS_PGYServerConfigSettings
	# Key is InstanceID
	my @serverClassInstances = ();
	@serverClassInstances = cimEnumerateClass("SVS_PGYServerConfigSettings");
	cimPrintClass(\@serverClassInstances, "SVS_PGYServerConfigSettings");

	# Search Keys
	my $instanceID = undef;
	my $serverinstanceID = undef;
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		$instanceID = $oneClass{"InstanceID"}; 
		next if ($instanceID);
	} # foreach instance (should be only one)
	foreach my $refClass (@serverClassInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		$serverinstanceID = $oneClass{"InstanceID"}; 
		next if ($instanceID);
	} # foreach instance (should be only one)

	#
	#### All arguments
	if ($optUpdSetConfig) {
	    my $data = readCommentedTxtFile($optUpdSetConfig);
	    if (!defined $data) {
		addMessage("m", "- [ERROR] Unable to read file $optUpdSetConfig");
		return;
	    }
	    $data =~ s/\n/,/gm;
	    $data =~ s/,$//;
	    $optArguments = $data;
	    $optArguments .= "," if ($optArguments and $optUpdRepUser);
	    $optArguments .= "UpdRepositoryUserId=$optUpdRepUser" if ($optUpdRepUser);
	    $optArguments .= "," if ($optArguments and $optUpdRepPassword);
	    $optArguments .= "UpdRepositoryPassword=$optUpdRepPassword" if ($optUpdRepPassword);
	}
	#### Update arguments
	my $allArguments = $optArguments;
	if ($optArguments =~ m/ConfHttpProxy/) {
	    $optArguments =~ s/ConfHttpProxy[^,]*//g;
	    while ($optArguments =~ m/,,/) { # perl error
		$optArguments =~ s/,,/,/g;
	    }
	    $optArguments =~ s/,+$//; # it is an error that ,, replacement did'nt work proper
	    $optArguments =~ s/^,+//;
	    $optArguments = undef if ($optArguments =~ /^\s*$/);
	}
	my $useModify = 0;
	#### Try Invoke
	# SVS_PGYUpdateConfigSettings->ModifyConfigSettings
	# Key InstanceID
	# IN PropertyNames[]
	# IN PropertyValues []
	$optKeys = "InstanceID=$instanceID";
	($useModify, $retCode)  = setUpdateConfigSettingsInvoke("SVS_PGYUpdateConfigSettings");
=begin COMMENT
        if ($optArguments) {
	    my $saveOptArguments = $optArguments;
	    my $saveNotifyMessage = $notifyMessage;

	    # ..... Rearange Arguments
	    my @propertyName = ();
	    my @propertyValue = ();
	    my %properties = splitKeyValueOption($optArguments);
	    foreach my $key (keys %properties) {
		my $value = undef;
		next if (!defined $key);
		$value = $properties{$key};
		$value = '' if (!defined $value);
		push(@propertyName, $key);
		push(@propertyValue, $value);
	    } # foreach argument
	    $optArguments = '';
	    foreach my $pName (@propertyName) {
		$optArguments .= "," if ($optArguments);
		$optArguments .= "PropertyNames=$pName";
	    } # foreach prop name
	    foreach my $pValue (@propertyValue) {
		$optArguments .= "," if ($optArguments);
		$optArguments .= "PropertyValues=$pValue";
	    } # foreach prop name
	    @expectedOutParameter = ();
	    $hasArrayParameter = 1; # hint for wbemcli
	    my $response = cimInvoke("SVS_PGYUpdateConfigSettings", "ModifyConfigSettings");
	    $useModify = 1 if (!defined $response);
	    $optArguments = $saveOptArguments;
	    $notifyMessage = $saveNotifyMessage;
	    $hasArrayParameter = undef;
	}
=end COMMENT
=cut
	#### Modify SVS_PGYUpdateConfigSettings - WS-Transfer::Put()
	if ($useModify) {
	    $retCode = cimModify("SVS_PGYUpdateConfigSettings") if ($useModify);
	}
	#### Proxy Arguments
	my $serverRetCode = undef;
	if ($allArguments =~ m/ConfHttpProxy/) {
	    $optKeys = "InstanceID=$serverinstanceID";
	    $optArguments = $allArguments;
	    if ($optArguments =~ m/Upd/m) {
		$optArguments =~ s/Upd[^,]*//g;
		while ($optArguments =~ m/,,/) { # perl error
		    $optArguments =~ s/,,/,/g;
		}
		$optArguments =~ s/,+$//; # it is an error that ,, replacement did'nt work proper
		$optArguments =~ s/^,+//;
		$optArguments = undef if ($optArguments =~ /^\s*$/);
	    }	    
	}
	#### Try Invoke
	if ($allArguments =~ m/ConfHttpProxy/) {
	    $useModify = 0;
	    ($useModify, $serverRetCode) = setUpdateConfigSettingsInvoke("SVS_PGYServerConfigSettings");
	    $serverRetCode = 0 if (!$useModify);
	}
	#### Modify SVS_PGYServerConfigSettings - WS-Transfer::Put()
	if ($useModify and $allArguments =~ m/ConfHttpProxy/) {   
		$serverRetCode = cimModify("SVS_PGYServerConfigSettings") if ($optArguments);
	}
	####
	addExitCode(0) if (defined $retCode and ($retCode =~ m/0/ or $retCode));
	addExitCode(0) if (defined $serverRetCode and ($serverRetCode =~ m/0/ or $serverRetCode));
  } #setUpdateConfigSettings


  sub startUpdateCheck {
	# SVS_PGYCheckConfigData ???
	storeUpdateService_Keys();
	if (!$optKeys) {
	    addMessage("m","StartUpdateCheck(UNAVAILABLE)");
	    return;
	}
	@expectedOutParameter = ();
	(my $rc, my $response) = cimInvoke("SVS_PGYSoftwareUpdateService", "StartCheck");
	$exitCode = 0 if (defined $rc and $rc == 0);
	# SVS_PGYSoftwareUpdateService
	# KEY: CIM_Service: SystemCreationClassName, SystemName, CreationClassName, Name
	#	"SVS_PGYComputerSystem", ..., "SVS_PGYSoftwareUpdateService", "SVS:UpdateService"
  } #startUpdateCheck
  sub getUpdateCheckLogData {
	# SVS_PGYCheckData.GetUpdateCheckLogFile
	# Key: InstanceID
	# OUT: LogFileContent (string)
	my @classInstances = ();	
	@classInstances = cimEnumerateClass("SVS_PGYCheckData");
	cimPrintClass(\@classInstances, "SVS_PGYCheckData");

	if ($#classInstances < 0) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}
	my $instanceID = undef;
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		$instanceID = $oneClass{"InstanceID"}; 
		next if ($instanceID);
	} # foreach instance (should be only one)
	if (!defined $instanceID) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}
	$optKeys = "InstanceID=$instanceID";
	@expectedOutParameter = ();
	push (@expectedOutParameter, "LogFileContent");
	my $response = cimInvoke("SVS_PGYCheckData", "GetUpdateCheckLogFile");
	# EXTRACT: one must be carefull how to handle this because of multiple linebreaks !
	my $logcontent = undef;
	$logcontent = $response if ($response and $response =~ m/<LogFileContent>/m); # WS-MAN
	if ($logcontent) {
	    $logcontent =~ s/.*<LogFileContent>//m;
	    $logcontent =~ s/<.LogFileContent>.*//m; 
	    $logcontent =~ s/\s+$//gm;
	}
	addMessage("l",$logcontent) if ($logcontent);
	$exitCode = 0 if (defined $logcontent and $logcontent !~ m/^\s*$/);
	addMessage("m","Empty Update Check Logfile ") if ($exitCode);
  } #getUpdateCheckLogData

  sub getUpdateDiffTable {
	my $returnarray = shift;
	my @classInstances = ();
	my @arrJobComponents = ();

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
	    push(@arrJobComponents, $componentPath) if ($returnarray);
	    if ($optUpdDiffList and (!$printLimit or $printIndex < $printLimit)) { # stdout
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
	    if ($optUpdDiffList and $optOutdir) { # file
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
	addMessage("l", "#...\n") if ($optUpdDiffList and ($printLimit and $printLimit == $printIndex));

	if ($optUpdDiffList and $optOutdir) {
	    writeTxtFile($fileHost, "DIFF", $variableVerboseMessage);
	}
	$variableVerboseMessage = $save_variableVerboseMessage;
	addMessage("m","No update difference list available") if ($optUpdDiffList and $#classInstances < 0);
	$notifyMessage = undef if ($#classInstances < 0);
	return \@arrJobComponents if ($returnarray);
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
	addMessage("m","No update installation list available") if ($#classInstances < 0);
	$notifyMessage = undef if ($#classInstances < 0);
  } # getUpdateInstTable
  sub getUpdateReleaseNotes {
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYUpdateDiff");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateDiff");
	if ($#classInstances < 0) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}
	# SVS_PGYUpdateDiff.GetReleaseNotes()
	# KEYS: InstanceID
	# OUT: ReleaseNotes
	$optArguments = undef;
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $instance = $oneClass{"InstanceID"};
		my $component = $oneClass{"ComponentPath"};
		my $componentVersion = $oneClass{"ComponentVersion"};
		my $installedVersion = $oneClass{"InstalledVersion"};
		my $repos2InstRanking = $oneClass{"Repos2InstRanking"};
		next if (!$instance);

		next if ($optGetOneReleaseNote and $component and $component ne $optGetOneReleaseNote);
		next if ($optGetDiffReleaseNotes and (!$componentVersion or !$installedVersion));
		next if ($optGetDiffReleaseNotes 
		    and $repos2InstRanking and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );
		
		$optKeys = "InstanceID=\"$instance\"";
		@expectedOutParameter = ();
		push (@expectedOutParameter, "ReleaseNotes");
		my $response = cimInvoke("SVS_PGYUpdateDiff", "GetReleaseNotes");
		if (!$response) {
		    addStatusTopic("l","UNKNOWN", "ReleaseNote", $component);
		    addMessage("l","\n");
		} else {
		    addStatusTopic("l","AVAILABLE", "ReleaseNote", $component)
			if (!$optGetOneReleaseNote);
		    $response =~ s/<ReleaseNotes>/<ReleaseNotes>\n/;
		    $response =~ s!</ReleaseNotes>!\n</ReleaseNotes>!;
		    $response =~ s/\r\n/\n/g;
		    $response =~ s/\r/\n/g;
		    $response =~ s/<ReleaseNotes>\s+/<ReleaseNotes>\n/;
		    $response =~ s!\s+</ReleaseNotes>!\n</ReleaseNotes>!;
		    if ($optGetOneReleaseNote) {
			$response =~ s/^\<ReleaseNotes\>\n//;
			$response =~ s!\</ReleaseNotes\>$!!;
		    }
		    addMessage("l","\n");
		    addMessage("l","$response\n\n");
		    $exitCode = 0;
		}
	} # foreach
	if ($exitCode) {
	    addMessage("m","- Unable to get release notes");
	} else {
	    addMessage("m","- Found release notes") if (!$optGetOneReleaseNote);
	}
  } #getUpdateReleaseNotes

  sub updJobListComponentPaths {
	my $printThis = shift;
	# SVS_PGYSoftwareUpdateService.ListComponentPaths
	# OUT: ComponentPaths[]
	@expectedOutParameter = ();
	push (@expectedOutParameter, "ComponentPaths");
	my $response = cimInvoke("SVS_PGYSoftwareUpdateService", "ListComponentPaths");
	if ($printThis and !$response) {
	    addMessage("l","ComponentPathList - empty");
	}
	$notifyMessage = undef if ($response);
	$exitCode = 0 if ($response);
	return 0 if (!$response);
	return 1 if (!$optUpdJobList);
	return $response if ($optUpdJobList);
  } #updJobListComponentPaths
  sub updJobAddtoComponentPath {
	my $refComponents = shift;
	my $file = undef;
	my @componentArray = ();
	my $singleComponent = undef;
	if (!$refComponents) {
	    $file = $optStartUpdJob;
	    $file = $optUpdJobAdd if (!defined $file);
	    return -1 if (!defined $file);
	    my $data = readCommentedTxtFile($file);
	    if (!defined $data) {
		addMessage("m", "- [ERROR] Unable to read file $file");
		return -1;
	    }
	    while ($data) {
		$singleComponent = $1 if ($data =~ m/^([^\n]+)\n/);
		push (@componentArray, $singleComponent) if ($singleComponent);
		$data =~ s/^[^\n]+\n//;
		$data = undef if ($data =~ m/^\s*$/m);
	    }
	} else {
	    @componentArray  = @$refComponents;
	}
	my $rc = 0;
	foreach $singleComponent (@componentArray) {
	    # SVS_PGYSoftwareUpdateService.AddToComponentPath
	    # IN:   ComponentPath
	    next if (!$singleComponent);
	    $optArguments = "ComponentPath=\"$singleComponent\"";
	    @expectedOutParameter = ();
	    ( my $localrc, my $response) = cimInvoke("SVS_PGYSoftwareUpdateService", "AddtoComponentPath");
	    if ($localrc and $localrc =~ m/^\d+$/ and $localrc == 2) {
		addStatusTopic("l","ERROR","AddUpdateComponent",$singleComponent);
		addMessage("l","\n");
		$rc = 2;
	    }
	    if ($localrc and $localrc =~ m/^\d+$/ and $localrc == 1) {
		addStatusTopic("l","EXISTS","AddUpdateComponent",$singleComponent);
		addMessage("l","\n");
		$rc = 1 if ($rc != 2);
		$exitCode = 1	if ($optUpdJobAdd);
		addMessage("m", "- there is an error hint concerning add of component")
		    if ($optUpdJobAdd and (!defined $msg or $msg =~ m/^\s*$/));
	    } elsif($optUpdJobAdd and defined $localrc and !$localrc) {
		$exitCode = 0;
	    }
	} # foreach
	return $rc;
  } #updJobAddtoComponentPath
  sub startUpdateJob {
	my $response = undef;
	storeUpdateService_Keys();
	if (!$optKeys) {
	    addMessage("m","StartUpdateJob(UNAVAILABLE)");
	    return;
	}
	if (!defined $optUpdJobAdd and !defined $optUpdJobList and !defined $optStartUpdJobList) 
	{
	    # SVS_PGYSoftwareUpdateService.CleanupJob
	    @expectedOutParameter = ();
	    (my $rc, $response) = cimInvoke("SVS_PGYSoftwareUpdateService", "CleanupJob");
	    if (!defined $rc) {
		$exitCode = 2;
		addMessage("m","\n") if ($msg);
		addMessage("m","[ERROR] Could not invoke method 'SVS_PGYSoftwareUpdateService->CleanupJob'");
	    } elsif ($optCleanupUpdJob) {
		$exitCode = 0;
		addMessage("m","CleanupJob(started) Returncode=$rc");
	    }
	} # not single steps
	if (defined $optUpdJobStartTime and $optUpdJobStartTime) {
	    # SVS_PGYSoftwareUpdateService.SetJobStartTime
	    # IN: TimeToStartJob (time_t)
	    $optArguments = "TimeToStartJob=$optUpdJobStartTime";
	    @expectedOutParameter = ();
	    my $response = cimInvoke("SVS_PGYSoftwareUpdateService", "SetJobStartTime");
	}
	if ($optStartUpdJobAll) {
	    my $refJobComponents = getUpdateDiffTable(1);
	    my $rc = updJobAddtoComponentPath($refJobComponents);
	    return if ($rc < 0);
	}
	if ($optStartUpdJob or $optUpdJobAdd) { # selection by file
	    my $rc = updJobAddtoComponentPath();
	    return if ($rc < 0);
	}
	if ($optStartUpdJob or $optUpdJobList or $optStartUpdJobAll) {
	    $optArguments = undef;
	    my $listExists = updJobListComponentPaths(1);
	    addMessage("l",$listExists) if ($optUpdJobList);
	    if (!$listExists) {
		addMessage("m","no update job components found"); 
		return if (!$listExists); # all added components failed ... nothing to do
	    }
	}
	if (($optStartUpdJobList or $optStartUpdJobAll or $optStartUpdJob)
	and !defined $optUpdJobAdd and !defined $optUpdJobList and !defined $optCleanupUpdJob) 
	{
	    # SVS_PGYSoftwareUpdateService.StartJob
	    # IN: UpdateAll (not for 7.10.18 or higher)
	    # OUT: StartJob
	    #$optArguments = "UpdateAll=FALSE" if ($optStartUpdJob or $optStartUpdJobList);
	    #$optArguments = "UpdateAll=TRUE" if ($optStartUpdJobAll);
	    $optArguments = undef;
	    @expectedOutParameter = ();
	    push (@expectedOutParameter, "StartJob");
	    $response = cimInvoke("SVS_PGYSoftwareUpdateService", "StartJob");
	    if (!$response) {
		$exitCode = 2;
		addMessage("m","\n") if ($msg);
		addMessage("m","[ERROR] Could not invoke method 'SVS_PGYSoftwareUpdateService->StartJob'");
	    } else {
		$exitCode = 0;
		addMessage("m", "UpdateJob(Started)");
	    }
	} # start
  } #startUpdateJob
  sub splitWbemUpdateJobComponentsLog { # only for wbemcli
	my $inarrErrorText	= shift;
	my $inarrStatus		= shift; 
	my $inarrReturnCode	= shift; 
	my $inarrStartTime	= shift; 
	my $inarrEndTime	= shift; 
	my $rc = 1;
	my @arrErrorText = ();
	my @arrStatus = ();
	my @arrReturnCode = ();
	my @arrStartTime = ();
	my @arrEndTime = ();
	@arrErrorText = split m/,/, $inarrErrorText;
	@arrStatus = split m/,/, $inarrStatus;
	@arrReturnCode = split m/,/, $inarrReturnCode;
	@arrStartTime = split m/,/, $inarrStartTime;
	@arrEndTime = split m/,/, $inarrEndTime;
	$rc = 0 if ($#arrStatus == $#arrErrorText);
	return ($rc, \@arrErrorText, \@arrStatus, \@arrReturnCode, \@arrStartTime, \@arrEndTime); 
  } #splitWbemUpdateJobComponentsLog
  sub getUpdateJobComponentsLog {
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYComponentInfo");
	cimPrintClass(\@classInstances, "SVS_PGYComponentInfo");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "ComponentLogInfo","UNAVAILABLE");
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	    return;
	} else {
	    #addTableHeader("l","Job Components Log Info");
	    addComponentStatus("m", "ComponentLogInfo","AVAILABLE");
	    $exitCode = 0;
	}
	my $i=0;
	foreach my $refClass (@classInstances) {
		next if (!$refClass);
		my %oneClass = %{$refClass};
		my $path	= $oneClass{"ComponentPath"}; 
		my $text	= $oneClass{"ComponentErrorText"};
		my $start	= $oneClass{"ComponentStartTime"};
		my $code	= $oneClass{"ComponentReturnCode"};
		my $status	= $oneClass{"ComponentStatus"};
		my $end		= $oneClass{"ComponentEndTime"};

		my @statusText = ( "Waiting",
		    "Downloading", "Downloaded", "Updating", "Updated", "Done - OK",
		    "Done - Error", "No job defined", "Cleanup", "Reboot",
		    "..undefined..",);

		$status = 10 if (!defined $status or $status < 0 or $status > 9);
		$text =~ s/[\"]/\\\"/g if ($text);
		addStatusTopic("l",$statusText[$status],"ComponentLog", $path);
		addKeyIntValue("l", "\n# ReturnCode", $code);
		addKeyLongValue("l", "\n# StartTime", gmctime($start)) if ($start);
		addKeyLongValue("l", "EndTime", gmctime($end)) if ($end);
		addKeyLongValue("l", "\n# LogText", $text);
		addMessage("l","\n");
		$i++;
	} #foreach instance
  } #getUpdateJobComponentsLog
  sub getUpdateJobComponentsLogMethod {
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYUpdateJob");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateJob");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "UpdateJobInformation","UNAVAILABLE");
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	    return;
	}
	my $instance = undef;
	foreach my $refClass (@classInstances) {
		next if (!$refClass);
		my %oneClass = %{$refClass};
		$instance = $oneClass{"InstanceID"} if (!defined $instance); 
	} #foreach instance (should be only one)

	# SVS_PGYUpdateJob.GetComponentsInfo
	# KEYS: InstanceID
	# OUT ComponentErrorText [], ComponentStartTime [], ComponentReturnCode [], 
	# OUT ComponentEndTime[], ComponentStatus []
	$optKeys = "InstanceID=$instance";
	$optArguments = undef;
	@expectedOutParameter = ();
	push (@expectedOutParameter, "ComponentErrorText");
	push (@expectedOutParameter, "ComponentStartTime");
	push (@expectedOutParameter, "ComponentReturnCode");
	push (@expectedOutParameter, "ComponentEndTime");
	push (@expectedOutParameter, "ComponentStatus");
	my $response = cimInvoke("SVS_PGYUpdateJob", "GetComponentsInfo");
	if (!$response) {
	    $exitCode = 2;
	    addMessage("m","\n") if ($msg);
	    addMessage("m","[ERROR] Could not invoke method 'SVS_PGYUpdateJob->GetComponentsInfo'");
	} else {
	    $exitCode = 0;
	    # split response
	    # TODO ... search a generic solution for outparam arrays
	    my @arrErrorText = ();
	    my @arrReturnCode = ();
	    my @arrStatus = ();
	    my @arrStartTime = ();
	    my @arrEndTime = ();
	    my $rest = $response;
	    $rest =~ s/\s*$//; # remove last spaces
	    while ($rest) {
		my $content = undef;
		if ($rest =~ m/^<ComponentErrorText>/) {
		    $rest =~ s/^<ComponentErrorText>//;
		    $content = $1 if ($rest =~ m/^([^<]*)/);
		    push (@arrErrorText, $content) if ($content);
		    $rest =~ s/^[^<]*//;
		    $rest =~ s!^</ComponentErrorText>!!;
		} elsif ($rest =~ m/^<ComponentReturnCode>/) {
		    $rest =~ s/^<ComponentReturnCode>//;
		    $content = $1 if ($rest =~ m/^([^<]*)/);
		    push (@arrReturnCode, $content) if ($content);
		    $rest =~ s/^[^<]*//m;
		    $rest =~ s!^</ComponentReturnCode>!!;
		} elsif ($rest =~ m/^<ComponentStatus>/) {
		    $rest =~ s/^<ComponentStatus>//;
		    $content = $1 if ($rest =~ m/^([^<]*)/);
		    push (@arrStatus, $content) if ($content);
		    $rest =~ s/^[^<]*//m;
		    $rest =~ s!^</ComponentStatus>!!;
		} elsif ($rest =~ m/^<ComponentStartTime>/) {
		    $rest =~ s/^<ComponentStartTime>//;
		    $content = $1 if ($rest =~ m/^([^<]*)/);
		    push (@arrStartTime, $content) if ($content);
		    $rest =~ s/^[^<]*//m;
		    $rest =~ s!^</ComponentStartTime>!!;
		} elsif ($rest =~ m/^<ComponentEndTime>/) {
		    $rest =~ s/^<ComponentEndTime>//;
		    $content = $1 if ($rest =~ m/^([^<]*)/);
		    push (@arrEndTime, $content) if ($content);
		    $rest =~ s/^[^<]*//m;
		    $rest =~ s!^</ComponentEndTime>!!;
		} else { # ignore
		    $rest =~ s/^<[^>]>//;
		    $rest =~ s/^[^<]*//m;
		    $rest =~ s!^</[^>]>!!;
		}
		$rest =~ s/^\s+//;
		$rest = undef if ($rest and $rest =~ m/^\s*$/);
	    } #while response
	    #### repair wbem arrays
	    if ($#arrReturnCode == 0  and $#arrErrorText == 0 and $arrReturnCode[0] =~ m/,/) { 
		# wbemcli returns arrays as one comma separated lists
		# This is a big problem for values with commas
		(my $rc, my $refarrErrorText, my $refarrStatus, my $refarrReturnCode, 
		my $refarrStartTime, my $refarrEndTime) = 
		    splitWbemUpdateJobComponentsLog(
			$arrErrorText[0], $arrStatus[0],$arrReturnCode[0], $arrStartTime[0], $arrEndTime[0]);
		if (!$rc) {
		    # This works only if Update Agent didn't set commas in the ErrorText
		    @arrErrorText = @{$refarrErrorText};
		    @arrStatus = @{$refarrStatus};
		    @arrReturnCode = @{$refarrReturnCode};
		    @arrStartTime = @{$refarrStartTime};
		    @arrEndTime = @{$refarrEndTime};
		}
	    }
	    #### print
	    for (my $i=0; $i <= $#arrStartTime; $i++) {
		my $text = $arrErrorText[$i];
		my $status = $arrStatus[$i];
		my $code = $arrReturnCode[$i];
		my $start = $arrStartTime[$i];
		my $end = $arrEndTime[$i];

		addStatusTopic("l",undef,"ComponentLog", $i);
		addKeyIntValue("l", "ReturnCode", $code);
		addKeyIntValue("l", "ReturnStatus", $status);
		addKeyLongValue("l", "LogText", $text);
		addKeyLongValue("l", "StartTime", gmctime($start)) if ($start);
		addKeyLongValue("l", "EndTime", gmctime($end)) if ($end);
		addMessage("l","\n");
	    } # for
	}
  } #getUpdateJobComponentsLog
  sub getUpdateJobLogFile {
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYUpdateJob");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateJob");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "UpdateJobInformation","UNAVAILABLE");
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	    return;
	}
	my $logfile = undef;
	foreach my $refClass (@classInstances) {
		next if (!$refClass);
		my %oneClass = %{$refClass};
		$logfile = $oneClass{"LogFileName"} if (!defined $logfile); 
	} #foreach instance (should be only one)

	# SVS_PGYSoftwareUpdateService.ReadLogFile
	# IN: LogFileName <- SVS_PGYUpdateJob.LogFileName !? 
	# OUT: LogFileContent (XML)
	storeUpdateService_Keys();
	if (!$optKeys) {
	    addMessage("m","GetUpdateJobLogFile(UNAVAILABLE)");
	    return;
	}
	#$logfile =~ s!\\!/!g; # ... mixed  / and \ for windows
	$optArguments = "LogFileName=\"$logfile\"";
	#$optArguments = "LogFileName=C:/job_1_log.xml"; # troubles with blanks and quotes
	@expectedOutParameter = ();
	push (@expectedOutParameter, "LogFileContent");
	my $response = cimInvoke("SVS_PGYSoftwareUpdateService", "ReadLogFile");
	if (!$response) {
	    $exitCode = 2;
	    addMessage("m","[ERROR] Could not invoke method 'SVS_PGYSoftwareUpdateService->ReadLogFile'");
	} else {
	    my $data = $response;
	    $data =~ s/^<LogFileContent>//;
	    $data =~ s/<.LogFileContent>//;
	    if (!$data or $data =~ m/^\s*$/) {
		addMessage("m","[ERROR] Empty Update Job Logfile");
		$exitCode = 1;
	    } else {
		addMessage("l",$data);
		$exitCode = 0;
	    }
	}
  } #getUpdateJobLogFile
  sub cancelUpdateJob {
	my $save_notifyMessage = $notifyMessage;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYUpdateJob");
	cimPrintClass(\@classInstances, "SVS_PGYUpdateJob");
	if ($#classInstances < 0) {
	    addComponentStatus("m", "UpdateJobInformation","UNAVAILABLE");
	    $notifyMessage = $save_notifyMessage; # ignore not existing instance - this is normal due to developers
	    return;
	}
	my $instance = undef;
	foreach my $refClass (@classInstances) {
		next if (!$refClass);
		my %oneClass = %{$refClass};
		$instance = $oneClass{"InstanceID"} if (!defined $instance); 
	} #foreach instance (should be only one)
	# SVS_PGYUpdateJob.RequestStateChange
	# Parameter RequestedState=5, TimeoutPeriod=0
	$optKeys = "InstanceID=$instance";
	$optArguments = "RequestedState=5";
	@expectedOutParameter = ();
	(my $rc, my $response) = cimInvoke("SVS_PGYUpdateJob", "RequestStateChange");
	if (!defined $rc) {
	    $exitCode = 2;
	    addMessage("m","\n") if ($msg);
	    addMessage("m","[ERROR] Could not invoke method 'SVS_PGYUpdateJob->RequestStateChange'");
	} else {
	    $exitCode = 0; 
	    addMessage("m","- CancelUpdateJob(Started) ReturnCode=$rc");
	}
  } #cancelUpdateJob

  sub processUpdateManagement {
	return if (!$optUpdate);
	my $sysstatus = undef;
	$sysstatus = getUpdateStatus();
	if ($sysstatus == 4) {
	    addMessage("m", "Unable to get ServerView CIM Classes");
	    $msg = "- " . $msg if ($msg);
	    return;
	}

	getUpdateConfigSettings() if ($optUpdGetConfig);
	setUpdateConfigSettings() if ($optUpdSetConfig or $optUpdSetConfigArg);

	startUpdateCheck()	if ($optStartUpdCheck);
	getUpdateCheckLogData() if ($optGetUpdCheckLog);

	getUpdateDiffTable()	if ($optUpdDiffList);
	getUpdateInstTable()	if ($optUpdInstList);
	getUpdateReleaseNotes() if ($optGetAllReleaseNotes or $optGetDiffReleaseNotes 
				or  $optGetOneReleaseNote);

	startUpdateJob()	if ($optStartUpdJobAll	or $optStartUpdJob
				or  $optUpdJobAdd	or $optUpdJobList
				or  $optStartUpdJobList	or $optCleanupUpdJob
				or  $optUpdJobStartTime);
	cancelUpdateJob()	if ($optCancelUpdJob);
	getUpdateJobLogFile()	if ($optUpdJobLogFile);
	getUpdateJobComponentsLog() if ($optUpdJobComponentLog);

	$msg = "- " . $msg if ($msg);
  } #processUpdateManagement

#########################################################################
sub processData {
	my $discoveredType = 0;
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
	} elsif ($exitCode != 2) {
		if (!$isESXi and !$isLINUX and !$isWINDOWS and !$isiRMC
		and $main::verbose <= 10) 
		{
		    $exitCode = 3;
		    $msg .= "- ";
		    addMessage("m", "ERROR - Server Type could not be evaluated");
		} else {
		    $discoveredType = 1;
		}
	} 
	if ($discoveredType and  $optUpdate) {
	    $exitCode = 3;
	    processUpdateManagement();
	} 
	if ($discoveredType and $optInvoke) {
	    $exitCode = 3;
	    cimInvoke($optClass, $optMethod);
	}
	if ($discoveredType and $optModify) {
	    $exitCode = 3;
	    cimModify($optClass);
	}
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
	#### TEXT LANGUAGE AWARENESS
	print 'UNKNOWN: Timeout' . "\n";
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
$stateString = undef if (($optUpdJobLogFile or $optGetUpdCheckLog or $optGetOneReleaseNote) 
    and !$exitCode); # suppress "OK"
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


