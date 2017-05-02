#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2016
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.01
# Date:		2016-07-06

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage;
#use Time::localtime 'ctime';
use Time::gmtime 'gmctime';
use utf8;

#------ This script uses curl -------#

# LATER ... add iRMC/eLCM inside this script !

#### HELP ##############################################
# HIDDEN:
#	Split of startjob: --cleanupjob, --addjob=s,--listjob,--startjoblist
#	    
#
=head1 NAME

updmanag_fujitsu_server_REST.pl - Update Manager Administration for server with installed ServerView Agent
(using component ServerView Server Control)

=head1 SYNOPSIS

updmanag_fujitsu_server_REST.pl 
  {  -H|--host=<host> [-A|--admin=<host>]
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      [-S|--service=<type>]
      [-u|--user=<username> -p|--password=<pwd>]
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

Update Manager Administration for Fujitsu server with installed ServerView Agent.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>  [-A|--admin=<ip>]

Host address as DNS name or ip address of the server.
With optional option -A an administrative ip address can be specified.
This might be the address of iRMC as an example.
The communication is done via the admin address if specified.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>]

REST service port number and transport type.
In the transport type 'http' or 'https' can be specified.

These options are used for curl calles without any preliminary checks.

=item [-S|--service=<type>]

Type of the REST Service.

"A" | "Agent" - ServerView Server Control REST Service

=item -u|--user=<username> -p|--password=<pwd>

Authentication data. 

These options are used for curl calles without any preliminary checks.



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
our $optUseMode = undef;
our $optServiceType = undef;	# AGENT, REPORT, iRMC, ISM, SOA

# pure REST options
our $optRestAction	= undef;
our $optRestData	= undef;
our $optRestUrlPath	= undef;
our $optRestHeaderLines	= undef;
our $optConnectTimeout	= undef;

# REST authentication
our $optUserName = undef; 
our $optPassword = undef; 
our $optCert = undef;
our $optCertPassword = undef;
our $optPrivKey = undef; 
our $optPrivKeyPassword = undef; 
our $optCacert = undef;

# REST specific option
our $optTransportType = undef;

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

# 
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
our $is2014Profile = undef;


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

	   		"chkidentify", 

			"X|rest=s",
			"D|data=s",
			"R|requesturlpath=s",
			"headers=s",
			"ctimeout=i",	

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
			  
			  "arguments=s",

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

			"X|rest=s",
			"D|data=s",
			"R|requesturlpath=s",
			"headers=s",
			"ctimeout=i",	

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
	$k="S";		$optServiceType = $options{$k}		if (defined $options{$k});

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
		$optUseMode = $options{$key}			if ($key eq "U"			);
		$optServiceType = $options{$key}		if ($key eq "S"			);
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 
		$optChkIdentify = $options{$key}                if ($key eq "chkidentify" 	);	 
		
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
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

	# required combination tests
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
	$optTransportType = "https" if (!defined $optTransportType);

	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}

	# Defaults ...
	if (!defined $optInvoke and !defined $optModify 
	and !defined $optChkIdentify) 
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
		and !defined $optCleanupUpdJob	and !defined $optUpdJobStartTime
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
	    $cmd .= " -v" if ($useRESTverbose or $main::verbose >= 60);
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
	    $cmd .= " --url $fullURL";
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
	    addExitCode(0) if ($outPayload);
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
# SvAgent - SCCI	
#########################################################################
# ... the following three are for compatibility with the check script
  our $gAgentSCSversion = undef;
  our $gAgentSCCIversion = undef;
  our $gAgentSCCIcompany = undef;
  our %gAgentOC = (
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
	"UmDiffReleaseNotes"			=> 0x3314,

	"UmServerStartCheck"			=> 0x3331,
	"UmServerUpdateCheckStatus"		=> 0x3336,
	"UmServerUpdateCheckErrorCode"		=> 0x3337,
	"UmServerLastCheckTime"			=> 0x3332,
	"UmServerUpdateCheckLogFile"		=> 0x3335,

	"UmJobNumberComponents"			=> 0x33A0,
	"UmJobComponentPath"			=> 0x33A1,
	"UmJobComponentStartTime"		=> 0x33A3,
	"UmJobComponentEndTime"			=> 0x33A4,
	"UmJobComponentStatus"			=> 0x33A5,
	"UmJobComponentReturnCode"		=> 0x33A6,
	"UmJobComponentErrorText"		=> 0x33A7,

	"UmJobStatus"				=> 0x33B0,
	"UmJobStartTime"			=> 0x33B1,
	"UmJobLogFileName"			=> 0x33B5,
	"UmJobErrorFileName"			=> 0x33B6,
	"UmJobReadLogFile"			=> 0x33BF,

	"UmJobSetComponentPath"			=> 0x33A2,
	"UmJobSetStartTime"			=> 0x33B2,
	"UmJobStartJob"				=> 0x33BC,
	"UmJobCancelJob"			=> 0x33BD,
	"UmJobCleanup"				=> 0x33BE,

	#"ReadConfigurationSpace"		=> 0xE001,
	"UpdRepositoryPath", 			=> 0xE001,
	"UpdRepositoryAccess", 			=> 0xE001,
	"UpdRepositoryUserId",			=> 0xE001,
	"UpdRepositoryPassword",		=> 0xE001,
	"UpdUpdateCheckMode", 			=> 0xE001,
	"UpdDownloadMode",			=> 0xE001,
	"UpdDownloadServerAddress", 		=> 0xE001,
	"UpdDownloadRepositoryPath",		=> 0xE001,
	"UpdDeleteBinaryAfterUpdate",		=> 0xE001,
	"UpdScheduleDate",			=> 0xE001,	
	"UpdScheduleFrequency",			=> 0xE001,
	"UpdDownloadProtocol",			=> 0xE001,
	"UpdAlertNewUpdates",			=> 0xE001,
	"UpdAlertJobFinished",			=> 0xE001,
	"HttpProxyServerUsage",			=> 0xE001,
	"HttpProxyServerAddress",		=> 0xE001,
	"HttpProxyServerPort",			=> 0xE001,
	"HttpProxyServerUserId",		=> 0xE001,
	"HttpProxyServerPasswd",		=> 0xE001,

	"WriteConfigurationSpace"		=> 0xE002,
  );
  our %gAgentOE = (
	"UpdRepositoryPath", 			=> 0x1A40,
	"UpdRepositoryAccess", 			=> 0x1A41,
	"UpdRepositoryUserId",			=> 0x1A42,
	"UpdRepositoryPassword",		=> 0x1A43,
	"UpdUpdateCheckMode", 			=> 0x1A44,
	"UpdDownloadMode",			=> 0x1A45,
	"UpdDownloadServerAddress", 		=> 0x1A47,
	"UpdDownloadRepositoryPath",		=> 0x1A48,
	"UpdDeleteBinaryAfterUpdate",		=> 0x1A49,
	"UpdScheduleDate",			=> 0x1A4A,	
	"UpdScheduleFrequency",			=> 0x1A4B,
	"UpdDownloadProtocol",			=> 0x1A4C,
	"UpdAlertNewUpdates",			=> 0x1A4D,
	"UpdAlertJobFinished",			=> 0x1A4E,
	"HttpProxyServerUsage",			=> 0x1A90,
	"HttpProxyServerAddress",		=> 0x1A91,
	"HttpProxyServerPort",			=> 0x1A92,
	"HttpProxyServerUserId",		=> 0x1A93,
	"HttpProxyServerPasswd",		=> 0x1A94,
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
		    $valueDA = jsonPrintArray(undef, $responseDA);
		}
	    }
	    #$valueDA = jsonUnescape($valueDA) if ($valueDA =~ m/[\\]/);
	    return $valueDA;
	} # foreach
	return undef;
  } # agentJson_GetCmdSimpleData
 ####
  sub agent_CheckError {
	my $providerout = shift;
	my $outheader = shift;
	my $errtext = shift;
	my $tmpExitCode = 3;
	if ($outheader and $outheader =~ m/HTTP.[\d\.]+ 401/) {
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
	} elsif ($providerout and $providerout =~ m/\"error\".*\"msg\"/i) {
	    addMessage("m", "Server Control returns error !");
	    addMessage("l",$providerout);
	    addMessage("l","\n") if ($errtext);
	    addMessage("l",$errtext) if ($errtext);
	    addExitCode(2);
	    $tmpExitCode = 2;
	} elsif (!defined $providerout) {
	    addMessage("m", "Empty response !");
	    addMessage("l",$errtext) if ($errtext);
	    addExitCode(2);
	    $tmpExitCode = 2;
	}
	return $tmpExitCode;
  } # agent_CheckError
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

  sub agentUpdateSystemStatus {
	$useRESTverbose = 1; # for 401 checks
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmServerStatus");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return $rc if ($rc == 2);
	$useRESTverbose = 0;
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $updStatus = agentJson_GetCmdSimpleData($refCmd,"UmServerStatus");  
	    my @updText = ("ok",
		"recommended", "mandatory","unknown","undefined","..unexpected..");
	    $updStatus = 4 if (!defined $updStatus);
	    $updStatus = 5 if ($updStatus < 0 or $updStatus > 3);
	    if ($optUpdSysStatus) {
		addExitCode($updStatus) if ($updStatus < 3);
		addComponentStatus("m", "UpdateStatus",$updText[$updStatus]);
	    }
	    return $exitCode;
  } # agentUpdateSystemStatus
  sub agentUpdateCheckStatus {
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmServerUpdateCheckStatus");
	    agentJson_AddCmd($refArrayCmd,"UmServerUpdateCheckErrorCode");
	    agentJson_AddCmd($refArrayCmd,"UmServerLastCheckTime");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $status = agentJson_GetCmdSimpleData($refCmd,"UmServerUpdateCheckStatus");  
	    my $lastcheck = agentJson_GetCmdSimpleData($refCmd,"UmServerLastCheckTime");  
	    my $lastcode = agentJson_GetCmdSimpleData($refCmd,"UmServerUpdateCheckErrorCode");  
	#### EVAL  
	    $rc = -1;
	    my @statusText = ("Done - OK",
		"Done - Error", "Downloading","Checking","undefined","..unexpected..");
	    $status = 4 if (!defined $status);
	    $status = 5 if ($status < 0 or $status > 3);
	    $rc = $status if (defined $status and $status >= 0 and $status <= 3);
	    addComponentStatus("m", "UpdateCheckStatus",$statusText[$rc])
		if ($optUpdCheckStatus and $rc >= 0);
	    if ($optUpdStatus or $optUpdCheckStatus) {
		addStatusTopic("l","Update Check");
		addKeyLongValue("l", "LastCheckTime", gmctime($lastcheck)) 
		    if ($lastcheck  and $lastcheck > 0);
		addKeyValue("l", "UpdateCheckErrorCode", $lastcode); # ignore 0
		addMessage("l","\n");
		addExitCode(0) if ($optUpdCheckStatus and $optUpdCheckStatus==1 and $rc == 0);
		addExitCode(1) if ($optUpdCheckStatus and $optUpdCheckStatus==1  and $rc == 1);
	    }
	    return $rc;
  } # agentUpdateCheckStatus
  sub agentUpdateJobStatus {
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobStatus");
	    agentJson_AddCmd($refArrayCmd,"UmJobStartTime");
	    agentJson_AddCmd($refArrayCmd,"UmJobLogFileName");
	    agentJson_AddCmd($refArrayCmd,"UmJobErrorFileName");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $status = agentJson_GetCmdSimpleData($refCmd,"UmJobStatus");  
	    my $starttime = agentJson_GetCmdSimpleData($refCmd,"UmJobStartTime");  
	    my $logfile = agentJson_GetCmdSimpleData($refCmd,"UmJobLogFileName");  
	    my $errfile = agentJson_GetCmdSimpleData($refCmd,"UmJobErrorFileName");  
	#### EVAL
	my @statusText = ("Waiting", 
	    "Downloading", "Downloaded", "Updating", "Updated", "Done - OK", 
	    "Done - Error", "No job defined", "Rescanning", "Rebooting",
		    "..unexpected..", "undefined",
	);
	$status = 10 if ($status and ($status < 0 or $status > 9));
	$status = 11 if (!defined $status);
	$rc = -1;
	$rc = $status if (defined $status and $status >= 0 and $status <= 9);
	addComponentStatus("m", "UpdateJobStatus",$statusText[$status])
	    if ($optUpdJobStatus and $rc >= 0);
	return $rc if ($rc == 7);
	if ($optUpdStatus or $optUpdJobStatus) {
	    addStatusTopic("l","Update Job");
	    addKeyLongValue("l", "UpdateStartTime", gmctime($starttime)) 
		if ($starttime  and $starttime > 0);
	    addKeyLongValue("l", "LogFile", $logfile);
	    addKeyLongValue("l", "ErrorFile", $errfile);
	    addMessage("l","\n");
	    addExitCode(0) if ($optUpdJobStatus and $optUpdJobStatus==1 and $rc == 5);
	    addExitCode(1) if ($optUpdJobStatus and $optUpdJobStatus==1 and $rc == 6);
	}
	return $rc;
  } # agentUpdateJobStatus

  sub agentGetUpdateConfigSettings {
	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;

	#### BUILD
	my @updConfParams = (
	    "UpdRepositoryPath",
	    "UpdRepositoryAccess",
	    "UpdRepositoryUserId",
	    "UpdRepositoryPassword",
	    "UpdUpdateCheckMode",
	    "UpdDownloadMode",
	    "UpdDownloadServerAddress",
	    "UpdDownloadRepositoryPath",
	    "UpdDeleteBinaryAfterUpdate",
	    "UpdScheduleDate",
	    "UpdScheduleFrequency",
	    "UpdDownloadProtocol",
	    "UpdAlertNewUpdates",
	    "UpdAlertJobFinished",
					    
	    "HttpProxyServerUsage",
	    "HttpProxyServerAddress",
	    "HttpProxyServerPort",
	    "HttpProxyServerUserId",
	    "HttpProxyServerPasswd",
	);
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd(); 
	    foreach my $key (@updConfParams) {
		agentJson_AddCmd($refArrayCmd,$key);
	    } # foreach
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### 
	my $save_variableVerboseMessage = $variableVerboseMessage;
	$variableVerboseMessage = '';
	if ($optOutdir) {
	    addMessage("v","#\tUpdAlertJobFinished (uint16) - (0=disable,1=enable)\n");
	    addMessage("v","#\tUpdAlertNewUpdates (uint16) - (0=disable,1=enable)\n");
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
	    addMessage("v","#\t    (Default(e.g.)=/opt/fujitsu/ServerViewSuite/EM_UPDATE/UpdateRepository)\n");
	    addMessage("v","#\tUpdRepositoryUserId (string)\n");
	    addMessage("v","#\tUpdScheduleDate (uint64) - (time_t seconds)\n");
	    addMessage("v","#\tUpdScheduleFrequency (uint64) - number of days\n");
	    addMessage("v","#\tUpdUpdateCheckMode (uint16) - (0=manually,1=aftermodification,2=scheduler)\n");
	    addMessage("v","#\tConfHttpProxyServerUsage (uint16) - (0=no,1=systemconfig,2=userconfig)\n");
	    addMessage("v","#\tConfHttpProxyServerPort (uint32)\n");
	    addMessage("v","#\tConfHttpProxyServerAddress (string)\n");
	    addMessage("v","#\tConfHttpProxyServerId (string)\n");
	    addMessage("v","#\tConfHttpProxyServerPasswd (string)\n");
	}
	#### SPLIT and EVAL
	my $refCmd = agentJson_ExtractCmd($providerout);
	    foreach my $key (@updConfParams) {
		my $value = agentJson_GetCmdSimpleData($refCmd,$key);
		addKeyIntValue("l",$key, $value) if (defined $value and $value !~ m/^\s*$/
			and $key ne "UpdRepositoryPassword" and $key ne "UpdScheduleDate"
			and $key ne "UpdRepositoryPath" and $key ne "ConfHttpProxyServerPasswd");
		addKeyLongValue("l",$key, $value) if (defined $value
			and $key eq "UpdRepositoryPath");
		addKeyIntValue("l",$key, "****") if (defined $value and $value !~ m/^\s*$/
			and ($key eq "UpdRepositoryPassword" or $key eq "ConfHttpProxyServerPasswd"));
		addKeyLongValue("l",$key, gmctime($value)) if ($value
			and $key eq "UpdScheduleDate");
		if ($optOutdir) {
		    addKeyIntValue("v",$key, $value) if (defined $value and $value !~ m/^\s*$/);
		    addKeyIntValue("v","#" . $key, "") if ($key and (!defined $value or $value =~ m/^\s*$/));
		    addMessage("v","\n") if ($key);
		}
	    } # foreach
	####
	if (!$longMessage or $longMessage =~ m/^\s*$/) {
	    addMessage("m", "- [ERROR] The Agent side does not support this functionality");
	    return;
	}
	$exitCode = 0;
	addMessage("m", "Update Config Settings available");
	####
	if ($optOutdir) {
	    $variableVerboseMessage =~ s/^\s+//gm;
	    writeTxtFile($fileHost, "CFG", $variableVerboseMessage);
	} # print file
	$variableVerboseMessage = $save_variableVerboseMessage
  } # agentGetUpdateConfigSettings
  sub agentSetUpdateConfigSettings {
	#### All arguments
	if ($optUpdSetConfig) {
	    my $data = readCommentedTxtFile($optUpdSetConfig);
	    if (!defined $data) {
		addMessage("m"," -") if (!defined $msg);
		addMessage("m", "[ERROR] Unable to read file $optUpdSetConfig");
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
	my $hasKeyError = 0;
	my $wrongKey = undef;
	if (!$optArguments) {
		addMessage("m"," -") if (!defined $msg);
		addMessage("m", "[ERROR] Unable to set configuration - missing arguments");
		return;
	}
	#### check on wrong arguments
	my %properties = splitKeyValueOption($optArguments);
	foreach my $key (keys %properties) {
		#$value = $properties{$key};
		next if (!defined $key);
		$wrongKey = $key;
		$key = $1 if ($key =~ m/Conf(.*)/); # CIM Syntax
		my $oe = $gAgentOE{$key};
		next if ($key and $key eq "UpdAutomaticInstall"); # not realy supported
		$hasKeyError = 1 if (!defined $oe);
		last if ($hasKeyError);
	}
	if ($hasKeyError) {
		addMessage("m"," -") if (!defined $msg);
		addMessage("m", "[ERROR] Unable to set configuration - wrong key '$wrongKey'");
		return;
	}
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd(); 
	    foreach my $key (keys %properties) {
		next if (!defined $key);
		my $value = $properties{$key};
		$key = $1 if ($key =~ m/Conf(.*)/);  # CIM Syntax
		my $oe = $gAgentOE{$key};
		next if ($key and $key eq "UpdAutomaticInstall"); # not realy supported
		next if (!defined $oe);
		next if (!defined $value);
		#$value = "\"$value\"" if ($value !~ m/\d+/);
		agentJson_AddCmd($refArrayCmd,"WriteConfigurationSpace",$key,undef,undef,$value);
	    }
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#*** response contains new values if accepted ***#
	#### SPLIT and EVAL
	my $setWarning = 0;
	my $refCmd = agentJson_ExtractCmd($providerout);
	    foreach my $key (keys %properties) {
		my $setvalue = $properties{$key};
		$key = $1 if ($key =~ m/Conf(.*)/);  # CIM Syntax
		my $oe = $gAgentOE{$key};
		next if ($key and $key eq "UpdAutomaticInstall"); # not realy supported
		next if (!defined $oe);
		next if (!defined $setvalue);
		my $responsevalue = agentJson_GetCmdSimpleData($refCmd,"WriteConfigurationSpace",$key);
		if (!defined $responsevalue and defined $setvalue) {
		    $setWarning = 1;
		} elsif ($setvalue =~ m/^\d+$/) {
		    $setWarning = 1 if ($responsevalue =~ m/^\d+$/ and $setvalue != $responsevalue);
		} else {
		    my $oneSlashResponse = $responsevalue;
		    my $oneSlashSet = $setvalue;
		    # e.g. for win-filename-comparison !
		    $oneSlashResponse =~ s/[\\]+/\\/g;
		    $oneSlashSet =~ s/[\\]+/\\/g;
		    $oneSlashResponse =~ s/[\"\']+//g;
		    $oneSlashSet =~ s/[\"\']+//g;
		    $setWarning = 1 if ($oneSlashResponse ne $oneSlashSet);
		}
	    }
	addExitCode(0) if (!$setWarning);
	addExitCode(1) if ($setWarning);
	if ($setWarning) {
	    addMessage("m","There are differences of values to-be-set and stored values - check configuration");
	}
  } # agentSetUpdateConfigSettings

  sub agentStartUpdateCheck {
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmServerStartCheck");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	addExitCode(0);
	addMessage("m","StartUpdateCheck(Started)");
  } # agentStartUpdateCheck
  sub agentGetUpdateCheckLogData {
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmServerUpdateCheckLogFile");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $logcontent = agentJson_GetCmdSimpleData($refCmd,"UmServerUpdateCheckLogFile"); 
	addMessage("l",$logcontent) if ($logcontent);
	addExitCode(0) if (defined $logcontent and $logcontent !~ m/^\s*$/);
	addMessage("m","Empty Update Check Logfile ") if ($exitCode);
  } # agentGetUpdateCheckLogData

  sub agentUpdateDiffTable {
	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

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
	    addMessage("m", " -") if ($msg);
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
	$exitCode = 0 if ($exitCode == 3);
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # agentUpdateDiffTable
  sub agentUpdateInstTable {
	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

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
	    addMessage("m", " -") if ($msg);
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
	$exitCode = 0 if ($exitCode == 3);
	$variableVerboseMessage = $save_variableVerboseMessage;
  } # agentUpdateInstTable
  sub agentUpdateReleaseNotes {
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
	    addMessage("m", " -") if ($msg);
	    addMessage("m","No update component list available") if (!$nrComponent);
	    return if (!$nrComponent);
	}
	my @compOI = ();
	{ # get components ranking
	    #### BUILD
		(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$nrComponent;$i++) {
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentPath", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRepos2InstRanking", undef, $i);
		    #agentJson_AddCmd($refArrayCmd,"UmDiffReleaseNotes", undef, $i);
		} # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $repos2InstRanking = agentJson_GetCmdSimpleData($refCmd,"UmDiffRepos2InstRanking", undef, $i);
		my $componentPath = agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentPath", undef, $i);
		my $oneSlashComponentPath = $componentPath;
		$oneSlashComponentPath =~ s/[\\]+/\\/g;
		next if ($optGetOneReleaseNote and $oneSlashComponentPath 
		    and $oneSlashComponentPath ne $optGetOneReleaseNote);
		next if ($optGetDiffReleaseNotes 
		    and $repos2InstRanking and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );
		push (@compOI, $i);
		last if ($optGetOneReleaseNote and $componentPath 
		    and $componentPath eq $optGetOneReleaseNote);
	    } # for
	} # components
	####
	if ($#compOI >= 0) {
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
	    foreach my $i (@compOI) {
		agentJson_AddCmd($refArrayCmd,"UmDiffComponentPath", undef, $i);
		agentJson_AddCmd($refArrayCmd,"UmDiffReleaseNotes", undef, $i);
	    } # foreach
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    foreach my $i (@compOI) {
		my $componentPath = agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentPath", undef, $i);
		my $relnote = agentJson_GetCmdSimpleData($refCmd,"UmDiffReleaseNotes", undef, $i);
		if (!$relnote) {
		    addStatusTopic("l","UNKNOWN", "ReleaseNote", $componentPath);
		    addMessage("l","\n");
		} else {
		    addStatusTopic("l","AVAILABLE", "ReleaseNote", $componentPath)
			if (!$optGetOneReleaseNote);
		    addMessage("l","\n");
		    addMessage("l","$relnote\n\n");
		    $exitCode = 0;
		}
	    } # foreach
	} # get release notes
	if ($exitCode) {
	    addMessage("m","- Unable to get release notes");
	} else {
	    addMessage("m","- Found release notes") if (!$optGetOneReleaseNote);
	}
  } # agentUpdateReleaseNotes

  sub agentUpdateJobCleanup {	
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobCleanup");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	if ($optCleanupUpdJob) {
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my $rcAction = agentJson_GetCmdSimpleData($refCmd,"UmJobCleanup");  
	    if (defined $rcAction) {
		addExitCode(0);
		addMessage("m","CleanUpdateJob(Started)");
		addKeyValue("m","Startcode",$rcAction) if ($rcAction);
	    } else {
		addExitCode(2);
		addMessage("m","Unexpected response of cleanup update job action");
	    }
	} # only Cleanup
  } # agentUpdateJobCleanup
  sub agentUpdateJobStartTime {
	my $settime = shift;
	return if (!defined $settime or $settime !~ m/^\d+$/);
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobSetStartTime",undef,undef,undef,$settime);
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### EVAL
	if (defined $optUpdJobStartTime) {
	    addExitCode(0);
	}
  } # agentUpdateJobStartTime
  sub agentUpdateJobInstTable {
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
	my %hashList = ();
	{ # get components
	    #### BUILD
		(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();
		for (my $i=0;$i<$nrComponent;$i++) {
		    agentJson_AddCmd($refArrayCmd,"UmDiffComponentPath", undef, $i);
		    agentJson_AddCmd($refArrayCmd,"UmDiffRepos2InstRanking", undef, $i);
		} # for
	    #### CALL REST/JSON
		(my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $componentPath = agentJson_GetCmdSimpleData($refCmd,"UmDiffComponentPath", undef, $i);
		my $repos2InstRanking = agentJson_GetCmdSimpleData($refCmd,"UmDiffRepos2InstRanking", undef, $i);
		
		my $needsupdate = 1;
		$needsupdate = 0 if ($repos2InstRanking 
		    and ($repos2InstRanking < 0 or $repos2InstRanking > 2) );
		$hashList{$componentPath} = $needsupdate;
	    } # for
	} # components
	####
	return ($nrComponent,%hashList);
  } # agentUpdateJobInstTable
  sub agentUpdateJobListComponentPaths {
	my $getList = shift;
	my $nrComponent = 0;
	my %hashList = ();
	{ # nr of Update Job Components
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobNumberComponents");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    $nrComponent = agentJson_GetCmdSimpleData($refCmd,"UmJobNumberComponents");   
	}
	if ($optUpdJobList) {
	    if (!$nrComponent) {
		addMessage("m", " -") if ($msg);
		addMessage("m","No job update component list available");
		return 0 if (!$nrComponent);
	    } elsif ($nrComponent) {
		addExitCode(0);
		addMessage("m", " -") if ($msg);
		addMessage("m","NumberOfComponents=$nrComponent");
	    }
	}
	if ($optUpdJobList or ($nrComponent and $getList)) {
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    for (my $i=0;$i<$nrComponent;$i++) {
		agentJson_AddCmd($refArrayCmd,"UmJobComponentPath",undef,$i);
	    } # for
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $path = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentPath",undef,$i);
		if ($optUpdJobList) {
		    addStatusTopic("l",undef,"JobComponent",$i);
		    addKeyLongValue("l","Path", $path);
		    addMessage("l","\n");
		} else {
		    $hashList{$path} = 1;
		}
	    } # for
	} #optUpdJobList or internal list
	return wantarray ? ($nrComponent, %hashList) : $nrComponent;
	return $nrComponent;
  } # agentUpdateJobListComponentPaths
  sub agentUpdateJobAddtoComponentPath {
	my $refComponents = shift;
	my $file = undef;
	my @fileComponentArray = ();
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
		push (@fileComponentArray, $singleComponent) if ($singleComponent);
		$data =~ s/^[^\n]+\n//;
		$data = undef if ($data =~ m/^\s*$/m);
	    }
	} # file
	else {
	    @fileComponentArray  = @$refComponents;
	}
	(my $nrcomp, my %hashJobList) = agentUpdateJobListComponentPaths(1);
	$nrcomp = 0 if (!$nrcomp);
	my $rc = 0;
	#### CHECK EXISTING job components
	my @jobComponentArray = ();
	    foreach $singleComponent (@fileComponentArray) {
		next if (!defined $singleComponent);
		if ($hashJobList{$singleComponent}) {
		    addStatusTopic("l","EXISTS","AddUpdateComponent",$singleComponent);
		    addMessage("l","\n");
		    $rc = 1 if ($rc != 2);
		    $exitCode = 1	if ($optUpdJobAdd);
		    addMessage("m", "there is an error hint concerning add of component")
			if ($optUpdJobAdd and (!defined $msg or $msg =~ m/^\s*$/));
		} else {
		    push (@jobComponentArray, $singleComponent);
		}
	    } # foreach
	    return $nrcomp if ($#jobComponentArray <0);
	#### CHECK INST LIST
	my @componentArray = ();
	(my $nrInst, my %hashInstList) = agentUpdateJobInstTable();
	    foreach $singleComponent (@jobComponentArray) {
		next if (!defined $singleComponent);
		if (!defined $hashInstList{$singleComponent}) {
		    addStatusTopic("l","UNKNOWN","AddUpdateComponent",$singleComponent);
		    addMessage("l","\n");
		    $rc = 1 if ($rc != 2);
		    $exitCode = 1	if ($optUpdJobAdd);
		    addMessage("m", "there is an error hint concerning add of component")
			if ($optUpdJobAdd and (!defined $msg or $msg =~ m/^\s*$/));
		} elsif (!$hashInstList{$singleComponent}) {
		    addStatusTopic("l","UPTODATE","AddUpdateComponent",$singleComponent);
		    addMessage("l","\n");
		    $rc = 1 if ($rc != 2);
		    $exitCode = 1	if ($optUpdJobAdd);
		    addMessage("m", "there is an error hint concerning add of component")
			if ($optUpdJobAdd and (!defined $msg or $msg =~ m/^\s*$/));
		} else {
		    push (@componentArray, $singleComponent);
		}
	    } # foreach
	    return $nrcomp if ($#componentArray <0);
	    $exitCode = 3;
	    $msg = undef;
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    foreach $singleComponent (@componentArray) {
		next if (!$singleComponent);
		agentJson_AddCmd($refArrayCmd,"UmJobSetComponentPath",undef,$nrcomp,undef,$singleComponent);
		$nrcomp++;
	    } # foreach
	#### CALL REST/JSON
	($rc, my $providerout) = agentJson_CallCmd($refMain);
	    return -1 if ($rc == 2);
	#### SPLIT
	$nrcomp = agentUpdateJobListComponentPaths();
	$nrcomp = 0 if (!$nrcomp);
	if ($optUpdJobAdd) {
	    addExitCode(0);
	    addKeyIntValue("m","JobComponentNumber",$nrcomp);
	}
	return $nrcomp;
  } # agentUpdateJobAddtoComponentPath
  sub agentStartUpdateJob {
	my $callStart = 0;
	$callStart = 1 if (($optStartUpdJobList or $optStartUpdJobAll or $optStartUpdJob)
	and !defined $optUpdJobAdd and !defined $optUpdJobList and !defined $optCleanupUpdJob);
	#### Cleanup
	if (!defined $optUpdJobAdd and !defined $optUpdJobList and !defined $optStartUpdJobList) 
	{
	    agentUpdateJobCleanup();
	}
	#### Start Time
	if (defined $optUpdJobStartTime and $optUpdJobStartTime) {
	    agentUpdateJobStartTime($optUpdJobStartTime);
	} elsif ($callStart or defined $optUpdJobStartTime) {
	    agentUpdateJobStartTime(0);
	}
	#### Prepare All
	if ($optStartUpdJobAll) {
	    my @componentArray = ();
	    (my $nrInst, my %hashInstList) = agentUpdateJobInstTable();
	    foreach my $comp (keys %hashInstList) {
		my $mode = $hashInstList{$comp};
		push (@componentArray, $comp) if ($mode); # needs update
	    } # foreach
	    if ($#componentArray < 0) {
		addMessage("m","no update job components found"); 
		return;
	    }
	    my $rc = agentUpdateJobAddtoComponentPath(\@componentArray);
	    return if ($rc < 0);
	} # all
	#### Add
	if ($optStartUpdJob or $optUpdJobAdd) { # selection by file
	    my $rc = agentUpdateJobAddtoComponentPath();
	    return if ($rc < 0);
	}
	#### List
	if ($optStartUpdJob or $optUpdJobList or $optStartUpdJobAll) {
	    #$optArguments = undef;
	    my $nrpaths = agentUpdateJobListComponentPaths();
	    if (!$nrpaths) {
		addMessage("m","no update job components found"); 
		return; # There are no components
	    }
	}
	#return if ($main::verboseTable and $main::verboseTable == 999);
	#### Start
	if ($callStart) {
	    my $updateAllFlag = 0;
	    #$updateAllFlag = 1 if ($optStartUpdJobAll); # Agent says that this does not work in V7
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
		agentJson_AddCmd($refArrayCmd,"UmJobStartJob",undef,undef,undef,$updateAllFlag);
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my $rcAction = agentJson_GetCmdSimpleData($refCmd,"UmJobStartJob");  
	    if (defined $rcAction) {
		addExitCode(0);
		addMessage("m","StartUpdateJob(Started)");
		addKeyValue("m","Startcode",$rcAction) if ($rcAction);
	    } else {
		addExitCode(2);
		addMessage("m","Unexpected response of start update job action");
	    }	    
	}
  } # agentStartUpdateJob
  sub agentUpdateJobComponentsLog {
	my $nrComponent = agentUpdateJobListComponentPaths();
	if (!$nrComponent) {
	    addComponentStatus("m", "UpdateJobInformation","UNAVAILABLE");
	    return if (!$nrComponent);
	}
	if ($nrComponent) {
	    addComponentStatus("m", "UpdateJobInformation","AVAILABLE");
	    addExitCode(0);
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    #"UmJobComponentPath"			=> 0x33A1,
	    for (my $i=0;$i<$nrComponent;$i++) {
		agentJson_AddCmd($refArrayCmd,"UmJobComponentPath",undef,$i);
		agentJson_AddCmd($refArrayCmd,"UmJobComponentStartTime",undef,$i);
		agentJson_AddCmd($refArrayCmd,"UmJobComponentEndTime",undef,$i);
		agentJson_AddCmd($refArrayCmd,"UmJobComponentStatus",undef,$i);
		agentJson_AddCmd($refArrayCmd,"UmJobComponentReturnCode",undef,$i);
		agentJson_AddCmd($refArrayCmd,"UmJobComponentErrorText",undef,$i);
	    } # for
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my @statusText = ( "Waiting",
		"Downloading", "Downloaded", "Updating", "Updated", "Done - OK",
		"Done - Error", "No job defined", "Rescanning", "Rebooting", "undefined",
		"..unexpected..",
	    );
	    for (my $i=0;$i<$nrComponent;$i++) {
		my $path = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentPath",undef,$i);
		my $start = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentStartTime",undef,$i);
		my $end = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentEndTime",undef,$i);
		my $status = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentStatus",undef,$i);
		my $code = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentReturnCode",undef,$i);
		my $text = agentJson_GetCmdSimpleData($refCmd,"UmJobComponentErrorText",undef,$i);
		$status = 11 if (defined $status and ($status < 0 or $status > 9));
		$status = 10 if (!defined $status);
		addStatusTopic("l",undef,"ComponentLog", $i);
		addKeyIntValue("l", "ReturnCode", $code);
		addKeyLongValue("l", "ReturnStatus", $statusText[$status]);
		addKeyLongValue("l", "LogText", $text);
		addKeyLongValue("l", "StartTime", gmctime($start)) if ($start);
		addKeyLongValue("l", "EndTime", gmctime($end)) if ($end);
		addMessage("l","\n");
	    } # for
	} # get data
  } # agentUpdateJobComponentsLog
  sub agentUpdateJobLogFile {	
	#### BUILD
	(my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobLogFileName");
	    agentJson_AddCmd($refArrayCmd,"UmJobErrorFileName");
	#### CALL REST/JSON
	(my $rc, my $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	my $refCmd = agentJson_ExtractCmd($providerout);
	    my $logfile = agentJson_GetCmdSimpleData($refCmd,"UmJobLogFileName");  
	if (!$logfile) {
	    addMessage("m","GetUpdateJobLogFile(NOLOGFILE)");
	    return;
	}
	
	#### BUILD
	($refMain, $refArrayCmd) = agentJson_CreateJsonCmd();  
	    agentJson_AddCmd($refArrayCmd,"UmJobReadLogFile",undef,undef,undef,$logfile);
	#### CALL REST/JSON
	($rc, $providerout) = agentJson_CallCmd($refMain);
	    return if ($rc == 2);
	#### SPLIT
	$refCmd = agentJson_ExtractCmd($providerout);
	    my $content = agentJson_GetCmdSimpleData($refCmd,"UmJobReadLogFile");
	#### EVAL
	if (!$content) {
	    addMessage("m","GetUpdateJobLogFile(UNAVAILABLE)");
	    return;
	}
	addMessage("l",$content);
	$exitCode = 0;
  } # agentUpdateJobLogFile
  sub agentCancelUpdateJob {
	#### component list ?
	my $nrComponent = agentUpdateJobListComponentPaths();
	if (!$nrComponent) {
	    addMessage("m", "No update job running - the job component list is empty");
	    return;
	}
	#### Status ?
	my @statusText = ("Waiting", 
	    "Downloading", "Downloaded", "Updating", "Updated", "Done - OK", 
	    "Done - Error", "No job defined", "Rescanning", "Rebooting",
		    "..unexpected..", "undefined",
	);
	my $status = agentUpdateJobStatus();
	if (defined $status and $status >= 5) {
	    my $text = $statusText[$status];
	    addMessage("m", "No update job running at the moment - status is \"$text\"");
	    return;
	}
	#### Cancel
	{
	    #### BUILD
	    (my $refMain, my $refArrayCmd) = agentJson_CreateJsonCmd();  
		agentJson_AddCmd($refArrayCmd,"UmJobCancelJob");
	    #### CALL REST/JSON
	    (my $rc, my $providerout) = agentJson_CallCmd($refMain);
		return if ($rc == 2);
	    #### SPLIT
	    my $refCmd = agentJson_ExtractCmd($providerout);
	    my $rcAction = agentJson_GetCmdSimpleData($refCmd,"UmJobCancelJob");  
	    if (defined $rcAction) {
		addExitCode(0);
		addMessage("m","CancelUpdateJob(Started)");
		addKeyValue("m","Startcode",$rcAction) if ($rcAction);
	    } else {
		addExitCode(2);
		addMessage("m","Unexpected response of cancel update job action");
	    }
	}
  } # agentCancelUpdateJob
#########################################################################
# iRMC/eLCM								#
#########################################################################
  sub iRMCConnectionTest { 
	$optRestHeaderLines = "Accept: application/json";
	my $save_optConnectTimeout = $optConnectTimeout;
	$optConnectTimeout  = 20 if (!defined $optConnectTimeout or $optConnectTimeout > 20);
	(my $out, my $outheader, my $errtext) = 
		restCall("GET","/sessionInformation",undef);
	#
	if ($out and $out =~ m/^\s*\{/) { # must be a JSON answer
	    $optServiceType = "iRMC" if ($out);
	    addExitCode(0);
	}
	if ($out and $out =~ m/ServerView Remote Management/) {
	    addMessage("l","[ERROR] Detected iRMC - but no REST service available\n");
	    addExitCode(1); # prevent SCS test
	}
	if ($exitCode == 0 and $optChkIdentify) {
	    addMessage("m","- ") if (!$msg);
	    addKeyLongValue("m","REST-Service", "iRMC REST Service V0");
	}
	$optRestHeaderLines = undef;
	$optConnectTimeout = $save_optConnectTimeout;
  } # iRMCConnectionTest
#########################################################################
# UPDATE								#
#########################################################################
  sub getUpdateSystemStatus {
	return agentUpdateSystemStatus() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type\n");
	return 4;
  } #getUpdateSystemStatus
  sub getUpdateCheckStatus {
	my $sysrc = shift;
	return $sysrc if ($sysrc == 4);
	return agentUpdateCheckStatus() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type\n");
	return -1;
  } #getUpdateCheckStatus
  sub getUpdateJobStatus {
	my $sysrc = shift;
	return $sysrc if ($sysrc == 4);
	return agentUpdateJobStatus() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type\n");
	return -1;
  } #getUpdateJobStatus
  sub getUpdateStatus {
	my $sysstatus = 4;
	$sysstatus = getUpdateSystemStatus();
	getUpdateCheckStatus($sysstatus) if ($exitCode != 2 and $optUpdCheckStatus);
	getUpdateJobStatus($sysstatus) if ($exitCode != 2 and $optUpdJobStatus);
	return $sysstatus;
  } #getUpdateStatus

  sub getUpdateConfigSettings {
	return agentGetUpdateConfigSettings() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #getUpdateConfigSettings
  sub setUpdateConfigSettings {
	return agentSetUpdateConfigSettings() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #setUpdateConfigSettings

  sub startUpdateCheck {
	return agentStartUpdateCheck() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #startUpdateCheck
  sub getUpdateCheckLogData {
	return agentGetUpdateCheckLogData() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #getUpdateCheckLogData

  sub getUpdateDiffTable {
	return agentUpdateDiffTable() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } # getUpdateDiffTable
  sub getUpdateInstTable {
	return agentUpdateInstTable() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } # getUpdateInstTable
  sub getUpdateReleaseNotes {
	return agentUpdateReleaseNotes() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #getUpdateReleaseNotes

  sub startUpdateJob {
	return agentStartUpdateJob() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #startUpdateJob
  sub getUpdateJobComponentsLog {
	return agentUpdateJobComponentsLog() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #getUpdateJobComponentsLog
  sub getUpdateJobLogFile {
	return agentUpdateJobLogFile() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #getUpdateJobLogFile
  sub cancelUpdateJob {
	return agentCancelUpdateJob() 
	    if ($optServiceType and $optServiceType =~ m/^A/i);
	addMessage("m","This action is not allowed for this service type");
  } #cancelUpdateJob

  sub processUpdateManagement {
	return if (!$optUpdate);
	my $sysstatus = undef;
	$sysstatus = getUpdateStatus();

	if (!defined $sysstatus or $sysstatus == 4) {
	    addMessage("m", "Unable to get ServerView REST Information");
	    $msg = "- " . $msg if ($msg);
	    return;
	}
	return if ($exitCode==2); # auth error

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
				or  defined $optUpdJobStartTime);
	cancelUpdateJob()	if ($optCancelUpdJob);
	getUpdateJobLogFile()	if ($optUpdJobLogFile);
	getUpdateJobComponentsLog() if ($optUpdJobComponentLog);

	$msg = "- " . $msg if ($msg);
  } #processUpdateManagement
#########################################################################
  sub connectionTest {
	my $checknext = 1;
	$exitCode = 3;
	{
	    $exitCode = 3 if ($exitCode != 0);
	    iRMCConnectionTest()	if (!$optServiceType or $optServiceType =~ m/^ir/i
		or $optServiceType =~ m/^i/);
	    $checknext = 0 if ($exitCode == 0);
	    $checknext = 0 if ($exitCode == 1); # prevent SCS call
	}
	if ($checknext) {
	    $exitCode = 3 if ($exitCode != 0);
		# check of 3172 after iRMC because of bad Remote Manager on 3172
	    agentConnectionTest()	if (!$optServiceType or $optServiceType =~ m/^A/i);
	    $checknext = 0 if ($exitCode == 0);
	}
	if ($checknext and $optServiceType and $optServiceType !~ m/^A/i) {
		addMessage("m","- This action is not allowed for this service type");
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

#########################################################################
sub processData {
	my $discoveredType = 0;
	# Check Availability and Type:
	if (!$optTimeout) {
	    alarm(60);
	}
	connectionTest(); # includes --chkidentify
	return if ($exitCode != 0);

	if ($optServiceType and  $optUpdate) {
	    $exitCode = 3;
	    processUpdateManagement();
	} 
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


