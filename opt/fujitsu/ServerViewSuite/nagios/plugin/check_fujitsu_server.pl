#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2012, 2013, 2014, 2015, 2016
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.30.00
# Date:		2016-05-19
#
# Based on SNMP MIB  2013-04 or higher
# ...	SNMP PRIMEQUEST 1st changes for Cassiopeia (2013-02)
# ...	SVUpdate.mib (2013)

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Getopt::Long qw(GetOptions);
use Pod::Usage  qw(pod2usage);
use Net::SNMP;
use Time::Local 'timelocal';
#use Time::localtime 'ctime';
use utf8;

##### HELP ################################

=head1 NAME

check_fujitsu_server.pl - Nagios-Check-Plugin for various Fujitsu servers

=head1 SYNOPSIS

check_fujitsu_server.pl 
  { -H|--host=<host>  [-A|--admin=<host>]
    [-P|--port=<port>] [-T|--transport=<type>] [--snmp=<n>]
    { [ -C|--community=<SNMP community string> ] | 
      { -u|--user=<username> 
        [--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
        [--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
        [--ctxengine=<id>] [--ctxname=<name>]
      }
      -I|--inputfile=<filename>
    }
    { [--chkuptime] | [--systeminfo] |
      [--chkmemperf [-w<percent>] [-c<percent>] ] |
      [--chkfsperf  [-w<percent>] [-c<percent>] ] |
      [--chknetperf  [-w<kbytesec>] [-c<kbytesec>] ] |
      { { [--blade] } | { [--pq | --primequest] } 
          { [--chksystem] 
            {[--chkenv] | [--chkenv-fan|--chkcooling] [--chkenv-temp] }
            [--chkpower] 
            {[--chkhardware] | [--chkcpu] [--chkvoltage] 
             [--chkmemmodule]}
            [--chkstorage] 
            [--chkdrvmonitor]
            [--chkupdate [{--difflist|--instlist}  [-O|--outputdir=<dir>]]]
          }
      } |
      { [--bladeinside] | 
        [--bladesrv] [--bladestore] [--bladekvm] 
        {[--bladeio] | [--bladeio-switch] [--bladeio-phy] 
          [--bladeio-fcswitch] [--bladeio-sasswitch] 
          [--bladeio-fsiom]  
        }
      } |
      { --rack }
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } |
  [-h|--help] | [-V|--version] 

Checks a Fujitsu server using SNMP.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip> [-A|--admin=<ip>]

Host address as DNS name or IP address of the server.
With optional option -A an administrative IP address can be specified.
This might be the address of iRMC as an example.
The communication is done via the admin address if specified.

These options are used for Net::SNMP calles without any preliminary checks.

=item [-P|--port=<port>] [-T|--transport=<type>] [--snmp=<n>]

SNMP service port number (default is 161) and SNMP transport socket type
like 'udp' or 'tcp' or 'udp6' or 'tcp6'.
The Perl Net::SNMP option for -T is in SNMP naming the '-domain' parameter.
With the "snmp" option 1=SNMPv1 or 2=SNMPv2c can be specified - SNMPv3 is 
automaticaly enabled if username is specified. All other values are ignored !

ATTENTION: IPv6 addresses require Net::SNMP version V6 or higher.

These options are used for Net::SNMP calles without any preliminary checks.

=item -C|--community=<SNMP community string>

SNMP community of the server - usable for SNMPv1 and SNMPv2. Default is 'public'.

These options are used for Net::SNMP calles without any preliminary checks.

=item --user=<username> 
[--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
[--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
[--ctxengine=<id>] [--ctxname=<name>]

SNMPv3 authentication data. Default of authprotocol is 'md5' - Default of
privprotocol is 'des'. More about this options see Perl Net::SNMP session options.

These options are used for Net::SNMP calles without any preliminary checks.

=item -I|--inputfile=<filename>

Host specific options read from <filename>. All options but '-I' can be
set in <filename>. These options overwrite options from command line.

=item --chkuptime

Tool option to check the SNMP access by reading the SNMP uptime via RFC1213.
This option can not be combined with other check options

=item --systeminfo

Only print available system information (dependent on server type and SNMP support).
This option can not be combined with other check options

=item --chkmemperf [-w<percent>] [-c<percent>]

PRIMERGY server: Get memory usage performance data (in percent).
This option can not be combined with other check options

With options -w and -c the warning and critical threshold limit can be set.
<percent> should be a simple integer 0..100

=item --chkfsperf [-w<percent>] [-c<percent>]

PRIMERGY server: Get file system performance data.
This option can not be combined with other check options

With options -w and -c the warning and critical threshold limit can be set.
<percent> should be a simple integer 0..100

=item --chknetperf [-w<kbytesec>] [-c<kbytesec>]

PRIMERGY server: Get network interface performance data.
This option can not be combined with other check options

With options -w and -c the warning and critical threshold limit can be set.
<kbytesec> should be a simple integer for KByte/sec

=item --blade

Check management blade (MMB)

=item --pq or --primequest

Check management information for a PRIMEQUEST system

=item --chksystem 

=item --chkenv | [--chkenv-fan|--chkcooling] [--chkenv-temp]

=item --chkpower

=item --chkhardware | [--chkcpu] [--chkvoltage] [--chkmemmodule]

Select range of system information: System meaning anything besides
Environment (Cooling Devices, Temperature) or Power (Supply units and consumption).

"Check Hardware" can be combined only with PRIMEQUEST option and returns voltage,
cpu and memory-module information.

Options chkenv and chkhardware can be splittet to select only parts of the above mentioned
ranges.

Hint: --chkenf-fan is an option available for compatibility reasons. 
The selected functionality is identic to chkcooling which supports the monitoring
for any cooling device: fans and liquid pumps

=item --chkhardware | [--chkcpu] [--chkvoltage] [--chkmemmodule]

=item --chkstorage

For PRIMERGY server these options can be used to monitor only "Hardware" or only "MassStorage" parts.
These areas are part of the Primergy System Information

=item --chkdrvmonitor

For PRIMERGY server: monitor "DriverMonitor" parts.

=item --chkupdate [{--difflist|--instlist}  [-O|--outputdir=<dir>]]

For PRIMERGY server: monitor "Update Agent" status.

difflist:
Fetch Update component difference list and print the first 10 ones of these and store
all of these in an host specific output file in directory <dir> if specified.

instlist:
Fetch Update installed component list and print the first 10 ones of these and store
all of these in an  host specific output file in directory <dir> if specified.

=item --bladeinside

Check all sub blade status values in a PRIMERGY Blade server. This is a combination
of --bladesrv --bladeio --bladekvm --bladestore where messages that one part doesn't
exist were suppressed.
(Do not combine with --blade - Use only for PRIMERGY Blades)

=item --bladesrv

Check server blade status values in a PRIMERGY Blade server.
(Do not combine with --blade - Use only for PRIMERGY Blades)

=item --bladeio |  --bladeio-***

Check io connection blade status values in a PRIMERGY Blade server. 
This option can be splitted for single types: 
[--bladeio-switch] [--bladeio-phy] [--bladeio-fcswitch] [--bladeio-sasswitch] [--bladeio-fsiom]
(Do not combine with --blade - Use only for PRIMERGY Blades)

=item --bladekvm

Check key/video/mouse blade status values in a PRIMERGY Blade server. 
(Do not combine with --blade - Use only for PRIMERGY Blades)

=item --bladestore

Check storage blade status values in a PRIMERGY Blade server. 
(Do not combine with --blade - Use only for PRIMERGY Blades)

=item --rack

Get monitoring information for RackCDU-TM.

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

#####################################

# HIDDEN OPTION #####################
# --agentinfo --chkfan --chktemp

#### GLOBALS ########################
# global control definitions
our $skipInternalNamesForNotifies = 1;


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
our $optTransportType = undef;
our $optSNMP = undef;
our $optAdminHost = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;

#$main::useNotify = 1;

# init additional options
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
#our $optChkTpm = undef;
our $optChkCpuLoadPerformance	= undef;
our $optChkMemoryPerformance	= undef;
our $optChkFileSystemPerformance = undef;
our $optChkNetworkPerformance	= undef;
our $optChkUpdate = undef;
our     $optChkUpdDiffList	= undef;
our	$optChkUpdInstList	= undef;
our	$optOutdir		= undef;

our $optBlade = undef;
our $optBladeContent = undef;
our $optBladeSrv = undef;
our $optBladeIO = undef;
our	$optBladeIO_Switch = undef;
our	$optBladeIO_FCPT = undef;
our	$optBladeIO_Phy = undef;
our	$optBladeIO_FCSwitch = undef;
our	$optBladeIO_IBSwitch = undef;
our	$optBladeIO_SASSwitch = undef;
our	$optBladeIO_FSIOM = undef;
our $optBladeKVM = undef;
our $optBladeStore = undef;

our $optPrimeQuest = undef;

our $optRackCDU = undef;

our $optChkUpTime = undef;
our $optSystemInfo = undef;
our $optAgentInfo = undef;
our $optUseDegree = undef;

# special sub options
our $optWarningLimit = undef;
our $optCriticalLimit = undef;

# option cross check result
our $setOverallStatus = undef;	# no chkoptions
our $setOnlySystem = undef;	# only --chksystem

# init output data
our $exitCode = 3;
our $error = '';
our $msg = '';
our $longMessage = '';
our $performanceData = '';
our $variableVerboseMessage = '';
our $notifyMessage = '';

# init some multi used processing variables
our $session;
our $useSNMPv3 = undef;
our $serverID = undef;
our $useDegree = 0;
our $PSConsumptionBTUH = 0;
#our %snmpSessionOpts;

#########################################################################################
#----------- multi usable functions
  sub finalize {
	my $tmpExitCode = shift;
	$|++; # for unbuffered stdout print (due to Perl documentation)
	my $string = "@_";
	$string =~ s/\s*$//;
	print "$string" if ($string);
	print "\n";
	alarm(0); # stop timeout
	exit($tmpExitCode);
  }
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
	$host = $optAdminHost if ($optAdminHost);
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
	my $isiRMC = undef;
	$isiRMC = 1 if (!defined $notifyMessage or !$notifyMessage or $notifyMessage =~ m/iRMC/ or $notifyMessage !~ m/Description/i);
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

###############################################################################
#----------- RFC1213
sub RFC1213sysinfoUpTime {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidUpTime	= $snmpOidSystem . '3.0'; #sysUpTime.0
	my $uptime = trySNMPget($snmpOidUpTime,"sysUpTime");
	if ($uptime) {
		$exitCode = 0;
		$msg .= "- SNMP access OK - SNMP UpTime = $uptime";
	} else {
		$msg .= "- Unable to get SNMP information";
		$longMessage .= "SNMP::get_request: " . $main::session->error;
	}
}
our $prgSystemName = undef;
sub RFC1213sysinfoToLong {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidDescr	= $snmpOidSystem . '1.0'; #sysDescr.0
	my $snmpOidContact	= $snmpOidSystem . '4.0'; #sysContact.0
	my $snmpOidName		= $snmpOidSystem . '5.0'; #sysName.0
	my $snmpOidLocation	= $snmpOidSystem . '6.0'; #sysLocation.0

	my $descr = trySNMPget($snmpOidDescr,"sysDescr");
	return if ($main::session->error =~ m/No response from remote host/);
	my $name = trySNMPget($snmpOidName,"sysName");
	my $contact = trySNMPget($snmpOidContact,"sysContact");
	my $location = trySNMPget($snmpOidLocation,"sysLocation");

	$prgSystemName = $name;
	$name =~ s/\0//g if ($name);

	addKeyValue("n","Systemname",$name);
	addKeyLongValue("n","Description",$descr);
	addLocationContact("n",$location, $contact);
} #RFC1213sysinfoToLong
sub mibTestSNMPget {

	my $oid = shift;
	my $topic = shift;
	my $skipRFC1213 = shift;

	print '-> OID \'' . $oid . '\' (REQUIRED) ' if ($main::verbose >= 10);
	my $response = $main::session->get_request($oid);
	my $printresponse = '<nothing>';
	$printresponse = $response->{$oid} if ($response);
	print '<- response: ' . $printresponse . "\n" if ($main::verbose >= 10);
	# ATTENTION - THIS SHOULD BE CHANGED
	if (!$skipRFC1213) {
		RFC1213sysinfoToLong() unless (defined $response);
		$longMessage .= "\n" unless (defined $response);
	}
	$notifyMessage =~ s/^\s+//m; # remove leading blanks
	$notifyMessage =~ s/\s+$//m; # remove last blanks
	finalize(3, $state[3], 
			"Unable to get SNMP " . $topic . " information for this host",
			($main::session->error?"\nSNMP::get_request: " . $main::session->error:''),
			(! $notifyMessage ? '': "\n" . $notifyMessage),
			($longMessage?"\n" . $longMessage:''),
	        ) 
		unless (defined $response);
	return ($response?$response->{$oid}:undef);
}
#------------ other helpers
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
		return 0 if ($val == 4294967295); # -0

		my $diffval = $maxval - $val;
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
  } #addRpmToPerfdata
  sub addPressureToPerfdata {
	my $name = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	#my $min = shift;
	#my $max = shift;

	if (defined $name and $current) {
		$performanceData .= ' ' . $name . '=' if ($name);
		$performanceData .= $current;
		$performanceData .= 'bar';
		$performanceData .= ';' if ($warning or $critical);
		$performanceData .= "$warning" if ($warning);
		$performanceData .= ';' if ($critical);
		$performanceData .= "$critical" if ($critical);
	}
  } #addPressureToPerfdata
#----------- synchronize verbose output format functions
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
	$tmp .= " ID=$id" if ($id or $container =~ m/.*m.*/);
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
  sub addPressure {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $tmp = '';
	my $suf = undef;
	$suf .= "bar";
	if ($current) {
		$tmp .= " Pressure=$current" . $suf;
		$tmp .= " Warning=$warning" . $suf if (defined $warning and $warning !~ m/:/);
		$tmp .= " Critical=$critical" . $suf if (defined $critical and $critical !~ m/:/);
		$tmp .= " WarningRange=$warning" . $suf if (defined $warning and $warning =~ m/:/);
		$tmp .= " CriticalRange=$critical" . $suf if (defined $critical and $critical =~ m/:/);
	}
	addMessage($container,$tmp);
  }
  sub addFlow {
	my $container = shift;
	my $current = shift;
	my $warning = shift;
	my $critical = shift;
	my $tmp = '';
	my $suf = undef;
	$suf .= "l/h";
	if ($current) {
		$tmp .= " Flow=$current" . $suf;
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
####
sub endVariableVerboseMessageLine {
	$variableVerboseMessage .= "\n";
}
sub endLongMessageLine {
	$longMessage .= "\n";
}
#################################################################################
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
		        "A|admin=s", 
			"snmp=i",
		       	"t|timeout=i",	
		       	"v|verbose=i",
			"vtab=i",
		       	"V|version",	
			"h|help",	
			"w|warning=i",
			"c|critical=i",
		    
			"chkuptime"		,
			"systeminfo"		,
			"agentinfo"		,
			"pq"			,
			"primequest"		,
			"rack"			,
			"blade"			,
			"bladeinside"		,
			"bladesrv"		,
			"bladeio"		,
			"bladeio-switch"	,
			"bladeio-fcpt"		,
			"bladeio-phy"		,
			"bladeio-fcswitch"	,
			"bladeio-ibswitch"	,
			"bladeio-sasswitch"	,
			"bladeio-fsiom"		,
			"bladekvm"		,
			"bladestore"		,
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
			"chkupdate"		,
			"chkstorage"		,
			"chkcpuload"		,
			"chkmemperf"		,
			"chkfsperf"		,
			"chknetperf"		,
			"chkfanperf"		,
			"degree!",

			"difflist",
			"instlist",
			  "O|outputdir=s",

	   		"u|user=s"		,
	   		"authkey=s"		,
	   		"authpassword=s"	,
	   		"authprot=s"		,
	   		"privkey=s"		,
	   		"privpassword=s"	,
	   		"privprot=s"		,	   		
	   		"ctxengine=s"		,
	   		"ctxname=s"		,
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
		        "A|admin=s", 
			"snmp=i",
		       	"t|timeout=i",	
		       	"v|verbose=i",
		       	"V|version",	
			"h|help",	
			"w|warning=i",
			"c|critical=i",
		    
			"chkuptime"		,
			"systeminfo"		,
			"agentinfo"		,
			"pq"			,
			"primequest"		,
			"rack"			,
			"blade"			,
			"bladeinside"		,
			"bladesrv"		,
			"bladeio"		,
			"bladeio-switch"	,
			"bladeio-fcpt"		,
			"bladeio-phy"		,
			"bladeio-fcswitch"	,
			"bladeio-ibswitch"	,
			"bladeio-sasswitch"	,
			"bladeio-fsiom"		,
			"bladekvm"		,
			"bladestore"		,
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
			"chkupdate"		,
			"chkstorage"		,
			"chkcpuload"		,
			"chkmemperf"		,
			"chkfsperf"		,
			"chknetperf"		,
			"chkfanperf"		,
			"degree!",

			"difflist",
			"instlist",
			  "O|outputdir=s",

	   		"u|user=s"		,
	   		"authkey=s"		,
	   		"authpassword=s"	,
	   		"authprot=s"		,
	   		"privkey=s"		,
	   		"privpassword=s"	,
	   		"privprot=s"		,
	   		"ctxengine=s"		,
	   		"ctxname=s"		,
		    ) or pod2usage({
			    -msg     => "\n" . 'Invalid argument!' . "\n",
			    -verbose => 1,
			    -exitval => 3
		    });
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
		#$optInputFile = $chkFileName;
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
	$k="A";		$optAdminHost		= $options{$k} if (defined $options{$k});
	$k="agentinfo";	$optAgentInfo		= $options{$k} if (defined $options{$k});
	$k="ctxengine";	$optCtxEngine		= $options{$k} if (defined $options{$k});
	$k="ctxname";	$optCtxName		= $options{$k} if (defined $options{$k});
	$k="degree";	$optUseDegree		= $options{$k} if (defined $options{$k});
	$k="difflist";	$optChkUpdDiffList	= $options{$k} if (defined $options{$k});
	$k="instlist";	$optChkUpdInstList	= $options{$k} if (defined $options{$k});
	$k="rack";	$optRackCDU		= $options{$k} if (defined $options{$k});
	$k="snmp";	$optSNMP		= $options{$k} if (defined $options{$k});
	$k="O";		$optOutdir		= $options{$k} if (defined $options{$k});
	$k="vtab";	$main::verboseTable = $options{$k}	if (defined $options{$k});
	    # ... the loop below is not realy necessary ...
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
		#$optInputFile = $options{$key}                	if ($key eq "I"			);
		$optWarningLimit = $options{$key}               if ($key eq "w"			);
		$optCriticalLimit = $options{$key}              if ($key eq "c"			);

		$optChkUpTime = $options{$key}			if ($key eq "chkuptime"		);
		$optSystemInfo = $options{$key}			if ($key eq "systeminfo"	);
		$optPrimeQuest = $options{$key}			if ($key eq "pq"		);
		$optPrimeQuest = $options{$key}			if ($key eq "primequest"	);
		$optBlade = $options{$key}			if ($key eq "blade"		);
		$optBladeContent = $options{$key}		if ($key eq "bladeinside"	);
		$optBladeSrv = $options{$key}			if ($key eq "bladesrv"		);
		$optBladeIO = $options{$key}			if ($key eq "bladeio"		);
		$optBladeIO_Switch = $options{$key}		if ($key eq "bladeio-switch"	);
		$optBladeIO_FCPT = $options{$key}		if ($key eq "bladeio-fcpt"	);
		$optBladeIO_Phy = $options{$key}		if ($key eq "bladeio-phy"	);
		$optBladeIO_FCSwitch = $options{$key}		if ($key eq "bladeio-fcswitch"	);
		$optBladeIO_IBSwitch = $options{$key}		if ($key eq "bladeio-ibswitch"	);
		$optBladeIO_SASSwitch = $options{$key}		if ($key eq "bladeio-sasswitch"	);
		$optBladeIO_FSIOM = $options{$key}		if ($key eq "bladeio-fsiom"	);
		$optBladeKVM = $options{$key}			if ($key eq "bladekvm"		);
		$optBladeStore = $options{$key}			if ($key eq "bladestore"	);

		$optChkSystem = $options{$key}			if ($key eq "chksystem"		);
		$optChkEnvironment = $options{$key}		if ($key eq "chkenv"		);
		$optChkEnv_Fan = $options{$key}			if ($key eq "chkenv-fan"	);
		$optChkEnv_Temp = $options{$key}		if ($key eq "chkenv-temp"	);
		$optChkPower = $options{$key}			if ($key eq "chkpower"		);
		$optChkHardware = $options{$key}		if ($key eq "chkhardware"	);
		$optChkCPU = $options{$key}			if ($key eq "chkcpu"		);
		$optChkVoltage = $options{$key}			if ($key eq "chkvoltage"	);
		$optChkMemMod = $options{$key}			if ($key eq "chkmemmodule"	);
		$optChkDrvMonitor = $options{$key}		if ($key eq "chkdrvmonitor"	);
		$optChkUpdate = $options{$key}			if ($key eq "chkupdate"		);
		$optChkStorage = $options{$key}			if ($key eq "chkstorage"	);
		$optChkCpuLoadPerformance = $options{$key}	if ($key eq "chkcpuload"	);
		$optChkMemoryPerformance = $options{$key}	if ($key eq "chkmemperf"	);
		$optChkFileSystemPerformance = $options{$key}	if ($key eq "chkfsperf"		);
		$optChkNetworkPerformance = $options{$key}	if ($key eq "chknetperf"	);
		$optChkFanPerformance = $options{$key}		if ($key eq "chkfanperf"	);
	   	
		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optAuthKey = $options{$key}             	if ($key eq "authkey"	 	);
		$optAuthPassword = $options{$key}             	if ($key eq "authpassword" 	);
		$optAuthProt = $options{$key}             	if ($key eq "authprot"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey"	 	);
		$optPrivPassword = $options{$key}             	if ($key eq "privpassword" 	);
		$optPrivProt = $options{$key}             	if ($key eq "privprot"	 	);
		
	}
  } #setOptions

  sub evaluateOptions { # script specific

	# check command-line parameters
	pod2usage({
		-verbose => 2,
		-exitval => 0,
	}) if ((defined $optHelp) || !$argvCnt);

	pod2usage({
		-msg		=> "\n$0" . ' - version: ' . $version . "\n",
		-verbose	=> 0,
		-exitval	=> 0,
	}) if (defined $optShowVersion);

	pod2usage({
		-msg		=> "\n" . 'Missing host address !' . "\n",
		-verbose	=> 0,
		-exitval	=> 3
	}) if ((!$optHost or $optHost eq '') and (!$optAdminHost or $optAdminHost eq ''));
	
	if ($optHost =~ m/.*:.*:.*/ and !$optTransportType) {
		$optTransportType = "udp6";
	}

	if (!defined $optUserName and !defined $optCommunity) {
		$optCommunity = 'public'; # same default as other snmp nagios plugins
	}
	# 
	if (!defined $optChkUpdate and ($optChkUpdDiffList or $optChkUpdInstList)) {
		$optChkUpdate = 999;
	}
	# first checks of sub blade options
	if (  (defined $optBladeIO_Switch)   || (defined $optBladeIO_FCPT)     || (defined $optBladeIO_Phy) 
	   || (defined $optBladeIO_FCSwitch) || (defined $optBladeIO_IBSwitch) || (defined $optBladeIO_SASSwitch)
	   || (defined $optBladeIO_FSIOM)
	   ) 
	{
		$optBladeIO = 999;
	}
	if ((defined $optBladeSrv) || (defined $optBladeIO) || (defined $optBladeKVM) || (defined $optBladeStore)) {
		$optBladeContent = 999 if (!defined $optBladeContent);
	}
	if (defined $optBladeContent and $optBladeContent != 999) { # all blades inside
		$optBladeSrv = 999 if (!defined $optBladeSrv);
		$optBladeIO = 888 if (!defined $optBladeIO); # ! not 999 !
		$optBladeKVM = 999 if (!defined $optBladeKVM);
		$optBladeStore = 999 if (!defined $optBladeStore);
	}
	# wrong combination tests
	my $wrongCombination = undef;
	if (defined $optPrimeQuest) {
		$wrongCombination = "--pq --chkcpuload" if (defined $optChkCpuLoadPerformance);
		$wrongCombination = "--pq --chkmemperf" if (defined $optChkMemoryPerformance
		    and $main::verbose < 4);
		$wrongCombination = "--pq --chkfsperf" if (defined $optChkFileSystemPerformance);
		$wrongCombination = "--pq --chknetperf" if (defined $optChkNetworkPerformance);
		$wrongCombination = "--pq --bladesrv" if (defined $optBladeSrv);
		$wrongCombination = "--pq --bladeio" if (defined $optBladeIO);
		$wrongCombination = "--pq --bladekvm" if (defined $optBladeKVM);
		$wrongCombination = "--pq --bladestore" if (defined $optBladeStore);
		$wrongCombination = "--pq --bladeinside" 
			if (defined $optBladeContent and $optBladeContent != 999);
		$wrongCombination = "--pq --chkstorage" if (defined $optChkStorage);
		$wrongCombination = "--pq --chkdrvmonitor" if (defined $optChkDrvMonitor);
		$wrongCombination = "--pq --chkupdate" if (defined $optChkUpdate);
	} # primequest
	if (defined $optRackCDU) {
		$wrongCombination = "--rack --chkcpuload" if (defined $optChkCpuLoadPerformance);
		$wrongCombination = "--rack --chkmemperf" if (defined $optChkMemoryPerformance
		    and $main::verbose < 4);
		$wrongCombination = "--rack --chkfsperf" if (defined $optChkFileSystemPerformance);
		$wrongCombination = "--rack --chknetperf" if (defined $optChkNetworkPerformance);
		$wrongCombination = "--rack --bladesrv" if (defined $optBladeSrv);
		$wrongCombination = "--rack --bladeio" if (defined $optBladeIO);
		$wrongCombination = "--rack --bladekvm" if (defined $optBladeKVM);
		$wrongCombination = "--rack --bladestore" if (defined $optBladeStore);
		$wrongCombination = "--rack --bladeinside" 
			if (defined $optBladeContent and $optBladeContent != 999);
		$wrongCombination = "--rack --chkstorage" if (defined $optChkStorage);
		$wrongCombination = "--rack --chkdrvmonitor" if (defined $optChkDrvMonitor);
		$wrongCombination = "--rack --chkupdate" if (defined $optChkUpdate);
	} # rackCDU
	if (defined $optBlade) {
		$wrongCombination = "--blade --chkcpuload" if (defined $optChkCpuLoadPerformance);
		$wrongCombination = "--blade --chkmemperf" if (defined $optChkMemoryPerformance);
		$wrongCombination = "--blade --chkfsperf" if (defined $optChkFileSystemPerformance);
		$wrongCombination = "--blade --chknetperf" if (defined $optChkNetworkPerformance);
		$wrongCombination = "--blade --chkstorage" if (defined $optChkStorage);
		$wrongCombination = "--blade --chkdrvmonitor" if (defined $optChkDrvMonitor);
		$wrongCombination = "--blade --chkupdate" if (defined $optChkUpdate);
	}
	if (defined $optSNMP) {
		$wrongCombination = "--snmp 3 ... and no SNMPv3 credentials (set user name)" 
			if ($optSNMP and $optSNMP == 3 and !$optUserName);
	}
	pod2usage({
		-msg     => "\n" . "Invalid argument combination \"$wrongCombination\"!" . "\n",
		-verbose => 0,
		-exitval => 3
	}) if ($wrongCombination);
	# after readin of options set defaults
	if ((!defined $optChkSystem) 
	and (!defined $optChkEnvironment) and (!defined $optChkPower)
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
		$optChkHardware = 999 if ($optPrimeQuest);
		# exotic values if somebody needs to see if an optchk was explizit set via argv or if this 
		# is default
		$setOverallStatus = 1;
	}
	if ((defined $optChkSystem) 
	and (!defined $optChkEnvironment) and (!defined $optChkPower)
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
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}
	$useDegree = 1 if (defined $optUseDegree and $optUseDegree);
  } #evaluateOptions

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

#################################################################################
#----------- PRIMEQUEST PSA-COM functions
our %psaStatusMap = (
                     0x00000000		=> 3,                           
                     0x10000000		=> 2,
                     0x01000000		=> 6,
                     0x00100000		=> 5,
                     0x00040000		=> 4,
                     0x00010000		=> 1,           
);
our @psaStatusText = (	undef,
	"unknown", "not-present", "ok", "degraded", "warning", "error",
);
our $psaAvailable = 0;
sub primequestPsaComManagementInfo {
	my $partID = shift;
	#--	partitionManagementInfo :	.1.3.6.1.4.1.211.1.31.1.2.100.7.5
	my $snmpOidManagementInfoGroup = '.1.3.6.1.4.1.211.1.31.1.2.' . $partID . '.7.5.'; #partitionManagementInfo
	my $snmpOidName		= $snmpOidManagementInfoGroup . '2.0'; #partitionName
	my $snmpOidHostName	= $snmpOidManagementInfoGroup . '3.0'; #hostName
	my $snmpOidManAddress2	= $snmpOidManagementInfoGroup . '10.0'; #partitionManagementAddress2

	if ($main::verbose >= 1 and !$main::verboseTable) {
		my $name = trySNMPget($snmpOidName, "partitionManagementInfo");
		my $hostname = trySNMPget($snmpOidHostName, "partitionManagementInfo");
		my $manAddress2 = trySNMPget($snmpOidManAddress2, "partitionManagementInfo");

		if ($name or $hostname or $manAddress2) {
			addTableHeader("v","Partition Management Info") if (!$psaAvailable);
			addStatusTopic("v",undef, "Partition", $partID);
			addKeyValue("v","Name", $name);
			addHostName("v",$hostname);
			addIP("v",$manAddress2);
			$variableVerboseMessage .= "\n";
			$psaAvailable = 1;
		}
	} #verbose
} #primequestPsaComManagementInfo
sub primequesPsaComPhysCompStatus {
	my $partID = shift;
	#--	physCompStatus :	.1.3.6.1.4.1.211.1.31.1.2.100.6.1
	my $snmpOidPhysCompStatusGroup = '.1.3.6.1.4.1.211.1.31.1.2.' . $partID . '.6.1.'; #physCompStatus
	my $snmpOidCpu		= $snmpOidPhysCompStatusGroup .	'1.0'; #cpuParTotalStatus
	my $snmpOidMem		= $snmpOidPhysCompStatusGroup .	'2.0'; #memoryParTotalStatus
	my $snmpOidPci		= $snmpOidPhysCompStatusGroup .	'3.0'; #pciFuncParTotalStatus
	my $snmpOidSysBoard	= $snmpOidPhysCompStatusGroup .	'4.0'; #systemBoardParTotalStatus
	my $snmpOidIoBoard	= $snmpOidPhysCompStatusGroup .	'5.0'; #ioBoardParTotalStatus
	my $snmpOidScsi		= $snmpOidPhysCompStatusGroup .	'6.0'; #scsiDevParTotalStatus

	# Remark: In tests only PCI and SCSI Status was printed

	if ($main::verbose >= 1 and !$main::verboseTable) {
		my $cpu = trySNMPget($snmpOidCpu, "partitionManagementInfo");
		my $mem = trySNMPget($snmpOidMem, "partitionManagementInfo");
		my $pci = trySNMPget($snmpOidPci, "partitionManagementInfo");
		my $sysBoard = trySNMPget($snmpOidSysBoard, "partitionManagementInfo");
		my $ioBoard = trySNMPget($snmpOidIoBoard, "partitionManagementInfo");
		my $scsi = trySNMPget($snmpOidScsi, "partitionManagementInfo");
		$sysBoard = undef if (defined $sysBoard and $sysBoard eq "NULL");
		if (defined $cpu or defined $mem or defined $pci or defined $sysBoard 
		or  defined $ioBoard or defined $scsi
		) {
			addStatusTopic("v",undef, "Partition", $partID);
			addComponentStatus("v","CPU", $psaStatusText[$psaStatusMap{$cpu}]) 
				if (defined $cpu);
			addComponentStatus("v","Memory", $psaStatusText[$psaStatusMap{$mem}]) 
				if (defined $mem);
			addComponentStatus("v","PCI", $psaStatusText[$psaStatusMap{$pci}]) 
				if (defined $pci);
			addComponentStatus("v","SystemBoard", $psaStatusText[$psaStatusMap{$sysBoard}]) 
				if (defined $sysBoard);
			addComponentStatus("v","IO-Board", $psaStatusText[$psaStatusMap{$ioBoard}]) 
				if (defined $ioBoard);
			addComponentStatus("v","SCSI", $psaStatusText[$psaStatusMap{$scsi}]) 
				if (defined $scsi);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primequesPsaComPhysCompStatus
sub primequestPsaComPhysicalCpuTable {
	my $partID = shift;
	#--	physicalCpuTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.1.1	
	my $snmpOidCpuTable = '.1.3.6.1.4.1.211.1.31.1.2.' . $partID . '.1.1.1.1.'; #physicalCpuTable (2 index)
	my $snmpOidName		= $snmpOidCpuTable . '3'; #phCpuPhysicalID
	my $snmpOidOldStatus	= $snmpOidCpuTable . '4'; #phCpuStatus - bits
	my $snmpOidStatus	= $snmpOidCpuTable . '6'; #phCpuPresentStatus - bits
		# ... in tests both status values were not present
	my @tableChecks = ( $snmpOidName, $snmpOidOldStatus, $snmpOidStatus);

	if ($main::verbose >= 2 and !$main::verboseTable) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 2);
		$variableVerboseMessage .= "  CPU Table:\n" if ($#snmpIDs > 0);
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			#my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			#my $oldstatus = $entries->{$snmpOidOldStatus . '.' . $snmpID};
			#my $bitStatus = undef;
			#$bitStatus = $oldstatus if (defined $oldstatus);
			#$bitStatus = $status if (!defined $bitStatus);
			#my $decimalstatus = undef;
			#$decimalstatus = $psaStatusMap{$bitStatus} if (defined $bitStatus);

			addStatusTopic("v",undef, "    CPU", $snmpID);
			addName("v",$name);
			#$variableVerboseMessage .= " Status=$psaStatusText[$decimalstatus]:" if (defined $decimalstatus);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primequestPsaComPhysicalCpuTable
sub primequestPsaComSystemBoardTable {
	my $partID = shift;
	#--	systemBoardTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.6.1
	my $snmpOidSystemBoardTable = '.1.3.6.1.4.1.211.1.31.1.2.' . $partID . '.1.6.1.1.'; #systemBoardTable (1 index)
	my $snmpOidId		= $snmpOidSystemBoardTable . '2'; #sbPhysicalID
	my $snmpOidModel	= $snmpOidSystemBoardTable . '10'; #sbModel
	my $snmpOidSerialNo	= $snmpOidSystemBoardTable . '11'; #sbSerialNo
	my @tableChecks = ( 
		$snmpOidId, $snmpOidModel, $snmpOidSerialNo,
	);
	if ($main::verbose >= 2 and !$main::verboseTable) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidId, 1);
		$variableVerboseMessage .= "  System Board Table:\n" if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
			my $id = $entries->{$snmpOidId . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerialNo . '.' . $snmpID};

			addStatusTopic("v",undef, "    SystemBoard", $snmpID);
			addSerialIDs("v",$serial, undef);
			addName("v",$id);
			addProductModel("v",undef, $model);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primequestPsaComSystemBoardTable
sub primequestPSACOM {
	#### Hint of ServerView OperationsManager: use partitionID 0-4 instead of '100'

	#PSA-COM-MIB.mib
	my $i = 0;
	if ($optChkSystem and !$main::verboseTable) {
		#addTableHeader("v","Partition Management Info");
		for ($i=0;$i<4;$i++) {
			primequestPsaComManagementInfo($i);
		}
		addMessage("v","* ATTENTION: No Partition Related Information available !\n")
			if (!$psaAvailable);
		if ($psaAvailable) {
			if ($main::verbose >= 3) { # in tests only PCI and SCSI status was shown
				addTableHeader("v","Partition Related Physical Component Status");
				for ($i=0;$i<4;$i++) {
					primequesPsaComPhysCompStatus($i);
				}
			}
			addTableHeader("v","Partition Related Physical Component Tables");
			for ($i=0;$i<4;$i++) {
				addStatusTopic("v",undef, "Partition", $i);
				$variableVerboseMessage .= "\n";
				primequestPsaComSystemBoardTable($i);
				primequestPsaComPhysicalCpuTable($i);
				
				#--	memoryModuleTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.2.1 id status ?	
				#--	scsiDeviceTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.3.1 status ?
				#--	diskSliceTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.3.2 perf ?
				#--	nicTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.4.1 perf ?
				#--	pciFunctionTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.5.1
				#--	iobTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.7.1
				#--	iobSlotTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.7.2
				#--	sduTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.8.1
				#--	sduControllerTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.8.2
				#--	sduFanTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.8.3
				#--	sduPsuTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.8.4
				#--	pciboxTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.9.1	no status
				#--	pciboxSlotTable :	.1.3.6.1.4.1.211.1.31.1.2.100.1.9.2	no real status
				#--	gspbTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.9.3	no status
				#--	sasuTable :		.1.3.6.1.4.1.211.1.31.1.2.100.1.9.4	no status
			}
		} #psaAvailable
	} #System
} #primequestPSACOM

#----------- PRIMEQUEST MMB-COM functions
our $pqTempStatus = undef;
our $pqFanStatus = undef;
our $pqPowerSupplyStatus = undef;
our $pqVoltageStatus = undef;
our $pqCPUStatus = undef;
our $pqMemoryStatus = undef;

# UnitIds
# 1 - Chassis
# 2-5 Partition
# 18 free-pool,
# 19-22 sb, 43-44 iou, 51-54 liou-div, 67-68 pci-box ,
# 118-125 fan-tray, 136-137 mmb,
# 143-144 gspb, 145-148 lgspb-dev, 149-152 sas-unit,
# 153-156 psu, 157 dvdb, 158-161 lpci-box

our @pqClassText = ( "none",
	"chassis", "partition", "free-pool", "sb", undef,
	undef, "iou", "iou-divided", "iou-nodivided", "pci-box",
	undef, undef, undef, undef, undef,
	undef, "fan-tray", undef, undef, "op-panel",
	"mmb", undef, undef, undef, undef,
	undef, undef, "gspb", "gspb-divided", "gspb-nodivided",
	"sas-unit", "psu", "dvdb", "lpci-box", "fan", 
	"du", "..unexpected..",
);
sub primequestStatusComponentTable {
	my $snmpOidOverallStatusArea = '.1.3.6.1.4.1.211.1.31.1.1.1.8.'; #status
	my %commonSystemCodeMap = (	1       =>      0,
					2       =>      1,
					3       =>      2,
					4       =>      2,
					5	=>	3,);
	my $snmpOidStatusTable = $snmpOidOverallStatusArea . '2.1.';#statusComponentTable
	my $snmpOidId			= $snmpOidStatusTable . '1'; #csUnitId
	my $snmpOidType			= $snmpOidStatusTable . '2'; #csType
	my $snmpOidValue		= $snmpOidStatusTable . '3'; #componentStatusValue
	my @tableChecks = ( 
		$snmpOidId, $snmpOidType, $snmpOidValue, 
	);
	my @cntCodes = ( -1, 0,0,0,0,0, );
	my @overallStatusText = ( "none", 
		"ok", "degraded", "error", "failed", "unknown", "..unexpected..",
	);
	my @typeText = ( "none", 
		"system-boot", "power", "temperatures", "fans", "power-supplies",
		"voltages", "cpus", "memory-modules", "total", "fan-redundancy", 
		"power-supply-redundancy", "..unexpected..",
	); 
	my $getInfos = 0;
	$getInfos = 1 if (($optChkSystem and !$main::verboseTable) or $main::verboseTable==821);
	if (!$main::verboseTable or $main::verboseTable==821) { # Chassis:
		#msg .= " - Chassis:" if ($optChkSystem and $optChkSystem == 999);
		addTopicInLine("m", "Chassis") if ($optChkSystem and $optChkSystem == 999);
		for (my $i=1;$i < 10 ;$i++) {
			my $value = trySNMPget($snmpOidValue . '.1.' . $i ,"StatusComponentTable");
			if (defined $value) {
				$value = 0 if ($value < 0);
				$value = 6 if ($value > 6);
				addComponentStatus("m",$typeText[$i], $overallStatusText[$value])
					if (($optChkSystem and $optChkSystem == 999)
					or  ($optChkEnvironment and ($i == 3 or $i == 4))
					or  ($optChkEnv_Fan and $i == 4)
					or  ($optChkEnv_Temp and $i == 3)
					or  ($optChkPower and ($i == 5))
					or  ($optChkHardware and ($i == 6 or $i == 7 or $i == 8))
					or  ($optChkVoltage and $i == 6)
					or  ($optChkCPU and $i == 7)
					or  ($optChkMemMod and $i == 8)
					);
				$pqTempStatus		= $commonSystemCodeMap{$value} if ($i == 3);
				$pqFanStatus		= $commonSystemCodeMap{$value} if ($i == 4);
				$pqPowerSupplyStatus	= $commonSystemCodeMap{$value} if ($i == 5);
				$pqVoltageStatus	= $commonSystemCodeMap{$value} if ($i == 6);
				$pqCPUStatus		= $commonSystemCodeMap{$value} if ($i == 7);
				$pqMemoryStatus		= $commonSystemCodeMap{$value} if ($i == 8);
			} # value
		} # for
	}
	if ($getInfos) { # partitions
		addTableHeader("v","StatusComponentTable - Partitions");
		for (my $unitID=2; $unitID < 6 ; $unitID++) { 
			my $nr = $unitID - 2;
			my $gotPartition = undef;
			for (my $i=1;$i < 10 ;$i++) { 
				my $value = trySNMPget($snmpOidValue . '.' . $unitID . '.' . $i ,"StatusComponentTable");
				if (defined $value and !defined $gotPartition) {
					$gotPartition = 1;
					addStatusTopic("v",undef, "Partition", $nr);
				}
				addComponentStatus("v",$typeText[$i], $overallStatusText[$value]) 
					if (defined $value);
				$cntCodes[$value]++ if (defined $value and $i == 9);
			}
			$variableVerboseMessage .= "\n" if $gotPartition;
		}
		addTopicInLine("m", "Partitions");
 		for (my $i=1;$i < 6;$i++) {
			addStatusCount("m", $overallStatusText[$i], $cntCodes[$i]);
  		}
	}
	if ($getInfos) { # system board
		@cntCodes = ( -1, 0,0,0,0,0, );
		addTableHeader("v","StatusComponentTable - SystemBoards");
		for (my $unitID=19; $unitID <= 22 ; $unitID++) { 
			my $nr = $unitID -19;
			my $gotSB = undef;
			
			for (my $i=1;$i < 10 ;$i++) { 
				my $value = trySNMPget($snmpOidValue . '.' . $unitID . '.' . $i ,"StatusComponentTable");
				if (defined $value and !defined $gotSB) {
					$gotSB = 1;
					addStatusTopic("v",undef, "SystemBoard", $nr);
				}
				addComponentStatus("v",$typeText[$i], $overallStatusText[$value]) 
					if (defined $value);
				$cntCodes[$value]++ if (defined $value and $i == 9);
			}
			$variableVerboseMessage .= "\n" if ($gotSB);
		}
		#msg .= " - SystemBoard:";
		addTopicInLine("m","SystemBoard");
 		for (my $i=1;$i < 6;$i++) {
 			#msg .= "-$overallStatusText[$i]($cntCodes[$i])"	
 			#	if ($cntCodes[$i]);
 			addStatusCount("m", $overallStatusText[$i], $cntCodes[$i]);
		}
	}	
	if ($main::verboseTable==821) { # needs to much time:
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidType, 2);

		addTableHeader("v","StatusComponentTable - Other Units");
		foreach my $snmpID (@snmpIDs) {
			my $unit = $entries->{$snmpOidId . '.' . $snmpID};
			my $status = $entries->{$snmpOidValue . '.' . $snmpID};
			my $type = $entries->{$snmpOidType . '.' . $snmpID};
			$type = 0 if (!defined $type or $type < 0);
			$type = 12 if ($type > 12);
			if ($type and $status and ($unit == 18 or $unit > 22)) {
				addComponentStatus("v","[$unit]-$typeText[$type]", 
					$overallStatusText[$status]);
			}
		}
		$variableVerboseMessage .= "\n";
	}
} #primequestStatusComponentTable
sub primequestUnitParentTable {
	my $snmpOidUnitParentTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.5.1.'; #unitParentTable
	my $snmpOidUnitId	= $snmpOidUnitParentTable . '1'; #pUnitId
	my $snmpOidParentNr	= $snmpOidUnitParentTable . '2'; #pParentNr
	my $snmpOidPClass	= $snmpOidUnitParentTable . '4'; #parentUnitClass
	my @tableChecks = (
		$snmpOidUnitId, $snmpOidParentNr, $snmpOidPClass, 
	);
	if ($main::verboseTable == 251) { #UnitParentTable
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidUnitId, 2);

		addTableHeader("v","Unit Parent Table");
		foreach my $snmpID (@snmpIDs) {
			my $unit = $entries->{$snmpOidUnitId . '.' . $snmpID};
			my $pnr = $entries->{$snmpOidParentNr . '.' . $snmpID};
			my $pclass = $entries->{$snmpOidPClass . '.' . $snmpID};
			$pclass = 0 if (!defined $pclass or $pclass <= 0);
			$pclass = 37 if ($pclass > 37);

			$variableVerboseMessage .= "$unit <--- $pnr";
			addKeyValue("v","Class", $pqClassText[$pclass]);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primequestUnitParentTable
sub primequestUnitChildTable {
	my $snmpOidUnitChildTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.6.1.'; #unitChildTable
	my $snmpOidUnitId	= $snmpOidUnitChildTable . '1'; #cUnitId
	my $snmpOidChildNr	= $snmpOidUnitChildTable . '2'; #cChildNr
	my $snmpOidCClass	= $snmpOidUnitChildTable . '4'; #childUnitClass
	my @tableChecks = (
		$snmpOidUnitId, $snmpOidChildNr, $snmpOidCClass, 
	);
	if ($main::verboseTable == 261) { #UnitChildTable
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidUnitId, 2);

		addTableHeader("v","Unit Child Table");
		foreach my $snmpID (@snmpIDs) {
			my $unit = $entries->{$snmpOidUnitId . '.' . $snmpID};
			my $cnr = $entries->{$snmpOidChildNr . '.' . $snmpID};
			my $cclass = $entries->{$snmpOidCClass . '.' . $snmpID};
			$cclass = 0 if (!defined $cclass or $cclass <= 0);
			$cclass = 37 if ($cclass > 37);

			$variableVerboseMessage .= "$unit ---> $cnr";
			addKeyValue("v","Class", $pqClassText[$cclass]);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primequestUnitChildTable
sub primequestUnitTable {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.3.1.'; #mmb sysinfo unitInformation unitTable
	my $snmpOidClass	= $snmpOidUnitTable .  '2'; #unitClass
	my $snmpOidDesignation	= $snmpOidUnitTable .  '4'; #unitDesignation
	my $snmpOidModel	= $snmpOidUnitTable .  '5'; #unitModelName
	my $snmpOidSerial	= $snmpOidUnitTable .  '7'; #unitSerialNumber
	my $snmpOidLocation	= $snmpOidUnitTable .  '8'; #unitLocation
	my $snmpOidContact	= $snmpOidUnitTable .  '9'; #unitContact
	my $snmpOidAdmURL	= $snmpOidUnitTable . '10'; #unitAdminURL
	my @tableChecks = (
		$snmpOidClass, $snmpOidDesignation, $snmpOidModel, $snmpOidSerial, 
		$snmpOidLocation, $snmpOidContact, $snmpOidAdmURL,
	);
	if ($main::verboseTable == 231) { # UnitTable - needs a lot of time
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidClass, 1);

		addTableHeader("v","Unit Table");
		foreach my $snmpID (@snmpIDs) {
			my $class = $entries->{$snmpOidClass . '.' . $snmpID};
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			my $location = $entries->{$snmpOidLocation . '.' . $snmpID};
			my $contact = $entries->{$snmpOidContact . '.' . $snmpID};
			my $admURL = $entries->{$snmpOidAdmURL . '.' . $snmpID};
			$class = 0 if (!defined $class or $class <= 0);
			$class = 37 if ($class > 37);

			addStatusTopic("v",undef, undef, $snmpID);
			addSerialIDs("v",$serial, undef);
			addKeyValue("v","Class", $pqClassText[$class]);
			addName("v",$designation);
			addLocationContact("v",$location, $contact);
			addAdminURL("v",$admURL);
			addProductModel("v",undef, $model);
			$variableVerboseMessage .= "\n";
		}
	}
} #primequestUnitTable
sub primequestUnitTableChassisSerialNumber {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.3.1.'; #mmb sysinfo unitInformation unitTable
	my $snmpOidSerial	= $snmpOidUnitTable .  '7'; #unitSerialNumber
	{ 
		my $serial = trySNMPget($snmpOidSerial . '.1' ,"unitSerialNumber-Chassis");
		$msg .= "-" if (!$optSystemInfo);
		addSerialIDs("m",$serial, undef) if ($optChkSystem and !$optSystemInfo);
		addSerialIDs("n",$serial, undef);
	}
} #primequestUnitTableChassisSerialNumber
sub primequestUnitTableChassis {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.3.1.'; #mmb sysinfo unitInformation unitTable
	my $snmpOidDesignation	= $snmpOidUnitTable .  '4'; #unitDesignation
	my $snmpOidModel	= $snmpOidUnitTable .  '5'; #unitModelName
	my $snmpOidSerial	= $snmpOidUnitTable .  '7'; #unitSerialNumber
	my $snmpOidLocation	= $snmpOidUnitTable .  '8'; #unitLocation
	my $snmpOidContact	= $snmpOidUnitTable .  '9'; #unitContact
	my $snmpOidAdmURL	= $snmpOidUnitTable . '10'; #unitAdminURL
	{
		my $getInfos = 0;
		my $verbose = 0;
		my $notify = 0;
		$verbose = 1 if ($main::verbose >= 1);
		$notify = 1 
			if (!$main::verbose and !$main::verboseTable and $exitCode and $exitCode < 3);
		$getInfos = 1 if ($verbose or $notify);
		if ($getInfos) {
			my $designation = trySNMPget($snmpOidDesignation . '.1' ,"unitDesignation-Chassis");
			my $model = trySNMPget($snmpOidModel . '.1' ,"unitModelName-Chassis");
			my $location = trySNMPget($snmpOidLocation . '.1' ,"unitLocation-Chassis");
			my $contact = trySNMPget($snmpOidContact . '.1' ,"unitContact-Chassis");
			my $admURL = trySNMPget($snmpOidAdmURL . '.1' ,"unitAdminURL-Chassis");
			{
				RFC1213sysinfoToLong();
				addAdminURL("n",$admURL);
				addProductModel("n",undef, $model);
				addKeyValue("n","Designation",$designation);
			}
		}
	} # opt System
} #primequestUnitTableChassis
sub primequestTemperatureSensorTable {
	my $snmpOidTemperatureSensorTable = '.1.3.6.1.4.1.211.1.31.1.1.1.5.1.1.'; #temperatureSensorTable (2)
	#my $snmpOidUnitId	= $snmpOidTemperatureSensorTable . '1'; #tempUnitId
	#	... UnitId is SB SystemBoard number
	my $snmpOidDesignation	= $snmpOidTemperatureSensorTable . '3'; #tempSensorDesignation
	my $snmpOidIndentifier	= $snmpOidTemperatureSensorTable . '4'; #tempSensorIdentifier
	my $snmpOidStatus	= $snmpOidTemperatureSensorTable . '5'; #tempSensorStatus
	my $snmpOidCurrent	= $snmpOidTemperatureSensorTable . '6'; #tempCurrentTemperature
	my $snmpOidWarning	= $snmpOidTemperatureSensorTable . '7'; #tempWarningLevel
	my $snmpOidCritical	= $snmpOidTemperatureSensorTable . '8'; #tempCriticalLevel
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidIndentifier, 
		$snmpOidStatus, $snmpOidCurrent, $snmpOidWarning, $snmpOidCritical, 
	);
	my @statusText = ( "none",
		"unknown", "not-available", "ok", undef , "failed",
		"temperature-warning", "temperature-critical", "..unexpected..",
	);
	if (($optChkEnvironment or $optChkEnv_Temp) and !$main::verboseTable) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Temperature Sensors");
		my $saveUnitId = undef;
		foreach my $snmpID (@snmpIDs) {
			my $triggerLongMessage = 0;
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $identifier = $entries->{$snmpOidIndentifier . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $current = $entries->{$snmpOidCurrent . '.' . $snmpID};
			my $warning = $entries->{$snmpOidWarning . '.' . $snmpID};
			my $critical = $entries->{$snmpOidCritical . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			$designation =~ s/_Temp\.//;
			my $name = $designation;
			$name = $identifier if ($identifier);
			$status = 0 if (!defined $status or $status < 0); # seen for Chassis Unit
			$status = 8 if ($status > 8 or $status == 4);

			if (($main::verbose < 2) 
			&&  ($pqTempStatus == 1 or $pqTempStatus == 2)
			&&  ($status >= 5)
			) { 
				$triggerLongMessage = 1;
			}
			addTemperatureToPerfdata($name, $current, $warning, $critical) 
				if (!$main::verboseTable);

			if (!$main::verboseTable) {
				addStatusTopic("v",$statusText[$status],
					"Sensor", $snmpID);
				addName("v",$name);
				addCelsius("v",$current, $warning, $critical);
				$variableVerboseMessage .= "\n";
			}
			if ($triggerLongMessage) { 
				addStatusTopic("l",$statusText[$status],
					"Sensor", $snmpID);
				addName("l",$name);
				addCelsius("l",$current, $warning, $critical);
				$longMessage .= "\n";
			}
		} # each sensor
	} # optChkEnvironment
} #primequestTemperatureSensorTable
sub primequestFanTable {
	my $snmpOidFanTable = '.1.3.6.1.4.1.211.1.31.1.1.1.5.2.1.'; #fanTable (2)
	my $snmpOidDesignation	= $snmpOidFanTable . '3'; #fanDesignation
	my $snmpOidIdentifier	= $snmpOidFanTable . '4'; #fanIdentifier
	my $snmpOidStatus	= $snmpOidFanTable . '5'; #fanStatus
	my $snmpOidSpeed	= $snmpOidFanTable . '6'; #fanCurrentSpeed
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidIdentifier, 
		$snmpOidStatus, $snmpOidSpeed, 
	);
	my @statusText = ( "none",
		"unknown", "disabled", "ok", "failed", "prefailed-predicted",
		"redundant-fan-failed", "not-manageable", "not-present", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (!$main::verbose and !$main::verboseTable and $pqFanStatus and $pqFanStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	$getInfos = 1 if ($optChkFanPerformance);
	if (($optChkEnvironment or $optChkEnv_Fan) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Fans") if ($verbose);
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $identifier = $entries->{$snmpOidIdentifier . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $speed = $entries->{$snmpOidSpeed . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			my $name = $designation;
			$name = $identifier if ($identifier);
			$status = 0 if (!defined $status or $status < 0);
			$status = 9 if ($status > 9);

			if ($verbose) {
				addStatusTopic("v",$statusText[$status], "Fan", $snmpID =~ m/(\d+)\.\d+/);
				addName("v",$name); 
				addKeyRpm("v","Speed", $speed);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and  ($status == 2 or $status == 4 or $status == 5 or $status == 6)
			) { 
				addStatusTopic("l",$statusText[$status], "Fan", $snmpID =~ m/(\d+)\.\d+/);
				addName("l",$name);
				addKeyRpm("l","Speed", $speed);
				$longMessage .= "\n";
			}
			if ($optChkFanPerformance) {
				addRpmToPerfdata($name, $speed, undef, undef);
			}
		} # each fan
	} #optChkEnvironment and verbose or error
} #primequestFanTable
sub primequestPowerSupplyTable {
	my $snmpOidPowerSupplyTable = '.1.3.6.1.4.1.211.1.31.1.1.1.6.2.1.'; #powerSupplyTable
	my $snmpOidDesignation	= $snmpOidPowerSupplyTable . '3'; #powerSupplyDesignation
	my $snmpOidIdentifier	= $snmpOidPowerSupplyTable . '4'; #powerSupplyIdentifier
	my $snmpOidStatus	= $snmpOidPowerSupplyTable . '5'; #powerSupplyStatus
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidIdentifier, 
		$snmpOidStatus,
	);
	my @statusText = ( "none",
		"unknown", "not-present", "ok", "failed", "ac-fail", 
		"dc-fail", "critical-temperature", "not-manageable", "predictive-fail", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (!$main::verbose and !$main::verboseTable 
		and $pqPowerSupplyStatus and $pqPowerSupplyStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if ($optChkPower and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Power Supplies") if ($verbose);
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $identifier = $entries->{$snmpOidIdentifier . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			my $name = $designation;
			$name = $identifier if ($identifier);
			$status = 0 if (!defined $status or $status < 0);
			$status = 10 if ($status > 10);

			if ($verbose) {
				addStatusTopic("v",$statusText[$status], "PSU", $snmpID =~ m/\d+\.(\d+)/);
				addName("v",$name);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and  ($status == 4 or $status == 5 or $status == 6 or $status == 7 or $status == 9)
			) { 
				addStatusTopic("l",$statusText[$status], "PSU", $snmpID =~ m/\d+\.(\d+)/);
				addName("l",$name);
				$longMessage .= "\n";
			}
		} # each power supply
	} #optChkPower and verbose or error
} #primequestPowerSupplyTable
sub primequestPowerMonitoringTable {
	my $snmpOidPowerMonitoringTable = '.1.3.6.1.4.1.211.1.31.1.1.1.4.5.1.'; #powerMonitoringTable
	my $snmpOidMax		= $snmpOidPowerMonitoringTable . '4.1'; #pmNominalPowerConsumption
	my $snmpOidCurrent	= $snmpOidPowerMonitoringTable . '5.1'; #pmCurrentPowerConsumption
	my $snmpOidCtrl1	= $snmpOidPowerMonitoringTable . '6.1'; #pmCurrentPowerControl
	# ... since Cassiopeia 2013
	my $snmpOidStatus	= $snmpOidPowerMonitoringTable . '7.1'; #pmPowerLimitStatus
	my $snmpOidMaxLimit	= $snmpOidPowerMonitoringTable . '8.1'; #pmPowerLimitThreshold
	my $snmpOidWarning	= $snmpOidPowerMonitoringTable . '9.1'; #pmPowerLimitWarning
	my $snmpOidCritical	= $snmpOidPowerMonitoringTable . '10.1'; #pmRedundancyCritLevel
	my $snmpOidCtrl2	= $snmpOidPowerMonitoringTable . '11.1'; #pmPowerControlMode
	my $snmpOidUnit		= $snmpOidPowerMonitoringTable . '12.1'; #pmPowerDisplayUnit
		# ... unknown(1) watt(2) btu(3)
	my @ctrlText = ( "none",
        	"unknown", "disabled", "best-performance", "minimum-power", "automatic",	"scheduled", "limited", "low-noise", "..unexpected..",
	);
	my @statusText = ("none",
		"unknown", "ok", "warning", "error", "disabled",
		"..unexpected..",
	);
	if ($optChkPower and !$main::verboseTable) {
		my $current	= trySNMPget($snmpOidCurrent);
		my $max		= trySNMPget($snmpOidMax);
		my $maxLimit	= trySNMPget($snmpOidMaxLimit);
		my $ctrl1	= trySNMPget($snmpOidCtrl1);
		my $ctrl2	= trySNMPget($snmpOidCtrl2);
		my $status	= trySNMPget($snmpOidStatus);
		my $warn	= trySNMPget($snmpOidWarning);
		my $critical	= trySNMPget($snmpOidCritical);
		my $unit	= trySNMPget($snmpOidUnit);
		$ctrl1 = 9 if (defined $ctrl1 and $ctrl1 > 9);
		$ctrl2 = 9 if (defined $ctrl2 and $ctrl2 > 9);
		my $ctrl = $ctrl1;
		$ctrl = $ctrl2 if (defined $ctrl2 and $ctrl2 > 0);
		$ctrl = undef if (defined $ctrl and $ctrl < 0);
		$status = undef if (defined $status and $status < 0);
		$status = 6 if (defined $status and $status > 6);
		my $statusText = undef;
		$statusText = $statusText[$status] if ($status);
		my $maxThreshold = $maxLimit;
		$maxThreshold = $critical if (defined $critical and $critical > 0);

		$PSConsumptionBTUH = 1 if (defined $unit and $unit == 3);

		#### TODO - enable -w, -c for PRIMEQUEST PowerConsumption if $max is defined
		# ... and newer parts are not available
		if (defined $current and $current != -1 and !$main::verboseTable) {
			addPowerConsumptionToPerfdata($current, 
				$warn, $maxThreshold, undef,$max);
		}
		if ($main::verbose >= 2) {
			addTableHeader("v","Power Consumption");
			addStatusTopic("v",$statusText,"PowerConsumption",undef);
			addKeyWatt("v","Current", $current,
				$warn, $critical, undef, $max);
			addKeyWatt("v","MaxLimit", $maxLimit,
				undef,undef, undef, undef);
			addKeyValue("v","Control", $ctrlText[$ctrl]) if ($ctrl);
			$variableVerboseMessage .= "\n"
		}
	} #optChkPower
} #primequestPowerMonitoringTable
sub primequestVoltageTable {
	# (1/100V)
	my $snmpOidVoltageTable = '.1.3.6.1.4.1.211.1.31.1.1.1.6.3.1.'; #voltageTable
	my $snmpOidDesignation	= $snmpOidVoltageTable . '3'; #voltageDesignation
	my $snmpOidStatus	= $snmpOidVoltageTable . '4'; #voltageStatus
	my $snmpOidCurrent	= $snmpOidVoltageTable . '5'; #voltageCurrentValue
	my $snmpOidMin		= $snmpOidVoltageTable . '7'; #voltageMinimumLevel
	my $snmpOidMax		= $snmpOidVoltageTable . '8'; #voltageMaximumLevel
	my @tableChecks = (
		$snmpOidDesignation, 
		$snmpOidStatus, $snmpOidCurrent, $snmpOidMin, $snmpOidMax,
	);
	my @statusText = ( "none", 
		"unknown", "not-available", "ok", "too-low", "too-high",
		"sensor-failed", "low-warning", "high-warning", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verboseTable == 631); # PQ VoltageTable
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (!$main::verbose and !$main::verboseTable and $pqVoltageStatus and $pqVoltageStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkHardware or $optChkVoltage) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Voltages")	if ($verbose);
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $current = $entries->{$snmpOidCurrent . '.' . $snmpID};
			my $min = $entries->{$snmpOidMin . '.' . $snmpID};
			my $max = $entries->{$snmpOidMax . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			my $name = $designation;
			$status = 0 if (!defined $status or $status < 0);
			$status = 9 if ($status > 9);

			#### TODO/QUESTION PRIMEQUEST Voltage and Performance -w -c ?

			if ($verbose) {
				addStatusTopic("v",$statusText[$status], "Voltage", $snmpID);
				addName("v",$name);
				addmVolt("v",$current,undef,undef,$min,$max);
				$variableVerboseMessage .= "\n";
			} 
			elsif ($notify and $status >= 4) { 
				addStatusTopic("l",$statusText[$status], "Voltage", $snmpID);
				addName("l",$name);
				addmVolt("l",$current,undef,undef,$min,$max);
				$longMessage .= "\n";
			}
		} # each power supply
	} #optChkHardware - verbose or error
} #primequestVoltageTable
sub primequestCpuTable {
	my $snmpOidCpuTable = '.1.3.6.1.4.1.211.1.31.1.1.1.6.4.1.'; #cpuTable
	my $snmpOidDesignation	= $snmpOidCpuTable . '3'; #cpuDesignation
	my $snmpOidStatus	= $snmpOidCpuTable . '4'; #cpuStatus
	my $snmpOidModel	= $snmpOidCpuTable . '5'; #cpuModelName
	my $snmpOidSpeed	= $snmpOidCpuTable . '8'; #cpuCurrentSpeed
	my @tableChecks = (
		$snmpOidDesignation, 
		$snmpOidStatus, $snmpOidModel, $snmpOidSpeed,
	);
	my @statusText = ( "none",
		"unknown", "not-present", "ok", "disabled", "error",
		"failed", "missing-termination", "prefailed-warning", "..unexpected..",
	);

	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verboseTable == 641); # PQ CPUTable
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (!$main::verbose and !$main::verboseTable and $pqCPUStatus and $pqCPUStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkHardware or $optChkCPU) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","CPU Table") if ($verbose);
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $speed = $entries->{$snmpOidSpeed . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			my $name = $designation;
			$status = 0 if (!defined $status or $status < 0);
			$status = 9 if ($status > 9);

			if ($verbose) {
				addStatusTopic("v",$statusText[$status],"CPU",$snmpID);
				addName("v",$name);
				addProductModel("v",undef, $model); 
				addKeyMHz("v","Speed", $speed);
				$variableVerboseMessage .= "\n";
			} elsif ($notify and $status >= 4) { 
				addStatusTopic("l",$statusText[$status],"CPU",$snmpID);
				addName("l",$name);
				addProductModel("l",undef, $model);
				addKeyMHz("l","Speed", $speed);
				$longMessage .= "\n";
			}
		} # each
	} # hardware 
} #primequestCpuTable
sub primequestMemoryModuleTable {
	my $snmpOidMemoryModuleTable = '.1.3.6.1.4.1.211.1.31.1.1.1.6.5.1.'; #memoryModuleTable
	my $snmpOidDesignation	= $snmpOidMemoryModuleTable . '3'; #memModuleDesignation
	my $snmpOidStatus	= $snmpOidMemoryModuleTable . '4'; #memModuleStatus
	my $snmpOidCapacity	= $snmpOidMemoryModuleTable . '6'; #memModuleCapacity MB
	my $snmpOidConfig	= $snmpOidMemoryModuleTable . '13'; #memModuleConfiguration
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidStatus, 
		$snmpOidCapacity, $snmpOidConfig,
	);
	my @statusText = ( "none",
		"unknown", "not-present", "ok", "failed-disabled", "error",
		"..unexpected..", "warning", "hot-spare", "configuration-error", "..unexpected..",
	);
	my @configText = ( "none",
		"unknown", "normal", "disabled", "hotSpare", "mirror",
		"raid", "notUsable", "..unexpected..",
	); 
	if ($main::verboseTable == 651) { # PQ - MemoryModuleTable - needs toooooo much time
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Memory Modules Table");
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $capacity = $entries->{$snmpOidCapacity . '.' . $snmpID};
			my $config = $entries->{$snmpOidConfig . '.' . $snmpID};
			$designation =~ s/[ ,;=]/_/g;
			my $name = $designation;
			$status = 0 if (!defined $status or $status < 0);
			$status = 10 if ($status > 10);
			$config = 0 if (!defined $config or $config < 0);
			$config = 8 if ($config > 8);

			if ($status != 2 or $main::verbose >= 3) { # not "not-present"
				addStatusTopic("v",$statusText[$status],"MemMod", $snmpID);
				addName("v",$name);
				addKeyValue("v","Config", $configText[$config]) if ($config);
				addKeyMB("v","Capacity", $capacity);
				$variableVerboseMessage .= "\n";
			}
		} # each
	} # hardware and this table
} #primequestMemoryModuleTable
sub primequestPerformanceTable {
	# ATTENTION: in the tests there was no data inside
	my $snmpOidPerformanceTable = '.1.3.6.1.4.1.211.1.31.1.1.1.4.3.1.'; #performanceTable (2)
	my $snmpOidType		= $snmpOidPerformanceTable . '3'; #perfType
	my $snmpOidValue	= $snmpOidPerformanceTable . '4'; #performanceValue
	my $snmpOidName		= $snmpOidPerformanceTable . '5'; #performanceName
	my @tableChecks = (
		$snmpOidType, $snmpOidValue, $snmpOidName,  
	);
	my @typeText = ( "none",
		"cpu", "cpu-overall", "pci-load", "pci-efficiency", "pci-transfer",
		"memory-physical", "memory-total", "memory-percent", "..unexpected..",
	);
        #            cpu:             Load of a single CPU in percent
        #            cpu-overall:     Overall CPU load in percent
        #            pci-load:        PCI bus load in percent
        #            pci-efficiency:  PCI bus efficiency in percent (100% is optimum)
        #            pci-transfer:    PCI bus transfer rate in MBytes/sec.
        #            memory-physical: Physical memory usage in MBytes
        #            memory-total:    Total memory usage (physical + virtual) in MBytes
        #            memory-percent:  Physical memory usage in percent"
	my $getInfos = 0;
	$getInfos = 1 if ($main::verbose >= 3 and $optChkHardware and !$main::verboseTable);
	$getInfos = 1 if ($optChkCpuLoadPerformance);
	$getInfos = 1 if ($optChkMemoryPerformance);
	my $totalCPU = undef;
	#my @cpu = (0,0,0,0,0, 0,0,0,0,0, -1,);
	my $virtualMemMBytes = undef;
	my $physMemPercent = undef;
	my $physMemMBytes = undef;
	if ($getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidType, 2);

		addTableHeader("v","Hardware Performance Values")
			if ($main::verbose >= 3);
		my $maxInd = 0;
		foreach my $id (@snmpIdx) {
 			my $type  = $entries->{$snmpOidType . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
			my $value = $entries->{$snmpOidValue . '.' . $id};
			$type = 0 if (!defined $type or $type < 0);
			$type = 9 if ($type > 9);
			if ($main::verbose >= 3 and !$main::verboseTable) {
				addStatusTopic("v",undef,$typeText[$type],undef);
				addName("v",$name);
				addKeyValue("v","Value", $value);
				if ($type and $type >= 5 and $type <= 7) {
					$variableVerboseMessage .= "MB";
				} else {
					$variableVerboseMessage .= "%";
				}
				$variableVerboseMessage .= "\n";
			} 
			if ($optChkCpuLoadPerformance and defined $value) {
				$totalCPU = $value if ($type == 2);
				#$cpu[$objNr]=$value if ($type == 1);
				#$maxInd = $objNr if ($objNr > $maxInd);
			}
			if ($optChkMemoryPerformance and defined $value) {
				$physMemMBytes = $value if ($type == 6);
				$virtualMemMBytes = $value if ($type == 7 and ($name =~ m/virtual/));
				$physMemPercent = $value if ($type == 8);
			}
		} # each
		#if ($maxInd) {
		#	$maxInd++;
		#	$cpu[$maxInd] = -1;
		#}
	} #verbose
	if ($optChkCpuLoadPerformance) {
		#msg			.= "Total=$totalCPU" . "%" if ($totalCPU);
		addKeyPercent("m", "Total", $totalCPU, undef,undef, undef,undef);
		addPercentageToPerfdata("Total", $totalCPU, undef, undef) if (!$main::verboseTable);
		#my $i = 0;
		#for ($i=0; $cpu[$i] != -1;$i++) {
		#	addPercentageToPerfdata("CPU[$i]", $cpu[$i], undef, undef);
		#} #each
		$exitCode = 0;
	} #cpu load
	if ($optChkMemoryPerformance) {
		my $warn = ($optWarningLimit?$optWarningLimit:0);
		my $crit = ($optCriticalLimit?$optCriticalLimit:0);
		$warn = undef if ($warn == 0);
		$crit = undef if ($crit == 0);
		#msg .= "Physical-Memory=$physMemPercent" . "% " if ($physMemPercent);
		addKeyPercent("m", "Physical-Memory", $physMemPercent, undef,undef, undef,undef);
		#msg .= "Physical-Memory=$physMemMBytes" . "MB " if ($physMemMBytes);
		addKeyMB("m","Physical-Memory", $physMemMBytes);
		#msg .= "Virtual-Memory=$virtualMemMBytes" . "MB " if ($virtualMemMBytes);
		addKeyMB("m","Virtual-Memory", $virtualMemMBytes);
		addPercentageToPerfdata("Physical-Memory", $physMemPercent, $warn, $crit) 
			if (!$main::verboseTable);
		$exitCode = 0;
		$exitCode = 1 if ($warn and $physMemPercent > $warn);
		$exitCode = 2 if ($crit and $physMemPercent > $crit);
	} #memory
} #primequestPerformanceTable
sub primequestManagementNodeTable {
	my $snmpOidManagementNodeTable = '.1.3.6.1.4.1.211.1.31.1.1.1.3.1.1.'; #managementNodeTable
	my $snmpOidAddress	= $snmpOidManagementNodeTable . '4'; #unitNodeAddress
	my $snmpOidName		= $snmpOidManagementNodeTable . '7'; #unitNodeName
	my $snmpOidClass	= $snmpOidManagementNodeTable . '8'; #unitNodeClass
	my $snmpOidMAC		= $snmpOidManagementNodeTable . '9'; #unitNodeMacAddress
	my @tableChecks = (
		$snmpOidAddress, $snmpOidName, 
		$snmpOidClass, $snmpOidMAC,
	);
	my @classText = ( "none",
		"unknown", "primery", "secondary", "management-blade", "secondary-remote",
		"secondary-remote-backup", "baseboard-controller", "secondary-management-blade", "..unknown..",
	);
	if ($main::verbose == 3 or $main::verboseTable == 311) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidAddress, 2);

		addTableHeader("v","Management Node Table");
		foreach my $snmpID (@snmpIDs) {
			my $address = $entries->{$snmpOidAddress . '.' . $snmpID};
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $class = $entries->{$snmpOidClass . '.' . $snmpID};
			my $mac = $entries->{$snmpOidMAC . '.' . $snmpID};
			$class = 0 if (!defined $class or $class < 0);
			$class = 9 if ($class > 9);
			{ 
				addStatusTopic("v",undef, "Node", $snmpID);
				addName("v",$name);
				addKeyValue("v","Address", $address);
				#addKeyValue("v","MAC", $mac);
				addMAC("v", $mac);
				addKeyValue("v","Class", $classText[$class]) if ($class);
				$variableVerboseMessage .= "\n";
			}
		} # each
	} # system and specific table
} #primequestManagementNodeTable
sub primequestServerTable {
	my $snmpOidServerTable = '.1.3.6.1.4.1.211.1.31.1.1.1.4.1.1.'; #serverTable
	my $snmpUnitID		= $snmpOidServerTable . '1'; #srvUnitId
	my $snmpOidBootStatus	= $snmpOidServerTable . '4'; #srvCurrentBootStatus
	my $snmpOidBootUUID	= $snmpOidServerTable . '7'; #srvUUID
	my $snmpOidManIP	= $snmpOidServerTable . '10'; #srvManagementIP
	my @tableChecks = (
		$snmpUnitID, $snmpOidBootStatus, $snmpOidBootUUID, 
		$snmpOidManIP,
	);
	my @bootText = ( "none",
		"unknown", "off", "no-boot-cpu", "self-test", "setup",
		"os-boot", "diagnostic-boot", "os-running", "diagnostic-running", "os-shutdown",
		"diagnostic-shutdown", "reset", "panic", "check-stop", "dumping", 
		"halt", "..unexpected..",
	);
	if ($main::verbose == 3 or $main::verboseTable == 411) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidBootStatus, 1);

		addTableHeader("v","Server Table");
		foreach my $snmpID (@snmpIDs) {
			my $unitid = $entries->{$snmpUnitID . '.' . $snmpID};
			my $bstatus = $entries->{$snmpOidBootStatus . '.' . $snmpID};
			my $uuid = $entries->{$snmpOidBootUUID . '.' . $snmpID};
			my $mip = $entries->{$snmpOidManIP . '.' . $snmpID};
			$bstatus = 0 if (!defined $bstatus or $bstatus < 0);
			$bstatus = 17 if ($bstatus > 17);
			{ 
				addStatusTopic("v",undef, "Server", $snmpID);
				addKeyIntValue("v","Partition",($unitid-2));
				addKeyValue("v","BootStatus",$bootText[$bstatus]) if ($bstatus);
				addKeyValue("v","ManagementIP",$mip);
				addKeyValue("v","UUID",$uuid);
				$variableVerboseMessage .= "\n";
			}
		} # each
	}
} #primequestServerTable
sub primequest {
	# MMB-COM-MIB.mib
	my $snmpOidPrimeQuestMMBSysInfo = '.1.3.6.1.4.1.211.1.31.1.1.1.'; # primequest - mmb - sysinfo
	my $snmpOidUnitInfo = $snmpOidPrimeQuestMMBSysInfo . '2.'; #unitInformation
	my $snmpOidLocalID	= $snmpOidUnitInfo . '1.0'; #localServerUnitId
	#my $snmpOidNumberUnits	= $snmpOidUnitInfo . '2.0'; #numberUnits

	my $snmpOidOverallStatusArea = $snmpOidPrimeQuestMMBSysInfo . '8.'; #status
	my $snmpOidStatus = $snmpOidOverallStatusArea . '1.0'; #agentStatus
	my %commonSystemCodeMap = (	1       =>      0,
					2       =>      1,
					3       =>      2,
					4       =>      2,
					5	=>	3,);
	my @overallStatusText = ( "none", "ok", "degraded", "error", "failed", "unknown",);

	my $localID = mibTestSNMPget($snmpOidLocalID,"PRIMEQUEST");
	my $allStatus = simpleSNMPget($snmpOidStatus,"agentStatus");
	$allStatus = 0 if (!defined $allStatus or $allStatus < 0 or $allStatus > 5);
	$exitCode = $commonSystemCodeMap{$allStatus};

	primequestUnitTableChassisSerialNumber();
	$msg .= " -" if ($optChkSystem);
	addKeyValue("m","All",$overallStatusText[$allStatus]) if ($optChkSystem);
	primequestStatusComponentTable();

	$exitCode = $pqTempStatus if (defined $pqTempStatus and 
		$optChkEnv_Temp and !defined $optChkEnv_Fan);
	$exitCode = $pqFanStatus if (defined $pqFanStatus and 
		$optChkEnv_Fan and !defined $optChkEnv_Temp);
	addExitCode($pqFanStatus) if ($optChkEnv_Temp and $optChkEnv_Fan);
	if ((defined $optChkEnvironment) && (!defined $optChkPower) && (!defined $optChkSystem)) {
		$exitCode = 3 if (!defined $pqTempStatus);
		$exitCode = $pqTempStatus if (defined $pqTempStatus);
		addExitCode($pqFanStatus);
	}
	if ((defined $optChkPower) && (!defined $optChkEnvironment) && (!defined $optChkSystem)) { 
		$exitCode = 3 if (!defined $pqPowerSupplyStatus);
		$exitCode = $pqPowerSupplyStatus if (defined $pqPowerSupplyStatus);
	}
	$exitCode = $pqCPUStatus if (defined $pqCPUStatus and 
		$optChkCPU and !defined $optChkVoltage and !defined $optChkMemMod);
	$exitCode = $pqVoltageStatus if (defined $pqVoltageStatus and 
		$optChkVoltage and !defined $optChkCPU and !defined $optChkMemMod);
	$exitCode = $pqMemoryStatus if (defined $pqMemoryStatus and 
		$optChkMemMod and !defined $optChkCPU and !defined $optChkVoltage);
	addExitCode($pqVoltageStatus) if ($optChkCPU and $optChkVoltage);
	addExitCode($pqMemoryStatus) if ($optChkMemMod and ($optChkCPU or $optChkVoltage));
	if ((defined $optChkHardware) 
	&& (!defined $optChkSystem) && (!defined $optChkEnvironment) && (!defined $optChkPower)) {
		$exitCode = 3 if (!defined $pqVoltageStatus);
		$exitCode = $pqVoltageStatus if (defined $pqVoltageStatus);
		addExitCode($pqCPUStatus);
		addExitCode($pqMemoryStatus);
	}
	if ((defined $optChkSystem) && (!defined $optChkEnvironment) && (!defined $optChkPower)) {
		$exitCode = $commonSystemCodeMap{$allStatus};
	}
	if (defined $optChkSystem and $commonSystemCodeMap{$allStatus}
	    and !$pqFanStatus and !$pqTempStatus and !$pqPowerSupplyStatus 
	    and !$pqCPUStatus and !$pqVoltageStatus and !$pqMemoryStatus) 
	{
		$longMessage .= "- Hint: Please check the status on the system itself or via administrative url - ";
	}

	primequestUnitTableChassis(); # search System information like Contact ...
	primequestUnitTable();
	primequestUnitParentTable();
	primequestUnitChildTable();
	primequestManagementNodeTable();
	primequestServerTable();
	primequestPSACOM();

	primequestTemperatureSensorTable();
	primequestFanTable();

	primequestPowerSupplyTable();
	primequestPowerMonitoringTable();

	primequestVoltageTable();
	primequestCpuTable();
	primequestMemoryModuleTable();
	primequestPerformanceTable();
} #primequest
#----------- PRIMERGY Blade - management blade functions
our $overallFan = 0;
our $overallTemp = 0;
our $overallPS = 0;
our @s31OverallStatusText = ( "none",
	"unknown", "ok", "degraded", "critical",
);
sub primergyManagementBladePowerSupply {
	my %bladeErrorCodeMap = (	0 => 3,
					1 => 3,
					2 => 0,
					3 => 1,
					4 => 2);
	my $snmpOidBladePSOverall	= '.1.3.6.1.4.1.7244.1.1.1.3.2.1.0'; #s31SysPowerSupplyStatus.0
	my $snmpOidBladePSTable		= '.1.3.6.1.4.1.7244.1.1.1.3.2.4.1.';#s31SysPowerSupplyUnitTable
	my $snmpOidStatus		= $snmpOidBladePSTable . '2'; #s31SysPowerSupplyUnitStatus
	my $snmpOidProduct		= $snmpOidBladePSTable . '4'; #s31SysPowerSupplyUnitProductName
	my $snmpOidModel		= $snmpOidBladePSTable . '5'; #s31SysPowerSupplyUnitModelName
	my $snmpOidSerial		= $snmpOidBladePSTable . '7'; #s31SysPowerSupplyUnitSerialNumber
	my @bladePSChecks = (
		$snmpOidStatus,
		$snmpOidProduct,
		$snmpOidModel,
		$snmpOidSerial,
	);
	my @bladePSStatusText = ( "none", 
		"unknown", "ok", "not-present", "warning", "critical",
		"off", "dummy", "fanmodule", "..unexpected..",
	);	
	if (defined $optChkPower) { 
		my $oPS = simpleSNMPget($snmpOidBladePSOverall,"PowerSupplyOverall");
		$oPS = 0 if (!defined $oPS or $oPS < 0 or $oPS > 4);
		$overallPS = $bladeErrorCodeMap{$oPS};
		#msg .= ' - PowerSupplies(' . $s31OverallStatusText[$oPS] . ')';
		addComponentStatus("m", "PowerSupplies", $s31OverallStatusText[$oPS]);

		if ((!defined $optChkEnvironment) && (!defined $optChkSystem)) {
		    $exitCode = $overallPS;
		}
		my $getinfos = 0;
		my $verbose = 0;
		my $notify = 0;
		$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
		$notify = 1 if (!$main::verbose and !$main::verboseTable and $overallPS and $overallPS < 3);
		$getinfos = 1 if ($verbose or $notify);
		if ($getinfos) {
			my $entries = getSNMPtable(\@bladePSChecks);
			my @snmpIDs = ();
			@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 1);

			addTableHeader("v","Power Supplies") if ($verbose);
			foreach my $snmpID (@snmpIDs) {
				my $psStatus = $entries->{$snmpOidStatus . '.' . $snmpID};
				my $psSerial = $entries->{$snmpOidSerial . '.' . $snmpID};
				my $psProduct = $entries->{$snmpOidProduct . '.' . $snmpID};
				my $psModel = $entries->{$snmpOidModel . '.' . $snmpID};
				$psStatus = 0 if (!defined $psStatus or $psStatus < 0);
				$psStatus = 9 if ($psStatus > 9);
				if ($verbose) {
					addStatusTopic("v",$bladePSStatusText[$psStatus],
						"PowerSupplyUnit", $snmpID);
					addSerialIDs("v",$psSerial, undef);
					addProductModel("v",$psProduct, $psModel);
					endVariableVerboseMessageLine();
				}
				elsif ($notify and ($psStatus == 4) or ($psStatus == 5)) {
					addStatusTopic("l",$bladePSStatusText[$psStatus],
						"PowerSupplyUnit", $snmpID);
					addSerialIDs("l",$psSerial, undef);
					addProductModel("l",$psProduct, $psModel);
					endLongMessageLine();
				}
			} # all ids
		} # verbose or error
	}
	chomp($msg);
} #primergyManagementBladePowerSupply
sub primergyManagementBladeEnvironment {
	my %bladeErrorCodeMap = (	0 => 3,
					1 => 3,
					2 => 0,
					3 => 1,
					4 => 2);
	my $snmpOidBladeFanOverall = '.1.3.6.1.4.1.7244.1.1.1.3.3.4.0'; #s31SysFanOverallStatus.0
	my $snmpOidBladeTempOverall = '.1.3.6.1.4.1.7244.1.1.1.3.4.2.0'; #s31SysTemperatureStatus.0

	my $snmpOidBladeFanPrefix = '.1.3.6.1.4.1.7244.1.1.1.3.3.1.1.'; #s31SysFanTable
	my $snmpOidBladeFanStatus = $snmpOidBladeFanPrefix . '2'; #s31SysFanStatus
	my $snmpOidBladeFanDesc = $snmpOidBladeFanPrefix . '3'; #s31SysFanDesignation - verbose
	my $snmpOidBladeFanSpeed = $snmpOidBladeFanPrefix . '4'; #s31SysFanCurrentSpeed
	my $snmpOidBladeFanIdent = $snmpOidBladeFanPrefix . '8'; #s31SysFanIdentification
        my @bladeFanChecks = (
		$snmpOidBladeFanStatus,
		$snmpOidBladeFanSpeed,
		$snmpOidBladeFanDesc
	);
	my @bladeFanStatus = ( "none",
		"unknown", "disabled", "ok", "fail", "prefailure-predicted",
		"redundant-fan-failed", "not-manageable", "not-present", "not-available", "..unexpected..",
	);

	my $snmpOidBladeTempPrefix = '.1.3.6.1.4.1.7244.1.1.1.3.4.1.1.'; #s31SysTemperatureSensorTable
	my $snmpOidBladeTempStatus = $snmpOidBladeTempPrefix . '2'; #s31SysTempSensorStatus
	my $snmpOidBladeTempWarn = $snmpOidBladeTempPrefix . '4'; #s31SysTempUpperWarningLevel
	my $snmpOidBladeTempCrit = $snmpOidBladeTempPrefix . '5'; #s31SysTempUpperCriticalLevel
	my $snmpOidBladeTempValue = $snmpOidBladeTempPrefix . '6'; #s31SysTempCurrentValue
	my $snmpOidBladeTempDesc = $snmpOidBladeTempPrefix . '3'; #s31SysTempSensorDesignation
	my @bladeTempChecks = (
		$snmpOidBladeTempStatus,
		$snmpOidBladeTempValue,
		$snmpOidBladeTempWarn,
		$snmpOidBladeTempCrit,
		$snmpOidBladeTempDesc
	);
	my @bladeTempStatus = ( "none",
		"unknown", "disable", "ok", "failed", "warning", 
		"critical", "not-available", "..unexpected..",
	);
	# get subsystem information
	if (defined $optChkEnvironment or $optChkEnv_Fan or $optChkEnv_Temp) { 
		if ($optChkEnvironment or $optChkEnv_Fan) {
			my $oFan = simpleSNMPget($snmpOidBladeFanOverall,"FanOverall");
			$oFan = 0 if (!defined $oFan or $oFan < 0 or $oFan > 4);
			$overallFan = $bladeErrorCodeMap{$oFan};
			#msg .= ' - Fans(' . $s31OverallStatusText[$oFan] . ')';
			addComponentStatus("m", "Fans", $s31OverallStatusText[$oFan]);
		}
		if ($optChkEnvironment or $optChkEnv_Temp) {
			my $oTemp = simpleSNMPget($snmpOidBladeTempOverall,"TemperaturOverall");
			$oTemp = 0 if (!defined $oTemp or $oTemp < 0 or $oTemp > 4);
			$overallTemp = $bladeErrorCodeMap{$oTemp};
			#msg .= ' - Temperatures(' . $s31OverallStatusText[$oTemp] . ')';
			addComponentStatus("m", "Temperatures", $s31OverallStatusText[$oTemp]);
		}

		if ($optChkEnvironment and (!defined $optChkPower) and (!defined $optChkSystem)) {
		    $exitCode = 3;
		    addExitCode($overallFan);
		    addExitCode($overallTemp);
		}
		addExitCode($overallFan) if ($optChkEnv_Fan and (!defined $optChkSystem));
		addExitCode($overallTemp) if ($optChkEnv_Temp and (!defined $optChkSystem));
	}
	chomp($msg);
	# process fan information
	my $getinfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (!$main::verbose and !$main::verboseTable and $overallFan and $overallFan < 3);
	$getinfos = 1 if ($verbose or $notify);
	$getinfos = 1 if ($optChkFanPerformance);
	if ((defined $optChkEnvironment or $optChkEnv_Fan) and $getinfos) { 
		my @snmpIDs = ();
		my $entries = getSNMPtable(\@bladeFanChecks);
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidBladeFanStatus, 1);

		addTableHeader("v","Fans") if ($verbose);
		foreach my $fanID (@snmpIDs) {
			my $fanStatus  = $entries->{$snmpOidBladeFanStatus . '.' . $fanID};
			$fanStatus = 0 if (!defined $fanStatus or $fanStatus < 0);
			$fanStatus = 10 if ($fanStatus > 10);
			next if (($fanStatus eq '9' or $fanStatus eq '2' or $fanStatus eq '8' or $fanStatus eq '7') and $main::verbose < 3);
			my $fanDesc = $entries->{$snmpOidBladeFanDesc . '.' . $fanID};
			my $fanSpeed = $entries->{$snmpOidBladeFanSpeed . '.' . $fanID};
			my $fanIdent = trySNMPget($snmpOidBladeFanIdent . '.' . $fanID ,
				"FanIdentification");
			$fanDesc =~ s/[ ,;=]/_/g;
			if (! defined $fanIdent) {
				$fanIdent = $fanDesc;
			}
			if ($verbose) {
				addStatusTopic("v",$bladeFanStatus[$fanStatus], "Fan", $fanID);
				addName("v",$fanIdent);
				addKeyRpm("v","Speed", $fanSpeed);
				$variableVerboseMessage .= "\n";
			} elsif ($notify and $fanStatus >= 4 and $fanStatus <= 6) {
				addStatusTopic("l",$bladeFanStatus[$fanStatus], "Fan", $fanID);
				addName("l",$fanIdent);
				addKeyRpm("l","Speed", $fanSpeed);
				endLongMessageLine();
			}
			if ($optChkFanPerformance) {
				addRpmToPerfdata($fanIdent, $fanSpeed, undef, undef);
			}
		} #each
	} # fan

	# process temperature information
	$notify = 0;
	$notify = 1 if (!$main::verbose and !$main::verboseTable and $overallTemp and $overallTemp < 3);
	if (($optChkEnvironment or $optChkEnv_Temp) and !$main::verboseTable) { 
		my @snmpIDs = ();
		my $entries = getSNMPtable(\@bladeTempChecks);
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidBladeTempStatus, 1);

		addTableHeader("v","Temperature Sensors");
		foreach my $tempID (@snmpIDs) {	
			my $tempStatus  = $entries->{$snmpOidBladeTempStatus . '.' . $tempID};
				# ... TemperaturSensorStatus !
			$tempStatus = 0 if (!defined $tempStatus or $tempStatus < 0);
			$tempStatus = 8 if ($tempStatus > 8);
			next if (($tempStatus eq '7' or $tempStatus eq '2') and $main::verbose < 3); 
			# skip if disabled or not available
			my $tempValue = $entries->{$snmpOidBladeTempValue . '.' . $tempID};
			my $tempWarn = $entries->{$snmpOidBladeTempWarn . '.' . $tempID};
			my $tempCrit = $entries->{$snmpOidBladeTempCrit . '.' . $tempID};
			my $tempDesc = $entries->{$snmpOidBladeTempDesc . '.' . $tempID};
			$tempDesc =~ s/[ ,;=]/_/g;
			
			addTemperatureToPerfdata($tempDesc, $tempValue, $tempWarn, $tempCrit)
				if (!$main::verboseTable);

			if ($verbose) {
				addStatusTopic("v",$bladeTempStatus[$tempStatus], "Sensor", $tempID);
				addName("v",$tempDesc);
				addCelsius("v",$tempValue, $tempWarn, $tempCrit);
				$variableVerboseMessage .= "\n";
			}
			if ($tempCrit > 0  and $tempValue >= $tempCrit) {
				$exitCode = 2;
			} elsif ($tempWarn > 0 and $tempValue >= $tempWarn) {
				$exitCode = 1 if ($exitCode != 2);
			} 
			if ($notify and ($tempStatus >=4 and $tempStatus <=6)) {
				addStatusTopic("l",$bladeTempStatus[$tempStatus], "Sensor", $tempID);
				addName("l",$tempDesc);
				addCelsius("l",$tempValue, $tempWarn, $tempCrit);
				endLongMessageLine();
			}
		} #each temp
	} # optChkEnvironment
} #primergyManagementBladeEnvironment
sub primergyManagementBladePowerConsumption {
	# ATTENTION - There are three index part in this table - one is a timestamp !
	my $snmpOidAgentDateTime	= '.1.3.6.1.4.1.7244.1.1.1.1.7.0'; #s31AgentDateTime
	my $snmpOidBladePowerConsumptionTable = '.1.3.6.1.4.1.7244.1.1.1.15.1.1.'; #s31UtilizationHistoryTable
	#my $snmpOidPowerUnitId		= $snmpOidBladePowerConsumptionTable . '1'; #s31uthUnitId
	#my $snmpOidPowerEntity		= $snmpOidBladePowerConsumptionTable . '2'; #s31uthEntity
	#my $snmpOidPowerTimeStamp	= $snmpOidBladePowerConsumptionTable . '3'; #s31uthTimeStamp
	#my $snmpOidPowerHwUUID		= $snmpOidBladePowerConsumptionTable . '4'; #s31uthHardwareUUID
	#	.1.3.6.1.4.1.7244.1.1.1.15.1.1.4.1.2.1110717600 --- XXXXXXXX
	my $snmpOidPowerAverage		= $snmpOidBladePowerConsumptionTable . '5'; #s31uthAverageValue
	my $snmpOidPowerMin		= $snmpOidBladePowerConsumptionTable . '6'; #s31uthMinValue
	my $snmpOidPowerMax		= $snmpOidBladePowerConsumptionTable . '7'; #s31uthMaxValue
	# Sample
	# .1.3.6.1.4.1.7244.1.1.1.15.1.1.3.1.1.1111363200 --- 1111363200

	# .1.3.6.1.4.1.7244.1.1.1.15.1.1.5.1.1.600 --- 1663 ???

	my @bladePowerChecks = ( #verbose
		$snmpOidPowerAverage,
	); 
	# get power consumption if enabled
	if (defined $optChkPower) { 
		my $chkAgentDateTime = trySNMPget($snmpOidAgentDateTime, "AgentDateTime");
		my $timeStamp = 0;
		my $nodeTimeStamp = 0;
		my $localTimeStamp = time();
		$timeStamp = $localTimeStamp;
		if (defined $chkAgentDateTime) {
			$chkAgentDateTime =~ m|(..)/(..)/(....) (..):(..):(..).*|;
			my $tmon = $1; 
			my $tday = $2; 
			my $tyear = $3;
			my $thour = $4; 
			my $tmin = $5; 
			my $tsec = $6;
			#print "****** $chkAgentDateTime => $tsec,$tmin,$thour,$tday,$tmon,$tyear \n";
			$nodeTimeStamp = timelocal($tsec,$tmin,$thour,$tday,$tmon-1,$tyear);
			# about $tmon - 1 see timelocal / localtime  description
			$timeStamp = $nodeTimeStamp;
		}
		#printf "local=$localTimeStamp, node=$nodeTimeStamp\n";
		$timeStamp =~ m/(.*)([0-9]{3})/;
		my $preSeconds = $1;
		my $lastSeconds = $2;
		my $chkSeconds = ($lastSeconds > 800?800
			:	 ($lastSeconds > 600?600
			:	 ($lastSeconds > 400?400
			:	 ($lastSeconds > 200?200:'000') ) ) );
		my $timeChk = "$preSeconds" . "$chkSeconds";
		my @chkPowerKeys = ();

		# In V1-V3.00 cout=10 for half an hour;
		for (my $pCount=0;$pCount<25;$pCount++) { # 200 seconds frequency	
			push(@chkPowerKeys, ($timeChk - ($pCount*200))) ;
			#push(@chkPowerKeys, ($timeChk - ($pCount*200))) ; # ?
			#push(@chkPowerKeys, ($timeChk - ($pCount*200))) ; # ?
		}

		if ($main::verbose > 98) { # for diagnostic only !!! this is slooooooooow
			my $entries = getSNMPtable(\@bladePowerChecks);
		}
		foreach my $pKey (@chkPowerKeys) {
			my $chkPowerAverage = undef;
			my $chkPowerAverage1 = trySNMPget($snmpOidPowerAverage . '.1.1.' . $pKey ,
				"PowerAverage");
			    # ... should be available all 10 Minutes
			my $chkPowerAverage2 = trySNMPget($snmpOidPowerAverage . '.1.2.' . $pKey ,
				"PowerAverage");
			    # ... should be available once per hour
			my $chkPowerAverage3 = trySNMPget($snmpOidPowerAverage . '.1.3.' . $pKey ,
				"PowerAverage");
			    # ... should be available once per day
			my $powerEntity = undef;
			my $frequenzyString = undef;
			if ((defined $chkPowerAverage1) && ($chkPowerAverage1 != 0)) {
				$chkPowerAverage = $chkPowerAverage1 ;
				$powerEntity = '.1.1.';
				$frequenzyString = "10minutes";
			}
			if ((!defined $chkPowerAverage) 
			&& (defined $chkPowerAverage2) && ($chkPowerAverage2 != 0)) 
			{
				$chkPowerAverage = $chkPowerAverage2;
				$powerEntity = '.1.2.';
				$frequenzyString = "hour";
			}
			if ((!defined $chkPowerAverage) 
			&& (defined $chkPowerAverage3) && ($chkPowerAverage2 != 0)) {
				$chkPowerAverage = $chkPowerAverage3;
				$powerEntity = '.1.3.';	
				$frequenzyString = "day";
			}
			if ((defined $chkPowerAverage) && ($chkPowerAverage != 0)) {
				addPowerConsumptionToPerfdata($chkPowerAverage, undef,undef, undef,undef)
					if (!$main::verboseTable);
				if ($main::verbose >= 2) {
					my $chkPowerMin 
						= trySNMPget($snmpOidPowerMin . $powerEntity . $pKey ,
						"PowerMin");
					my $chkPowerMax 
						= trySNMPget($snmpOidPowerMax . $powerEntity . $pKey ,
						"PowerMax");
					addTableHeader("v","Power Consumption");
					addStatusTopic("v","ok", "PowerConsumption", undef);
					addKeyValue("v","TimeStamp", $pKey);
					addKeyWatt("v","Average", $chkPowerAverage,
					    undef,undef, $chkPowerMin, $chkPowerMax);
					addKeyValue("v","AverageFrequenzy", $frequenzyString);
					$variableVerboseMessage .= "\n";
				}
				last;
			} #found
		} #try keys
	} #optChkPower
} #primergyManagementBladePowerConsumption
sub primergyManagementBlade_MgmtBladeTable {
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
	if ($main::verboseTable == 211 or $optAgentInfo) { # BLADE ManagementBlade
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidStatus, 1);
		addTableHeader("v","Management Blade Table");
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
			{ 
				addStatusTopic("v",$statusText[$status], "MMB", $snmpID);
				addSerialIDs("v",$serial, undef);
				addProductModel("v",$product,$model);
				addKeyValue("v", "FWVersion", $fw);
				addMAC("v", $mac);
				addKeyValue("v","RunMode",$modeText[$runmode]) if (defined $runmode);
				addMessage("v","\n");
			}
		} # each
		if ($version and $optAgentInfo) {
			addMessage("m", " -") if (!$msg);
			addKeyValue("m","Version",$version) if ($version !~ m/\s/);
			addKeyLongValue("m","Version",$version) if ($version =~ m/\s/);
			$main::verbose = 2 if ($main::verbose <= 2);
			addExitCode(0);
		} #found something
	}
} #primergyManagementBlade_MgmtBladeTable
sub primergyManagementBlade_ID {
	my $snmpOidBladeID = '.1.3.6.1.4.1.7244.1.1.1.3.5.1.0'; #s31SysChassisSerialNumber.0

	my $serverID = simpleSNMPget($snmpOidBladeID,"BladeID");
	addSerialIDs("n", $serverID, undef);
} #
sub primergyManagementBlade_AdminURL {
	my $snmpOidAgentInfo = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidBladeAdmURL	= $snmpOidAgentInfo . '5.0';#s31AgentAdministrativeUrl.0
	
	my $admURL = trySNMPget($snmpOidBladeAdmURL,"AgentAdminURL");
	addAdminURL("n",$admURL);
} #
sub primergyManagementBlade_ID_AdminURL {
	my $snmpOidBladeID = '.1.3.6.1.4.1.7244.1.1.1.3.5.1.0'; #s31SysChassisSerialNumber.0

	my $snmpOidAgentInfo = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidBladeAdmURL	= $snmpOidAgentInfo . '5.0';#s31AgentAdministrativeUrl.0
	
	my $serverID = simpleSNMPget($snmpOidBladeID,"BladeID");
	my $admURL = trySNMPget($snmpOidBladeAdmURL,"AgentAdminURL");
	addSerialIDs("n", $serverID, undef);
	addAdminURL("n",$admURL);
} #primergyManagementBlade_ID_AdminURL
sub primergyManagementBladeNotifyData {
	primergyManagementBlade_ID();
	RFC1213sysinfoToLong();
	primergyManagementBlade_AdminURL();
}
sub primergyManagementBlade {
	############# 
	my %bladeErrorCodeMap = (	0 => 3,
					1 => 3,
					2 => 0,
					3 => 1,
					4 => 2);

	my $snmpOidBladeStatus = '.1.3.6.1.4.1.7244.1.1.1.3.1.5.0'; #s31SysCtrlOverallStatus.0
	my $snmpOidBladeID = '.1.3.6.1.4.1.7244.1.1.1.3.5.1.0'; #s31SysChassisSerialNumber.0
	my $snmpOidS31Test = $snmpOidBladeID;

	my $snmpOidBladeCtrlOverall = '.1.3.6.1.4.1.7244.1.1.1.3.1.5.0'; #s31SysCtrlOverallStatus.0
	my $snmpOidAgentInfo = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidBladeAdmURL	= $snmpOidAgentInfo . '5.0';#s31AgentAdministrativeUrl.0
	#my $snmpOidAgentName	= $snmpOidAgentInfo . '9.0';#s31AgentName.0 ... see RFC1213

	#------------------------------------------------------
	mibTestSNMPget($snmpOidS31Test,"PRIMERGY Blade");
	# get overall status
	my $bladestatus = simpleSNMPget($snmpOidBladeStatus,"BladeStatus");
	$bladestatus = 0 if (!defined $bladestatus or $bladestatus < 0 or $bladestatus > 4);
	$exitCode = $bladeErrorCodeMap{$bladestatus} if ($optChkSystem);

	# get ServerID
	{ 
		$serverID = simpleSNMPget($snmpOidBladeID,"BladeID");
		$msg .= " -";
		#msg .= " - ID=" . $serverID;
		addSerialIDs("m", $serverID, undef) if (defined $optChkSystem);
		addSerialIDs("n", $serverID, undef);
	}
	#### TEXT LANGUAGE AWARENESS
	# get subsystem information
	$msg .= " -";

	primergyManagementBladeEnvironment();

	primergyManagementBladePowerSupply();

	# get power consumption if enabled
	primergyManagementBladePowerConsumption();
	
	if ($exitCode == 1 or $exitCode == 2 or $main::verbose >= 1) {
		my $admURL = trySNMPget($snmpOidBladeAdmURL,"AgentAdminURL");
		RFC1213sysinfoToLong();
		addAdminURL("n",$admURL);
	}
	if (defined $optChkSystem) { 
		if (($main::verbose >= 1)
		||  (  (($exitCode == 1) || ($exitCode == 2)) 
		    && ($overallFan < $exitCode) && ($overallTemp < $exitCode) && ($overallPS < $exitCode)
		    )
		) {
			my $oCtrl = simpleSNMPget($snmpOidBladeCtrlOverall,"ControlOverall");
			$oCtrl = 0 if (!defined $oCtrl or $oCtrl < 0 or $oCtrl > 4);
			my $overallCtrl = $bladeErrorCodeMap{$oCtrl};
			#msg .= ' - SystemControl(' . $s31OverallStatusText[$oCtrl] . ')';
			addComponentStatus("m","SystemControl",$s31OverallStatusText[$oCtrl]);
			$longMessage .= "- Hint: Please check the status on the system itself or via administrative url - "
				if (($exitCode == 1 or $exitCode == 2)
				and !$overallFan and !$overallTemp and !$overallPS);
			#addKeyLongValue("l","\tHint","Please check status information via Administrative Url")
			if ((($exitCode == 1) || ($exitCode == 2))
			&& ($overallCtrl == 0)
			) {
				#msg .= ' - BladesInside(' . $state[$exitCode] . ')'; 
				# never reached point
				addComponentStatus("m","BladesInside",$state[$exitCode]);
			}
		} # verbose or search-not-ok
	} #optChkSystem

	primergyManagementBlade_MgmtBladeTable();
} # end primergyManagementBlade

#----------- PRIMERGY Blade - sub blade functions
sub primergyFSIOMBlade {
	my $snmpOidBladeFsiom		= '.1.3.6.1.4.1.7244.1.1.1.3.8.'; #s31SysFsiom
	my $snmpOidState		= $snmpOidBladeFsiom . '1.0'; #s31SysFsiomStatus.0 
	my $snmpOidProduct		= $snmpOidBladeFsiom . '3.0'; #s31SysFsiomProductName.0
	my $snmpOidSerial		= $snmpOidBladeFsiom . '5.0'; #s31SysFsiomSerialNumber.0
	my $snmpOidModel		= $snmpOidBladeFsiom . '9.0'; #s31SysFsiomModelName.0
	# '7.0' s31SysFsiomConnectionStatus
	# '8,0' s31SysFsiomConnectionTarget
	# unknown(1), ok(2), not-present(3), error(4), critical(5)
	my %bladeFsiomErrorCodeMap = (	0 => 3,
					1 => 3,
					2 => 0,
					3 => 3,
					4 => 1,
					5 => 2);
	my @statusText = ("none",
		"unknown", "ok", "not-present", "error", "critical",
		"..unexpected..",
	);
	my $overallFsiom = undef;
	my $tmpOverallFsiom = trySNMPget($snmpOidState,"FsiomOverall");
	$tmpOverallFsiom = 0 if (!defined $tmpOverallFsiom or $tmpOverallFsiom < 0 or $tmpOverallFsiom > 5);
	if ($tmpOverallFsiom) {
		$overallFsiom = $bladeFsiomErrorCodeMap{$tmpOverallFsiom};
	}
	if (($tmpOverallFsiom) && $overallFsiom != 3) { # not "not-present" or "unknown"
		#msg .= ' FSIOM(' . $statusText[$tmpOverallFsiom] . ')';
		addComponentStatus("m","FSIOM", $statusText[$tmpOverallFsiom]);
	}
	# return code
	if (defined $overallFsiom ) {
		my $serial = undef;
		my $product = undef;
		my $model = undef;
		my $getinfos = 0;
		my $verbose = 0;
		my $notify = 0;
		$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
		$notify = 1 if ($overallFsiom == 5 or $overallFsiom == 4);
		$getinfos = 1 if ($verbose or $notify);
		if ($getinfos) {
			$serial = trySNMPget($snmpOidSerial,"FsiomSerialNumber");
			$product = trySNMPget($snmpOidProduct,"FsiomProduct");
			$model = trySNMPget($snmpOidModel,"FsiomModel");
		}
		if ($verbose) {
			addStatusTopic("v",$statusText[$tmpOverallFsiom], "FSIOM", undef);
			addSerialIDs("v",$serial, undef);
			addProductModel("v",$product, $model);
			endVariableVerboseMessageLine();
		}
		elsif ($notify) {
			addStatusTopic("l",$statusText[$tmpOverallFsiom], "FSIOM", undef);
			addSerialIDs("l",$serial, undef);
			addProductModel("l",$product, $model);
			endLongMessageLine();
		}
		# return codes
		$exitCode = 0 if ($exitCode == 3);# reset default
		if (($overallFsiom == 4) && ($exitCode < 1)) { #nagios warning 
			$exitCode = 1;
		}
		if (($overallFsiom == 5) && ($exitCode < 2)) { #nagios critical 
			$exitCode = 2;
		}
	}
} #end primergyFSIOMBlade
sub primergyServerBlades {
	############# 
	my $snmpOidSrvBlade	= '.1.3.6.1.4.1.7244.1.1.1.4.'; #s31ServerBlade

	my $snmpOidSrvCtrlTable	= $snmpOidSrvBlade . '1.1.1.'; #s31SvrCtrlTable
	my $snmpOidAdmURL	= $snmpOidSrvCtrlTable . '4'; #s31SvrCtrlAdministrativeUrl.<id>

	my $snmpOidSrvBladeTable = $snmpOidSrvBlade . '2.1.1.'; #s31SvrBladeTable
	my $snmpOidStatus		= $snmpOidSrvBladeTable . '2'; #s31SvrBladeStatus
	my $snmpOidSerial		= $snmpOidSrvBladeTable . '5'; #s31SvrBladeSerialNumber
	my $snmpOidProduct		= $snmpOidSrvBladeTable . '6'; #s31SvrBladeProductName
	my $snmpOidModel		= $snmpOidSrvBladeTable . '7'; #s31SvrBladeModelName
	my $snmpOidIDSerial		= $snmpOidSrvBladeTable . '17'; #s31SvrBladeIdentSerialNumber
	my $snmpOidHostName		= $snmpOidSrvBladeTable . '21'; #s31SvrHostname
	#s31SvrBladeCustomerProductName 22
	my @bladeSrvBladeTableChecks = (
		$snmpOidStatus,
		$snmpOidSerial,
		$snmpOidProduct,
		$snmpOidModel,
		$snmpOidIDSerial,
		$snmpOidHostName,
	);
	my @cntSrvBladesCodes = ( -1, 0,0,0,0,0,0, 0 );
	my @verboseSrvBladeStatusText = ( "none", 
		"unknown","ok","not-present","error","critical",
		"standby", "..unexpected..",
	);

	my $snmpOidSrvNicInfoTable = $snmpOidSrvBlade . '7.1.1.'; #s31SvrNicInfoTable
	my $snmpOidNICPhyAddress	= $snmpOidSrvNicInfoTable . '3'; #s31SvrNicPhysicalAddress
	my $snmpOidNICIP		= $snmpOidSrvNicInfoTable . '4'; #s31SvrNicIpAddress
	my $snmpOidNICType		= $snmpOidSrvNicInfoTable . '6'; #s31SvrNicType
	my @nicInfoTableChecks = (
		$snmpOidNICPhyAddress, $snmpOidNICIP, $snmpOidNICType,
	);
	my @nicInfoTypeText = ( "none",
		"unknown", "on-board-lan-controller", "daughter-card", "baseboard-management-controller", "..unexpected..",
	);
		
	#------------------------------------------------------

	my $srvBladesData = getSNMPtable(\@bladeSrvBladeTableChecks);

	my $snmpKey = undef;
	my @listOfErrorServer = ();

	my $verbose = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	if (defined $srvBladesData) {
		my @srvBladesEntries = ();
		@srvBladesEntries = getSNMPTableIndex($srvBladesData, $snmpOidStatus, 1);

		addTableHeader("v","Server Blades") if ($verbose);
		foreach my $srvID (@srvBladesEntries) {
			my $srvStatus  = $srvBladesData->{$snmpOidStatus . '.' . $srvID};
			my $srvHostNm = $srvBladesData->{$snmpOidHostName . '.' . $srvID};
			my $serial = $srvBladesData->{$snmpOidSerial . '.' . $srvID};
			my $IDserial = $srvBladesData->{$snmpOidIDSerial . '.' . $srvID};
			my $product = $srvBladesData->{$snmpOidProduct . '.' . $srvID};
			my $model = $srvBladesData->{$snmpOidModel . '.' . $srvID};
			$srvStatus = 0 if (!defined $srvStatus or $srvStatus < 0);
			$srvStatus = 7 if ($srvStatus > 7);

			my $admURL = trySNMPget($snmpOidAdmURL . '.' . $srvID,"SrvBlade-AdminURL");
			if ((defined $admURL) && ($admURL !~ m/http/)) {
			    $admURL = undef;
			}
			if ($verbose) {
				addStatusTopic("v",$verboseSrvBladeStatusText[$srvStatus],"Server", $srvID);
				addSerialIDs("v",$serial, $IDserial);
				addHostName("v",$srvHostNm);
				addAdminURL("v",$admURL);
				addProductModel("v",$product, $model);
				endVariableVerboseMessageLine();
			}
			$cntSrvBladesCodes[$srvStatus]++ if ($srvStatus and $srvStatus != 7);
			if (($srvStatus == 4 or $srvStatus == 5) and !$verbose ) {
				addStatusTopic("l",$verboseSrvBladeStatusText[$srvStatus], 
					"Server", $srvID);
				addSerialIDs("l",$serial, $IDserial);
				addHostName("l",$srvHostNm);
				addAdminURL("l",$admURL);
				addProductModel("l",$product, $model);
				endLongMessageLine();
				push(@listOfErrorServer, $srvID);
			}
		}
		# output
		#msg .= " Server";
		addTopicStatusCount("m", "Server");
		for (my $i=1;$i < 7;$i++) {
			#msg .= "-$verboseSrvBladeStatusText[$i]($cntSrvBladesCodes[$i])"	
			#	if ($cntSrvBladesCodes[$i]);
			addStatusCount("m", $verboseSrvBladeStatusText[$i], $cntSrvBladesCodes[$i]);
		}
		# return code
		if (($exitCode == 3) 
		&& (  $cntSrvBladesCodes[2] || $cntSrvBladesCodes[3] || $cntSrvBladesCodes[4]
		   || $cntSrvBladesCodes[5] || $cntSrvBladesCodes[6])
		) { # reset default
		    $exitCode = 0;
		}
		if ($cntSrvBladesCodes[4] && $exitCode < 1) { #nagios warning 
			$exitCode = 1;
		}
		if ($cntSrvBladesCodes[5] && $exitCode < 2) { #nagios critical 
			$exitCode = 2;
		}
	} elsif (defined $optBladeSrv and $optBladeSrv != 999) {
		$msg .= "-No ServerBlades- ";
	}
	# NIC
	if (defined $srvBladesData and ($verbose or $#listOfErrorServer >= 0)) {
		my $nicInfoEntries = getSNMPtable(\@nicInfoTableChecks);
		my @snmpKeys = ();
		@snmpKeys = getSNMPTableIndex($nicInfoEntries, $snmpOidNICIP, 2);
		my $saveSrvId = 0;
		my $foundSrvID = 0;
		addTableHeader("v","Server Blade NIC Table") if ($verbose);
		foreach my $snmpID (@snmpKeys) {
			my $phyAddress  = $nicInfoEntries->{$snmpOidNICPhyAddress . '.' . $snmpID};
			my $ip  = $nicInfoEntries->{$snmpOidNICIP . '.' . $snmpID};
			my $type  = $nicInfoEntries->{$snmpOidNICType . '.' . $snmpID};
			$ip = undef if ($ip and $ip =~ m/0\.0\.0\.0/);
			$snmpID =~ m/(.*)\.(.*)/;
			$type = 0 if (!defined $type or $type < 0);
			$type = 5 if ($type > 5);
			my $srvID = $1;
			my $nicIndex = $2;
			if ($saveSrvId != $srvID and $#listOfErrorServer >= 0) {
				$foundSrvID = 0;
				foreach my $chkid (@listOfErrorServer) {
					$foundSrvID = 1 if ($chkid == $srvID);
				}
			}
			if (defined $ip or $nicIndex == 1) {
				addStatusTopic("v",undef,"ServerNicInfo", $snmpID);
				#addKeyValue("v","PhysicalAddress", $phyAddress);
				addMAC("v", $phyAddress);
				addIP("v",$ip);
				addKeyValue("v","Type",$nicInfoTypeText[$type]) if ($type);
				$variableVerboseMessage .= "\n";
			}
			if (!$verbose and $foundSrvID and $ip) {
				addStatusTopic("l",undef,"ServerNicInfo", $snmpID);
				#addKeyValue("l","PhysicalAddress", $phyAddress);
				addMAC("l", $phyAddress);
				addIP("l",$ip);
				addKeyValue("l","Type",$nicInfoTypeText[$type]) if ($type);
				$longMessage .= "\n";
			}
			$saveSrvId = $srvID;
		}
	} #verbose
	chomp($msg);
} # end primergyServerBlades
sub primergySwitchBlades {
	############# 
	my $snmpOidSwBladeTable = '.1.3.6.1.4.1.7244.1.1.1.5.1.1.'; #s31SwitchBladeTable
	my $snmpOidStatus		= $snmpOidSwBladeTable . '2'; #s31SwitchBladeStatus
	my $snmpOidSerial		= $snmpOidSwBladeTable . '5'; #s31SwitchBladeSerialNumber
	my $snmpOidProduct		= $snmpOidSwBladeTable . '6'; #s31SwitchBladeProductName
	my $snmpOidModel		= $snmpOidSwBladeTable . '7'; #s31SwitchBladeModelName
	my $snmpOidIPAddr		= $snmpOidSwBladeTable . '10'; #s31SwitchBladeIpAddress
	#my $snmpOidAdmURL		= $snmpOidSwBladeTable . '11'; #s31SwitchBladeAdministrativeUrl
	# ... similar to IP
	my $snmpOidAssignedName		= $snmpOidSwBladeTable . '28'; #s31SwitchBladeUserAssignedName
	my $snmpOidIDSerial		= $snmpOidSwBladeTable . '29'; #s31SwitchBladeIdentSerialNumber
		# ATTENTION - IdentSerialNumber might be not available !
	my @bladeSwBladeTableChecks = (
		$snmpOidStatus,
		$snmpOidSerial,
		$snmpOidProduct,
		$snmpOidModel,
		$snmpOidIPAddr,
		$snmpOidAssignedName,
	);
	my @cntSwBladesCodes = ( -1, 0,0,0,0,0,0,0, 0,);
	my @verboseSwBladeStatusText = ( "none", 
		"unknown","ok","not-present","error","critical",
		"standby","present", "..unexpected..",
	);

	#------------------------------------------------------

	my $swBladesData = getSNMPtable(\@bladeSwBladeTableChecks);

	if (defined $swBladesData) {
		my @swBladesKeys = ();
		@swBladesKeys = getSNMPTableIndex($swBladesData, $snmpOidStatus, 1);

		my $verbose = 0;
		$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
		addTableHeader("v","Switch Blades") if ($verbose);
		foreach my $swID (@swBladesKeys) {
			my $swStatus  = $swBladesData->{$snmpOidStatus . '.' . $swID};
 			my $swIP = $swBladesData->{$snmpOidIPAddr . '.' . $swID};
 			my $serial = $swBladesData->{$snmpOidSerial . '.' . $swID};
 			my $product = $swBladesData->{$snmpOidProduct . '.' . $swID};
 			my $model = $swBladesData->{$snmpOidModel . '.' . $swID};
 			my $swUserName = $swBladesData->{$snmpOidAssignedName . '.' . $swID};
			my $IDserial = trySNMPget($snmpOidIDSerial . '.' . $swID,"IndentSerialNumber");
			$swStatus = 0 if (!defined $swStatus or $swStatus < 0);
			$swStatus = 8 if ($swStatus > 8);
			if ($verbose) {
				addStatusTopic("v",$verboseSwBladeStatusText[$swStatus], "Switch", $swID);
				addSerialIDs("v",$serial, $IDserial);
				addIP("v",$swIP);
				addName("v",$swUserName);
				addProductModel("v",$product, $model);
				endVariableVerboseMessageLine();
			}
			$cntSwBladesCodes[$swStatus]++ if ($swStatus);
			if ((($swStatus == 4) || ($swStatus == 5)) &&  !$verbose ) {
				addStatusTopic("l",$verboseSwBladeStatusText[$swStatus], 
					"Switch", $swID);
				addSerialIDs("l",$serial, $IDserial);
				addIP("l",$swIP);
				addName("l",$swUserName);
				addProductModel("l",$product, $model);
				endLongMessageLine();
			}
		}
		# output
		#msg .= " Switch";
		addTopicStatusCount("m", "Switch");
		for (my $i=1;$i < 8;$i++) {
			#msg .= "-$verboseSwBladeStatusText[$i]($cntSwBladesCodes[$i])"	
			#	if ($cntSwBladesCodes[$i]);
			addStatusCount("m", $verboseSwBladeStatusText[$i], $cntSwBladesCodes[$i]);
		}
		# return code
		if (($exitCode == 3) 
		&& (  $cntSwBladesCodes[2] || $cntSwBladesCodes[3] || $cntSwBladesCodes[4]
		   || $cntSwBladesCodes[5] || $cntSwBladesCodes[6] || $cntSwBladesCodes[7])
		) { # reset default
		    $exitCode = 0;
		}
		if ($cntSwBladesCodes[4] && $exitCode < 1) { #nagios warning 
			$exitCode = 1;
		}
		if ($cntSwBladesCodes[5] && $exitCode < 2) { #nagios critical 
			$exitCode = 2;
		}
	} elsif (defined $optBladeIO_Switch) {
		$msg .= "-No Switch Blades- ";
	}

	chomp($msg);
} # end primergySwitchBlades
sub primergyFiberChannelPassThroughBlades { # TODO - Blades with primergyFiberChannelPassThroughBlades
	############# 
	my $snmpOIDFcPTVoltageTable = '1.3.6.1.4.1.7244.1.1.1.8.1.1.1.'; #s31FcPassThroughBladeVoltageTable
	#### QUESTION s31FcPassThroughBladeVoltageTable
	my $snmpOIDFcPTPortsTable = '1.3.6.1.4.1.7244.1.1.1.8.1.3.1.'; #s31FcPassThroughBladePortsTable
	#### QUESTION s31FcPassThroughBladePortsTable
	my $snmpOIDFcPTInfoTable = '1.3.6.1.4.1.7244.1.1.1.8.1.2.1.'; #s31FcPassThroughBladeInfoTable
	my $snmpOIDInfoStatus = $snmpOIDFcPTInfoTable . '2'; #s31FcPassThroughBladeInfoStatus
	my $snmpOIDSerial	= $snmpOIDFcPTInfoTable . '5'; #s31FcPassThroughBladeInfoSerialNumber
	my $snmpOIDFcPTInfoWwnn = $snmpOIDFcPTInfoTable . '9'; #s31FcPassThroughBladeActiveWwnn
	my $snmpOIDFcPTInfoWwpn = $snmpOIDFcPTInfoTable . '10'; #s31FcPassThroughBladeActiveWwpn	
	my $snmpOIDSlot		= $snmpOIDFcPTInfoTable . '14'; #s31FcPassThroughBladeSlotId	
	my $snmpOIDIdSerial	= $snmpOIDFcPTInfoTable . '16'; #s31FcPassThroughBladeInfoIdentSerialNumber	
	my @bladeFcPTInfoTableChecks = (
		$snmpOIDInfoStatus,
		$snmpOIDFcPTInfoWwnn,
		$snmpOIDFcPTInfoWwpn,
		$snmpOIDSerial,
		$snmpOIDSlot,
 	);
	#### TODO Which Information is relevant/interesting for the customer ?
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0, );
	my @verboseStatusText = ( "none", 
		"unknown","ok","not-present","error","critical",
		"standby", "..unexpected..", 
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeFcPTInfoTableChecks);

	if (defined $entries) {
		#$msg .= "-FOUND FiberChannelPassThrough Blades-";
		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDInfoStatus, 1);

		addTableHeader("v","Fiber Channel Pass Through Switch Blades");
 		foreach my $bladeID (@bladesKeys) {
 			my $status  = $entries->{$snmpOIDInfoStatus . '.' . $bladeID};
			my $slotid = $entries->{$snmpOIDSlot . '.' . $bladeID};
 			my $serial = $entries->{$snmpOIDSerial . '.' . $bladeID};
			my $IDserial = trySNMPget($snmpOIDIdSerial . '.' . $bladeID,"IdentSerialNumber");
			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
			addStatusTopic("v",$verboseStatusText[$status], "FCPT", $bladeID);
			addSerialIDs("v",$serial, $IDserial);
			addSlotID("v",$slotid);
			endVariableVerboseMessageLine();
 			$cntCodes[$status]++;
 			if ((($status == 4) || ($status == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$status], "FCPT", $bladeID);
				addSerialIDs("l",$serial, $IDserial);
				addSlotID("l",$slotid);
				endLongMessageLine();
 			}
 		}
		# output
		addTopicStatusCount("m","Fiber Channel Pass Through Switch");
 		for (my $i=1;$i < 7;$i++) {
			addStatusCount("m",$verboseStatusText[$i], $cntCodes[$i]);
 		}
		# return code
 		if (($exitCode == 3) 
 		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
 		   || $cntCodes[5] || $cntCodes[6])
 		) { # reset default
 		    $exitCode = 0;
 		}
 		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
 			$exitCode = 1;
 		}
 		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
 			$exitCode = 2;
 		}
	} elsif (defined $optBladeIO_FCPT) {
		$msg .= "-No FiberChannelPassThrough Blades- ";
	}

	chomp($msg);
} # end primergyFiberChannelPassThroughBlades
sub primergyPhyBlades {
	############# Pass Through Blades
	my $snmpOIDPhyBladeTable = '1.3.6.1.4.1.7244.1.1.1.10.1.1.'; #s31PhyBladeTable
	my $snmpOIDSerial		= $snmpOIDPhyBladeTable . '4'; #s31PhyBladeSerialNumber
	my $snmpOIDProduct		= $snmpOIDPhyBladeTable . '5'; #s31PhyBladeProductName
	my $snmpOIDStatus		= $snmpOIDPhyBladeTable . '9'; #s31PhyBladeStatus
	my $snmpOIDIdSerial		= $snmpOIDPhyBladeTable . '11'; #s31PhyBladeIdentSerialNumber
	my @bladeTableChecks = (
		$snmpOIDSerial,
		$snmpOIDProduct,
		$snmpOIDStatus,
 	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0,);
	my @verboseStatusText = ( "none", 
		"unknown","ok","not-present","error","critical",
		"standby", "..unexpected..", 
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);

	if (defined $entries) {
 		my @swBladesKeys = ();
		@swBladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","LAN Pass Through Blades");
 		foreach my $swID (@swBladesKeys) {
 			my $swStatus  = $entries->{$snmpOIDStatus . '.' . $swID};
 			my $product = $entries->{$snmpOIDProduct . '.' . $swID};
 			my $serial = $entries->{$snmpOIDSerial . '.' . $swID};
 			my $IDserial = trySNMPget($snmpOIDIdSerial . '.' . $swID,"IndentSerialNumber");
			$swStatus = 0 if (!defined $swStatus or $swStatus < 0);
			$swStatus = 7 if ($swStatus > 7);
 			addStatusTopic("v",$verboseStatusText[$swStatus], "LANPT", $swID, );
			addSerialIDs("v",$serial, $IDserial);
			addProductModel("v",$product, undef);
			endVariableVerboseMessageLine();
			$cntCodes[$swStatus]++;
 			if ((($swStatus == 4) || ($swStatus == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$swStatus], "LANPT", $swID);
				addSerialIDs("l",$serial, $IDserial);
				addProductModel("l",$product, undef);
				endLongMessageLine();
 			}
		}
		# output
 		#msg .= " LAN Pass Through Blades";
		addTopicStatusCount("m", "LAN Pass Through Blades");
 		for (my $i=1;$i < 8;$i++) {
 			#msg .= "-$verboseStatusText[$i]($cntCodes[$i])"	
 			#	if ($cntCodes[$i]);
			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
 		}
		# return code
 		if (($exitCode == 3) 
 		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
 		   || $cntCodes[5] || $cntCodes[6] )
 		) { # reset default
 		    $exitCode = 0;
 		}
 		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
 			$exitCode = 1;
 		}
 		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
 			$exitCode = 2;
 		}
	} elsif (defined $optBladeIO_Phy) {
		$msg .= "-No LAN Pass Through Blades- ";
	}

	chomp($msg);
} # end primergyPhyBlades
sub primergyFCSwitchBlades {
	############# 
	my $snmpOIDFCSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.12.1.1.'; #s31FCSwitchBladeTable
	my $snmpOIDSerial	= $snmpOIDFCSwitchBladeTable . '4'; #s31FCSwitchBladeSerialNumber
	my $snmpOIDProduct	= $snmpOIDFCSwitchBladeTable . '5'; #s31FCSwitchBladeProductName
	my $snmpOIDModel	= $snmpOIDFCSwitchBladeTable . '6'; #s31FCSwitchBladeModelName
	my $snmpOIDIpAddress	= $snmpOIDFCSwitchBladeTable . '8'; #s31FCSwitchBladeIpAddress
	#my $snmpOIDFcIpAddress	= $snmpOIDFCSwitchBladeTable . '11'; #s31FCSwitchBladeFcIpAddress
	#my $snmpOIDFcName	= $snmpOIDFCSwitchBladeTable . '13'; #s31FCSwitchBladeFcSwitchName
	my $snmpOIDSlotId	= $snmpOIDFCSwitchBladeTable . '15'; #s31FCSwitchBladeSlotId
	my $snmpOIDStatus	= $snmpOIDFCSwitchBladeTable . '17'; #s31FCSwitchBladeStatus
	#my $snmpOIDAdmURL	= $snmpOIDFCSwitchBladeTable . '18'; #s31FCSwitchBladeAdministrativeURL
	# ... see ipaddr
	my $snmpOIDIdSerial	= $snmpOIDFCSwitchBladeTable . '23'; #s31FCSwitchBladeIdentSerialNumber
		# ATTENTION - IdentSerialNumber might be not available !
	my @bladeTableChecks = (
		$snmpOIDSerial,
		$snmpOIDProduct,
		$snmpOIDModel,
		$snmpOIDIpAddress,
	#	$snmpOIDFcIpAddress,
	#	$snmpOIDFcName,
		$snmpOIDSlotId,
		$snmpOIDStatus,
	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0, );
	my @verboseStatusText = ( "none", 
		"unkown","ok","not-present","error","critical",
		"standby", "..unexpected..",
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);

	if (defined $entries) {
		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","Fiber Channel Switch Blades");
 		foreach my $bladeID (@bladesKeys) {
 			my $status  = $entries->{$snmpOIDStatus . '.' . $bladeID};
 			my $ipaddr = $entries->{$snmpOIDIpAddress . '.' . $bladeID};
 			my $product = $entries->{$snmpOIDProduct . '.' . $bladeID};
 			my $model = $entries->{$snmpOIDModel . '.' . $bladeID};
			my $slotid = $entries->{$snmpOIDSlotId . '.' . $bladeID};
 			my $serial = $entries->{$snmpOIDSerial . '.' . $bladeID};
			my $IDserial = trySNMPget($snmpOIDIdSerial . '.' . $bladeID,"IdentSerialNumber");
 			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
			addStatusTopic("v",$verboseStatusText[$status], "FCSwitch", $bladeID);
			addSerialIDs("v",$serial, $IDserial);
			addSlotID("v",$slotid);
			addIP("v",$ipaddr);
			addProductModel("v",$product, $model);
			endVariableVerboseMessageLine();
 			$cntCodes[$status]++;
 			if ((($status == 4) || ($status == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$status], "FCSwitch", $bladeID);
				addSerialIDs("l",$serial, $IDserial);
				addSlotID("l",$slotid);
				addIP("l",$ipaddr);
				addProductModel("l",$product, $model);
				endLongMessageLine();
 			}
 		}
		# output
 		#msg .= " Fiber Channel Switch";
		addTopicStatusCount("m", "Fiber Channel Switch");
 		for (my $i=1;$i < 7;$i++) {
 			#msg .= "-$verboseStatusText[$i]($cntCodes[$i])"	
 			#	if ($cntCodes[$i]);
			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
 		}
		# return code
 		if (($exitCode == 3) 
 		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
 		   || $cntCodes[5] || $cntCodes[6])
 		) { # reset default
 		    $exitCode = 0;
 		}
 		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
 			$exitCode = 1;
 		}
 		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
 			$exitCode = 2;
 		}
	} elsif (defined $optBladeIO_FCSwitch) {
		$msg .= "-No Fiber Channel Switch Blades- ";
	}

	chomp($msg);
} # end primergyFCSwitchBlades
sub primergyIBSwitchBlades { #TODO - Blades with primergyIBSwitchBlades
	############# Infiniband Switch Blades
	my $snmpOIDIBSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.16.1.1.'; #s31IBSwitchBladeTable
	my $snmpOIDSerialNr	= $snmpOIDIBSwitchBladeTable . '4'; #s31IBSwitchBladeSerialNumber
	my $snmpOIDProduct	= $snmpOIDIBSwitchBladeTable . '5'; #s31IBSwitchBladeProductName
	my $snmpOIDModel	= $snmpOIDIBSwitchBladeTable . '6'; #s31IBSwitchBladeModelName
	my $snmpOIDIpAddress	= $snmpOIDIBSwitchBladeTable . '8'; #s31IBSwitchBladeIpAddress
	my $snmpOIDSlotId	= $snmpOIDIBSwitchBladeTable . '11'; #s31IBSwitchBladeSlotId
	my $snmpOIDStatus	= $snmpOIDIBSwitchBladeTable . '13'; #s31IBSwitchBladeStatus
	my $snmpOIDAdmURL	= $snmpOIDIBSwitchBladeTable . '14'; #s31IBSwitchBladeAdministrativeURL
	my $snmpOIDIdSerial	= $snmpOIDIBSwitchBladeTable . '19'; #s31IBSwitchBladeIdentSerialNumber
	my @bladeTableChecks = (
		$snmpOIDSerialNr,
		$snmpOIDProduct,
		$snmpOIDModel,
		$snmpOIDIpAddress,
		$snmpOIDSlotId,
		$snmpOIDStatus,
		$snmpOIDAdmURL,
	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0,);
	my @verboseStatusText = ( "none", 
		"unkown","ok","not-present","error","critical",
		"standby", "..unexpected..", 
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);

	if (defined $entries) {
		#$msg .= "-FOUND Infiniband Switch Blades- ";
		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","Infiniband Switch Blades");
 		foreach my $bladeID (@bladesKeys) {
 			my $status  = $entries->{$snmpOIDStatus . '.' . $bladeID};
 			my $ipaddr = $entries->{$snmpOIDIpAddress . '.' . $bladeID};
 			my $product = $entries->{$snmpOIDProduct . '.' . $bladeID};
 			my $model = $entries->{$snmpOIDModel . '.' . $bladeID};
			my $slotid = $entries->{$snmpOIDSlotId . '.' . $bladeID};
 			my $serial = $entries->{$snmpOIDSerialNr . '.' . $bladeID};
			my $admURL = $entries->{$snmpOIDAdmURL . '.' . $bladeID};
			my $IDserial = trySNMPget($snmpOIDIdSerial . '.' . $bladeID,"IdentSerialNumber");
 			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
 			addStatusTopic("v",$verboseStatusText[$status], "IBSwitch", $bladeID);
			addSerialIDs("v",$serial, $IDserial);
			addSlotID("v",$slotid);
			addIP("v",$ipaddr);
			addAdminURL("v",$admURL);
			addProductModel("v",$product, $model);
			endVariableVerboseMessageLine();
 			$cntCodes[$status]++;
 			if ((($status == 4) || ($status == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$status], "IBSwitch", $bladeID);
				addSerialIDs("l",$serial, $IDserial);
				addSlotID("l",$slotid);
				addIP("l",$ipaddr);
				addAdminURL("l",$admURL);
				addProductModel("l",$product, $model);
				endLongMessageLine();
 			}
 		}
		# output
		addTopicStatusCount("m","Infiniband Switch");
 		for (my $i=1;$i < 7;$i++) {

			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
 		}
		# return code
 		if (($exitCode == 3) 
 		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
 		   || $cntCodes[5] || $cntCodes[6])
 		) { # reset default
 		    $exitCode = 0;
 		}
 		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
 			$exitCode = 1;
 		}
 		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
 			$exitCode = 2;
 		}
	} elsif (defined $optBladeIO_IBSwitch) {
		$msg .= "-No Infiniband Switch Blades- ";
	}

	chomp($msg);
} # end primergyIBSwitchBlades
sub primergySASSwitchBlades {
	############# Serial attached SCSI Switch Blade
	my $snmpOIDSASSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.17.1.1.'; #s31SASSwitchBladeTable
	my $snmpOIDSerial	= $snmpOIDSASSwitchBladeTable . '4'; #s31SASSwitchBladeSerialNumber
	my $snmpOIDProduct	= $snmpOIDSASSwitchBladeTable . '5'; #s31SASSwitchBladeProductName
	my $snmpOIDModel	= $snmpOIDSASSwitchBladeTable . '6'; #s31SASSwitchBladeModelName
	my $snmpOIDIpAddress	= $snmpOIDSASSwitchBladeTable . '8'; #s31SASSwitchBladeIpAddress
	my $snmpOIDSlotId	= $snmpOIDSASSwitchBladeTable . '11'; #s31SASSwitchBladeSlotId
	my $snmpOIDStatus	= $snmpOIDSASSwitchBladeTable . '13'; #s31SASSwitchBladeStatus
	#my $snmpOIDAdmURL	= $snmpOIDSASSwitchBladeTable . '14'; #s31SASSwitchBladeAdministrativeURL
	my $snmpOIDIDSerial	= $snmpOIDSASSwitchBladeTable . '20'; #s31SASSwitchBladeIdentSerialNumber
		# ATTENTION - IdentSerialNumber might be not available !
	my @bladeTableChecks = (
		$snmpOIDSerial,
		$snmpOIDProduct,
		$snmpOIDModel,
		$snmpOIDIpAddress,
		$snmpOIDSlotId,
		$snmpOIDStatus,
	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0,);
	my @verboseStatusText = ( "none", 
		"unkown","ok","not-present","error","critical",
		"standby", "..unexpected..",
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);
	if (defined $entries) {
 		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","Serial Attached SCSI Switch Blades");
  		foreach my $bladeID (@bladesKeys) {
 			my $status  = $entries->{$snmpOIDStatus . '.' . $bladeID};
 			my $ipAddr = $entries->{$snmpOIDIpAddress . '.' . $bladeID};
 			my $slot = $entries->{$snmpOIDSlotId . '.' . $bladeID};
 			my $serial = $entries->{$snmpOIDSerial . '.' . $bladeID};
 			my $model = $entries->{$snmpOIDModel . '.' . $bladeID};
			my $product = $entries->{$snmpOIDProduct . '.' . $bladeID};
 			my $IDserial = trySNMPget($snmpOIDIDSerial . '.' . $bladeID,"IndentSerialNumber");
  			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
			addStatusTopic("v",$verboseStatusText[$status], "SASSwitch", $bladeID);
			addSerialIDs("v",$serial, $IDserial);
			addSlotID("v",$slot);
			addIP("v",$ipAddr);
			addProductModel("v",$product, $model);
			endVariableVerboseMessageLine();
 			$cntCodes[$status]++;
 			if ((($status == 4) || ($status == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$status], "SASSwitch", $bladeID);
				addSerialIDs("l",$serial, $IDserial);
				addSlotID("l",$slot);
				addIP("l",$ipAddr);
				addProductModel("l",$product, $model);
				endLongMessageLine();
 			}
 		}
		# output
 		#msg .= " Serial Attached SCSI Switch";
		addTopicStatusCount("m", "Serial Attached SCSI Switch");
 		for (my $i=1;$i < 7;$i++) {
 			#msg .= "-$verboseStatusText[$i]($cntCodes[$i])"	
 			#	if ($cntCodes[$i]);
			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
 		}
		# return code
 		if (($exitCode == 3) 
 		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
 		   || $cntCodes[5] || $cntCodes[6])
 		) { # reset default
 		    $exitCode = 0;
 		}
 		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
 			$exitCode = 1;
 		}
 		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
 			$exitCode = 2;
 		}
	} elsif (defined $optBladeIO_SASSwitch) {
		$msg .= "-No Serial Attached SCSI Switch Blades- ";
	}

	chomp($msg);
} # end primergySASSwitchBlades
sub primergyIOConnectionBlades {
	if ((defined $optBladeIO_FSIOM) || ($optBladeIO != 999)) {
		primergyFSIOMBlade();
	}
	if ((defined $optBladeIO_Switch) || ($optBladeIO != 999)) {
		primergySwitchBlades();
	}
	if ((defined $optBladeIO_FCPT) || ($optBladeIO != 999)) {
		primergyFiberChannelPassThroughBlades();
	}
	if ((defined $optBladeIO_Phy) || ($optBladeIO != 999)) {
		primergyPhyBlades();
	}
	if ((defined $optBladeIO_FCSwitch) || ($optBladeIO != 999)) {
		primergyFCSwitchBlades();
	}
	if ((defined $optBladeIO_IBSwitch) || ($optBladeIO != 999)) {
		primergyIBSwitchBlades();
	}
	if ((defined $optBladeIO_SASSwitch) || ($optBladeIO != 999)) {
		primergySASSwitchBlades();
	}
} # end primergyIOConnectionBlades
sub primergyKVMBlades {
	############# PRIMERGY BLADE SERVERBLADE OIDs 
	my $snmpOIDKvmBladeTable = '1.3.6.1.4.1.7244.1.1.1.11.1.1.'; #s31KvmBladeTable
	my $snmpOIDSerial	= $snmpOIDKvmBladeTable . '4'; #s31KvmBladeSerialNumber
	my $snmpOIDProduct	= $snmpOIDKvmBladeTable . '5'; #s31KvmBladeProductName
	my $snmpOIDModel	= $snmpOIDKvmBladeTable . '6'; #s31KvmBladeModelName
	my $snmpOIDIpAddress	= $snmpOIDKvmBladeTable . '9'; #s31KvmBladeIpAddress
	my $snmpOIDStatus	= $snmpOIDKvmBladeTable . '18'; #s31KvmBladeStatus
	#my $snmpOIDAdmURL	= $snmpOIDKvmBladeTable . '19'; #s31KvmBladeAdministrativeURL
	my @bladeTableChecks = (
		$snmpOIDSerial,
		$snmpOIDProduct,
		$snmpOIDModel,
		$snmpOIDIpAddress,
		$snmpOIDStatus,
	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0,);
	my @verboseStatusText = ( "none", 
		"unkown","ok","not-present","error","critical",
		"standby", "..unexpected..",
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);

	if (defined $entries) {
 		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","Key-Video-Mouse Blades");
 		foreach my $kvmID (@bladesKeys) {
 			my $kvmStatus  = $entries->{$snmpOIDStatus . '.' . $kvmID};
 			my $kvmIP = $entries->{$snmpOIDIpAddress . '.' . $kvmID};
			my $kvmProduct = $entries->{$snmpOIDProduct . '.' . $kvmID};
			my $model = $entries->{$snmpOIDModel . '.' . $kvmID};
			my $serial = $entries->{$snmpOIDSerial . '.' . $kvmID};
  			$kvmStatus = 0 if (!defined $kvmStatus or $kvmStatus < 0);
			$kvmStatus = 7 if ($kvmStatus > 7);
			addStatusTopic("v",$verboseStatusText[$kvmStatus], "KVM", $kvmID, );
			addSerialIDs("v",$serial, undef);
			addIP("v",$kvmIP);
			addProductModel("v",$kvmProduct, $model);
			endVariableVerboseMessageLine();
			$cntCodes[$kvmStatus]++;
			if ((($kvmStatus == 4) || ($kvmStatus == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$kvmStatus], "KVM", $kvmID);
				addSerialIDs("l",$serial, undef);
				addIP("l",$kvmIP);
				addProductModel("l",$kvmProduct, $model);
				endLongMessageLine();
			}
 		}
		# output
		#msg .= " KVM";
		addTopicStatusCount("m","KVM");
		for (my $i=1;$i < 7;$i++) {
			#msg .= "-$verboseStatusText[$i]($cntCodes[$i])"	
			#	if ($cntCodes[$i]);
			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
		}
		# return code
		if (($exitCode == 3) 
		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
		   || $cntCodes[5] || $cntCodes[6])
		) { # reset default
		    $exitCode = 0;
		}
		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
			$exitCode = 1;
		}
		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
			$exitCode = 2;
		}
	} elsif (defined $optBladeKVM and $optBladeKVM != 999) {
		$msg .= "-No KVM Blades- ";
	}

	chomp($msg);
} # end primergyKVMBlades
sub primergyStorageBlades {
	############# PRIMERGY BLADE SERVERBLADE OIDs 
	my $snmpOIDStorageBladeTable = '1.3.6.1.4.1.7244.1.1.1.13.1.1.'; #s31StorageBladeTable
	my $snmpOIDSerialNR	= $snmpOIDStorageBladeTable . '4'; #s31StorageBladeSerialNumber
	my $snmpOIDProduct	= $snmpOIDStorageBladeTable . '5'; #s31StorageBladeProductName
	my $snmpOIDModel	= $snmpOIDStorageBladeTable . '6'; #s31StorageBladeModelName
	my $snmpOIDStatus	= $snmpOIDStorageBladeTable . '8'; #s31StorageBladeStatus
	my $snmpOIDIdSerialNR	= $snmpOIDStorageBladeTable . '10'; #s31StorageBladeIdentSerialNumber
	my $snmpOIDAdmURL	= $snmpOIDStorageBladeTable . '11'; #s31StorageBladeAdministrativeURL
	my @bladeTableChecks = (
		$snmpOIDSerialNR,
		$snmpOIDProduct,
		$snmpOIDModel,
		$snmpOIDStatus,
		$snmpOIDIdSerialNR,
		$snmpOIDAdmURL,
	);
	my @cntCodes = ( -1, 0,0,0,0,0,0, 0,);
	my @verboseStatusText = ( "none", 
		"unkown","ok","not-present","error","critical",
		"standby", "..unexpected..",
	);

	#------------------------------------------------------

	my $entries = getSNMPtable(\@bladeTableChecks);

	if (defined $entries) {
  		my @bladesKeys = ();
		@bladesKeys = getSNMPTableIndex($entries, $snmpOIDStatus, 1);

		addTableHeader("v","Storage Blades");
		foreach my $storeID (@bladesKeys) {
 			my $storeStatus  = $entries->{$snmpOIDStatus . '.' . $storeID};
 			my $storeSerial = $entries->{$snmpOIDSerialNR . '.' . $storeID};
 			my $storeIdSerial = $entries->{$snmpOIDIdSerialNR . '.' . $storeID};
			my $storeAdmURL = $entries->{$snmpOIDAdmURL . '.' . $storeID};
			my $product = $entries->{$snmpOIDProduct . '.' . $storeID};
			my $model = $entries->{$snmpOIDModel . '.' . $storeID};
   			$storeStatus = 0 if (!defined $storeStatus or $storeStatus < 0);
			$storeStatus = 7 if ($storeStatus > 7);
			addStatusTopic("v",$verboseStatusText[$storeStatus], "Storage", $storeID);
			addSerialIDs("v",$storeSerial, $storeIdSerial);
			addAdminURL("v",$storeAdmURL);
			addProductModel("v",$product, $model);
			endVariableVerboseMessageLine();
			$cntCodes[$storeStatus]++;
			if ((($storeStatus == 4) || ($storeStatus == 5)) &&  ($main::verbose < 2) ) {
				addStatusTopic("l",$verboseStatusText[$storeStatus], 
					"Storage", $storeID);
				addSerialIDs("l",$storeSerial, $storeIdSerial);
				addAdminURL("l",$storeAdmURL);
				addProductModel("l",$product, $model);
				endLongMessageLine();
			}
 		}
		# output
		#msg .= " Storage Blades";
		addTopicStatusCount("m","StorageBlades");
		for (my $i=1;$i < 7;$i++) {
			#msg .= "-$verboseStatusText[$i]($cntCodes[$i])"	
			#	if ($cntCodes[$i]);
			addStatusCount("m", $verboseStatusText[$i], $cntCodes[$i]);
		}
 		# return code
		if (($exitCode == 3) 
		&& (  $cntCodes[2] || $cntCodes[3] || $cntCodes[4]
		   || $cntCodes[5] || $cntCodes[6])
		) { # reset default
		    $exitCode = 0;
		}
		if ($cntCodes[4] && $exitCode < 1) { #nagios warning 
			$exitCode = 1;
		}
		if ($cntCodes[5] && $exitCode < 2) { #nagios critical 
			$exitCode = 2;
		}
	} elsif (defined $optBladeStore and $optBladeStore != 999) {
		$msg .= "-No Storage Blades- ";
	}

	chomp($msg);
} # end primergyStorageBlades

#----------- PRIMERGY server functions - INVENT.mib
sub inv_sniInventoryOSinformation {
	my $snmpOidInventory = '.1.3.6.1.4.1.231.2.10.2.1.'; #sniInventory
	my $snmpOidOS		= $snmpOidInventory . '4.0'; #sniInvHostOS
	my $snmpOidName		= $snmpOidInventory . '8.0'; #sniInvHostName
	my $snmpOidOSRevision	= $snmpOidInventory . '22.0'; #sniInvHostOSRevision
	my $snmpOidFQDN		= $snmpOidInventory . '26.0'; #sniInvFullQualifiedName

	my $testCode = 0;
	my $os = trySNMPget($snmpOidOS,"sniInventory"); # check INVENT.mib existence
	$testCode = 3 if (!defined $os);
	if ($testCode==0) {
		my $name = trySNMPget($snmpOidName,"sniInventory");
		my $revision = trySNMPget($snmpOidOSRevision,"sniInventory");
		my $fqdn = trySNMPget($snmpOidFQDN,"sniInventory");
		addKeyLongValue("n","OS",$os);
		addKeyLongValue("n","OS-Revision",$revision);
		addKeyValue("n","Name",$name) if($main::verbose > 2);
		if ($fqdn) {
			$fqdn = undef if ($prgSystemName and ($prgSystemName eq $fqdn));
			addKeyLongValue("n","FQDN",$fqdn);
		}
	}
} #inv_sniInventoryOSinformation
sub inv_sniFileSystemTable  {
	my $snmpOidFileSystemTable = '.1.3.6.1.4.1.231.2.10.2.1.18.1.'; #sniFileSystemTable
	my $snmpOidIsMounted	= $snmpOidFileSystemTable .  '6'; #sniIsMounted
	my $snmpOidName		= $snmpOidFileSystemTable .  '7'; #sniFSName
	my $snmpOidKBSize	= $snmpOidFileSystemTable .  '8'; #sniFSSize KB
	my $snmpOidKBSpace	= $snmpOidFileSystemTable . '10'; #sniFSAvailableSpace
	my $snmpOidUsage	= $snmpOidFileSystemTable . '11'; #sniFSUsage %
	my $snmpOidType		= $snmpOidFileSystemTable . '12'; #sniFSTypeString
	# try
	my $snmpOidMBSize	= $snmpOidFileSystemTable . '13'; #sniFSSizeMb
	my $snmpOidMBSpace	= $snmpOidFileSystemTable . '14'; #sniFSAvailableSpaceMb
	my @tableChecks = (
		$snmpOidIsMounted, $snmpOidName, $snmpOidKBSize, $snmpOidKBSpace,
		$snmpOidUsage, $snmpOidType,
	);
	my $all_notify = 0;
	{ # everytime
		my $is_linux = 0;
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 1);

		addTableHeader("v","File System Table");
		$exitCode = 0 if ($#snmpIDs >= 0);
		my $notify = 0;
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $mounted = $entries->{$snmpOidIsMounted . '.' . $snmpID};
			my $type = $entries->{$snmpOidType . '.' . $snmpID};
			my $usage = $entries->{$snmpOidUsage . '.' . $snmpID};
			#$name = "..undefined.." if (!defined $name);
			#$name = "..N/A.." if (!$name);
			#$type = "..undefined.." if (!defined $type);
			#$type = "..N/A.." if (!$type);
			my $mmode = '';
			$mmode = "$mounted" if (defined $mounted);

			next if (!$type and $main::verbose < 3);
			$is_linux = 1 if ($name eq "/");

			addStatusTopic("v",undef, "FS", $snmpID);
			addName("v",$name);
			addKeyLongValue("v","Type", $type);
			addKeyIntValueUnit("v","Use",$usage,"%");

			my $sizeUnit = undef;
			my $spaceUnit = undef;
			my $size = trySNMPget($snmpOidMBSize . '.' . $snmpID);
			my $space = trySNMPget($snmpOidMBSpace . '.' . $snmpID);
			$sizeUnit = "MB" if ($size);
			$spaceUnit = "MB" if ($space);
			if (!$size) {
				$size = $entries->{$snmpOidKBSize . '.' . $snmpID};
				$sizeUnit = "KB" if ($size);
			}
			if (!$space) {
				$space = $entries->{$snmpOidKBSpace . '.' . $snmpID};
				$spaceUnit = "KB" if ($space);
			}
			addKeyValueUnit("v","Size",$size,$sizeUnit) if ($sizeUnit);
			addKeyValueUnit("v","Space",$space,$spaceUnit) if ($spaceUnit);
			addKeyValue("v","MountMode",$mmode);
			$variableVerboseMessage .= "\n";

			if ($usage) {
				$name = "FS_$snmpID" if (!$name);
				$name =~ s/(.*) \((.)\:\)/$2_$1/ if ($name =~ m/\(.\:\)$/);
					# ... above is for WINDOWS "name (x:)"
				$name =~ s/[ ,;=]/_/g;
				$name =~ s/[:()]//g;
				if ($name =~ m/^([A-Z]_)/) {
					my $lchar = $1;
					if ($name =~ m/^$lchar$lchar/) {
						# lchar was already part of name !
						$name =~ s/^$lchar//;
					}
				}
				if ($is_linux and $usage == 100) {
					$usage = 0 if ($name =~ m/\/dev\/.*/);
					$usage = 0 if ($name =~ m/\/system\/.*/);
					$usage = 0 if ($name =~ m/\/sys\/.*/);
					$usage = 0 if ($name =~ m/\/proc\/.*/);
					$usage = 0 if ($name =~ m/\/media\/.*/);
					$usage = 0 if ($name eq "/vol");  # found on solaris
					$usage = 0 if ($name eq "/devices");  # found on solaris
					$usage = 0 if ($type eq "proc");
					$usage = 0 if ($type eq "sysfs");
					$usage = 0 if ($type eq "mntfs");
					$usage = 0 if ($type eq "rpc_pipefs");
					$usage = 0 if ($type eq "autofs"); # found on solaris
					$usage = 0 if ($type =~m/^iso9.*/);
					$usage = 0 if ($type =~m/.*gvfs.*/);
				}
				if ($usage) {
					my $perfname = $name;
					$perfname = "ROOT" if ($perfname eq "/");
					#$perfname =~ s/^\///;
					addPercentageToPerfdata($perfname,$usage,
						$optWarningLimit,$optCriticalLimit);
				}
				$notify = 0;
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
					addStatusTopic("l",undef, "FS", $snmpID);
					addName("l",$name);
					addKeyLongValue("l","Type", $type);
					addKeyIntValueUnit("l","Use",$usage,"%");
					$longMessage .= "\n";
				}
			} # usage performance data
		} # for keys
		$msg .= "- file system limit reached" if ($all_notify); 
	}
} #inv_sniFileSystemTable
sub inv_sniNetworkInterfaceTable  {
	my $snmpOidNetworkInterfaceTable = '.1.3.6.1.4.1.231.2.10.2.1.25.1.'; #sniNetworkInterfaceTable
	my $snmpOidName		= $snmpOidNetworkInterfaceTable . '2'; #sniInterfaceDescription
	my $snmpOidAdapter	= $snmpOidNetworkInterfaceTable . '3'; #sniInterfaceAdapter
	my $snmpOidConnectionNm	= $snmpOidNetworkInterfaceTable . '4'; #sniInterfaceConnectionName
	my $snmpOidUsage	= $snmpOidNetworkInterfaceTable . '5'; #sniInterfaceUsage %
	my $snmpOidSpeed	= $snmpOidNetworkInterfaceTable . '6'; #sniInterfaceSpeed KB/sec
	my $snmpOidBytesIO	= $snmpOidNetworkInterfaceTable . '9'; #sniInterfaceBytesInOut KB/sec
	# ATTENTION: Usage was not set for current test servers
	my @tableChecks = (
		$snmpOidName, $snmpOidAdapter, $snmpOidConnectionNm, $snmpOidUsage,
		$snmpOidSpeed, $snmpOidBytesIO,
	);
	my $all_notify = 0;
	{
		my $foundPerf = 0;
		my $foundVirtEthernet = 0;
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 1);

		addTableHeader("v","Network Interface Table");
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $adapter = $entries->{$snmpOidAdapter . '.' . $snmpID};
			my $conn = $entries->{$snmpOidConnectionNm . '.' . $snmpID};
			my $usage = $entries->{$snmpOidUsage . '.' . $snmpID};
			my $speed = $entries->{$snmpOidSpeed . '.' . $snmpID};
			my $iobytes = $entries->{$snmpOidBytesIO . '.' . $snmpID};
			$conn = undef if ($conn and $name and $conn =~m/$name/);

			$foundVirtEthernet = 1 if ($conn and $conn =~ m/vEthernet/ 
					and $name and $name =~ m/Hyper-V/);

			addStatusTopic("v", undef, "NetIF", $snmpID);
			addKeyLongValue("v","Description",$name);
			addKeyLongValue("v","Adapter", $adapter);
			addKeyLongValue("v","Connection",$conn);
			addKeyValueUnit("v","Usage",$usage,"%");
			addKeyValueUnit("v","Speed",$speed,"KB/sec");
			addKeyIntValueUnit("v","BytesInOut",$iobytes,"KB/sec");
			$variableVerboseMessage .= "\n";
			my $perfname = "NetIF[$snmpID]";
			$perfname = "Loopback[$snmpID]" 
				if (! $conn and $name and $name =~ m/Loopback/);
			$perfname = "vEthernet[$snmpID]" 
				if ($conn and $conn =~ m/vEthernet/);
			$perfname = "LAN[$snmpID]" 
				if ($conn and $conn =~ m/LAN/);
			$perfname = "LocalAreaConnection[$snmpID]" 
				if ($conn and $conn =~ m/Local Area Connection/);
			if ($perfname eq "NetIF[$snmpID]") {
				$perfname = "$conn" . "[$snmpID]" 
					if ($conn and $conn !~ m/\s/ and $conn !~ m/^0x/);
			}
			if ($perfname eq "NetIF[$snmpID]") {
				$perfname = "$name" . "[$snmpID]" 
					if ($name and $name !~ m/\s/ and $name !~ m/^0x/);
			}

			addKBsecToPerfdata($perfname, $iobytes, 
				$optWarningLimit, $optCriticalLimit)
				if ($speed or $iobytes);
			$foundPerf = 1 if ($speed or $iobytes);
			my $notify = 0;
			if ($iobytes and $optWarningLimit 
				and $iobytes > $optWarningLimit) {
				$exitCode = 1 if ($exitCode != 2);
				$notify = 1;
				$all_notify = 1;
			}
			if ($iobytes and $optCriticalLimit and $iobytes > $optCriticalLimit) {
				$exitCode = 2;
				$notify = 1;
				$all_notify = 1;
			}
			$notify = 0 if ($main::verbose >= 2); # allready printed
			if ($notify and $iobytes and $speed) {
				addStatusTopic("l", undef, "NetIF", $snmpID);
				addKeyLongValue("l","Description",$name);
				addKeyLongValue("l","Adapter", $adapter);
				addKeyLongValue("l","Connection",$conn);
				addKeyValueUnit("l","Usage",$usage,"%");
				addKeyValueUnit("l","Speed",$speed,"KB/sec");
				addKeyIntValueUnit("l","BytesInOut",$iobytes,"KB/sec");
				$longMessage .= "\n";
			}
		} # for keys
		$msg .= "- network interface limit reached" if ($all_notify); 
		$exitCode = 0 if ($#snmpIDs >= 0 and $foundPerf and $exitCode == 3);
		$msg .= "- unable to monitor Hyper-V Virtual Ethernet on this system" if (!$foundPerf and $foundVirtEthernet);
	}
} #inv_sniNetworkInterfaceTable
#----------- PRIMERGY server functions - OS.mib
  sub svOsInfoTable {
	my $isiRMC = shift;
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.2.1.'; #svOsInfoTable
	my $snmpDesignation = $snmpOID . '2.1'; #svOsDesignation
	my $snmpVersion	    = $snmpOID . '6.1'; #svOsVersionDesignation
	my $snmpDomain	    = $snmpOID . '13.1'; #svOsDomainName

	my $os		= trySNMPget($snmpDesignation, "svOsDesignation");
	my $version	= trySNMPget($snmpVersion, "svOsVersionDesignation");
	my $fqdn	= trySNMPget($snmpDomain, "svOsDomainName");
	$os = undef		if ($os and $os =~ m/^n.a$/);
	$version = undef	if ($version and $version =~ m/^n.a$/);
	$fqdn = undef		if ($fqdn and $fqdn =~ m/^n.a$/);
	if (!$isiRMC) {
		addKeyLongValue("n","OS",$os);
		addKeyLongValue("n","OS-Revision",$version);
		if ($fqdn) {
			$fqdn = undef if ($prgSystemName and ($prgSystemName eq $fqdn));
			addKeyLongValue("n","FQDN",$fqdn) if (!$isiRMC);
		}
	} else {
		addKeyLongValue("n","BaseServer-OS",$os);
		addKeyLongValue("n","BaseServer-OS-Revision",$version);
		if ($fqdn) {
			$fqdn = undef if ($prgSystemName and ($prgSystemName eq $fqdn));
			addKeyLongValue("n","BaseServer-FQDN",$fqdn);
		}
	}
	return 1 if ($os);
	return 0 if (!$os);
  } #svOsInfoTable
  sub svOsPropertyTable {
	return 0 if (!$optChkCpuLoadPerformance);
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.3.1.'; #svOsPropertyTable
	my $snmpCPUload  = $snmpOID . '6.1'; #svOsOverallCpuLoad

	my $cpuload = trySNMPget($snmpCPUload,"svOsOverallCpuLoad");
	if (defined $cpuload and $cpuload >= 0) {
	    addKeyPercent("m", "Total", $cpuload, undef,undef, undef,undef);
	    addPercentageToPerfdata("Total", $cpuload, undef, undef)
		    if (!$main::verboseTable);
	    return 1;
	} else {
	    return 0;
	}
  } #svOsPropertyTable
#----------- PRIMERGY server functions - Status.mib
our $resultEnv = 3;  
our $resultPower = 0;  
our $resultSystem = 0; 
our $resultMassStorage = undef;
our $resultDrvMonitor = undef;
our $resultOverall = undef;
sub sieStComponentTable {
	# Status.mib
	my $snmpOidStComponentTable = '.1.3.6.1.4.1.231.2.10.2.11.4.1.1.'; #sieStComponentTable
	my $snmpOidFixName	= $snmpOidStComponentTable . '2'; #sieStComponentName
	my $snmpOidStatus	= $snmpOidStComponentTable . '3'; #sieStComponentStatusValue
	my $snmpOidLastMessage	= $snmpOidStComponentTable . '4'; #sieStComponentLastErrorMessage
	my $snmpOidName		= $snmpOidStComponentTable . '5'; #sieStComponentDisplayName
	my @tableChecks = (
		$snmpOidFixName, $snmpOidStatus, $snmpOidLastMessage, $snmpOidName, 
	);
	my @statusText = ( "none",
		"ok", "degraded", "error", "failed", "unknown",	
		"notPresent", "notManageable", "..unexpected..",
	);
	my $getInfos = 0;
	my $collectStorage = '';
	$getInfos = 1 if ($main::verboseTable == 1411);
	# $main::verbose = 100 if ($getInfos == 1);
	if ($optChkStorage and defined $resultMassStorage and $main::verbose == 4) {
		$getInfos = 1 if ($resultMassStorage);
		$getInfos = 1 if ($main::verbose >= 2);
	} #TO-BE_DISCUSSED
	if ($getInfos) { #sieStComponentTable
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 1);

		if ($main::verboseTable == 1411) {
			addTableHeader("v","Status Component Table - Status.mib");
			foreach my $id (@snmpIdx) {
				my $name = $entries->{$snmpOidName . '.' . $id};
				my $status = $entries->{$snmpOidStatus . '.' . $id};
				my $message = $entries->{$snmpOidLastMessage . '.' . $id};
				my $internalName = $entries->{$snmpOidFixName . '.' . $id};
				$status = 0 if (!defined $status or $status < 0);
				$status = 8 if ($status > 8);
				next if ($status == 5);
				{
					addStatusTopic("v",$statusText[$status],"StatusComponent",$id);
					addKeyLongValue("v","Name",$name);
					addKeyLongValue("v","InternalName",$internalName);
					$message = undef if ($message =~ m/<<not supported>>/);
					addKeyLongValue("v","LastError",$message);
					$variableVerboseMessage .= "\n";
				} 
			} # each
		} # ALL
		elsif ($optChkStorage and defined $resultMassStorage) {
			addTableHeader("v","Status Component Table - MassStorage parts");
			my $isSvRaid = 0;
			foreach my $id (@snmpIdx) {
				my $name = $entries->{$snmpOidName . '.' . $id};
				my $status = $entries->{$snmpOidStatus . '.' . $id};
				my $message = $entries->{$snmpOidLastMessage . '.' . $id};
				my $internalName = $entries->{$snmpOidFixName . '.' . $id};
				$status = 0 if (!defined $status or $status < 0);
				$status = 8 if ($status > 8);
				next if ($status == 5);
				if (    $name =~ m/storage/i or $name =~ m/raid/i 
				    or  $internalName =~ m/storage/i or $internalName =~ m/raid/i) 
				{
				    $isSvRaid = 1 if ($internalName =~ m/SvRaidAura/i);
				    if ($main::verbose >= 2) {
					addStatusTopic("v",$statusText[$status],"StatusComponent",$id);
					addKeyLongValue("v","Name",$name);
					addKeyLongValue("v","InternalName",$internalName)
					    if ($main::verbose >= 33);
					$message = undef if ($message =~ m/<<not supported>>/);
					addKeyLongValue("v","LastError",$message);
					$variableVerboseMessage .= "\n";
				    } elsif ($resultMassStorage and $status >= 2 and $status <= 4) 
				    {
					# SVRAID -> SvRaidAura, SvRaidAdapters, SvRaidLogicalDrives, SvRaidPhysicalDisks
					next if ($isSvRaid and
					    (  $internalName =~ m/SvRaidAura/i
					    or $internalName =~ m/SvRaidAdapters/i
					    or $internalName =~ m/SvRaidLogicalDrives/i
					    or $internalName =~ m/SvRaidPhysicalDisks/i) );
					addStatusTopic("l",$statusText[$status],"StatusComponent",$id);
					addKeyLongValue("l","Name",$name);
					$message = undef if ($message =~ m/<<not supported>>/);
					addKeyLongValue("l","LastError",$message);
					$longMessage .= "\n";
				    }
				} # storage or raid match
			} # each
		} # Storage
	} # table verbose
} #sieStComponentTable
sub sieStatusAgent {
	# Status.mib
	my $snmpOidPrefix = '1.3.6.1.4.1.231.2.10.2.11.'; #sieStatusAgent
	my $snmpOidSysStat		= $snmpOidPrefix . '2.1.0'; #sieStSystemStatusValue.0
	#my $snmpOidStSystemMessage	= $snmpOidPrefix . '2.2.0'; #sieStSystemLastErrorMessage.0
	my $snmpOidSubSysCnt	= $snmpOidPrefix . '3.2.0'; #sieStNumberSubsystems.0
	my $snmpOidSubSys	= $snmpOidPrefix . '3.1.1.'; #sieStSubsystemTable
	my $snmpOidSubSysName		= $snmpOidSubSys . '2'; #sieStSubsystemName
	my $snmpOidSubSysValue		= $snmpOidSubSys . '3'; #sieStSubsystemStatusValue
	#my $snmpOidSubSysMessage	= $snmpOidSubSys . '4' ;#sieStSubsystemLastErrorMessag
	#	... in tests LastErrorMessage was NOT set !
	my @subSysStatusText = ( 'none', 
		'ok', 'degraded', 'error', 'failed', 'unknown' );
	#my @subSystemNameText = ( "none",
	#	'Environment', 'PowerSupply', 'MassStorage', 'SystemBoard', 'Network',
	#	'DrvMonitor',
	#); # not always in this order !
	my %commonSystemCodeMap = (	1       =>      0,
					2       =>      1,
					3       =>      2,
					4       =>      2,
					5	=>	3,);
	my $srvSubSystem_cnt = undef;
	my $srvCommonSystemStatus = undef; 
	my $result = undef;
	# fetch central system state
	#$srvCommonSystemStatus = simpleSNMPget($snmpOidSysStat,"SystemStatus"); # not for iRMC
	$srvCommonSystemStatus = trySNMPget($snmpOidSysStat,"SystemStatus");
	if (!$srvCommonSystemStatus) { # iRMC S4 and version who does not support STATUS.mib
	    $exitCode = 4;
	    return;
	}
	# set exit value
	$srvCommonSystemStatus = 5 if (!$srvCommonSystemStatus or $srvCommonSystemStatus > 5);
	$resultOverall = $commonSystemCodeMap{$srvCommonSystemStatus}; 
	# get subsystem information
	$srvSubSystem_cnt = simpleSNMPget($snmpOidSubSysCnt,"SubSystemCount");
	
	for (my $x = 1; $x <= $srvSubSystem_cnt; $x++) {	
		$result = simpleSNMPget($snmpOidSubSysValue . '.' . $x,"SubsystemStatusValue"); #sieStSubsystemStatusValue	
		my $subSystemName = simpleSNMPget($snmpOidSubSysName . '.' . $x,"SubsystemName"); #sieStSubsystemName	
		my $printAll = 0;
		next if ($result >= 5 or !defined $result or !$result);

		if ($x < 5) {
		    if (((defined $optChkEnvironment) && ($x == 1))
		    ||  ((defined $optChkPower) && ($x == 2)) 
		    ||  ((defined $optChkSystem) && ($x > 2)) 
		    ||  ((defined $optChkStorage) && ($x == 3)) 
		    ) {  
			addComponentStatus("m", $subSystemName, $subSysStatusText[$result]);
			$result = 5 if ($result > 5);
			if ($x == 1) {
				$resultEnv = $commonSystemCodeMap{$result};
			} elsif ($x == 2) {
				$resultPower = $commonSystemCodeMap{$result};
			} elsif ($x > 2) {
				my $tmp_result = 0;
				$tmp_result = $commonSystemCodeMap{$result};
				$resultSystem = $tmp_result if ($resultSystem <= $tmp_result);
				if ($x == 3) { # included in System
					$resultMassStorage = $commonSystemCodeMap{$result};
				}
			}
		    }
		} # displayname
		elsif ((($x > 4) && (defined $optChkSystem) && ($main::verbose >= 1))
		|| ($optChkSystem and $result > 1 and $exitCode > 0 and ($subSystemName ne 'DrvMonitor'))
		) {	# ... for verbose or on warning or error
			addComponentStatus("m", $subSystemName, $subSysStatusText[$result]);
			$printAll = 1;
		}	
		if ($x >= 6 and ($subSystemName eq 'DrvMonitor')) {
			$resultDrvMonitor = $commonSystemCodeMap{$result};
			if ($optChkDrvMonitor and !$printAll) {
				addComponentStatus("m", $subSystemName, $subSysStatusText[$result]);
			}
		}
		if ($result > $srvCommonSystemStatus and $result != 5) 
		{
			my $tmp_result = 0;
			$tmp_result = $commonSystemCodeMap{$result};
			$resultOverall = $tmp_result if ($resultOverall <= $tmp_result); 
		}
	} # for subsystems
	# sieStComponentTable(); ... check later for Storage Parts
} #sieStatusAgent


#----------- PRIMERGY server functions - SC2.mib
our $psHasMultiUnits = undef;
sub primergyServerFanTable {
	my $rcEnv = shift;

	my $snmpOidEnvFanPrefix = '.1.3.6.1.4.1.231.2.10.2.2.10.5.2.1.'; #sc2FanTable
	my $snmpOidEnvFanStatus		= $snmpOidEnvFanPrefix . '5'; #sc2fanStatus
	my $snmpOidEnvFanSpeed		= $snmpOidEnvFanPrefix . '6'; #sc2fanCurrentSpeed
	my $snmpOidEnvFanDesc		= $snmpOidEnvFanPrefix . '3'; #sc2fanDesignation
	my $snmpOidEnvFanDeviceType	= $snmpOidEnvFanPrefix . '10'; #sc2fanCoolingDeviceType
	    # 1 unknown, 2 fan, 3 liquid
	    # sc2fanCoolingDeviceType - only SvAgent V7.10 knows this OID
	my @envFanChecks = (
		$snmpOidEnvFanStatus,
		$snmpOidEnvFanSpeed,
		$snmpOidEnvFanDesc
	);

	#### TEXT LANGUAGE AWARENESS
	my @srvFanStatus = ( "none",
		"unknown", "disabled", "ok", "fail", "prefailure-predicted",
		"redundant-fan-failed", "not-manageable", "not-present", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if ($rcEnv and $rcEnv < 3);
	$getInfos = 1 if ($verbose or $notify);
	$getInfos = 1 if ($optChkFanPerformance);
	if (($optChkEnvironment or $optChkEnv_Fan) and $getInfos) {
		my @snmpIDs = ();
		my $entries = getSNMPtable(\@envFanChecks);
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidEnvFanStatus, 2);

		addTableHeader("v","Cooling Devices") if ($verbose);
		my $hasDeviceType = undef;
		foreach my $fanID (@snmpIDs) {
			my $fanStatus  = $entries->{$snmpOidEnvFanStatus . '.' . $fanID};
			my $fanDesc = $entries->{$snmpOidEnvFanDesc . '.' . $fanID};
			my $fanSpeed = $entries->{$snmpOidEnvFanSpeed . '.' . $fanID};
			my $fanType = undef;
			$fanType = trySNMPget($snmpOidEnvFanDeviceType, "FanDeviceType")
			    if (!defined $hasDeviceType or $hasDeviceType);
			$hasDeviceType = 1 if (!defined $hasDeviceType and $fanType and $fanType >= 1 and $fanType <=3);
			$hasDeviceType = 0 if (!defined $hasDeviceType);
			$fanDesc =~ s/[ ,;=]/_/g;
			$fanDesc =~ s/_$//;
			$fanStatus = 0 if (!defined $fanStatus or $fanStatus < 0);
			$fanStatus = 9 if ($fanStatus > 9);
			next if (($fanStatus eq '2' or $fanStatus eq '8') and $main::verbose < 3);
			
			my $printFanID = 0;
			$printFanID = $1 if ($fanID =~ /\d+\.(\d+)/);
			$printFanID = $fanID if ($psHasMultiUnits);
			if ($verbose) {
				addStatusTopic("v",$srvFanStatus[$fanStatus], "Fan", $printFanID)
				    if (!$fanType or $fanType < 3);
				addStatusTopic("v",$srvFanStatus[$fanStatus], "Liquid",	$printFanID)
				    if ($fanType and $fanType == 3);
				addName("v",$fanDesc);
				addKeyRpm("v","Speed", $fanSpeed);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and   (($fanStatus == 2) || ($fanStatus == 4) || ($fanStatus == 5) ||($fanStatus == 6))
			) {
				addStatusTopic("l",$srvFanStatus[$fanStatus], "Fan", $printFanID);
				addName("l",$fanDesc);
				addKeyRpm("l","Speed", $fanSpeed);
				$longMessage .= "\n";
			}
			if ($optChkFanPerformance) {
				addRpmToPerfdata($fanDesc, $fanSpeed, undef, undef);
			}
		} #for
	}
} #primergyServerFanTable
sub primergyServerTemperatureSensorTable {
	my $rcEnv = shift;

	my $snmpOidEnvTempPrefix = '1.3.6.1.4.1.231.2.10.2.2.10.5.1.1.'; #sc2TemperatureSensorTable
	my $snmpOidEnvTempStatus	= $snmpOidEnvTempPrefix . '5'; #sc2tempSensorStatus
	my $snmpOidEnvTempWarn		= $snmpOidEnvTempPrefix . '7'; #sc2tempWarningLevel
	my $snmpOidEnvTempCrit		= $snmpOidEnvTempPrefix . '8'; #sc2tempCriticalLevel
	my $snmpOidEnvTempValue		= $snmpOidEnvTempPrefix . '6'; #sc2tempCurrentTemperature
	my $snmpOidEnvTempDesc		= $snmpOidEnvTempPrefix . '3'; #sc2tempSensorDesignation
	my @envTempChecks = (
		$snmpOidEnvTempStatus,
		$snmpOidEnvTempValue,
		$snmpOidEnvTempWarn,
		$snmpOidEnvTempCrit,
		$snmpOidEnvTempDesc
	);
	my @srvTempStatus = ( "none",
		"unknown", "not-available", "ok", "sensor-failed", "failed", 
		"temperature-warning-toohot", "temperature-critical-toohot", "ok", "temperature-warning", "..unexpected..",
	); # 8 is "temperature-normal"
	# now check the temperatures
	my $getinfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 1 and !$main::verboseTable);
	$notify = 1 if ($rcEnv and $rcEnv < 3);
	$getinfos = 1; # get performance data always !
	if (($optChkEnvironment or $optChkEnv_Temp) and $getinfos) {
		my @snmpIDs = ();
		my $entries = getSNMPtable(\@envTempChecks);
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidEnvTempStatus, 2);

		addTableHeader("v","Temperature Sensors") if ($verbose);
		my %chkDoubleNames = ();
		foreach my $tempID (@snmpIDs) {	
			my $tempStatus  = $entries->{$snmpOidEnvTempStatus . '.' . $tempID};
			$tempStatus = 0 if (!defined $tempStatus or $tempStatus < 0);
			$tempStatus = 10 if ($tempStatus > 10);
			next if ($tempStatus eq '2' and $main::verbose < 3);

			my $tempValue = $entries->{$snmpOidEnvTempValue . '.' . $tempID};
			my $tempWarn = $entries->{$snmpOidEnvTempWarn . '.' . $tempID};
			my $tempCrit = $entries->{$snmpOidEnvTempCrit . '.' . $tempID};
			my $tempDesc = $entries->{$snmpOidEnvTempDesc . '.' . $tempID};
			#next if ($tempValue == 0);

			$tempDesc =~ s/[ ,;=]/_/g;
			$tempDesc =~ s/_$//;

			my $perfDesc = $tempDesc;
			my $exist = 0;
			$exist = 1 if (defined $chkDoubleNames{$perfDesc});
			if ($psHasMultiUnits and $exist) {
			    $perfDesc .= "_$tempID";
			}
			$chkDoubleNames{$perfDesc} = 1;
			addTemperatureToPerfdata($perfDesc, $tempValue, $tempWarn, $tempCrit)
				if (!$main::verboseTable);

			my $printID = 0;
			$printID = $1 if ($tempID =~ /\d+\.(\d+)/);
			$printID = $tempID if ($psHasMultiUnits);
			if ($verbose) {
				addStatusTopic("v",$srvTempStatus[$tempStatus],"Sensor",$printID);
				addName("v",$tempDesc);
				addCelsius("v",$tempValue, $tempWarn,$tempCrit);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and   ($tempStatus>=4 and $tempStatus!=8) 
			) {
				addStatusTopic("l",$srvTempStatus[$tempStatus],"Sensor",$printID);
				addName("l",$tempDesc);
				addCelsius("l",$tempValue, $tempWarn,$tempCrit);
				$longMessage .= "\n";
			}
		} #each sensor
	} # optChkEnvironment
} #primergyServerTemperatureSensorTable

sub primergyServerPowerSupplyTable {
	my $rcPower = shift;

	my $snmpOidPowerSupplyTable = '1.3.6.1.4.1.231.2.10.2.2.10.6.2.1.'; #sc2PowerSupplyTable
	#my $snmpOidSupplyNr	= $snmpOidPowerSupplyTable . '2'; #sc2psPowerSupplyNr
	#my $snmpOidDesignation	= $snmpOidPowerSupplyTable . '3'; #sc2PowerSupplyDesignation
	my $snmpOidIdentifier	= $snmpOidPowerSupplyTable . '4'; #sc2PowerSupplyIdentifier
	my $snmpOidStatus	= $snmpOidPowerSupplyTable . '5'; #sc2PowerSupplyStatus
	my $snmpOidLoad		= $snmpOidPowerSupplyTable . '6';#sc2psPowerSupplyLoad
	my $snmpOidMax		= $snmpOidPowerSupplyTable . '7'; #sc2psPowerSupplyNominal
	my @tableChecks = (
		$snmpOidIdentifier,
		$snmpOidStatus,
		$snmpOidLoad,
		$snmpOidMax,
	);
	my @statusText = ( "none", 
	    "unknown", "not-present", "ok", "failed", "ac-fail", 
	    "dc-fail", "critical-temperature", "not-manageable", "fan-failure-predicted", "fan-failure",
	    "power-safe-mode","non-redundant-dc-fail", "non-redundant-ac-fail", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if ($rcPower and $rcPower < 3);
	$getInfos = 1 if ($verbose or $notify);
	if ($optChkPower and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Power Supplies") if ($verbose);
		foreach my $id (@snmpIdx) {
 			my $pstatus  = $entries->{$snmpOidStatus . '.' . $id};
 			my $name = $entries->{$snmpOidIdentifier . '.' . $id};
 			my $load = $entries->{$snmpOidLoad . '.' . $id};
 			my $max = $entries->{$snmpOidMax . '.' . $id};
			$pstatus = 0 if (!defined $pstatus or $pstatus < 0);
			$pstatus = 14 if ($pstatus > 14);
			next if ($pstatus == 2 and $main::verbose < 3);
			my $printID = 0;
			$printID = $1 if ($id =~ /\d+\.(\d+)/);
			$printID = $id if ($psHasMultiUnits);
			if ($verbose) {
				addStatusTopic("v",$statusText[$pstatus],"PSU",$printID);
				addName("v",$name);
				addKeyWatt("v","CurrentLoad", $load,
					undef,undef, undef,$max);
				$variableVerboseMessage .= "\n";
			} elsif ($notify and $pstatus >=4) {
				addStatusTopic("l",$statusText[$pstatus],"PSU",$printID);
				addName("l",$name);
				addKeyWatt("l","CurrentLoad", $load,
					undef,undef, undef,$max);
				$longMessage .= "\n";
			}
		} # each
	}
	#### TODO / QUESTION PRIMERGY -w -c and performance limits for power supplies (multiple PSUs !)
} #primergyServerPowerSupplyTable
sub primergyServerPowerConsumption {
	my $powerConsumption = undef;
	# Power consumption OID
	my $snmpOidPowerMonitoringTable = '.1.3.6.1.4.1.231.2.10.2.2.10.4.5.1.'; #sc2PowerMonitoringTable
	my $snmpOidPowerConsumption	= $snmpOidPowerMonitoringTable . '5.1'; #sc2pmCurrentPowerConsumption.1
	my $snmpOidPowerStatus		= $snmpOidPowerMonitoringTable . '7.1'; #sc2pmPowerLimitStatus.1
	my $snmpOidPowerLimit		= $snmpOidPowerMonitoringTable . '8.1'; #sc2pmPowerLimitThreshold.1
	my $snmpOidPowerPercentWarning	= $snmpOidPowerMonitoringTable . '9.1'; #sc2pmPowerLimitWarning.1
	my $snmpOidPowerCriticLevel	= $snmpOidPowerMonitoringTable . '10.1'; #sc2pmRedundancyCritLevel.1 
	my @verboseText = ( "none", 
		"unknown", "ok", "warning", "error", "disabled", 
		"..unexpected..",
	);

	if (defined $optChkPower and !$main::verboseTable) { 
		$powerConsumption = trySNMPget($snmpOidPowerConsumption,"PowerConsumption");
		if (defined $powerConsumption) {
			my $status = trySNMPget($snmpOidPowerStatus,"PowerLimitStatus");
			my $limit = undef;
			my $lWarning = undef;
			my $lCritical = undef;
			my $warn = undef;
			my $notify = 0;
			if ((defined $status) && ($status > 1) && ($status < 5) ) {
				if ($status == 4) {
					$exitCode = 2;
					$notify = 1;
				}
				if ($status == 3) {
					$exitCode = 1 if ($exitCode == 0 or $exitCode == 3);
					$notify = 1;
				}
				$limit = trySNMPget($snmpOidPowerLimit,"PowerLimitThreshold");
				$lWarning = trySNMPget($snmpOidPowerPercentWarning,"PowerLimitWarning");
				$lCritical = trySNMPget($snmpOidPowerCriticLevel,"RedundancyCritLevel");
				if (defined $limit and defined $lWarning and $limit > 0) {
					$warn = ($limit / 100 ) * $lWarning;
				}
				if (defined $limit and defined $lCritical and ($lCritical <= 0)) {
					$lCritical = undef;
				}
				if ($main::verbose >= 2) {
					addTableHeader("v","Power Consumption");
					addStatusTopic("v",$verboseText[$status],"PowerConsumption",undef);
					addKeyWatt("v","Current", $powerConsumption,
						$limit,$lCritical);
					#addKeyPercent("v",undef,undef,
					#	$lWarning,undef, undef,undef);
					$variableVerboseMessage .= "\n"
				} elsif ($notify) {
					addStatusTopic("l",$verboseText[$status],"PowerConsumption",undef);
					addKeyWatt("l","Current", $powerConsumption,
						$limit,$lCritical);
					#addKeyPercent("l",undef,undef,
					#	$lWarning,undef, undef,undef);
					$longMessage .= "\n"
				}
			}

			addPowerConsumptionToPerfdata($powerConsumption, $limit,$lCritical, undef,undef)
				if (!$main::verboseTable);
		} # PowerConsumption available
	} #optChkPower
} #primergyServerPowerConsumption

sub primergyServer_ParentMMB {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.3.1.1.'; #sc2ManagementNodeTable
	my $snmpOidAddress	= $snmpOidTable . '4'; #sc2UnitNodeAddress
	my $snmpOidName		= $snmpOidTable . '7'; #sc2UnitNodeName
 	my $snmpOidClass	= $snmpOidTable . '8'; #sc2UnitNodeClass
	my @tableChecks = (
		$snmpOidAddress,
		$snmpOidName,
		$snmpOidClass,
	);
	#my @classText = ( "none",
	#	 "unknown", "primary", "secondary", "management-blade",	"secondary-remote", #"secondary-remote-backup", "baseboard-controller", "..unexpected..",
	#);
	{ 
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidAddress, 2);
		foreach my $id (@snmpIdx) {
 			my $address  = $entries->{$snmpOidAddress . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
 			my $classid = $entries->{$snmpOidClass . '.' . $id};
  			next if ($classid and $classid != 4);
			addKeyValue("n","ParentMMB", $address);
			addKeyValue("n","ParentMMBName", $name) if ($name and $address and $name ne $address);
		}
	}
} #primergyServer_ParentMMB
sub primergyServer_ManagementNodeTable {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.3.1.1.'; #sc2ManagementNodeTable
	my $snmpOidAddress	= $snmpOidTable . '4'; #sc2UnitNodeAddress
	my $snmpOidName		= $snmpOidTable . '7'; #sc2UnitNodeName
 	my $snmpOidClass	= $snmpOidTable . '8'; #sc2UnitNodeClass
 	my $snmpOidMac		= $snmpOidTable . '9'; #sc2UnitNodeMacAddress
	#	... this mac is a string with 0x....
 	my $snmpOidModel	= $snmpOidTable . '12'; #sc2UnitNodeControllerModel
	my @tableChecks = (
		$snmpOidAddress,
		$snmpOidName,
		$snmpOidClass,
		$snmpOidMac,	
		$snmpOidModel,
	);
	my @classText = ( "none",
		 "unknown", "primary", "secondary", "management-blade",	"secondary-remote", "secondary-remote-backup", "baseboard-controller", "..unexpected..",
	);
	if (($optChkSystem and $main::verbose >=3) or $main::verboseTable == 311) { 
		#### QUESTION: is this relevant for somebody ?
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidAddress, 2);

		addTableHeader("v","Management Nodes");
		foreach my $id (@snmpIdx) {
 			my $address  = $entries->{$snmpOidAddress . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
 			my $classid = $entries->{$snmpOidClass . '.' . $id};
  			my $mac = $entries->{$snmpOidMac . '.' . $id};
			my $model = $entries->{$snmpOidModel . '.' . $id};
			$classid = 0 if (!defined $classid or $classid < 0);
			$classid = 8 if ($classid > 8);
			
			addStatusTopic("v",undef, "Node", $id=~m/\d+\.(\d+)/);
			addIP("v",$address);
			addName("v",$name) if ($name and !($name eq $address));
			addKeyLongValue("v","ControllerType", $model);
			addKeyValue("v","Class", $classText[$classid]) if ($classid > 2);
			addMAC("v", $mac);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primergyServer_ManagementNodeTable
sub primergyServer_ServerTable {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.4.1.1.'; #sc2ServerTable
 	my $snmpOidMemory	= $snmpOidTable . '2'; #sc2srvPhysicalMemory
	my $snmpOidBootStatus	= $snmpOidTable . '4'; #sc2srvCurrentBootStatus
 	my $snmpOidUuid		= $snmpOidTable . '7'; #sc2srvUUID
	my @bootText = ( "none", 
		"unknown", "off", "no-boot-cpu", "self-test", "setup",
		"os-boot", "diagnostic-boot", "os-running", "diagnostic-running", "os-shutdown", 
		"diagnostic-shutdown", "reset", "..unexpected..",
	);
	my @tableChecks = (
		$snmpOidMemory,
		$snmpOidBootStatus,
		$snmpOidUuid,
	);
	if (($optChkSystem and $main::verbose >=3) or $main::verboseTable == 411) { 
		#### QUESTION: is this relevant for somebody ?
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidUuid, 1);
		addTableHeader("v","Server Table");
		foreach my $id (@snmpIdx) {
 			my $memory  = $entries->{$snmpOidMemory . '.' . $id};
 			my $bstatus = $entries->{$snmpOidBootStatus . '.' . $id};
 			my $uuid = $entries->{$snmpOidUuid . '.' . $id};
			$bstatus = 0 if (!defined $bstatus or $bstatus < 0);
			$bstatus = 13 if ($bstatus > 13);

			addStatusTopic("v",undef,"Server",$id);
			addKeyValue("v","UUID", $uuid);
			addKeyMB("v","Memory", $memory);
			addKeyValue("v","BootStatus", $bootText[$bstatus]) if ($bstatus > 0);
			$variableVerboseMessage .= "\n";
		}
	} #verbose
} #primergyServer_ServerTable
our $cxChassisSerial	= undef;
our $cxChassisName	= undef;
our $cxChassisModel	= undef;
our $cxChassesLocation	= undef;
our $cxChassisContact	= undef;
sub primergyServerUnitTable {
	my $genNotify = shift;
	my $snmpOidUnitTable = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable
	my $snmpOidUnitId	= $snmpOidUnitTable .'1' ;#sc2uUnitId
	my $snmpOidClass	= $snmpOidUnitTable .'2' ;#sc2UnitClass
	my $snmpOidCabNr	= $snmpOidUnitTable .'3' ;#sc2UnitCabinetNr
	my $snmpOidDesignation	= $snmpOidUnitTable .'4' ;#sc2UnitDesignation
	my $snmpOidModel	= $snmpOidUnitTable .'5' ;#sc2UnitModelName
	my $snmpOidSerial	= $snmpOidUnitTable .'7' ;#sc2UnitSerialNumber
	my $snmpOidLocation	= $snmpOidUnitTable .'8' ;#sc2UnitLocation
	my $snmpOidContact	= $snmpOidUnitTable .'9' ;#sc2UnitContact
	my $snmpOidAdmURL	= $snmpOidUnitTable .'10' ;#sc2UnitAdminURL
	my $snmpOidWWN		= $snmpOidUnitTable .'14' ;#sc2UnitWorldWideName
	my $snmpOidManIP	= $snmpOidUnitTable .'18' ;#sc2ManagementIpAddress

	# .1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.4.1 Name of Server

	my @tableChecks = (
		$snmpOidUnitId, $snmpOidClass, $snmpOidCabNr, $snmpOidDesignation, $snmpOidModel,
		$snmpOidSerial, $snmpOidLocation, $snmpOidContact, $snmpOidAdmURL, $snmpOidWWN,
		$snmpOidManIP,
	);
	my @classText = ( "none",
		"unknown", "standardServer", "storageExtension", "bladeServerChassis", "bladeServer",
		"clusterNode", "multiCodeChassis", "multiNodeServer", "virtualServer", "virtualPartition",
		"systemboardInPartition", "unexpected12", "unexpected13", "unexpected14", "unexpected15", 
		"unexpected16", "unexpected17", "unexpected18", "unexpected19", "virtualServerVmware",
		"virtualServerHyperV", "virtualServerXen", "virtualServerPan", "..unexpected..", 
	);
	{ # SC2 UnitTable 2.3 => 231
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidClass, 1);

		addTableHeader("v","Unit Table") if ($main::verboseTable == 231 or ($psHasMultiUnits and $main::verbose>=3));
		foreach my $snmpID (@snmpIDs) {
			my $unitid = $entries->{$snmpOidUnitId . '.' . $snmpID};
			my $class = $entries->{$snmpOidClass . '.' . $snmpID};
			my $cabnr = $entries->{$snmpOidCabNr . '.' . $snmpID};
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			my $location = $entries->{$snmpOidLocation . '.' . $snmpID};
			my $contact = $entries->{$snmpOidContact . '.' . $snmpID};
			my $admURL = $entries->{$snmpOidAdmURL . '.' . $snmpID};
			my $wwn = $entries->{$snmpOidWWN . '.' . $snmpID};
			my $manIp = $entries->{$snmpOidManIP . '.' . $snmpID};
			$class = 0 if (!defined $class or $class < 0);
			$class = 24 if ($class > 24);
			if ($class == 7 and $serial) { #multiCodeChassis
				$cxChassisSerial	= $serial;
				$cxChassisName		= $designation;
				$cxChassisModel		= $model;
				$cxChassesLocation	= $location;
				$cxChassisContact	= $contact;
			}
			$psHasMultiUnits = 1 if ($cabnr and $cabnr > 10); # ignore CX400
			if (!$genNotify and ($main::verboseTable == 231 or $psHasMultiUnits)) { 
				addStatusTopic("v",undef, "Unit", $unitid);
				addKeyIntValue("v","CabinetNr", $cabnr);
				addSerialIDs("v",$serial, undef);
				addKeyValue("v","Class",$classText[$class]) if ($class);
				addName("v",$designation);
				addProductModel("v",undef, $model);
				addLocationContact("v",$location, $contact);
				addAdminURL("v",$admURL);
				addKeyValue("v","ManagementIP", $manIp);
				addKeyValue("v","WWN", $wwn);
				$variableVerboseMessage .= "\n";
			}
			if ($genNotify and $snmpID == 1) {
				addAdminURL("n",$admURL);
				addKeyLongValue("n","ManagementIP",$manIp);
				addProductModel("n",undef, $model);
				# ATTENTION - print MultiNodeInformation as last part
			}
		} # each
	} #
	# iRMC: Name seems to be the HousingType
} #primergyServerUnitTable
our $svAgentVersion = undef;
sub primergyServerAgentInfo {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.2.10.2.2.10.1.'; #sc2AgentInfo
	my $snmpOidAgtID	= $snmpOidAgentInfoGroup . '1.0'; #sc2AgentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0'; #sc2AgentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0'; #sc2AgentVersion
	{ # for SSM check the agent version mmust be fetched
		my $id = trySNMPget($snmpOidAgtID,"sc2AgentInfo");
		my $company = trySNMPget($snmpOidCompany,"sc2AgentInfo");
		my $version = trySNMPget($snmpOidVersion,"sc2AgentInfo");
		$svAgentVersion = $version;
		if ($main::verbose >= 3 and ($id || $company || $version)) {
			addStatusTopic("v",undef,"AgentInfo", undef);
			addKeyLongValue("v","Ident",$id);
			addKeyValue("v","Version",$version) if ($version !~ m/\s/);
			addKeyLongValue("v","Version",$version) if ($version =~ m/\s/);
			addKeyLongValue("v","Company",$company);
			addMessage("v","\n");
		} #found something
	} #verbose
} #primergyServerAgentInfo
sub primergyServerSystemInformation {
	#my $serial = shift;
	my $snmpOidUnitTable = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable
	my $snmpOidName		= $snmpOidUnitTable . '4.1'; #sc2UnitDesignation.1
	my $snmpOidModel	= $snmpOidUnitTable . '5.1'; #sc2UnitModelName.1
	my $snmpOidLocation	= $snmpOidUnitTable . '8.1'; #sc2UnitLocation.1
	my $snmpOidContact	= $snmpOidUnitTable . '9.1'; #sc2UnitContact.1
	my $snmpOidAdminUrl	= $snmpOidUnitTable . '10.1'; #sc2UnitAdminURL.1
	my $snmpOidManIPAddress = $snmpOidUnitTable . '18.1'; #sc2ManagementIpAddress.1
	RFC1213sysinfoToLong(); # Always for the detection of iRMC
	{
		if (($main::verbose) || ($exitCode==1) || ($exitCode==2)) {
			my $name = trySNMPget($snmpOidName,"sc2UnitTable");
			my $model = trySNMPget($snmpOidModel,"sc2UnitTable");
			my $location = trySNMPget($snmpOidLocation,"sc2UnitTable");
			my $contact = trySNMPget($snmpOidContact,"sc2UnitTable");
			my $admURL = trySNMPget($snmpOidAdminUrl,"sc2UnitTable");
			my $manageIP = trySNMPget($snmpOidManIPAddress,"sc2UnitTable");
			if ($location or $contact or $admURL or $manageIP or $model) {
				{
					addAdminURL("n",$admURL);
					addKeyLongValue("n","ManagementIP",$manageIP);
					addProductModel("n",undef, $model);
					if ($cxChassisName or $cxChassisModel) {
						my $isiRMC = undef;
						$isiRMC = 1 if ($notifyMessage =~ m/iRMC/);
						my $hasOSmib = svOsInfoTable();
						inv_sniInventoryOSinformation() if (!$hasOSmib);

						$notifyMessage .= "\n";
						addStatusTopic("n", undef,"Multi Node System", undef);
						addSerialIDs("n", $cxChassisSerial, undef);
						addName("n", $cxChassisName);
						addLocationContact("n",$cxChassesLocation, $cxChassisContact);
						addProductModel("n",undef, $cxChassisModel);
					}
				} # new notify
			} # infos available
		} # verbose or warning or error
	} 
} #primergyServerSystemInformation
our $psVoltageStatus = undef;
our $psCPUStatus = undef;
our $psMemoryStatus = undef;
our $psFanStatus = undef;
our $psTempStatus = undef;
our $psPowerStatus = undef;
our @psStatusText = ( "ok", "warning", "error", "unknown", ); #sc2Status in NAGIOS return values
sub primergyServerStatusComponentTable {
	my $snmpOidStatusGroup = '.1.3.6.1.4.1.231.2.10.2.2.10.8.'; #sc2Status
	my $snmpOidOverallStatus	= $snmpOidStatusGroup . '1.0'; #sc2AgentStatus
	my @statusText = ( "none",
		"ok", "warning", "error", undef, "unknown",
		"..unexpected..",
	);
	my %codeMap = (			1       =>      0,
					2       =>      1,
					3       =>      2,
					4       =>      2,
					5	=>	3,);
	my $snmpOidStatusComponentTable = $snmpOidStatusGroup . '2.1.'; #sc2StatusComponentTable
	my $snmpOidBoot		= $snmpOidStatusComponentTable . '3'; #sc2csStatusBoot
	my $snmpOidPower	= $snmpOidStatusComponentTable . '4'; #sc2csStatusPowerSupply
	my $snmpOidTemp		= $snmpOidStatusComponentTable . '5'; #sc2csStatusTemperature
	my $snmpOidFan		= $snmpOidStatusComponentTable . '6'; #sc2csStatusFans
	my $snmpOidVolt		= $snmpOidStatusComponentTable . '7'; #sc2csStatusVoltages
	my $snmpOidCpu		= $snmpOidStatusComponentTable . '8'; #sc2csStatusCpu
	my $snmpOidMem		= $snmpOidStatusComponentTable . '9'; #sc2csStatusMemoryModule
	my @tableChecks = (
		$snmpOidBoot, $snmpOidPower, $snmpOidTemp,
		$snmpOidFan, $snmpOidVolt, $snmpOidCpu, $snmpOidMem,
	);
	{
		#my $overallStatus = trySNMPget($snmpOidOverallStatus, "sc2AgentStatus");
		#$variableVerboseMessage .= "Overall: $statusText[$overallStatus]" if (defined $overallStatus);
		#$variableVerboseMessage .= "\n" if (defined $overallStatus);

		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		@snmpIDs = getSNMPTableIndex($entries, $snmpOidPower, 1);
		addTableHeader("v","Status Component Table") 
		    if (($main::verbose > 2 and $optChkSystem) or $main::verboseTable == 821);
		foreach my $snmpID (@snmpIDs) {
			my $boot = $entries->{$snmpOidBoot . '.' . $snmpID};
			my $power = $entries->{$snmpOidPower . '.' . $snmpID};
			my $temp = $entries->{$snmpOidTemp . '.' . $snmpID};
			my $fan = $entries->{$snmpOidFan . '.' . $snmpID};
			my $volt = $entries->{$snmpOidVolt . '.' . $snmpID};
			my $cpu = $entries->{$snmpOidCpu . '.' . $snmpID};
			my $mem = $entries->{$snmpOidMem . '.' . $snmpID};
			#$psHasMultiUnits = 1 if ($snmpID > 1);
			$boot = 0 if (!defined $boot or $boot < 0);
			$boot = 6 if ($boot > 6);
			if (($main::verbose > 2 and $optChkSystem) or $main::verboseTable == 821) { 
				addStatusTopic("v",undef,"Unit", $snmpID);
				addComponentStatus("v","Boot", $statusText[$boot]) if (defined $boot); 
				addComponentStatus("v","PowerSupplies", $statusText[$power]) 
					if (defined $power); 
				addComponentStatus("v","Temperatures", $statusText[$temp]) 
					if (defined $temp); 
				addComponentStatus("v","Cooling", $statusText[$fan]) if (defined $fan); 
				addComponentStatus("v","Voltages", $statusText[$volt]) if (defined $volt); 
				addComponentStatus("v","CPUs", $statusText[$cpu]) if (defined $cpu); 
				addComponentStatus("v","MemoryModules", $statusText[$mem]) 
					if (defined $mem); 
				$variableVerboseMessage .= "\n";
			}
			$volt = 5 if ($volt and $volt > 5);
			$cpu = 5 if ($cpu and $cpu > 5);
			$mem = 5 if ($mem and $mem > 5);
			$fan = 5 if ($fan and $fan > 5);
			$temp = 5 if ($temp and $temp > 5);
			$psVoltageStatus = $codeMap{$volt} if ($volt and !defined $psVoltageStatus);
			$psCPUStatus = $codeMap{$cpu} if ($cpu and !defined $psCPUStatus);
			$psMemoryStatus = $codeMap{$mem} if ($mem and !defined $psMemoryStatus);
			$psFanStatus = $codeMap{$fan} if ($fan and !defined $psFanStatus);
			$psTempStatus = $codeMap{$temp} if ($temp and !defined $psTempStatus);
			$psPowerStatus = $codeMap{$power} if ($power and !defined $psPowerStatus);

			if ($snmpID == $snmpIDs[0]) {
			    addComponentStatus("m", "Cooling", $statusText[$fan])
				    if ($optChkEnv_Fan and defined $psFanStatus);
			    addComponentStatus("m", "TemperatureSensors", $statusText[$temp])
				    if ($optChkEnv_Temp and defined $psTempStatus);
			}
		} # each
	}
} #primergyServerStatusComponentTable

sub primergyServerSystemBoardTable {
	my $snmpOidSystemBoardTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.1.1.'; #sc2SystemBoardTable
	my $snmpOidModel	= $snmpOidSystemBoardTable . '3'; #sc2SystemBoardModelName
	my $snmpOidProduct	= $snmpOidSystemBoardTable . '4'; #sc2SystemBoardProductNumber
	my $snmpOidSerial	= $snmpOidSystemBoardTable . '6'; #sc2SystemBoardSerialNumber
	my $snmpOidDesignation	= $snmpOidSystemBoardTable . '7'; #sc2SystemBoardDesignation
	my @tableChecks = (
		$snmpOidModel, $snmpOidProduct, $snmpOidSerial, $snmpOidDesignation,
	);
	if ($main::verboseTable == 611) { #PS SystemBoardTable
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidSerial, 2);

		addTableHeader("v","System Board Table");
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $product = $entries->{$snmpOidProduct . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			{ 
				addStatusTopic("v",undef,"SystemBoard", $snmpID);
				addSerialIDs("v",$serial, undef);
				addName("v",$designation);
				addProductModel("v",$product, $model);
				$variableVerboseMessage .= "\n";
			}
		} # each
	}
} #primergyServerSystemBoardTable
sub primergyServerVoltageTable {
	my $snmpOidVoltageTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.3.1.'; #sc2VoltageTable
	my $snmpOidDesignation		= $snmpOidVoltageTable . '3'; #sc2VoltageDesignation
	my $snmpOidStatus		= $snmpOidVoltageTable . '4'; #sc2VoltageStatus
	my $snmpOidCurrent		= $snmpOidVoltageTable . '5'; #sc2VoltageCurrentValue mV
	my $snmpOidMin			= $snmpOidVoltageTable . '7'; #sc2VoltageMinimumLevel
	my $snmpOidMax			= $snmpOidVoltageTable . '8'; #sc2VoltageMaximumLevel
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidStatus, $snmpOidCurrent, $snmpOidMin, $snmpOidMax,
	);
	my @statusText = ( "none",
		"unknown", "not-available", "ok", "too-low", "too-high",
		"out-of-range",	"warning", "..unexpected..",
	);
	return if (!defined $psVoltageStatus);
	if ($optChkHardware or $optChkVoltage) {
		#msg .= " Voltages($psStatusText[$psVoltageStatus])";
		addComponentStatus("m", "Voltages", $psStatusText[$psVoltageStatus]);
	}
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if ($psVoltageStatus and $psVoltageStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if ( ($optChkSystem or $optChkHardware or $optChkVoltage) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Voltages") if ($verbose);
		foreach my $id (@snmpIdx) {
 			my $status  = $entries->{$snmpOidStatus . '.' . $id};
 			my $name = $entries->{$snmpOidDesignation . '.' . $id};
			my $current = $entries->{$snmpOidCurrent . '.' . $id};
  			my $min = $entries->{$snmpOidMin . '.' . $id};
 			my $max = $entries->{$snmpOidMax . '.' . $id};
			$name =~ s/[ ,;=]/_/g;
			$status = 0 if (!defined $status or $status < 0);
			$status = 8 if ($status > 8);
			if ($verbose) {
				addStatusTopic("v",$statusText[$status],"Voltage",$id=~m/\d+\.(\d+)/);
				addName("v",$name);
				addmVolt("v",$current, undef,undef, $min,$max);
				$variableVerboseMessage .= "\n";
			} 
			elsif ($notify and ($status >= 4)
			) {
				addStatusTopic("l",$statusText[$status],"Voltage",$id=~m/\d+\.(\d+)/);
				addName("l",$name);
				addmVolt("l",$current, undef,undef, $min,$max);
				$longMessage .= "\n";
			}
		} #each
	}
} #primergyServerVoltageTable
sub primergyServerCPUTable {
	my $snmpOidCPUTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.4.1.'; #sc2CPUTable
	my $snmpOidDesignation	= $snmpOidCPUTable . '3'; #sc2cpuDesignation
	my $snmpOidStatus	= $snmpOidCPUTable . '4'; #sc2cpuStatus
	my $snmpOidModel	= $snmpOidCPUTable . '3'; #sc2cpuModelName
	my $snmpOidSpeed	= $snmpOidCPUTable . '8'; #sc2cpuCurrentSpeed MHz
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidStatus, $snmpOidModel, $snmpOidSpeed, 
	);
	my @statusText = ( "none",
		"unknown", "not-present", "ok", "disabled", "error",
		"failed", "missing-termination", "prefailure-warning", "..unexpected..",
	);
	return if (!defined $psCPUStatus);
	if ($optChkHardware or $optChkCPU) {
		#msg .= " CPUs($psStatusText[$psCPUStatus])";
		addComponentStatus("m", "CPUs", $psStatusText[$psCPUStatus]);
	}
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if ($psCPUStatus and $psCPUStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkHardware or $optChkSystem or $optChkCPU) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","CPU Table") if ($verbose);
		foreach my $id (@snmpIdx) {
 			my $status  = $entries->{$snmpOidStatus . '.' . $id};
 			my $name = $entries->{$snmpOidDesignation . '.' . $id};
			my $model = $entries->{$snmpOidModel . '.' . $id};
			my $speed = $entries->{$snmpOidSpeed . '.' . $id};
			$model = undef if ($model and $name and $model eq $name);
 			$name =~ s/[ ,;=]/_/g;
			$status = 0 if (!defined $status or $status < 0);
			$status = 9 if ($status > 9);
			if ($verbose) {
				addStatusTopic("v",$statusText[$status],"CPU",$id=~m/\d+\.(\d+)/);
				addName("v",$name);
				addProductModel("v",undef, $model);
				addKeyMHz("v","Speed", $speed);
				$variableVerboseMessage .= "\n";
			} 
			elsif ($notify and ($status >= 5)
			) {
 				addStatusTopic("l",$statusText[$status],"CPU",$id=~m/\d+\.(\d+)/);
				addName("l",$name);
				addProductModel("l",undef, $model);
				addKeyMHz("l","Speed", $speed);
				$longMessage .= "\n";
			}
		} #each
	}
} #primergyServerCPUTable
sub primergyServerMemoryModuleTable {
	my $snmpOidMemoryModuleTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.5.1.'; #sc2MemoryModuleTable
	my $snmpOidDesignation	= $snmpOidMemoryModuleTable . '3'; #sc2memModuleDesignation
	my $snmpOidStatus	= $snmpOidMemoryModuleTable . '4'; #sc2memModuleStatus
	my $snmpOidCapacity	= $snmpOidMemoryModuleTable . '6'; #sc2memModuleCapacity MB
	my $snmpOidType		= $snmpOidMemoryModuleTable . '9'; #sc2memModuleType
	my $snmpOidFrequency	= $snmpOidMemoryModuleTable . '14'; #sc2memModuleFrequency MHz
	my $snmpOidMaxFrequency	= $snmpOidMemoryModuleTable . '15'; #sc2memModuleMaxFrequency
	my @tableChecks = (
		$snmpOidDesignation, $snmpOidStatus, $snmpOidCapacity, $snmpOidType, 
		$snmpOidFrequency, $snmpOidMaxFrequency, 
	);
	my @statusText = ( "none",
		"unknown", "not-present", "ok", "disabled", "error",
		"failed", "prefailure-predicted", "hot-spare", "mirror", "raid",
		"hidden", "..unexpected..",
	);
	return if (!defined $psMemoryStatus);
	if ($optChkHardware or $optChkMemMod) {
		#msg .= " MemoryModules($psStatusText[$psMemoryStatus])";
		addComponentStatus("m", "MemoryModules", $psStatusText[$psMemoryStatus]);
	}
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if ($psMemoryStatus and $psMemoryStatus < 3);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkHardware or $optChkSystem or $optChkMemMod) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","Memory Modules Table") if ($verbose);
		foreach my $id (@snmpIdx) {
 			my $status  = $entries->{$snmpOidStatus . '.' . $id};
 			my $name = $entries->{$snmpOidDesignation . '.' . $id};
			my $capacity = $entries->{$snmpOidCapacity . '.' . $id};
			my $type = $entries->{$snmpOidType . '.' . $id};
			my $frequency = $entries->{$snmpOidFrequency . '.' . $id};
			my $max = $entries->{$snmpOidMaxFrequency . '.' . $id};
			$status = 0 if (!defined $status or $status < 0);
			$status = 12 if ($status > 12);
 			$name =~ s/[ ,;=]/_/g;
			if ($verbose and $status != 2) {
				addStatusTopic("v",$statusText[$status],"Memory",$id=~m/\d+\.(\d+)/);
				addName("v",$name);
				addKeyLongValue("v","Type", $type);
				addKeyMB("v","Capacity", $capacity);
				addKeyMHz("v","Frequency", $frequency);
				addKeyMHz("v","Frequency-Max", $max);
				$variableVerboseMessage .= "\n";
			} 
			elsif ($notify and ($status >= 5)
			) {
				addStatusTopic("l",$statusText[$status],"Memory",$id=~m/\d+\.(\d+)/);
				addName("l",$name);
				addKeyLongValue("l","Type", $type);
				addKeyMB("l","Capacity", $capacity);
				addKeyMHz("l","Frequency", $frequency);
				addKeyMHz("l","Frequency-Max", $max);
				$longMessage .= "\n";
			}
		} #each
	}
} #primergyServerMemoryModuleTable

sub primergyServerPerformanceTable {
	my $osmib = shift;
	my $snmpOidPerformanceTable = '.1.3.6.1.4.1.231.2.10.2.2.10.4.3.1.'; #sc2PerformanceTable (2)
	my $snmpOidType		= $snmpOidPerformanceTable . '3'; #sc2PerformanceType
	my $snmpOidObjNr	= $snmpOidPerformanceTable . '4'; #sc2PerformanceObjectNr
	my $snmpOidName		= $snmpOidPerformanceTable . '5'; #sc2PerformanceName
	my $snmpOidValue	= $snmpOidPerformanceTable . '6'; #sc2PerformanceName
	my @tableChecks = (
		$snmpOidType, $snmpOidObjNr, $snmpOidName, $snmpOidValue, 
	);
	my @typeText = ( "none",
		"cpu", "cpu-overall", "pci-load", "pci-efficiency", "pci-transfer",
		"memory-physical", "memory-total", "memory-percent", "..unexpected..",
	);
        #            cpu:             Load of a single CPU in percent
        #            cpu-overall:     Overall CPU load in percent
        #            pci-load:        PCI bus load in percent
        #            pci-efficiency:  PCI bus efficiency in percent (100% is optimum)
        #            pci-transfer:    PCI bus transfer rate in MBytes/sec.
        #            memory-physical: Physical memory usage in MBytes
        #            memory-total:    Total memory usage (physical + virtual) in MBytes
        #            memory-percent:  Physical memory usage in percent"
	my $getInfos = 0;
	$getInfos = 1 if ($main::verbose >= 3 and $optChkHardware and !$main::verboseTable);
	$getInfos = 1 if ($optChkCpuLoadPerformance);
	$getInfos = 1 if ($optChkMemoryPerformance);
	my $totalCPU = undef;
	my @cpu = (0,0,0,0,0, 0,0,0,0,0, -1,);
	my $virtualMemMBytes = undef;
	my $physMemPercent = undef;
	my $physMemMBytes = undef;
	if ($getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidType, 2);

		addTableHeader("v","Hardware Performance Table") 
			if ($entries and $main::verbose >= 3 and !$main::verboseTable);
		my $maxInd = 0;
		foreach my $id (@snmpIdx) {
 			my $type  = $entries->{$snmpOidType . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
			my $objNr = $entries->{$snmpOidObjNr . '.' . $id};
			my $value = $entries->{$snmpOidValue . '.' . $id};
			$type = 0 if (!defined $type or $type < 0);
			$type = 9 if ($type > 9);
			if ($main::verbose >= 3 and !$main::verboseTable) {
				addStatusTopic("v",undef,$typeText[$type],undef);
				addKeyLongValue("v","Data","$name" . "[$objNr]") if ($type and $type == 1);
				addKeyLongValue("v","Data",$name) if ($type and $type != 1);
				if ($type == 5) {
					addKeyMB("v","Value", $value);
					$variableVerboseMessage .= "/sec";
				} elsif ($type and $type > 5 and $type <= 7) {
					addKeyMB("v","Value", $value);
				} else {
					addKeyPercent("v","Value", $value);
				}
				$variableVerboseMessage .= "\n";
			} 
			if ($optChkCpuLoadPerformance and defined $value) {
				$totalCPU = $value if ($type == 2);
				$cpu[$objNr]=$value if ($type == 1);
				$maxInd = $objNr if ($objNr > $maxInd);
			}
			if ($optChkMemoryPerformance and defined $value) {
				$physMemMBytes = $value if ($type == 6);
				$physMemMBytes = negativeValueCheck($physMemMBytes);
				$virtualMemMBytes = $value if ($type == 7 and ($name =~ m/virtual/));
				$virtualMemMBytes = negativeValueCheck($virtualMemMBytes);
				$physMemPercent = $value if ($type == 8);
				$physMemPercent = negativeValueCheck($physMemPercent);
			}
		} # each
		if ($maxInd) {
			$maxInd++;
			$cpu[$maxInd] = -1;
		}
	} #verbose
	if ($optChkCpuLoadPerformance) {
		if (!$osmib) {
		    addKeyPercent("m", "Total", $totalCPU, undef,undef, undef,undef);
		    addPercentageToPerfdata("Total", $totalCPU, undef, undef)
			    if (!$main::verboseTable);
		}
		if (defined $totalCPU) {
		    my $i = 0;
		    for ($i=0; $cpu[$i] != -1;$i++) {
			    addPercentageToPerfdata("CPU[$i]", $cpu[$i], undef, undef)
				    if (!$main::verboseTable);
		    } #each
		}
		$exitCode = 0 if (defined $totalCPU);
	} #cpu load
	if ($optChkMemoryPerformance) {
		my $warn = ($optWarningLimit?$optWarningLimit:0);
		my $crit = ($optCriticalLimit?$optCriticalLimit:0);
		$warn = undef if ($warn == 0);
		$crit = undef if ($crit == 0);
		addKeyPercent("m", "Physical-Memory", $physMemPercent, undef,undef, undef,undef);
		addKeyMB("m","Physical-Memory", $physMemMBytes);
		addKeyMB("m","Virtual-Memory", $virtualMemMBytes);
		addPercentageToPerfdata("Physical-Memory", $physMemPercent, $warn, $crit)
			if (!$main::verboseTable);
		$exitCode = 0;
		$exitCode = 1 if ($warn and $physMemPercent and $physMemPercent > $warn);
		$exitCode = 2 if ($crit and $physMemPercent and $physMemPercent > $crit);
		$exitCode = 3 if (!$physMemPercent and !$physMemMBytes and !$virtualMemMBytes);
	} #memory
} #primergyServerPerformanceTable
sub primergyServerDriverMonitoring {
	#--      sc2DriverMonitorComponentTable:	1.3.6.1.4.1.231.2.10.2.2.10.11.1
	#--      sc2DriverMonitorMessageTable:		1.3.6.1.4.1.231.2.10.2.2.10.11.2
	my $snmpOidDrvMonCompTable = '.1.3.6.1.4.1.231.2.10.2.2.10.11.1.1.'; #sc2DriverMonitorComponentTable(3)
	my $snmpOidClass	= $snmpOidDrvMonCompTable . '1'; #sc2drvmonCompClass
	my $snmpOidName		= $snmpOidDrvMonCompTable . '3'; #sc2drvmonCompName
	my $snmpOidType		= $snmpOidDrvMonCompTable . '4'; #sc2drvmonCompType
	my $snmpOidDrvName	= $snmpOidDrvMonCompTable . '5'; #sc2drvmonCompDriverName
	my $snmpOidLocation	= $snmpOidDrvMonCompTable . '6'; #sc2drvmonCompLocationDesignation
	my $snmpOidStatus	= $snmpOidDrvMonCompTable . '8'; #sc2drvmonCompStatus
	my @tableChecks = (
		$snmpOidClass, $snmpOidName, $snmpOidType, $snmpOidDrvName, $snmpOidLocation, 
		$snmpOidStatus,
	);
	my @classText = ("none",
		"other", "software", "network",	"storage", "..unexpected..",
	);
	my @typeText = ("none",
		"other", "pci", "usb",  "..unexpected..",
	);
	my @statusText = ("none",
		"ok", "warning", "error", undef, "unknown",
		 "..unexpected..",
	);
	my $getInfos = 0;
	my $verboseInfo = 0;
	my $notokInfo = 0;
	$verboseInfo = 1 
		if ($main::verbose >= 2 or $main::verboseTable == 1111);
	$notokInfo = 1
		if (!$main::verboseTable and $resultDrvMonitor 
		and ($resultDrvMonitor == 1 or $resultDrvMonitor == 2));
	$getInfos = 1 if ($verboseInfo or $notokInfo);
	if ($getInfos) { #sc2DriverMonitorComponentTable
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 3);

		addTableHeader("v","Driver Monitor Component Table");
		foreach my $id (@snmpIdx) {
			my $name = $entries->{$snmpOidName . '.' . $id};
			my $status = $entries->{$snmpOidStatus . '.' . $id};
			my $class = $entries->{$snmpOidClass . '.' . $id};
			my $type = $entries->{$snmpOidType . '.' . $id};
			my $drvName = $entries->{$snmpOidDrvName . '.' . $id};
			my $location = $entries->{$snmpOidLocation . '.' . $id};
			$status = 0 if (!defined $status or $status < 0);
			$status = 6 if ($status > 6);
			$class = 0 if (!defined $class or $class < 0);
			$class = 5 if ($class > 5);
			$type = 0 if (!defined $type or $type < 0);
			$type = 4 if ($type > 4);
			next if (($status == 4 or $status > 5) and $main::verbose < 3);
			$id =~ m/(\d+\.)\d+\.(\d+)/;
			my $shortid = $1 . $2;
			if ($verboseInfo) {
				addStatusTopic("v",$statusText[$status],"DrvMon",
					$shortid);
				addKeyLongValue("v","Name", $name);
				addKeyValue("v","Class",$classText[$class]) if ($class);
				addKeyValue("v","Type",$typeText[$type]) if ($type);
				addKeyValue("v","Driver",$drvName);
				addKeyLongValue("v","Location",$location);
				$variableVerboseMessage .= "\n";
			} elsif ($notokInfo and ($status == 2 or $status == 3)) {
				addStatusTopic("l",$statusText[$status],"DrvMon",
					$shortid);
				addKeyLongValue("l","Name", $name);
				addKeyValue("l","Class",$classText[$class]) if ($class);
				addKeyValue("l","Type",$typeText[$type]) if ($type);
				addKeyValue("l","Driver",$drvName);
				addKeyLongValue("l","Location",$location);
				$longMessage .= "\n";
			}
		} # each
	}
} #primergyServerDriverMonitoring
sub primergyServerTrustedPlatformModuleTable { # --> INVENTORY
	my $snmpOidTpmTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.8.1.';
	#sc2TrustedPlatformModuleTable - 1 index
	my $snmpOidHardwareAvailable	= $snmpOidTpmTable . '2'; #sc2tpmHardwareAvailable
	my $snmpOidBiosEnabled		= $snmpOidTpmTable . '3'; #sc2tpmBiosEnabled
	my $snmpOidEnabled		= $snmpOidTpmTable . '4'; #sc2tpmEnabled
	my $snmpOidActivated		= $snmpOidTpmTable . '5'; #sc2tpmActivated
	my $snmpOidOwnership		= $snmpOidTpmTable . '6'; #sc2tpmOwnership
	my @tableChecks = (
		$snmpOidHardwareAvailable, $snmpOidBiosEnabled, $snmpOidEnabled, 
		$snmpOidActivated, $snmpOidOwnership, 
	);
	my @UFTtext = ("none", 
		"unknown", "false", "true", "..unexpected..",);
	my $verboseInfo = 0;
	$verboseInfo = 1 if ($main::verbose >= 2);
	{
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidHardwareAvailable, 1);

		addTableHeader("v","Trusted Platform Module Table");
		my $tmpExitCode = 3;
		foreach my $id (@snmpIdx) {
			my $hwAvailable = $entries->{$snmpOidHardwareAvailable . '.' . $id};
			my $biosEnabled = $entries->{$snmpOidBiosEnabled . '.' . $id};
			my $enabled = $entries->{$snmpOidEnabled . '.' . $id};
			my $activated = $entries->{$snmpOidActivated . '.' . $id};
			my $ownership = $entries->{$snmpOidOwnership . '.' . $id};
			$hwAvailable = 0 if (!defined $hwAvailable or $hwAvailable < 0);
			$hwAvailable = 4 if ($hwAvailable > 3);
			$biosEnabled = 0 if (!defined $biosEnabled or $biosEnabled < 0);
			$biosEnabled = 4 if ($biosEnabled > 3);
			$enabled = 0 if (!defined $enabled or $enabled < 0);
			$enabled = 4 if ($enabled > 3);
			$activated = 0 if (!defined $activated or $activated < 0);
			$activated = 4 if ($activated > 3);
			$ownership = 0 if (!defined $ownership or $ownership < 0);
			$ownership = 4 if ($ownership > 3);
		
			if ($verboseInfo) {
				addStatusTopic("v",$UFTtext[$enabled],"tpm", $id);
				addKeyValue("v","HardwareAvailable", $UFTtext[$hwAvailable]);
				addKeyValue("v","BiosEnabled", $UFTtext[$biosEnabled]);
				addKeyValue("v","Activated", $UFTtext[$activated]);
				addKeyValue("v","Qwnership", $UFTtext[$ownership]);
				$variableVerboseMessage .= "\n";
			} 
			$tmpExitCode = addTmpExitCode(0, $tmpExitCode) if ($enabled == 3 and $activated == 3);
			$tmpExitCode = addTmpExitCode(1, $tmpExitCode) if ($activated == 2);
			$tmpExitCode = addTmpExitCode(2, $tmpExitCode) if ($enabled == 2 and $activated == 2);
		} # each
		addExitCode($tmpExitCode);
		addComponentStatus("m","TrustedPlatformModule","unknown")
			if ($tmpExitCode==3);
		addComponentStatus("m","TrustedPlatformModule","disabled")
			if ($tmpExitCode==2);
		addComponentStatus("m","TrustedPlatformModule","deactivated")
			if ($tmpExitCode==1);
		addComponentStatus("m","TrustedPlatformModule","activated")
			if ($tmpExitCode==0);
	}
} #primergyServerTrustedPlatformModuleTable
sub primergyServerSerialID {	#... this function makes only a "try" to get infos
	# Server identification (via serial number)
	my $snmpOidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1'; #sc2UnitSerialNumber.1
	{	
		my $serverID = trySNMPget($snmpOidServerID,"ServerID");
		addSerialIDs("n", $serverID, undef);
	}
} # primergyServerSerialID
sub primergyServer {
	# Server identification (via serial number)
	my $snmpOidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1'; #sc2UnitSerialNumber.1
	my $snmpOidSc2Test = $snmpOidServerID;

	#--------------------------------------------
	mibTestSNMPget($snmpOidSc2Test,"SV-Agent") 
		if ($optChkSystem or $optChkEnvironment or $optChkPower or $optChkUpdate);
	# fetch ServerID
	primergyServerUnitTable(0); # for CX400 search $serverID
	$msg = '';
	$msg .= "-" if (defined $optChkSystem);
	if (defined $optChkSystem and $cxChassisSerial) {
		addKeyValue("m", "Chassis-ID", $cxChassisSerial);
	}
	#primergyServerSerialID(); .. this function makes only a "try" to get infos
	{ 
		$serverID = simpleSNMPget($snmpOidServerID,"ServerID");
		if ($serverID) {
			addSerialIDs("m", $serverID, undef) if (defined $optChkSystem);
			addSerialIDs("n", $serverID, undef);
		}
	}
	$msg .= " -" if (defined $optChkSystem);
	primergyServerStatusComponentTable();
	primergyServerUnitTable(0) if ($psHasMultiUnits);
	# fetch central system state
	sieStatusAgent();
	if ($exitCode == 4) { # iRMC and no STATUS.mib
	    $exitCode = 3;
	    $resultOverall = 3;
	    $resultEnv = 3;
	    $resultPower = 3;
	    $resultSystem = 3;

	    $resultEnv = addTmpExitCode($psFanStatus, $resultEnv);
	    $resultEnv = addTmpExitCode($psTempStatus, $resultEnv);
	    $resultPower = addTmpExitCode($psPowerStatus, $resultPower);
	    $resultSystem = addTmpExitCode($psMemoryStatus, $resultSystem);
	    $resultSystem = addTmpExitCode($psCPUStatus, $resultSystem);
	    $resultSystem = addTmpExitCode($psVoltageStatus, $resultSystem);
	    $resultOverall = addTmpExitCode($resultEnv, $resultOverall);
	    $resultOverall = addTmpExitCode($resultPower, $resultOverall);
	    $resultOverall = addTmpExitCode($resultSystem, $resultOverall);

	    addComponentStatus("m", "Environment", $psStatusText[$resultEnv])
		if ($optChkEnvironment);
	    addComponentStatus("m", "PowerSupplies", $psStatusText[$resultPower])
		if ($optChkPower);
	    addComponentStatus("m", "SystemBoard", $psStatusText[$resultSystem])
		if ($optChkSystem);
	}
	if ($setOverallStatus) {
		$exitCode = $resultOverall if (defined $resultOverall);
	} else { # mixture of options
		$exitCode = 3;
		addExitCode($resultEnv) if (defined $optChkEnvironment and $optChkEnvironment==1);
		addExitCode($resultPower) if (defined $optChkPower and $optChkPower==1);
		addExitCode($resultSystem) if (defined $optChkSystem and $optChkSystem==1);
		if (defined $optChkStorage and $optChkStorage) {
			if (defined $resultMassStorage) {
				addExitCode($resultMassStorage) if ($optChkStorage==1);
			} elsif ($optChkStorage != 999) {
				#$exitCode = 3;
				$msg .= "- No MassStorage information - ";
			}
		}
		if ((defined $optChkDrvMonitor) and $optChkDrvMonitor) {
			if (defined $resultDrvMonitor) {
				addExitCode($resultDrvMonitor) if ($optChkDrvMonitor==1);
			} elsif ($optChkDrvMonitor != 999) {
				#$exitCode = 3;
				$msg .= "- No Driver Monitor information - ";
			}
		}
		if ($optChkHardware and $optChkHardware==1) { # double if system was set
			addExitCode($psCPUStatus);
			addExitCode($psVoltageStatus);
			addExitCode($psMemoryStatus);
		}
		addExitCode($psFanStatus) if ($optChkEnv_Fan and $optChkEnv_Fan==1);
		addExitCode($psTempStatus) if ($optChkEnv_Temp and $optChkEnv_Temp==1);
		addExitCode($psCPUStatus) if ($optChkCPU and $optChkCPU==1);
		addExitCode($psVoltageStatus) if ($optChkVoltage and $optChkVoltage==1);
		addExitCode($psMemoryStatus) if ($optChkMemMod and $optChkMemMod==1);
	} # mixture

	primergyServerSystemInformation();
	primergyServerAgentInfo();
	my $ssmURL = socket_getSSM_URL($svAgentVersion);
	addKeyValue("n","MonitorURL", $ssmURL);
	addKeyValue("n", "SpecifiedAddress", $optHost) 
	    if ($optHost and $optAdminHost);
	addKeyValue("n","AdminAddress", $optAdminHost) 
	    if ($optHost and $optAdminHost);
	primergyServer_ManagementNodeTable();
	primergyServer_ServerTable();
	
	chomp($msg);
	
	# process fan information
	primergyServerFanTable($resultEnv);
	
	# now check the temperatures
	primergyServerTemperatureSensorTable($resultEnv);

	# power supply
	primergyServerPowerSupplyTable($resultPower);

	# get Powerconsumption
	primergyServerPowerConsumption();


	#hardware ... part of SystemBoard status
	primergyServerSystemBoardTable();
	primergyServerVoltageTable();
	primergyServerCPUTable();
	primergyServerMemoryModuleTable();
	
	my $osmib = svOsPropertyTable();
	primergyServerPerformanceTable($osmib);
	sieStComponentTable();

	my $isiRMC = undef;
	$isiRMC = 1 if ($notifyMessage =~ m/iRMC/);
	if (!$cxChassisName and !$cxChassisModel) {
	    my $hasOSmib = svOsInfoTable($isiRMC);
	    inv_sniInventoryOSinformation() if (!$hasOSmib);
	}
	primergyServer_ParentMMB();

	#MassStorage -> RAID.mib
	if (defined $resultMassStorage and !$isiRMC) { # component MassStorage exist
		RAID();
	} # MassStorage
	if (defined $resultDrvMonitor and $optChkDrvMonitor) {
		primergyServerDriverMonitoring();
	}
} # end primergyServer
sub primergyServerNotifyData {
	$notifyMessage = undef;
	primergyServerSerialID();
	RFC1213sysinfoToLong();
	primergyServerAgentInfo();
	my $ssmURL = socket_getSSM_URL($svAgentVersion);
	addKeyValue("n","MonitorURL", $ssmURL);
	primergyServerUnitTable(1);
	addKeyValue("n", "SpecifiedAddress", $optHost) 
	    if ($optHost and $optAdminHost);
	addKeyValue("n","AdminAddress", $optAdminHost) 
	    if ($optHost and $optAdminHost);
	my $isiRMC = undef;
	$isiRMC = 1 if ($notifyMessage and $notifyMessage =~ m/iRMC/);
	my $hasOSmib = svOsInfoTable($isiRMC);
	inv_sniInventoryOSinformation() if (!$hasOSmib);
	primergyServer_ParentMMB();
	if ($cxChassisName or $cxChassisModel) {
		$notifyMessage .= "\n";
		addStatusTopic("n", undef,"Multi Node System", undef);
		addSerialIDs("n", $cxChassisSerial, undef);
		addName("n", $cxChassisName);
		addLocationContact("n",$cxChassesLocation, $cxChassisContact);
		addProductModel("n",undef, $cxChassisModel);
	}
} # primergyServerNotifyData

#----------- SVUpdate.mib
  sub svupdComponentTable {
	return if (!$optChkUpdDiffList and !$optChkUpdInstList);
	my $save_exitCode = $exitCode;
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.12.1.2.2.1.'; #svupdComponentTable
	    # ATTENTION - no double 1.1. at the end here !
 	my $snmpOidPath		= $snmpOidTable .  '2'; #svupdComponentPath
 	my $snmpOidCompVersion	= $snmpOidTable .  '5'; #svupdComponentVersion
 	my $snmpOidInstVersion	= $snmpOidTable .  '6'; #svupdComponentInstalledVersion
 	my $snmpOidRepos	= $snmpOidTable .  '8'; #svupdRepos2InstRanking
 	my $snmpOidMandatory	= $snmpOidTable .  '9'; #svupdIsMandatoryComponent
 	my $snmpOidSeverity	= $snmpOidTable . '11'; #svupdVendorSeverity
 	my $snmpOidReboot	= $snmpOidTable . '15'; #svupdRebootRequired
 	my $snmpOidDuration	= $snmpOidTable . '16'; #svupdInstallDuration; sec
 	my $snmpOidSize		= $snmpOidTable . '17'; #svupdDownloadSize; MB
 	my $snmpOidVendor	= $snmpOidTable . '20'; #svupdVendor
 	my $snmpOidInRepos	= $snmpOidTable . '22'; #svupdBinaryLoaded
	my @yesnoText = ( "none", 
	    "yes", "no", "..unexpected..",
	);
	my @rankText = ( "none", 
	    "unknown", "repositoryNewest", "repositoryNewer", "equal", "highestDowngrade",
	    "repositoryOlder", "..unexpected..",
	);
	my @severityText = ( "none", 
	    "optional", "recommended", "mandatory", "..unexpected..",
	);
	my @rebootText = ( "none", 
	    "no", "immediate", "asConfigured", "dynamic", "..unexpected..",
	);
	my @tableChecks = (
		$snmpOidPath		,
		$snmpOidCompVersion	,
		$snmpOidInstVersion	,
		$snmpOidRepos	,
		$snmpOidMandatory,	
		$snmpOidSeverity,	
		$snmpOidReboot	,
		$snmpOidDuration,	
		$snmpOidSize	,	
		$snmpOidVendor	,
		$snmpOidInRepos	,
	);
	# the output directory
	handleOutputDirectory() if ($optOutdir);
	return if ($exitCode == 2);

	my $fileHost = $optHost;
	$fileHost =~ s/[^A-Z,a-z,.,\-,0-9]//g;
	{
		my $printLimit = 10;
		my $printIndex = 0;
		$printLimit = 0 if ($main::verbose >= 3);
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidPath, 1);
		my $save_verboseMessage = $variableVerboseMessage;
		$variableVerboseMessage = '';
		foreach my $id (@snmpIdx) {
 			my $path	= $entries->{$snmpOidPath		. '.' . $id};
			my $cvers	= $entries->{$snmpOidCompVersion	. '.' . $id};
			my $ivers	= $entries->{$snmpOidInstVersion	. '.' . $id};
			my $rank	= $entries->{$snmpOidRepos		. '.' . $id};
			my $mandatory   = $entries->{$snmpOidMandatory		. '.' . $id};
			my $severity	= $entries->{$snmpOidSeverity		. '.' . $id};
			my $reboot	= $entries->{$snmpOidReboot		. '.' . $id};
			my $duration	= $entries->{$snmpOidDuration		. '.' . $id};
			my $size	= $entries->{$snmpOidSize		. '.' . $id};
			my $vendor	= $entries->{$snmpOidVendor		. '.' . $id};
			my $inRepos	= $entries->{$snmpOidInRepos		. '.' . $id};

			$mandatory = 3 if (!defined $mandatory or $mandatory < 0 or $mandatory > 2);
			$rank = 7 if (!defined $rank or $rank < 0 or $rank > 6);
			$severity = 4 if (!defined $severity or $severity < 0 or $severity > 3);
			$reboot  =5 if (!defined $reboot or $reboot < 0 or $reboot > 4);

			my $uptodate = 0;
			$uptodate = 1 if ($rank and ($rank < 2 or $rank > 3) and $optChkUpdInstList);

			next if (!$cvers or !$ivers);
			next if ($rank and ($rank < 2 or $rank > 3) and $main::verbose < 9 and $optChkUpdDiffList);

			#my $sevExitCode = undef;
			#$sevExitCode = $severity - 1 if ($severity > 0 and $severity <= 3);
			#addExitCode($sevExitCode) if (defined $sevExitCode and $optChkUpdDiffList);

			if (!$printLimit or $printIndex < $printLimit) {
			    addStatusTopic("l",$severityText[$severity], "",undef) if (!$uptodate);
			    addStatusTopic("l","uptodate", "",undef) if ($uptodate);
				addKeyLongValue("l", "Path", $path);
			    addMessage("l", "\n");
			    addMessage("l", "#\t");
				addKeyLongValue("l", "Installed", $ivers);
			    addMessage("l", "\n");
			    addMessage("l", "#\t");
				addKeyLongValue("l", "Available", $cvers);
			    addMessage("l", "\n");
			    if ($main::verbose >= 2) {
				addMessage("l", "#\t");
				    addKeyLongValue("l", "Vendor", $vendor);
				addMessage("l", "\n");
				addMessage("l", "#\t");
				    addKeyValue("l", "Rank", $rankText[$rank]) if ($main::verbose >= 9);
				    addKeyValue("l", "Mandatory", $yesnoText[$mandatory]);
				    addKeyIntValue("l", "Severity", $severityText[$severity]);
				addMessage("l", "\n");
				addMessage("l", "#\t");
				    addKeyMB("l", "Size", $size);
				    addKeyIntValueUnit("l", "Duration", $duration, "sec");
				    addKeyIntValue("l", "RebootMode", $rebootText[$reboot]);
				addMessage("l", "\n");
			    }
			    $printIndex++;
			}
			if ($optOutdir) { # file
			    addMessage("v",$path);
			    addMessage("v", "\n");
			    addMessage("v", "#\t");
				addKeyLongValue("v", "Installed", $ivers);
			    addMessage("v", "\n");
			    addMessage("v", "#\t");
				addKeyLongValue("v", "Available", $cvers);
			    addMessage("v", "\n");
			    
			    addMessage("v", "#\t");
				addKeyLongValue("v", "Vendor", $vendor);
			    addMessage("v", "\n");
			    addMessage("v", "#\t");
				addKeyValue("v", "Mandatory", $yesnoText[$mandatory]);
				addKeyValue("v", "Severity", $severityText[$severity]);
			    addMessage("v", "\n");
			    addMessage("v", "#\t");
				addKeyMB("v", "Size", $size);
				addKeyValueUnit("v", "Duration", $duration, "sec");
				addKeyValue("v", "RebootMode", $rebootText[$reboot]);
			    addMessage("v", "\n");		
			}
		} # foreach
		addMessage("l", "#...\n") if ($printLimit and $printLimit == $printIndex);
		if ($optOutdir) {
		    writeTxtFile($fileHost, "DIFF", $variableVerboseMessage);
		}
		$variableVerboseMessage = $save_verboseMessage;
	} # get table
  } #svupdComponentTable

  sub primergyUpdateAgent {
	my $snmpOidUpdServerStatus = '.1.3.6.1.4.1.231.2.10.2.12.1.3.1.0'; #svupdServerStatus
	#	    1=OK, 2=Warn, 3=Crit, 4=Unknown
	my @updStateText = ('none', 'ok', 'warning', 'critical', 'unknown', "..undefined..",);
	return if (!$optChkUpdate);
	my $updstate = undef;
	{
	    $updstate = mibTestSNMPget($snmpOidUpdServerStatus,"SV-UpdateAgent", 1); # skip internal RFC1213
	    addStatusTopic("v", undef, "UpdateStatus", undef);
	    $updstate = -1 if (!defined $updstate);
	    addKeyIntValue("v", "NumericState", $updstate);
	    $updstate = 4 if ($updstate < 1);
	    $updstate = 4 if ($updstate > 4);
	    addExitCode($updstate -1);
	    addComponentStatus("m", "UpdateStatus", $updStateText[$updstate]);
	} # status
	if (($updstate and $updstate >= 2 and $updstate != 4 and $optChkUpdDiffList) 
	or  ($updstate and $updstate >= 1 and $updstate != 4 and $optChkUpdInstList)) {
	    svupdComponentTable();
	}
  } # primergyUpdateAgent
#----------- RAID functions
our $raidLDrive = undef;
our $raidPDevice = undef;
our $raidCtrl = undef;
our @raidCompStatusText = ( "none",	"ok", "prefailure", "failure", "..unexpected..",);
our @raidInterfaceText = ( "none",
	"other", "scsi", "ide",	"ieee1394", "sata",
	"sas", "fc", "..unexpected..",
);
sub RAIDoverallStatus {
	my $snmpOidSrvStatusGroup = '.1.3.6.1.4.1.231.2.49.1.3.'; #svrStatus
	my $snmpOidOverall	= $snmpOidSrvStatusGroup . '4.0'; #svrStatusOverall
	my $overall = trySNMPget($snmpOidOverall, "svrStatus");
	if (defined $overall) {
		$overall = 0 if ($overall < 0);
		$overall = 4 if ($overall > 4);
		#$raidCompStatusText[$overall]
		$exitCode = 0 if ($overall == 1);
		$exitCode = 1 if ($overall == 2);
		$exitCode = 2 if ($overall == 3);
	}
	$resultMassStorage = $exitCode;
	if (!defined $resultOverall) { # Status.mib is not existing
		#msg .= "MassStorage($raidCompStatusText[$overall])" 
		addComponentStatus("m", "MassStorage", $raidCompStatusText[$overall])
			if (defined $overall);
		addKeyLongValue("l","Hint", "RAID Only Check - status is RAID status");
	}
} #RAIDoverallStatus
sub RAIDsvrStatus {
	my $snmpOidSrvStatusGroup = '.1.3.6.1.4.1.231.2.49.1.3.'; #svrStatus
	my $snmpOidLogicDrive	= $snmpOidSrvStatusGroup . '1.0'; #svrStatusLogicalDrives
	my $snmpOidPhysDevice	= $snmpOidSrvStatusGroup . '2.0'; #svrStatusPhysicalDevices
	my $snmpOidController	= $snmpOidSrvStatusGroup . '3.0'; #svrStatusControllers
	my $snmpOidOverall	= $snmpOidSrvStatusGroup . '4.0'; #svrStatusOverall
	if ($main::verbose >=2 or $resultMassStorage != 0) {
		my $logicDrive = trySNMPget($snmpOidLogicDrive, "svrStatus");
		my $phyDevice = trySNMPget($snmpOidPhysDevice, "svrStatus");
		my $controller = trySNMPget($snmpOidController, "svrStatus");
		my $overall = trySNMPget($snmpOidOverall, "svrStatus");
		my $found = 0;
		if ($logicDrive or $phyDevice or $controller or $overall) {
			$found = 1;
			$raidLDrive = $logicDrive;
			$raidPDevice = $phyDevice;
			$raidCtrl = $controller;
		}
		if (defined $overall) {
			$overall = 0 if ($overall < 0);
			$overall = 4 if ($overall > 4);
		}
		if (defined $controller) {
			$controller = 0 if ($controller < 0);
			$controller = 4 if ($controller > 4);
		}
		if (defined $phyDevice) {
			$phyDevice = 0 if ($phyDevice < 0);
			$phyDevice = 4 if ($phyDevice > 4);
		}
		if (defined $logicDrive) {
			$logicDrive = 0 if ($logicDrive < 0);
			$logicDrive = 4 if ($logicDrive > 4);
		}
		addTableHeader("v","RAID Overview");
		if ($found and $main::verbose >=2) {
			$variableVerboseMessage .= "\n";
			addStatusTopic("v",$raidCompStatusText[$overall],
				"RAID -", undef);
			addComponentStatus("v","Controller", $raidCompStatusText[$controller])
				if (defined $controller);
			addComponentStatus("v","PhysicalDevice", $raidCompStatusText[$phyDevice])
				if (defined $phyDevice);
			addComponentStatus("v","LogicalDrive", $raidCompStatusText[$logicDrive])
				if (defined $logicDrive);
			$variableVerboseMessage .= "\n";
		} elsif ($found and $resultMassStorage != 0) {
			addStatusTopic("l",$raidCompStatusText[$overall],
				"RAID -", undef);
			addComponentStatus("l","Controller", $raidCompStatusText[$controller])
				if (defined $controller);
			addComponentStatus("l","PhysicalDevice", $raidCompStatusText[$phyDevice])
				if (defined $phyDevice);
			addComponentStatus("l","LogicalDrive", $raidCompStatusText[$logicDrive])
				if (defined $logicDrive);
			$longMessage .= "\n";
		}
	}
} #RAIDsvrStatus
sub RAIDsvrCtrlTable {
	#--		:		
	my $snmpOidSvrCtrlTable = '.1.3.6.1.4.1.231.2.49.1.4.2.1.'; #svrCtrlTable (1)
	my $snmpOidModel	= $snmpOidSvrCtrlTable .  '2'; #svrCtrlModelName
	my $snmpOidDescription	= $snmpOidSvrCtrlTable .  '5'; #svrCtrlBusLocationText
	my $snmpOidCache	= $snmpOidSvrCtrlTable . '13'; #svrCtrlCacheSize MB
	my $snmpOidBbuStatus	= $snmpOidSvrCtrlTable . '14'; #svrCtrlBBUStatus
	my $snmpOidStatus	= $snmpOidSvrCtrlTable . '15'; #svrCtrlStatus
	my $snmpOidInterface	= $snmpOidSvrCtrlTable . '16'; #svrCtrlInterface
	my $snmpOidSerial	= $snmpOidSvrCtrlTable . '21'; #svrCtrlSerialNo
	my $snmpOidDriverName	= $snmpOidSvrCtrlTable . '22'; #svrCtrlDriverName
	my $snmpOidDisplayName	= $snmpOidSvrCtrlTable . '25'; #svrCtrlDisplayName
	my $snmpOidHostName	= $snmpOidSvrCtrlTable . '26'; #svrCtrlHostName
	my @tableChecks = (
		$snmpOidModel, $snmpOidDescription, $snmpOidCache, $snmpOidBbuStatus, $snmpOidStatus, 
		$snmpOidInterface, $snmpOidSerial, $snmpOidDriverName, $snmpOidDisplayName, $snmpOidHostName, 
	);
	my @bbuStatusText = ( "none",
		"notAvailable",	"onLine", "onBattery", "onBatteryLow", "charging",
		"discharging", "failed", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (defined $raidCtrl and $raidCtrl > 1);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkSystem or $optChkStorage) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 1);
		addTableHeader("v","RAID Controller") if ($verbose);
		foreach my $id (@snmpIdx) {
 			my $model  = $entries->{$snmpOidModel . '.' . $id};
 			my $descr = $entries->{$snmpOidDescription . '.' . $id};
			my $cache = $entries->{$snmpOidCache . '.' . $id};
			my $bbuStatus = $entries->{$snmpOidBbuStatus . '.' . $id};
			my $status = $entries->{$snmpOidStatus . '.' . $id};
			my $interface  = $entries->{$snmpOidInterface . '.' . $id};
 			my $serial = $entries->{$snmpOidSerial . '.' . $id};
			my $driver = $entries->{$snmpOidDriverName . '.' . $id};
			my $display = $entries->{$snmpOidDisplayName . '.' . $id};
			my $hostname = $entries->{$snmpOidHostName . '.' . $id};
			$status = 0 if (!defined $status or $status < 0);
			$status = 4 if ($status > 4);
			$interface = 0 if (!defined $interface or $interface < 0);
			$interface = 8 if ($interface > 8);
			$bbuStatus = 8 if ($bbuStatus and $bbuStatus > 8);

			if ($verbose) {
				addStatusTopic("v",$raidCompStatusText[$status],
				"RAIDCtrl", $id);
				addSerialIDs("v",$serial, undef);
				addKeyLongValue("v","Name", $display);
				addKeyLongValue("v","Description", $descr);
				addHostName("v",$hostname);
				addKeyMB("v","Cache", $cache);
				addKeyValue("v","BBU", $bbuStatusText[$bbuStatus])
					if (defined $bbuStatus and $bbuStatus > 1);
				addKeyValue("v","Interface", $raidInterfaceText[$interface])
					if (defined $interface);
				addKeyValue("v","Driver", $driver);
				addProductModel("v",undef, $model) if (!defined $display);
				$variableVerboseMessage .= "\n";
			} elsif ($notify and $status > 1) {
				addStatusTopic("l",$raidCompStatusText[$status],
				"RAIDCtrl", $id);
				addSerialIDs("l",$serial, undef);
				addKeyLongValue("l","Name", $display);
				addKeyLongValue("l","Description", $descr);
				addHostName("l",$hostname);
				addKeyValue("l","BBU", $bbuStatusText[$bbuStatus])
					if (defined $bbuStatus and $bbuStatus > 1);
				addProductModel("l",undef, $model) if (!defined $display);
				$longMessage .= "\n";
			}
		} # each
	} #getInfos
} #RAIDsvrCtrlTable
sub RAIDsvrPhysicalDeviceTable {
	my $snmpOidPhysicalDeviceTable = '.1.3.6.1.4.1.231.2.49.1.5.2.1.'; #svrPhysicalDeviceTable (4)
	my $snmpOidNodel	= $snmpOidPhysicalDeviceTable .  '5'; #svrPhysicalDeviceModelName
	my $snmpOidGB		= $snmpOidPhysicalDeviceTable .  '7'; #svrPhysicalDeviceCapacity GB
	my $snmpOidType		= $snmpOidPhysicalDeviceTable .  '9'; #svrPhysicalDeviceType
	my $snmpOidInterface	= $snmpOidPhysicalDeviceTable . '11'; #svrPhysicalDeviceInterface
	my $snmpOidErrors	= $snmpOidPhysicalDeviceTable . '12'; #svrPhysicalDeviceErrors
	my $snmpOidBadBlocks	= $snmpOidPhysicalDeviceTable . '13'; #svrPhysicalDeviceNrBadBlocks
	my $snmpOidSmartStatus	= $snmpOidPhysicalDeviceTable . '14'; #svrPhysicalDeviceSmartStatus
	my $snmpOidStatus	= $snmpOidPhysicalDeviceTable . '15'; #svrPhysicalDeviceStatus
	my $snmpOidSerial	= $snmpOidPhysicalDeviceTable . '17'; #svrPhysicalDeviceSerialNumber
	#my $snmpOidExStatus	= $snmpOidPhysicalDeviceTable . '20'; #svrPhysicalDeviceStatusEx
	my $snmpOidMB		= $snmpOidPhysicalDeviceTable . '21'; #svrPhysicalDeviceCapacityMB MB
	my $snmpOidEnclosure	= $snmpOidPhysicalDeviceTable . '22'; #svrPhysicalDeviceEnclosureNumber
	my $snmpOidSlot		= $snmpOidPhysicalDeviceTable . '23'; #svrPhysicalDeviceSlot
	my $snmpOidDisplay	= $snmpOidPhysicalDeviceTable . '24'; #svrPhysicalDeviceDisplayName
	my $snmpOidPower	= $snmpOidPhysicalDeviceTable . '26'; #svrPhysicalDevicePowerStatus
	my @tableChecks = (
		$snmpOidNodel, $snmpOidGB, $snmpOidType, $snmpOidInterface, $snmpOidErrors, 
		$snmpOidBadBlocks, $snmpOidSmartStatus, $snmpOidStatus, $snmpOidSerial, 
		$snmpOidMB, $snmpOidEnclosure, $snmpOidSlot, $snmpOidDisplay, $snmpOidPower, 
	);
	my @typeText = ( "none",
		"other", "disk", "tape", "printer", "processor",
		"writeOnce", "cdRomDvd", "scanner", "optical", "jukebox",
		"communicationDevice", undef, undef, undef, undef,
		undef, undef, "host", "..unexpected..",
	); # host(98) -> 18
	my @smartStatusText = ( "none",
		"ok", "failurePredicted", "smartNotAvailable", "smartMonitoringDisabled",
		"..unexpected..",
	);
	my @statusText = ( "none",
		"unknown", "noDisk", "online", "ready",	"failed",
		"rebuilding", "hotspareGlobal",	"hotspareDedicated", "offline",	"unconfiguredFailed",
		"formatting", "dead", "..unexpected..",
	);
	my @powerText = ( "none",
		"active", "stopped", "transition", "..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (defined $raidPDevice and $raidPDevice > 1);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkSystem or $optChkStorage) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 4);

		addTableHeader("v","RAID Physical Device")	if ($verbose);
		foreach my $id (@snmpIdx) {
			my $model  = $entries->{$snmpOidNodel . '.' . $id};
 			my $gb = $entries->{$snmpOidGB . '.' . $id};
			my $type = $entries->{$snmpOidType . '.' . $id};
			my $interface  = $entries->{$snmpOidInterface . '.' . $id};
			my $errors = $entries->{$snmpOidErrors . '.' . $id};
			my $badblocks = $entries->{$snmpOidBadBlocks . '.' . $id};
			my $smart = $entries->{$snmpOidSmartStatus . '.' . $id};
			my $status = $entries->{$snmpOidStatus . '.' . $id};
 			my $serial = $entries->{$snmpOidSerial . '.' . $id};
			my $mb = $entries->{$snmpOidMB . '.' . $id};
			my $enclosure = $entries->{$snmpOidEnclosure . '.' . $id};
			my $slot = $entries->{$snmpOidSlot . '.' . $id};
			my $display = $entries->{$snmpOidDisplay . '.' . $id};
			my $power = $entries->{$snmpOidPower . '.' . $id};
			$interface = 0 if (!defined $interface or $interface < 0);
			$interface = 8 if ($interface > 8);

			$type = 0 if (!defined $type or $type < 0);
			$type = $type - 80 if ($type and $type > 90);
			$type = 19 if (($type >= 12 and $type <= 17) or $type > 19);
			$status = 0 if (!defined $status or $status < 0);
			$status = 13 if ($status > 13);
			$power = 0 if (!defined $power or $power < 0);
			$power = 4 if ($power > 4);

			if ($verbose) {
				my $ctrl = undef;
				$ctrl = $1 if ($id =~ m/^([^\.]+)/);

				if (defined $smart and ($smart == 1 or $smart == 2)) {
					addStatusTopic("v",$smartStatusText[$smart], undef, undef);
				}
				addStatusTopic("v",$statusText[$status], "PhysicalDevice", '');
				addKeyLongValue("v","Name", $display);
				addSerialIDs("v",$serial, undef);
				addKeyValue("v","CntErrors",$errors);
				addKeyValue("v","CntBadBlocks",$badblocks);
				addKeyValue("v","SmartStatus",$smartStatusText[$smart])
					if ($smart and $smart > 2 and $smart < 6);
				addKeyValue("v","PowerStatus",$powerText[$power]) if ($power);
				addKeyUnsignedIntValue("v","EnclosureNr",$enclosure);
				addKeyUnsignedIntValue("v","SlotNr",$slot);
				addKeyUnsignedIntValue("v","Ctrl",$ctrl);
				if ($gb) {
					addKeyGB("v","Capacity", $gb);
				} elsif ($mb) {
					addKeyMB("v","Capacity", $mb);
				}
				addKeyValue("v","Interface",$raidInterfaceText[$interface]) if ($interface);
				addKeyValue("v","Type",$typeText[$type]) if ($type);
				addProductModel("v",undef, $model) if (!defined $display);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and (      (defined $smart and $smart == 2) 
				or (defined $status and $status > 4 and (!defined $smart or $smart != 1)) )
			) {
				if (defined $smart and ($smart == 1 or $smart == 2)) {
					addStatusTopic("l",$smartStatusText[$smart], undef, undef);
				}
				addStatusTopic("l",$statusText[$status], "PhysicalDevice", '');
				addKeyLongValue("l","Name", $display);
				addSerialIDs("l",$serial, undef);
				addKeyValue("l","CntErrors",$errors);
				addKeyValue("l","CntBadBlocks",$badblocks);
				addKeyUnsignedIntValue("l","EnclosureNr",$enclosure);
				addKeyUnsignedIntValue("l","SlotNr",$slot);
				addKeyValue("l","Interface",$raidInterfaceText[$interface]) if ($interface);
				addKeyValue("l","Type",$typeText[$type]) if ($type);
				addProductModel("l",undef, $model) if (!defined $display);
				$longMessage .= "\n";
			}
		} # each
	} #getInfos
} #RAIDsvrPhysicalDeviceTable
sub RAIDsvrLogicalDriveTable {
	my $snmpOidLogicalDriveTable = '.1.3.6.1.4.1.231.2.49.1.6.2.1.'; #svrLogicalDriveTable (2)
	my $snmpOidSize		= $snmpOidLogicalDriveTable .  '4'; #svrLogicalDriveTotalSize GB
	my $snmpOidLevel	= $snmpOidLogicalDriveTable .  '5'; #svrLogicalDriveRaidLevel
	my $snmpOidStatus	= $snmpOidLogicalDriveTable . '10'; #svrLogicalDriveStatus
	my $snmpOidName		= $snmpOidLogicalDriveTable . '11'; #svrLogicalDriveName
	my $snmpOidOSDev	= $snmpOidLogicalDriveTable . '14'; #svrLogicalDriveOSDeviceName
	my $snmpOidDisplay	= $snmpOidLogicalDriveTable . '20'; #svrLogicalDriveDisplayName (try)
	my @tableChecks = (
		$snmpOidSize, $snmpOidLevel, $snmpOidStatus, $snmpOidName, $snmpOidOSDev, 
	);
	my @levelText = ( "none",
		"unknown", "raid0", "raid01", "raid1", "raid1e",
		"raid10", "raid3", "raid4", "raid5", "raid50",
		"raid5e", "raid5ee", "raid6", "concat",	"single",
		"raid60", "raid1e0", "..unexpected..",		
	);
	my @statusText = ( "none",
		"unknown", "online", "degraded", "offline", "rebuilding",
		"verifying", "initializing", "morphing", "partialDegraded",
		"..unexpected..",
	);
	my $getInfos = 0;
	my $verbose = 0;
	my $notify = 0;
	$verbose = 1 if ($main::verbose >= 2 and !$main::verboseTable);
	$notify = 1 if (defined $raidLDrive and $raidLDrive > 1);
	$getInfos = 1 if ($verbose or $notify);
	if (($optChkSystem or $optChkStorage) and $getInfos) {
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		@snmpIdx = getSNMPTableIndex($entries, $snmpOidStatus, 2);

		addTableHeader("v","RAID Logical Drive") if ($verbose);
		foreach my $id (@snmpIdx) {
			my $status = $entries->{$snmpOidStatus . '.' . $id};
			my $size = $entries->{$snmpOidSize . '.' . $id};
			my $level = $entries->{$snmpOidLevel . '.' . $id};
			my $name = $entries->{$snmpOidName . '.' . $id};
			my $osdev = $entries->{$snmpOidOSDev . '.' . $id};
			my $display = trySNMPget($snmpOidDisplay . '.' . $id,"svrLogicalDriveTable");
			$level = 0 if (!defined $level or $level < 0);
			$level = 18 if ($level > 18);
			$status = 0 if (!defined $status or $status < 0);
			$status = 11 if ($status > 11);

			if ($verbose) {
				addStatusTopic("v",$statusText[$status], 
					"LogicalDrive", $id);
				addKeyLongValue("v","Name", $display) if ($display);
				addKeyLongValue("v","Name", $name) if ($name and !defined $display);
				addKeyLongValue("v","OSDeviceName", $osdev);
				addKeyValue("v","Level", $levelText[$level]) if ($level);
				addKeyGB("v","TotalSize", $size);
				$variableVerboseMessage .= "\n";
			} elsif ($notify
			and (defined $status and $status > 2)
			) {
				addStatusTopic("l",$statusText[$status], 
					"LogicalDrive", $id);
				addKeyLongValue("l","Name", $display) if ($display);
				addKeyLongValue("l","Name", $name) if ($name and !defined $display);
				addKeyLongValue("l","OSDeviceName", $osdev);
				addKeyValue("l","Level", $levelText[$level]) if ($level);
				addKeyGB("l","TotalSize", $size);
				$longMessage .= "\n";
			}
		} # each
	} #getInfos
} #RAIDsvrLogicalDriveTable
sub RAID {
	# RAID.mib
	#my $snmpOidRaidMib = '.1.3.6.1.4.1.231.2.49.'; #fscRAIDMIB
	if ($optChkSystem or $optChkStorage) {
		RAIDsvrStatus();
		RAIDsvrCtrlTable();
		RAIDsvrPhysicalDeviceTable();
		RAIDsvrLogicalDriveTable();
	} #optChkSystem
} # RAID
#------------ Storage ?
  sub storageOverallStatus {
	# Status.mib
	my $snmpOidPrefix = '1.3.6.1.4.1.231.2.10.2.11.'; #sieStatusAgent
	my $snmpOidSysStat		= $snmpOidPrefix . '2.1.0'; #sieStSystemStatusValue.0
	my $srvCommonSystemStatus = trySNMPget($snmpOidSysStat,"SystemStatus");
	if (defined $srvCommonSystemStatus) {
		sieStatusAgent();
	}
	my $storeExitCode = $resultMassStorage;
	$resultMassStorage = undef;
	# RAID
	RAIDoverallStatus();
	if (!defined $storeExitCode and $exitCode == 3) {
		$msg .= "- No RAID or other MassStorage - ";
	}
	addExitCode($storeExitCode);
  } #storageOverallStatus
#------------ ASETEK-RACKCDU-SMI-V1-MIB-V15.mib - HELPER
  sub rack_handleTemperaturePerfdata {
	my $topic   = shift;
	my $current = shift;
	my $searchErrors = shift;
	my $wmin = shift;
	my $wmax = shift;
	my $amin = shift;
	my $amax = shift;
	return if (!defined $current);

	# current measurement value is in 1/10 and threshold is 1/1
	my $printCurrent = $current ? $current / 10 : 0;
	my $warn = undef;
	my $crit = undef;
	$warn .= "$wmin:" if ($wmin);
	$warn .= "$wmax" if ($wmax);
	$crit .= "$amin:" if ($amin);
	$crit .= "$amax" if ($amax);
	#$useDegree = 1; #... QA says no-degree should be default

	# monitoring print
	my $status = 0;
	$status = 1	    if ((defined $wmin and $printCurrent < $wmin)
			    or  (defined $wmax and $printCurrent > $wmax));
	$status = 2	    if ((defined $amin and $printCurrent < $amin)
			    or  (defined $amax and $printCurrent > $amax));
	$status = 3 if (!defined $wmin and !defined $wmax and !defined $amin and !defined $amax);
	my $textStatus = "ok";
	$textStatus = "warning" if ($status == 1);
	$textStatus = "critical" if ($status == 2);
	$textStatus = "none" if ($status == 3);
	if ($main::verbose >= 2) {
	    addStatusTopic("v",$textStatus,"Temperature","");
	    addName("v",$topic);
	    addCelsius("v",$printCurrent,$warn,$crit);
	    addMessage("v","\n");
	} elsif ($searchErrors and $status) {
	    addStatusTopic("l",$textStatus,"Temperature","");
	    addName("l",$topic);
	    addCelsius("l",$printCurrent,$warn,$crit);
	    addMessage("l","\n");
	}

	# performance print    
	addTemperatureToPerfdata($topic,$printCurrent,$warn,$crit);    
  } #rack_handleTemperaturePerfdata
  sub rack_handlePressurePerfdata {
	my $topic   = shift;
	my $current = shift;
	my $searchErrors = shift;
	my $wmin = shift;
	my $wmax = shift;
	my $amin = shift;
	my $amax = shift;
	return if (!defined $current);

	# current measurement and threshold are 1/1000 bar
	my $printCurrent = $current ? $current / 1000 : 0;
	my $printWmin = $wmin ? $wmin / 1000 : 0;
	my $printWmax = $wmax ? $wmax / 1000 : 0;
	my $printAmin = $amin ? $amin / 1000 : 0;
	my $printAmax = $amax ? $amax / 1000 : 0;

	my $warn = undef;
	my $crit = undef;
	$warn .= "$printWmin:" if ($printWmin);
	$warn .= "$printWmax";
	$crit .= "$printAmin:" if ($printAmin);
	$crit .= "$printAmax";

	# monitoring print
	my $status = 0;
	$status = 1	    if ((defined $wmin and $current < $wmin)
			    or  (defined $wmax and $current > $wmax));
	$status = 2	    if ((defined $amin and $current < $amin)
			    or  (defined $amax and $current > $amax));
	my $textStatus = "ok";
	$textStatus = "warning" if ($status == 1);
	$textStatus = "critical" if ($status == 2);
	if ($main::verbose >= 2) {
	    addStatusTopic("v",$textStatus,"Pressure","");
	    addName("v",$topic);
	    addPressure("v",$printCurrent,$warn,$crit);
	    addMessage("v","\n");
	} elsif ($searchErrors and $status) {
	    addStatusTopic("l",$textStatus,"Pressure","");
	    addName("l",$topic);
	    addPressure("l",$printCurrent,$warn,$crit);
	    addMessage("l","\n");
	}

	# performance print    
	addPressureToPerfdata($topic,$printCurrent,$warn,$crit);    
  } #rack_handlePressurePerfdata
  sub rack_handleFlowPerfdata {
	my $topic   = shift;
	my $current = shift;
	my $searchErrors = shift;
	my $wmin = shift;
	my $wmax = shift;
	my $amin = shift;
	my $amax = shift;
	return if (!defined $current);

	# current measurement might be ml/sec and threshold might be 1/1000 ml/sec 
	my $compareWmin = $wmin ? $wmin / 1000 : 0;
	my $compareWmax = $wmax ? $wmax / 1000 : 0;
	my $compareAmin = $amin ? $amin / 1000 : 0;
	my $compareAmax = $amax ? $amax / 1000 : 0;

	my $floatCurrent = $current ? ($current / 1000) * 3600 : 0;
	my $floatWmin = $wmin ? ($wmin / 1000 / 1000) * 3600 : 0;
	my $floatWmax = $wmax ? ($wmax / 1000 / 1000) * 3600: 0;
	my $floatAmin = $amin ? ($amin / 1000 / 1000) * 3600: 0;
	my $floatAmax = $amax ? ($amax / 1000 / 1000) * 3600: 0;

	my $printCurrent = sprintf ("%.2f", $floatCurrent);
	my $printWmin = sprintf ("%.2f", $floatWmin);
	my $printWmax = sprintf ("%.2f", $floatWmax);
	my $printAmin = sprintf ("%.2f", $floatAmin);
	my $printAmax = sprintf ("%.2f", $floatAmax);

	my $warn = undef;
	my $crit = undef;
	$warn .= "$printWmin:" if ($printWmin);
	$warn .= "$printWmax";
	$crit .= "$printAmin:" if ($printAmin);
	$crit .= "$printAmax";

	# monitoring print
	my $status = 0;
	$status = 1	    if ((defined $compareWmin and $current < $compareWmin)
			    or  (defined $compareWmax and $current > $compareWmax));
	$status = 2	    if ((defined $compareAmin and $current < $compareAmin)
			    or  (defined $compareAmax and $current > $compareAmax));
	my $textStatus = "ok";
	$textStatus = "warning" if ($status == 1);
	$textStatus = "critical" if ($status == 2);
	if ($main::verbose >= 2) {
	    addStatusTopic("v",$textStatus,"Flow","");
	    addName("v",$topic);
	    addFlow("v",$printCurrent,$warn,$crit);
	    addMessage("v","\n");
	} elsif ($searchErrors and $status) {
	    addStatusTopic("l",$textStatus,"Flow","");
	    addName("l",$topic);
	    addFlow("l",$printCurrent,$warn,$crit);
	    addMessage("l","\n");
	}

	# performance print    
	addKeyUnitToPerfdata("FlowFacility","l/h",$printCurrent,$warn,$crit) if (defined $printCurrent);
  } #rack_handleFlowPerfdata
#------------ ASETEK-RACKCDU-SMI-V1-MIB-V15.mib
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
	$descr	= trySNMPget($snmpOIDDescription,"rack product.description") if ($type);

	if ($main::verboseTable == 400 and !$type) {
	    $type = "..type..";
	    $name = "..name..";
	    $descr = "..descr..";
	}
	addKeyLongValue("n","RackIdentifier",$name);
	addKeyLongValue("n","RackType",$type);
	addKeyLongValue("n","Description",$descr);
  } #rackSystemInfo
  sub rackAgentInfo {
	my $baseOID = ".1.3.6.1.4.1.39829.1.1."; # product
	my $snmpOIDVersion	= $baseOID . "2.0"; #version
	my $snmpOIDDate		= $baseOID . "3.0"; #date

	my $version	= trySNMPget($snmpOIDVersion,"rack product.version");
	my $date	= trySNMPget($snmpOIDDate,"rack product.date");

	if ($main::verboseTable == 400 and !$version) {
	    $version = "\$version\$";
	    $date = "\$date\$";
	}

	if ($version or $date) {
	    addStatusTopic("v",undef,"AgentInfo", undef);
	    addKeyLongValue("v","Version",$version);
	    addKeyLongValue("v","RevisionDate",$date);
	    addMessage("v", "\n");
	}
	$exitCode = 0 if ($optAgentInfo);
  } #rackAgentInfo
  sub rackTemperatures {
	my $searchErrors = shift;
	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    # current values in 1/10 °C 
	    my $snmpOidTFI	= $mBaseOID . "100.0"; #temperatureFacilityIn
	    my $snmpOidTFO	= $mBaseOID . "101.0"; #temperatureFacilityOut
	    my $snmpOidTSI	= $mBaseOID . "102.0"; #temperatureServerIn
	    my $snmpOidTSO	= $mBaseOID . "103.0"; #temperatureServerOut
	    my $snmpOidTA	= $mBaseOID . "104.0"; #temperatureAmbient
	#### thresholds
	    my $tBaseOID = ".1.3.6.1.4.1.39829.1.7."; # notifications
	    # threshold values in °C 
	    my $snmpOidFIWarnMin	= $tBaseOID . "154.0"; #warningMinFi
	    my $snmpOidFIWarnMax	= $tBaseOID . "156.0"; #warningMaxFi
	    my $snmpOidFIAlarmMin	= $tBaseOID . "158.0"; #alarmMinFi
	    my $snmpOidFIAlarmMax	= $tBaseOID . "160.0"; #alarmMaxFi
	    #
	    my $snmpOidFOWarnMin	= $tBaseOID . "162.0"; #warningMinFo
	    my $snmpOidFOWarnMax	= $tBaseOID . "164.0"; #warningMaxFo
	    my $snmpOidFOAlarmMin	= $tBaseOID . "166.0"; #alarmMinFo
	    my $snmpOidFOAlarmMax	= $tBaseOID . "168.0"; #alarmMaxFo
	    #
	    my $snmpOidSIWarnMin	= $tBaseOID . "170.0"; #warningMinSi
	    my $snmpOidSIWarnMax	= $tBaseOID . "172.0"; #warningMaxFi
	    my $snmpOidSIAlarmMin	= $tBaseOID . "174.0"; #warningMaxSi
	    my $snmpOidSIAlarmMax	= $tBaseOID . "176.0"; #alarmMaxSi
	    #
	    my $snmpOidSOWarnMin	= $tBaseOID . "178.0"; #warningMinSo
	    my $snmpOidSOWarnMax	= $tBaseOID . "180.0"; #warningMaxSo
	    my $snmpOidSOAlarmMin	= $tBaseOID . "182.0"; #alarmMinSo
	    my $snmpOidSOAlarmMax	= $tBaseOID . "184.0"; #alarmMaxSo
	#### get values
	my $current = undef;
	my $wmin = undef;
	my $wmax = undef;
	my $amin = undef;
	my $amax = undef;
	{ # Facility In
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 189;
		$wmin=0; $wmax=55; $amin=0; $amax=60;
	    } else {
	    $current = trySNMPget($snmpOidTFI,"rack measurements.temperatureFacilityIn");
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidFIWarnMin,"rack notifications.warningMinFi");
		$wmax = trySNMPget($snmpOidFIWarnMax,"rack notifications.warningMaxFi");
		$amin = trySNMPget($snmpOidFIAlarmMin,"rack notifications.alarmMinFi");
		$amax = trySNMPget($snmpOidFIAlarmMax,"rack notifications.alarmMaxFi");
	    }
	    } # 400
	    rack_handleTemperaturePerfdata("FacilityIn",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
	$current = undef;
	{ # Facility Out
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 196;
		$wmin=0; $wmax=55; $amin=0; $amax=60;
	    } else {
	    $current = trySNMPget($snmpOidTFO,"rack measurements.temperatureFacilityOut");
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidFOWarnMin,"rack notifications.warningMinFo");
		$wmax = trySNMPget($snmpOidFOWarnMax,"rack notifications.warningMaxFo");
		$amin = trySNMPget($snmpOidFOAlarmMin,"rack notifications.alarmMinFo");
		$amax = trySNMPget($snmpOidFOAlarmMax,"rack notifications.alarmMaxFo");
	    }
	    } # 400
	    rack_handleTemperaturePerfdata("FacilityOut",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
	$current = undef;
 	{ # Server In
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 196;
		$wmin=0; $wmax=45; $amin=0; $amax=50;
	    } else {
	    $current = trySNMPget($snmpOidTSI,"rack measurements.temperatureServerIn");
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidSIWarnMin,"rack notifications.warningMinSi");
		$wmax = trySNMPget($snmpOidSIWarnMax,"rack notifications.warningMaxSi");
		$amin = trySNMPget($snmpOidSIAlarmMin,"rack notifications.alarmMinSi");
		$amax = trySNMPget($snmpOidSIAlarmMax,"rack notifications.alarmMaxSi");
	    }
	    } # 400
	    rack_handleTemperaturePerfdata("ServerIn",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
	$current = undef;
	{ # Server Out
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 218;
		$wmin=0; $wmax=20; $amin=0; $amax=30; # not identic with first test data
	    } else {
	    $current = trySNMPget($snmpOidTSO,"rack measurements.temperatureServerOut");
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidSOWarnMin,"rack notifications.warningMinSo");
		$wmax = trySNMPget($snmpOidSOWarnMax,"rack notifications.warningMaxSo");
		$amin = trySNMPget($snmpOidSOAlarmMin,"rack notifications.alarmMinSo");
		$amax = trySNMPget($snmpOidSOAlarmMax,"rack notifications.alarmMaxSo");
	    }
	    } # 400
	    rack_handleTemperaturePerfdata("ServerOut",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
 	$current = undef;
	{ # Ambient
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 352;
	    } else {
	    $current = trySNMPget($snmpOidTA,"rack measurements.temperatureServerOut");
	    } # 400
	    rack_handleTemperaturePerfdata("Ambient",$current);
	}
  } #rackTemperatures
  sub rackPressures {
	my $searchErrors = shift;
	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    # current values in 1/1000 bar
	    my $snmpOidPS	= $mBaseOID . "105.0"; #pressureServer
	    my $snmpOidPF	= $mBaseOID . "106.0"; #pressureFacility
	#### thresholds
	    my $tBaseOID = ".1.3.6.1.4.1.39829.1.7."; # notifications
	    my $snmpOidPSWarnMin	= $tBaseOID . "194.0"; #warningMinPressureServer
	    my $snmpOidPSWarnMax	= $tBaseOID . "196.0"; #warningMaxPressureServer
	    my $snmpOidPSAlarmMin	= $tBaseOID . "198.0"; #alarmMinPressureServer
	    my $snmpOidPSAlarmMax	= $tBaseOID . "200.0"; #alarmMaxPressureServer
	    #
	    my $snmpOidPFWarnMin	= $tBaseOID . "202.0"; #warningMinPressureFacility
	    my $snmpOidPFWarnMax	= $tBaseOID . "204.0"; #warningMaxPressureFacility
	    my $snmpOidPFAlarmMin	= $tBaseOID . "206.0"; #alarmMinPressureFacility
	    my $snmpOidPFAlarmMax	= $tBaseOID . "208.0"; #alarmMaxPressureFacility
	#### get values
	my $current = undef;
	my $wmin = undef;
	my $wmax = undef;
	my $amin = undef;
	my $amax = undef;
	{ # Server Pressure
	    $current = trySNMPget($snmpOidPS,"rack measurements.pressureServer");
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 3;
		$wmin=0; $wmax=200; $amin=0; $amax=300;
	    } else {
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidPSWarnMin,"rack notifications.warningMinPressureServer");
		$wmax = trySNMPget($snmpOidPSWarnMax,"rack notifications.warningMaxPressureServer");
		$amin = trySNMPget($snmpOidPSAlarmMin,"rack notifications.alarmMinPressureServer");
		$amax = trySNMPget($snmpOidPSAlarmMax,"rack notifications.alarmMaxPressureServer");
	    }
	    } # 400
	    rack_handlePressurePerfdata("ServerPressure",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
	{ # Facility Pressure
	    $current = trySNMPget($snmpOidPF,"rack measurements.pressureServer");
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 1995;
		$wmin=0; $wmax=3000; $amin=0; $amax=3500;
	    } else {
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidPFWarnMin,"rack notifications.warningMinPressureFacility");
		$wmax = trySNMPget($snmpOidPFWarnMax,"rack notifications.warningMaxPressureFacility");
		$amin = trySNMPget($snmpOidPFAlarmMin,"rack notifications.alarmMinPressureFacility");
		$amax = trySNMPget($snmpOidPFAlarmMax,"rack notifications.alarmMaxPressureFacility");
	    }
	    } # 400
	    rack_handlePressurePerfdata("FacilityPressure",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
  } #rackPressures
  sub rackFlowCapacity {
	my $searchErrors = shift;
	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    my $snmpOidFF	= $mBaseOID . "109.0"; #flowFacility ? ml/sec
	#### thresholds ? 1/1000 ml/sec
	    my $tBaseOID = ".1.3.6.1.4.1.39829.1.7."; # notifications
	    my $snmpOidWarnMin	= $tBaseOID . "186.0"; #warningMinFlow
	    my $snmpOidWarnMax	= $tBaseOID . "188.0"; #warningMaxFlow
	    my $snmpOidAlarmMin	= $tBaseOID . "190.0"; #alarmMinFlow
	    my $snmpOidAlarmMax	= $tBaseOID . "192.0"; #alarmMaxFlow
	#### get values
	my $current = undef;
	my $wmin = undef;
	my $wmax = undef;
	my $amin = undef;
	my $amax = undef;
	{ # Flow Facility
	    if ($main::verboseTable==400 and !defined $current) {
		$current = 280;		
		#GUI: 1011,11 ...
		$wmin=27777; $wmax=944444; $amin=20833; $amax=972222;
		#GUI: 100, 3400, 75, 3500
	    } else {
	    $current = trySNMPget($snmpOidFF,"rack measurements.flowFacility");
	    if (defined $current) {
		$wmin = trySNMPget($snmpOidWarnMin,"rack notifications.warningMinFlow");
		$wmax = trySNMPget($snmpOidWarnMax,"rack notifications.warningMaxFlow");
		$amin = trySNMPget($snmpOidAlarmMin,"rack notifications.alarmMinFlow");
		$amax = trySNMPget($snmpOidAlarmMax,"rack notifications.alarmMaxFlow");
	    }
	    } # 400
	    rack_handleFlowPerfdata("FlowFacility",$current,$searchErrors,$wmin,$wmax,$amin,$amax);
	}
  } #rackFlowCapacity
  sub rackHeatLoad {
	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    my $snmpOidHL	= $mBaseOID . "110.0"; #heatload W	/??sec	- 987
	#### unit
	    my $uBaseOID = ".1.3.6.1.4.1.39829.1.6."; # units
	    my $snmpOidFactor	= $mBaseOID . "71.0"; #heatAverageFactor sec
	#### get values
	{
	    my $current = undef;
	    my $sec = undef;
	    if ($main::verboseTable==400) {
		$current = 987;
		$sec=60;
	    } else {
	    $current = trySNMPget($snmpOidHL,"rack measurements.heatload") if (!defined $current);
	    $sec = trySNMPget($snmpOidFactor,"rack units.heatAverageFactor")
		if (defined $current and $main::verbose >= 2);
	    }
	    # print
	    if (defined $current and $main::verbose >= 2) {
		addStatusTopic("v","none","HeatLoad","");
		addKeyValueUnit("v","Current",$current,"Watt");		
		addKeyValueUnit("v","HeatAverageFactor",$sec,"sec");
		addMessage("v","\n");
	    }
	    addKeyUnitToPerfdata("HeatLoad","Watt",$current) if (defined $current);
	}
  } #rackHeatLoad
  sub rackControllerOut {
  	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    my $snmpOidCO	= $mBaseOID . "111.0"; #controllerOut	1/10 %	- 350
	#### get values
	{
	    my $current = undef;
	    if ($main::verboseTable==400) {
		$current = 350;
	    } else {
	    $current = trySNMPget($snmpOidCO,"rack measurements.controllerOut") if (!defined $current);
	    }
	    $current = $current ? $current / 10 : 0; 
	    if (defined $current and $main::verbose >= 2) {
		addStatusTopic("v","none","ControllerOut","");
		addKeyValueUnit("v","Current",$current,"%");		
		addMessage("v","\n");
	    }
	    addKeyUnitToPerfdata("ControllerOut","%",$current) if (defined $current);
	}
  } #rackControllerOut
  sub rackData {
	my $overallStatus = shift;

	#### current values
	    my $mBaseOID = ".1.3.6.1.4.1.39829.1.3."; # measurements
	    # boolean
	    my $snmpOidSLeak	= $mBaseOID . "107.0"; #serverLeak
	    my $snmpOidSLevel	= $mBaseOID . "108.0"; #serverLevel (coolant)
	    # exotic
	    my $snmpOidHL	= $mBaseOID . "110.0"; #heatload W	/??sec	- 987
	    my $snmpOidCO	= $mBaseOID . "111.0"; #controllerOut	1/10 %	- 350

	#### thresholds
	    my $tBaseOID = ".1.3.6.1.4.1.39829.1.7."; # notifications

	my $getInfos = 0;
	my $searchErrors = 0;
	$searchErrors = 1 if ($overallStatus == 1 or $overallStatus == 2); # warning , errors
	$getInfos = 1 if ($main::verbose >= 2 or $searchErrors);
	#### various Status Values
	if ($getInfos) {
	    my $serverLeak  = undef;
	    my $serverLevel = undef;
	    if ($main::verboseTable == 400 and !$serverLeak) {
		$serverLeak=2; $serverLevel=2;
	    } else {
	    $serverLeak = trySNMPget($snmpOidSLeak,"rack measurements.serverLeak");
	    $serverLevel = trySNMPget($snmpOidSLevel,"rack measurements.serverLevel") if ($serverLeak);
	    }
	    $serverLeak = undef if ($serverLeak and $serverLeak < 0);
	    $serverLeak = undef if ($serverLeak and $serverLeak > 2);
	    $serverLevel = undef if ($serverLevel and $serverLevel < 0);
	    $serverLevel = undef if ($serverLevel and $serverLevel > 2);

	    if ($main::verbose >= 2) {
		addStatusTopic("v",undef,"RackMeasurement", undef);
		addKeyValue("v","Leak", "no")  if ($serverLeak and $serverLeak == 1);
		addKeyValue("v","Leak", "yes") if ($serverLeak and $serverLeak == 2);
		addKeyValue("v","Leak", "N/A") if (!$serverLeak);
		addKeyValue("v","CoolantLevel", "ok") if ($serverLevel and $serverLevel == 1);
		addKeyValue("v","CoolantLevel", "low") if ($serverLevel and $serverLevel == 2);
		addKeyValue("v","CoolantLevel", "N/A") if (!$serverLevel);
		addMessage("v","\n");
	    } elsif (($serverLeak and $serverLeak == 2 ) 
	      or     ($serverLevel and $serverLevel == 2)) 
	    {
		addStatusTopic("l",undef,"RackMeasurement", undef);
		addKeyValue("l","Leak", "yes") if ($serverLeak and $serverLeak == 2);
		addKeyValue("l","CoolantLevel", "low") if ($serverLevel and $serverLevel == 2);
		addMessage("l","\n");
	    }
	}
	#### performance
	{
	    rackTemperatures($searchErrors);
	    rackPressures($searchErrors);
	    rackFlowCapacity($searchErrors);
	    rackHeatLoad();
	    rackControllerOut();
	}	  
  } #rackData
  sub forceRackCDUStatus {
	my $OID = ".1.3.6.1.4.1.39829.1.1.6.0"; # status
	#ok(1),                warning(2),                error(3),                unknown(5)
	my @statusText = ("undefined",
	    "ok", "warning", "error", "..unexpected..", "unknown", 
	    "..unexpected..",
	);
	my $status = undef;
	$status = mibTestSNMPget($OID,"RackCDU SNMP Agent") if (!$main::verbose or $main::verbose < 60);
	if ($optChkSystem and defined $status) {
	    $exitCode = 0 if ($status == 1);
	    $exitCode = 1 if ($status == 2);
	    $exitCode = 2 if ($status == 3);
	    my $lstatus = $status;
	    $lstatus = 6 if ($lstatus > 5);
	    $lstatus = 0 if ($lstatus < 0);
	    addMessage("m","- ");
	    addComponentStatus("m","RackCDU", $statusText[$lstatus]);
	}
	$status = 6 if (!defined $status and $main::verbose and $main::verbose >= 60);
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

	if ($optSystemInfo) {
	    rackSystemInfo();
	} elsif (defined $optAgentInfo) {
	    rackAgentInfo();
	} else {
	    rackData($status);
	    rackSystemInfo() if ($main::verbose 
		or $exitCode == 1 or  $exitCode == 2);
	}
  } #rackCDU
#------------ 
  sub processData {
	if (defined $optChkUpTime) {
		RFC1213sysinfoUpTime();
	} elsif ($optSystemInfo) {
		$main::verbose = 1 if (!$main::verbose);
		if (!defined $optPrimeQuest and !defined $optRackCDU 
		and !defined $optBlade and !defined $optBladeContent) 
		{
			primergyServerNotifyData();
		} elsif (defined $optBlade or defined $optBladeContent) {
			primergyManagementBladeNotifyData();
		} elsif (defined $optPrimeQuest) {
			primequestUnitTableChassisSerialNumber();
			primequestUnitTableChassis();
		} elsif (defined $optRackCDU) {
			rackCDU();
		}
		if ($notifyMessage) {
		    $exitCode = 0;
		} else {
		    $msg .= "- Unable to get SNMP information";
		}
	} elsif (defined $optAgentInfo) {
		if (!defined $optPrimeQuest and !defined $optRackCDU 
		and !defined $optBlade and !defined $optBladeContent) 
		{
			$main::verbose = 3 if ($main::verbose <3);
			primergyServerAgentInfo();
			if ($variableVerboseMessage) {
			    $longMessage = $variableVerboseMessage;
			    $variableVerboseMessage = undef;
			    my $version = undef;
			    if ($longMessage =~ m/Version=\"/) {
				$longMessage =~ m/(Version=\"[^\"]*\")\s/;
				$version = $1;
			    } else {
				$longMessage =~ m/(Version=[^\s]*)/;
				$version = $1;
			    }
			    #$longMessage =~ m/(Version=.*) Company/;
			    #$version = $1;
			    addMessage("m", "- " . $version);
			    $exitCode = 0;
			}
		} elsif (defined $optBlade or defined $optBladeContent) {
			primergyManagementBlade_MgmtBladeTable();
		} elsif (defined $optPrimeQuest) {
			#primequestUnitTableChassisSerialNumber();
			#primequestUnitTableChassis();
		} elsif (defined $optRackCDU) {
			rackCDU();
		}
	} elsif (defined $optPrimeQuest) {
		primequest();
	} elsif (defined $optBlade) {
		primergyManagementBlade();
	} elsif (defined $optBladeContent) {
		{
			addStatusTopic("n",undef,"MMB System Information", undef);
			primergyManagementBladeNotifyData();
		}
		if (defined $optBladeSrv) {
			primergyServerBlades();
		}
		if (defined $optBladeIO) {
			primergyIOConnectionBlades();
		}
		if (defined $optBladeKVM) {
			primergyKVMBlades();
		}
		if (defined $optBladeStore) {
			primergyStorageBlades();
		}
	} elsif (defined $optRackCDU) {
		rackCDU();
	} 
	elsif (	$optChkCpuLoadPerformance or $optChkMemoryPerformance
	or	$optChkFileSystemPerformance or $optChkNetworkPerformance) 
	{
		my $snmpOidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1'; #sc2UnitSerialNumber.1
		my $snmpOidSc2Test = $snmpOidServerID;
		mibTestSNMPget($snmpOidSc2Test,"SV-Agent");
		if ($optChkCpuLoadPerformance or $optChkMemoryPerformance) {
		    my $osmib = svOsPropertyTable();
		    primergyServerPerformanceTable($osmib);
		} elsif ($optChkFileSystemPerformance) {
		    inv_sniFileSystemTable();
		} elsif ($optChkNetworkPerformance) {
		    inv_sniNetworkInterfaceTable();
		}
		if (($exitCode > 0) or $main::verbose) {
			primergyServerNotifyData();
		}
	}
	elsif ($optChkStorage and !$optChkSystem and !$optChkEnvironment and !$optChkPower 
	and !$optChkHardware and !$optChkDrvMonitor)
	{
		#RAIDoverallStatus();
		storageOverallStatus();
		sieStComponentTable();
		primergyServerNotifyData();
		my $isiRMC = undef;
		$isiRMC = 1 if ($notifyMessage =~ m/iRMC/);
		RAID() if (!$isiRMC);
	} else {
		primergyServer();
		if ($optChkUpdate) {
			primergyServerNotifyData(); # reset
			primergyUpdateAgent();
		}
	}
  } #processData
#------------ MAIN PART

handleOptions();

#$main::verbose = $optVerbose;
#$main::verboseTable = $optVerboseTable;

# set timeout
local $SIG{ALRM} = sub {
	#### TEXT LANGUAGE AWARENESS
	print 'UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($optTimeout);

# connect to SNMP host
openSNMPsession();

processData();

# close SNMP session
closeSNMPsession();
chop($error);

# output to nagios
#$|++; # for unbuffered stdout print (due to Perl documentation)
$msg =~ s/^\s*//gm if ($msg); # remove leading blanks
if ($msg) {
    $msg =~ s/\0//gm; # remove 0x00 of iRMC data
}
if ($notifyMessage) {
    $notifyMessage =~ s/^\s+//gm; # remove leading blanks
    $notifyMessage =~ s/\s*$//m; # remove last blanks
    $notifyMessage =~ s/\0//gm; # remove 0x00 of iRMC data
}
$notifyMessage = undef if ($main::verbose < 1 and ($exitCode==0));
if ($longMessage) {
    $longMessage =~ s/^\s*//m; # remove leading blanks
    $longMessage =~ s/\s*$//m; # remove last blanks
    $longMessage =~ s/\0//gm; # remove 0x00 of iRMC data
}
if ($variableVerboseMessage) {
    $variableVerboseMessage =~ s/^\s*//m; # remove leading blanks
    $variableVerboseMessage =~ s/\n$//m; # remove last break
    $variableVerboseMessage =~ s/\0//gm; # remove 0x00 of iRMC data
}
$variableVerboseMessage = undef if ($main::verbose < 2 and  !$main::verboseTable);
$variableVerboseMessage = undef if ($variableVerboseMessage and $variableVerboseMessage =~ m/^\s*$/);

finalize(
	$exitCode, 
	$state[$exitCode], 
	$msg,
	(! $notifyMessage ? '': "\n" . $notifyMessage),
	($longMessage eq '' ? '' : "\n" . $longMessage),
	($variableVerboseMessage) ? "\n" . $variableVerboseMessage: "",
	($performanceData ? "\n |" . $performanceData : ""),
);
################ EOSCRIPT
