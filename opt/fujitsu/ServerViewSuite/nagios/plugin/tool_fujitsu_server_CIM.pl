#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2014, 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.00
# Date:		2015-11-11

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;


our $wsmanPerlBindingScript = "fujitsu_server_wsman.pl";
our $wbemcliScript = "check_fujitsu_server_CIM.pl";

=head1 NAME

tool_fujitsu_server_CIM.pl - Tool around Fujitsu servers for unscheduled calls using CIM protocol

=head1 SYNOPSIS

tool_fujitsu_server_CIM.pl 
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      [-U|--use=<mode>]
      [--cacert=<cafile>]
      [--cert=<certfile> --privkey=<keyfile>] 
      { -u|--user=<username> -p|--password=<pwd> 
      } |
      -I|--inputfile=<filename>
    }
    { [--typetest [--nopp]] 
      | --connectiontest
      | --ipv4-discovery }
    }
    [--ctimeout=<connection timeout in seconds>]
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } | [-h|--help] | [-V|--version] 

Tool around Fujitsu servers for unscheduled calls using CIM protocol

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

This option is used for wbemcli or openwsman calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>] [-U|--use=<mode>]

CIM service port number and transport type and the selection of wbemcli versus wsman Perl binding. 

WBEMCLI USAGE: The program wbemcli uses a default port 5989 for the calls - It is not 
necessary to enter this number.

WS-MAN USAGE: The port number must be set because there exists no common default 
for corresponding WS-MAN services. For some known port numbers the transport type is automatic set.

In the transport type 'http' or 'https' can be specified. 'https' is default for wbemcli.

To select WS-MAN usage enter "W" as use mode - "C" is default and is meant for "CIM-XML" usage.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item -u|--user=<username> -p|--password=<pwd>

Authentication data. For use in cim-xml protocol (wbemcli) the password must
not contain any '.'.

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [--cacert=<cafile>]

For wbemcli: CA certificate file. If not set -noverify will be used.
    See wbemcli parameter -cacert

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item [--cert=<certfile> --privkey=<keyfile>]

For wbemcli: Client certificate file and Client private key file.
    wbemcli requires both file names if this should be used.
    It depends on configuration on the host side if these 
    certificates are verified or not !
    See wbemcli parameter -clientcert and -clientkey

These options are used for wbemcli or openwsman calles without any preliminary checks.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.

=item --typetest [--nopp]

CIM test checking variable ports (if not specified) for the various CIM services
and test with credential. 
Test of availability of ServerView Classes and reading server type specific information.
As a result the type of a server can be checked.
This is the default option for this tool script.

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --connectiontest [--nopp]

CIM test checking variable ports (if not specified) for the various CIM services
and test with credentials. 

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --ipv4-discovery

SNMP test of various MIBs if accessible for 256 servers for a given n.n.n. IPv4 address. 
As a result the type of these server are checked.

=item [--ctimeout=<connection timeout in seconds>]

Timeout for the connection test to the CIM service. Default is 30 seconds.
All values higher than 30 will be ignored.

=item -t|--timeout=<timeout in seconds>

Timeout for the script processing.

=item -v|--verbose=<verbose mode level>

Enable verbose mode (levels: 6, 10).
Print additional CIM class data (only few) and print additional information
about inside script calls.

=item -V|--version

Print version information and help text.

=item -h|--help

Print help text.

=cut

# define states
#### TEXT LANGUAGE AWARENESS (Standard in Nagios-Plugin)
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# init main options
our $argvCnt = $#ARGV + 1;
our $optHost = '';
our $optTimeout = 0;
our $optShowVersion = undef;
our $optHelp = undef;
our $optPort = undef;
our $optInputFile = undef;

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

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::processPrint = 1;

# init additional options
our $optTypeTest	= undef;
our $optConnectionTest	= undef;
our $optIpv4Discovery	= undef;

our $optExtended	= undef;
our $optNoProcessPrint	= undef;
our $optConnectTimeout	= undef;

# define and init output data
our $msg = '';
our $longMessage = '';
our $exitCode = 3;
our $variableVerboseMessage = '';
our $notifyMessage = '';

# other globals
our $isWINDOWS = undef;
our $isLINUX = undef;
our $isESXi = undef;
our $isiRMC = undef;
$main::scriptPath = undef;
our @gCntCodes = ( 0,0,0,0,0 );
#our @gCodesText = ( "ok", "no-cim", "no-cim-access", "timeout", "unknown");
our $usableCIMXML = undef;
our $usableWSMAN = undef;

our @components = ();

###################################################################################
#----------- print functions
  sub intermediatePrint {
	my $string = "@_";
	print "$string" if ($string);
	print "\n";
  }
  sub finalize {
	my $exitCode = shift;
	my $string = "@_";
	print "$string" if ($string);
	print "\n";
	alarm(0); # stop timeout
	exit($exitCode);
  }

####
sub addMessage {
	my $container = shift;
	my $string = "@_";
	if ($string) {
		$msg .= $string				if ($container =~ m/.*m.*/);
		$notifyMessage .= $string		if ($container =~ m/.*n.*/);
		$longMessage .= $string			if ($container =~ m/.*l.*/);
		$variableVerboseMessage .= $string	if ($container =~ m/.*v.*/);
	}
} #addMessage
sub addAdminURL {
	my $admURL = shift;
	my $tmp = '';
	$admURL = undef if ($admURL and ($admURL !~ m/http/));
	$admURL = undef if ($admURL and ($admURL =~ m/0\.0\.0\.0/));
	$admURL = undef if ($admURL and ($admURL =~ m/255\.255\.255\.255/));
	$admURL = undef if ($admURL and ($admURL =~ m/\/\/127\./));
	$tmp .= "    AdminURL\t= $admURL\n" if ($admURL);
	addMessage("l",$tmp);
}
# for inventory prints
sub add1stLevel {
	my $string = shift;
	return if (!$string);
	print "* $string\n";
}
sub add2ndKeyValue {
	my $key = shift;
	my $value = shift;
	return if (!$key or !$value);
	$value = "\"$value\"" if ($value =~ m/\s/);
	$value = " $value"    if ($value !~ m/\s/);
	print "    $key\t=$value\n";
}
sub addInvAdminURL {
	my $admURL = shift;
	my $tmp = '';
	$admURL = undef if ($admURL and ($admURL !~ m/http/));
	$admURL = undef if ($admURL and ($admURL =~ m/0\.0\.0\.0/));
	$admURL = undef if ($admURL and ($admURL =~ m/255\.255\.255\.255/));
	$admURL = undef if ($admURL and ($admURL =~ m/\/\/127\./));
	print "    AdminURL\t= $admURL\n" if ($admURL);
}
###############################################################################
# OPTIONS
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
		-verbose	=> 1,
		-exitval	=> 3
	) if ($optHost eq '');

	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}

	# Defaults
	$optTypeTest = 999 if (!defined $optTypeTest 
		and !defined $optConnectionTest and !defined $optIpv4Discovery
		);
  } #evaluateOptions
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
			"H|host=s",	
		       	"P|port=i",	
		       	"T|transport=s",	
		        "U|use=s",
		       	"S|service=s",	
		       	"t|timeout=i",	
		       	"v|verbose=i",	
		       	"V|version",	
		       	"h|help",	
	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
		       	"typetest",	
		       	"connectiontest",	
		       	"ipv4-discovery",
			"e|extended",	
			"nopp",	
			"ctimeout=i",	
	   		"I|inputfile=s", 
			"inputdir=s",
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
			"H|host=s",	
		       	"P|port=i",	
		       	"T|transport=s",	
		        "U|use=s",
		       	"S|service=s",	
		       	"t|timeout=i",	
		       	"v|verbose=i",	
		       	"V|version",	
		       	"h|help",	
	   		"u|user=s", 
	   		"p|password=s", 
	   		"cert=s", 
	   		"privkey=s", 
	   		"cacert=s", 
		       	"typetest",	
		       	"connectiontest",	
		       	"ipv4-discovery",
			"e|extended",	
			"nopp",	
			"ctimeout=i",
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
  sub handleOptions { # script specific
	# read all options and return prioritized
	my %options = readOptions();

	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k = undef;
	$k="ctimeout";	$optConnectTimeout = $options{$k} if ($options{$k});

	# remark: ... the loop is unnecessary
	foreach my $key (sort keys %options) {
		#print "options: $key = $options{$key}\n";

	        $optShowVersion = $options{$key}              	if ($key eq "V"			); 
		$optHelp = $options{$key}	               	if ($key eq "h"			);
		$optHost = $options{$key}                     	if ($key eq "H"			);
		$optPort = $options{$key}                     	if ($key eq "P"		 	);
		$optTransportType = $options{$key}            	if ($key eq "T"			);
		$optUseMode = $options{$key}			if ($key eq "U"			);
		$optUseMode = $options{$key}			if ($key eq "U"			);
		#$optServiceMode = $options{$key}		if ($key eq "S"			);
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 

		$optTypeTest = $options{$key}              	if ($key eq "typetest"		);	 
		$optConnectionTest = $options{$key}             if ($key eq "connectiontest"	);	 
		$optIpv4Discovery = $options{$key}              if ($key eq "ipv4-discovery"	); 
		$optExtended = $options{$key}			if ($key eq "e"			); 
		$optNoProcessPrint = $options{$key}		if ($key eq "nopp"		); 

		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		$optCert = $options{$key}             		if ($key eq "cert"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey" 		);
		$optCacert = $options{$key}             	if ($key eq "cacert"	 	);
		$optInputFile = $options{$key}          	if ($key eq "I"	 		);

	}

	# evaluateOptions expects options set in global variables
	evaluateOptions();
  } #handleOptions

###############################################################################
use IO::Socket;
  sub socket_checkSCS {
	my $host = shift;
	return undef if (!$host);
	my $EOL = "\015\012";
	my $BLANK = $EOL x 2;
	my $document = "/cmd?t=connector.What&aid=svnagiostool";
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

###############################################################################
  sub cimScriptEnumerateClass {
	my $class = shift;
	my $cmdParams = shift;
	return undef if (!$class);
	my $useFormAdd = undef;
	my $oneXML = undef;
	my @listXML = ();
	my @list = ();

	my $script = $wbemcliScript . " " . $cmdParams;
	my $cmd = $script . " --chkclass -C$class";
	my $cmdPrint = $cmd;
	$cmdPrint =~ s/ \'[^\']*\' / **** /g;
	print "... CMD: $cmdPrint\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	#identic - open (my $pHandle, "$cmd |");
	
	#print "**** read data ...\n" if ($main::verbose > 20); 
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
		#print if ($main::verbose >= 60); # $_

	}
	$oneXML = undef if (defined $oneXML and $oneXML eq "");
	push (@listXML, $oneXML) if ($oneXML);
	#print "ClassCounter=$#listXML\n" if ($main::verbose >= 60);
	#print "**** check error data ...\n" if ($main::verbose > 20); 
	if (!$foundClass) { ###### ERROR CASE
	    my $allStderr = $oneXML;
	    $allStderr =~ s/MAXINDEX.*//;
	    $allStderr =~ s/instances./instances of class $class/;
	    #addMessage("n", $allStderr);
	    #print "$allStderr" if ($main::verbose >= 10); 
	}
	if ($foundClass) {
		#print "**** split class fields ...\n" if ($main::verbose 2 10); 
		
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
			    my $key = undef;
			    $tagArray[$cnt] =~ m/([^:]+)\:/;
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
	#print "**** close pipe ...\n" if ($main::verbose > 20); 
	close $pHandle;
	return @list;
  } # cimScriptEnumerateClass

  sub cimEnumerateClass {
	my $class = shift;
	my $cmdParams = shift;
	return cimScriptEnumerateClass($class, $cmdParams);
  }

  sub cimPrintClass { # for tests
	my $refList = shift; # ATTENTION: Array Parameter always as reference !
	my $className = shift;

	my @list = @{$refList};
	my $printClass = '';
	$printClass = " CLASS: " . $className if ($className);
	# Print output.
	print "MAXINDEX: " . $#list . "$printClass\n";
	foreach(@list) {
	    print "{---------------------------------------------------\n";
	    my %route = %$_;
	    foreach my $key (keys %route) {
		print $key,": ",$route{$key},"\n";
	    }
	    print "}---------------------------------------------------\n";
	}
  } #cimPrintClass


###############################################################################
  sub buildCommonParameters {
	my $params = '';
	$params .= "-H $optHost";
	$params .= " -P $optPort"	    if ($optPort);		# this might be predefinied
	$params .= " -T $optTransportType"  if ($optTransportType);	# this might be predefinied
	$params .= " -U $optUseMode"	    if ($optUseMode);		# this might be predefinied
	#$params .= " -t $optTimeout"	    if ($optTimeout);
	#$params .= " -v $main::verbose"	    if ($main::verbose);
	$params .= " -u '$optUserName'"	    if ($optUserName);
	$params .= " -p '$optPassword'"	    if ($optPassword);
	$params .= " --cert $optCert"		    if ($optCert);
	$params .= " --privkey $optPrivKey"	    if ($optPrivKey);
	$params .= " --cacert $optCacert"	    if ($optCacert);
	$params .= " -I$optInputFile"	    if ($optInputFile);
	return $params;
  } #
  sub oneConnectionTest {
	my $cmd = shift;
	my $printCmd = shift;

	if (!$optConnectTimeout or $optConnectTimeout > 30) {
	    $cmd .= " -t30";
	    $printCmd .= " -t30";
	} else {
	    $cmd .= " -t$optConnectTimeout";
	    $printCmd .= " -t$optConnectTimeout";
	}

	my $rc = undef;
	print "... CMD: $printCmd\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	my $result = join ('', <$pHandle>);
	#print "[[[$result]]]\n";
	$rc = 0 if ($result =~ m/^OK/);
	$rc = 1 if (!defined $rc and $result =~ m/username\/password/); # CIM-XML
	$rc = 1 if (!defined $rc and $result =~ m/authentication error discovered/); # WSMAN
	$rc = 2 if (!defined $rc and $result =~ m/Couldn\'t connect to server/); # both
	$rc = 3 if (!defined $rc and $result =~ m/Timeout/i); # both
	$rc = 4 if (!defined $rc);
	    # " unable to get identify information "
	if (defined $rc and $rc == 0) {
	    my $typeInfo = undef;
	    $result =~ m/Type\=([^\s]*)/;
	    $typeInfo = $1;
	    if ($typeInfo) {
		$isWINDOWS = 1 if ($typeInfo =~ m/Windows/i);
		$isESXi = 1 if ($typeInfo =~ m/ESXi/i);
		$isLINUX = 1 if ($typeInfo =~ m/Linux/i);
		$isiRMC = 1 if ($typeInfo =~ m/iRMC/i);
	    }
	}
	if ($main::processPrint and defined $rc) {
		print "... RESPONSE: $result\n" if ($rc==4); # unusual returns
		print "<<< ";
		print "OK" if (!$rc);
		print "AUTHENTICATION ERROR" if ($rc==1);
		print "CONNECTION ERROR" if ($rc==2);
		print "TIMEOUT" if ($rc==3);
		print "UNKNOWN" if ($rc==4);
		print "\n"
	}
	return $rc;
  } # oneConnectionTest
  sub connectionTest {
	my $cmdParams = shift;
	$cmdParams .= " --chkidentify";
	my $useParams = $cmdParams;

	my $cmd = "$wbemcliScript $useParams";
	
	my $found = 0;
	my $cAuthErr = 0;
	my $cConnErr = 0;
	my $cTimeErr = 0;
	my $cUnkErr = 0;
	my $wAuthErr = 0;
	my $wConnErr = 0;
	my $wTimeErr = 0;
	my $wUnkErr = 0;
	my $port = undef;
	my $prot = undef;
	my $trans = undef;
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;
	# CIM-XML
	if ($usableCIMXML and $optPassword !~ m/\./ and (!$optUseMode or $optUseMode !~ m/^W/)) {
		my $rc = undef;
		# 1st without any explizit settings
		{   
		    print ">>> connect test CIM-XML: use standard parameters\n" if ($main::processPrint);
		    $rc = oneConnectionTest($cmd, $printCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $cUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "<default>" if (!$optPort);
			$prot = "CIM-XML";
			$trans = "<default>" if (!$optTransportType);
		    }
		}
		# 2nd 5989 https
		if (!$found and !$cAuthErr and !$optPort) {
		    $rc = undef;
		    print ">>> connect test CIM-XML: 5989\n" if ($main::processPrint);
		    my $useCmd = $cmd . " -P5989";
		    $useCmd .= " -Thttps" if (!$optTransportType);
		    my $usePrintCmd = $printCmd . " -P5989";
		    $usePrintCmd .= " -Thttps" if (!$optTransportType);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $cUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "5989" if (!$optPort);
			$prot = "CIM-XML";
			$trans = "https" if (!$optTransportType);
		    }
		} #5989
		# 3rd 5988 http
		if (!$found and !$cAuthErr and !$optPort) {
		    print ">>> connect test CIM-XML: 5988\n" if ($main::processPrint);

		    my $useCmd = $cmd . " -P5988";
		    $useCmd .= " -Thttp" if (!$optTransportType);
		    my $usePrintCmd = $printCmd . " -P5988";
		    $usePrintCmd .= " -Thttp" if (!$optTransportType);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $cUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "5988" if (!$optPort);
			$prot = "CIM-XML";
			$trans = "http" if (!$optTransportType);
		    }
		} #5988
	} # CIM-XML
	if (!$found and $usableWSMAN and (!$optUseMode or $optUseMode !~ m/^C/)) {
		$cmd .= " -UW" if (!$optUseMode);
		$printCmd .= " -UW" if (!$optUseMode);
		# 1st 5986 https	(WIN, LX)
		my $rc = undef;
		{
		    print ">>> connect test WS-MAN: entered parameters or port 5986\n" if ($main::processPrint);

		    my $useCmd = $cmd;
		    $useCmd .= " -P5986" if (!$optPort);
		    $useCmd .= " -Thttps" if (!$optTransportType and !$optPort);
		    my $usePrintCmd = $printCmd;
		    $usePrintCmd .= " -P5986" if (!$optPort);
		    $usePrintCmd .= " -Thttps" if (!$optTransportType and !$optPort);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $wUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "5986" if (!$optPort);
			$prot = "WS-MAN";
			$trans = "https" if (!$optTransportType and !$optPort);
		    }		
		} # 5986
		# 2nd 5985 http		(WIN, LX)
		if (!$found and !$wAuthErr and !$optPort) {
		    print ">>> connect test WS-MAN: port 5985\n" if ($main::processPrint);

		    my $useCmd = $cmd;
		    $useCmd .= " -P5985" if (!$optPort);
		    $useCmd .= " -Thttp" if (!$optTransportType);
		    my $usePrintCmd = $printCmd;
		    $usePrintCmd .= " -P5985" if (!$optPort);
		    $usePrintCmd .= " -Thttp" if (!$optTransportType);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $wUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "5985" if (!$optPort);
			$prot = "WS-MAN";
			$trans = "http" if (!$optTransportType);
		    }		
		} #5985
		# 3rd 8888 https	(ESXi)
		if (!$found and !$wAuthErr and !$optPort) {
		    print ">>> connect test WS-MAN: port 8888\n" if ($main::processPrint);

		    my $useCmd = $cmd;
		    $useCmd .= " -P8888" if (!$optPort);
		    $useCmd .= " -Thttps" if (!$optTransportType);
		    my $usePrintCmd = $printCmd;
		    $usePrintCmd .= " -P8888" if (!$optPort);
		    $usePrintCmd .= " -Thttps" if (!$optTransportType);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $wUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "8888" if (!$optPort);
			$prot = "WS-MAN";
			$trans = "https" if (!$optTransportType);
		    }		
		} #8888
		# 4th 8889 http		(ESXi)
		if (!$found and !$wAuthErr and !$optPort) {
		    print ">>> connect test WS-MAN: port 8889\n" if ($main::processPrint);

		    my $useCmd = $cmd;
		    $useCmd .= " -P8889" if (!$optPort);
		    $useCmd .= " -Thttp" if (!$optTransportType);
		    my $usePrintCmd = $printCmd;
		    $usePrintCmd .= " -P8889" if (!$optPort);
		    $usePrintCmd .= " -Thttp" if (!$optTransportType);

		    $rc = oneConnectionTest($useCmd, $usePrintCmd);
		    $found = 1 if (defined $rc and !$rc);
		    $cAuthErr = 1 if ($rc and $rc == 1);
		    $cConnErr = 1 if ($rc and $rc == 2);
		    $cTimeErr = 1 if ($rc and $rc == 3);
		    $wUnkErr = 1 if ($rc and $rc == 4);
		    if ($found) {
			$port = "8889" if (!$optPort);
			$prot = "WS-MAN";
			$trans = "http" if (!$optTransportType);
		    }		
		} #8889
	} # WS-MAN

	# for printouts
	#$longMessage .= "    InAddress\t= $optHost\n";
	if ($found) {
		    $port = $optPort if (!$port);
		    $trans = $optTransportType if (!$trans);
		    $longMessage .= "    Protocol\t= $prot \n" if ($prot);
		    $longMessage .= "    Port\t= $port \n" if ($port);
		    $longMessage .= "    TransType\t= $trans \n" if ($trans);
		    $longMessage .= "    ServiceType\t= Windows\n" if ($isWINDOWS);
		    $longMessage .= "    ServiceType\t= Linux\n" if ($isLINUX);
		    $longMessage .= "    ServiceType\t= ESXi\n" if ($isESXi);
		    $longMessage .= "    ServiceType\t= iRMC\n" if ($isiRMC);
		    $longMessage .= "    OptionFile\t= $optInputFile\n" if ($optInputFile);
		    $gCntCodes[0]++;
	} elsif ($cAuthErr or $wAuthErr) {
		    $msg .= " - AUTHENTICATION FAILED ";
		    $gCntCodes[2]++;
	} elsif ($cConnErr or $wConnErr) {
		    $msg .= " - CONNECTION FAILED ";
		    $gCntCodes[1]++;
	} elsif ($cTimeErr or $wTimeErr) {
		    $msg .= " - TIMEOUT ";
		    $gCntCodes[3]++;
	} elsif ($cUnkErr or $wUnkErr) {
		    $msg .= " - MISCELLANEOUS";
		    $gCntCodes[4]++;
	}
	# additional command parameters and option settings
	my $newParams = '';
	if ($found) {
		if (!$optPort and $port and $port !~ m/default/) {
			$optPort = $port;
			$newParams .= " -P $optPort";
		}
		if (!$optTransportType and $trans and $trans !~ m/default/) {
			$optTransportType = $trans;
			$newParams .= " -T $optTransportType";
		}
		if (!$optUseMode and $prot =~ m/^WS/) { #WS-MAN
			$optUseMode = "W"; 
			$newParams .= " -U $optUseMode";
		}
	}
	$exitCode = 0 if ($found);
	return $newParams;
  } #connectionTest
###############################################################################
  sub getComputerSystemInfo {
	my $cmdParams = shift;
	return if (!$usableCIMXML);
	my $cmd = '';

	my $useParams = $cmdParams . " --systeminfo";
	$cmd = "$wbemcliScript $useParams";
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;

	my $found = 0;

	print ">>> get basic systeminfo\n" if ($main::processPrint);
	print "... CMD: $printCmd\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	my $result = join ('', <$pHandle>);
	$found = 1 if ($result =~ m/Name/ or $result =~ m/Model/);
	$result =~ s/.*Name/Name/;
	#print "---$result---\n";
	my $name = undef;
	my $admURL = undef;
	my $os = undef;
	my $mmbAddress = undef;
	my $model = undef;
	if ($result =~ m/Name/) {
	    $result =~ m/Name=(\"[^\"]+\")/;
	    $name = $1 if ($1);
	    $result =~ m/Name=([^\s]+)/ if (!$name);
	    $name = $1 if ($1 and !$name);
	}
	if ($result =~ m/AdminURL/) {
	    $result =~ m/AdminURL=(\"[^\"]+\")/;
	    $admURL = $1 if ($1 and $1 ne $name);
	    $result =~ m/AdminURL=([^\s]+)/ if (!$admURL);
	    $admURL = $1 if ($1 and !$admURL and (!$name or $1 ne $name));
	}
	if ($result =~ m/OSDescription=/) {
	    $result =~ m/OSDescription=(\"[^\"]+\")/;
	    $os = $1 if ($1 and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	    $result =~ m/OSDescription=([^\s]+)/ if (!$os);
	    $os = $1 if ($1 and !$os and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	}
	if (!$os and $result =~ m/OS=/) {
	    $result =~ m/OS=(\"[^\"]+\")/;
	    $os = $1 if ($1 and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	    $result =~ m/OS=([^\s]+)/ if (!$os);
	    $os = $1 if ($1 and !$os and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	}
	if ($result =~ m/ParentMMB=/ and $optExtended) {
	    $result =~ m/ParentMMB=([^\s]+)/;
	    $mmbAddress = $1 if ($1 and (!$os or $1 ne $os) and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	}
	if ($result =~ m/Model=/) {
	    $result =~ m/Model=\"([^\"]+)\"/;
	    $model = $1 if ($1 and (!$mmbAddress or $1 ne $mmbAddress) and (!$os or $1 ne $os) and (!$name or $1 ne $name) and (!$admURL or $1 ne $admURL));
	}

	if ($found) {
	    $longMessage .= "\n";
	    $longMessage .= "    Name\t= $name\n" if ($name);
	    $longMessage .= "    Name\t= N.A.\n" if (!$name);
	    $longMessage .= "    Model\t= $model\n" if ($model);
	    $longMessage .= "    AdminURL\t= $admURL\n" if ($admURL);
	    $longMessage .= "    Parent Address\t= $mmbAddress\n" if ($mmbAddress);
	    $longMessage .= "    OS\t\t= $os\n" if ($os);
	    print "<<< OK\n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN - no SVS information available\n" if ($main::processPrint);
	}
	return $found;
  } #getComputerSystemInfo

  sub getUpdateStatus {
	my $cmdParams = shift;
  	print ">>> get server update status \n" if ($main::processPrint);
	my @classInstances = ();
	if (!$isiRMC) {   
	    @classInstances = cimEnumerateClass("SVS_PGYComputerSystem", $cmdParams);
	    cimPrintClass(\@classInstances, "SVS_PGYComputerSystem") if ($main::verbose > 5);
	} else {
	    @classInstances = cimEnumerateClass("SVS_iRMCBaseServer", $cmdParams);
	    cimPrintClass(\@classInstances, "SVS_iRMCBaseServer") if ($main::verbose > 5);
	}
	my $updStatus = undef;
	if ($#classInstances >= 0) {
	    my $ref1stClass = $classInstances[0]; # There should be only one instance !
	    my %compSystem = %{$ref1stClass};
	    $updStatus = $compSystem{"ServerUpdateStatus"};
	    $updStatus = 3 if (defined $updStatus and $updStatus =~ m/^\s*$/);
	} #SVS_PGYComputerSystem
	my $tmpExitCode = 3;
	$tmpExitCode = $updStatus if (defined $updStatus and $updStatus <= 3);
	if (defined $updStatus) {
	    #addComponentStatus("m", "UpdateStatus",$state[$tmpExitCode]);
	    addMessage("l", "    UpdateAgent\t= Status($state[$tmpExitCode]) Monitoring=available\n");
	    print "<<< OK \n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN \n" if ($main::processPrint);
	}
  } #getUpdateStatus

  our $svAgentVersion = undef;
  sub getAgentsVersion {
	my $cmdParams = shift;
	return if (!$cmdParams);
	# ATTENTION - AgentInfo might be a multi-used-class in future
	print ">>> get agent version\n" if ($main::processPrint);
	my @classInstances = ();
	if (!$isiRMC) {
	    {   
		@classInstances = cimEnumerateClass("SVS_PGYCIMProviderIdentity", $cmdParams);
	    }
	    if ($#classInstances < 0 and (!$optServiceMode or $optServiceMode eq "W" or $optServiceMode eq "L") ) {
		if (!$optServiceMode) {
		    $optServiceMode = "W621" if ($isWINDOWS);
		    $optServiceMode = "L621" if ($isLINUX);
		} else {
		    $optServiceMode .= "621";
		}
		$cmdParams .= " -S$optServiceMode" if ($optServiceMode);

		@classInstances = cimEnumerateClass("SVS_PGYCIMProviderIdentity", $cmdParams);
	    }
	    if ($#classInstances >= 0) {
		cimPrintClass(\@classInstances, "SVS_PGYCIMProviderIdentity") if ($main::verbose > 5);
		my $ref1stClass = $classInstances[0]; # There should be only one instance !
		my %first = %{$ref1stClass};

		my $caption = $first{"Caption"};
		my $version = $first{"VersionString"};
		my $manu = $first{"Manufacturer"};

		$caption = undef if (defined $caption and $caption =~ m/^\s*$/);
		$version = undef if (defined $version and $version =~ m/^\s*$/);
		$manu = undef if (defined $manu and $manu =~ m/^\s*$/);
		$svAgentVersion = $version;

		$caption = "ServerView CIM Provider" if ($caption and $caption =~ m/svs_cimprovider/);
		if ($caption and $version) {
	
		    addMessage("l", "    Agent\t= $caption\n") if ($caption);
		    addMessage("l", "    AgentVersion= $version\n") if ($version);
		    addMessage("l", "    AgentOrigin\t= $manu\n") if ($manu);
		    print "<<< OK \n" if ($main::processPrint);
		} else {
		    print "<<< UNKNOWN corrupt CIM information\n" if ($main::processPrint);
		}
	    } #SVS_PGYCIMProviderIdentity
	} # not iRMC
	else { # iRMC
	    @classInstances = ();
	    {
		@classInstances = cimEnumerateClass("SVS_iRMCSoftwareIdentity", $cmdParams);
		cimPrintClass(\@classInstances, "SVS_iRMCSoftwareIdentity") if ($main::verbose > 5);
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
		    addMessage("l", "    FWVersion\t= $versionString\n") if ($versionString);
		    print "<<< OK \n" if ($main::processPrint);
		}
	    } #SVS_iRMCSoftwareIdentity
	} # iRMC
	if ($#classInstances < 0) {
	    print "<<< UNKNOWN agent version\n" if ($main::processPrint);
	}
  } #getAgentsVersion

  sub getComponentList {
	my $cmdParams = shift;
	return if ($isiRMC);
	my $foundPGYSubsystem = 0;
	my $foundPGYHealthStateComponent = 0;
	print ">>> get component list\n" if ($main::processPrint);
	#$cmdParams .= " -S$optServiceMode" if ($optServiceMode);
	my @classInstances = ();
	my $classnm = undef;
	if ($isESXi) {
		@classInstances = cimEnumerateClass("SVS_PGYSubsystem", $cmdParams);
		$foundPGYSubsystem = 1 if ($#classInstances >= 0);
		$classnm = "SVS_PGYSubsystem" if ($#classInstances >= 0);
	}
	if (!$foundPGYSubsystem) {
		@classInstances = cimEnumerateClass("SVS_PGYHealthStateComponent", $cmdParams);
		if ($#classInstances < 0 and $optUseMode and $optUseMode =~ m/^W/ ) 
		{
		    if (!$optServiceMode) {
			$optServiceMode = "W621" if ($isWINDOWS);
			$optServiceMode = "L621" if ($isLINUX);
		    } else {
			$optServiceMode .= "621";
		    }
		    $cmdParams .= " -S$optServiceMode" if ($optServiceMode);

		    @classInstances = cimEnumerateClass("SVS_PGYHealthStateComponent", $cmdParams);
		}
		$foundPGYHealthStateComponent = 1 if ($#classInstances >= 0);
		$classnm = "SVS_PGYHealthStateComponent" if ($#classInstances >= 0);
	}
	cimPrintClass(\@classInstances, $classnm) 
	    if ($main::verbose > 5 and $#classInstances >= 0);
  	if (!$foundPGYSubsystem and !$foundPGYHealthStateComponent) {
		print "<<< UNKNOWN - Unable to get ServerView subsystem summary status CIM information\n" 
		    if ($main::processPrint);
		return;
	} elsif ($#classInstances == 0) {
		print "<<< UNKNOWN - Corrupt ServerView subsystem summary status CIM information\n" 
		    if ($main::processPrint);
		return;
	}
	if ($foundPGYSubsystem) {
		foreach my $refClass (@classInstances) {
		    my %oneClass = %{$refClass};
		    my $name = $oneClass{"ElementName"};
		    #my $subStatus = $oneClass{"SubsystemStatus"};
		    if ($name) {
			if ($name =~ m/Enviro.*ment/i) { # "Enviroment" - write error is in CIM provider !
			    push(@components, "Environment");
			} elsif ($name =~ m/PowerSupply/i) {
			    push(@components, "Power");
			} elsif ($name =~ m/Systemboard/i) {
			    push(@components, "Systemboard");
			} elsif ($name =~ m/MassStorage/i) {
			    push(@components, "MassStorage");
			} else {
			    push(@components, $name);
			}
		    } # name
		} #foreach class instances
		
	} # ESXi
	if ($foundPGYHealthStateComponent) { 
		foreach my $refClass (@classInstances) {
		    my %oneClass = %{$refClass};
		    my $name = $oneClass{"ElementName"};
		    my $ID = $oneClass{"InstanceID"};
		    next if (!$ID or !$name);
		    if ($name and $ID =~ m/^0\-\d+$/) { # InstanceID : 0-n
			if ($name =~ m/Environment/i) {
				push(@components, "Environment");
			} elsif ($name =~ m/Power\s*Supply/i) {
				push(@components, "Power");
			} elsif ($name =~ m/System\s*Board/i) {
				push(@components, "Systemboard");
			} elsif ($name =~ m/Mass\s*Storage/i) {
				push(@components, "MassStorage");
			} else {
				if ($name =~ m/Driver\s*Monitor/i) {
					push(@components, "DriverMonitor");
				} else {
					push(@components, $name);
				}
			}
		    } # 0-n
		} #foreach class instances
	} # foundPGYHealthStateComponent
	if ($#components >= 0) {
	    $longMessage .= "    Components\t= @components \n" if ($#components >= 0);
	    print "<<< OK\n" if ($main::processPrint and $#components >= 0);
	} else {
	    print "<<< UNKNOWN\n" if ($main::processPrint and $#components < 0);
	}
  } #getComponentList

  sub getiRMCAgentUsage {
	my $cmdParams = shift;
      	return if (!$isiRMC or !$optExtended);
  	print ">>> get iRMC agent usage \n" if ($main::processPrint);
	#0 Disconnected
	#1 Management agent connected
	#2 Agentless service connected
	my @agtStatusText = ( "No Agent", "Mgmt. Agent", "Agentless Service", "..undefined..",);

	my @classInstances = ();
	{   
	    @classInstances = cimEnumerateClass("SVS_iRMCServiceProcessor", $cmdParams);
	    cimPrintClass(\@classInstances, "SVS_iRMCServiceProcessor") if ($main::verbose > 5);
	}
	my $agtStatus = undef;
	if ($#classInstances >= 0) {
	    my $ref1stClass = $classInstances[0]; # There should be only one instance !
	    my %service = %{$ref1stClass};
	    $agtStatus = $service{"AgentConnectStatus"};
	    $agtStatus = 3 if ($agtStatus and ($agtStatus > 3 or $agtStatus < 0));
	}
	if (defined $agtStatus) {
	    addMessage("l", "    Agent\t= $agtStatusText[$agtStatus]\n");
	    print "<<< OK \n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN \n" if ($main::processPrint);
	}
  } #getiRMCAgentUsage

  sub getComputerInfos {
	my $svs = 0;
	my $cmdParams = shift;
	return if (!$usableCIMXML);
	$svs = getComputerSystemInfo($cmdParams);
	if ($svs) {
	    my $storeServiceMode = $optServiceMode;
	    getiRMCAgentUsage($cmdParams) if ($optExtended and $isiRMC);
	    getAgentsVersion($cmdParams) if ($optExtended);
	    $cmdParams .= " -S$optServiceMode" 
		if ($optServiceMode 
		    and (!$storeServiceMode or $storeServiceMode ne $optServiceMode));
	    @components = ();
	    getComponentList($cmdParams);
	    $cmdParams .= " -S$optServiceMode" 
		if ($optServiceMode 
		    and (!$storeServiceMode or $storeServiceMode ne $optServiceMode));
	    # SCS/SSM
	    my $chkSSM = 0;
	    if ($optExtended and !$isiRMC) {
		print (">>> ServerView Remote Connector\n") if ($main::processPrint);
		my $scsVersion = socket_checkSCS($optHost);
		print "<<< OK Version=$scsVersion\n" if ($main::processPrint and $scsVersion);
		print "<<< UNKNOWN\n" if ($main::processPrint and !$scsVersion);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.0[4-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.[1-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.[1-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V[3-9]/);
	    }
	    if ($chkSSM) {
		    print (">>> ServerView System Monitor\n") if ($main::processPrint);
		    my $ssmAddress = socket_checkSSM($optHost, $svAgentVersion);
		    print "<<< OK Address=$ssmAddress\n" if ($main::processPrint and $ssmAddress);
		    print "<<< UNKNOWN\n" if ($main::processPrint and !$ssmAddress);
		    $longMessage .= "\n    MonitorURL\t= $ssmAddress\n" if ($ssmAddress);
	    }
	    # Update
	    getUpdateStatus($cmdParams);
	}
  } #getComputerSystem

###############################################################################
  sub typeTest {
	my $commonParams = buildCommonParameters();
	# CIM-XML or WS-MAN access with which port ?
	my $newParams = connectionTest($commonParams);
	if (!$exitCode and $optTypeTest) {
		$commonParams .= $newParams if ($newParams);
		getComputerInfos($commonParams);
	} # connection ok
  } # typeTest

  sub ipv4discovery {
	my $ipv4host = $optHost;
	$|++; # for unbuffered stdout print (due to Perl documentation)
	# initial check of hostaddress
	if ($ipv4host !~ m/^\d+\.\d+\.\d+\.$/) {
		$exitCode = 2;
		$msg .= " - This method requires IPv4 part <n>.<n>.<n>. as host address";
	}
	$ipv4host =~ m/^(\d+)\.(\d+)\.(\d+)\.$/;
	if ($exitCode != 2 and ($1 > 255 or $2 > 255 or $3 > 255)) {
		$exitCode = 2;
		$msg .= " - Errnous number parts in IPv4 host address";
	}
	if ($exitCode != 2) {
		my @cntCodes = ( 0,0,0,0 );
		$main::processPrint = 0;
		$exitCode = 3;
		for (my $i=0;$i < 256;$i++) {
			print (">>> $ipv4host" . "$i\n");
			$optHost = "$ipv4host" . "$i";
			$exitCode = 3;
			typeTest();
			intermediatePrint(	
				$state[$exitCode], 
				($msg?$msg:''),
				(! $longMessage ? '' : "\n" . $longMessage),
				($variableVerboseMessage and ($main::verbose >= 2 
				or $main::verboseTable)) ? "\n" . $variableVerboseMessage: '',);
			$msg				= undef;
			$longMessage			= undef;
			$variableVerboseMessage		= undef;
		}
		$exitCode = 0 if ($gCntCodes[0]);
		$msg .= " -";
		$msg .= " OK($gCntCodes[0])" if ($gCntCodes[0]);
		$msg .= " NO-CIM($gCntCodes[1])" if ($gCntCodes[1]);
		$msg .= " NO-CIM-AUTH($gCntCodes[2])" if ($gCntCodes[2]);
		$msg .= " TIMEOUT($gCntCodes[3])" if ($gCntCodes[3]);
		$msg .= " UNKOWN($gCntCodes[4])" if ($gCntCodes[4]);
	}
  } #ipv4discovery

  sub checkTools { # ... UseMode ???
	my $fileName = undef; 
	$fileName = $main::scriptPath . $wbemcliScript;
	if (! -x $fileName) {
	    $usableCIMXML = 0;
	} else {
	    $usableCIMXML = 1;
	    $wbemcliScript = $main::scriptPath . $wbemcliScript;
	}
	if ($exitCode != 2) {
	    $fileName = $main::scriptPath . $wsmanPerlBindingScript;
	    if (! -x $fileName) {
		    $usableWSMAN = 0;
	    } else {
		    $usableWSMAN = 1;
		    $wsmanPerlBindingScript = $main::scriptPath . $wsmanPerlBindingScript;
	    }
	}
  } #checkTools
###############################################################################
  sub processData {
	$exitCode = 3;
        checkTools(); # set $usable* variables
	if (!$usableCIMXML) {
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the CIM access\n");
	    return;
	} 
	if ($optTypeTest or $optConnectionTest) {
		typeTest();
	} elsif ($optIpv4Discovery) {
		ipv4discovery();
	}
  } #processData
###############################################################################
#------------ MAIN PART

my $path = $0;

handleOptions();

$main::scriptPath = $path;
$main::scriptPath =~ s/[^\/]+$//;

# set timeout
local $SIG{ALRM} = sub {
	#### TEXT LANGUAGE AWARENESS
	print "UNKNOWN: Timeout\n";
	exit(3);
};
alarm($optTimeout);

$main::processPrint = 0 if ($optNoProcessPrint);

processData();

# final output 
my $stateString = $state[$exitCode];
#$stateString = '' if ($optInventory);
finalize(
	$exitCode, 
	$stateString, 
	($msg?$msg:''),
	(! $longMessage ? '' : "\n" . $longMessage),
	(($main::verbose >= 2 or $main::verboseTable) and $variableVerboseMessage) 
		? "\n" . $variableVerboseMessage: '',
);
################ EOSCRIPT


