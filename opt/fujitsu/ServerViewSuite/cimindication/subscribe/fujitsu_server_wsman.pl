#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2012, 2013, 2014, 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.20.01
# Date:		2015-08-14

# CHANGELOG
#   -16	    splitKeyValueOption and zero values
#   -16	    store _OUTPUT items beside ReturnValue to longMessage

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

use openwsman;
#########################################################################
# Kind of description of openWSMAN functionality:
#	http://turing.suse.de/~kkaempf/openwsman/
# Mailing group address:
#	http://openwsman.2324880.n4.nabble.com/
# Mail:
#	openwsman-devel@lists.sourceforge.net
#########################################################################


#------ This Script uses openwsman.pm - see cim*** functions ---------------------#

#### URI ###############################################

our $uriWINDOWS = "http://schemas.microsoft.com/wbem/wsman/1/wmi";
our $uriLINUX	= "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2";

our $uriNSSVS	= "root/svs";
our $uriSuffix	= "/root/svs";
our $uriESXiSVS	= "http://schemas.svs.org/wbem/wscim/1/cim-schema/2/root/svs";		# lt. V6.21.01 Agents
our $uriWINFTSSVS  = "http://schemas.ts.fujitsu.com/wbem/wscim/1/cim-schema/2";		# ? V6.30 Windows
our $uriFTSSVS  = "http://schemas.ts.fujitsu.com/wbem/wscim/1/cim-schema/2/root/svs";	# gt V6.21.01 Agents (?)

our $uriNSLSIESG= "lsi/lsimr13";
our $uriLSIESG	= "http://schemas.lsi.com/wbem/wscim/1/cim-schema/2/lsi/lsimr13";

#
#	"wmicim2"	=> $uriWINDOWS,
#	"cim2"		=> $uriLINUX,
#	"wmicim2svs"	=> $uriWINDOWS . $uriSuffix,
#	"cim2svs"	=> $uriLINUX . $uriSuffix,
#	"svscim2"	=> $uriESXiSVS,
#	"svs2cim2"	=> $uriFTSSVS,
#

#   ESXi requires this for enumerations !
#    <wsman:SelectorSet>
#      <wsman:Selector Name="__cimnamespace">root/svs</wsman:Selector>
#    </wsman:SelectorSet>
# -k "<key>=<value>"

#### HELP ##############################################
=head1 NAME

fujitsu_server_wsman.pl - Helper around Fujitsu specific WS-MAN calls

=head1 SYNOPSIS

fujitsu_server_wsman.pl 
  { -H|--host=<host> 
    [-P|--port=5985|8889|...] 
    [-T|--transport=<type>]
    [-U|--use={W|WE}]
    [-S|--service={E|L|W}]
    { [--cacert=<cafile>]
      [--cert=<certfile> --privkey=<keyfile>] 
      { -u|--user=<username> -p|--password=<pwd> }
    } |
      -I|--inputfile=<filename>
    { [--chkidentify] | 
      { --chkclass -C|--class=<class uri> } |
      { --invoke   -C|--class=<class uri> --method=<method> 
        [--selectors=<keyvalues-list>] 
        [--arguments=<keyvalues-list>] 
      }
      { --modify   -C|--class=<class uri>
        [--keys=<keyvalues-list>] 
        [--arguments=<keyvalues-list>] 
      }
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Checks a Fujitsu server reading CIM via the  WS-MAN protocol.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

This option is used for openwsman calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>]

CIM service port number and transport type. The port number must be set because there
exists no defualt for that. In the transport type 'http' or 'https' can be specified.
'http' is default.

ATTENTION: IPv6 addresses require Net::SNMP version V6 or higher.

These options are used for openwsman calles without any preliminary checks.

=item  [-U|--use={W|WE}] [-S|--service={E|L|W}]

Select Use-Mode: W=OpenWSMan-Perbinding, WE=OpenWSMan-Executable.
Select Service-Mode: E=ESXi, L=Linux, W=Windows

=item --chkidentify

Tool option to check the access to the CIM provider by reading the service "Identification".
This option can not be combined with other check options

=item --chkclass -C|--class=<class uri>

(internal) 

=item -u|--user=<username> -p|--password=<pwd>

Authentication data.

These options are used for openwsman calles without any preliminary checks.

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
our $optAuthPassword = undef; #CIM / SNMPv3
our $optInputFile = undef;

# CIM authentication
our $optUserName = undef; 
our $optPassword = undef; 
our $optCert = undef; 
our $optPrivKey = undef; 
our $optCacert = undef;
our $optAuthDigest = undef;

# CIM specific option
our $optTransportType = "http";
our $optTransportPrefix = '/wsman';
our $optClass = undef; 
our $optUseMode = undef;
our $optServiceMode = undef;	# E ESXi, L Linux, W Windows

our $optSystemInfo = undef;
our $optChkClass = undef;
our $optChkIdentify = undef;
our $optInvoke = undef;
our $optModify = undef;
our	$optKeys	= undef;
our	$optArguments	= undef;
our	$optMethod	= undef;

# special sub options
our $optWarningLimit = undef;
our $optCriticalLimit = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;

#### GLOBAL DATA BESIDE OPTIONS
# global control definitions
our $skipInternalNamesForNotifies = 1;	    # suppress print of internal product or model names

# define states
#### TEXT LANGUAGE AWARENESS (Standard in Nagios-Plugin)
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# option cross check result
our $setOverallStatus = undef;	# no chkoptions
our $setOnlySystem = undef;	# only --chksystem

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
our $globalNamespace = undef;

# CIM
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
# MAYBE TODO "is old or new ESXi"


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
  } #addMessage
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
#### OPTION FUNCTION ######
#
# handleOptions(): get command-line parameters
#
# Options can be set:
#	- as command line options
#	- in filename set for '-I|--inputfile'
#
# Each option on command line can be set more than once, the last value
# for such an option is used then. In <filename> options from command line 
# can be set resp. reset. With '-I' all options from command line can be set
# with the exception of '-I' which must not be used within the file again.
#
# The priority of these options is the following:
#
#    - Options from 'inputfile' overwrite command line options and 
#
# Option values are stored in 'global variables' which are already defined
# in main script.
#
# Use of options is checked and usage message printed by 'pod2usage' which
# implicitly exits the script, so no return value is necessary to indicate
# success or failure of this function.
#
# HINT for developer: $main::verbose is not set during these functions 

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
			"P|port=i",	
			"T|transport=s",	
		       	"U|use=s",
		       	"S|service=s",	
		       	"C|class=s",
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
		       	"systeminfo",

			"u|user=s",
			"p|password=s",
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
			"adigest",
	   		"I|inputfile=s", 
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
			"P|port=i",	
			"T|transport=s",	
		       	"U|use=s",
		       	"S|service=s",	
		       	"C|class=s",
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
		       	"systeminfo",

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
	     }
	}

    	return ( %options );
  } #getScriptOpts

  sub getOptionsFromFile {

	my $filename = shift;
	my $inputType = shift;
	my %options = ();


    	my $infileString = readDataFile( $filename);
	if (defined $infileString) {
		%options = getScriptOpts($infileString, $inputType);
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

  sub setOptions {  # script specific
	my $refOptions = shift;
	my %options =%$refOptions;
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="adigest";		$optAuthDigest		= $options{$k} if (defined $options{$k});
	$k="arguments";		$optArguments		= $options{$k} if (defined $options{$k});
	$k="keys";		$optKeys		= $options{$k} if (defined $options{$k});
	$k="method";		$optMethod		= $options{$k} if (defined $options{$k});
	$k="modify";		$optModify		= $options{$k} if (defined $options{$k});

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
		$optInvoke = $options{$key}               	if ($key eq "invoke"		); 
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		$optCert = $options{$key}             		if ($key eq "cert"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey" 		);
		$optCacert = $options{$key}             	if ($key eq "cacert"	 	);
		$optInputFile = $options{$key}                	if ($key eq "I"			);
		#$optEncryptFile = $options{$key}              	if ($key eq "E"		 	);
		
	}
  } # setOptions

  sub evaluateOptions { # script specific
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
	) if ($optHost eq '');

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
	) if (!$optPort);

	# wrong combination tests
	pod2usage(
		-msg     => "\n" . "argument --cert requires argument --privkey !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if (($optCert and !$optPrivKey) or (!$optCert and $optPrivKey));
	pod2usage(
		-msg     => "\n" . "action argument --chkclass requires argument -C <class> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optChkClass and !$optClass);
	pod2usage(
		-msg     => "\n" . "action argument --invoke requires argument -C <class> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optInvoke and !$optClass);
	pod2usage(
		-msg     => "\n" . "action argument --modify requires argument -C <class> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optModify and !$optClass);
	pod2usage(
		-msg     => "\n" . "action argument --invoke requires argument --method <method> !" . "\n",
		-verbose => 0,
		-exitval => 3
	) if ($optInvoke and !$optMethod);
	
	# Defaults
	{	# Default action
		if (!$optChkClass and !$optChkIdentify and !$optInvoke and !$optModify) 
		{
		    $optChkIdentify = 999;
		}
		# Default tool usage
		if (!$optUseMode) {
		    $optUseMode = "W"; # WS-MAN Perl-Binding
		}
	}
	if ($optServiceMode) {
		$isESXi = 1 if ($optServiceMode =~ m/^E/);
		$isLINUX = 1 if ($optServiceMode =~ m/^L/);
		$isWINDOWS = 1 if ($optServiceMode =~ m/^W/);
		$isiRMC = 1 if ($optServiceMode =~ m/^I/);
	}
	
	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}
  } #evaluateOptions

#
# main routine to handle options from command line and -I/-E filename
#
sub handleOptions {
	# read all options and return prioritized
	my %options = readOptions();

	#
	# assign to global variables
	setOptions(\%options);

	# evaluateOptions expects options set in global variables
	evaluateOptions();

} #handleOptions

#### CIM HELPER #########################################################
  sub setClassNamespace {
	my $class = shift;
	my $substitute = undef;
	if ($class =~ m/^wmicim2svs/) {
		$substitute = $uriWINDOWS . $uriSuffix;
		$class =~ s/wmicim2svs/$substitute/;
	} elsif ($class =~ m/^cim2svs/) {
		$substitute = $uriLINUX . $uriSuffix;
		$class =~ s/cim2svs/$substitute/;
	} elsif ($class =~ m/^wmicim2/) {
		$substitute = $uriWINDOWS;
		$class =~ s/wmicim2/$substitute/;
	} elsif ($class =~ m/^svscim2/) {
		$substitute = $uriESXiSVS;
		$class =~ s/svscim2/$substitute/;
	} elsif ($class =~ m/^svs2cim2/) {
		$substitute = $uriFTSSVS;
		$class =~ s/svs2cim2/$substitute/;
	} elsif ($class =~ m/^svs3cim2/) {
		$substitute = $uriWINFTSSVS;
		$class =~ s/svs3cim2/$substitute/;
	} elsif ($class =~ m/^cim2/) {
		$substitute = $uriLINUX;
		$class =~ s/cim2/$substitute/;
	}
	$globalNamespace = $substitute;
	if ($class =~ m/^SVS_/) {
	    if ($isWINDOWS) {
		if ($optServiceMode and $optServiceMode eq "W621") { # "future" version namespace
		    $class = $uriFTSSVS . "/" . $class;
		    #$class = $uriWINDOWS . $uriSuffix . "/" . $class;
		    $globalNamespace = $uriFTSSVS if (!$globalNamespace);
		} else {
		    #$class = $uriFTSSVS . "/" . $class;
		    $class = $uriWINDOWS . $uriSuffix . "/" . $class;
		    $globalNamespace = $uriWINDOWS . $uriSuffix if (!$globalNamespace);
		    # There seems to be no way to influence WIN to change the namespace
		}
	    } elsif ($isLINUX or $isiRMC) {
		if ($optServiceMode and $optServiceMode eq "L621") { # "old" version namespace
		    $class = $uriLINUX . $uriSuffix . "/" . $class;
		    $globalNamespace = $uriLINUX . $uriSuffix if (!$globalNamespace);
		} else {
		    $class = $uriFTSSVS . "/" . $class;
		    $globalNamespace = $uriFTSSVS if (!$globalNamespace);
		}
	    } else {
		$class = $uriESXiSVS . "/" . $class;
		$globalNamespace = $uriESXiSVS if (!$globalNamespace);
	    }
	}
	elsif ($class =~ m/^LSIESG_/) {
		$class = $uriLSIESG . "/" . $class;
		$globalNamespace = $uriLSIESG if (!$globalNamespace);
	}
	elsif ($class =~ m/^CIM_/) {
		my $substitute = $uriLINUX;
		$class = $uriLINUX . "/" . $class;
		$globalNamespace = $uriLINUX if (!$globalNamespace);
	}
	return $class;
  } #setClassNamespace

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
		$keyValues{$key}    = $value;
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

  sub splitKeyValueOptionArray {
	my $optionString = shift;
	my @keyValueArray = ();
	my %keyValues = ();
	return %keyValues if (!$optionString);

	my $rest = $optionString;
	while ($rest) {
	    my $key = undef;
	    my $value = undef;
	    $key = $1 if ($rest =~ m/^([^=]+)=/);
	    $rest =~ s/^[^=]+=// if (defined $key); # strip key
	    if ($rest =~ m/^[\"]/) {
		$value = $1 if ($rest =~ m/^(\"[^\"]+\")/);
		$rest =~ s/^\"[^\"]+\"// if (defined $value);
		if (!defined $value) {
		    $value = '' if ($rest =~ m/^\"\"/);
		    $rest =~ s/^\"\"// if (defined $value);
		}
	    }
	    elsif ($rest =~ m/^[\']/) {
		$value = $1 if ($rest =~ m/^(\'[^\']+\')/);
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

	    my $oneKeyValue = undef;
	    $oneKeyValue .= "$key=" if ($key);
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
  } #splitKeyValueOptionArray

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

#### WSMAN EXCEPTIONS: ##################################################
  sub cimWSMAN_Generic_Exceptions {
	my $nsclass = shift;
	my $iMethod = shift;
	#uuid:bc03a1a7-14c4-14c4-8002-047a66290c0
	my $result = undef;

	# Build the request
	my $xmlObject = openwsman::create_soap_envelope();
	if ($xmlObject) {
	    my $header = $xmlObject->header();
	    if ($header) {
		# Action
		my $headChild = undef;
		$headChild = $header->add("http://schemas.xmlsoap.org/ws/2004/08/addressing",
		    "Action",
		    "$nsclass/$iMethod");
		$headChild->attr_add("http://www.w3.org/2003/05/soap-envelope","mustUnderstand","true")
		    if ($headChild);
		# To
		$headChild = undef;
		$headChild = $header->add("http://schemas.xmlsoap.org/ws/2004/08/addressing",
		    "To",
		    "http://$optHost:$optPort/wsman");
		$headChild->attr_add("http://www.w3.org/2003/05/soap-envelope","mustUnderstand","true")
		    if ($headChild);
		# TODO - resourceURI: flexible namespace
		$headChild = undef;
		$headChild = $header->add("http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd",
		    "ResourceURI",
		    "$nsclass");
		$headChild->attr_add("http://www.w3.org/2003/05/soap-envelope","mustUnderstand","true")
		    if ($headChild);
		# MessageID
		$headChild = undef;
		$headChild = $header->add("http://schemas.xmlsoap.org/ws/2004/08/addressing",
		    "MessageID",
		    "urn:$iMethod-$$");
		$headChild->attr_add("http://www.w3.org/2003/05/soap-envelope","mustUnderstand","true")
		    if ($headChild);
		# ReplyTo 
		$headChild = undef;
		$headChild = $header->add("http://schemas.xmlsoap.org/ws/2004/08/addressing",
		    "ReplyTo",
		    undef);
		if ($headChild) {
		    my $replytoChild = undef;
		    $replytoChild = $headChild->add("http://schemas.xmlsoap.org/ws/2004/08/addressing",
			"Address",
			"http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous");
		} # ReplyTo
		# SelectorSet
		$headChild = undef;
		$headChild = $header->add("http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd",
		    "SelectorSet",
		    undef);
		if ($headChild) {
		    my $selectorChild = undef;
		    $selectorChild = $headChild->add("http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd",
			"Selector",
			"root/svs");
		    $selectorChild->attr_add(undef,"Name","__cimnamespace")
			if ($selectorChild);
		    $selectorChild = undef;
		    # ..... Selectors
		    my %selectors = splitKeyValueOption($optKeys);
		    foreach my $key (keys %selectors) {
			my $value = undef;
			$value = $selectors{$key};
			$selectorChild = $headChild->add("http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd",
			    "Selector",
			    $value);
			$selectorChild->attr_add(undef,"Name",$key)
			    if ($selectorChild);
		    }
		} # SelectorSet
	    } # header
	    my $body = $xmlObject->body();
	    if ($body) {
		my $bodyChild = undef;
		$bodyChild = $body->add(
		    "$nsclass",
		    $iMethod . "_INPUT",
		    undef);
		if ($bodyChild) {
		    my $param = undef;
		    # ..... Parameters
		    my @properties = splitKeyValueOptionArray($optArguments);
		    my $formerKey = undef;
		    foreach my $keyValue (@properties) {
			my $key = undef;
			my $value = undef;
			$key = $1 if ($keyValue =~ m/^([^=]+)=/);
			$value = $keyValue if (! defined $key);
			$value = $1 if ($key and $keyValue =~ m/=(.*)/);
			if (defined $value) {
			    $value =~ s/^\"//;
			    $value =~ s/\"$//;
			    $value =~ s/^\'//;
			    $value =~ s/\'$//;
			}
			$key = $formerKey if (!defined $key and defined $formerKey);
			#$options->add_property($key, $value) if ($key and defined $value);
			$param = $bodyChild->add(
			    "$nsclass",
			    $key,
			    $value);
		    }
		    # ..... Parameters
		    #my %properties = splitKeyValueOption($optArguments);
		    #foreach my $key (keys %properties) {
			#my $value = undef;
			#$value = $properties{$key};
			#$param = $bodyChild->add(
			 #   "$nsclass",
			#    $key,
			#    $value);
		    #} # foreach
		} #INPUT
	    } # body
	    #
	    my $xmlStream = $xmlObject->string();
	    print "$xmlStream\n" if ($main::verbose >= 60);
	} # xmlObject
	# send
	my $retcode = undef;
	$retcode = $clientSession->send_request($xmlObject);
	$result = $clientSession->build_envelope_from_response();
	if ($main::verbose >= 60 and $result) {
	    $result->dump_file(*STDOUT);
	}
	undef $xmlObject;
	unless($result && $result->is_fault eq 0) {
	    addMessage("m", "\n") if ($msg);
	    addMessage("m", "[ERROR] Could not send the $iMethod request.");
	    my $code = $clientSession->last_error;
	    addMessage("m", " (LastError=$code)") if ($code);
	    $code = $clientSession->response_code;
	    addMessage("m", " (ResponseCode=$code)") if ($code);
	    undef $result;
	    return -1;
	} else {
	    my $body =  undef;
	    my $methodOutput = undef;
	    my $foundOutput = 0;
	    my $outCounter = 0;
	    my $retCode = undef;
	    $body = $result->body();
	    $methodOutput = $body->child() if ($body);
	    if ($methodOutput) {
		my $field = $methodOutput->name();
		$outCounter = $methodOutput->size();
		$foundOutput = 1 if ($outCounter >= 1 and $field and $field =~ m/$iMethod/);
		if (!$foundOutput) {
		    addMessage("m", "[ERROR] corrupt method output - unexpected \"$field\" and size=$outCounter.");
		}
	    } # output
	    else {
		addMessage("m", "[ERROR] Could not read method output.");
	    }
	    if ($foundOutput) {
		for((my $cnt = 0) ; ($cnt<$outCounter) ; ($cnt++)) {
		    my $node = $methodOutput->get($cnt);
		    if ($node) {
			my $name = $node->name();
			my $text = $node->text();
			if ($name and $name =~ m/ReturnValue/i) {
			    $retCode = $text;	    
			} else { # print first level items to longMessage
			    addMessage("l","<$name>");
			    addMessage("l",$text);
			    addMessage("l","</$name>\n");
			}
		    }
		    #$items->{$nodes->get($cnt)->name()} = $nodes->get($cnt)->text();
		} #for
	    } # found
	    if ($optInvoke and defined $retCode) {
		$exitCode = 0;
		$msg = '';
		addMessage("m", "-");
		addKeyIntValue("m", "ReturnCode", $retCode);
	    }
	    return $retCode;
	}	
  } #cimWSMAN_Generic_Exceptions

#### CIM ACCESS OPENWSMAN PERL ##########################################
  sub cimWSMANInitConnection {
	# debug (to stderr)
	# openwsman::set_debug(-1);
	openwsman::set_debug(-1) if ($main::verbose >=20);
	$clientSession = new openwsman::Client::($optHost, $optPort, $optTransportPrefix, 
		$optTransportType, $optUserName, $optPassword);
	if (!$clientSession) {
		addMessage("m","- [ERROR] Unable to get a Client Instance for to $optHost (Port:$optPort, Type=$optTransportType).");
		$exitCode = 2;
		return; # never reached point
	}
	# auth. mode
	if ($optAuthDigest) {
	    $clientSession->transport()->set_auth_method($openwsman::DIGEST_AUTH_STR);
	} else {
	    $clientSession->transport()->set_auth_method($openwsman::BASIC_AUTH_STR);
	}

	if ($optCacert and $optTransportType eq "https") {
	    $clientSession->transport()->set_cainfo($optCacert)	if ($optCacert);
	}
	if ($optCert and $optTransportType eq "https") {
	    $clientSession->transport()->set_cert($optCert)	if ($optCert);
	    $clientSession->transport()->set_key($optPrivKey)	if ($optPrivKey);
	} 
	# older Perl-WSMAN does not know $openwsman::FALSE;
	$clientSession->transport()->set_verify_host(0);
	$clientSession->transport()->set_verify_peer(0) if (!$optCacert);
	
	$clientSession->set_encoding("utf-8"); # should be default
  } # cimWSMANInitConnection
  sub cimWSMANFinishConnection {
	undef $clientSession;
  } # cimWSMANFinishConnection
  #
  #########################################################################
=begin COMMENT
	client.encoding = "utf-8" ... should be standard in LINUX
	options.max_elements = 999
	$result->dump_file(*STDOUT)
=end COMMENT
=cut

  sub cimWSMANIdentify {
	my $result = undef; # Used to store obtained data.
	# Identify.
	# (options)
	# Set up client options.
	my $options = new openwsman::ClientOptions::();
	if (!$options) {
		addMessage("m","- [ERROR] Could not create client options handler for openwsman.");
		$exitCode = 2;
		return;
	}
	# Dump the XML request to stdout.
	$options->set_dump_request() if ($main::verbose>=60 && $optChkIdentify);

	$result = $clientSession->identify($options);
	unless($result && $result->is_fault eq 0) {
		my $code = $clientSession->response_code();
		my $fault = $clientSession->fault_string();
		$fault = '' if (!$fault);
		if ($code == 401) {
			addMessage("m","- [ERROR] authentication error discovered.");
		} else {
			addMessage("m","- [ERROR] unable to connect to $optHost (Port:$optPort) Code=$code FaultString=\"$fault.\"");
		}
		$exitCode = 2;
		return;
	}
	$exitCode = 0 if ($optChkIdentify);
	if ($main::verbose >= 60 and $result) {
	    $result->dump_file(*STDOUT);
	}
	# Get server info.
	my $root = $result->root;
	my $prot_version = $root->find($openwsman::XML_NS_WSMAN_ID,
				       "ProtocolVersion")->text();
	my $prod_vendor = $root->find($openwsman::XML_NS_WSMAN_ID,
				      "ProductVendor")->text();
	my $prod_version = $root->find($openwsman::XML_NS_WSMAN_ID,
				       "ProductVersion")->text();

	# Print output.
	addKeyValue("m","Protocol",$prot_version ) if ($optChkIdentify);
	addKeyLongValue("m","Vendor",$prod_vendor ) if ($optChkIdentify);
	addKeyLongValue("m","Version",$prod_version ) if ($optChkIdentify);

	# "Openwsman Project" => LINUX
	# "Microsoft Corporation" => WINDOOF
	# "VMware Inc." ESXi - Version "VMware ESXi 5.0.0 ***"
	$isWINDOWS = 1 if ($prod_vendor =~ m/Microsoft/i);
	$isESXi = 1 if ($prod_vendor =~ m/VMware/i && $prod_version =~ m/ESXi/i);
	$isLINUX = 1 if (!$isWINDOWS && !$isESXi);
	#### TODO ??? iRMC & OpenWSMAN
	addStatusTopic("v", undef, "CIMService", undef);
	addKeyValue("v", "Type", "Windows") if ($isWINDOWS);
	addKeyValue("v", "Type", "LINUX") if ($isLINUX);
	addKeyValue("v", "Type", "ESXi") if ($isESXi);

	# delete ??? client
  } # cimWSMANIdentify

  sub cimWSMANEnumerateClass {
	my $optClass = shift;
	return if (!$optClass);
	$exitCode = 3 if ($optChkClass);
	my $origClass = $optClass;
	#
	my $class = setClassNamespace($optClass);

	addKeyValue("v", "OriginClass", $origClass);
	addKeyValue("v", "FullClassUri", $class);
	#
	# Set up client options.
	my $options = new openwsman::ClientOptions::();
	if (!$options) {
		addMessage("m","- [ERROR] Could not create wsman client options handler.");
		$exitCode = 2;
		return;
	}
	# Dump the XML request to stdout.
	$options->set_dump_request() if ($main::verbose>=60);
	#$options->set_max_elements(250); # not available

	$options->add_selector("__cimnamespace", $uriNSSVS) if ($isESXi or $class =~ m/SVS_/);
	$options->add_selector("__cimnamespace", $uriNSLSIESG) if ($isESXi or $class =~ m/LSI/);
	#
	my $result = undef; # Used to store obtained data.
	my @list;   # Instances list.

	# Enumerate from external schema (uri).
	# (options, filter, resource uri)
	$result = $clientSession->enumerate($options, undef, $class);
	if ($main::verbose >= 60 and $result) {
	    $result->dump_file(*STDOUT);
	}
	unless($result && $result->is_fault eq 0) {
	    addMessage("m", "[ERROR] Could not enumerate instances.");
	    my $code = $clientSession->last_error;
	    addMessage("m", " (LastError=$code)") if ($code);
	    $code = $clientSession->response_code;
	    addMessage("m", " (ResponseCode=$code)") if ($code);
	    return;
	}

	# Get context.
	my $context = $result->context();
	my $nextContext = $context;

	my $isEndOfSequenceError = 0;
	while($nextContext and !$isEndOfSequenceError) {
		$context = $nextContext;
		# Pull from local server.
		# (options, filter, resource uri, enum context)
		$result = $clientSession->pull($options, undef, $class, $context);
		if ($main::verbose >= 70 and $result and $optChkClass) {
			my $fh = undef;
			open($fh, ">> OUT.txt");
			$result->dump_file($fh) if ($fh);
			close($fh) if ($fh);
		}
		next unless($result);

		# Get nodes.
		# soap body -> PullResponse -> items
		# XML_NS_ENUMERATION
		my $findNS = $openwsman::XML_NS_ENUMERATION;
		my $xmlItems =  $result->body()->find($findNS, "Items");
		my $nodes = $xmlItems->child() if ($xmlItems);
		if (!$nodes) {
			$isEndOfSequenceError = 1 if (!$result->context());
			next;
		}
		next unless($nodes);

		# ATTENTION In $nodes are multiple items !!!

		# Get items.
		my $items;
		for((my $cnt = 0) ; ($cnt<$nodes->size()) ; ($cnt++)) {
			my $value = $nodes->get($cnt)->text();
			next if ((!defined $value) and !$main::verbose);
			next if (!$value and $value !~ m/^\d+$/ and !$main::verbose); # empty strings
			my $field = $nodes->get($cnt)->name();
			my $text = $nodes->get($cnt)->text();
			#$items->{$nodes->get($cnt)->name()} = $nodes->get($cnt)->text();
			#$items->{$field} = $text;
			if ($items and $items->{$field}) {
			    my $store = $items->{$field};
			    $store = '"' . $store . '"' if ($store !~ m/^\"/);
			    $store .= ",";
			    $store .= "\"$text\"";
			    $items->{$field} = $store;
			} else {
			    $items->{$field} = $text;
			}		
		}
		push @list, $items;

		$nextContext = $result->context();
	}
	# Release context.
	$clientSession->release($options, $class, $context) if($context); # use the last exiting one

	$exitCode = 0 if ($#list >= 0 and $optChkClass);

	return @list;
  } # cimWSMANEnumerateClass

  sub cimWSMANInvoke {
	my $iClass = shift;
	my $iMethod = shift;
	return if (!$iClass or !$iMethod);

	my $wsmanversion =  undef;
	$wsmanversion = $openwsman::OPENWSMAN_VERSION if (defined $openwsman::OPENWSMAN_VERSION);

	my $origClass = $iClass;
	#
	my $class = setClassNamespace($iClass);

	addKeyValue("v", "OriginClass", $origClass);
	addKeyValue("v", "FullClassUri", $class);

	##### OpenWSMan ERROR
	if ($wsmanversion and ($wsmanversion eq "2.4.13" or $wsmanversion eq "2.4.14") 
	and $optArguments and $optArguments =~ m/,/ 	) 
	{
	    addMessage("l",
		"- [WARNING] OpenWsman version $wsmanversion is unable to handle multiple argument properties. A workaround implementation is used.");
	    $exitCode = 2;

	    return cimWSMAN_Generic_Exceptions($class, $iMethod)
		if (($iClass =~ m/IndicationRegistrationService/ and $iMethod =~ m/RegisterCIMXMLIndication/) 
		 or ($iClass =~ m/UpdateJob/ and $iMethod =~ m/RequestStateChange/)
		 or ($iMethod =~ m/ModifyConfigSettings/));
	    return undef;
	}

	# Set up client options.
	my $options = new openwsman::ClientOptions::();
	if (!$options) {
		addMessage("m","- [ERROR] Could not create wsman client options handler.");
		$exitCode = 2;
		return;
	}
	# Dump the XML request to stdout.
	$options->set_dump_request() if ($main::verbose>=60);

	$options->add_selector("__cimnamespace", $uriNSSVS) if ($class =~ m/SVS_/);

	# ..... Selectors
	my %selectors = splitKeyValueOption($optKeys);
	foreach my $key (keys %selectors) {
	    my $value = undef;
	    $value = $selectors{$key};
	    $options->add_selector($key, $value) if ($key and defined $value);
	}

	# ..... Parameters
	my @properties = splitKeyValueOptionArray($optArguments);
	my $formerKey = undef;
	foreach my $keyValue (@properties) {
	    my $key = undef;
	    my $value = undef;
	    $key = $1 if ($keyValue =~ m/^([^=]+)=/);
	    $value = $keyValue if (! defined $key);
	    $value = $1 if ($key and $keyValue =~ m/=(.*)/);
	    if (defined $value) {
		$value =~ s/^\"//;
		$value =~ s/\"$//;
		$value =~ s/^\'//;
		$value =~ s/\'$//;
	    }
	    $key = $formerKey if (!defined $key and defined $formerKey);
	    $options->add_property($key, $value) if ($key and defined $value);
	}

	# ..... Invoke
	my $result = undef; # Used to store obtained data.
	my @list;   # Instances list.
	$result = $clientSession->invoke($options, $class, $iMethod);
	if ($main::verbose >= 60 and $result) {
	    $result->dump_file(*STDOUT);
	}
	unless($result && $result->is_fault eq 0) {
	    addMessage("m", "[ERROR] Could not invoke method.");
	    my $code = $clientSession->last_error;
	    addMessage("m", " (LastError=$code)") if ($code);
	    $code = $clientSession->response_code;
	    addMessage("m", " (ResponseCode=$code)") if ($code);
	    return;
	}	
	#### TODO split invoke result ...
	my $body =  undef;
	my $methodOutput = undef;
	my $foundOutput = 0;
	my $outCounter = 0;
	my $retCode = undef;
	$body = $result->body();
	$methodOutput = $body->child() if ($body);
	if ($methodOutput) {
	    my $field = $methodOutput->name();
	    $outCounter = $methodOutput->size();
	    $foundOutput = 1 if ($outCounter >= 1 and $field and $field =~ m/$iMethod/);
	    if (!$foundOutput) {
		addMessage("m", "[ERROR] corrupt method output - unexpected \"$field\" and size=$outCounter.");
	    }
	} # output
	else {
	    addMessage("m", "[ERROR] Could not read method output.");
	}
	if ($foundOutput) {
	    for((my $cnt = 0) ; ($cnt<$outCounter) ; ($cnt++)) {
		my $node = $methodOutput->get($cnt);
		if ($node) {
		    my $name = $node->name();
		    my $text = $node->text();
		    if ($name and $name =~ m/ReturnValue/i) {
			$retCode = $text;	    
		    } else { # print first level items to longMessage
			addMessage("l","<$name>");
			addMessage("l",$text);
			addMessage("l","</$name>\n");
		    }
		}
		#$items->{$nodes->get($cnt)->name()} = $nodes->get($cnt)->text();
	    } #for
	} # found
	if ($optInvoke and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "-");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	}
	undef $options; ######### <--- ATTENTION - required to prevent core of OpenWSMAN lt. V2.4.8
	return $retCode;
  } # cimWSMANInvoke

  sub cimWSMANModify { # WS-Transfer-Put
	my $iClass = shift;
	return if (!$iClass);

	my $origClass = $iClass;
	#
	my $class = setClassNamespace($iClass); # set $globalNamespace

	addKeyValue("v", "OriginClass", $origClass);
	addKeyValue("v", "FullClassUri", $class);

	# Set up client options.
	my $options = new openwsman::ClientOptions::();
	if (!$options) {
		addMessage("m","- [ERROR] Could not create wsman client options handler.");
		$exitCode = 2;
		return;
	}
	# Dump the XML request to stdout.
	$options->set_dump_request() if ($main::verbose>=60);
	#$options->set_max_elements(250); # not available

	$options->add_selector("__cimnamespace", $uriNSSVS) if ($class =~ m/SVS_/);

	# ..... Selector Keys
	my %selectors = splitKeyValueOption($optKeys);
	foreach my $key (keys %selectors) {
	    my $value = undef;
	    $value = $selectors{$key};
	    $options->add_selector($key, $value) if ($key and defined $value);
	}

	# ..... Parameters
	my $classBasename = $class;
	$classBasename = $1 if ($class =~ m/.*[\/]([^\/]+)$/);
	my $xmlStream = undef;
	my $xmlObject = new openwsman::XmlDoc::($classBasename, $class);
	#my $xmlObject = new openwsman::XmlDoc::($classBasename, $globalNamespace);
	#my $xmlObject = new openwsman::XmlDoc::($class);
	if ($xmlObject) {
	    my $root = $xmlObject->root();
	    my %properties = splitKeyValueOption($optArguments);
	    foreach my $key (keys %properties) {
	        my $value = undef;
	        $value = $properties{$key};
		$root->add($class, $key, $value) if ($key);
	    }
	    $xmlStream = $xmlObject->string();
	    my $lsize = length($xmlStream);
	}
	
	# ..... Put
	my $result = undef; # Used to store obtained data.
	my @list;   # Instances list.
	$result = $clientSession->put($options, $class, $xmlStream, length($xmlStream), "utf-8");
	if ($main::verbose >= 60 and $result) {
	    $result->dump_file(*STDOUT);
	}

	undef $xmlObject;

	unless($result && $result->is_fault eq 0) {
	    addMessage("m", "[ERROR] Could not invoke method.");
	    my $code = $clientSession->last_error;
	    addMessage("m", " (LastError=$code)") if ($code);
	    $code = $clientSession->response_code;
	    addMessage("m", " (ResponseCode=$code)") if ($code);
	    return;
	}	
	#### TODO split PUT result ...
	my $body =  undef;
	my $methodOutput = undef;
	my $foundOutput = 0;
	my $outCounter = 0;
	my $retCode = undef;
	$body = $result->body();
	$methodOutput = $body->child() if ($body);
	if ($methodOutput) {
	    my $field = $methodOutput->name();
	    $outCounter = $methodOutput->size();
	    $foundOutput = 1 if ($outCounter >= 1);
	    if (!$foundOutput) {
		addMessage("m", "[ERROR] corrupt method output - unexpected \"$field\" and size=$outCounter.");
	    }
	    $retCode = 0 if ($field =~ m/$classBasename/);
	} # output
	else {
	    addMessage("m", "[ERROR] Could not read PUT output.");
	}
	if ($optModify and defined $retCode) {
	    $exitCode = 0;
	    addMessage("m", "-");
	    addKeyIntValue("m", "ReturnCode", $retCode);
	}
	undef $options; ######### <--- ATTENTION - required to prevent core of OpenWSMAN lt. V2.4.8
	return $retCode;
  } # cimWSMANModify

#### CIM ACCESS OPENWSMAN EXEC ##########################################
=begin comment
p.pl -H<win> -P5985 -u administrator -p ***** --chkclass -Cwmicim2svs/SVS_PGYComputerSystem
p.pl -H<esxi> -u root -p **** -P8889 --chkclass -Csvscim2/SVS_PGYPhysicalMemory
p.pl -H<lin> -P8889 -uroot -p**** --chkclass -Ccim2svs/SVS_PGYPhysicalMemory

ESXi
p.pl -H*.221 -P8889 -uroot -p**** --chkclass -Ccim2/CIM_ComputerSystem
    ... CIM_* leads to not-only SVS_PGYComputerSystem !
p.pl -H*.221 -P8889 -uroot -p**** --chkclass -Csvscim2/SVS_PGYComputerSystem

p.pl -H*.34 -P8889 -uroot -p**** --chkclass -Ccim2/CIM_ComputerSystem
    ... CIM_* leads to not-only SVS_PGYComputerSystem !
p.pl -H*.34 -P8889 -uroot -p**** --chkclass -Csvscim2/SVS_PGYComputerSystem

=end comment
=cut

our $wsmanEnumForm = "wsman enumerate %s -h %s -P %s -u '%s' -p '%s' -y basic -V -v";
our $wsmanEnumForm2 = "wsman enumerate %s -b https://%s:%s -u '%s' -p '%s' -y basic -V -v";
our $wsmanEnumNSAdd = " --namespace=root/svs";
our $wsmanIdentForm = "wsman identify -h %s -P %s -u '%s' -p '%s' -y basic -V -v";
our $wsmanIdentForm2 = "wsman identify -b https://%s:%s -u '%s' -p '%s' -y basic -V -v";

  sub cimWSExecInitConnection {
	$clientSession = 1;
  } # cimInitConnection

  sub cimWSExecFinishConnection {
	$clientSession = 0;
  } # cimFinishConnection

  sub cimWSExecIdentify {
	my $cmd = sprintf($wsmanIdentForm, $optHost, $optPort, $optUserName, $optPassword);
	my $cmd2 = sprintf($wsmanIdentForm2, $optHost, $optPort, $optUserName, $optPassword);
	my $xmlIdent = "";
	$cmd = $cmd2 if ($optTransportType eq "https");
	my $printCmd = $cmd;
	$printCmd =~ s/\'[^\']*\'/****/g; #...user &  password
	print "Command=\"$printCmd\"\n" if ($main::verbose >=10); 

	my $errCmd = $cmd;
	$cmd = $cmd . " 2>/dev/null"; 
		# There is a problem to catch stderr - 2>&1 does not work in open()

	open (my $pHandle, '-|', $cmd);
	
	while (<$pHandle>) {
		$xmlIdent .= $_; 
		print if ($main::verbose >= 60); # $_
	}
	close $pHandle;
	print ">>> " . $xmlIdent .  " <<<\n" if ($optChkIdentify and $main::verbose >=60);

	if (! $xmlIdent or $xmlIdent eq "") { ###### ERROR CASE
	    my $allStderr = `$errCmd 2>&1`;
	    addMessage("n", $allStderr);
	    addMessage("m","- [ERROR] unable to get identify information of server.");
	    $exitCode = 2;
	}

	$xmlIdent =~ m/.*ProtocolVersion>([^<]*)<.*ProtocolVersion/ig;
	my $prot_version = $1;
	$xmlIdent =~ m/.*ProductVendor>([^<]*)<.*ProductVendor/ig;
	my $prod_vendor = $1;
	$xmlIdent =~ m/.*ProductVersion>([^<]*)<.*ProductVersion/ig;
	my $prod_version = $1;

	addKeyValue("m","Protocol",$prot_version ) if ($optChkIdentify);
	addKeyLongValue("m","Vendor",$prod_vendor ) if ($optChkIdentify);
	addKeyLongValue("m","Version",$prod_version ) if ($optChkIdentify);

	# "Openwsman Project" => LINUX
	# "Microsoft Corporation" => WINDOOF
	# "VMware Inc." ESXi - Version "VMware ESXi 5.0.0 ***"
	if ($prod_vendor) {
		$isWINDOWS = 1 if ($prod_vendor =~ m/Microsoft/i);
		$isESXi = 1 if ($prod_vendor =~ m/VMware/i && $prod_version =~ m/ESXi/i);
		$isLINUX = 1 if (!$isWINDOWS && !$isESXi);
		addStatusTopic("v", undef, "CIMService", undef);
		addKeyValue("v", "Type", "Windows") if ($isWINDOWS);
		addKeyValue("v", "Type", "LINUX") if ($isLINUX);
		addKeyValue("v", "Type", "ESXi") if ($isESXi);
		$exitCode = 0;
	}
  } # cimWSExecIdentify

  sub cimWSExecEnumerateClass {
	return if (!$optClass);
	$exitCode = 3;
	my $useFormAdd = undef;
	#
	my $class = setClassNamespace($optClass);

	$useFormAdd = $wsmanEnumNSAdd if ($class =~ m/SVS_/ or $isESXi);
	addKeyValue("v", "OriginClass", $optClass);
	addKeyValue("v", "FullClassUri", $class);
	
	my $cmd = sprintf($wsmanEnumForm, $class, $optHost, $optPort, $optUserName, $optPassword);
	my $cmd2 = sprintf($wsmanEnumForm2, $class, $optHost, $optPort, $optUserName, $optPassword);
	$cmd = $cmd2 if ($optTransportType eq "https");
	$cmd .= $useFormAdd if ($useFormAdd);
	my $printCmd = $cmd;
	$printCmd =~ s/\'[^\']*\'/****/g; #...Attention password

	my $oneXML = undef;
	my @listXML = undef;

	print "Command=$printCmd\n" if ($main::verbose>=10); 
	$cmd .= " 2>/dev/null" if (!$main::verbose or $main::verbose < 60);
	open (my $pHandle, '-|', $cmd);
	while (<$pHandle>) {
		my $tmpStream = $_;
		if ($tmpStream =~ m/<\?xml version=/ and $oneXML) {
		    push @listXML, $oneXML;
		    $oneXML = '';
		}
		$oneXML .= $tmpStream; 
		print if ($main::verbose >= 60); # $_
	}
	push (@listXML, $oneXML) if ($oneXML);
	#print "XML-Counter=" . $#listXML . "\n";
	my $foundPullresponse = 0;
	my @PullItems = undef;
	foreach my $singleXML (@listXML) {
		my $foundEndOfSequence = 0;
		if ($singleXML and $singleXML =~ m/\:PullResponse>/) {
		    $singleXML =~ m/\:EndOfSequence/;
		    $foundEndOfSequence = 1 if ($1);
		}
		if ($singleXML and $singleXML =~ m/\:PullResponse>/) {
			$foundPullresponse = 1;
			$singleXML =~ s/\r//mg;
			$singleXML =~ s/\n//mg;
			$singleXML =~ m/<[^\s]*:Items>(.*)<\/[^\s]*:Items/;
			my $itemcontent = $1;
			if ($itemcontent) {
			    $itemcontent =~ s/^\s+//;
			    $itemcontent =~ s/\s+$//;
			    #print "++++$itemcontent+++\n";
			    push (@PullItems, $itemcontent);
			}
		}
		next if ($foundEndOfSequence);
	} 
	#print "PullCounter=" . $#PullItems . "\n";
	my @list = ();
	foreach my $singleXML (@PullItems) {
		my @tagArray = ();
		next if (!$singleXML);
		#print "--- $singleXML---\n" if ($singleXML);
		# search main tag inside end remove this
		$singleXML =~ m/^<([^:]*:[^ >]*)[ >]/;
		my $maintag = $1;
		#print "___ $maintag ___\n" if ($maintag);
		$singleXML =~ s/<$maintag[^>]*>\s*//;
		$singleXML =~ s/\s*<\/$maintag>//;
		while ($singleXML) { # split for CIM elements
			# search next tag
			$singleXML =~ m/^<([^:]*:[^ >]*)[ >].*/;
			my $tag = $1;
			#print "    ___ $tag ___\n" if ($tag);
			my $tagXML = undef;
			#$singleXML =~ m/(<$tag.*$tag>).*/;
			$singleXML =~ m/(<$tag[^>]*[^<]*<[^>]*$tag>).*/;
			$tagXML = $1 if ($1);
			#print "nil ? $tagXML\n";
			$tagXML = undef if ($tagXML eq $tag);
			my $isNil = 0;
			if (!$tagXML) {
			    #print "nil\n";
			    $singleXML =~ m/(<$tag[^>]*>)/;
			    $tagXML = $1 if ($1);
			    $isNil = 1;
			}
			#print "=== $tagXML ===\n" if ($tagXML);
			push (@tagArray, $tagXML);
			if (!$isNil) {
			    #$singleXML =~ s/<$tag.*$tag>\s*// if (!$isNil); # there might be special chars inside the tags
			    # be aware of "arrays" of tags
			    $singleXML =~ s/^<$tag[^>]*>//;
			    $singleXML =~ s/^[^>]*>\s*//;
			}
			$singleXML =~ s/<$tag[^>]*>\s*// if ($isNil); # there might be special chars inside the attributes
			#print "+--$singleXML--+\n" if ($singleXML);
			#$singleXML = undef;
		} # split into elements
		my $items;
		#print "Tag-Counter = $#tagArray";
		for((my $cnt = 0) ; ($cnt<=$#tagArray) ; ($cnt++)) { # split key value
			$tagArray[$cnt] =~ m/>(.*)</;
			my $value = $1;
			$tagArray[$cnt] =~ m/^<[^:]*:([^ >]*).*>/;
			my $key = $1;
			$value = '' if (!defined $value);
			#print "...key=$key value=$value\n";
			next if ((!defined $value) and !$main::verbose);
			next if (!$value and $value !~ m/^\d+$/ and !$main::verbose); # empty strings
			if ($items and $items->{$key}) {
			    my $store = $items->{$key};
			    $store = '"' . $store . '"' if ($store !~ m/^\"/);
			    $store .= ",";
			    $store .= "\"$value\"";
			    $items->{$key} = $store;
			} else {
			    $items->{$key} = $value;
			}
		} # for CIM elements

		#push (@list, [@tagArray]) if (@tagArray);
		push (@list, $items);
	} # for each class stream

	$exitCode = 0 if ($foundPullresponse);
	close $pHandle;
	return @list;
	
  } # cimWSExecEnumerateClass

##### CIM ###############################################################
  sub cimInitConnection {
	cimWSMANInitConnection() if ($optUseMode eq "W");
	cimWSExecInitConnection() if ($optUseMode eq "WE");
  } #cimInitConnection

  sub cimFinishConnection {
	cimWSMANFinishConnection() if ($optUseMode eq "W");
	cimWSExecFinishConnection() if ($optUseMode eq "WE");
  } # cimFinishConnection

  sub cimIdentify {
	cimWSMANIdentify() if ($optUseMode eq "W");
	cimWSExecIdentify() if ($optUseMode eq "WE");
  } #cimIdentify

  sub cimEnumerateClass {
	my $class = shift;
	return cimWSMANEnumerateClass($class) if ($optUseMode eq "W");
	return cimWSExecEnumerateClass($class) if ($optUseMode eq "WE");
  } #cimEnumerateClass

  sub cimInvoke {
	my $class = shift;
	my $method = shift;
	# no way to use wsman executable
	return cimWSMANInvoke($class, $method);
  } # cimInvoke

  sub cimModify {
	my $class = shift;
	my $method = shift;
	# not implemented - wsman executable
	return cimWSMANModify($class);
  } # cimModify

  sub cimPrintClass {
	my $refList = shift; # ATTENTION: Array Parameter always as reference !
	my $className = shift;
	my @list = @{$refList};
	my $printClass = '';
	$printClass = " CLASS: " . $className if ($className);
	# Print output.
	addMessage("l","MAXINDEX: " . $#list . "$printClass\n");
	foreach(@list) {
	    addMessage("l", "{---------------------------------------------------\n");
	    my %route = %$_;
	    foreach my $key (keys %route) {
		addMessage("l", "" .  $key . ": " . $route{$key} . "\n");
	    }
	    addMessage("l", "}---------------------------------------------------\n");
	}
  } #cimPrintClass

#########################################################################
  sub initCIMConnection {
	# Check Availability and Type:
	cimInitConnection();
	if ($clientSession and $exitCode != 2 and ($optChkIdentify or !$optServiceMode)) {
		cimIdentify(); # ... silent for all other calls besides chkidentify
	} # session
  } # initCIMConnection
  sub finishCIMConnection {
	cimFinishConnection() if ($clientSession);
  } #finishCIMConnection
#########################################################################
sub processData {
	# Check Availability and Type:
	initCIMConnection();
	if ($exitCode != 2 and $optChkClass) {
		$exitCode = 3 if (!$optChkIdentify); # not only identify
		my @classInstances = cimEnumerateClass($optClass);
		cimPrintClass(\@classInstances, $optClass);
	} 
	if ($exitCode != 2 and $optInvoke) {
		$exitCode = 3;
		cimInvoke($optClass, $optMethod); 
	}
	if ($exitCode != 2 and $optModify) {
		$exitCode = 3;
		cimModify($optClass); 
	}
	finishCIMConnection();
} # processData

#### MAIN ################################################################

#evaluateGetOptions();
handleOptions();

#### set timeout
local $SIG{ALRM} = sub {
	#### TEXT LANGUAGE AWARENESS
	print 'UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($optTimeout);

##### DO SOMETHING

$exitCode = 3;

$|++; # for unbuffered stdout print (due to Perl documentation)

processData();

#### 

# output to nagios
#$|++; # for unbuffered stdout print (due to Perl documentation)
$msg =~ s/^\s*//gm; # remove leading blanks
$notifyMessage =~ s/^\s*//gm; # remove leading blanks
$notifyMessage =~ s/\s*$//m; # remove last blanks
$notifyMessage = undef if ($main::verbose < 1 and ($exitCode==0));
$longMessage =~ s/^\s*//m; # remove leading blanks
$longMessage =~ s/\s*$//m; # remove last blanks
$variableVerboseMessage =~ s/^\s*//m; # remove leading blanks
$variableVerboseMessage =~ s/\n$//m; # remove last break

finalize(
	$exitCode, 
	$state[$exitCode], 
	$msg,
	(! $notifyMessage ? '': "\n" . $notifyMessage),
	($longMessage eq '' ? '' : "\n" . $longMessage),
	($main::verbose >= 2 or $main::verboseTable) ? "\n" . $variableVerboseMessage: "",
	($performanceData ? "\n |" . $performanceData : ""),
);
################ EOSCRIPT


