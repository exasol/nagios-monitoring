#!/usr/bin/perl

##  Copyright (C) Fujitsu Technology Solutions 2014, 2015, 2016
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.01
# Date:		2016-08-04


use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Net::SNMP;
#use Time::Local 'timelocal';
use Time::localtime 'ctime';
use utf8;

# USED other scripts
our $snmpScript = "tool_fujitsu_server.pl";
our $cimScript = "tool_fujitsu_server_CIM.pl";
our     $wbemcliScript = "check_fujitsu_server_CIM.pl";
our         $wsmanPerlBindingScript = "fujitsu_server_wsman.pl";
our $restScript = "tool_fujitsu_server_REST.pl";


=head1 NAME

discover_fujitsu_server.pl - Discovery and Generation of Configurations

=head1 SYNOPSIS

discover_fujitsu_server.pl 
  { -H|--host=<host> 
    [-U|--use=<mode> ]
    { [-I|--inputfile=<filename> [--inputdir=<inputfiledir>]]
      | --ic|--inputcollection=<dir>
    }
    { [--onehost] | --ipv4-discovery | 
      --hc|--hostcollection=<file> |
    }
    { [--config] | --txt }
    [-O|--outputdir=<dir>]
    [--ctimeout=<connection timeout in seconds>]
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } | [-h|--help] | [-V|--version] 

Discovery of hosts and generation of Nagios host configurations if wanted

Advanced Options:
    [ --snmp{first|last|no}public ]
    [ --csv=<csvfile> [--show] [--nobmc] |
      --xml=<xmlfile> [--show] [--nobmc]
    ]
    [--nozeroip] [--sortbyname]
  
=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

=item [-U|--use=<mode>]

Select SNMP with "S", select any CIM-XML/WS-MAN variant with "CW",
select only WS-MAN usage with "W", select only CIM-XML with "C",
select REST with "R"

=item [-I|--inputfile=<filename> [--inputdir=<inputfiledir>]] | --ic|--inputcollection=<dir>

The input option file will be used for the tool_***.pl calls. In the files should
be options for these tools - e.g. credentials, port and transport type restrictions.
The discovery script tries to analyse if the content is meant for SNMP or CIM calls.

recommended: use full qualified directory path

inputfiledir - directory path of the input option file

inputcollection - directory path in which a collection of multiple input option files

=item [--onehost] | --ipv4-discovery | --hc|--hostcollection=<file> | ...

onehost:
Test only one host address. This is default.

ipv4-discovery:
Test for 256 servers for a given n.n.n. IPv4 address.
Test for a limited range servers for a given n.n.n.<firstn>-<lastn> IPv4 address.

hostcollection:
Test a list of host addresses written into a file.

=item [--config] | --txt

Generate simple text output or generate text output and Nagios host definition configuration.
Default is --config.

=item [--outputdir=<dir>]

Specify output directory for resulting text and config files. Default is "svout".

=item [--ctimeout=<connection timeout in seconds>]

Timeout for the connection test to the CIM service. Default is 30 seconds.
All values higher than 30 will be ignored.
ATTENTION: This is used for the call of the CIM script !

=item -t|--timeout=<timeout in seconds>

Timeout for the call of the other scripts for SNMP or CIM checks.
ATTENTION: This is no timeout for this script !

=item -v|--verbose=<verbose mode level>

Enable verbose mode (levels: 10).
Print additional information about inside script calls.

=item -V|--version

Print version information and help text.

=item -h|--help

Print help text.

=item [ --snmp{first|last|no}public ]

Relevant for SNMPv1/2 discovery and handling of community settings.
Default is snmpfirstpublic.
Non "public" SNMP communities can be specified in input option files see next options.

snmpfirstpublic: Try community "public" before any other community settings

snmplastpublic: Try community "public" after any other community settings

snmpnopublic: Try only specified community settings

=item { --csv=<csvfile> | --xml=<xmlfile> [--show] [--nobmc] }

csv:
Test a list of host addresses which are the "NetAddress" and "BmcAddress" part of a 
ServerView OperationsManager server list CSV file (CSV Delimiter is ',')

xml:
Test a list of host addresses which are the "NetAddress" and "BmcAddress"  part of a 
ServerView OperationsManager server list XML file

show:
"show only mode" - Only show evaluations of found server information - there will be no discover process

nobmc:
Use "nobmc" to prevent "BmcAddress" discovery.

=item --nozeroip

Only for IPv4 addresses: Don't fill the last address part with zeros for output files and Nagios host name. 
This is a sorting relevant option.
    E.g. 172.17.48.87 results in  172.17.48.087* files and Nagios host name.
    With --nozeroip 172.17.48.87 results in  172.17.48.87* files and Nagios host name and
    *.87 is sorted after *.100 as an example.

=item --sortbyname

As Default the Nagios host name is build with <ip>_<systemname>_*. With this additional option
it will be <systemname>_<ip>_* .

=cut

# define states
#### TEXT LANGUAGE AWARENESS (Standard in Nagios-Plugin)
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# init main options
our $argvCnt = $#ARGV + 1;
our $optHost = '';
our $optPort = undef;
our $optUseMode = undef;
our $optServiceMode = undef;	# E ESXi, L Linux, W Windows
our $optTransportType = undef;

our $optTimeout = 0;
our $optShowVersion = undef;
our $optHelp = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::processPrint = 1;

# option input files
our $optInputFile	= undef;
our $optInputDir	= undef;
our $optInputCollection = undef;

# action options
our $optOneHost		= undef;
our $optIpv4Discovery	= undef;
our $optHostCollection	= undef;
our $optCSVCollection	= undef;
our $optXMLCollection	= undef;

# output options
our $optExtended	= undef;
our $optNoProcessPrint	= undef;
our $optTxtOut		= undef;
our $optConfigOut	= undef;
our $optOutdir		= undef;
our $optConnectTimeout	= undef;
our $optZeroIP		= 1;
our $optSortByName	= undef;

# process options
our $optProcessMode	= undef;
our $optSnmpPublic1st	= undef;
our $optSnmpPublicLast	= undef;
our $optSnmpPublicNone	= undef;
our $optShowOnly	= undef;
our $optUseBMC		= 1;
our $optAllowNoAuth	= 0;

# init output data
our $msg = '';
our $longMessage = '';
our $exitCode = 3;
our $variableVerboseMessage = '';
our $notifyMessage = '';

# init some multi used processing variables
$main::scriptPath = undef;
our @gCntCodes = ( 0,0,0,0 );
	####our @gCodesText = ( "ok", "no-snmp", "no-snmp-access", "unknown");
our $usableSNMP = undef;
our $usableCIM = undef;
our $usableREST = undef;
our $usableCHKCIM = undef;
our $usableWSMAN = undef;
our $refSnmpInputFiles = undef;	# reference on a hash table !
our $refCimInputFiles = undef;	# reference on a hash table !
our $refRestInputFiles = undef;	# reference on a hash table !
our $refInputFiles = undef;	# reference on a hash table !
our $refResults = undef;	# reference on a hash table !

# SVOM Serverlist information
our $checkAddInfo = undef;
our @csvnumbers = ();
our %hostDisplayName = ();
our %hostSNMPCommunity = ();

###############################################################################
# PRINT FUNCTIONS
  sub finalizeMessageContainer {
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
  } #finalizeMessageContainer

  sub finalize {
	my $exitCode = shift;
	my $string = "@_";
	print "$string" if ($string);
	print "\n";
	#alarm(0); # stop timeout
	exit($exitCode);
  }

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
		       	"t|timeout=i",	
		       	"v|verbose=i",	
		       	"V|version",	
		       	"h|help",

			"H|host=s",	
		        "U|use=s",	       	
			
		       	"onehost",
			"ipv4-discovery",
			"hc|hostcollection=s", 
			"csv=s",
			"xml=s",
			
			"e|extended",
			"ctimeout=i",	
			"txt",
			"config",
			"O|outputdir=s",
			"show",
			"bmc",
			"nobmc",
			"nozeroip",
			"sortbyname",
			
	   		"I|inputfile=s", 
			"inputdir=s",
			"ic|inputcollection=s",

			"snmpfirstpublic",
			"snmplastpublic",
			"snmpnopublic",
			"auth!",
		) or pod2usage({
			-msg     => "\n" . 'Invalid argument!' . "\n",
			-verbose => 1,
			-exitval => 3
		});
	}
    	return ( %options );
  } #getScriptOpts
  
  sub readOptions {

	my %mainOptions;	# command line optiond

	#
	# command line options first
	#
	%mainOptions = getScriptOpts();

	#
	if ($main::verbose >= 60) {
	    print "\n+++mainOptions at the end\n" if ($main::verbose >= 60);
	    foreach my $key_m (sort keys %mainOptions) {
		    print " $key_m = $mainOptions{$key_m}\n" if ($main::verbose >= 60);
	    }
	    print "+++\n" if ($main::verbose >= 60);
	}

	return ( %mainOptions);
  } #readOptions

  sub setOptions { # script specific
	my $refOptions = shift;
	return if (!$refOptions);
	my %options =%$refOptions;
	
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $key = undef;
	$key="V";	$optShowVersion		= $options{$key} if ($options{$key});
	$key="h";	$optHelp		= $options{$key} if ($options{$key});
	$key="t";	$optTimeout		= $options{$key} if ($options{$key});
	$key="v";	$main::verbose		= $options{$key} if ($options{$key});

	$key="H";	$optHost		= $options{$key} if ($options{$key});
	$key="U";	$optUseMode 		= $options{$key} if ($options{$key});

	$key="onehost"; $optOneHost		= $options{$key} if ($options{$key});
	$key="ipv4-discovery";$optIpv4Discovery	= $options{$key} if ($options{$key});
	$key="hc";	$optHostCollection	= $options{$key} if ($options{$key});
	$key="csv";	$optCSVCollection	= $options{$key} if ($options{$key});
	$key="xml";	$optXMLCollection	= $options{$key} if ($options{$key});

	$key="e|extended";$optExtended		= $options{$key} if ($options{$key});
	$key="ctimeout";$optConnectTimeout	= $options{$key} if ($options{$key});
	$key="txt";	$optTxtOut		= $options{$key} if ($options{$key});
	$key="config";  $optConfigOut		= $options{$key} if ($options{$key});
	$key="O";	$optOutdir		= $options{$key} if ($options{$key});
	$key="M";	$optProcessMode		= $options{$key} if ($options{$key});
	$key="show";	$optShowOnly		= $options{$key} if ($options{$key});
	$key="nozeroip";	$optZeroIP	= 0		 if ($options{$key});
	$key="sortbyname";	$optSortByName	= $options{$key} if ($options{$key});

	$key="I";	$optInputFile		= $options{$key} if ($options{$key});
	$key="inputdir";$optInputDir	 	= $options{$key} if ($options{$key});
	$key="ic";	$optInputCollection	= $options{$key} if ($options{$key});

	$key="snmpfirstpublic";	$optSnmpPublic1st	= $options{$key} if ($options{$key});
	$key="snmplastpublic";	$optSnmpPublicLast	= $options{$key} if ($options{$key});
	$key="snmpnopublic";	$optSnmpPublicNone	= $options{$key} if ($options{$key});

	# sequence sensible
  	$key="bmc";	$optUseBMC		= 1 if ($options{$key});
	$key="nobmc";	$optUseBMC		= 0 if ($options{$key});
	if (defined $options{"auth"}) {
	    my $value = $options{"auth"};
	    $optAllowNoAuth = 0 if ($value);
	    $optAllowNoAuth = 1 if (!$value);
	}
  } #setOptions

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

	# option checks
	pod2usage(
		-msg		=> "\n" . 'Missing host address !' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	) if (!$optHost and !$optHostCollection and !$optCSVCollection and !$optXMLCollection);

	# wrong combinations
	$wrongCombination = "--onehost --ipv4-discovery" 
	    if ($optOneHost and $optIpv4Discovery);
	$wrongCombination = "--onehost --hostcollection" 
	    if (!$wrongCombination and $optOneHost and $optHostCollection);
	$wrongCombination = "--onehost --csv" 
	    if (!$wrongCombination and $optOneHost and $optCSVCollection);
	$wrongCombination = "--onehost --xml" 
	    if (!$wrongCombination and $optOneHost and $optXMLCollection);
	$wrongCombination = "--host=s --hostcollection" 
	    if (!$wrongCombination and $optHost and $optHostCollection);
	$wrongCombination = "--host=s --csv" 
	    if (!$wrongCombination and $optHost and $optCSVCollection);
	$wrongCombination = "--host=s --xml" 
	    if (!$wrongCombination and $optHost and $optXMLCollection);
	$wrongCombination = "-I=s --inputcollection" 
	    if (!$wrongCombination and $optInputFile and $optInputCollection);
	pod2usage({
		-msg     => "\n" . "Invalid argument combination \"$wrongCombination\"!" . "\n",
		-verbose => 0,
		-exitval => 3
	}) if ($wrongCombination);
	
	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}

	# Defaults
	$optOutdir = "svout" if (!$optOutdir);
	$optOneHost = 999 if (!$optOneHost and !$optIpv4Discovery and !$optHostCollection 
	    and !$optCSVCollection and !$optXMLCollection);
	if (!defined $optTxtOut and !defined $optConfigOut) {
		$optTxtOut = 999;
		$optConfigOut = 999;
	}
	$optSnmpPublic1st = 999 
		if (!defined $optSnmpPublic1st and !defined $optSnmpPublicLast 
		and !defined $optSnmpPublicNone);
  } #evaluateOptions

  sub handleOptions {
	# read all options and return prioritized
	my %options = readOptions();

	#
	# assign to global variables
	setOptions(\%options);

	# evaluateOptions expects options set in global variables
  	evaluateOptions();
  } #handleOptions

###############################################################################
# MISC HELPERS
  sub ipv4Enhanced {
	my $address = shift;
	my $filledaddress = $address;
	return $address if (!$address or $address !~ m/^\d+\.\d+\.\d+\.\d+$/); # only IPv4
	return $address if (!$optZeroIP);

	if ($address =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
	    # %3d
	    $filledaddress = sprintf("%d.%d.%d.%03d", $1, $2, $3, $4);
	}
	return $filledaddress
  } #ipv4Enhanced
###############################################################################
# DIRECTORIES

  sub checkDirectory {
        my $dir = shift;
	my $modesDir = 0;
	$modesDir++ if ( -r $dir );
	$modesDir++ if ( -w $dir );
	$modesDir++ if ( -x $dir );
	$modesDir++ if ( -d $dir );
	if ($main::verbose >= 60 and $main::processPrint) {
	    print ">>> Check directory $dir [";
	    print "r" if ( -r $dir );
	    print "w" if ( -w $dir );
	    print "x" if ( -x $dir );
	    print "d" if ( -d $dir );
	    print "] <<<\n";
	}
	return $modesDir;
  } #checkDirectory

  sub listDirectory {
	my $dir = shift;
	my @sortArray = ();
	my @arr = ();

	opendir(my $dh, $dir);
    	while (my $file = readdir $dh) {
		next if ($file and ($file eq "." or $file eq ".."));
		next if ( -d "$dir/$file" );
        	print "<> $dir/$file\n" if ($main::verbose >= 60);
		my $filenm = "$dir/$file";
		push (@arr, $filenm );
    	}
    	closedir $dh if ($dh);
	@sortArray = sort @arr if ($#arr >= 0);
      return @sortArray;
  } #listDirectory

  sub handleOutputDirectory {
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
# INFRASTRUCTURE
  sub checkTools {
	my $fileName = undef; 

	$fileName = $main::scriptPath . $snmpScript;
	if (! -x $fileName) {
	    $usableSNMP = 0;
	} else {
	    $usableSNMP = 1;
	    $snmpScript = $main::scriptPath . $snmpScript;
	}

	$fileName = $main::scriptPath . $cimScript;
	if (! -x $fileName) {
	    $usableCIM = 0;
	} else {
	    $usableCIM = 1;
	    $cimScript = $main::scriptPath . $cimScript;
	}

	$fileName = $main::scriptPath . $restScript;
	if (! -x $fileName) {
	    $usableREST = 0;
	} else {
	    $usableREST = 1;
	    $restScript = $main::scriptPath . $restScript;
	}

	$fileName = $main::scriptPath . $wbemcliScript;
	if (! -x $fileName) {
	    $usableCHKCIM = 0;
	} else {
	    $usableCHKCIM = 1;
	}
	
	$fileName = $main::scriptPath . $wsmanPerlBindingScript;
	if (! -x $fileName) {
		$usableWSMAN = 0;
	} else {
		$usableWSMAN = 1;
	}

	# evaluate
	if (!$usableCIM and !$usableSNMP and !$usableREST) {
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the SNMP or CIM or REST access\n");
	    return;
	}
	if ($optUseMode and $optUseMode =~ m/^S/ and !$usableSNMP) {
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the SNMP access\n");
	    return;
	}
	if ($optUseMode and $optUseMode =~ m/^R/ and !$usableREST) {
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the REST access\n");
	    return;
	}
	if ($optUseMode and $optUseMode =~ m/^CW/ and (!$usableCIM or !$usableCHKCIM)) 
	{
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the CIM access\n");
	    return;
	}
	if ($optUseMode and $optUseMode =~ m/^W/ 
		and (!$usableCIM or !$usableCHKCIM or !$usableWSMAN)) 
	{
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the WS-MAN access\n");
	    return;
	}
	if ($optUseMode and $optUseMode =~ m/^C/ 
		and (!$usableCIM or !$usableCHKCIM)) 
	{
	    $exitCode = 2;
	    addMessage("m", "ERROR - Unable to find tools for the CIM-XML access\n");
	    return;
	}
  } #checkTools

###############################################################################
# COLLECTION HELPER
  sub splitCSV {
	my $line = shift;
	my @parts = ();
	return @parts if (!$line);
	# TODO ? variable CSV delimiter and variable quoting
	while ($line) {
	    if ($line =~ m/^\"/) { # strings
		$line =~ m/^\"([^\"]*)\"/;
		push @parts, $1 if (defined $1);
		$line =~ s/^\"[^\"]*\"//;
	    } elsif ($line =~ m/^\'/) { # strings
		$line =~ m/^\'([^\']*)\'/;
		push @parts, $1 if (defined $1);
		$line =~ s/^\'[^\']*\'//;
	    } else { #numeric or empty ... TODO: be aware of delimiter
		$line =~ m/^([^,]*)/;
		push @parts, $1;
		$line =~ s/^[^,]*//;
	    }
	    $line =~ s/,// if ($line);
	} # while
	return @parts;
  } #splitCSV

  sub svom_useDisplayName {
	my $netaddr = shift;
	my $systemname = shift;
	my $displayname = shift;
	my $useDisplayName = undef;

	$useDisplayName = $systemname if ($systemname 
	    and $systemname !~ m/localhost/ 
	    and $systemname !~ m/unknown/
	    and $systemname !~ m/[(]none[)]/
	    and $systemname !~ m/N\.A\./i);
	$useDisplayName = undef if ($netaddr and $useDisplayName and $useDisplayName eq $netaddr);
	$useDisplayName = $displayname if ($displayname 
	    and $displayname !~ m/localhost/ 
	    and $displayname !~ m/unknown/
	    and $displayname !~ m/[(]none[)]/
	    and $displayname !~ m/N\.A\./i
	    and (!$useDisplayName 
		or ($displayname ne $systemname)) ); 
	$useDisplayName = undef if ($netaddr and $useDisplayName and $useDisplayName eq $netaddr);
	return $useDisplayName;
  } #svom_useDisplayName

  sub svom_useServerType {
	my $stype = shift;
	return 0 if (!$stype);
	return 0 if (	$stype =~ m/.+Blade/ or $stype =~ m/BladeFrame/
	    or		$stype =~ m/Storage/ or $stype =~ m/Eternus/ 
	    or		$stype eq "NetAPP"   or	$stype eq "CFabric"
	    or		$stype eq "Switch"
	    or		$stype =~ m/^Bare/   or $stype =~ m/Citrix/ 
	    or		$stype =~ m/Centric/ or	$stype =~ m/PRIMEPOWER/
	    or		$stype eq "MultiNodeChassis"
	);
	return 1;
  } #svom_useServerType

  sub svom_checkIP { # check address exceptions
	my $address = shift;
	$address = undef if ($address and 
	    ($address eq "0000:0000:0000:0000:0000:0000:0000:0000" or 
	     $address eq "0.0.0.0" or 
	     $address eq "::" or 
	     $address eq ''
	    )
	);
	return $address;
  } #svom_checkIP

  sub svomCommunity {
	my $netaddr = shift;
	my $community = shift;
	return if (!$community or !$netaddr);
	return if ($netaddr eq "0.0.0.0");
	return if ($community eq "public");
      		
	my $filehost = hostnm4file($netaddr);
	my $fileauth = "$optOutdir/"  . $filehost . "_AUTH_SNMP.txt";
	print "... generate $fileauth\n" if ($main::processPrint);
	my $stream = "-C $community\n";
	writeTxtFile($filehost, "AUTH_SNMP", $stream);
	chmod 0600, $fileauth; # must be oct mode
	$hostSNMPCommunity{$netaddr} = $fileauth;
  } #svomCommunity

  sub svomCSVentries { # depend on csvnumbers of handleCSVFile
	my $line = shift;
	my @entries = ();
	return @entries if (!$line);
	# ATTENTION: There might be values with commatas inside
	my @parts = splitCSV($line);
	print "... ignore corrupt CSV line\n" if ($main::processPrint and $#parts < $csvnumbers[6]);
	return @entries if ($#parts < $csvnumbers[6]);
	#
	my $iSystemName = $csvnumbers[0];
	my $iType	= $csvnumbers[1];
	my $iNetAddress = $csvnumbers[2];
	my $iCommunity	= $csvnumbers[3];
	my $iDisplay	= $csvnumbers[4];
	my $iBmcAddress	= $csvnumbers[5];
	my $iMgmtService = $csvnumbers[6];

	push(@entries, $parts[$iSystemName]);
	push(@entries, $parts[$iType]);
	push(@entries, $parts[$iNetAddress]);
	push(@entries, $parts[$iCommunity]);
	push(@entries, $parts[$iDisplay]);
	push(@entries, $parts[$iBmcAddress]);
	push(@entries, $parts[$iMgmtService]);

	return @entries;
  } #svomCSVentries

  sub svomCSVentries3 { # depend on csvnumbers of handleCSVFile
	my $line = shift;
	my @entries = ();
	return @entries if (!$line);
	# ATTENTION: There might be values with commatas inside
	my @parts = splitCSV($line);
	print "... ignore corrupt CSV line\n" if ($main::processPrint and $#parts < $csvnumbers[2]);
	return @entries if ($#parts < $csvnumbers[2]);
	#
	my $iServerName = $csvnumbers[0];
	my $iNetAddress = $csvnumbers[1];
	my $iCommunity	= $csvnumbers[2];

	push(@entries, $parts[$iServerName]);
	push(@entries, $parts[$iNetAddress]);
	push(@entries, $parts[$iCommunity]);
	return @entries;
  } #svomCSVentries3

  sub svomXMLServerData {
		my $content = shift;
		my @serverdata = ();
		return @serverdata if (!$content or $content !~ m/MgmtService/);

		#### split as-simple-as-possible into serverdata
		$content =~ s/<\/MgmtService>/<\/MgmtService>\n/g;
		while ($content) {
				my $line = undef;
				$line = $1 if ($content =~ m/^([^\n]+)\n/);
				if ($line and $line =~ m/MgmtService/) {
					push (@serverdata, $line);
					$content =~ s/^[^\n]+\n//;
				} else {
					$content = undef;
				}
		} # while
		print "... XMLServerCount=$#serverdata\n" if ($main::processPrint);
		return @serverdata;
  } #svomXMLServerData

  sub svomSortUniqueHosts {
	my $refHostline = shift;
	my @hostline = @{$refHostline};
	my @outHostline = ();
	my $saveOneHost = undef;
	foreach my $oneLine (sort @hostline) {
	    next if (!$oneLine);
	    next if ($saveOneHost and $saveOneHost eq $oneLine);
	    push (@outHostline, $oneLine);
	    $saveOneHost = $oneLine;
	} # foreach
	return @outHostline;
  } #svomSortUniqueHosts

  sub svomShowOnly {
	my $use = shift;
	my $netaddr = shift;
	my $bmcaddress = shift;
	my $stype = shift;
	my $mgmt = shift;
	my $community = shift;
	my $systemname = shift;
	my $displayname = shift;
	my $nagiosname = shift;
	return if (!$optShowOnly and $main::verboseTable != 999);
	{
		$netaddr = '(N.A.)'	if (!defined $netaddr);
		$netaddr = '(N.A.)'	if (defined $netaddr and ($netaddr eq '' or $netaddr =~ m/^\s+$/));
		$stype = ''		if (!defined $stype and defined $mgmt);
		$mgmt = ''		if (!defined $mgmt and defined $stype);
		$systemname = ''	if (!defined $systemname and defined $displayname);
		$displayname = ''	if (!defined $displayname and defined $systemname);
		$community = ''		if (!defined $community);
		#print "{ $use - $netaddr, $stype, $mgmt, $bmcaddress, $systemname, $displayname, $nagiosname, $community }\n";
		print "try:" if ($use);
		print "ign:" if (!$use);
		print " Address=$netaddr";
		print     " BMC=$bmcaddress" if ($bmcaddress and $bmcaddress ne '');
		print     " Type=$stype Mgmt=$mgmt\n" if ($stype or $mgmt);
		print "     SystemName=\"$systemname\"\n     DisplayName=\"$displayname\"\n"
		    if ($systemname or $displayname);
		print "     SuggestedName=\"$nagiosname\"\n" if ($nagiosname and $nagiosname ne '');
		print "     SpecialSNMPCommunity=$community\n" if ($community ne "public");
	}
  } #svomShowOnly

###############################################################################
# COLLECTION FILES
  sub handleInputOptionFiles { # recursive call !
	my $chkFileName = shift;
	my $forSNMP = undef;		# check if file is for SNMP call 
	my $forCIM = undef;		# check if file is for CIM call 
	my $forREST = undef;		# check if file is for REST call 
	if (!$chkFileName and $optInputFile) {
		$chkFileName = "";
		$chkFileName .= $optInputDir . "/" if ($optInputDir 
		    and $optInputFile and $optInputFile !~ m/^\//);
		$chkFileName .= $optInputFile;
		$optInputFile = $chkFileName;
	}
	$exitCode = 3;
	if ($chkFileName) {
		print ">>> read input option file $chkFileName\n" if ($main::processPrint);
		my $content = readDataFile($chkFileName);
		if ($exitCode == 11) {
		    print "<<< ERROR - file not found or readable\n" 
			if ($main::processPrint);
		    addMessage("m", "- input file not found or readable");
		}
		elsif ($exitCode == 12) {
		    print "<<< ERROR - unable to open file\n" 
			if ($main::processPrint);
		    addMessage("m", "- unable to open input file");
		}
		elsif (!$content) {
		    print "<<< ERROR - empty file\n" 
			if ($main::processPrint);
		    addMessage("m", "- empty input file");
		    $exitCode = 10;
		}
		$exitCode = 2 if ($exitCode >= 10);
		return if ($exitCode == 2);
		
		$content =~ s/\n//mg;
		# TODO --- GetOptions Check !!!
		$forSNMP = 1 if ($content =~ m/\-\-authpass/);
		$forSNMP = 1 if ($content =~ m/\-\-privpass/);
		$forSNMP = 1 if ($content =~ m/\-\-snmp/);
		$forSNMP = 1 if ($content =~ m/\-C/);
		if (!$forSNMP) {
		    $forCIM = 1 if ($content =~ m/\-u/);
		    $forCIM = 1 if ($content =~ m/\-p/);
		    $forCIM = 1 if ($content =~ m/\-\-cert/);
		    $forCIM = 1 if ($content =~ m/\-\-cacert/);
		    $forREST = 1 if ($content =~ m/\-u/);
		    $forREST = 1 if ($content =~ m/\-p/);
		    $forREST = 1 if ($content =~ m/\-\-cert/);
		    $forREST = 1 if ($content =~ m/\-\-cacert/);
		    $forREST = 0 if ($content =~ m/\-U/ or $content =~ m/\-\-use/);
		    $forCIM = 0 if ($content =~ m/\-S[=\s]*[AR]/ or $content =~ m/\-\-service[=\s]*[AR]/);
		}

		$refSnmpInputFiles->{$chkFileName}  = "SNMP" if ($forSNMP);
		$refCimInputFiles->{$chkFileName}   = "CIM"  if ($forCIM);
		$refRestInputFiles->{$chkFileName}  = "REST"  if ($forREST);
		$refInputFiles->{$chkFileName} = "SNMP" if ($forSNMP);
		$refInputFiles->{$chkFileName} = "CIM"  if ($forCIM or $forREST);
		$refInputFiles->{$chkFileName} = "ANY"  if (!$forCIM and !$forSNMP);
		
		if ($main::processPrint) {
		    print "<<< OK - usable for SNMP calls\n" 
			if ($forSNMP);
		    print "<<< OK - usable for CIM and REST calls\n" 
			if ($forCIM and $forREST);
		    print "<<< OK - usable for CIM calls\n" 
			if ($forCIM and !$forREST);
		    print "<<< OK - usable for REST calls\n" 
			if (!$forCIM and $forREST);
		    print "<<< WARNING - unspecific content - file will be ignored\n" 
			if (!$forCIM and !$forSNMP and !$forREST);
		}
	} # input file
	elsif ($optInputCollection) {
	    my @arrInput = ();
	    my $modesDir = checkDirectory($optInputCollection);
	    if (!$modesDir or $modesDir < 4) {   
		addMessage("m", 
		    "ERROR - input collection directory $optInputCollection doesn't exist or has not enough access rights");
		$exitCode = 2;
		return;
	    } 
	    @arrInput = listDirectory($optInputCollection);
	    foreach my $infile (@arrInput) {
		handleInputOptionFiles($infile);
	    }
	    return;
	} # input collection
  } #handleInputOptionFiles

  sub handleHostCollectionFile {
	my $colFile = shift;
	my @hostline = ();
	print ">>> read host collection file $colFile\n" if ($main::processPrint);
	my $content = readDataFile($colFile);
	if ($exitCode == 11) {
	    print "<<< ERROR - file not found or readable\n" 
		if ($main::processPrint);
	    addMessage("m", "- host collection file not found or readable");
	}
	elsif ($exitCode == 12) {
	    print "<<< ERROR - unable to open file\n" 
		if ($main::processPrint);
	    addMessage("m", "- unable to open host collection file");
	}
	elsif (!$content) {
	    print "<<< ERROR - empty file\n" 
		if ($main::processPrint);
	    addMessage("m", "- empty host collection file");
	    $exitCode = 10;
	}
	$exitCode = 2 if ($exitCode >= 10);
	return @hostline if ($exitCode == 2);

	while ($content and $content =~ m/([^\n]+)\n/) {
	    push (@hostline, $1);
	    $content =~ s/[^\n]+\n//;
	}
	print "<<< OK\n" if ($main::processPrint);
	return @hostline;
  } #handleHostCollectionFile

  sub handleCSVFile {
	my $colFile = shift;
	my @hostline = ();
	my @sortedHostline = ();
	return  @hostline if (!$colFile);
	print ">>> read CSV server list file $colFile\n" if ($main::processPrint);
	my $content = readDataFile($colFile);
	$content =~ s/\r//mg;
	if ($exitCode == 11) {
	    print "<<< ERROR - file not found or readable\n" 
		if ($main::processPrint);
	    addMessage("m", "- CSV host collection file not found or readable");
	}
	elsif ($exitCode == 12) {
	    print "<<< ERROR - unable to open file\n" 
		if ($main::processPrint);
	    addMessage("m", "- unable to CSV open host collection file");
	}
	elsif (!$content) {
	    print "<<< ERROR - empty file\n" 
		if ($main::processPrint);
	    addMessage("m", "- empty CSV host collection file");
	    $exitCode = 10;
	}
	$exitCode = 2 if ($exitCode >= 10);
	return @hostline if ($exitCode == 2);

	# check first line for syntax
	my $knownFormat = 0;
	my $foundSVOM = 0;
	{ # Full SVOM csv
	    $content =~ m/([^\n]+)\n/;
	    my $headline = $1;
	    my @parts = splitCSV($headline);
	    
	    for (my $i=0;$i <= $#parts; $i++) { # sequence sensitive !
		push (@csvnumbers, $i) if ($parts[$i] eq "SystemName");
		push (@csvnumbers, $i) if ($parts[$i] eq "Type");
		push (@csvnumbers, $i) if ($parts[$i] eq "NetAddress");
		push (@csvnumbers, $i) if ($parts[$i] eq "Community");
		push (@csvnumbers, $i) if ($parts[$i] eq "ServerListDisplayName");
		push (@csvnumbers, $i) if ($parts[$i] eq "BmcAddress");
		push (@csvnumbers, $i) if ($parts[$i] eq "MgmtService");
	    }
	    if ($#csvnumbers >= 6) {
		$foundSVOM = 7;
		$checkAddInfo = 1;
	    }
	    if (!$foundSVOM) { # short CSV
		@csvnumbers = ();
		for (my $i=0;$i <= $#parts; $i++) { # sequence sensitive !
		    push (@csvnumbers, $i) if ($parts[$i] eq "ServerName");
		    push (@csvnumbers, $i) if ($parts[$i] eq "NetAddress");
		    push (@csvnumbers, $i) if ($parts[$i] eq "Community");
		}
		if ($#csvnumbers >= 2) {
		    $foundSVOM = 3;
		    $checkAddInfo = 1;
		}
	    } # not 7-part
	    $knownFormat = 1 if ($foundSVOM);
	    print "... CSV is SVOM server list\n" if ($main::processPrint and $knownFormat
		and $foundSVOM == 7);
	    print "... CSV is server-address-community list\n" if ($main::processPrint and $knownFormat
		and $foundSVOM == 3);
	    $content =~ s/[^\n]+\n//;
	} # Full SVOM csv
	# read lines
	while ($foundSVOM and $foundSVOM==7 and $content and $content =~ m/([^\n]+)\n/) {
	    my $line = $1;
	    my @entries = svomCSVentries($line);
	    $content =~ s/[^\n]+\n//;
	    next if ($#entries < 6);
	    
	    my $useDisplayName = undef;
	    my $systemname = $entries[0];
	    my $stype = $entries[1];
	    my $netaddr = $entries[2];
	    my $community = $entries[3];
	    my $displayname = $entries[4];
	    #my $mgmt = $entries[5];
	    my $bmcaddress = $entries[5];
	    my $mgmt = $entries[6];
	    $systemname = undef if (!$systemname or $systemname eq '');
	    $community = undef if (!$community or $community eq '');
	    $displayname = undef if (!$displayname or $displayname eq '');
	    $stype = undef if (!$stype or $stype eq '');
	    $bmcaddress	    = svom_checkIP($bmcaddress);
	    $netaddr	    = svom_checkIP($netaddr);
	    $useDisplayName = svom_useDisplayName($netaddr, $systemname, $displayname);
	    
	    my $use = 0;
	    $use = svom_useServerType($stype);
	    $hostDisplayName{$netaddr} = $useDisplayName if ($netaddr and $useDisplayName and $use);
	    push (@hostline, $netaddr) if ($netaddr and $use);
	    $use = 0 if ($use and !$netaddr and !$bmcaddress);
	    $use = 0 if ($use and !$netaddr and !$optUseBMC);

	    push (@hostline, $bmcaddress) if ($bmcaddress and $use and $optUseBMC and 
		(!defined $netaddr or $bmcaddress ne $netaddr));
	    
	    svomShowOnly($use, $netaddr, $bmcaddress, $stype, $mgmt, $community,
		$systemname, $displayname, $useDisplayName);
	    svomCommunity($netaddr, $community) if ($use);
	} # while svom CSV
	while ($foundSVOM and $foundSVOM==3 and $content and $content =~ m/([^\n]+)\n/) {
	    my $line = $1;
	    my @entries = svomCSVentries3($line);
	    $content =~ s/[^\n]+\n//;
	    next if ($#entries < 2);

	    my $useDisplayName = undef;
	    my $serverName = $entries[0];
	    my $netaddr = $entries[1];
	    my $community = $entries[2];
	    $serverName = undef if (!$serverName or $serverName eq '');
	    $netaddr	    = svom_checkIP($netaddr);
	    $useDisplayName = svom_useDisplayName($netaddr, $netaddr, $serverName);

	    $hostDisplayName{$netaddr} = $useDisplayName if ($netaddr and $useDisplayName);
	    push (@hostline, $netaddr) if ($netaddr);
	    svomShowOnly(1, $netaddr, undef, undef, undef, $community,
		undef, undef, $useDisplayName);
	    svomCommunity($netaddr, $community);
	} # while svom 3-part CSV
	####
	@sortedHostline = svomSortUniqueHosts( \@hostline );
	####
	if (!$knownFormat) {
	    print "<<< ERROR - unknown format in CSV file\n" 
		if ($main::processPrint);
	    addMessage("m", "- unknown format in CSV file");
	    $exitCode = 2;
	} else {
	    print "<<< OK COUNT=$#sortedHostline\n" if ($main::processPrint and $knownFormat);
	    $msg .= '';
	}
	####
	return @sortedHostline;
  } #handleCSVFile

  sub handleXMLFile {
	my $colFile = shift;
	my @hostline = ();
	my @sortedHostline = ();
	return  @hostline if (!$colFile);
	print ">>> read XML server list file $colFile\n" if ($main::processPrint);
	my $content = readDataFile($colFile);
	$content =~ s/\r//mg if ($content);
	if ($exitCode == 11) {
	    print "<<< ERROR - file not found or readable\n" 
		if ($main::processPrint);
	    addMessage("m", "- XML host collection file not found or readable");
	}
	elsif ($exitCode == 12) {
	    print "<<< ERROR - unable to open file\n" 
		if ($main::processPrint);
	    addMessage("m", "- unable to open XML host collection file");
	}
	elsif (!$content) {
	    print "<<< ERROR - empty file\n" 
		if ($main::processPrint);
	    addMessage("m", "- empty XML host collection file");
	    $exitCode = 10;
	}
	$exitCode = 2 if ($exitCode >= 10);
	return @hostline if ($exitCode == 2);
	my $knownFormat = 0;
	my $foundSVOM = 0;
	my $foundSVOMDataBase = 0;

	#### There are two formats: One is the ServerGroupData export the other is the export of the 
	#    SERVER_LIST database table
	$foundSVOM = 1 
	    if ($content =~ m/ServerGroupData .*xmlns\=\"urn:SVOperationsManager[\/\d]+Server\"/m);
	$foundSVOMDataBase = 1 
	    if (!$foundSVOM and $content =~ m/<[^\s]*ExportedTables>.*<[^\s]*Table [^>]*name=\"SERVER_LIST\"[^>]*>/m);
	#### SVOM ServerGroupData Export
	if ($foundSVOM) {
	    print "... discovered SVOM ServerGroupData format\n" 
		if ($main::processPrint);
	    $checkAddInfo = 1;
	    $content =~ s/[^\n]+\n// if ($content =~ m/\<\?xml/);
	    $content =~ s/^\s*<ServerGroupData[^>]+>// if ($content =~ m/ServerGroupData xmlns/);
	    $content =~ s/^\s*//mg;
	    #printf ("%.200s...\n", $content);
	    $content =~ s/<[^>]ServerGroupData>\s*$//m;
	    $content =~ s/\n//mg;
	    $content =~ s/<GroupCollection>.*$//mg;
	}
	#### SVOM Database SERVER_LIST Export
	if ($foundSVOMDataBase) {
	    print "... discovered SVOM SERVER_LIST database format\n" 
		if ($main::processPrint);
	    $checkAddInfo = 1;
	    $content =~ s/[^\n]+\n// if ($content =~ m/\<\?xml/);
	    $content =~ s/\n//mg;
	}
	#### split end evaluate
	if ($foundSVOM or $foundSVOMDataBase) {
	    my @serverdata = svomXMLServerData($content);
	    for (my $i=0; $i <=$#serverdata; $i++) {
		my $oneset = $serverdata[$i];
		my $srvnm = undef;	my $sysnm = undef;	my $displaynm = undef;
		my $netaddr = undef;	my $bmcaddress = undef;	my $community = undef;
		my $stype = undef;	my $mgmt = undef;
		my $useDisplayName = undef;
		$netaddr = $1	if ($oneset =~ m/<NetAddress>([^<]*)</);
		$stype = $1	if ($oneset =~ m/<Type>([^<]*)</);
		$mgmt = $1	if ($oneset =~ m/<MgmtService>([^<]*)</);
		$srvnm = $1	if ($oneset =~ m/<ServerName>([^<]*)</);
		$sysnm = $1	if ($oneset =~ m/<SystemName>([^<]*)</);
		$displaynm = $1	if ($oneset =~ m/<ServerListDisplayName>([^<]*)</);
		$bmcaddress = $1 if ($oneset =~ m/<BmcAddress>([^<]*)</);
		$community = $1	if ($oneset =~ m/<Community>([^<]*)</);

		$bmcaddress = svom_checkIP($bmcaddress);
		$netaddr = svom_checkIP($netaddr);

		$useDisplayName = svom_useDisplayName($netaddr, $sysnm, $displaynm);;

		my $use = 0;
		$use = svom_useServerType($stype);

		push (@hostline, $netaddr) if ($netaddr and $use);
		$hostDisplayName{$netaddr} = $useDisplayName if ($netaddr and $useDisplayName and $use);
		$use = 0 if ($use and !$netaddr and !$bmcaddress);

		$use = 0 if ($use and !$netaddr and !$optUseBMC);

		push (@hostline, $bmcaddress) if ($bmcaddress and $use and $optUseBMC and 
		    (!defined $netaddr or $bmcaddress ne $netaddr));

		svomShowOnly($use, $netaddr, $bmcaddress, $stype, $mgmt, $community,
		    $sysnm, $displaynm, $useDisplayName);
		svomCommunity($netaddr, $community) if ($use);
	    } #for
	} # SVOM database
	####
	@sortedHostline = svomSortUniqueHosts( \@hostline );
	#### 
	$knownFormat = 1 if ($foundSVOM or $foundSVOMDataBase);
	if (!$knownFormat) {
	    print "<<< ERROR - unknown format in XML file\n" 
		if ($main::processPrint);
	    addMessage("m", "- unknown format in XML file");
	    $exitCode = 2;
	} else {
	    print "<<< OK - Count=$#hostline\n" if ($main::processPrint and $knownFormat);
	    $msg .= '';
	}
	return @sortedHostline;
  } #handleXMLFile

###############################################################################
# SCRIPT PREPARATIONS
  sub buildScriptCmd {
	my $script = shift;
        my $host = shift;
	my $infile = shift;
	return undef if (!$host);

	my $params = $script;
	$params .= " -H $host";	
	$params .= " -t $optTimeout"	    if ($optTimeout);
	$params .= " -I $infile"	    if ($infile);
	$params .= " -v $main::verboseTable"	if ($main::verboseTable);
	$params .= " --typetest --nopp";
	
	return $params;
  } #buildScriptCmd

  sub callScript {
	my $cmd = shift;
	my $result = undef;
	print "CMD: $cmd\n" if ($main::verbose >= 10);
	open (my $pHandle, '-|', $cmd);
	$result = join ('', <$pHandle>) if ($pHandle);
	close $pHandle if ($pHandle);
	return $result;
  } #callScript

###############################################################################
# OUTPUT FILES
  sub hostnm4file {
	my $host = shift;
	return undef if (!$host);
	my $fileHost = $host;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	$fileHost = ipv4Enhanced($fileHost);
	return $fileHost;
  } #hostnm4file

  sub writeTxtFile {
	my $filehost = shift;
	my $type = shift;
	my $result = shift;

	my $txt = undef;
	my $txtFileName = $optOutdir . "/$filehost" . "_$type.txt";
	open ($txt, ">", $txtFileName);
	print $txt $result if ($result and $txt);
	close $txt if ($txt);
  } #writeTxtFile

  sub createNagiosAddressInfos {
	my $host = shift;
	my $name = shift;
	my $prot = shift;
	my $outstring = undef;

	my $specialhost = $host;
	$specialhost = ipv4Enhanced($host);
	if ($specialhost eq $name) {
	    $outstring .= "\thost_name\t$specialhost" . "_$prot\n";
	} elsif ($optSortByName) {
	    $outstring .= "\thost_name\t$name" . "_$specialhost" . "_$prot\n";
	} else {
	    $outstring .= "\thost_name\t$specialhost" . "_$name" . "_$prot\n";
	}
	my $displayname = $name;
	my $alternativeDisplay = undef;
	$alternativeDisplay = $hostDisplayName{$host} if ($checkAddInfo);
	$displayname = $alternativeDisplay if ($checkAddInfo and $alternativeDisplay);
	$displayname = undef if ($displayname and ($displayname eq "N.A." or $displayname =~ m/^N\/A$/i));
	$outstring .= "\tdisplay_name\t$displayname\n" if ($displayname);
	$outstring .= "\taddress\t\t$host\n";
	return $outstring
  } #createNagiosAddressInfos

  sub createSNMPconfig {
	my $host = shift;
	my $filehost = shift;
	my $type = shift;
	my $result = shift;

	# 
	my $name = undef;
	my $serverType = undef;
	my $components = undef;
	my $subBlades = undef;
	my $admURL = undef;
	my $ssmURL = undef;
	my $parent = undef;
	my $infile = undef;
	my $isServer		= undef;
	my $isiRMC		= undef;
	my $isBlade		= undef; # MMB
	my $isPrimequest	= undef; # MMB
	my $isRack		= undef; # MMB
	my $hasUpdateMonitor	= undef;
	my $isWindows		= undef;
	my $raid		= undef;

	# check server type
	if ($result =~ m/Type\s*= ([^\n]+)/) {
	    $serverType = $1;
	}
	$raid = 1 if ($result =~ m/RAID\s*= ([^\n]+)/); # ... Only RAID ?
	if (!$serverType) {
	    print "... no ServerView SNMP information\n" 
		if ($main::processPrint);
	    my $topic = "CONNECTION OK - NO SERVERVIEW";
	    if ($refResults and $refResults->{$topic}) {
		my $store = $refResults->{$topic};
		$refResults->{$topic} = "$store + $host|SNMP";
	    } else {
		$refResults->{$topic} = "$host|SNMP";
	    }
	    return;
	}
	print "... SNMP ServerView information OK\n";

	# server type ?
	{
	    $isPrimequest = 1 if ($serverType eq "Primequest");
	    $isBlade = 1 if (!$isPrimequest and $serverType eq "Primergy Blade");
	    $isRack = 1 if ($serverType =~ m/RackCDU/);
	    $isServer = 1 if (!$isPrimequest and !$isBlade and !$isRack);
	    $isiRMC = 1 if ($serverType =~ m/iRMC/);
	}

	# other values
	if ($result =~ m/Name\s*= ([^\n]+)/) {
	    $name = $1;
	}
	if ($isServer and $result =~ m/Components\s*= ([^\n]+)/) {
	    $components = $1;
	}
	if ($isBlade and $result =~ m/Sub-Blades\s*= ([^\n]+)/) {
	    $subBlades = $1;
	}
	if ($result =~ m/AdminURL\s*= ([^\n]+)/) {
	    $admURL = $1;
	}
	if ($result =~ m/MonitorURL\s*= ([^\n]+)/) {
	    $ssmURL = $1;
	}
	if ($result =~ m/OptionFile\s*= ([^\n]+)/) {
	    $infile = $1;
	}
	if ($isServer and $result =~ m/Parent Address\s*= ([^\n]+)/) {
	    $parent = $1;
	}
	if ($isServer) {
	    $hasUpdateMonitor = 1 if ($result =~ m/UpdateAgent\s*= [^\n]*available.*/);
	    #$hasUpdateMonitor = 0 if ($result =~ m/UpdateAgent\s*= [^\n]*UNKNOWN.*/);
	    $isWindows = 1 if ($result =~ m/OS\s*= Windows Server/);
	}
	$isWindows = 1 if (!$isServer);
	$isWindows = 0 if ($isRack);
	
	# name for output config file
	$name = "na" if (!$name);
	my $suffix = "SV";
	$suffix = "SViRMC" if ($serverType =~ m/iRMC/);
	$suffix = "SVRack" if ($isRack);
	if ($refResults and $refResults->{$name}) {
	    my $store = $refResults->{$name};
	    $refResults->{$name} = "$store + $host|SNMP|$suffix";
	} else {
	    $refResults->{$name} = "$host|SNMP|$suffix";
	}

	##############
	return if (!$optConfigOut);
	#... for tests: $name = 'I/N\A$R*I&I%I"I\'III';
	$name =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	my $cfg = undef;
	my $cfgFileName = $optOutdir . "/$filehost" . "_$type" . "_$name.cfg";
	
	# write config
	open ($cfg, ">", $cfgFileName);
	    print $cfg "####parents\t$parent\n" if ($parent);
	    print $cfg "define host {\n";
	        my $addrinfo = createNagiosAddressInfos($host, $name, "SNMP");
		print $cfg $addrinfo;

		my $hostgroups = undef;
		$hostgroups = "primergy-servers"		if ($isServer and !$isiRMC);
		$hostgroups = "primergy-servers-iRMC-SNMP"	if ($isServer and $isiRMC);
		$hostgroups .= ",primergy-update-monitor"	if ($isServer and $hasUpdateMonitor);
		$hostgroups = "primergy-blade-servers"		if ($isBlade);
		$hostgroups = "primequest-servers"		if ($isPrimequest);
		$hostgroups = "rackcdu_systems"			if ($isRack);
		print $cfg "\thostgroups\t$hostgroups\n";
		my $useTemplate = undef;
		$useTemplate = "windows-server" if ($isWindows);
		$useTemplate = "linux-server" if (!$isWindows);
		print $cfg "\tuse\t\t$useTemplate\n";
		print $cfg "\t_SV_OPTIONS\t-I $infile\n" if ($infile);
		print $cfg "\tnotes_url\t$ssmURL\n" if ($ssmURL);
		print $cfg "\tnotes_url\t$admURL\n" if ($admURL and !$ssmURL);
		print $cfg "\tregister\t1\n";
	    print $cfg "}\n";
	close $cfg if ($cfg);
  } #createSNMPconfig

  sub createCIMconfig {
	my $host = shift;
	my $filehost = shift;
	my $type = shift;
	my $result = shift;

	# 
	my $name = undef;
	my $prot = undef;
	my $port = undef;
	my $trans = undef;
	my $srvmode = undef;
	my $components = undef;
	my $admURL = undef;
	my $ssmURL = undef;
	my $parent = undef;
	my $infile = undef;
	my $hasUpdateMonitor	= undef;
	my $isWindows		= undef;
	my $hasModel = 0;

	# check components 
	if ($result =~ m/Components\s*= ([^\n]+)/) {
	    $components = $1;
	}
	if ($result =~ m/ServiceType\s*= ([^\n]+)/) {
	    $srvmode = $1;
	}
	#ATTENTION: iRMC Agentless/Agentless has no component list
	if ($srvmode and $srvmode =~ m/iRMC/ and $result =~ m/Model\s*= /) { 
	    $hasModel = 1;
	}
	if (!$components and !$hasModel) {
	    print "... no ServerView CIM Agent information (checked with summary status values)\n" 
		if ($main::processPrint);
	    my $topic = "CONNECTION OK - NO SERVERVIEW";
	    if ($refResults and $refResults->{$topic}) {
		my $store = $refResults->{$topic};
		$refResults->{$topic} = "$store + $host|CIM";
	    } else {
		$refResults->{$topic} = "$host|CIM";
	    }
	    return;
	}
	print "... CIM ServerView information OK\n";
	
	# get other values
	if ($result =~ m/Name\s*= ([^\n]+)/) {
	    $name = $1;
	}
	if ($result =~ m/Protocol\s*= ([^\n]+)/) {
	    $prot = $1;
	    $prot = undef if ($prot and $prot =~ m/CIM\-XML/);
	}
	if ($result =~ m/Port\s*= ([^\n]+)/) {
	    $port = $1;
	    $port = undef if ($port and $port =~ m/default/);
	}
	if ($result =~ m/TransType\s*= ([^\n]+)/) {
	    $trans = $1;
	    $trans = undef if ($trans and $trans =~ m/default/);
	}
	if ($result =~ m/AdminURL\s*= ([^\n]+)/) {
	    $admURL = $1;
	}
	if ($result =~ m/MonitorURL\s*= ([^\n]+)/) {
	    $ssmURL = $1;
	}
	if ($result =~ m/OptionFile\s*= ([^\n]+)/) {
	    $infile = $1;
	}
	if ($result =~ m/Parent Address\s*= ([^\n]+)/) {
	    $parent = $1;
	}
	{
	    $hasUpdateMonitor = 1 if ($result =~ m/UpdateAgent\s*= [^\n]*available.*/);
	    #$hasUpdateMonitor = 0 if ($result =~ m/UpdateAgent\s*= [^\n]*UNKNOWN.*/);
	    $isWindows = 1 if ($result =~ m/OS\s*= Windows Server/);
	}

	# name for output config file
	$name = "na" if (!$name);
	my $suffix = "SV";
	$suffix .= "iRMC" if ($srvmode =~ /iRMC/);
	if ($refResults and $refResults->{$name}) {
	    my $store = $refResults->{$name};
	    $refResults->{$name} = "$store + $host|CIM|$suffix";
	} else {
	    $refResults->{$name} = "$host|CIM|$suffix";
	}	
	
	###########################
	return if (!$optConfigOut);
	#... for tests: $name = 'I/N\A$R*I&I%I"I\'III';
	$name =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	my $cfg = undef;
	my $cfgFileName = $optOutdir . "/$filehost" . "_$type" . "_$name.cfg";

	# write config
	open ($cfg, ">", $cfgFileName);
	    print $cfg "####parents\t$parent\n" if ($parent);
	    print $cfg "define host {\n";
	        my $addrinfo = createNagiosAddressInfos($host, $name, "CIM");
		print $cfg $addrinfo;
		my $hostgroups = undef;
		$hostgroups = "primergy-servers-CIM";
		print $cfg "\thostgroups\t$hostgroups\n";
		my $useTemplate = undef;
		$useTemplate = "windows-server" if ($isWindows);
		$useTemplate = "linux-server" if (!$isWindows);
		print $cfg "\tuse\t\t$useTemplate\n";
		my $servicetype = undef;
		if ($srvmode) {
		    $servicetype = "I" if ($srvmode =~ m/iRMC/);
		    $servicetype = "E" if ($srvmode =~ m/ESXi/);
		    $servicetype = "L" if ($srvmode =~ m/Linux/i);
		    $servicetype = "W" if ($srvmode =~ m/Windows/i);
		}
		my $inoptions = undef;
		$inoptions .= "-UW " if ($prot);
		$inoptions .= "-P$port " if ($port);
		$inoptions .= "-T$trans " if ($trans);
		$inoptions .= "-S$servicetype " if ($servicetype);
		$inoptions .= "-I $infile ";
		print $cfg "\t_SV_CIM_OPTIONS\t$inoptions\n" if ($inoptions);
		print $cfg "\tnotes_url\t$ssmURL\n" if ($ssmURL);
		print $cfg "\tnotes_url\t$admURL\n" if ($admURL and !$ssmURL);
		print $cfg "\tregister\t1\n";
	    print $cfg "}\n";
	close $cfg if ($cfg);
  } #createCIMconfig

  sub createRESTconfig {
	my $host = shift;
	my $filehost = shift;
	my $type = shift;
	my $result = shift;

	# 
	my $name = undef;
	my $prot = undef;
	my $port = undef;
	my $trans = undef;
	my $srvmode = undef;
	my $components = undef;
	my $admURL = undef;
	my $ssmURL = undef;
	my $parent = undef;
	my $infile = undef;
	my $hasUpdateMonitor	= undef;
	my $isWindows		= undef;
	my $hasModel = 0;
	# check components 
	if ($result =~ m/Components\s*= ([^\n]+)/) {
	    $components = $1;
	}
	if ($result =~ m/Model\s*= /) {
	    $hasModel = 1; # each REST service should be able to support this information
	}
	if (!$components and !$hasModel) {
	    print "... no ServerView REST information (checked with component and model data)\n" 
		if ($main::processPrint);
	    my $topic = "CONNECTION OK - NO SERVERVIEW";
	    if ($refResults and $refResults->{$topic}) {
		my $store = $refResults->{$topic};
		$refResults->{$topic} = "$store + $host|REST";
	    } else {
		$refResults->{$topic} = "$host|REST";
	    }
	    return;
	}
	print "... REST ServerView information OK\n";
	# get other values
	if ($result =~ m/Name\s*= ([^\n]+)/) {
	    $name = $1;
	}
	if ($result =~ m/Protocol\s*= ([^\n]+)/) {
	    $prot = $1;
	    $prot = "Agent" if ($prot and $prot =~ m/REST\-Server\-Control/);
	    $prot = "Report" if ($prot and $prot =~ m/iRMC\-Report/);
	}
	if ($result =~ m/Port\s*= ([^\n]+)/) {
	    $port = $1;
	    $port = undef if ($port and $port =~ m/default/);
	}
	if ($result =~ m/TransType\s*= ([^\n]+)/) {
	    $trans = $1;
	    $trans = undef if ($trans and $trans =~ m/default/);
	}
	if ($result =~ m/AdminURL\s*= ([^\n]+)/) {
	    $admURL = $1;
	}
	if ($result =~ m/MonitorURL\s*= ([^\n]+)/) {
	    $ssmURL = $1;
	}
	if ($result =~ m/OptionFile\s*= ([^\n]+)/) {
	    $infile = $1;
	}
	if ($result =~ m/Parent Address\s*= ([^\n]+)/) {
	    $parent = $1;
	}
	{
	    $hasUpdateMonitor = 1 if ($result =~ m/UpdateAgent\s*=/);
	    #$hasUpdateMonitor = 0 if ($result =~ m/UpdateAgent\s*= [^\n]*UNKNOWN.*/);
	    $isWindows = 1 if ($result =~ m/OS\s*= Windows Server/);
	}
	# name for output config file
	$name = "na" if (!$name);
	my $suffix = "SV";
	$suffix .= "iRMCReport" if ($prot =~ /Report/);
	if ($refResults and $refResults->{$name}) {
	    my $store = $refResults->{$name};
	    $refResults->{$name} = "$store + $host|REST|$suffix";
	} else {
	    $refResults->{$name} = "$host|REST|$suffix";
	}	
	###########################
	return if (!$optConfigOut);
	#... for tests: $name = 'I/N\A$R*I&I%I"I\'III';
	$name =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	my $cfg = undef;
	my $cfgFileName = $optOutdir . "/$filehost" . "_$type" . "_$name.cfg";

	# write config
	open ($cfg, ">", $cfgFileName);
	    print $cfg "####parents\t$parent\n" if ($parent);
	    print $cfg "define host {\n";
	        my $addrinfo = createNagiosAddressInfos($host, $name, "REST");
		print $cfg $addrinfo;
		my $hostgroups = undef;
		$hostgroups = "primergy-servers-REST";
		$hostgroups .= ",primergy-servers-REST-update-monitor"	if ($hasUpdateMonitor);
		$hostgroups = "primergy-servers-iRMCReport-REST" if ($prot =~ /Report/);
		print $cfg "\thostgroups\t$hostgroups\n";
		my $useTemplate = undef;
		$useTemplate = "windows-server" if ($isWindows);
		$useTemplate = "linux-server" if (!$isWindows);
		print $cfg "\tuse\t\t$useTemplate\n";
		my $servicetype = undef;
		if ($prot) {
		    $servicetype = "A" if ($prot =~ m/Agent/);
		    $servicetype = "R" if ($prot =~ m/Report/);
		}
		my $inoptions = undef;
		$inoptions .= "-P$port " if ($port);
		$inoptions .= "-T$trans " if ($trans);
		$inoptions .= "-S$servicetype " if ($servicetype);
		$inoptions .= "-I $infile " if ($infile);
		print $cfg "\t_SV_REST_OPTIONS\t$inoptions\n" if ($inoptions);
		print $cfg "\tnotes_url\t$ssmURL\n" if ($ssmURL);
		print $cfg "\tnotes_url\t$admURL\n" if ($admURL and !$ssmURL);
		print $cfg "\tregister\t1\n";
	    print $cfg "}\n";
	close $cfg if ($cfg);
  } # createRESTconfig
###############################################################################
# DATA PROCESSING
  sub oneHostInfileLoop { # calls oneHost
	my $host = shift;
	my $refOptInputFiles = shift;
	my $refCimOptInputFiles = shift;
	my $refRestOptInputFiles = shift;
	my $snmpExitCode = 3;
	my $cimExitCode = 3;
	my $restExitCode = 3;
	return if (!$refOptInputFiles);
	
	my %allInputFiles = %$refOptInputFiles;
	{
	    my $hasSnmpInfile = undef;
	    foreach my $cInfile (sort keys %allInputFiles) 
	    {
		next if (!$cInfile or !$allInputFiles{$cInfile});
		my $cForWhat = $allInputFiles{$cInfile};
		$hasSnmpInfile = 1 if ($cForWhat eq "SNMP");
		last if ($hasSnmpInfile);
	    }
	    $exitCode = 3;
	    # SNMP
	    if ($optSnmpPublic1st and (!$optUseMode or $optUseMode =~ m/^S/)) 
	    {
		print "... try Community public\n" if ($main::processPrint);
		oneHost($host, undef, 0, "SNMP"); # Test -C public
		$snmpExitCode = $exitCode  if ($exitCode != 3)
	    }
	    foreach my $cInfile (sort keys %allInputFiles) 
	    {
		$exitCode = 3;
		next if (!$cInfile or !$allInputFiles{$cInfile} 
		    or $allInputFiles{$cInfile} eq "ANY");
		next if (!$allInputFiles{$cInfile} eq "CIM");
		my $cForWhat = $allInputFiles{$cInfile};
		if ((!$optUseMode or $optUseMode =~ m/^S/) and $snmpExitCode == 3
		and ($hasSnmpInfile and $cForWhat eq "SNMP")) 
		{
		    print "... try $cInfile\n" if ($main::processPrint);
		    oneHost($host, $cInfile, 0, "SNMP");
		    $snmpExitCode = $exitCode if ($exitCode != 3);
		} 
	    } 
	    if ($optSnmpPublicLast and (!$optUseMode or $optUseMode =~ m/^S/)) 
	    {
		print "... try Community public\n" if ($main::processPrint);
		oneHost($host, undef, 0, "SNMP"); # Test -C public
		$snmpExitCode = $exitCode  if ($exitCode != 3)
	    }
	}
	%allInputFiles = %$refCimOptInputFiles;
	{
	    # CIM
	    foreach my $cInfile (sort keys %allInputFiles) 
	    {
		$exitCode = 3;
		next if (!$cInfile or !$allInputFiles{$cInfile} 
		    or $allInputFiles{$cInfile} eq "ANY");
		next if (!$cInfile or !$allInputFiles{$cInfile} 
		    or $allInputFiles{$cInfile} eq "SNMP");
		my $cForWhat = $allInputFiles{$cInfile};

		if ((!$optUseMode or $optUseMode =~ m/^C/ or $optUseMode =~ m/^W/) 
		and $cForWhat eq "CIM" and ($cimExitCode == 3 or $cimExitCode == 1)) 
		{
		    #$optUseMode = "CW" if (!$optUseMode);
		    print "... try CIM $cInfile \n";
		    oneHost($host, $cInfile, 0, "CIM");
		    $cimExitCode = $exitCode if ($exitCode != 3);
		    last if ($exitCode == 0 or $exitCode == 3);
		}
	    }
	    # result codes 
	    $exitCode = $snmpExitCode if ($snmpExitCode != 3);
	    $exitCode = $cimExitCode if 
		(defined $cimExitCode 
		and ($cimExitCode==0 or $cimExitCode==1) 
		and  $cimExitCode < $exitCode);
	} 
	%allInputFiles = %$refRestOptInputFiles;
	if (!$optUseMode or $optUseMode =~ m/^R/) 
	{ # REST
	    $exitCode  = 3;
	    if ($optAllowNoAuth) 
	    {
		print "... try REST no authentication (insular network)\n" if ($main::processPrint);
		oneHost($host, undef, 0, "REST"); # 
		$restExitCode = $exitCode  if ($exitCode != 3)
	    }
	    if ($exitCode == 1 or !$optAllowNoAuth) { # check other auth
		$exitCode = 3;
		foreach my $cInfile (sort keys %allInputFiles) 
		{
		    if ((!$optUseMode or $optUseMode =~ m/^R/)
		    and ($restExitCode == 3 or $restExitCode == 1)) 
		    {
			print "... try REST $cInfile \n";
			oneHost($host, $cInfile, 0, "REST");
			$restExitCode = $exitCode if ($exitCode != 3);
			last if ($exitCode == 0 or $exitCode == 3);
		    }
		} # foreach
	    }
	} # REST
  } #oneHostInfileLoop

  sub oneHost { # recursive call via oneHostInfileLoop !
	my $host = shift;
	my $infile = shift;
	my $start = shift;
	my $protocol = shift;
	my $pp = $main::processPrint;
	my %allInputFiles = ();
	my $forWhat = undef;
	my $allrc = 3;
	my $rc = 3;
	%allInputFiles = %$refInputFiles if ($refInputFiles);
	$forWhat = $allInputFiles{$infile} if ($refInputFiles and $infile and $allInputFiles{$infile});
	if (!$forWhat and $checkAddInfo and $infile) { # refInputFiles might be not set in case of checkAddInfo
	    my $auth = $hostSNMPCommunity{$host};
	    $forWhat = "SNMP" if ($auth and $infile eq $auth);
	}

	print ">>> $host\n" if ($main::processPrint and $start);
	my $communityInfile = undef;
	$communityInfile = $hostSNMPCommunity{$host} if ($checkAddInfo and !$infile and $start);
	if ($communityInfile) {
	    my $addRefInputFiles = undef;
	    $addRefInputFiles->{$communityInfile} = "SNMP";
	    oneHostInfileLoop($host, $addRefInputFiles); # recursive !
	}
	elsif (!$infile and $optInputCollection and $start) {
	    oneHostInfileLoop($host, $refInputFiles, $refCimInputFiles, $refRestInputFiles); # recursive !
	} else { # single input file
	    my $log = undef;
	    my $logFileName = undef;
	    my $fileHost = hostnm4file($host);	#$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	    $logFileName = $optOutdir . "/$fileHost.log";
	    open ($log, ">>", $logFileName);
		# TODO - here is no check if the host-log exists and is blocked

	    $pp = undef if (!$log);
	    
	    print $log "START DATE: \t" . ctime() . "\n" if ($pp);
	    print $log "ADDRESS:\t$host\n" if ($pp);
	    print $log "INFILE:\t\t$infile\n" if ($pp and $infile);
	    #### SNMP
	    if ((!$optUseMode or $optUseMode =~ m/^S/) and !$infile and $optSnmpPublicNone) 
	    {
		print $log ">>> SNMP\n" if ($pp);
		print $log "<<< UNKNOWN (disabled check of community public)\n" if ($pp);
	    }
	    elsif ((!$optUseMode or $optUseMode =~ m/^S/) 
	    and ((!$infile) or ($forWhat and $forWhat eq "SNMP"))) 
	    {
		
		print $log ">>> SNMP\n" if ($pp);
		my $snmpInfile = undef;
		$snmpInfile = $infile if ($infile and $forWhat and $forWhat eq "SNMP");
		my $cmd = buildScriptCmd($snmpScript, $host, $snmpInfile);
		$cmd .= " -e"; # to get parent address
		print $log "... call: $cmd \n" if ($pp);
		my $result = callScript($cmd);
		print $log $result if ($result and $pp);

		my $extract = 'unknown';
		$extract = $1 if ($result =~ m/^([^\s]+) /m);
		$rc = 0 if ($extract eq "OK");
		$allrc = 0 if ($extract eq "OK");
		if ($rc == 0) {
		    $exitCode = 0;
		    print "... SNMP connection OK \n";
		    writeTxtFile($fileHost, "SNMP", $result);
		    createSNMPconfig($host,$fileHost, "SNMP", $result);
		} # success
		elsif ($result =~ m/usmStatsUnknownUserNames/) {
		    $extract = "SNMPV3 AUTHENTICATION ERROR";
		    $exitCode = 1 if ($exitCode == 3); # do not overwrite potential SNMP-OK
		    print "... SNMPV3 AUTHENTICATION ERROR \n";
		    if ($refResults and $refResults->{"AUTHENTICATION ERROR"}) {
			my $store = $refResults->{"AUTHENTICATION ERROR"};
			$refResults->{"AUTHENTICATION ERROR"} = "$store + $host|SNMP"
			    if ($store !~ m/$host[|]SNMP/); # be careful with the regexp ! 
		    } else {
			$refResults->{"AUTHENTICATION ERROR"} = "$host|SNMP";
		    }
		}
		elsif ($result =~ m/TIMEOUT/i) {
		    $extract = "TIMEOUT";
		    if ($refResults and $refResults->{"TIMEOUT"}) {
			my $store = $refResults->{"TIMEOUT"};
			$refResults->{"TIMEOUT"} = "$store + $host|SNMP";
		    } else {
			$refResults->{"TIMEOUT"} = "$host|SNMP";
		    }
		}
		print $log "<<< $extract\n" if ($pp);
	    } # SNMP
	    #### CIM
	    $rc = 3;
	    if ((!$optUseMode or $optUseMode =~ m/^C/ or $optUseMode =~ m/^W/) 
		and $infile
		and $forWhat and $forWhat eq "CIM"
		and (!$protocol or $protocol eq "CIM")) 
	    {
		print $log ">>> CIM\n" if ($pp);
		my $cimInfile = undef;
		$cimInfile = $infile;
		my $cmd = buildScriptCmd($cimScript, $host, $cimInfile);
		$cmd .= " -e"; # ... read agents version
		$cmd .= " -U$optUseMode" if ($optUseMode 
		    and ($optUseMode eq "C" or $optUseMode =~ m/^W/));
		$cmd .= " --ctimeout $optConnectTimeout" if ($optConnectTimeout);
		print $log "... call: $cmd \n" if ($pp);
		my $result = callScript($cmd);
		print $log $result if ($result and $pp);

		my $extract = 'unknown';
		$extract = $1 if ($result =~ m/^([^\s]+) /);
		$rc = 0 if ($extract eq "OK");
		$rc = 1 if ($rc == 3 and $result =~ m/AUTHENTICATION/);
		$allrc = 0 if ($extract eq "OK");
		$allrc = 1 if ($allrc == 3 and $rc == 3 and $result =~ m/AUTHENTICATION/);
		if ($rc == 0) {
		    $exitCode = 0;
		    print "... CIM connection OK \n";
		    writeTxtFile($fileHost, "CIM", $result);
		    createCIMconfig($host,$fileHost, "CIM", $result);
		    # remove AUTH ERROR
		    $extract = "AUTHENTICATION ERROR";
		    if ($refResults and $refResults->{"AUTHENTICATION ERROR"}) {
			my $store = $refResults->{"AUTHENTICATION ERROR"};
			if ($store =~ m/$host[|]CIM/) { # be careful with the regexp ! 
			    $store =~ s/[+ ]*$host.CIM[\s]*//;
			    $refResults->{"AUTHENTICATION ERROR"} = $store;
			}
		    }
		} # success
		elsif ($rc == 1) {
		    $extract = "AUTHENTICATION ERROR";
		    $exitCode = 1 if ($exitCode == 3); # do not overwrite potential SNMP-OK
		    print "... CIM AUTHENTICATION ERROR \n";
		    if ($refResults and $refResults->{"AUTHENTICATION ERROR"}) {
			my $store = $refResults->{"AUTHENTICATION ERROR"};
			$refResults->{"AUTHENTICATION ERROR"} = "$store + $host|CIM"
			    if ($store !~ m/$host[|]CIM/); # be careful with the regexp ! 
		    } else {
			$refResults->{"AUTHENTICATION ERROR"} = "$host|CIM";
		    }
		}
		elsif ($result =~ m/TIMEOUT/i) {
		    $extract = "TIMEOUT";
		    if ($refResults and $refResults->{"TIMEOUT"}) {
			my $store = $refResults->{"TIMEOUT"};
			$refResults->{"TIMEOUT"} = "$store + $host|CIM";
		    } else {
			$refResults->{"TIMEOUT"} = "$host|CIM";
		    }
		}
		print $log "<<< $extract\n" if ($pp);
	    }
	    #### REST
	    $rc = 3;
	    if ((!$optUseMode or $optUseMode =~ m/^R/) 
		and ( $infile and $forWhat and ($forWhat eq "CIM" or $forWhat eq "REST")
			or ($optAllowNoAuth and !$infile))
		#and ( ($infile or $optAllowNoAuth) 
		#    or ($forWhat 
		#	and ($forWhat eq "CIM" or $forWhat eq "REST")))
		and (!$protocol or $protocol eq "REST")) 
	    {
		print $log ">>> REST\n" if ($pp);
		my $restInfile = undef;
		$restInfile = $infile;
		my $cmd = buildScriptCmd($restScript, $host, $restInfile);
		$cmd .= " -e"; # ... read agents version
		$cmd .= " --ctimeout $optConnectTimeout" if ($optConnectTimeout);
		print $log "... call: $cmd \n" if ($pp);
		my $result = callScript($cmd);
		print $log $result if ($result and $pp);

		my $extract = 'unknown';
		$extract = $1 if ($result =~ m/^([^\s]+) /);
		$rc = 0 if ($extract eq "OK");
		$rc = 1 if ($rc == 3 and $result =~ m/AUTHENTICATION/);
		$allrc = 0 if ($extract eq "OK");
		$allrc = 1 if ($allrc == 3 and $rc == 3 and $result =~ m/AUTHENTICATION/);
		if ($rc == 0) {
		    $exitCode = 0;
		    print "... REST connection OK \n";
		    writeTxtFile($fileHost, "REST", $result);
		    createRESTconfig($host,$fileHost, "REST", $result);
		    # remove AUTH ERROR
		    $extract = "AUTHENTICATION ERROR";
		    if ($refResults and $refResults->{"AUTHENTICATION ERROR"}) {
			my $store = $refResults->{"AUTHENTICATION ERROR"};
			if ($store =~ m/$host[|]REST/) { # be careful with the regexp ! 
			    $store =~ s/[+ ]*$host.REST[\s]*//;
			    $refResults->{"AUTHENTICATION ERROR"} = $store;
			}
		    }
		} # success
		elsif ($rc == 1) {
		    $extract = "AUTHENTICATION ERROR";
		    $exitCode = 1 if ($exitCode == 3); # do not overwrite potential SNMP-OK
		    print "... REST AUTHENTICATION ERROR \n";
		    if ($refResults and $refResults->{"AUTHENTICATION ERROR"}) {
			my $store = $refResults->{"AUTHENTICATION ERROR"};
			$refResults->{"AUTHENTICATION ERROR"} = "$store + $host|REST"
			    if ($store !~ m/$host[|]REST/); # be careful with the regexp ! 
		    } else {
			$refResults->{"AUTHENTICATION ERROR"} = "$host|REST";
		    }
		}
		elsif ($result =~ m/TIMEOUT/i) {
		    $extract = "TIMEOUT";
		    if ($refResults and $refResults->{"TIMEOUT"}) {
			my $store = $refResults->{"TIMEOUT"};
			$refResults->{"TIMEOUT"} = "$store + $host|REST";
		    } else {
			$refResults->{"TIMEOUT"} = "$host|REST";
		    }
		}
		print $log "<<< $extract\n" if ($pp);
	    }
	    print $log "END DATE: \t" . ctime() . "\n";
	    close $log if ($log);
	} # single input file
	print "<<< $host $allrc\n" if ($main::processPrint and $start);
  } #oneHost

  sub ipv4discovery {
	my $host = shift;
	my $infile = shift;
	my $ipv4host = $host;
	my $bestExitCode = 3;
	my $firstLimit = undef;
	my $lastLimit = undef;
	# initial check of hostaddress
	if ($ipv4host !~ m/^\d+\.\d+\.\d+\./) {
		$exitCode = 2;
		$msg .= " - This method requires IPv4 address parts <n>.<n>.<n>. as host address (be aware of the dot at the end)";
	} 
	$ipv4host =~ m/^(\d+)\.(\d+)\.(\d+)\./;
	if ($exitCode != 2 
	and ($1 > 255 or $2 > 255 or $3 > 255 or $1 < 0 or $2 < 0 or $3 < 0)) 
	{
		$exitCode = 2;
		$msg .= " - Errnous number parts in IPv4 host address";
	}
	if ($exitCode != 2 and $ipv4host =~ m/^\d+\.\d+\.\d+\.(\d+-\d+)$/) {
	    my $limits = $1;
	    $limits =~ m/(\d+)-(\d+)/;
	    $firstLimit = $1;
	    $lastLimit = $2;
	    if ($1 > 255 or $2 > 255 or $1 < 0 or $2 < 0) {
		$exitCode = 2;
		$msg .= " - Errnous number parts in IPv4 host address";
	    } elsif ($firstLimit > $lastLimit) {
		$exitCode = 2;
		$msg .= " - Errnous number limit parts in IPv4 host address";
	    }
	    $lastLimit++ if (defined $lastLimit);
	    $ipv4host =~ s/\d+-\d+$//;
	} elsif ($exitCode != 2 and $ipv4host !~ m/^\d+\.\d+\.\d+\.$/) {
		$exitCode = 2;
		$msg .= " - This method requires IPv4 part <n>.<n>.<n>.[<range>] as host address";
	}
	if ($exitCode != 2) {
		$exitCode = 3;
		my $first = 0;
		my $last = 256;
		if (defined $firstLimit and defined $lastLimit) {
		    $first = $firstLimit;
		    $last  = $lastLimit;
		}
		for (my $i=$first;$i < $last;$i++) {
			#print (">>> $ipv4host" . "$i\n");
			$optHost = "$ipv4host" . "$i";
			$exitCode = 3;
			oneHost($optHost,$infile,1);
			$bestExitCode = $exitCode if ($exitCode < $bestExitCode);
		}
		$exitCode = $bestExitCode;
	}
  } #ipv4discovery

  sub hostCollection {
	my $collectionFile = shift;
	my $infile = shift;
	my @hostline = ();

	@hostline = handleHostCollectionFile($collectionFile);
	return if ($exitCode == 2);

	foreach my $oneLine (@hostline) {
		#or  $oneLine =~ m/^\d+\.\d+\.\d+\.\d+\-\d+$/) 
		if ($oneLine =~ m/^\d+\.\d+\.\d+\.$/ 
		or  $oneLine =~ m/^\d+\.\d+\.\d+\.\d+\-\d+$/ )
		{
		    ipv4discovery($oneLine, $infile);
		} else {
		    oneHost($oneLine, $infile,1);
		}
	} # foreach
  } #hostCollection

  sub CSVCollection {
	my $collectionFile = shift;
	my $infile = shift;
	return if (!$collectionFile);
	my @hostline = ();
	@hostline = handleCSVFile($collectionFile);
	return if ($exitCode == 2);
	return if ($main::verboseTable == 999);
	return if ($optShowOnly);
	my $saveOneHost = undef;
	foreach my $oneLine (sort @hostline) {
	    next if (!$oneLine);
	    next if ($saveOneHost and $saveOneHost eq $oneLine);
	    oneHost($oneLine, $infile,1) if ($main::verboseTable != 999);
	    $saveOneHost = $oneLine;
	} # foreach
  } # CSVCollection

  sub XMLCollection {
	my $collectionFile = shift;
	my $infile = shift;
	return if (!$collectionFile);
	my @hostline = ();
	@hostline = handleXMLFile($collectionFile);
	return if ($exitCode == 2);
	return if ($optShowOnly);
	my $saveOneHost = undef;
	foreach my $oneLine (sort @hostline) {
	    next if (!$oneLine);
	    next if ($saveOneHost and $saveOneHost eq $oneLine);
	    oneHost($oneLine, $infile,1) if ($main::verboseTable != 999);
	    $saveOneHost = $oneLine;
	} # foreach
  } #XMLCollection

  sub processData {
	$exitCode = 3;
        checkTools(); # set $usable* variables
	return if ($exitCode == 2);

	# the output directory
	handleOutputDirectory();
	return if ($exitCode == 2);

	print "DATE; \t" . ctime() . "\n" if ($main::processPrint);
	print "OUTDIR:\t$optOutdir\n" if ($main::processPrint);
	handleInputOptionFiles($optInputFile);
	return if ($exitCode == 2);

	# actions
	if ($optOneHost) {
	    oneHost($optHost, $optInputFile,1); 
	} elsif ($optIpv4Discovery) {
	    ipv4discovery($optHost, $optInputFile); 
	} elsif ($optHostCollection) {
	    hostCollection($optHostCollection, $optInputFile);
	} elsif ($optCSVCollection) {
	    CSVCollection($optCSVCollection, $optInputFile);
	} elsif ($optXMLCollection) {
	    XMLCollection($optXMLCollection, $optInputFile);
	}
	print "SUMMARY:\n" if ($main::processPrint and !$optShowOnly);
	if ($refResults and $main::processPrint) {
	    my $special = undef;
	    $special = $refResults->{"TIMEOUT"};
	    if ($special) {
		print "TIMEOUT\n\t" . $special . "\n";
	    }
	    $special = $refResults->{"AUTHENTICATION ERROR"};
	    if ($special) {
		print "AUTHENTICATION ERROR\n\t" . $special . "\n";
	    }
	    $special = $refResults->{"CONNECTION OK - NO SERVERVIEW"};
	    if ($special) {
		print "CONNECTION OK - NO SERVERVIEW\n\t" . $special . "\n";
	    }
	    my %results = %$refResults;
	    foreach my $hostnm (sort %results) {
		next  if (!$hostnm);
		next if ($hostnm =~ m/AUTHENTICATION ERROR/ or $hostnm =~ m/TIMEOUT/
		    or $hostnm =~ m/CONNECTION OK \- NO SERVERVIEW/);
		my $value = $results{$hostnm};
		next  if (!$value);
		print "$hostnm\n\t" . $value . "\n" if ($hostnm);
	    }
	}
  } #processData
###############################################################################
#------------ MAIN PART
$|++; # for unbuffered stdout print (due to Perl documentation)

my $path = $0;
$main::scriptPath = $path;
$main::scriptPath =~ s/[^\/]+$//;

handleOptions();

processData();

# final output 
my $stateString = $state[$exitCode];

$stateString = '' if ($optShowOnly);

finalizeMessageContainer();
finalize(
	$exitCode, 
	$stateString, 
	$msg,
	(! $notifyMessage	? '': "\n" . $notifyMessage),
	(! $longMessage		? '' : "\n" . $longMessage),
	($variableVerboseMessage ? "\n" . $variableVerboseMessage : ""),
);
################ EOSCRIPT
