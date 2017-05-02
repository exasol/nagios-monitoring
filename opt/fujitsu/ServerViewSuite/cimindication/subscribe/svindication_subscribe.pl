#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.20.00
# Date:		2015-11-03

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
=head1 NAME

svindication_subscribe.pl - Administer ServerView CIM indication subscriptions

=head1 SYNOPSIS

svindication_subscribe.pl 
  {  -H|--host=<host>
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      [-U|--use=<mode>]
      [-S|--service=<mode>]
      [--cacert=<cafile>]
      [--cert=<certfile> --privkey=<keyfile>] 
      { -u|--user=<username> -p|--password=<pwd> 
    } |
    -I|--inputfile=<filename>
    { [--list] |
      --add=<listenerhost> 
        [--listport=<listenerport>] 
        [--listttransport=<listenertype>] |
      --remove=<listenerhost>
        [--listport=<listenerport>] 
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Administer ServerView CIM indication subscriptions.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server.

This address are used for wbemcli or openwsman calles without any preliminary checks.

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


=item --list

List all ServerView subscribe registrations

=item --add=<listenerhost> [--listport=<listenerport>] [--listttransport=<listenertype>]

Add one listener to the ServerView subscribe registrations. 

listenerhost: Please enter an IP address or a DNS name to be used by the remote system
to address the listner. This host will also be used to identify this subscription.

listenerport: Default 3169 for the svcimlistenerd. Add alternative port number if the
listener is started for a different port.

listenertype: Default is https. Use "http" if the target remote service is unable
to send indications via https.

=item --remove=<listenerhost>

Remove one listener in the ServerView subscribe registrations.

listenerhost: Please enter the IP address or the DNS name with which the listener was added.





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
our $optInvoke = undef;
our $optModify = undef;
our	$optKeys	= undef;
our	$optArguments	= undef;
our	$optMethod	= undef;

# init other action options
our $optList		= undef;
our $optAdd		= undef;
our   $optListenerPort		= 3169;
our   $optListenerTransport	= "https";
our $optRemove		= undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::scriptPath = undef;

#### GLOBAL DATA BESIDE OPTIONS

# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# init output data
our $exitCode = 3;
our $error = '';
our $msg = '';
our $notifyMessage = '';
our $longMessage = '';
our $variableVerboseMessage = '';

# init some multi used processing variables (CIM)
our $clientSession = undef;

# CIM
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
our $is2014Profile = undef;

# CIM central ClassEnumerations to be used by multiple functions:
our $cimOS = undef;
our $cimOSDescription = undef;
our @cimSvsComputerSystem = ();
our @cimSvsOperatingSystem = ();
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
	exit($tmpExitCode);
  }
#----------- miscelaneous helpers 
=begin COMMENT
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
=end COMMENT
=cut

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

=begin COMMENT
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
=end COMMENT
=cut
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
####
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

			"list",
			"add=s",
			"remove=s",
			"listport=i",
			"listtransport=s",

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

	
			"list",
			"add=s",
			"remove=s",
			"listport=i",
			"listtransport=s",


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
	$k="vtab";	$main::verboseTable = $options{$k}	if (defined $options{$k});

	$k="invoke";	$optInvoke	= $options{$k}		if (defined $options{$k});
	$k="keys";	$optKeys	= $options{$k}		if (defined $options{$k});
	$k="modify";	$optModify	= $options{$k}		if (defined $options{$k});
	$k="method";	$optMethod	= $options{$k}		if (defined $options{$k});
	$k="arguments";	$optArguments	= $options{$k}		if (defined $options{$k});

	$k="list";	$optList	= $options{$k}		if (defined $options{$k});
	$k="add";	$optAdd		= $options{$k}		if (defined $options{$k});
	$k="remove";	$optRemove	= $options{$k}		if (defined $options{$k});
	$k="listport";		$optListenerPort	= $options{$k}	if (defined $options{$k});
	$k="listtransport";	$optListenerTransport	= $options{$k}	if (defined $options{$k});

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
	if (!defined $optAdd and !defined $optList and !defined $optRemove) {
		$optList = 999;
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
our $wbemCimInteropForm = " '%s://%s:%s@%s/root/interop:%s'";	# CIM_Indication*
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
	} elsif ($class =~ m/^12_LSIESG_.*/) { # HACK
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
	####$wbemFlexibleForm
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

	# host and port
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
		if (!defined $retCode and $tmpStream =~ m/^$host/) {
		    $tmpStream =~ m/($method.*)/;
		    $retCode = $1 if ($1);
		    $retCode =~ s/$method:\s+// if (defined $retCode);
		} elsif (defined $retCode and $tmpStream =~ m/^$host/) {
		    $tmpStream = '';
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
			if (!$foundThis and $tmpStream =~m/^$outparam:/) {
			    $stream .= "</$currentOutParam>" 
				if ($currentOutParam);
			    $tmpStream =~ s/^$outparam://;
			    $tmpStream =~ s/^\s+//;
			    $tmpStream = "<$outparam>" . $tmpStream;
			    $currentOutParam = $outparam;
			    $foundThis = 1;
			}
		    } # foreach
		    $stream .= $tmpStream;
		} else {
		    $stream .= $tmpStream;
		}
		print if ($main::verbose >= 60); # $_
	}
	$stream =~ s/\s+$// if ($stream);
	$stream .= "</$currentOutParam>" if ($currentOutParam);
	if (! defined $retCode) { ###### ERROR CASE
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
	print "**** close pipe ...\n" if ($main::verbose > 20); 
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
	$cmd .= " -v $main::verbose" if ($main::verbose and $main::verbose >= 10);
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
	if ($optInvoke and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "- ");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	    addMessage("l", $outstream) if ($outstream);
	}
	$outstream =~ s/^OriginClass[^\n]+//m if ($outstream and $main::verbose >= 10);
	print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	$outstream = $retCode if (!defined $outstream);
	$outstream = undef if ($outstream and $outstream =~ m/^\s*$/);
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
	return $outstream;
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
# SUBSCRIPTION HELPER							#
#########################################################################
  sub getIndicationRegistrationService_SystemNameKey {
	my $systemName = undef;
	my @classInstances = ();
	@classInstances = cimEnumerateClass("SVS_PGYIndicationRegistrationService");
	cimPrintClass(\@classInstances, "SVS_PGYIndicationRegistrationService");
	if ($#classInstances < 0) {
	    return undef;
	}
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		$systemName = $oneClass{"SystemName"}; 
	} #foreach instance (should be only one)
	return $systemName;
  } #getIndicationRegistrationService_SystemNameKey
  sub storeIndicationRegistrationService_Keys {
	# keys CIM_Service: SystemCreationClassName, SystemName, CreationClassName, Name
	$optKeys = undef;
	my $systemName = undef;
	$systemName = getIndicationRegistrationService_SystemNameKey();
	if (!defined $systemName) {
	    return 3;
	}
	$optKeys = "SystemCreationClassName=SVS_PGYComputerSystem";
	$optKeys .= ",SystemName=$systemName";
	$optKeys .= ",CreationClassName=SVS_PGYIndicationRegistrationService";
	$optKeys .= ",Name=RegistrationService";
	return 0;
  } #storeIndicationRegistrationService_Keys
  sub getListenerURL {
	my $save_notifyMessage = $notifyMessage;
	my %hashUrl = ();
	my @classInstances = ();

	# SFCB
	@classInstances = cimEnumerateClass("/root/interop:CIM_ListenerDestinationCIMXML");
	cimPrintClass(\@classInstances, "/root/interop:CIM_ListenerDestinationCIMXML");

	# Pegasus
	if ($#classInstances < 0) {
	    @classInstances = cimEnumerateClass("/root/svs:CIM_ListenerDestinationCIMXML");
	    cimPrintClass(\@classInstances, "/root/svs:CIM_ListenerDestinationCIMXML");
	}
	foreach my $refClass (@classInstances) {
		next if !$refClass;
		my %oneClass = %{$refClass};
		my $destination = $oneClass{"Destination"}; 
		my $name = $oneClass{"Name"}; 
		$name =~ s/^[^\#]*\#// if ($name);
		$hashUrl{$name} = $destination;
	} #foreach instance (should be only one)
	# Windows
	if ($#classInstances < 0) {
	    @classInstances = cimEnumerateClass("SVS_PGYWMIListenerCIMXML");
	    cimPrintClass(\@classInstances, "SVS_PGYWMIListenerCIMXML");
	    foreach my $refClass (@classInstances) {
		    next if !$refClass;
		    my %oneClass = %{$refClass};
		    my $destination = $oneClass{"DestinationURL"}; 
		    my $name = $oneClass{"Name"}; 
		    $name =~ s/^[^\#]*\#// if ($name);
		    $hashUrl{$name} = $destination;
	    } #foreach instance (should be only one)
	}
	$notifyMessage = $save_notifyMessage;
	return ( %hashUrl );
  } #getListenerURL

#########################################################################
# SUBSCRIPTIONS								#
#########################################################################
=begin COMMENT
w.pl -H 172.17.49.37 -IAUTH/ABG/WINAGT.txt -UW -P5985 -SW -Thttp -CSVS_PGYIndicationRegistrationService --invoke --method ListRegistrations --key SystemName=YLSK000558,SystemCreationClassName=SVS_PGYComputerSystem,CreationClassName=SVS_PGYIndicationRegistrationService,Name=RegistrationService  -v60

u.pl -H 172.17.49.37 -IAUTH/ABG/WINAGT.txt -UW -P5985 -SW -Thttp -CSVS_PGYIndicationRegistrationService --invoke --key SystemName=YLSK000558,SystemCreationClassName=SVS_PGYComputerSystem,CreationClassName=SVS_PGYIndicationRegistrationService,Name=RegistrationService --method UnRegisterRegistrationsByTag --arg "Tag=SvNagios.172.17.55.216" -v60

=end COMMENT
=cut

  sub splitWbemcliRegistrationListOutArrays {
	my $allHandles = shift;
	my $allTags = shift;
	my @outTags = ();
	my @outHandles = ();
	return ( @outTags, @outHandles) if (!$allHandles);
	if ($allHandles and !defined $allTags and $allHandles =~ m/Tags:/) { 
	    # wbemcli error concerning \n delimiter
	    $allTags = $1 if ($allHandles =~ m/.*Tags:(.*)$/);
	    $allHandles =~ s/Tags:.*//;
	}
	elsif ($allHandles and !defined $allTags) { 
	    # very old CIM Provider
	    if ($allHandles) {
	    }
	}
	if ($allHandles and $allTags) {
	    # Tags
	    while ($allTags) {
		my $single = undef;
		$single = $1 if ($allTags =~ m/^([^,]*)/);
		$allTags = undef if (!$single);
		next if (!$single);
		$single =~ s/\s*$//;
		push (@outTags, $single);
		$allTags =~ s/^[^,]*//;
		$allTags =~ s/^,//;
	    }
	    # Handles
	    if ($allHandles =~ m/root.interop/) {
		$allHandles =~ s!root/interop\:CIM_IndicationSubscription!\nroot/interop:CIM_IndicationSubscription!g;
	    } elsif ($allHandles =~ m/root.svs/) {
		$allHandles =~ s!root/svs\:CIM_IndicationSubscription!\nroot/svs:CIM_IndicationSubscription!g;
	    } else {
		$allHandles =~ s!CIM_IndicationSubscription\.Filter!\nCIM_IndicationSubscription.Filter!g;
	    }
	    #CIM_IndicationSubscription.Filter
	    $allHandles =~ s/^\n//;
	    while ($allHandles) {
		my $single = undef;
		$single = $1 if ($allHandles =~ m/^([^\n]*)/);
		$single =~ s/,$// if ($single);
		$allHandles = undef if (! defined $single);
		next if (! defined $single);
		push (@outHandles, $single);
		$allHandles =~ s/^[^\n]*//;
		$allHandles =~ s/^\n//;
	    }
	}
	return (\@outTags, \@outHandles); 
	# ATTENTION - this must be references of arrays otherwise Perl makes
	# one array out of these
  } #splitWbemcliRegistrationListOutArrays
  sub registrationList {
	#
	# SVS_PGYIndicationRegistrationService->ListRegistrations
	# KEYS	SystemCreationClassName, SystemName, CreationClassName, Name
	# IN	- 
	# OUT	RegistrationHandle[] Tags[]
	$optKeys = undef;
	storeIndicationRegistrationService_Keys();
	return if (!$optKeys);
	$optArguments = undef;
	@expectedOutParameter = ();
	push(@expectedOutParameter, "RegistrationHandles");
	push(@expectedOutParameter, "Tags");
	my ($rc , $response) = cimInvoke("SVS_PGYIndicationRegistrationService", "ListRegistrations");
	if (!defined $response or $response =~ m/^\d+$/) {
	    addMessage("m","- There are no Subscription Registrations");
	    $exitCode = 0;
	    return;
	}
	if (defined $rc and $rc =~ m/0*/) {
	    $exitCode = 0;
	}
	# handle list response
	# TODO ... search a generic solution for outparam arrays
	my @arrRegistrationHandle = ();
	my @arrTags = ();
	my $rest = $response;
	$rest =~ s/\s*$//; # remove last spaces
	while ($rest) {
	    my $content = undef;
	    if ($rest =~ m/^<RegistrationHandles>/) {
		$rest =~ s/^<RegistrationHandles>//;
		$content = $1 if ($rest =~ m/^([^<]*)/);
		push (@arrRegistrationHandle, $content) if ($content);
		$rest =~ s/^[^<]*//;
		$rest =~ s!^</RegistrationHandles>!!;
	    } elsif ($rest =~ m/^<Tags>/) {
		$rest =~ s/^<Tags>//;
		$content = $1 if ($rest =~ m/^([^<]*)/);
		push (@arrTags, $content) if ($content);
		$rest =~ s/^[^<]*//m;
		$rest =~ s!^</Tags>!!;
	    } else { # ignore
		$rest =~ s/^<[^>]>//;
		$rest =~ s/^[^<]*//m;
		$rest =~ s!^</[^>]>!!;
	    }
	    $rest =~ s/^\s+//;
	    $rest = undef if ($rest and $rest =~ m/^\s*$/);
	} #while response
	if ($#arrTags == -1 and $#arrRegistrationHandle == 0 
	and $arrRegistrationHandle[0] =~ m/^Tags:\s*$/ ) 
	{   # older wbemcli error (no -n (new lines))
	    addMessage("m","- There are no Subscription Registrations");
	    $exitCode = 0;
	    return;
	}
	if ($#arrTags == 0 and $#arrRegistrationHandle == 0 
	and $arrRegistrationHandle[0] =~ m/^\s*$/ and $arrTags[0] =~ m/^\s*$/) 
	{   # wbemcli
	    addMessage("m","- There are no Subscription Registrations");
	    $exitCode = 0;
	    return;
	}
	if ($#arrTags == -1 and $#arrRegistrationHandle == 0) { # wbemcli ERROR !!!
	    (my $refarrTags, my $refarrRegistrationHandle) = 
	    	splitWbemcliRegistrationListOutArrays($arrRegistrationHandle[0], undef);
	    @arrTags = @{$refarrTags};
	    @arrRegistrationHandle = @{$refarrRegistrationHandle};
	}
	elsif ($#arrTags == 0  and $#arrRegistrationHandle == 0 and $arrTags[0] =~ m/,/) { 
	    # wbemcli returns arrays as one comma separated list
	    # This is a big problem for values with commas
	    (my $refarrTags, my $refarrRegistrationHandle) = 
	    	splitWbemcliRegistrationListOutArrays($arrRegistrationHandle[0], $arrTags[0]);
	    @arrTags = @{$refarrTags};
	    @arrRegistrationHandle = @{$refarrRegistrationHandle};
	} elsif ($#arrTags == -1 and $#arrRegistrationHandle == -1) {
	    addMessage("m","- There are no Subscription Registrations");
	    $exitCode = 0;
	    return;
	}
	#### search URL
	my %hashUrl = getListenerURL();

	####
	for (my $i=0; $i <= $#arrRegistrationHandle; $i++) {
	    my $tag = $arrTags[$i];
	    my $handle = $arrRegistrationHandle[$i];
	    my $filtername = undef;
	    $filtername = $1 if ($handle =~ m/__EventFilter.Name=\\\"([^\\]*)\\\"/);
	    $filtername = $1 if (!$filtername and $handle =~ m/Name=....(SVS\:Filter[^\\]+)/);
		#__EventFilter.Name=\"SVS:Filter#TSvNagios-172.17.55.216T#_1\""
		#,Name=\\\"SVS:Filter#TSvNagios-172.17.55.216-3169T#_3\\\" (wbemcli)
	    my $shortFilter = $filtername;
	    $shortFilter =~ s/[^\#]*\#// if ($shortFilter);
	    my $url = $hashUrl{$shortFilter} if ($shortFilter);
	    addStatusTopic("l",undef,"Registration", $i);
	    addKeyValue("l", "Tag", $tag);
	    addKeyLongValue("l", "FilterName", $shortFilter);
	    addKeyLongValue("l", "ListenerURL", $url);
	    addKeyValue("l", "Handle", "'" . $handle . "'") if ($main::verbose >= 2);
	    addMessage("l","\n");
	} # for
  } #registrationList

  sub registrationAdd {
	# SVS_PGYIndicationRegistrationService->RegisterCIMXMLIndication
	# KEYS	SystemCreationClassName, SystemName, CreationClassName, Name
	# IN	Query, EventReceiver, QueryType, Tag
	# OUT	RegistrationHandle
	$optKeys = undef;
	storeIndicationRegistrationService_Keys();
	return if (!$optKeys);

	my $eventReceiver = undef;
	$eventReceiver = $optListenerTransport . '://' . $optAdd . ':' . $optListenerPort
	    if ($optAdd and $optAdd !~ m/:/); # any address beside IPv6

	$eventReceiver = $optListenerTransport . '://[' . $optAdd . ']:' . $optListenerPort
	    if ($optAdd and $optAdd =~ m/:/); # IPv6

	my $tag = 'SvNagios-' . $optAdd;
	$tag .= '-' . $optListenerPort if ($optListenerPort);
	$optArguments = undef;
	$optArguments  = "Query='SELECT * FROM SVS_PGYLogEntryArrived'";
	$optArguments .= ",EventReceiver=$eventReceiver";
	$optArguments .= ",QueryType=0";
	$optArguments .= ",Tag=$tag";

	@expectedOutParameter = ();
	push(@expectedOutParameter, "RegistrationHandle");
	my ($rc , $response) = cimInvoke("SVS_PGYIndicationRegistrationService", "RegisterCIMXMLIndication");
	if (defined $rc and $rc == 0) {
	    addMessage("m","- Successful registration");
	    $exitCode = 0;
	} else {
	    addMessage("m","- Error during registration");
	    addMessage("m","- returncode = $rc") if (defined $rc);
	    $exitCode = 2;
	}
  } #registrationAdd

  sub registrationRemove {
	# SVS_PGYIndicationRegistrationService->UnRegisterIndicationsByTag 
	# KEYS	SystemCreationClassName, SystemName, CreationClassName, Name
	# IN	Tag
	# OUT	---
	$optKeys = undef;
	storeIndicationRegistrationService_Keys();
	return if (!$optKeys);
	$optArguments = undef;
	my $tag = 'SvNagios-' . $optRemove . '-' .  $optListenerPort;
	$tag = 'SvNagios-' . $optRemove if ($optListenerPort == 0); # for "veryolder" subscriptions
	$tag = 'SvNagios-' . $optRemove . '3169' if ($optListenerPort == 1); # for "middleold" subscriptions
	$optArguments = "Tag=$tag";
	@expectedOutParameter = ();
	my ($rc , $response) = cimInvoke("SVS_PGYIndicationRegistrationService", 
	    "UnRegisterIndicationsByTag");
	if (defined $rc and $rc == 0) {
	    addMessage("m","- Successful un-registration");
	    $exitCode = 0;
	} else {
	    $rc = "..undefined.." if (!defined $rc);
	    addMessage("m","- Error during un-registration - returncode = $rc");
	    $exitCode = 2;
	}
  } #registrationRemove

  sub processSubscriptionRegistration {
	registrationList()	if ($optList);
	registrationAdd()	if ($optAdd);
	registrationRemove()	if ($optRemove);
  } #processSubscriptionRegistration
#########################################################################
# CENTRAL CONTROL							#
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
	if ($discoveredType and $optInvoke) {
	    $exitCode = 3;
	    cimInvoke($optClass, $optMethod);
	}
	if ($discoveredType and $optModify) {
	    $exitCode = 3;
	    cimModify($optClass);
	}
	if ($discoveredType and ($optAdd or $optList or $optRemove)) {
		processSubscriptionRegistration();
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
#$stateString = undef if (($optUpdJobLogFile or $optGetUpdCheckLog) and !$exitCode); # suppress "OK"
finalize(
	$exitCode, 
	$stateString, 
	$msg,
	(! $notifyMessage	? '': "\n" . $notifyMessage),
	(! $longMessage		? '' : "\n" . $longMessage),
	($variableVerboseMessage ? "\n" . $variableVerboseMessage : ""),
);
################ EOSCRIPT


