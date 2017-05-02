#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.00
# Date:		2015-11-12

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

our $checkScript = "check_fujitsu_server_REST.pl";

=head1 NAME

tool_fujitsu_server_REST.pl - Tool around Fujitsu servers using REST protocol

=head1 SYNOPSIS

tool_fujitsu_server_REST.pl 
  {  -H|--host=<host>
    { [-P|--port=<port>] 
      [-T|--transport=<type>]
      { -u|--user=<username> -p|--password=<pwd> 
      } |
      -I|--inputfile=<filename>
    }
    { [--typetest [--nopp]] 
      | --connectiontest
    }
    [--ctimeout=<connection timeout in seconds>]
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } | [-h|--help] | [-V|--version] 

Tool for type and connection tests around Fujitsu servers using REST protocol

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

This option is used for wbemcli or openwsman calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>]

Service port number and transport type.

In the transport type 'http' or 'https' can be specified. 'https' is the default.



=item -u|--user=<username> -p|--password=<pwd>

Authentication data. 

These options are used for curl calles without any preliminary checks.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.

=item --typetest [--nopp]

REST test checking variable ports (if not specified) for the various REST services
and test with credential. 
Test of availability data of the ServerView REST Services.
As a result the type of a server can be checked.
This is the default option for this tool script.

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --connectiontest [--nopp]

REST test checking variable ports (if not specified) for the various REST services
and test with credentials. 

With extra option nopp for no-process-print the inbetween process results are not
printed.

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

# REST authentication
our $optUserName = undef; 
our $optPassword = undef; 

# service specific option
our $optTransportType = undef;
our $optServiceMode = undef;	# AGENT, REPORT, iRMC, ISM, SOA

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::processPrint = 1;

# init additional options
our $optTypeTest	= undef;
our $optConnectionTest	= undef;

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
#our @gCodesText = ( "ok", "no-rest", "no-rest-access", "timeout", "unknown");
our $usableCheck = undef;

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
  sub setOptions {	
	my $refOptions = shift;
	my %options =%$refOptions;
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
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 

		$optTypeTest = $options{$key}              	if ($key eq "typetest"		);	 
		$optConnectionTest = $options{$key}             if ($key eq "connectiontest"	);	 
		$optExtended = $options{$key}			if ($key eq "e"			); 
		$optNoProcessPrint = $options{$key}		if ($key eq "nopp"		); 

		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optPassword = $options{$key}             	if ($key eq "p"		 	);
		$optInputFile = $options{$key}          	if ($key eq "I"	 		);
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
		and !defined $optConnectionTest
		);
  } #evaluateOptions
  sub handleOptions { # script specific
	# read all options and return prioritized
	my %options = readOptions();

	# assign to global variables
	setOptions(\%options);

	# evaluateOptions expects options set in global variables
	evaluateOptions();
  } #handleOptions
###############################################################################
  sub buildCommonParameters {
	my $params = '';
	$params .= "-H $optHost";
	$params .= " -P $optPort"	    if ($optPort);		# this might be predefinied
	$params .= " -T $optTransportType"  if ($optTransportType);	# this might be predefinied
	#$params .= " -t $optTimeout"	    if ($optTimeout);
	#$params .= " -v $main::verbose"	    if ($main::verbose >= 20);
	$params .= " -u '$optUserName'"	    if ($optUserName);
	$params .= " -p '$optPassword'"	    if ($optPassword);
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
	$rc = 1 if (!defined $rc and $result =~ m/authentication/i); 
	$rc = 2 if (!defined $rc and $result =~ m/couldn\'t connect to/); # curl
	$rc = 3 if (!defined $rc and $result =~ m/Timeout/i); # both
	$rc = 4 if (!defined $rc);
	    
	#print "[[[ => $rc ]]]\n";

	if (defined $rc and $rc == 0) {
	    my $typeInfo = undef;
	    
	    $typeInfo = $1 if (!defined $typeInfo and $result =~ m/AgentInfo \- Name=\"([^\"]*)\"/);
	    if ($typeInfo) {
		$isiRMC = 1 if ($typeInfo =~ m/iRMC/i);
	    }
	    #
	    if ($result =~ m/REST-Service=\"(.*)\"/) {
		my $name = $1;
		$optServiceMode = "A" if ($name and $name =~ m/Server Control/);
		$optServiceMode = "R" if ($name and $name =~ m/iRMC Report/);
		$optServiceMode = "ei" if ($name and $name =~ m/iRMC REST Service/);
		#$optServiceMode = "iredwait" if ($name and $name =~ m/iRMC Redfish Service.*Uninitialized.*/);
		#$optServiceMode = "ired" if ($name and $name =~ m/iRMC Redfish Service/);
	    }
	}
	if ($main::processPrint and defined $rc) {
		print "... RESPONSE: $result\n" if ($rc==4); # unusual returns
		#print "<<< ";
		#print "OK" if (!$rc);
		#print "AUTHENTICATION ERROR" if ($rc==1);
		#print "CONNECTION ERROR" if ($rc==2);
		#print "TIMEOUT" if ($rc==3);
		#print "UNKNOWN" if ($rc==4);
		#print "\n"
	}
	return $rc;
  } # oneConnectionTest
  sub connectionTest {
	my $cmdParams = shift;

	my $cmd = "$checkScript $cmdParams --chkidentify";
	
	my $found = 0;
	my $cAuthErr = 0;
	my $cConnErr = 0;
	my $cTimeErr = 0;
	my $cUnkErr = 0;
	my $port = undef;
	my $prot = undef;
	my $trans = undef;
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;
	if ($usableCheck) {
	    my $rc = undef;
	    print ">>> connect test REST\n" if ($main::processPrint);
	    $rc = oneConnectionTest($cmd, $printCmd);
	    $found = 1 if (defined $rc and !$rc);
	    $cAuthErr = 1 if ($rc and $rc == 1);
	    $cConnErr = 1 if ($rc and $rc == 2);
	    $cTimeErr = 1 if ($rc and $rc == 3);
	    $cUnkErr = 1 if ($rc and $rc == 4);
	    if ($found) { # authentication must be checked with a call to get data => --agent
		$cmd = "$checkScript $cmdParams --agent";
		$printCmd = $cmd;
		$printCmd =~ s/ \'[^\']*\' / **** /g;
		$rc = oneConnectionTest($cmd, $printCmd);
		$found = 1 if (defined $rc and !$rc);
		$found = 0 if (!defined $rc or $rc);
		$cAuthErr = 1 if ($rc and $rc == 1);
	    }
	    if ($found) {
		$port = "<default>" if (!$optPort);
		$prot = "REST";
		$trans = "<default>" if (!$optTransportType);
		$prot .= "-iRMC-Report" if ($optServiceMode and $optServiceMode =~ m/R/i);
		$prot .= "-Server-Control" if ($optServiceMode and $optServiceMode =~ m/A/i);
		$prot .= "-iRMC-eLCM-Prototype" if ($optServiceMode and $optServiceMode =~ m/^ei/i);
	    }
	    if ($main::processPrint and defined $rc) {
		    print "<<< ";
		    print "OK" if (!$rc);
		    print "AUTHENTICATION ERROR" if ($rc==1);
		    print "CONNECTION ERROR" if ($rc==2);
		    print "TIMEOUT" if ($rc==3);
		    print "UNKNOWN" if ($rc==4);
		    print "\n";
	    }
	} 

	# for printouts
	#$longMessage .= "    InAddress\t= $optHost\n";
	if ($found) {
		    $port = $optPort if (!$port);
		    $trans = $optTransportType if (!$trans);
		    $longMessage .= "    Protocol\t= $prot \n" if ($prot);
		    $longMessage .= "    Port\t= $port \n" if ($port);
		    $longMessage .= "    TransType\t= $trans \n" if ($trans);
		    $longMessage .= "    OptionFile\t= $optInputFile\n" if ($optInputFile);
		    $gCntCodes[0]++;
	} elsif ($cAuthErr) {
		    $msg .= " - AUTHENTICATION FAILED ";
		    $gCntCodes[2]++;
	} elsif ($cConnErr) {
		    $msg .= " - CONNECTION FAILED ";
		    $gCntCodes[1]++;
	} elsif ($cTimeErr) {
		    $msg .= " - TIMEOUT ";
		    $gCntCodes[3]++;
	} elsif ($cUnkErr) {
		    $msg .= " - MISCELLANEOUS - NO REST SERVICE";
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
		if ($optServiceMode) {
			$newParams .= " -S $optServiceMode";
		}
	}
	$exitCode = 0 if ($found);
	return $newParams;
  } #connectionTest
###############################################################################
  sub getComputerSystemInfo {
	my $cmdParams = shift;
	return if (!$usableCheck);
	my $cmd = '';

	my $useParams = $cmdParams . " --systeminfo";
	$cmd = "$checkScript $useParams";
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
	my $ssmAddress = undef;
	my $os = undef;
	my $fqdn = undef;
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
	if ($result =~ m/MonitorURL/) {
	    $result =~ m/MonitorURL=(\"[^\"]+\")/;
	    $admURL = $1 if ($1 and $1 ne $name);
	    $result =~ m/MonitorURL=([^\s]+)/ if (!$admURL);
	    $admURL = $1 if ($1 and !$admURL and (!$name or $1 ne $name));
	}
	if ($result =~ m/FQDN/) {
	    $fqdn = $1 if ($result =~ m/FQDN=([^\s]+)/);
	    $fqdn =~ s/\"//g if ($fqdn);
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
	if ($os) {
	    $isWINDOWS = 1  if ($os =~ m/Windows/i);
	    $isESXi = 1	    if ($os =~ m/ESXi/i);
	    $isLINUX = 1    if ($os =~ m/Linux/i);
	}
	if ($found) {
	    $longMessage .= "\n";
	    $longMessage .= "    Name\t= $name\n" if ($name);
	    $longMessage .= "    Name\t= N.A.\n" if (!$name);
	    $longMessage .= "    NodeType\t= Windows\n" if ($isWINDOWS);
	    $longMessage .= "    NodeType\t= Linux\n" if ($isLINUX);
	    $longMessage .= "    NodeType\t= ESXi\n" if ($isESXi);
	    $longMessage .= "    NodeType\t= iRMC\n" if ($isiRMC);
	    $longMessage .= "    Model\t= $model\n" if ($model);
	    $longMessage .= "    AdminURL\t= $admURL\n" if ($admURL);
	    $longMessage .= "    MonitorURL\t= $ssmAddress\n" if ($ssmAddress);
	    $longMessage .= "    Parent Address\t= $mmbAddress\n" if ($mmbAddress);
	    $longMessage .= "    FQDN\t= $fqdn\n" if ($fqdn and $optExtended);
	    $longMessage .= "    OS\t\t= $os\n" if ($os);
	    print "<<< OK\n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN - no SVS information available\n" if ($main::processPrint);
	}
	return $found;
  } #getComputerSystemInfo

  sub getUpdateStatus {
	my $cmdParams = shift;
	return if (!$usableCheck or $isiRMC);
	my $cmd = '';

	my $useParams = $cmdParams . " --chkupdate";
	$cmd = "$checkScript $useParams";
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;
  	print ">>> get server update status \n" if ($main::processPrint);
	print "... CMD: $printCmd\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	my $result = join ('', <$pHandle>);
	my $updStatus = undef;
	$updStatus = $1 if ($result =~ m/UpdateStatus\(([^\)]+)\)/);
	if (defined $updStatus) {
	    addMessage("l", "    UpdateAgent\t= Status($updStatus)\n");
	    print "<<< OK \n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN \n" if ($main::processPrint);
	}
  } #getUpdateStatus

  sub getAgentsVersion {
	my $cmdParams = shift;
	return if (!$usableCheck);
	my $cmd = '';

	print ">>> get agent version\n" if ($main::processPrint);
	my $useParams = $cmdParams . " --agentinfo";
	$cmd = "$checkScript $useParams";
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;
	print "... CMD: $printCmd\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	my $result = join ('', <$pHandle>);
	my $version = undef;
	my $caption = undef;
	my $connected = undef;
	$version = $1 if ($result =~ m/Version=([^\n]*)/);
	$version =~ s/\s*$// if ($version);
	$caption = $1 if ($result =~ m/Name=\"([^\"]*)\"/);
	$connected = $1 if ($result =~ m/ConnectedAgent=\"([^\"]*)\"/);
	if ($caption and $version and ($version =~ m/.*F$/ or $caption =~ m/iRMC/)) {
	    addMessage("l", "    Firmware\t= $caption\n") if ($caption);
	    addMessage("l", "    FWVersion\t= $version\n") if ($version);
	    addMessage("l", "    Agent\t= No Agent\n") if ($connected and $connected =~ m/no/i);
	    addMessage("l", "    Agent\t= Mgmt. Agent\n") if ($connected and $connected =~ m/management agent/i);
	    addMessage("l", "    Agent\t= Agentless Service\n") if ($connected and $connected =~ m/agentless/i);
	    print "<<< OK \n" if ($main::processPrint);
	} elsif ($caption and $version and $version) {
	    addMessage("l", "    Agent\t= $caption\n") if ($caption);
	    addMessage("l", "    AgentVersion= $version\n") if ($version);
	    print "<<< OK \n" if ($main::processPrint);
	} else {
	    print "<<< UNKNOWN agent version\n" if ($main::processPrint);
	}
  } #getAgentsVersion

  sub splitComponentList {
	my $list = shift;
	return () if (!$list);
	my @out = ();
	while ($list) {
	    my $name = undef;
	    my $status = undef;
	    $name = $1 if ($list =~ m/\s*([^\(]+)/);
	    last if (!$name);
	    $list =~ s/\s*[^\(]+//;
	    $status = $1 if ($list =~ m/\(([^\)]+)\)/);
	    last if (!$status);
	    $list =~ s/\([^\)]+\)//;
	    $list = undef if (!$list or $list =~ m/^\s*$/);
	    if ($name ne "Overall" and $status !~ m/unknown/i) {
		push (@out, $name);
	    }
	} #while
	return @out;
  } # splitComponentList
  sub getComponentList {
	my $cmdParams = shift;
	return if (!$usableCheck);
	my $cmd = '';

	my $useParams = $cmdParams . " -v1";
	$cmd = "$checkScript $useParams";
	my $printCmd = $cmd;
	$printCmd =~ s/ \'[^\']*\' / **** /g;
	print ">>> get component list\n" if ($main::processPrint);
	print "... CMD: $printCmd\n" if ($main::processPrint and $main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	my $result = join ('', <$pHandle>);
	$result =~ s/\n.*//mg if ($result);
	$result =~ s/^.*\- //m if ($result);
	@components = splitComponentList($result);
	if ($#components >= 0) {
	    $longMessage .= "    Components\t= @components \n" if ($#components >= 0);
	    print "<<< OK\n" if ($main::processPrint and $#components >= 0);
	} else {
	    print "<<< UNKNOWN\n" if ($main::processPrint and $#components < 0);
	}
  } #getComponentList

  sub getComputerInfos {
	my $svs = 0;
	my $cmdParams = shift;
	return if (!$usableCheck);
	$svs = getComputerSystemInfo($cmdParams);
	if ($svs) {
	    getAgentsVersion($cmdParams) if ($optExtended);
	    @components = ();
	    getComponentList($cmdParams);
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
  sub checkTools {
	my $fileName = undef; 
	$fileName = $main::scriptPath . $checkScript;
	if (! -x $fileName) {
	    $usableCheck = 0;
	} else {
	    $usableCheck = 1;
	    $checkScript = $main::scriptPath . $checkScript;
	}
  } #checkTools
###############################################################################
  sub processData {
	$exitCode = 3;
        checkTools(); # set $usable* variables
	if (!$usableCheck) {
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find scripts for the REST access\n");
	    return;
	} 
	if ($optTypeTest or $optConnectionTest) {
		typeTest();
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


