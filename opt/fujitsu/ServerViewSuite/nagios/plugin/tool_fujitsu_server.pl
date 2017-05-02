#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2012, 2013, 2014, 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.00
# Date:		2015-11-25
# Based on SNMP MIB up to 2013 (ServerView Suite V6.20)

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Net::SNMP;
#use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

##### HELP ################################
    # ... ATTENTION: Use only blanks and NO tab in the descriptions ! 

=head1 NAME

tool_fujitsu_server.pl - Tool around Fujitsu servers for unscheduled calls

=head1 SYNOPSIS

tool_fujitsu_server.pl 
  { -H|--host=<host> 
    [-p|--port=<port>] [-T|--transport=<type>]  [--snmp=<n>]
    { [ -C|--community=<SNMP community string> ] | 
      { -u|--user=<username>  
        [--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
        [--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
        [--ctxengine=<id>] [--ctxname=<name>]
      }
      -I|--inputfile=<filename>
    }
    { [--mibtest | --connectiontest | --typetest [--nopp]] 
      | --ipv4-discovery 
      [-e|--extended]
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } | [-h|--help] | [-V|--version] 

Tool around Fujitsu servers for unscheduled calls

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

This option is used for Net::SNMP calles without any preliminary checks.

=item [-p|--port=<port>] [-T|--transport=<type>]  [--snmp=<n>]

SNMP service port number (default is 161) and SNMP transport socket type
like 'udp' or 'tcp' or 'udp6' or 'tcp6'.
The Perl Net::SNMP option for -T is in SNMP naming the '-domain' parameter.
With the "snmp" option 1=SNMPv1 or 2=SNMPv2c can be specified - SNMPv3 is 
automaticaly enabled if username is specified.

ATTENTION: IPv6 addresses require Net::SNMP version V6 or higher.

These options are used for Net::SNMP calles without any preliminary checks.

=item -C|--community=<SNMP community string>

SNMP community of the server - usable for SNMPv1 and SNMPv2. Default is 'public'.

These options are used for Net::SNMP calles without any preliminary checks.

=item -u|--user=<username> 
[--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
[--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
[--ctxengine=<id>] [--ctxname=<name>]

SNMPv3 authentication data. Default of authprotocol is 'md5' - Default of
privprotocol is 'des'. More about this options see Perl Net::SNMP session options.

These options are used for Net::SNMP calles without any preliminary checks.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.

=item --mibtest [--nopp]

SNMP test of various MIBs if accessible. As a result the type of a server can be checked.
This is the default option for this tool script.

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --typetest [--nopp]

SNMP test of MIBs if accessible to get server type information. 
As a result the type of a server can be checked.

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --connectiontest [--nopp]

SNMP test for connection and test with credentials resp. community. 
Test of the support of standard RFC1213.mib.

With extra option nopp for no-process-print the inbetween process results are not
printed.

=item --ipv4-discovery

SNMP test of various MIBs if accessible for 256 servers for a given n.n.n. IPv4 address. 
As a result the type of these server are checked.

=item -e|--extended

Extended MIB-Test: 
- check if address of parent node can be discovered 
- print PRIMERGY MultiNode information if available 
- print FQDN if available 
- print Agent version in summary if available

=item -t|--timeout=<timeout in seconds>

Timeout for the script processing.

=item -v|--verbose=<verbose mode level>

Enable verbose mode (levels: 1,2).
Check more data and print more output with verbose level 2.

=item -V|--version

Print version information and help text.

=item -h|--help

Print help text.

=cut

# define states
#### TEXT LANGUAGE AWARENESS (Standard in Nagios-Plugin)
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# init main options
our $optTimeout = 0;
our $optShowVersion = undef;
our $optHelp = undef;
our $optInputFile = undef;

our $argvCnt = $#ARGV + 1;
our $optHost = '';
our $optPort = undef;
our $optTransportType = undef;
our $optCommunity = undef; #SNMPv1, SNMPv2
our $optUserName = undef;	#SNMPv3
our $optAuthKey = undef;	#SNMPv3
our $optAuthPassword = undef;	#SNMPv3
our $optAuthProt = undef;	#SNMPv3
our $optPrivKey = undef;	#SNMPv3
our $optPrivPassword = undef;	#SNMPv3
our $optPrivProt = undef;	#SNMPv3
our $optCtxEngine = undef;	#SNMPv3
our $optCtxName = undef;	#SNMPv3
our $optSNMP = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;
$main::processPrint = 1;
our @gCntCodes = ( 0,0,0,0 );
#our @gCodesText = ( "ok", "no-snmp", "no-snmp-access", "unknown");

# init additional options
our $optConnectionTest	= undef;
our $optTypeTest	= undef;
our $optMibTest		= undef;
our $optIpv4Discovery	= undef;
our $optInventory	= undef;

our $optExtended	= undef;
our $optNoProcessPrint	= undef;

# global data
our @components = ();
our @subblades = ();
our %agentVersion = (
	"Name"		=> undef,
	"Company"	=> undef,
	"Version"	=> undef,
);
our $biosVersion	= undef;
our $RFC1213Description	= undef; # for Blade MMBs to scan for model info

# init output data
our $msg = '';
our $longMessage = '';
our $exitCode = 3;
our $variableVerboseMessage = '';
our $notifyMessage = '';

# init some multi used processing variables
our $session;
our $useSNMPv3 = undef;

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
#----------- SNMP functions
  sub simpleSNMPget {
	my $oid = shift;
	my $topic = shift;
	my $useSNMPv3ctx = undef;
	$useSNMPv3ctx = 1 if ($useSNMPv3 and ($optCtxEngine or $optCtxName));

	print '-> OID \'' . $oid . '\' (required) ' if ($main::verbose >= 10);
	my $response = undef;
	$response = $main::session->get_request($oid) if (!$useSNMPv3ctx);
	$response = $main::session->get_request(
            -contextengineid	=> $optCtxEngine,
            -contextname	=> $optCtxName,
	    -varbindlist	=> [ $oid ],
	) if ($useSNMPv3ctx);
	finalize(3, $state[3], 'SNMP::get_request(' . $topic . '): ' . $main::session->error) unless (defined $response);
	print '<- response: ' . ($response?$response->{$oid}:'---') . "\n" 
	    if ($main::verbose >= 10);
	# SNMPv3 exception:
	$response->{$oid} = undef if ($response and $response->{$oid} and $response->{$oid} =~ m/noSuchObject/i);
	return $response->{$oid};
  }
  sub trySNMPget {
	my $oid = shift;
	my $topic = shift; # unused
	my $useSNMPv3ctx = undef;
	$useSNMPv3ctx = 1 if ($useSNMPv3 and ($optCtxEngine or $optCtxName));

	print '-> OID \'' . $oid . '\' ' if ($main::verbose >= 10);
	my $response = undef;
	$response = $main::session->get_request($oid) if (!$useSNMPv3ctx);
	$response = $main::session->get_request(
            -contextengineid	=> $optCtxEngine,
            -contextname	=> $optCtxName,
	    -varbindlist	=> [ $oid ],
	) if ($useSNMPv3ctx);
	print '<- response: ' . ($response?$response->{$oid}:'---') . "\n" 
		if ($main::verbose >= 10) ;
	my $snmpErr = $main::session->error;
	print "--- SNMP ERROR TEXT: $snmpErr\n" if (!$response and $snmpErr and $snmpErr !~ m/noSuchName/
	    and $main::verbose >= 60);
	# SNMPv3 exception:
	$response->{$oid} = undef if ($response and $response->{$oid} and $response->{$oid} =~ m/noSuchObject/i);
	return ($response?$response->{$oid}:undef);
  }
  sub getSNMPtable {
	my $tableCheckRef = shift;
      	my $entries = undef;
	my $useSNMPv3ctx = undef;
	$useSNMPv3ctx = 1 if ($useSNMPv3 and ($optCtxEngine or $optCtxName));
	return undef if (!$tableCheckRef);
	my $thefirst = $tableCheckRef->[0];
	$thefirst =~ s/\d+$/\*/ if ($thefirst);
	print "<--> try TABLE OIDs '$thefirst\'\n" if ($main::verbose >= 10);
	$entries = $main::session->get_entries( -columns => $tableCheckRef ) if (!$useSNMPv3ctx);
	$entries = $main::session->get_entries( 
            -contextengineid	=> $optCtxEngine,
            -contextname	=> $optCtxName,
	    -columns => $tableCheckRef 
	) if ($useSNMPv3ctx);
	if ($main::verbose >= 10) {
		foreach my $snmpKey ( keys %{$entries} ) {
			print "$snmpKey --- $entries->{$snmpKey}\n";
		}		
	}
	# SNMPv3 exception:
	if ($useSNMPv3 and $entries) {
		foreach my $snmpKey ( keys %{$entries} ) {
			$entries->{$snmpKey} = undef if ($snmpKey and $entries->{$snmpKey}
			and $entries->{$snmpKey} =~ m/noSuchObject/i);
			print "$snmpKey --- $entries->{$snmpKey}\n";
		}		
	}
	return $entries;
  } # getSNMPtable
  sub getSNMPTableIndex {
	my $entries = shift;
	my $oidSelector = shift;
	my $indexSelector = shift;
	my @snmpIDs = ();

	return @snmpIDs if (!$entries or !$oidSelector or (defined $indexSelector and $indexSelector > 4));

	if ($indexSelector == 0) { # anything after . ..... UNUSED
		foreach my $snmpKey ( keys %{$entries} ) {
			push(@snmpIDs, $1) if ($snmpKey =~ m/$oidSelector.(.*)/);
		}
	}
	if ($indexSelector == 1) { # 1 index - type =  dezimal
		foreach my $snmpKey ( keys %{$entries} ) {
			push(@snmpIDs, $1) if ($snmpKey =~ m/$oidSelector.(\d+)/);
		}
	}
	if ($indexSelector == 2) { # 2 index, type = dezimal
		foreach my $snmpKey ( keys %{$entries} ) {
			push(@snmpIDs, $1) if ($snmpKey =~ m/$oidSelector.(\d+\.\d+)/);
		}
	}
	if ($indexSelector == 3) { # 3 index, type = dezimal
		foreach my $snmpKey ( keys %{$entries} ) {
			push(@snmpIDs, $1) if ($snmpKey =~ m/$oidSelector.(\d+\.\d+\.\d+)/);
		}
	}
	if ($indexSelector == 4) { # 4 index, type = dezimal
		foreach my $snmpKey ( keys %{$entries} ) {
			push(@snmpIDs, $1) if ($snmpKey =~ m/$oidSelector.(\d+\.\d+\.\d+\.\d+)/);
		}
	}
	@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
	return @snmpIDs;
  } #getSNMPTableIndex

  sub openSNMPsession 
  {
	my $error = undef;
	# connect to SNMP host
	my $host = $optHost;
	#$host = $optAdminHost if ($optAdminHost);
	#my %snmpSessionOpts = (
	#		-hostname   => $host,
	#);
	my %snmpSessionOpts;
	$snmpSessionOpts{'-hostname'}	= $host;
	$snmpSessionOpts{'-port'}	= $optPort if (defined $optPort);
	$snmpSessionOpts{'-domain'}	= $optTransportType if ($optTransportType);
	my $trySNMPv3 = 0;
	if (defined $optUserName or ($optSNMP and $optSNMP==3)) {
		$trySNMPv3 = 1;
		# Syntax
		# http://net-snmp.sourceforge.net/docs/perl-SNMP-README.html
		#	versus
		# http://search.cpan.org/~dtown/Net-SNMP-v6.0.1/lib/Net/SNMP.pm
		#
		$variableVerboseMessage .= "--- SNMPv3 ---\n" if ($main::verbose >= 44);
		my %snmp3SessionOpts = %snmpSessionOpts;
		$snmp3SessionOpts{'-version'}		= "3";
		$snmp3SessionOpts{'-maxmsgsize'}		= "1472";
		$snmp3SessionOpts{'-username'}		= $optUserName if ($optUserName);
		if ($optAuthKey or $optAuthPassword) {
		    $snmp3SessionOpts{'-authkey'}	= $optAuthKey if ($optAuthKey);
		    $snmp3SessionOpts{'-authpassword'}	= $optAuthPassword if ($optAuthPassword);
		    $snmp3SessionOpts{'-authprotocol'}	= $optAuthProt || 'md5';
		}
		if ($optPrivKey or $optPrivPassword) {
		    $snmp3SessionOpts{'-privkey'}	= $optPrivKey if ($optPrivKey);
		    $snmp3SessionOpts{'-privpassword'}	= $optPrivPassword if ($optPrivPassword);
		    $snmp3SessionOpts{'-privprotocol'}	= $optPrivProt || 'des';
		}
		($main::session, $error) = Net::SNMP->session(%snmp3SessionOpts);
		#$variableVerboseMessage .= "ATTENTION - SNMPv3 Error=$error" 
		#	if ((!defined $main::session));
		$useSNMPv3 = 1 if (defined $main::session);
		#### TODO-QUESTION: Should I switch automaticaly to SNMP1/2 in case of errors for SNMPv3 ???
	} # SNMPv3 user
	else {
	    if (!defined $main::session) {
		    $snmpSessionOpts{'-community'}	= $optCommunity || 'public';
	    }
	    if (!defined $main::session and !$optSNMP) {
		    $variableVerboseMessage .= "--- SNMP ---\n" if ($main::verbose >= 44);
		    ($main::session, $error) = Net::SNMP->session(%snmpSessionOpts);
		    #$variableVerboseMessage .= "SNMP Error=$error" 
			#    if (!defined $main::session and $main::verbose >= 5);
	    }
	    if (!defined $main::session and (!$optSNMP or $optSNMP==1)) {
		    $variableVerboseMessage .= "--- SNMPv1 ---\n" if ($main::verbose >= 44);
		    $snmpSessionOpts{'-version'}		= 'snmpv1';
		    ($main::session, $error) = Net::SNMP->session(%snmpSessionOpts);
		    #$variableVerboseMessage .= "SNMP Error=$error" 
			#    if (!defined $main::session and $main::verbose >= 5);
	    }
	    if (!defined $main::session and (!$optSNMP or $optSNMP==2)) {
		    $variableVerboseMessage .= "--- SNMPv2c ---\n" if ($main::verbose >= 44);
		    $snmpSessionOpts{'-version'}		= 'snmpv2c';
		    ($main::session, $error) = Net::SNMP->session(%snmpSessionOpts);
		    #$variableVerboseMessage .= "SNMP Error=$error" 
			#    if (!defined $main::session and $main::verbose >= 5);
	    }
	}
	$exitCode = 2 unless $main::session;
	$error = "$error - Perl-Net::SNMP does not support transport type -T $optTransportType"
		if ($error and $error =~ m/Invalid argument \'-domain\'/);
	$error = "..undefined.." if (!$main::session and !defined $error);
	if ($trySNMPv3 and !$main::session) {
	    finalize(3, $state[3], "[SNMPv3] SNMP::session(): $error") unless $main::session;
	} else {
	    finalize(3, $state[3], "SNMP::session(): $error") unless $main::session;
	}
  } #openSNMPsession
  sub closeSNMPsession {
	# close SNMP session
	return if (!defined $main::session);
	$main::session->close;
	$main::session = undef;
  } #closeSNMPsession
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
	$tmp .= "\n    AdminURL\t= $admURL" if ($admURL);
	addMessage("l",$tmp);
}
sub addVersion {
	my $container = shift;
	my $version = shift;
	my $tmp = '';
	return if (!$version);
	$tmp = " Version=\"$version\"";
	addMessage($container,$tmp);
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
			"C|community=s",	
		       	"P|p|port=i",	
		       	"T|transport=s",
			"snmp=i",
		       	"t|timeout=i",	
		       	"v|verbose=i",
			"vtab=i",
		       	"V|version",	
		       	"h|help",	
		       	"u|user=s",	
		       	"authkey=s",	
		       	"authpassword=s",
		       	"authprot=s",	
		       	"privkey=s",	
		       	"privpassword=s",
		       	"privprot=s",	
	   		"ctxengine=s"		,
	   		"ctxname=s"		,
		       	"connectiontest",	
		       	"typetest",	
		       	"mibtest",	
		       	"ipv4-discovery",
			"e|extended",	
			"nopp",		
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
			"C|community=s",	
		       	"P|p|port=i",	
		       	"T|transport=s",
			"snmp=i",
		       	"t|timeout=i",	
		       	"v|verbose=i",	
		       	"V|version",	
		       	"h|help",
		       	"u|user=s",	
		       	"authkey=s",	
		       	"authpassword=s",
		       	"authprot=s",	
		       	"privkey=s",	
		       	"privpassword=s",
		       	"privprot=s",	
	   		"ctxengine=s"		,
	   		"ctxname=s"		,
			"connectiontest",	
		       	"typetest",	
		       	"mibtest",	
		       	"ipv4-discovery",
			"e|extended",	
			"nopp",		
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

  sub setOptions { # script specific
	my $refOptions = shift;
	my %options =%$refOptions;
	#
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="ctxengine";	$optCtxEngine		= $options{$k} if (defined $options{$k});
	$k="ctxname";	$optCtxName		= $options{$k} if (defined $options{$k});
	$k="snmp";  $optSNMP = $options{$k}		if ($options{$k});
	$k="vtab";  $main::verboseTable = $options{$k}	if ($options{$k});
	foreach my $key (sort keys %options) {
		#print "options: $key = $options{$key}\n";

	        $optShowVersion = $options{$key}              	if ($key eq "V"			); 
		$optHelp = $options{$key}	               	if ($key eq "h"			);
		$optHost = $options{$key}                     	if ($key eq "H"			);
		$optPort = $options{$key}                     	if ($key eq "P"		 	);
		$optTransportType = $options{$key}            	if ($key eq "T"			);
		$optCommunity = $options{$key}                  if ($key eq "C"		 	);
		$optTimeout = $options{$key}                  	if ($key eq "t"			);
		$main::verbose = $options{$key}               	if ($key eq "v"			); 
		
		$optMibTest = $options{$key}              	if ($key eq "mibtest"		);	 
		$optConnectionTest = $options{$key}             if ($key eq "connectiontest"	);	 
		$optTypeTest = $options{$key}              	if ($key eq "typetest"		);	 
		$optIpv4Discovery = $options{$key}              if ($key eq "ipv4-discovery"	); 
		$optExtended = $options{$key}			if ($key eq "e"			); 
		$optNoProcessPrint = $options{$key}		if ($key eq "nopp"		); 

		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optAuthKey = $options{$key}             	if ($key eq "authkey"	 	);
		$optAuthPassword = $options{$key}             	if ($key eq "authpassword" 	);
		$optAuthProt = $options{$key}             	if ($key eq "authprot"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey"	 	);
		$optPrivPassword = $options{$key}             	if ($key eq "privpassword" 	);
		$optPrivProt = $options{$key}             	if ($key eq "privprot"	 	);
		
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

	if ($optHost =~ m/.*:.*:.*/ and !$optTransportType) {
		$optTransportType = "udp6";
	}
	if (!defined $optUserName and !defined $optCommunity) {
		$optCommunity = 'public'; # same default as other snmp nagios plugins
	}
	#
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}

	# Defaults
	$optMibTest = 999 if (!defined $optMibTest 
		and !defined $optTypeTest
		and !defined $optConnectionTest
		and !defined $optIpv4Discovery);
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
#------------ RFC1213.mib
sub RFC1213sysinfoUpTime {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidUpTime	= $snmpOidSystem . '3.0'; #sysUpTime.0
	my $uptime = trySNMPget($snmpOidUpTime,"sysUpTime");
	if ($uptime) {
		$exitCode = 0;
		$msg .= "SNMP UpTime = $uptime";
	}
}
sub RFC1213sysinfo {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidDescr	= $snmpOidSystem . '1.0'; #sysDescr.0
	my $snmpOidContact	= $snmpOidSystem . '4.0'; #sysContact.0
	my $snmpOidName		= $snmpOidSystem . '5.0'; #sysName.0
	my $snmpOidLocation	= $snmpOidSystem . '6.0'; #sysLocation.0

	my $descr = trySNMPget($snmpOidDescr,"sysDescr");
	my $name = trySNMPget($snmpOidName,"sysName");
	my $contact = trySNMPget($snmpOidContact,"sysContact");
	my $location = trySNMPget($snmpOidLocation,"sysLocation");


	{
		$msg .= "\nSystemname=$name " if ($name);
		$msg .= "Description=\"$descr\"" if ($descr);
		$msg .= " Location=\"$location\"" if ($location);
		$msg .= " Contact=\"$contact\"" if ($contact);
		$msg .= "\n";

		$longMessage .= "    Name\t= $name\n" if ($name);
		$longMessage .= "    Name\t= ... undefined ...\n" if (!$name and ($descr or $location or $contact));

		$longMessage =~ s/\0//g; # BX600 name error

		$RFC1213Description = $descr; # for Blade Model scan
	}
} #RFC1213sysinfo
#------------ BIOS.mib
sub BIOS_sniBios {
        # .1.3.6.1.4.1.231.2.10.2.2.1 (sniBios)
        my $snmpOidBiosGroup = '.1.3.6.1.4.1.231.2.10.2.2.1.' ;#sniBios
        my $snmpOidMajorVersion         = $snmpOidBiosGroup . '1.0'; #sniBiosVersionMajor
        my $snmpOidMinorVersion         = $snmpOidBiosGroup . '2.0'; #sniBiosVersionMinor
        my $snmpOidDiagStatus           = $snmpOidBiosGroup . '3.0'; #sniBiosDiagnosticStatus

        $exitCode = 0;
        my $majVersion = trySNMPget($snmpOidMajorVersion,"sniBios");
	$exitCode = 2 if (!defined $majVersion);
        $exitCode = 3 if ($exitCode == 0 and $majVersion == -1);
	my $minVersion = undef;
	$minVersion = trySNMPget($snmpOidMinorVersion,"sniBios") if ($exitCode == 0);
	$exitCode = 3 if ($exitCode == 0 and !$majVersion and !$minVersion); # prevent Version=0.0
	$minVersion = undef if ($minVersion and $minVersion == -1);
	if ($exitCode == 0) {
                #my $minVersion = trySNMPget($snmpOidMinorVersion,"sniBios");
                my $diag = trySNMPget($snmpOidDiagStatus,"sniBios");
		#$msg .= "BIOS - Version=$majVersion";
		#$msg .= ".$minVersion" if (defined $minVersion);
		my $versionString = "$majVersion";
		$versionString .= ".$minVersion" if (defined $minVersion);
		$msg .= "BIOS -";
		addVersion("m", $versionString);
		if (defined $diag) {
			my $diagHex = '.....';
			$diagHex = sprintf("0x%x", $diag);
			$msg .= " Diagnostic-Bit-Status=$diagHex";
		}
        }
} #BIOS_sniBios
#------------ SC.mib
sub sc_sniScBiosVersionString {
	my $snmpOidBiosVersion = ".1.3.6.1.4.1.231.2.10.2.2.5.4.14.0";
	$exitCode = 0;
	my $scBiosVersion = trySNMPget($snmpOidBiosVersion);
	$exitCode = 3 if (!defined $scBiosVersion);
	if ($exitCode == 0) {
		#$msg .= "BIOS - $scBiosVersion";
		$msg .= "BIOS -";
		addVersion("m", $scBiosVersion);
        }
  } #sc_sniScBiosVersionString
#------------ INVENT.mib
sub sniInventory {
	my $snmpOidInventory = '.1.3.6.1.4.1.231.2.10.2.1.'; #sniInventory
	my $snmpOidMajVersion	= $snmpOidInventory . '1.0'; #sniInvRevMajor
	my $snmpOidMinVersion	= $snmpOidInventory . '2.0'; #sniInvRevMinor
	my $snmpOidOS		= $snmpOidInventory . '4.0'; #sniInvHostOS
	my $snmpOidName		= $snmpOidInventory . '8.0'; #sniInvHostName
	my $snmpOidOSRevision	= $snmpOidInventory . '22.0'; #sniInvHostOSRevision
	my $snmpOidFQDN		= $snmpOidInventory . '26.0'; #sniInvFullQualifiedName

	$exitCode = 0;
	my $majVersion = trySNMPget($snmpOidMajVersion,"sniInventory");
	$exitCode = 3 if (!defined $majVersion);
	if ($exitCode==0) {
		my $minVersion = trySNMPget($snmpOidMinVersion,"sniInventory");
		my $os = trySNMPget($snmpOidOS,"sniInventory");
		my $name = trySNMPget($snmpOidName,"sniInventory");
		my $fqdn = trySNMPget($snmpOidFQDN,"sniInventory");

		{
			#$msg .= "INVENT - Version=$majVersion";
			#$msg .= ".$minVersion" if (defined $minVersion);
			my $versionString = "$majVersion";
			$versionString .= ".$minVersion" if (defined $minVersion);
			$msg .= "INVENT -";
			addVersion("m", $versionString);
			$msg .= " Name=$name" if ($name);
			$msg .= " OS=\"$os\"" if ($os);
			$msg .= " FQDN=$fqdn" if ($fqdn);

			$longMessage .= "\n    OS\t\t= $os" if ($os);
			$longMessage .= "\n    FQDN\t= $fqdn" if ($fqdn and $optExtended);
		}
	}
} #sniInventory
#------------ OS.mib
  sub svOsAgentInfo {
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.1.';# svOsAgentInfo
	my $snmpID	= $snmpOID . '1.0'; #svOsAgentId
	my $snmpVersion = $snmpOID . '3.0'; #svOsAgentVersion
	my $snmpOSType	= $snmpOID . '5.0'; #svOsAgentInterface
	my @typeText = (        "none",
	    "other", "operatingSystem", "bmc", "unexpected", );

	$exitCode = 0;
	my $idString = trySNMPget($snmpID,"svOsAgentId");
	$exitCode = 3 if (!defined $idString);

	my $version = undef;
	my $type = undef;
	$version = trySNMPget($snmpVersion, "svOsAgentVersion") if ($idString);
	$type = trySNMPget($snmpOSType, "svOsAgentInterface") if ($idString);
	$type = 0 if (!defined $type or $type <= 0);
	$type = 4 if ($type and $type >= 4);
	$msg .= "OSAgent=\"$idString $version\"" if ($idString and $version);
	$msg .= "OSAgent=\"$idString\"" if ($idString and !$version);
	$msg .= " OSType=$typeText[$type]" if ($type);
  } #svOsAgentInfo
  sub svOsInfoTable {
	my $isiRMC = shift;
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.2.1.'; #svOsInfoTable
	my $snmpDesignation = $snmpOID . '2.1'; #svOsDesignation
	my $snmpVersion	    = $snmpOID . '6.1'; #svOsVersionDesignation
	my $snmpDomain	    = $snmpOID . '13.1'; #svOsDomainName

	my $os		= trySNMPget($snmpDesignation, "svOsDesignation");
	my $fqdn	= trySNMPget($snmpDomain, "svOsDomainName");

	if (!$isiRMC) {
	    $longMessage .= "\n    OS\t\t= $os" if ($os);
	    $longMessage .= "\n    FQDN\t= $fqdn" if ($fqdn and $optExtended);
	} else {
	    $longMessage .= "\n    Base-OS\t= $os" if ($os);
	    $longMessage .= "\n    Base-FQDN\t= $fqdn" if ($fqdn and $optExtended);
	}
  } #svOsInfoTable
  sub svOsPropertyTable {
 	my $isiRMC = shift;
	return if (!$isiRMC);
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.3.1.'; #svOsPropertyTable
	my $snmpManagement  = $snmpOID . '9.1'; #svOsManagementSoftware
	my @managText = ( 'undefined',
	    'Unknown Agent', 'No Agent', 'Agentless Service', 'Mgmt. Agent', '..undefined..', 
	);
	# ORIGIN strings: unknown(1),        none(2),        agentlessManagementService(3),        agents(4)
	# ... the strings above are the oness of CIM provider
	my $manag = trySNMPget($snmpManagement,"svOsManagementSoftware");
	$manag = 0 if (!defined $manag or $manag < 0);
	$manag = 5 if ($manag and $manag > 5);
 	addMessage("l", "\n    Agent\t= $managText[$manag]") if ($manag);
 } #svOsPropertyTable
  sub OSmib {
	my $item = shift;
	my $isiRMC = shift;
	svOsAgentInfo() if ($item == 0);
	svOsInfoTable($isiRMC) if ($item == 1);
	svOsPropertyTable($isiRMC) if ($item == 2);
  } #OSmib
#------------ Status.mib
sub status_sieStAgentInfo {
	#--       sieStAgentInfo group:	  1.3.6.1.4.1.231.2.10.2.11.1
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.2.10.2.11.1.'; #sieStAgentInfo
	my $snmpOidId		= $snmpOidAgentInfoGroup . '1.0'; #sieStAgentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0'; #sieStAgentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0'; #sieStAgentVersionString

	my $id = trySNMPget($snmpOidId, "sieStAgentInfo");
	$exitCode = 3 if (!defined $id);
	my $company = undef;
	my $version = undef;
	if ($id) {
		$company = trySNMPget($snmpOidCompany, "sieStAgentInfo");
		$version = trySNMPget($snmpOidVersion, "sieStAgentInfo");
	}
	if ($id) {
		$msg .= "Agent=\"$id\"";
		$msg .= " Company=$company" if ($company);
		#$msg .= " Version=$version" if ($version);
		addVersion("m", $version);
	}
	$agentVersion{"Name"} = $id if ($id);
	$agentVersion{"Company"} = $company if ($company);
	$agentVersion{"Version"} = $version if ($version);
} #status_sieStAgentInfo
sub status_sieStatus {
	# Status.mib
	my $snmpOidPrefix = '1.3.6.1.4.1.231.2.10.2.11.'; #sieStatus
	my $snmpOidSysStat		= $snmpOidPrefix . '2.1.0'; #sieStSystemStatusValue.0
	my $snmpOidSubSysCnt		= $snmpOidPrefix . '3.2.0'; #sieStNumberSubsystems.0
	my $snmpOidSubSys		= $snmpOidPrefix . '3.1.1.'; #sieStSubsystemTable
	my $snmpOidSubSysName		  = $snmpOidSubSys . '2'; #sieStSubsystemName
	my $snmpOidSubSysValue		  = $snmpOidSubSys . '3'; #sieStSubsystemStatusValue
	my @subSysStatusText = ( 'none', 'ok', 'degraded', 'error', 'failed', 'unknown' );
	my $srvSubSystem_cnt = undef;
	my $result = undef;
	# fetch central system state
	$exitCode = 0;
	my $srvCommonSystemStatus = trySNMPget($snmpOidSysStat,"SystemStatus");
	$exitCode = 3 if (!defined $srvCommonSystemStatus);

	if ($exitCode == 0) {
		# set exit value
		$srvCommonSystemStatus = 5 if ($srvCommonSystemStatus > 5);
		$msg .= "SUMMARY($subSysStatusText[$srvCommonSystemStatus])";
		# get subsystem information
		$srvSubSystem_cnt = trySNMPget($snmpOidSubSysCnt,"SubSystemCount");
		
		for (my $x = 1; $srvSubSystem_cnt and $x <= $srvSubSystem_cnt; $x++) {	
			$result = trySNMPget($snmpOidSubSysValue . '.' . $x,"SubsystemStatusValue"); #sieStSubsystemStatusValue	
			my $subSystemName = trySNMPget($snmpOidSubSysName . '.' . $x,"SubsystemName"); #sieStSubsystemName	
			next if (!defined $result or $result >= 5);
			next if (!$subSystemName); # iRMC error !
			{
				$msg .= " $subSystemName";
				$msg .= "($subSysStatusText[$result])";
			}
			push(@components, $subSystemName);
		} # for subsystems
	} # found overall
} #status_sieStatus
#------------ SC2.mib
sub sc2ManagementNodeTable {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.3.1.1.'; #sc2ManagementNodeTable
	my $snmpOidAddress	= $snmpOidTable . '4'; #sc2UnitNodeAddress
	my $snmpOidName		= $snmpOidTable . '7'; #sc2UnitNodeName
 	my $snmpOidClass	= $snmpOidTable . '8'; #sc2UnitNodeClass
	my @tableChecks = (
		$snmpOidAddress,
		$snmpOidName,
		$snmpOidClass,
	);
	if ($optExtended) {
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidAddress.(\d+\.\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		foreach my $id (@snmpIdx) {
 			my $address  = $entries->{$snmpOidAddress . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
 			my $class = $entries->{$snmpOidClass . '.' . $id};
			# search class == 4 --- "management-blade"
			if ($class and $class == 4) {
			    {
				$longMessage .= "\n    Parent Name\t= $name" 
					if ($name and $address and !($name eq $address));
				$longMessage .= "\n    Parent Address\t= $address";
			    }
			} #"management-blade"
		} # for keys
	} # extended
} #sc2ManagementNodeTable
sub sc2UnitTableModel {
	my $chkiRMC = shift;
	my $snmpOidUnitTable = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable
	my $snmpOidModel	= $snmpOidUnitTable . '5.1'; #sc2UnitModelName.1
	my $model = trySNMPget($snmpOidModel);
	if ($chkiRMC) {
		$longMessage .= "    Type\t= iRMC";
	}
	elsif ($model and $model =~ m/PRIMERGY/) {
		$longMessage .= "    Type\t= PRIMERGY with SV SNMP Agent";
	} else {
		$longMessage .= "    Type\t= Server with SV SNMP Agent";
	}
	$longMessage .= "\n    Model\t= $model" if ($model);
	{ # no dependency
		my $snmpOidAdmURL	= $snmpOidUnitTable .'10.1' ;#sc2UnitAdminURL

		my $admurl = trySNMPget($snmpOidAdmURL);
		addAdminURL($admurl); # ... extra checks
	}
	if ($optExtended) {

		# ---- MultiNode Chassis
		my $snmpOidClass	= $snmpOidUnitTable .'2.2' ;#sc2UnitClass
		my $snmpOidDesignation	= $snmpOidUnitTable .'4.2' ;#sc2UnitDesignation
		   $snmpOidModel	= $snmpOidUnitTable .'5.2' ;#sc2UnitModelName
		my $class = trySNMPget($snmpOidClass);
		my $name = undef;
		   $model = undef;
		if ($class and $class == 7) { # multiNodeChassis
			$name = trySNMPget($snmpOidDesignation);
			$model = trySNMPget($snmpOidModel);	
		}
		if ($name) {
			$longMessage .= "\n    MultiNode Parent\t= $name";
			$longMessage .= "\n    MultiNode Model\t= $model" if ($model);
		}
	} # extended
} #sc2UnitTableModel
sub sc2AgentInfo {
	my $chkiRMC = shift;
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.2.10.2.2.10.1.'; #sc2AgentInfo
	my $snmpOidAgtID	= $snmpOidAgentInfoGroup . '1.0'; #sc2AgentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0'; #sc2AgentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0'; #sc2AgentVersion
	
	$exitCode = 0;
	my $id = trySNMPget($snmpOidAgtID,"sc2AgentInfo");
	$exitCode = 3 if (!defined $id);
	if ($exitCode == 0) {
		my $company = trySNMPget($snmpOidCompany,"sc2AgentInfo");
		my $version = trySNMPget($snmpOidVersion,"sc2AgentInfo");
		{
			$msg .= "Server with SV SNMP Agent - Agent=\"$id\"";
			#$msg .= " Version=\"$version\"" if ($version);
			addVersion("m", $version);
			$msg .= " Company=\"$company\"" if ($company);
		}
		sc2UnitTableModel($chkiRMC); # check type
		sc2ManagementNodeTable();

		if (! $agentVersion{"Version"}) { # older iRMC
		    $agentVersion{"Name"} = $id if ($id);
		    $agentVersion{"Company"} = $company if ($company);
		    $agentVersion{"Version"} = $version if ($version);
		}
	} 
} #sc2AgentInfo

#------------ SVUpdate.mib
sub primergyUpdateAgent {
	my $snmpOidUpdServerStatus = '.1.3.6.1.4.1.231.2.10.2.12.1.3.1.0'; #svupdServerStatus
	#	    1=OK, 2=Warn, 3=Crit, 4=Unknown
	$exitCode = 0;
	my $state = trySNMPget($snmpOidUpdServerStatus);
	$exitCode = 3 if (!defined $state);
	if (defined $state) {
		$state = 4 if ($state > 4 or $state < 1);
		my $nagState = $state -1;
		$longMessage .= "\n    UpdateAgent\t= Status($state[$nagState]) SNMP-Monitoring=available";
	}
} # primergyUpdateAgent
#------------ S31.mib
sub s31CheckAgentInfo {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidAgtName	= $snmpOidAgentInfoGroup . '9.0' ; #s31AgentName
	$exitCode = 0;
	my $name = trySNMPget($snmpOidAgtName,"s31AgentInfo");
	$exitCode = 3 if (!defined $name);
}
sub s31AgentInfo {
	#--      s31AgentInfo group:              1.3.6.1.4.1.7244.1.1.1.1
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidIP		= $snmpOidAgentInfoGroup . '1.0' ; #s31AgentIpAddress
	my $snmpOidAdmURL	= $snmpOidAgentInfoGroup . '5.0' ; #s31AgentAdministrativeUrl
	my $snmpOidDate		= $snmpOidAgentInfoGroup . '7.0' ; #s31AgentDateTime
	my $snmpOidAgtName	= $snmpOidAgentInfoGroup . '9.0' ; #s31AgentName

	$exitCode = 0;
	my $name = trySNMPget($snmpOidAgtName,"s31AgentInfo");
	$exitCode = 3 if (!defined $name);
	my $ip = undef;
	my $url = undef;
	my $date = undef;

	if ($exitCode==0) {
		$ip = trySNMPget($snmpOidIP,"s31AgentInfo");
		$url = trySNMPget($snmpOidAdmURL,"s31AgentInfo");
		$date = trySNMPget($snmpOidDate,"s31AgentInfo");
	}
	if ($exitCode==0) {
		$msg .= "Blade - Name=$name";
		$msg .= " IP=$ip" if ($ip);
		$msg .= " AdminURL=$url" if ($url);
		$msg .= " DateTime=\"$date\"" if ($date);

		$longMessage .= "    Type\t= Primergy Blade";
		if ($RFC1213Description and $RFC1213Description =~ m/^PRIMERGY BX/) {
		    # Here is the dependency that RFC1213 description contains the correct data
		    my $model = undef;
		    if ($RFC1213Description =~ m/PRIMERGY BX([^\s]+) S(\d+)/) {
			my $type = $1;
			my $release = $2;
			$model = "PRIMERGY BX$type S$release";
		    } elsif ($RFC1213Description =~ m/PRIMERGY BX([^\s]+)/) {
			my $type = $1;
			$model = "PRIMERGY BX$type";
		    }
		    $longMessage .= "\n    Model\t= $model" if ($model);
		}
		addAdminURL($url) if ($url);
		$longMessage .= "\n";
	}
} #s31AgentInfo
sub s31MgmtBladeTable {
	my $snmpOidMgmtBladeTable = '.1.3.6.1.4.1.7244.1.1.1.2.1.1.'; #s31MgmtBladeTable (1)
	my $snmpOidStatus	= $snmpOidMgmtBladeTable .  '2'; #s31MgmtBladeStatus
	my $snmpOidSerial	= $snmpOidMgmtBladeTable .  '5'; #s31MgmtBladeSerialNumber
	my $snmpOidProduct	= $snmpOidMgmtBladeTable .  '6'; #s31MgmtBladeProductName
	my $snmpOidModel	= $snmpOidMgmtBladeTable .  '7'; #s31MgmtBladeModelName
	my $snmpOidFW		= $snmpOidMgmtBladeTable .  '9'; #s31MgmtBladeFirmwareVersion
	my $snmpOidMAC		= $snmpOidMgmtBladeTable . '10'; #s31MgmtBladePhysicalAddress
	my $snmpOidRunMode	= $snmpOidMgmtBladeTable . '11'; #s31MgmtBladeRunMode
	my @tableChecks = (
		$snmpOidStatus, $snmpOidSerial, $snmpOidProduct, $snmpOidModel, 
		$snmpOidMAC, $snmpOidRunMode, $snmpOidFW
	);
	my @statusText = ("none",
		"unknown", "ok", "not-present",	"error", "critical",
		"standby", "..unexpected..",
	);
	my @modeText = ( "none",
		"unknown", "master", "slave", "..unexpected..",
	);
	if ($optExtended) { # BLADE ManagementBlade
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 1);
		#addTableHeader("v","Management Blade Table");
		my $version = undef;
		foreach my $snmpID (@snmpIDs) {
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			my $product = $entries->{$snmpOidProduct . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $mac = $entries->{$snmpOidMAC . '.' . $snmpID};
			my $runmode = $entries->{$snmpOidRunMode . '.' . $snmpID};
			my $fw =  $entries->{$snmpOidFW . '.' . $snmpID};
			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
			$runmode = 0 if (!defined $runmode or $runmode < 0);
			$runmode = 4 if ($runmode > 4);
			$version = $fw if ($runmode == 2);
		} # each
		if ($version) {
			$agentVersion{"Version"} = $version if ($version);
		} #found something
	}
} #s31MgmtBladeTable

sub s31SwitchAgentInfo {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.1.1.1.1.'; # ???? QUANTA
	my $snmpOidDescription	= $snmpOidAgentInfoGroup . '1.0' ; #
	my $snmpOidSerial	= $snmpOidAgentInfoGroup . '4.0' ; #

	$exitCode = 0;
	my $description = trySNMPget($snmpOidDescription,"AgentInfo");
	$exitCode = 3 if (!defined $description);

	if ($exitCode==0) {
		my $serial = trySNMPget($snmpOidSerial,"s31AgentInfo");
		$msg .= "Switch - Description=\"$description\"";
		$msg .= " ID=$serial" if ($serial);

		$longMessage .= "    Type\t= Switch\n";
	}
} #s31SwitchAgentInfo
sub checkTableCount {
	my $statusOid = shift;
	my $name = shift;
	my $printSpecial = shift;
	my @tableChecks = (
		$statusOid,
	);
	#my $entries = $main::session->get_entries( -columns => \@tableChecks );
	my $entries = getSNMPtable(\@tableChecks);
	if ($entries) {
		my @keys = keys(%{$entries});
		my $count = $#keys;
		$count += 1 if ($count >= 0);
		$count = undef if ($count == -1);
		if ($count) {
			$msg .= "$name($count) ";
			push(@subblades,"$name($count)");
			$exitCode = 0;
			#if ($printSpecial and !$optExtended) {
			#	$longMessage .= "    Special\t= $name Blades\n";
			#}
		}
	} # entries
}
sub s31BladesInside {
	$exitCode  = 3;
	$msg = '';
	{ # Server Blade
		my $snmpOidSrvBlade	= '.1.3.6.1.4.1.7244.1.1.1.4.'; #s31ServerBlade
		my $snmpOidSrvBladeTable = $snmpOidSrvBlade . '2.1.1.'; #s31SvrBladeTable
		my $snmpOidStatus		= $snmpOidSrvBladeTable . '2'; #s31SvrBladeStatus
		checkTableCount($snmpOidStatus,"ServerBlades",0);
	}
	{ # FSIOM
		my $snmpOidBladeFsiom		= '.1.3.6.1.4.1.7244.1.1.1.3.8.'; #s31SysFsiom
		my $snmpOidState		= $snmpOidBladeFsiom . '1.0'; #s31SysFsiomStatus.0 

		my $tmpOverallFsiom = trySNMPget($snmpOidState,"FsiomOverall");
		if (defined $tmpOverallFsiom) {
			$msg .= "FSIOM(1) ";
			push(@subblades,"FSIOM(1)");
			$exitCode = 0;
		}
	}
	{ # SwitchBlade
		my $snmpOidSwBladeTable = '.1.3.6.1.4.1.7244.1.1.1.5.1.1.'; #s31SwitchBladeTable
		my $snmpOidStatus		= $snmpOidSwBladeTable . '2'; #s31SwitchBladeStatus
		checkTableCount($snmpOidStatus,"Switch",0);
	}
	{ # FCPT
		my $snmpOIDFcPTInfoTable = '1.3.6.1.4.1.7244.1.1.1.8.1.2.1.'; #s31FcPassThroughBladeInfoTable
		my $snmpOidStatus = $snmpOIDFcPTInfoTable . '2'; #s31FcPassThroughBladeInfoStatus
		checkTableCount($snmpOidStatus,"FibreChannelPassThrough",0);
	}
	{ #Phy LPT
		my $snmpOIDPhyBladeTable = '1.3.6.1.4.1.7244.1.1.1.10.1.1.'; #s31PhyBladeTable
		my $snmpOidStatus		= $snmpOIDPhyBladeTable . '9'; #s31PhyBladeStatus
		checkTableCount($snmpOidStatus,"LANPT",0);
	}
	{ # FC Switch
		my $snmpOIDFCSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.12.1.1.'; #s31FCSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDFCSwitchBladeTable . '17'; #s31FCSwitchBladeStatus
		checkTableCount($snmpOidStatus,"FCSwitch",0);
	}
	{ #IB Switch
		my $snmpOIDIBSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.16.1.1.'; #s31IBSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDIBSwitchBladeTable . '13'; #s31IBSwitchBladeStatus
		checkTableCount($snmpOidStatus,"IBSwitch",0);
	}
	{ # SAS
		my $snmpOIDSASSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.17.1.1.'; #s31SASSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDSASSwitchBladeTable . '13'; #s31SASSwitchBladeStatus
		checkTableCount($snmpOidStatus,"SASwitch",0);
	}
	{ #KVM
		my $snmpOIDKvmBladeTable = '1.3.6.1.4.1.7244.1.1.1.11.1.1.'; #s31KvmBladeTable
		my $snmpOidStatus	= $snmpOIDKvmBladeTable . '18'; #s31KvmBladeStatus
		checkTableCount($snmpOidStatus,"KVM",1);
	}
	{ # Storage
		my $snmpOIDStorageBladeTable = '1.3.6.1.4.1.7244.1.1.1.13.1.1.'; #s31StorageBladeTable
		my $snmpOidStatus	= $snmpOIDStorageBladeTable . '8'; #s31StorageBladeStatus
		checkTableCount($snmpOidStatus,"Storage",1);
	}
	$longMessage .= "    Sub-Blades\t= @subblades\n" if ($#subblades >= 0);
} #s31BladesInside
#------------ MMB-COM-MIB.mib
sub mmbcomCheckAgentInfo {
	my $snmpOidUnitInfoGroup = '.1.3.6.1.4.1.211.1.31.1.1.1.2.'; #mmb sysinfo unitInformation
	my $snmpOidLocalID = $snmpOidUnitInfoGroup . '1.0'; #localServerUnitId
	$exitCode = 0;
	my $localID = trySNMPget($snmpOidLocalID ,"unitInformation");
	$exitCode = 3 if (!defined $localID);
}
sub mmbcomAgentInfo { # Cassiopeia does not support following data !
	# 1.3.6.1.4.1.211.1.31.1 (primequest) .1(mmb) .1(sysinfo) .1(agentInfo)
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.211.1.31.1.1.1.1.'; #agentInfo
	my $snmpOidId		= $snmpOidAgentInfoGroup . '1.0' ;#agentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0' ;#agentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0' ;#agentVersion

	$exitCode = 0;
	my $id = trySNMPget($snmpOidId, "agentInfo");
	$exitCode = 3 if (!defined $id);
	my $company = undef;
	my $version = undef;
	if ($exitCode == 0) {
		$company = trySNMPget($snmpOidCompany, "agentInfo");
		$version = trySNMPget($snmpOidVersion, "agentInfo");
	}
	if ($exitCode == 0) {
		$msg .= "PRIMEQUEST - Agent=\"$id\"";
		#$msg .= " Version=$version" if ($version);
		addVersion("m", $version);
		$msg .= " Company=\"$company\"" if ($company);
	}
	$agentVersion{"Name"} = $id if ($id);
	$agentVersion{"Company"} = $company if ($company);
	$agentVersion{"Version"} = $version if ($version);
} #mmbcomAgentInfo
sub primequestUnitTableChassis {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.3.1.'; #mmb sysinfo unitInformation unitTable
	my $snmpOidDesignation	= $snmpOidUnitTable .  '4'; #unitDesignation
	my $snmpOidModel	= $snmpOidUnitTable .  '5'; #unitModelName
	my $snmpOidSerial	= $snmpOidUnitTable .  '7'; #unitSerialNumber
	my $snmpOidLocation	= $snmpOidUnitTable .  '8'; #unitLocation
	my $snmpOidContact	= $snmpOidUnitTable .  '9'; #unitContact
	my $snmpOidAdmURL	= $snmpOidUnitTable . '10'; #unitAdminURL
	
	$exitCode = 0;
	my $designation = trySNMPget($snmpOidDesignation . '.1' ,"unitDesignation-Chassis");
	$exitCode = 3 if (!defined $designation);
	if ($exitCode==0) {
		my $model = trySNMPget($snmpOidModel . '.1' ,"unitModelName-Chassis");
		my $location = trySNMPget($snmpOidLocation . '.1' ,"unitLocation-Chassis");
		my $contact = trySNMPget($snmpOidContact . '.1' ,"unitContact-Chassis");
		my $admURL = trySNMPget($snmpOidAdmURL . '.1' ,"unitAdminURL-Chassis");
		{
			$msg .= "PRIMEQUEST - Name=\"$designation\"";
			$msg .= " Location=\"$location\"" if ($location);
			$msg .= " Contact=\"$contact\"" if ($contact);
			$msg .= " AdminURL=\"$admURL\"" if ($admURL); 
			$msg .= " Model=\"$model\"" if ($model);
			$longMessage .= "    Type\t= Primequest";
			$longMessage .= "\n    AdminURL\t= $admURL" if ($admURL); 
			$longMessage .= "\n    Model\t= $model" if ($model);
		}
	} 
} #primequestUnitTableChassis
#------------ RACKCDU
  sub rackAgentInfo {
	my $baseOID = ".1.3.6.1.4.1.39829.1.1."; # product
	my $snmpOIDVersion	= $baseOID . "2.0"; #version
	#my $snmpOIDDate		= $baseOID . "3.0"; #date

	my $version	= trySNMPget($snmpOIDVersion,"rack product.version");
	#my $date	= trySNMPget($snmpOIDDate,"rack product.date");

	if ($main::verboseTable == 400 and !$version) {
	    $version = "\$version\$";
	    #$date = "\$date\$";
	}

	if ($version ) { # or $date
	    #$agentVersion{"Name"} = $id if ($id);
	    #$agentVersion{"Company"} = $company if ($company);
	    $agentVersion{"Version"} = $version if ($version);
	}
  } #rackAgentInfo
  sub rackSystemInfo {
	my $baseOID = ".1.3.6.1.4.1.39829.1.1."; # product
	my $snmpOIDName		= $baseOID . "1.0"; #name
	my $snmpOIDRnumber	= $baseOID . "4.0"; #rackNumber
	my $snmpOIDDescription	= $baseOID . "5.0"; #description

	my $type = undef;
	my $name = undef;
	my $descr = undef;
	$type	= trySNMPget($snmpOIDName,"rack product.name");
	$name	= trySNMPget($snmpOIDRnumber,"rack product.rackNumber") if ($type);
	#$descr	= trySNMPget($snmpOIDDescription,"rack product.description") if ($type);

	if ($main::verboseTable == 400 and !$type) {
	    $type = "..type..";
	    $name = "..name..";
	    #$descr = "..descr..";
	}
	if ($type or $name) {
	    addMessage("l","\n") if ($longMessage !~ m/\n$/);
	    addMessage("l","    Type\t= RackCDU\n");
	    addMessage("l","    Identifier\t= $name\n");
	    addMessage("l","    Model\t= $type");
	}
  } #rackSystemInfo
  sub forceRackCDUStatus {
	my $OID = ".1.3.6.1.4.1.39829.1.1.6.0"; # status
	#ok(1),                warning(2),                error(3),                unknown(5)
	my @statusText = ("undefined",
	    "ok", "warning", "error", "..unexpected..", "unknown", 
	    "..unexpected..",
	);
	my $status = undef;
	$status = trySNMPget($OID,"RackCDU SNMP Agent") if (!$main::verbose or $main::verbose < 60);
	if (defined $status) {
	    my $lstatus = $status;
	    $lstatus = 6 if ($lstatus > 5);
	    $lstatus = 0 if ($lstatus < 0);
	    addMessage("m","- ");
	    addComponentStatus("m","RackCDU", $statusText[$lstatus]);
	}
	#$status = 6 if (defined $status and $main::verbose and $main::verbose >= 60);
	return $status;
  } #forceRackCDUStatus
  sub rackCDU {
	my $status = undef;
	
	if ($main::verboseTable != 400) {
	    $status = forceRackCDUStatus();
	    return if (!defined $status);
	} else {
	    $status = 2;
	}
	$exitCode = 0 if (defined $status);
	
	if (defined $status) {
	    rackSystemInfo();
	    rackAgentInfo() if ($optExtended);
	}
  } #rackCDU
#------------ RAID
our @raidCompStatusText = ( "none",	"ok", "prefailure", "failure", "..unexpected..",);
sub RAIDsvrStatus {
	my $snmpOidSrvStatusGroup = '.1.3.6.1.4.1.231.2.49.1.3.'; #svrStatus
	my $snmpOidOverall	= $snmpOidSrvStatusGroup . '4.0'; #svrStatusOverall

	$exitCode = 0;
	my $overall = trySNMPget($snmpOidOverall, "svrStatus");
	$exitCode = 3 if (!defined $overall);
	if (defined $overall) {
		$overall = 0 if ($overall < 0);
		$overall = 4 if ($overall > 4);
		$longMessage .= "\n    RAID\t= Status($raidCompStatusText[$overall])";
	}
} #RAIDsvrStatus
#------------ MIB TEST
sub mibtest {
	my $rfc = 0;
	my $statusmib = 0;
	my $sc2mib = 0;
	my $s31 = 0;
	my $primequest = 0;
	my $rack = 0;
	my $isiRMC = 0;

	@components = ();
	@subblades = ();
	{ # session
		print (">>> SNMP connect to host $optHost\n") if ($main::processPrint);
		# connect to SNMP host
		openSNMPsession();
		if ($exitCode == 2) {
			$msg .= "- $variableVerboseMessage";
			print ("    <<< FAILED - $variableVerboseMessage\n") if ($main::processPrint);
			$variableVerboseMessage = undef;
			$gCntCodes[1]++;

		} else {
			addMessage("l","    OptionFile\t= $optInputFile\n")
				if ($optInputFile);
			print ("    <<< OK\n") if ($main::processPrint);
		}
	}
	if ($exitCode != 2) { # RFC1213 Uptime
		print (">>> RFC1213 - Uptime\n") if ($main::processPrint);
		RFC1213sysinfoUpTime();
		if ($exitCode == 0) {
			print ("    <<< OK - " . $msg) if ($main::processPrint);
			$rfc = 1;
		} elsif ($exitCode == 3) {
			my $error = $main::session->error;
			my $addMsg = "($error)";
			$addMsg = '' if ($error =~ m/No response from remote host/);
			$msg .= "- No permission to get information $addMsg";
			print "    <<< FAILED - No permission to get information" if ($main::processPrint);
			$gCntCodes[2]++;
			$longMessage = '';
		}
		print "\n" if ($main::processPrint);
		$msg = undef if ($exitCode == 0);
	}
	if ($rfc) { # RFC1213
		print (">>> RFC1213 - System Information\n") if ($main::processPrint);
		RFC1213sysinfo();
		if ($msg) {
			print ("    <<< OK:\n" . $msg) if ($main::processPrint);
			$msg =~ m/Description=\"(.*)\"/;
			my $desc = $1;
			$isiRMC = 1 if ($desc and $desc =~ m/ arm/); # machine type ARM
			$isiRMC = 1 if ($desc and $desc =~ m/iRMC/i); # iRMC FW 7.6x or higher
		} else {
			print "    <<< FAILED - Unexpected" if ($main::processPrint);
			$exitCode = 3;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if ((!$optConnectionTest and $rfc) or $main::verbose>=2) { # Status.mib - Agent
		$exitCode = 0;
		print (">>> Status - Agent Info\n") if ($main::processPrint);
		status_sieStAgentInfo();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
			$statusmib = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if (!$optConnectionTest and $rfc and $statusmib) { # Status.mib - Status
		print (">>> Status - Subsystem Status Info\n") if ($main::processPrint);
		status_sieStatus();
		if ($exitCode == 3) {
			print "    <<< FAILED (No SV SNMP Agent available)" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
			$statusmib = 1;
		}
		print "\n" if ($main::processPrint);
		$longMessage .= "    Components\t= @components \n" if ($#components >= 0);
		$msg = undef;
	}
	
	if (!$optConnectionTest
	    and $rfc and ($statusmib or $main::verbose>=2 or $isiRMC)) 
	{ # SC2.mib
		print (">>> SC2 - Agent Info\n") if ($main::processPrint);
		sc2AgentInfo($isiRMC);
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			$msg =~ s/\0//gm if ($isiRMC);
			$longMessage =~ s/\0//gm if ($isiRMC);
			print "    <<< OK - $msg" if ($main::processPrint);
			$sc2mib = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	my $osmib = undef;
	if (!$optConnectionTest and $sc2mib ) { # OS.mib
		print (">>> OS - Agent Info\n") if ($main::processPrint);
		OSmib(0, $isiRMC);
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			$msg =~ s/\0//gm if ($isiRMC);
			$longMessage =~ s/\0//gm if ($isiRMC);
			print "    <<< OK - $msg" if ($main::processPrint);
			$osmib = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if ($osmib) { # OS.mib
		OSmib(1, $isiRMC); # OS & FQDN
	}
	if (!$optConnectionTest and $rfc and !$osmib and ($statusmib or $main::verbose>=2) and !$isiRMC) 
	{ # INVENT.mib
		print (">>> INVENT - Central Info \n") if ($main::processPrint);
		sniInventory();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if (!$optConnectionTest and $rfc and ($statusmib or $main::verbose>=2) and !$isiRMC) { # SVUpdate.mib
		print (">>> SVUpdate\n") if ($main::processPrint);
		primergyUpdateAgent();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		
		$msg = undef;
	}
	if (!$optConnectionTest and !$optTypeTest
	    and $rfc and $main::processPrint and ($statusmib or $main::verbose>=2) and !$isiRMC) 
	{ # SC.mib
		print (">>> SC - BIOS Version\n") if ($main::processPrint);
		sc_sniScBiosVersionString();
		if ($exitCode == 2) {
			print "    <<< FAILED" if ($main::processPrint);
			$exitCode = 3;
		} elsif ($exitCode == 3) {
			print "    <<< UNDEFINED (0 or -1)" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	
	if (!$optConnectionTest and !$optTypeTest
	    and $rfc and $main::processPrint and ($statusmib or $main::verbose>=2) and !$isiRMC) 
	{ # BIOS.mib
		print (">>> BIOS - Version and Diagnostic\n") if ($main::processPrint);
		BIOS_sniBios();
		if ($exitCode == 2) {
			print "    <<< FAILED" if ($main::processPrint);
			$exitCode = 3;
		} elsif ($exitCode == 3) {
			print "    <<< UNDEFINED (0 or -1)" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	my $chkSSM = 0;
	if ($optExtended and !$optConnectionTest and $rfc and $statusmib and !$isiRMC) {
		print (">>> ServerView Remote Connector\n") if ($main::processPrint);
		my $scsVersion = socket_checkSCS($optHost);
		print "    <<< OK Version=$scsVersion\n" if ($main::processPrint and $scsVersion);
		print "    <<< UNKNOWN\n" if ($main::processPrint and !$scsVersion);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.0[4-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.00.[1-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V2.[1-9]/);
		$chkSSM = 1 if ($scsVersion and $scsVersion =~ m/^V[3-9]/);
	}
	if ($chkSSM) {
		print (">>> ServerView System Monitor\n") if ($main::processPrint);
		my $ssmAddress = socket_checkSSM($optHost,$agentVersion{"Version"});
		print "    <<< OK Address=$ssmAddress\n" if ($main::processPrint and $ssmAddress);
		print "    <<< UNKNOWN\n" if ($main::processPrint and !$ssmAddress);
		$longMessage .= "\n    MonitorURL\t= $ssmAddress" if ($ssmAddress);
	}
	if ((!$optConnectionTest and $rfc and (!$optTypeTest or ($optTypeTest and !$statusmib)) and !$isiRMC)
	    or $main::verbose >= 2)  
	{ # S31.mib - Agent
		print (">>> S31 - Agent Info\n") if ($main::processPrint);
		s31AgentInfo();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
			$s31 = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if (!$optConnectionTest and $rfc and $s31) { # S31 - SubBlades
		print (">>> S31 - SubBlades\n") if ($main::processPrint);
		s31BladesInside();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
			$s31 = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if (!$optConnectionTest and $rfc and $s31) {
		s31MgmtBladeTable(); # fetch FW
	}
	if ((!$optConnectionTest and $rfc
	    and (!$optTypeTest or ($optTypeTest and !$statusmib and !$s31)) and !$isiRMC)
	    or $main::verbose >= 2) 
	{ # MMB-COM-MIB.mib Agent Info
		print (">>> MMB-COM-MIB - Agent Info\n") if ($main::processPrint);
		mmbcomAgentInfo();
		mmbcomCheckAgentInfo() if ($exitCode == 3); # Cassiopeia
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			$msg .= "PRIMEQUEST - UNABLE TO GET AGENT INFO !"
			    if (!$msg); # Cassiopeia
			print "    <<< OK - $msg" if ($main::processPrint);
			$primequest = 1;
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if (!$optConnectionTest and $rfc and $primequest) { # MMB-COM-MIB.mib - Chassis Unit
		print (">>> MMB-COM-MIB - Chassis Unit Info\n") if ($main::processPrint);
		primequestUnitTableChassis();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if ((!$optConnectionTest and $rfc
	    and (!$optTypeTest or ($optTypeTest and !$statusmib and !$s31 and !$primequest)) 
	    and !$isiRMC)) {
		print (">>> RACKCDU - Overall Status\n") if ($main::processPrint);
		$exitCode = 3;
		rackCDU();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK" if ($main::processPrint);
			$rack = 1;
		}
		print "\n" if ($main::processPrint);
	}
	if (!$optConnectionTest and $rfc and !$isiRMC and !$rack) { #RAID
		print (">>> RAID - Overall Status\n") if ($main::processPrint);
		RAIDsvrStatus();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
	}
	if (!$optConnectionTest and !$optTypeTest 
	    and $rfc and $exitCode == 3 and $main::verbose >= 4) 
	{
		print (">>> ????-MIB - Switch Info\n") if ($main::processPrint);
		s31SwitchAgentInfo();
		if ($exitCode == 3) {
			print "    <<< FAILED" if ($main::processPrint);
		} else {
			print "    <<< OK - $msg" if ($main::processPrint);
		}
		print "\n" if ($main::processPrint);
		$msg = undef;
	}
	if ($osmib) {
	    OSmib(2, $isiRMC); # Management Agent Connection Status
	}
	if ($optExtended) {
	    my $agtVersion	= $agentVersion{"Version"};
	    addMessage("l","\n") if ($longMessage and $longMessage !~ m/\n$/);
	    $longMessage .= "    AgentVersion= $agtVersion \n" if ($agtVersion 
		and !$isiRMC and !$s31 and !$rack);
	    $longMessage .= "    FWVersion\t= $agtVersion \n" if ($agtVersion and ($isiRMC));
	    $longMessage .= "    FWVersion\t= $agtVersion" if ($agtVersion and ($s31 or $rack));
	}
	
	# close SNMP session
	closeSNMPsession();
	if ($longMessage) {
		$exitCode = 0;
		$gCntCodes[0]++;
	} elsif ($rfc) {
		$gCntCodes[3]++;
	}
} #mibtest
#------------
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
			mibtest();
			intermediatePrint(	
				$state[$exitCode], 
				($msg?$msg:''),
				(! $longMessage ? '' : "\n" . $longMessage),
				($main::verbose >= 2 
				or $main::verboseTable) ? "\n" . $variableVerboseMessage: '',);
			$msg				= undef;
			$longMessage			= undef;
			$variableVerboseMessage		= undef;
		}
		$exitCode = 0 if ($gCntCodes[0]);
		$msg .= " -";
		$msg .= " OK($gCntCodes[0])" if ($gCntCodes[0]);
		$msg .= " NO-SNMP($gCntCodes[1])" if ($gCntCodes[1]);
		$msg .= " NO-SNMP-ACCESS($gCntCodes[2])" if ($gCntCodes[2]);
		$msg .= " UNKNOWN($gCntCodes[3])" if ($gCntCodes[3]);
	}
} #ipv4discovery
#------------ MAIN PART

handleOptions();


# set timeout
local $SIG{ALRM} = sub {
	#### TEXT LANGUAGE AWARENESS
	print 'UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($optTimeout);

$main::processPrint = 0 if ($optNoProcessPrint);

if ($optMibTest or $optConnectionTest or $optTypeTest) {
	mibtest();
} elsif ($optIpv4Discovery) {
	ipv4discovery();
}

# final output 
my $stateString = $state[$exitCode];
# $stateString = '' if ($optInventory);
if ($msg) {
    $msg =~ s/\0//gm; # remove 0x00 of iRMC data
}
if ($longMessage) {
    $longMessage =~ s/\s*$//m; # remove last blanks
    $longMessage =~ s/\0//gm; # remove 0x00 of iRMC data
}
$longMessage = undef if ($longMessage =~ m/^\s*$/);
if ($variableVerboseMessage) {
    $variableVerboseMessage =~ s/\n$//m; # remove last break
    $variableVerboseMessage =~ s/\0//gm; # remove 0x00 of iRMC data
}
$variableVerboseMessage = undef if ($variableVerboseMessage =~ m/^\s*$/);
finalize(
	$exitCode, 
	$stateString, 
	($msg?$msg:''),
	(! $longMessage ? '' : "\n" . $longMessage),
	($variableVerboseMessage and ($main::verbose >= 2 or $main::verboseTable)) ? "\n" . $variableVerboseMessage: '',
);
################ EOSCRIPT


