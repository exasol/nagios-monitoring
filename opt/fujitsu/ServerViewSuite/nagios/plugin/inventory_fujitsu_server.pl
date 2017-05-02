#!/usr/bin/perl

## 
##  Copyright (C) Fujitsu Technology Solutions 2013, 2014, 2015
##  All rights reserved
##

# version string
our $version = '3.30.02';
# Version:	3.20.00
# Date:		2015-07-17
# Based on SNMP MIB 2012 or later

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Net::SNMP;
#use Time::localtime 'ctime';
use Time::gmtime 'gmctime'; # gmctime makes no own calculations about times !
use utf8;

=head1 NAME

inventory_fujitsu_server.pl - Search Inventory Data on Hosts

=head1 SYNOPSIS

inventory_fujitsu_server.pl 
  { -H|--host=<host> 
    [-p|--port=<port>] [-T|--transport=<type>]
    { [ -C|--community=<SNMP community string> ] | 
      { --user=<username>  
        [--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
        [--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
        [--ctxengine=<id>] [--ctxname=<name>]
      }
    }
    { [--inventory] 
      { [--invnet] [--invfw] [--invunit] [--invproc] }
    }
    [-t|--timeout=<timeout in seconds>]
    [-v|--verbose=<verbose mode level>]
  } | [-h|--help] | [-V|--version] 
  
Search Inventory Data on Hosts

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Host address as DNS name or ip address of the server 

=item [-p|--port=<port>] [-T|--transport=<type>]

SNMP service port number (default is 161) and SNMP transport socket type
like 'udp' or 'tcp' or 'udp6' or 'tcp6'.
The Perl Net::SNMP option for -T is in SNMP naming the '-domain' parameter.

ATTENTION: IPv6 addresses require Net::SNMP version V6 or higher.

=item -C|--community=<SNMP community string>

SNMP community of the server - usable for SNMPv1 and SNMPv2. Default is 'public'.

=item --user=<username> 
[--authpassword=<pwd>] [--authkey=<key>] [--authprot=<prot>] 
[--privpassword=<pwd>] [--privkey=<key>] [--privprot=<prot>]
[--ctxengine=<id>] [--ctxname=<name>]

SNMPv3 authentication data. Default of authprotocol is 'md5' - Default of
privprotocol is 'des'. More about this options see Perl Net::SNMP session options.

=item [-I|--inventory] 

Search Inventory Data on Hosts (Default)

=item [--invnet] [--invfw] [--invunit] [--invproc]

These options enable additional information search. It is dependent on
host if these information are available.

invnet - Search additional Network Addresses

invfw  - Only PRIMEQUEST and server with SVAgent - Print Firmware Table resp.
Print Component Version Table including FW information

invunit - Only PRIMEQUEST - Print Complete Unit Table

invproc - Only server with SVAgent - Print Current Processes Table

=item -t|--timeout=<timeout in seconds>

Timeout for the script processing.

=item -v|--verbose=<verbose mode level>

Enable verbose mode ...

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
our $optTransportType = undef;
our $optCommunity = undef;	#SNMPv1, SNMPv2
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
our $optAdminHost = undef;

# global option
$main::verbose = 0;
$main::verboseTable = 0;

# init additional options
our $optInventory	= undef;
our $optInvNetwork	= undef;
our $optInvCss		= undef; # no option
our $optInvFw		= undef;
our $optInvUnit		= undef; 
our $optInvProcesses	= undef; 

# ZABBIX
our $optZabbix = undef;

# init output data
our $msg = '';
our $longMessage = '';
our $performanceData = '';
our $exitCode = 3;
our $variableVerboseMessage = '';
our $notifyMessage = '';

# multi used processing variables
$main::session = undef;
our $useSNMPv3 = undef;

# GLOBAL INVENTORY DATA
our @components = ();
our @subblades = ();

our %agentVersion = (
	"Name"		=> undef,
	"Company"	=> undef,
	"Version"	=> undef,
);
our $biosVersion	= undef;
our $isiRMC		= undef;


#########################################################################################
#----------- multi usable functions
  sub finalize {
	my $exitCode = shift;
	$|++ if ($main::verbose < 5);
		# for unbuffered stdout print (due to Perl documentation)
	my $string = "@_";
	print "$string" if ($string);
	print "\n";
	alarm(0); # stop timeout
	exit($exitCode);
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

	if ($indexSelector == 0) { # anything after .
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
  }
####
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
#----------- synchronize verbose output format functions
  sub addMessage {
	my $container = shift;
	my $string = "@_";
	if ($string) {
		#$msg .= $string				if ($container =~ m/.*m.*/);
		#$notifyMessage .= $string		if ($container =~ m/.*n.*/);
		#$longMessage .= $string			if ($container =~ m/.*l.*/);
		#$variableVerboseMessage .= $string	if ($container =~ m/.*v.*/);
		print $string;
	}
  } #addMessage
  # for inventory prints
  sub addInv1stLevel {
	my $string = shift;
	return if (!$string);
	print "* $string\n";
  }
  sub addInv2ndKeyValue {
	my $key = shift;
	my $value = shift;
	return if (!$key or !$value);
	$value = "\"$value\"" if ($value =~ m/\s/);
	$value = " $value"    if ($value !~ m/\s/);
	print "    $key\t=$value\n";
  }
  sub addInv2ndKeyIntValue {
	my $key = shift;
	my $value = shift;
	return if (!$key or !defined $value);
	$value = "\"$value\"" if ($value =~ m/\s/);
	$value = " $value"    if ($value !~ m/\s/);
	print "    $key\t=$value\n";
  }
  sub addInv2ndKeyValueUnit {
	my $key = shift;
	my $value = shift;
	my $unit = shift;
	return if (!$key or !$value);
	$value = "\"$value\"" if ($value =~ m/\s/);
	$value = " $value"    if ($value !~ m/\s/);
	print "    $key\t=$value$unit\n";
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
####
  sub addTableHeader {
	my $oldContainer = shift; # unused
	my $string = shift;
	return if (!$string);
	print "* $string\n";
  }
  sub addStatusTopic {
	my $container = shift;
	my $status = shift;
	my $topic = shift;
	my $index = shift;
	my $tmp = '';
	$tmp .= "    *** ";
	$tmp .= "$status: " if ($status);
	$tmp .= "$topic" if ($topic);
	$tmp .= "[$index]" if (defined $index);
	$tmp .= "\n";
	print $tmp;
  }
  sub addKeyValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= "        $key\t= $value\n" if ($value);
	addMessage($container, $tmp);
  }
  sub addKeyValueUnit {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $unit = shift;
	my $tmp = '';
	$tmp .= "        $key\t= $value $unit\n" if ($value);
	addMessage($container, $tmp);
  }
  sub addKeyLongValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= "        $key\t=\"$value\"\n" if ($value);
	addMessage($container, $tmp);
  }
  sub addKeyIntValue {
	my $container = shift;
	my $key = shift;
	my $value = shift;
	my $tmp = '';
	$tmp .= "        $key\t= $value\n" if (defined $value);
	addMessage($container, $tmp);
  }
  sub addKeyMB {
	my $container = shift;
	my $key = shift;
	my $mbytes = shift;
	my $tmp = '';
	$mbytes = undef if (defined $mbytes and $mbytes < 0);
	$tmp .= "        $key\t= $mbytes" . "MB\n" if (defined $mbytes);
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
	if ((defined $id) && ($id =~ m/0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff/)) {
		$id = undef;
	}
	$tmp .= "        ID\t= $id\n" if ($id or $container =~ m/.*m.*/);
	$tmp .= "        ID2\t= $id2" if ($id2);
	addMessage($container, $tmp);
  }
  sub addName {
	my $container = shift;
	my $name = shift;
	my $tmp = '';
	$name = undef if (defined $name and $name eq '');
	$name = "\"$name\"" if ($name);
	$tmp .= "        Name\t=$name\n" if ($name);
	addMessage($container,$tmp);
  }
  sub addProductModel {
	my $container = shift;
	my $product = shift;
	my $model = shift;
	my $tmp = '';
	$container = "n"; # ... for inventory
	if ((defined $product) 
	&& ($product =~ m/0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff/)
	) {
		$product = undef;
	}
	if ($container =~ m/.*n.*/ and defined $product and 
	    ($product =~ m/^D\d{4}$/ or $product =~ m/A3C\d{8}/)
	) {
		$product = undef;
	}
	if ((defined $model) 
	&& ($model =~ m/0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff/)) {
		$model = undef;
	}
	if ($container =~ m/.*n.*/ and defined $model and 
	    ($model =~ m/A3C\d{8}/ or $model =~ m/^D\d{4}$/) )
	{
		$model = undef;
	}
	$tmp .= "        Product\t=\"$product\"\n" if ($product);
	$tmp .= "        Model\t=\"$model\"\n" if ($model);
	addMessage($container, $tmp);
  }
  sub addLocationContact {
	my $container = shift;
	my $location = shift;
	my $contact = shift;
	my $tmp = '';
	$location = undef if(defined $location and $location eq '');
	$contact = undef if(defined $contact and $contact eq '');
	$tmp .= "        Location=\"$location\"\n" if ($location);
	$tmp .= "        Contact\t=\"$contact\"\n" if ($contact);
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
	$tmp .= "        AdminURL=$admURL\n" if ($admURL);
	addMessage($container, $tmp);
  }
  sub addIP {
	my $container = shift;
	my $ip = shift;
	my $tmp = '';
	$ip = undef if (($ip) and ($ip =~ m/0\.0\.0\.0/));

	$tmp .= "        IP\t= $ip\n" if ($ip);
	addMessage($container, $tmp);
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
	$tmp .= "        MAC\t= $mac\n" if ($mac);
	addMessage($container,$tmp);
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
		       	"V|version",	
			"h|help",	
		    
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

			"inventory",
			"invfw",
			"invnet",
			"invunit",
			"invproc",

			"Z|zabbix=s",


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
			
	   		"u|user=s"		,
	   		"authkey=s"		,
	   		"authpassword=s"	,
	   		"authprot=s"		,
	   		"privkey=s"		,
	   		"privpassword=s"	,
	   		"privprot=s"		,
	   		"ctxengine=s"		,
	   		"ctxname=s"		,

			"inventory",
			"invfw",
			"invnet",
			"invunit",
			"invproc",

			"Z|zabbix=s",

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
	# assign to global variables
	# for options like 'x|xample' the hash key is always 'x'
	#
	my $k=undef;
	$k="A";		$optAdminHost	= $options{$k} if (defined $options{$k});
	$k="snmp";	$optSNMP	= $options{$k} if (defined $options{$k});
	$k="ctxengine";	$optCtxEngine		= $options{$k} if (defined $options{$k});
	$k="ctxname";	$optCtxName		= $options{$k} if (defined $options{$k});

	$k="inventory";		$optInventory	= $options{$k} if (defined $options{$k});
	$k="invfw";		$optInvFw	= $options{$k} if (defined $options{$k});
	$k="invnet";		$optInvNetwork	= $options{$k} if (defined $options{$k});
	$k="invunit";		$optInvUnit	= $options{$k} if (defined $options{$k});
	$k="invproc";		$optInvProcesses= $options{$k} if (defined $options{$k});

	$k="Z";		$optZabbix		= $options{$k} if (defined $options{$k});

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

		$optUserName = $options{$key}                 	if ($key eq "u"		 	);
		$optAuthKey = $options{$key}             	if ($key eq "authkey"	 	);
		$optAuthPassword = $options{$key}             	if ($key eq "authpassword" 	);
		$optAuthProt = $options{$key}             	if ($key eq "authprot"	 	);
		$optPrivKey = $options{$key}             	if ($key eq "privkey"	 	);
		$optPrivPassword = $options{$key}             	if ($key eq "privpassword" 	);
		$optPrivProt = $options{$key}             	if ($key eq "privprot"	 	);
		
	}
  }

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
	# first checks of sub blade options
	
	# wrong combination tests
	my $wrongCombination = undef;
	if (defined $optSNMP) {
		$wrongCombination = "--snmp 3 ... and no SNMPv3 credentials (set user name)" 
			if ($optSNMP and $optSNMP == 3 and !$optUserName);
	}

	# after readin of options set defaults	
	if ($main::verbose > 100) {
		$main::verboseTable = $main::verbose;
		$main::verbose = 0;
	}
	pod2usage({
		-msg     => "\n" . "Invalid argument combination \"$wrongCombination\"!" . "\n",
		-verbose => 0,
		-exitval => 3
	}) if ($wrongCombination);

	# Defaults
	if (!defined $optInventory and !$optInvFw and !$optInvNetwork and !$optInvUnit
	and !$optInvProcesses) 
	{
	    $optInventory = 999;
	}

  } #evaluateOptions

  sub handleOptions { # script specific
	# read all options and return prioritized
	my %options = readOptions();

	# assign to global variables
	setOptions(\%options);

	# evaluateOptions expects options set in global variables
	evaluateOptions();
  } #handleOptions
#################################################################################
#------------ RFC1213.mib
  sub RFC1213sysinfoUpTime {
	my $printThis = shift;
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidUpTime	= $snmpOidSystem . '3.0'; #sysUpTime.0
	my $uptime = trySNMPget($snmpOidUpTime);
	if ($uptime) {
		$exitCode = 0;
		addInv2ndKeyValue("SNMP Uptime", $uptime) 
			if ($printThis and $optInventory);
	} else {
		my $error = $main::session->error;
		$msg .= " - SNMP: $error";
	}
  } #RFC1213sysinfoUpTime
  sub RFC1213sysinfo {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidDescr	= $snmpOidSystem . '1.0'; #sysDescr.0
	my $snmpOidContact	= $snmpOidSystem . '4.0'; #sysContact.0
	my $snmpOidName		= $snmpOidSystem . '5.0'; #sysName.0
	my $snmpOidLocation	= $snmpOidSystem . '6.0'; #sysLocation.0

	my $descr = trySNMPget($snmpOidDescr);
	my $name = trySNMPget($snmpOidName);
	my $contact = trySNMPget($snmpOidContact);
	my $location = trySNMPget($snmpOidLocation);

	{
		addInv2ndKeyValue("Name",$name);
		addInv2ndKeyValue("Description",$descr);
		addInv2ndKeyValue("Location",$location);
		addInv2ndKeyValue("Contact",$contact);
	}
	$isiRMC = 1 if ($descr and $descr =~ m/iRMC/);
  } #RFC1213sysinfo
  sub RFC1213_ipAddrTable {
	my $snmpOidTable = ".1.3.6.1.2.1.4.20.1."; #ipAddrTable (1 index)
	my $snmpOidIp		= $snmpOidTable . '1'; #ipAdEntAddr
	my $snmpOidIndex	= $snmpOidTable . '2'; #ipAdEntIfIndex
	my $snmpOidMask		= $snmpOidTable . '3'; #ipAdEntNetMask
	#my $snmpOidBcast	= $snmpOidTable . '4'; #ipAdEntBcastAddr
	my $snmpOidReasm	= $snmpOidTable . '5'; #ipAdEntReasmMaxSize
	my @tableChecks = (
		$snmpOidIp, $snmpOidIndex, $snmpOidMask, 
		$snmpOidReasm, 
	);
	{
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		if (0) {
		    foreach my $snmpKey ( keys %{$entries} ) {
		    	#print "$snmpKey --- $entries->{$snmpKey}\n";
		    	push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidIp.(.*)/);
		    }
		    @snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		} else {
		    @snmpIDs = getSNMPTableIndex($entries, $snmpOidIp, 0);
		}
		addTableHeader("v","Standard IP Address Table") if ($#snmpIDs >= 0);
		$exitCode = 0 if ($#snmpIDs >= 0 and $exitCode == 3);
		foreach my $snmpID (@snmpIDs) {
			my $ip = $entries->{$snmpOidIp . '.' . $snmpID};
			my $index = $entries->{$snmpOidIndex . '.' . $snmpID};
			my $mask = $entries->{$snmpOidMask . '.' . $snmpID};
			#my $bcast = $entries->{$snmpOidBcast . '.' . $snmpID};
			my $reasm = $entries->{$snmpOidReasm . '.' . $snmpID};
			addStatusTopic("v", undef, "IpAddress", $ip);
			addKeyValue("v","IFIndex", $index);
			addKeyValue("v","Mask", $mask);
			#addKeyValue("v","BroadCastNr", $bcast);
			addKeyValue("v","ReasmMaxSize", $reasm);
			#$variableVerboseMessage .= "\n";
		} # for keys
	}
  } #RFC1213_ipAddrTable
#------------ OS.mib
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
	addInv2ndKeyValue("OS\t", $os);
	addInv2ndKeyValue("OS-Revision", $version);
	addInv2ndKeyValue("FQDN", $fqdn);
	return 1 if ($os);
  } #svOsInfoTable
  sub svOsSystemStartTime {
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.3.1.'; #svOsPropertyTable
 	my $snmpUpTime  = $snmpOID . '3.1'; #svOsSystemStartTime
	$exitCode = 0;
	my $onTime = trySNMPget($snmpUpTime);
	$exitCode = 3 if (!defined $onTime or !$onTime);
	if ($exitCode == 0 and $optInventory and $onTime and $onTime > 1423000000) { # iRMC-No-Agent ERROR !
		my $timeString = gmctime($onTime);
		addInv2ndKeyValue("OnTime", "$timeString");
	}
	return 1 if ($exitCode == 0);
	return 0 if ($exitCode != 0);
  } #svOsSystemStartTime
  sub svOsPropertyTable {
	return if (!$isiRMC);
	my $snmpOID = '.1.3.6.1.4.1.231.2.10.2.5.5.2.3.1.'; #svOsPropertyTable
	my $snmpManagement  = $snmpOID . '9.1'; #svOsManagementSoftware
	my $snmpVersion  = $snmpOID . '10.1'; #svOsManagementSoftwareVersion
	my @managText = ( 'undefined',
	    'Unknown Agent', 'No Agent', 'Agentless Service', 'Mgmt. Agent', '..undefined..', 
	);
	# ORIGIN strings: unknown(1),        none(2),        agentlessManagementService(3),        agents(4)
	# ... the strings above are the oness of CIM provider
	my $manag = trySNMPget($snmpManagement,"svOsManagementSoftware");
	my $version = trySNMPget($snmpVersion,"svOsManagementSoftwareVersion");
	$manag = 0 if (!defined $manag or $manag < 0);
	$manag = 5 if ($manag and $manag > 5);
	addInv2ndKeyValue("Agent", $managText[$manag]) if ($manag);
	addInv2ndKeyValue("Version", $version) if ($version and $version ne "n/a");
 } #svOsPropertyTable
 sub svOsClusterInfoTable {
	my $rc = 0;
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.5.5.3.1.1.'; #svOsClusterInfoTable  (1 index)
	my $snmpOidBoolean		= $snmpOidTable . '1.1'; #svOsClusterMember
	my $snmpOidName			= $snmpOidTable . '2.1'; #svOsClusterName
	my $snmpOidIP			= $snmpOidTable . '3.1'; #svOsClusterIpAddress
	my $snmpOidNrNodes		= $snmpOidTable . '4.1'; #svOsClusterNrNodes

	my $cluster = undef;
	my $clusterIP = undef;
	$cluster = trySNMPget($snmpOidBoolean,"svOsClusterMember");
	$clusterIP = trySNMPget($snmpOidIP,"svOsClusterIpAddress") if ($cluster);
	$rc = 1 if (defined $cluster);
	if ($cluster) {
	    addInv2ndKeyValue("InCluster", "false") 
		    if ($cluster and $cluster == 1);
	    addInv2ndKeyValue("InCluster", "true") 
		    if ($cluster and $cluster == 2);
	    addInv2ndKeyValue("ClusterIP", $clusterIP)
		    if ($cluster == 2 and $clusterIP);
	}
	return $rc;
 } #svOsClusterInfoTable
  sub svOsProcessTable {
      	return 0 if (!$optInvProcesses);
	my $rc = 0;
	my $snmpOidTable	= '.1.3.6.1.4.1.231.2.10.2.5.5.4.1.1.'; 
		#svOsProcessTable (2 index)
	my $snmpOidName		= $snmpOidTable . '2'; #svOsProcessName
	my $snmpOidDescription	= $snmpOidTable . '3'; #svOsProcessDescription
	my $snmpOidPath		= $snmpOidTable . '4'; #svOsProcessPath
	my $snmpOidVersion	= $snmpOidTable . '5'; #svOsProcessVersion
	my $snmpOidCPU		= $snmpOidTable . '6'; #svOsProcessUtilization
	my @tableChecks = (
		$snmpOidName, 
		$snmpOidDescription, $snmpOidPath, $snmpOidVersion, $snmpOidCPU, 
	);
        {
		my $entries = getSNMPtable(\@tableChecks);
		$rc = 1 if ($entries);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 2);
		addTableHeader("v","Process Table") if ($#snmpIDs >= 0);
		$exitCode = 0 if ($#snmpIDs >= 0 and $exitCode == 3);
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $path = $entries->{$snmpOidPath . '.' . $snmpID};
			my $desc = $entries->{$snmpOidDescription . '.' . $snmpID};
			my $version = $entries->{$snmpOidVersion . '.' . $snmpID};
			my $cpu = $entries->{$snmpOidCPU . '.' . $snmpID};
			my $pid = undef;
			$pid = $1 if ($snmpID =~ m/\d+\.(\d+)/);
			addStatusTopic("v", undef, "Process", $pid);
			addKeyValue("v","Name\t", $name);
			addKeyValue("v","Path\t", $path);
			addKeyValue("v","Description", $desc);
			addKeyValue("v","Version\t", $version);
			addKeyValueUnit("v","CPU\t", $cpu, "%");
		} # for keys
	}
	return $rc;
  } #svOsProcessTable
#------------ STATUS.mib
  sub status_sieStAgentInfo {
	#--       sieStAgentInfo group:	  1.3.6.1.4.1.231.2.10.2.11.1
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.2.10.2.11.1.'; #sieStAgentInfo
	my $snmpOidId		= $snmpOidAgentInfoGroup . '1.0'; #sieStAgentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0'; #sieStAgentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0'; #sieStAgentVersionString

	my $id = trySNMPget($snmpOidId);
	$exitCode = 3 if (!defined $id);
	my $company = undef;
	my $version = undef;
	if ($id) {
		$company = trySNMPget($snmpOidCompany);
		$version = trySNMPget($snmpOidVersion);
	}
	$agentVersion{"Name"} = $id;
	$agentVersion{"Company"} = $company;
	$agentVersion{"Version"} = $version;
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
	my $srvCommonSystemStatus = trySNMPget($snmpOidSysStat);
	$exitCode = 3 if (!defined $srvCommonSystemStatus);

	if ($exitCode == 0) {
		# set exit value
		$srvCommonSystemStatus = 5 if ($srvCommonSystemStatus > 5);
		# get subsystem information
		$srvSubSystem_cnt = trySNMPget($snmpOidSubSysCnt);
		
		for (my $x = 1; $srvSubSystem_cnt and $x <= $srvSubSystem_cnt; $x++) {	
			$result = trySNMPget($snmpOidSubSysValue . '.' . $x); #sieStSubsystemStatusValue	
			my $subSystemName = trySNMPget($snmpOidSubSysName . '.' . $x); #sieStSubsystemName	
			next if (!defined $result or $result >= 5);
			push(@components, $subSystemName);
		} # for subsystems
	} # found overall
  } #status_sieStatus
#------------ INVENT.mib
  sub inv_sniInventory {
	my $part = shift;
	my $snmpOidInventory = '.1.3.6.1.4.1.231.2.10.2.1.'; #sniInventory
	my $snmpOidMajVersion	= $snmpOidInventory . '1.0'; #sniInvRevMajor
	my $snmpOidMinVersion	= $snmpOidInventory . '2.0'; #sniInvRevMinor
	my $snmpOidOS		= $snmpOidInventory . '4.0'; #sniInvHostOS
	my $snmpOidName		= $snmpOidInventory . '8.0'; #sniInvHostName
	my $snmpOidOSRevision	= $snmpOidInventory . '22.0'; #sniInvHostOSRevision
	my $snmpOidCluster	= $snmpOidInventory . '23.0'; #sniInvServerInCluster
	my $snmpOidClusterIP	= $snmpOidInventory . '24.0'; #sniInvClusterAddress
	my $snmpOidFQDN		= $snmpOidInventory . '26.0'; #sniInvFullQualifiedName

	$exitCode = 0;
	my $majVersion = trySNMPget($snmpOidMajVersion);
	$exitCode = 3 if (!defined $majVersion);
	if ($exitCode==0) {
		my $minVersion = trySNMPget($snmpOidMinVersion);
		if ($part == 0) {
			my $os = trySNMPget($snmpOidOS);
			my $name = trySNMPget($snmpOidName);
			my $fqdn = trySNMPget($snmpOidFQDN);
			my $osrev = trySNMPget($snmpOidOSRevision);
			addInv2ndKeyValue("OS\t", $os);
			addInv2ndKeyValue("OS-Revision", $osrev);
			addInv2ndKeyValue("FQDN", $fqdn);

		} # 0
		if ($part == 1) {
			my $cluster = trySNMPget($snmpOidCluster);
			my $clusterIP = trySNMPget($snmpOidClusterIP);
			# unknown(1), false(2),	true(3)
			addInv2ndKeyValue("InCluster", "false") 
				if ($cluster and $cluster == 2);
			addInv2ndKeyValue("InCluster", "true") 
				if ($cluster and $cluster == 3);
			addInv2ndKeyValue("ClusterIP", $clusterIP)
				if ($cluster == 3);
		}
	} # existing
  } #inv_sniInventory
  sub inv_sniInvAgentTable {
	return if ($main::verboseTable != 2110); # not much use in this ?
	my $snmpOidAgentTable	= '.1.3.6.1.4.1.231.2.10.2.1.10.1.'; #sniInvAgentTable (1 index)
	#my $snmpOidMajor	= $snmpOidAgentTable . '2'; #sniAgentRevMajor
	#my $snmpOidMinor	= $snmpOidAgentTable . '3'; #sniAgentRevMinor
	my $snmpOidName		= $snmpOidAgentTable . '4'; #sniAgentName
	my $snmpOidPurpose	= $snmpOidAgentTable . '5'; #sniAgentPurpose
	my $snmpOidStatus	= $snmpOidAgentTable . '6'; #sniAgentStatus
	my @tableChecks = (
		$snmpOidName, $snmpOidPurpose, $snmpOidStatus, 
	);
	#	$snmpOidMajor, $snmpOidMinor, ALWAYS THE SAME ...
	my @purposeText = (	undef,
		"other", "not-network", "mass-storage", "hardware-specific", "os-specific", 
		"application-specific", "peripheral", "security", "management", "..undef..",
	);
	my @statusText = (	undef,
		"ok", "degraded", "error", "failed", "unknown", 
		"..undef..",
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		if (0) {
		    foreach my $snmpKey ( keys %{$entries} ) {
			    #print "$snmpKey --- $entries->{$snmpKey}\n";
			    push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidName.(.*)/);
		    }
		    @snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		} else {
		    @snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 0);
		}
		addTableHeader("v","Agent Table") if ($#snmpIDs >= 0);
		$exitCode = 0 if ($#snmpIDs >= 0 and $exitCode == 3);
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $purpose = $entries->{$snmpOidPurpose . '.' . $snmpID};
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			#my $major = $entries->{$snmpOidMajor . '.' . $snmpID};
			#my $minor = $entries->{$snmpOidMinor . '.' . $snmpID};
			$purpose = 10 if ($purpose and $purpose > 9);
			$status = 6 if ($status and $status > 5);
			addStatusTopic("v", $statusText[$status], "Agent", '');
			addKeyLongValue("v","Name",$name);
			addKeyValue("v","Purpose", $purposeText[$purpose]);
			#addKeyValue("v","Major", $major);
			#addKeyValue("v","Minor", $minor);
			#$variableVerboseMessage .= "\n";
		} # for keys
	}
  } #inv_sniInvAgentTable
  sub inv_sniLoadedProcessTable {
      	return if (!$optInvProcesses);
	my $snmpOidTable	= '.1.3.6.1.4.1.231.2.10.2.1.17.1.'; 
		#sniLoadedProcessTable (1 index)
	#my $snmpOidCodeLength	= $snmpOidTable . '2'; #sniCodeLength
	#my $snmpOidDataLength	= $snmpOidTable . '3'; #sniDataLength
	my $snmpOidName		= $snmpOidTable . '4'; #sniProcessName
	my $snmpOidDescription	= $snmpOidTable . '5'; #sniProcessDescription
	my $snmpOidMajor	= $snmpOidTable . '6'; #sniVersionMajor
	my $snmpOidMinor	= $snmpOidTable . '7'; #sniVersionMinor
	my $snmpOidRev		= $snmpOidTable . '8'; #sniRevision
	#my $snmpOidCopyright	= $snmpOidTable . '9'; #sniCopyRight
	my $snmpOidVersion	= $snmpOidTable . '10'; #sniProcessVersion
	my @tableChecks = (
		$snmpOidName, 
		$snmpOidDescription, $snmpOidMajor, $snmpOidMinor, 
		$snmpOidRev, $snmpOidVersion, 
	);
        {
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		if (0) {
		    foreach my $snmpKey ( keys %{$entries} ) {
			    #print "$snmpKey --- $entries->{$snmpKey}\n";
			    push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidName.(.*)/);
		    }
		    @snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		} else {
		    @snmpIDs = getSNMPTableIndex($entries, $snmpOidName, 0);
		}
		addTableHeader("v","Inventory Process Table") if ($#snmpIDs >= 0);
		$exitCode = 0 if ($#snmpIDs >= 0 and $exitCode == 3);
		foreach my $snmpID (@snmpIDs) {
			my $name = $entries->{$snmpOidName . '.' . $snmpID};
			my $desc = $entries->{$snmpOidDescription . '.' . $snmpID};
			#my $copy = $entries->{$snmpOidCopyright . '.' . $snmpID};
			my $version = $entries->{$snmpOidVersion . '.' . $snmpID};
			#my $clen = $entries->{$snmpOidCodeLength . '.' . $snmpID};
			#my $dlen = $entries->{$snmpOidDataLength . '.' . $snmpID};
			#$copy = "..non-UTF8.." if ($copy =~ m/^0x/);
			if (!$version) {
				my $major = $entries->{$snmpOidMajor . '.' . $snmpID};
				my $minor = $entries->{$snmpOidMinor . '.' . $snmpID};
				my $rev = $entries->{$snmpOidRev . '.' . $snmpID};
				$version = "$major.$minor";
				$version .= "$rev" if ($rev);
			}
			addStatusTopic("v", undef, "Process", $snmpID);
			addKeyValue("v","Name\t", $name);
			addKeyValue("v","Description", $desc);
			#addKeyValue("v","Copyright", $copy);
			addKeyValue("v","Version\t", $version);
			#addKeyValue("v","CodeLen", $clen);
			#addKeyValue("v","DataLen", $dlen);
			#$variableVerboseMessage .= "\n";
		} # for keys
	}
  } #inv_sniLoadedProcessTable
#------------ SC2.mib
  sub sc2CheckAgentInfo {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.231.2.10.2.2.10.1.'; #sc2AgentInfo
	my $snmpOidAgtID	= $snmpOidAgentInfoGroup . '1.0'; #sc2AgentId
	$exitCode = 0;
	my $id = trySNMPget($snmpOidAgtID);
	$exitCode = 3 if (!defined $id);
  }
  sub primergyServerSerialID {	#... this function makes only a "try" to get infos
	# Server identification (via serial number)
	my $snmpOidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1'; #sc2UnitSerialNumber.1
	{	
		my $serverID = trySNMPget($snmpOidServerID,"ServerID");
		addInv2ndKeyValue("ID\t", $serverID);
	}
  } # primergyServerSerialID
  sub sc2ManagementNodeTable_Parent {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.3.1.1.'; #sc2ManagementNodeTable
	my $snmpOidAddress	= $snmpOidTable . '4'; #sc2UnitNodeAddress
	my $snmpOidName		= $snmpOidTable . '7'; #sc2UnitNodeName
 	my $snmpOidClass	= $snmpOidTable . '8'; #sc2UnitNodeClass
	my @tableChecks = (
		$snmpOidAddress,
		$snmpOidName,
		$snmpOidClass,
	);
	{
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
				addInv2ndKeyValue("Parent Name", $name) 
					if ($name and $address and !($name eq $address));
				addInv2ndKeyValue("Parent Address", $address);
			    }
			} #"management-blade"
		} # for keys
	} # extended
  } #sc2ManagementNodeTable_Parent
  sub sc2UnitTable {
	my $topic = shift;
	my $snmpOidUnitTable = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable
	my $snmpOidModel	= $snmpOidUnitTable . '5.1'; #sc2UnitModelName.1
	my $snmpOidAdmURL	= $snmpOidUnitTable .'10.1' ;#sc2UnitAdminURL
	my $model = undef;
	if ($topic eq "I") { 
		my $snmpOidDesignation	= $snmpOidUnitTable .'4.1' ;#sc2UnitDesignation
		my $admurl = trySNMPget($snmpOidAdmURL);
		my $model = trySNMPget($snmpOidModel);
		my $design = trySNMPget($snmpOidDesignation);
		addInv2ndKeyValue("Model", $model);
		addInv2ndKeyValue("Housing", $design);
		addInvAdminURL($admurl);
	}
	if ($topic eq "I") { # ---- MultiNode Chassis
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
			addInv2ndKeyValue("MultiNode Parent", $name);
			addInv2ndKeyValue("MultiNode Model", $model);
		}
	}
  } #sc2UnitTable
  sub sc2ManagementNodeTable {
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.3.1.1.'; #sc2ManagementNodeTable
	my $snmpOidAddress	= $snmpOidTable . '4'; #sc2UnitNodeAddress
	my $snmpOidGateway	= $snmpOidTable . '6'; #sc2UnitNodeGateway
	my $snmpOidName		= $snmpOidTable . '7'; #sc2UnitNodeName
 	my $snmpOidClass	= $snmpOidTable . '8'; #sc2UnitNodeClass
 	my $snmpOidMac		= $snmpOidTable . '9'; #sc2UnitNodeMacAddress
	#	... this mac is a string with 0x....
 	my $snmpOidModel	= $snmpOidTable . '12'; #sc2UnitNodeControllerModel
 	my $snmpOidFW		= $snmpOidTable . '13'; #sc2UnitNodeControllerFWVersion
	#
	my @tableChecks = (
		$snmpOidAddress,
		$snmpOidGateway,
		$snmpOidName,
		$snmpOidClass,
		$snmpOidMac,	
		$snmpOidModel,
		$snmpOidFW,
	);
	my @classText = ( "none",
		 "unknown", "primary", "secondary", "management-blade",	"secondary-remote", "secondary-remote-backup", "baseboard-controller", "..unexpected..",
	);
	if ($optInvNetwork) { 
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidAddress.(\d+\.\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		addTableHeader("v","Agent Management Nodes") if ($entries);
		foreach my $id (@snmpIdx) {
 			my $address  = $entries->{$snmpOidAddress . '.' . $id};
 			my $name = $entries->{$snmpOidName . '.' . $id};
 			my $classid = $entries->{$snmpOidClass . '.' . $id};
  			my $mac = $entries->{$snmpOidMac . '.' . $id};
			my $model = $entries->{$snmpOidModel . '.' . $id};
			my $gateway = $entries->{$snmpOidGateway . '.' . $id};
			my $fw = $entries->{$snmpOidFW . '.' . $id};
			$classid = 0 if (!defined $classid or $classid < 0);
			$classid = 8 if ($classid > 8);
			
			addStatusTopic("v",undef, "Node", $id=~m/\d+\.(\d+)/);
			addIP("v",$address);
			addName("v",$name) if ($name and !($name eq $address));
			addKeyLongValue("v","ControllerType", $model);
			addKeyValue("v","Class", $classText[$classid]) if ($classid > 1);
			addMAC("v", $mac);
			addKeyValue("v", "Gateway", $gateway);
			addKeyValue("v", "FW", $fw);
			#$variableVerboseMessage .= "\n";
		}
	} #verbose
  } #sc2ManagementNodeTable
  sub sc2ManagementProcessorTable {
	my $snmpOidProcessor = ".1.3.6.1.4.1.231.2.10.2.2.10.3.4.1."; #sc2ManagementProcessorTable (2)
	my $snmpOidProcNr	= $snmpOidProcessor . '2'; #sc2spProcessorNr
	my $snmpOidModel	= $snmpOidProcessor . '3'; #sc2spModelName
	my $snmpOidFW		= $snmpOidProcessor . '4'; #sc2spFirmwareVersion
	my @tableChecks = (
		$snmpOidProcNr,		$snmpOidModel,		$snmpOidFW,
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidProcNr.(\d+\.\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		my $printedHeader = 0;
		foreach my $id (@snmpIdx) {
 			my $nr  = $entries->{$snmpOidProcNr . '.' . $id};
 			my $model = $entries->{$snmpOidModel . '.' . $id};
 			my $fw = $entries->{$snmpOidFW . '.' . $id};
  			
			if ($model and $fw) {
				addTableHeader("v","Agent Management Processor Table")
					if (!$printedHeader);
				addStatusTopic("v",undef, "Processor", $nr);
				addKeyLongValue("v","Model\t", $model);
				addKeyLongValue("v","FV-Version", $fw);
				$printedHeader = 1;
			}
		} # foreach
	}
  }
  sub sc2ServerTable {
	my $topic = shift;
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.2.10.4.1.1.'; #sc2ServerTable
 	my $snmpOidMemory	= $snmpOidTable . '2'; #sc2srvPhysicalMemory
	my $snmpOidBootStatus	= $snmpOidTable . '4'; #sc2srvCurrentBootStatus
 	my $snmpOidUuid		= $snmpOidTable . '7'; #sc2srvUUID
 	my $snmpOidBiosVersion	= $snmpOidTable . '11'; #sc2srvBiosVersion
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
	if (!defined $topic) { 
		#### QUESTION: is this relevant for somebody ?
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidUuid.(\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		addTableHeader("v","Agent Server Table") if ($entries);
		foreach my $id (@snmpIdx) {
 			my $memory  = $entries->{$snmpOidMemory . '.' . $id};
 			my $bstatus = $entries->{$snmpOidBootStatus . '.' . $id};
 			my $uuid = $entries->{$snmpOidUuid . '.' . $id};
			$bstatus = 0 if (!defined $bstatus or $bstatus < 0);
			$bstatus = 13 if ($bstatus > 13);

			addStatusTopic("v",undef,"Server",$id);
			addKeyValue("v","UUID\t", $uuid);
			addKeyMB("v","Memory\t", $memory);
			addKeyValue("v","BootStatus", $bootText[$bstatus]) if ($bstatus > 0);
			$variableVerboseMessage .= "\n";
		}
	} 
	elsif ($topic eq "UUID") {
		my $uuid = trySNMPget($snmpOidUuid . '.1');
		addInv2ndKeyValue("UUID", $uuid);
	}
	elsif ($topic eq "MEM") {
		my $memory = trySNMPget($snmpOidMemory . '.1');
		addInv2ndKeyValueUnit("Memory", $memory, "MB");
	}
	elsif ($topic eq "BIOS") {
		my $bios = trySNMPget($snmpOidBiosVersion . '.1');
		addInv2ndKeyValue("BIOS", $bios);
		$biosVersion = $bios if ($bios);
	}
  } #sc2ServerTable
  sub sc2VirtualIoManagerTable {
	my $snmpOidVIOMTable = ".1.3.6.1.4.1.231.2.10.2.2.10.4.8.1."; #sc2VirtualIoManagerTable
	my $snmpOidName		= $snmpOidVIOMTable . '2.1'; #sc2viomCurrentManagerId
	my $snmpOidEnabled	= $snmpOidVIOMTable . '3.1'; #sc2viomEnabled
	my $snmpOidBIOS		= $snmpOidVIOMTable . '4.1'; #sc2viomBiosSupport
	
	{ 
		#my $name	= trySNMPget($snmpOidName);
		my $enabled	= trySNMPget($snmpOidEnabled);
		my $bios	= trySNMPget($snmpOidBIOS);

		my @activationText = ( "none", 
			"unknown", "disabled", "enabled","..unexpected..",
		);

		if (defined $enabled) {
			$enabled = 0 if ($enabled < 0);
			$enabled = 4 if ($enabled > 4);
			addInv2ndKeyValue("VIOM", $activationText[$enabled]);
		}
		if (defined $enabled and defined $bios and $bios != 1) {
			$bios = 0 if ($bios < 0);
			$bios = 4 if ($bios > 4);
			addInv2ndKeyValue("VIOM Bios", $activationText[$bios]);
		}
	} 
  } #sc2VirtualIoManagerTable
  sub sc2SystemBoardTable {
	my $snmpOidSystemBoardTable = '.1.3.6.1.4.1.231.2.10.2.2.10.6.1.1.'; #sc2SystemBoardTable
	my $snmpOidModel	= $snmpOidSystemBoardTable . '3'; #sc2SystemBoardModelName
	my $snmpOidProduct	= $snmpOidSystemBoardTable . '4'; #sc2SystemBoardProductNumber
	my $snmpOidSerial	= $snmpOidSystemBoardTable . '6'; #sc2SystemBoardSerialNumber
	my $snmpOidDesignation	= $snmpOidSystemBoardTable . '7'; #sc2SystemBoardDesignation
	my @tableChecks = (
		$snmpOidModel, $snmpOidProduct, $snmpOidSerial, $snmpOidDesignation,
	);
	{ #PS SystemBoardTable
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		addTableHeader("v","Agent System Board Table") if ($entries);
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidSerial.(\d+\.\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		foreach my $snmpID (@snmpIDs) {
			my $designation = $entries->{$snmpOidDesignation . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $product = $entries->{$snmpOidProduct . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			{ 
				addStatusTopic("v",undef,"SystemBoard", $snmpID);
				addName("v",$designation);
				addSerialIDs("v",$serial, undef);
				addProductModel("v",$product, $model);
				#$variableVerboseMessage .= "\n";
			}
		} # each
	}
  } #sc2SystemBoardTable
  sub sc2TrustedPlatformModuleTable {
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
	$verboseInfo = 1; # inventory
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidHardwareAvailable.(\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		my $printHeader = 0;
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
		
			if ($hwAvailable > 1 or $biosEnabled > 1 or $enabled > 1 or $ownership > 1 ) 
			{
				addTableHeader("v","Agent Trusted Platform Module Table") 
				    if (!$printHeader);
				addStatusTopic("v",$UFTtext[$enabled],"tpm", $id);
				addKeyValue("v","HardwareAvailable", $UFTtext[$hwAvailable]);
				addKeyValue("v","BiosEnabled", $UFTtext[$biosEnabled]);
				addKeyValue("v","Activated", $UFTtext[$activated]);
				addKeyValue("v","Qwnership", $UFTtext[$ownership]);
				$printHeader = 1;
			} 
		} # each
	}
  } #sc2TrustedPlatformModuleTable
  sub sc2ComponentStatusSensorTable { # unused
	my $snmpOidTable = ".1.3.6.1.4.1.231.2.10.2.2.10.8.3.1."; #sc2ComponentStatusSensorTable (2)
	my $snmpOidName		= $snmpOidTable . '3'; #sc2cssSensorDesignation
	my $snmpOidDevice	= $snmpOidTable . '4'; #sc2cssSensorDevice
	my $snmpOidCss		= $snmpOidTable . '7'; #sc2cssSensorCssComponent
	my $snmpOidStatus	= $snmpOidTable . '8'; #sc2cssSensorStatus
	my @statusText = ("none",
		"unknown", "ok", "identify", "prefailure-warning", "failure",
		"not-present", "..unexpected..",
	);
	#false(1), true(2)
	my @tableChecks = (
		$snmpOidName, $snmpOidDevice, $snmpOidCss, $snmpOidStatus, 
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidName.(\d+\.\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		addTableHeader("v","Agent Component Status Sensor Table") if ($#snmpIdx >= 0);
		foreach my $id (@snmpIdx) {
			my $name = $entries->{$snmpOidName . '.' . $id};
			my $device = $entries->{$snmpOidDevice . '.' . $id};
			my $css = $entries->{$snmpOidCss . '.' . $id};
			my $status = $entries->{$snmpOidStatus . '.' . $id};
			my $cssText = undef;
			$cssText = "false" if ($css and $css == 1);
			$cssText = "true" if ($css and $css == 2);
			$status = 0 if (defined $status and $status < 0);
			$status = 7 if (defined $status and $status > 7);
			addStatusTopic("v",$statusText[$status],"CSS", $id);
			addName("v",$name);
			addKeyLongValue("v","Device", $device);
			addKeyValue("v","CustomerSelfService", $cssText);
		} # foreach
	}
  } #sc2ComponentStatusSensorTable
  sub sc2PowerSupplyRedundancyConfigurationTable {
	return if ($main::verboseTable != 1049);

	my $snmpOidTable = ".1.3.6.1.4.1.231.2.10.2.2.10.4.9.1."; 
		#sc2PowerSupplyRedundancyConfigurationTable (1 index)
	my $snmpOidMode			= $snmpOidTable . '2'; #sc2PSRedundancyMode
	my $snmpOidModeConfig		= $snmpOidTable . '3'; #sc2PSRedundancyModeConfig
	my $snmpOidConfigStatus		= $snmpOidTable . '6'; #sc2PSRedundancyConfigurationStatus
	my $snmpOidThresholdStatus	= $snmpOidTable . '7'; #sc2PSRedundancyThresholdStatus
	my $snmpOidStatus		= $snmpOidTable . '8'; #sc2PSRedundancyStatus

	my @modeText = ("none",
		"unknown", "not-specified", "no-redundancy", "psu-redundancy",
		"dual-ac-redundancy", 
		"triple-ac-redundancy", 
		"..unexpected..", 
	); # dual-ac-redundancy(18), triple-ac-redundancy(34)
	my @modeConfigText = ("none",
		"unknown", "no-redundancy",
			"redundancy-1-1",
			"redundancy-2-1",
			"redundancy-2-2",
			"redundancy-3-1",
		"..unexpected..",
	); # redundancy-1-1(19), redundancy-2-1(35), redundancy-2-2(36), redundancy-3-1(51)
	my @compStatusText = ("none",
		"ok","warning","error","..unexpected..", "unknown",
		"..unexpected..",
	);
	my @statusText = ( "none",
		"unknown","not-available","ok","warning","error",
		"..unexpected.."
	);
	my @tableChecks = (
		$snmpOidMode, $snmpOidModeConfig, $snmpOidConfigStatus, $snmpOidThresholdStatus,
		$snmpOidStatus,
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIdx = ();
		# store fetched data
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIdx, $1) if ($snmpKey =~ m/$snmpOidMode.(\d+)/);
		}		
		@snmpIdx = Net::SNMP::oid_lex_sort(@snmpIdx);
		#addTableHeader("v","Agent Power Redundancy Table") if ($#snmpIdx >= 0);
		my $printedHeader = 0;
		foreach my $id (@snmpIdx) {
			my $mode = $entries->{$snmpOidMode . '.' . $id};
			my $modeConfig = $entries->{$snmpOidModeConfig . '.' . $id};
			my $configStatus = $entries->{$snmpOidConfigStatus . '.' . $id};
			my $thresholdStatus = $entries->{$snmpOidThresholdStatus . '.' . $id};
			my $status = $entries->{$snmpOidStatus . '.' . $id};
			$status = 0 if (!defined $status);
			$status = 6 if ($status and $status > 6);
			next if ($status == 2);
			next if ($status == 1);
			$mode = 0 if (!defined $mode);
			$mode = 7 if ($mode == 5 or $mode == 6);
			$mode = 5 if ($mode == 18); $mode = 6 if ($mode == 34);
			$mode = 7 if ($mode  > 7);
			$modeConfig = 0 if (!defined $modeConfig);
			$modeConfig = 7 if ($modeConfig == 3 or $modeConfig == 4 
				or $modeConfig == 5 or $modeConfig == 6);
			$modeConfig = 3 if ($modeConfig == 19);
			$modeConfig = 4 if ($modeConfig == 35);
			$modeConfig = 5 if ($modeConfig == 36);
			$modeConfig = 6 if ($modeConfig == 51);
			$modeConfig = 7 if ($modeConfig > 7);
			$configStatus = 0 if (!defined $configStatus);
			$configStatus = 6 if ($configStatus >6);
			$thresholdStatus = 0 if (!defined $thresholdStatus);
			$thresholdStatus = 6 if ($thresholdStatus >6);
			addTableHeader("v","Agent Power Redundancy Table") if (!$printedHeader);
			$printedHeader = 1;

			addStatusTopic("v",$statusText[$status],"PSU", $id);
			addKeyValue("v","Mode\t\t", $modeText[$mode]);
			addKeyValue("v","ModeConfiguration", $modeConfigText[$modeConfig]);
			addKeyValue("v","ConfigurationStatus", $compStatusText[$configStatus]);
			addKeyValue("v","ThresholdStatus\t", $compStatusText[$thresholdStatus]);
		} # foreach
	}
  } #sc2PowerSupplyRedundancyConfigurationTable
#------------ SC.mib
  sub sc_sniScBiosVersionString { # ONLY FOR SVAGT < 7
	return if ($biosVersion and $main::verboseTable != 2000);
	my $snmpOidBiosVersion = ".1.3.6.1.4.1.231.2.10.2.2.5.4.14.0"; #sniScBiosVersionString
	$exitCode = 0;
	my $scBiosVersion = trySNMPget($snmpOidBiosVersion);
	$exitCode = 3 if (!defined $scBiosVersion);
	if ($exitCode == 0 and $optInventory and !$biosVersion) {
		addInv2ndKeyValue("BIOS", $scBiosVersion);
		$biosVersion = $scBiosVersion;
	}
  } #sc_sniScBiosVersionString
  sub sc_powerOnTime {
	my $snmpOidOnTime = ".1.3.6.1.4.1.231.2.10.2.2.5.9.11.0"; #powerOnTime
	$exitCode = 0;
	my $scOnTime = trySNMPget($snmpOidOnTime);
	$exitCode = 3 if (!defined $scOnTime);
	if ($exitCode == 0 and $optInventory) {
		my $timeString = gmctime($scOnTime);
		addInv2ndKeyValue("OnTime", "$timeString");
	}
  } #sc_powerOnTime
#------------ VV.mib
  sub vv_sieVvCompDefTable {
       	my $response = undef;
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.10.3.1.1.'; #sieVvCompDefTable
	my $snmpOidTypeNo	= $snmpOidTable . '2'; #sieVvCompDefType
	my $snmpOidName		= $snmpOidTable . '3'; #sieVvCompDefName
	my @tableChecks = (
		$snmpOidTypeNo, $snmpOidName,
	);
	{
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidTypeNo, 1);
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		$exitCode = 0 if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
		    my $no = $entries->{$snmpOidTypeNo . '.' . $snmpID};
		    my $name = $entries->{$snmpOidName . '.' . $snmpID};
		    $response->{$no} = $name;
		} # for keys
	}
	return $response;
  } #vv_sieVvCompDefTable
  sub vv_sieVvPhysNodeDefTable {
       	my $response = undef;
	my $snmpOidTable = '.1.3.6.1.4.1.231.2.10.2.10.3.2.1.'; #sieVvPhysNodeDefTable
	my $snmpOidTypeNo	= $snmpOidTable . '2'; #sieVvPhysNodeDefType
	my $snmpOidName		= $snmpOidTable . '3'; #sieVvPhysNodeDefName
	my @tableChecks = (
		$snmpOidTypeNo, $snmpOidName,
	);
	{
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();
		@snmpIDs = getSNMPTableIndex($entries, $snmpOidTypeNo, 1);
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		$exitCode = 0 if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
		    my $no = $entries->{$snmpOidTypeNo . '.' . $snmpID};
		    my $name = $entries->{$snmpOidName . '.' . $snmpID};
		    $response->{$no} = $name;
		} # for keys
	}
	return $response;
  } #vv_sieVvPhysNodeDefTable
  sub vv_sieVvInfoTable {
	my $snmpOidVvInfoTable = '.1.3.6.1.4.1.231.2.10.2.10.5.1.1.'; #sieVvInfoTable
	my $snmpOidPhysType	= $snmpOidVvInfoTable . '2'; #sieVvInfoPhysContNo
	my $snmpOidComponentType= $snmpOidVvInfoTable . '4'; #sieVvInfoCompType
	my $snmpOidVendor	= $snmpOidVvInfoTable . '5'; #sieVvInfoVendor
	my $snmpOidProdName	= $snmpOidVvInfoTable . '6'; #sieVvInfoProductName
	my $snmpOidProdNumber	= $snmpOidVvInfoTable . '7'; #sieVvInfoProductNumber
	my $snmpOidProdDescription	= $snmpOidVvInfoTable . '8'; #sieVvInfoProductDescription
	my $snmpOidVersion	= $snmpOidVvInfoTable . '9'; #sieVvInfoVersion
 	my $snmpOidSerial	= $snmpOidVvInfoTable . '11'; #sieVvInfoSerialNo
	my @tableChecks = (
		$snmpOidPhysType, $snmpOidComponentType,
		$snmpOidVendor, $snmpOidProdName,  
		$snmpOidProdDescription, $snmpOidVersion, $snmpOidSerial, 
	);
	my $componentTypeRef = vv_sieVvCompDefTable();
	$exitCode = 3;
	my $physicalNodeRef = undef;
	$physicalNodeRef = vv_sieVvPhysNodeDefTable()  if ($main::verbose);
	$exitCode = 3;
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidProdName.(\d+)/);
		}
		#print "--- Count = $#snmpIDs\n" if ($main::verbose >= 10);
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","VersionView Component Table") if ($#snmpIDs >= 0);
		$exitCode = 0 if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
			my $compType = $entries->{$snmpOidComponentType . '.' . $snmpID};
			my $physType = $entries->{$snmpOidPhysType . '.' . $snmpID};
			my $vendor = $entries->{$snmpOidVendor . '.' . $snmpID};
			my $pname = $entries->{$snmpOidProdName . '.' . $snmpID};
			#my $pnumber = $entries->{$snmpOidProdNumber . '.' . $snmpID};
			my $pdescr = $entries->{$snmpOidProdDescription . '.' . $snmpID};
			my $version = $entries->{$snmpOidVersion . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			$version = undef if ($version and $version eq "N/A");
			$vendor = undef if ($vendor and $vendor eq "unknown");
			$vendor = undef if ($vendor and $vendor eq "N/A");

			my $compTypeString = undef;
			if (defined $compType and $componentTypeRef) {
			    $compTypeString = $componentTypeRef->{$compType}
			}

			my $physicalTypeString = undef;
			if (defined $physType and $physicalNodeRef and $main::verbose) {
			    $physicalTypeString = $physicalNodeRef->{$physType}
			}

			addStatusTopic("v", undef, "Component", $snmpID);
			addKeyLongValue("v","Name\t",$pname);
			addKeyLongValue("v","Description", $pdescr);
			addKeyLongValue("v","Version\t",$version);
			addKeyLongValue("v","SerialID",$serial);
			addKeyLongValue("v","Vendor\t",$vendor);
			addKeyLongValue("v","Type\t",$compTypeString);
			addKeyLongValue("v","Container",$physicalTypeString)
			    if ($main::verbose);
			
			$variableVerboseMessage .= "\n";
		} # for keys
	}
  } #vv_sieVvInfoTable
#------------ BIOS.mib
sub BIOS_sniBios {
	return if ($biosVersion and $main::verboseTable != 1022);
        # .1.3.6.1.4.1.231.2.10.2.2.1 (sniBios)
        my $snmpOidBiosGroup = '.1.3.6.1.4.1.231.2.10.2.2.1.' ;#sniBios
        my $snmpOidMajorVersion         = $snmpOidBiosGroup . '1.0'; #sniBiosVersionMajor
        my $snmpOidMinorVersion         = $snmpOidBiosGroup . '2.0'; #sniBiosVersionMinor
        my $snmpOidDiagStatus           = $snmpOidBiosGroup . '3.0'; #sniBiosDiagnosticStatus

        $exitCode = 0;
        my $majVersion = trySNMPget($snmpOidMajorVersion);
	$exitCode = 2 if (!defined $majVersion);
        $exitCode = 3 if ($exitCode == 0 and $majVersion == -1);
	my $minVersion = undef;
	$minVersion = trySNMPget($snmpOidMinorVersion) if ($exitCode == 0);
	$exitCode = 3 if ($exitCode == 0 and !$majVersion and !$minVersion); # prevent Version=0.0
	$minVersion = undef if ($minVersion and $minVersion == -1);
	if ($exitCode == 0 and $optInventory and (!$biosVersion or $main::verboseTable == 1022)) {
		my $versionString = "V$majVersion.$minVersion";
		addInv2ndKeyValue("BIOS", $versionString);
		$biosVersion = $versionString;
	}
} #BIOS_sniBios
#------------ RAID
#our @raidCompStatusText = ( "none",	"ok", "prefailure", "failure", "..unexpected..",);
sub RAIDsvrStatus {
	my $snmpOidSrvStatusGroup = '.1.3.6.1.4.1.231.2.49.1.3.'; #svrStatus
	my $snmpOidOverall	= $snmpOidSrvStatusGroup . '4.0'; #svrStatusOverall

	$exitCode = 0;
	my $overall = trySNMPget($snmpOidOverall);
	$exitCode = 3 if (!defined $overall);
	if (defined $overall and $optInventory) {
		addInv1stLevel("Special Agents Information");
		addInv2ndKeyValue("RAID", "discovered");
	}
} #RAIDsvrStatus
#------------ S31.mib
  sub s31CheckAgentInfo {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidAgtName	= $snmpOidAgentInfoGroup . '9.0' ; #s31AgentName
	$exitCode = 0;
	my $name = trySNMPget($snmpOidAgtName);
	$exitCode = 3 if (!defined $name);
  } #s31CheckAgentInfo
  sub s31AgentInfo {
	#--      s31AgentInfo group:              1.3.6.1.4.1.7244.1.1.1.1
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidIP		= $snmpOidAgentInfoGroup . '1.0' ; #s31AgentIpAddress
	my $snmpOidAdmURL	= $snmpOidAgentInfoGroup . '5.0' ; #s31AgentAdministrativeUrl
	my $snmpOidDate		= $snmpOidAgentInfoGroup . '7.0' ; #s31AgentDateTime
	my $snmpOidAgtName	= $snmpOidAgentInfoGroup . '9.0' ; #s31AgentName

	$exitCode = 0;
	my $name = trySNMPget($snmpOidAgtName);
	$exitCode = 3 if (!defined $name);
	my $ip = undef;
	my $url = undef;
	my $date = undef;
	my $gateway = undef;

	if ($exitCode==0) {
		$ip = trySNMPget($snmpOidIP);
		$url = trySNMPget($snmpOidAdmURL);
		$date = trySNMPget($snmpOidDate);
		addInv2ndKeyValue("Name", $name);
		addInv2ndKeyValue("LocalTime", $date);
		addInv2ndKeyValue("IP\t", $ip);
		addInvAdminURL($url);
	}
  } #s31AgentInfo
  sub s31SysCtrlInfo_Strings {
	my $snmpOidSysCtrlInfoGrp = ".1.3.6.1.4.1.7244.1.1.1.3.1."; #s31SysCtrlInfo
 	my $snmpOidHousing	= $snmpOidSysCtrlInfoGrp . '4.0'; #s31SysCtrlHousingType
	# s31SysCtrlStatLed ... 7
	# s31SysCtrlNumberUps ... 9
	my $housing		= trySNMPget($snmpOidHousing);
	addInv2ndKeyValue("HousingType", $housing);
 }
  sub s31SysCtrlInfo_Counter {
	my $snmpOidSysCtrlInfoGrp = ".1.3.6.1.4.1.7244.1.1.1.3.1."; #s31SysCtrlInfo
	my $snmpOidNrFan	= $snmpOidSysCtrlInfoGrp . '1.0'; #s31SysCtrlNumberFans
	my $snmpOidNrSensor	= $snmpOidSysCtrlInfoGrp . '2.0'; #s31SysCtrlNumberTempSensors
	my $snmpOidNrPSU	= $snmpOidSysCtrlInfoGrp . '3.0'; #s31SysCtrlNumberPowerSupplyUnit
	my $snmpOidHousing	= $snmpOidSysCtrlInfoGrp . '4.0'; #s31SysCtrlHousingType
	my $snmpOidNrUps	= $snmpOidSysCtrlInfoGrp . '11.0'; #s31SysCtrlNumberOfUps

	my $snmpOidPowerSupplyGrp = ".1.3.6.1.4.1.7244.1.1.1.3.2."; #s31PowerSupply
	my $snmpOidNrPRed	= $snmpOidPowerSupplyGrp . '2.0'; #s31SysPowerSupplyRedundancy

	addInv1stLevel("Agent System Control Counter");
	my $nrfan		= trySNMPget($snmpOidNrFan);
	my $nrtempsensor	= trySNMPget($snmpOidNrSensor);
	my $nrpsu		= trySNMPget($snmpOidNrPSU);
	my $nrpsured		= trySNMPget($snmpOidNrPRed);
	my $housing		= trySNMPget($snmpOidHousing);
	my $nrups		= trySNMPget($snmpOidNrUps);
	addInv2ndKeyIntValue("Fans\t", $nrfan);
	addInv2ndKeyIntValue("TemperaturSensors", $nrtempsensor);
	addInv2ndKeyIntValue("PowerSupplyUnits", $nrpsu);
	addInv2ndKeyIntValue("PSURedundancy", $nrpsured);
	addInv2ndKeyIntValue("UPS\t\t", $nrups);
  } #s31SysCtrlInfo
  sub s31AgentDns {
  	my $snmpOidAgentDnsGroup = '.1.3.6.1.4.1.7244.1.1.1.1.14.'; #s31AgentDns
	my $snmpOidEnabled	= $snmpOidAgentDnsGroup . '1.0'; #s31AgentDnsEnable
	my $snmpOidIp1		= $snmpOidAgentDnsGroup . '2.0'; #s31AgentDnsIpAddress1
	my $snmpOidIp2		= $snmpOidAgentDnsGroup . '3.0'; #s31AgentDnsIpAddress2
	my $snmpOidIp61		= $snmpOidAgentDnsGroup . '6.0'; #s31AgentDnsAddress1
	my $snmpOidIp62		= $snmpOidAgentDnsGroup . '7.0'; #s31AgentDnsAddress2
	my $enabled = trySNMPget($snmpOidEnabled);
	my @enableText = ("none",
		"unknown", "disable", "enable", "..unexpected..",
	);
	$enabled = 0 if (!defined $enabled);
	$enabled = 4 if ($enabled and $enabled > 4);
	addInv2ndKeyValue("DNS\t", $enableText[$enabled]);
	if ($enabled == 3) {
		my $ip1 = trySNMPget($snmpOidIp1);
		my $ip2 = trySNMPget($snmpOidIp2);
		addInv2ndKeyValue("DNS IP", $ip1);
		addInv2ndKeyValue("DNS IP", $ip2);
		$ip1 = trySNMPget($snmpOidIp61);
		$ip2 = trySNMPget($snmpOidIp62);
		addInv2ndKeyValue("DNS IP", $ip1);
		addInv2ndKeyValue("DNS IP", $ip2);
	}
  } #s31AgentDns
  sub s31SysChassis {
	my $topic = shift;
	my $snmpOidSysChassis = ".1.3.6.1.4.1.7244.1.1.1.3.5."; #s31SysChassis
	my $snmpOidBladeID	= $snmpOidSysChassis . '1.0'; #s31SysChassisSerialNumber.0
	my $snmpOidVIOM		= $snmpOidSysChassis . '3.0';# s31SysChassisManagedByViom
	if ($topic eq "ID") {
		my $serverID = trySNMPget($snmpOidBladeID);
		addInv2ndKeyValue("ID\t", $serverID);
	}
	elsif ($topic eq "VIOM") {
		my @viomText = ("none", 
			"unknown", "unmanaged",	"managed",
		);
		my $viom = trySNMPget($snmpOidVIOM);
		addInv2ndKeyValue("VIOM", $viomText[$viom]) if (defined $viom);
	}
  }
  sub s31_AddSubBlades {
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
			push(@subblades,"$name($count)");
			$exitCode = 0;
		}
	} # entries
  } #s31_AddSubBlades
  sub s31BladesInside {
	$exitCode  = 3;
	$msg = '';
	{ # Server Blade
		my $snmpOidSrvBlade	= '.1.3.6.1.4.1.7244.1.1.1.4.'; #s31ServerBlade
		my $snmpOidSrvBladeTable = $snmpOidSrvBlade . '2.1.1.'; #s31SvrBladeTable
		my $snmpOidStatus		= $snmpOidSrvBladeTable . '2'; #s31SvrBladeStatus
		s31_AddSubBlades($snmpOidStatus,"ServerBlades",0);
	}
	{ # FSIOM
		my $snmpOidBladeFsiom		= '.1.3.6.1.4.1.7244.1.1.1.3.8.'; #s31SysFsiom
		my $snmpOidState		= $snmpOidBladeFsiom . '1.0'; #s31SysFsiomStatus.0 

		my $tmpOverallFsiom = trySNMPget($snmpOidState);
		if (defined $tmpOverallFsiom) {
			#$msg .= "FSIOM(1) " if (!$optInventory);
			push(@subblades,"FSIOM(1)");
			$exitCode = 0;
		}
	}
	{ # SwitchBlade
		my $snmpOidSwBladeTable = '.1.3.6.1.4.1.7244.1.1.1.5.1.1.'; #s31SwitchBladeTable
		my $snmpOidStatus		= $snmpOidSwBladeTable . '2'; #s31SwitchBladeStatus
		s31_AddSubBlades($snmpOidStatus,"Switch",0);
	}
	{ # FCPT
		my $snmpOIDFcPTInfoTable = '1.3.6.1.4.1.7244.1.1.1.8.1.2.1.'; #s31FcPassThroughBladeInfoTable
		my $snmpOidStatus = $snmpOIDFcPTInfoTable . '2'; #s31FcPassThroughBladeInfoStatus
		s31_AddSubBlades($snmpOidStatus,"FibreChannelPassThrough",0);
	}
	{ #Phy LPT
		my $snmpOIDPhyBladeTable = '1.3.6.1.4.1.7244.1.1.1.10.1.1.'; #s31PhyBladeTable
		my $snmpOidStatus		= $snmpOIDPhyBladeTable . '9'; #s31PhyBladeStatus
		s31_AddSubBlades($snmpOidStatus,"LANPT",0);
	}
	{ # FC Switch
		my $snmpOIDFCSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.12.1.1.'; #s31FCSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDFCSwitchBladeTable . '17'; #s31FCSwitchBladeStatus
		s31_AddSubBlades($snmpOidStatus,"FCSwitch",0);
	}
	{ #IB Switch
		my $snmpOIDIBSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.16.1.1.'; #s31IBSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDIBSwitchBladeTable . '13'; #s31IBSwitchBladeStatus
		s31_AddSubBlades($snmpOidStatus,"IBSwitch",0);
	}
	{ # SAS
		my $snmpOIDSASSwitchBladeTable = '1.3.6.1.4.1.7244.1.1.1.17.1.1.'; #s31SASSwitchBladeTable
		my $snmpOidStatus	= $snmpOIDSASSwitchBladeTable . '13'; #s31SASSwitchBladeStatus
		s31_AddSubBlades($snmpOidStatus,"SASwitch",0);
	}
	{ #KVM
		my $snmpOIDKvmBladeTable = '1.3.6.1.4.1.7244.1.1.1.11.1.1.'; #s31KvmBladeTable
		my $snmpOidStatus	= $snmpOIDKvmBladeTable . '18'; #s31KvmBladeStatus
		s31_AddSubBlades($snmpOidStatus,"KVM",1);
	}
	{ # Storage
		my $snmpOIDStorageBladeTable = '1.3.6.1.4.1.7244.1.1.1.13.1.1.'; #s31StorageBladeTable
		my $snmpOidStatus	= $snmpOIDStorageBladeTable . '8'; #s31StorageBladeStatus
		s31_AddSubBlades($snmpOidStatus,"Storage",1);
	}
	addInv2ndKeyValue("Sub-Blades","@subblades") if ($#subblades >= 0 and $optInventory);
  } #s31BladesInside
  sub s31_Network {
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.7244.1.1.1.1.'; #s31AgentInfo
	my $snmpOidGateway	= $snmpOidAgentInfoGroup . '3.0' ; #s31AgentGateway
	my $gateway	= trySNMPget($snmpOidGateway);
	addInv1stLevel("Agent Information around Network");
	addInv2ndKeyValue("Gateway", $gateway);

	s31AgentDns();
  }
  sub s31MgmtBladeTable {
	my $snmpOidMgmtBladeTable = '.1.3.6.1.4.1.7244.1.1.1.2.1.1.'; #s31MgmtBladeTable (1)
	my $snmpOidStatus	= $snmpOidMgmtBladeTable .  '2'; #s31MgmtBladeStatus
	my $snmpOidManufact	= $snmpOidMgmtBladeTable .  '3'; #s31MgmtBladeManufacture
	my $snmpOidSerial	= $snmpOidMgmtBladeTable .  '5'; #s31MgmtBladeSerialNumber
	my $snmpOidProduct	= $snmpOidMgmtBladeTable .  '6'; #s31MgmtBladeProductName
	my $snmpOidModel	= $snmpOidMgmtBladeTable .  '7'; #s31MgmtBladeModelName
	my $snmpOidHWVersion	= $snmpOidMgmtBladeTable .  '8'; #s31MgmtBladeHardwareVersion
	my $snmpOidFWVersion	= $snmpOidMgmtBladeTable .  '9'; #s31MgmtBladeFirmwareVersion
	my $snmpOidMAC		= $snmpOidMgmtBladeTable . '10'; #s31MgmtBladePhysicalAddress
	my $snmpOidRunMode	= $snmpOidMgmtBladeTable . '11'; #s31MgmtBladeRunMode
	my @tableChecks = (
		$snmpOidStatus, $snmpOidSerial, $snmpOidProduct, $snmpOidModel, 
		$snmpOidMAC, $snmpOidRunMode, $snmpOidManufact, $snmpOidHWVersion,
		$snmpOidFWVersion,
	);
	my @statusText = ("none",
		"unknown", "ok", "not-present",	"error", "critical",
		"standby", "..unexpected..",
	);
	my @modeText = ( "none",
		"unknown", "master", "slave", "..unexpected..",
	);
	{ # BLADE ManagementBlade
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		addTableHeader("v","Management Blade Table");
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidStatus.(\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		foreach my $snmpID (@snmpIDs) {
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $serial = $entries->{$snmpOidSerial . '.' . $snmpID};
			my $product = $entries->{$snmpOidProduct . '.' . $snmpID};
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $mac = $entries->{$snmpOidMAC . '.' . $snmpID};
			my $runmode = $entries->{$snmpOidRunMode . '.' . $snmpID};
			my $manufact	= $entries->{$snmpOidManufact . '.' . $snmpID};
			my $hwversion	= $entries->{$snmpOidHWVersion . '.' . $snmpID};
			my $fwversion	= $entries->{$snmpOidFWVersion . '.' . $snmpID};
			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);
			$runmode = 0 if (!defined $runmode or $runmode < 0);
			$runmode = 4 if ($runmode > 4);
			{ 
				addStatusTopic("v",$statusText[$status], "MMB", $snmpID);
				addSerialIDs("v",$serial, undef);
				addProductModel("v",$product,$model);
				addMAC("v", $mac);
				addKeyValue("v","RunMode",$modeText[$runmode]) if (defined $runmode);
				addKeyValue("","Maunfacturer", $manufact); # inv
				addKeyValue("","HW-Version", $hwversion); # inv
				addKeyValue("","FW-Version", $fwversion); # inv
				#$variableVerboseMessage .= "\n";
			}
		} # each
	}
  } #s31MgmtBladeTable
#------------ MMB-COM-MIB.mib
  sub mmbcomCheckAgentInfo {
	my $snmpOidUnitInfoGroup = '.1.3.6.1.4.1.211.1.31.1.1.1.2.'; #mmb sysinfo unitInformation
	my $snmpOidLocalID = $snmpOidUnitInfoGroup . '1.0'; #localServerUnitId
	$exitCode = 0;
	my $localID = trySNMPget($snmpOidLocalID);
	$exitCode = 3 if (!defined $localID);
  }
  sub mmbcomAgentInfo { # seems not to be supported !
	# 1.3.6.1.4.1.211.1.31.1 (primequest) .1(mmb) .1(sysinfo) .1(agentInfo)
	my $snmpOidAgentInfoGroup = '.1.3.6.1.4.1.211.1.31.1.1.1.1.'; #agentInfo
	my $snmpOidId		= $snmpOidAgentInfoGroup . '1.0' ;#agentId
	my $snmpOidCompany	= $snmpOidAgentInfoGroup . '2.0' ;#agentCompany
	my $snmpOidVersion	= $snmpOidAgentInfoGroup . '3.0' ;#agentVersion

	$exitCode = 0;
	my $id = trySNMPget($snmpOidId);
	$exitCode = 3 if (!defined $id);
	my $company = undef;
	my $version = undef;
	if ($exitCode == 0) {
		$company = trySNMPget($snmpOidCompany);
		$version = trySNMPget($snmpOidVersion);
	}
	$agentVersion{"Name"} = $id;
	$agentVersion{"Company"} = $company;
	$agentVersion{"Version"} = $version;
  } #mmbcomAgentInfo
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
  sub primequestUnitTableChassis {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.211.1.31.1.1.1.2.3.1.'; #mmb sysinfo unitInformation unitTable
	my $snmpOidDesignation	= $snmpOidUnitTable .  '4'; #unitDesignation
	my $snmpOidModel	= $snmpOidUnitTable .  '5'; #unitModelName
	my $snmpOidSerial	= $snmpOidUnitTable .  '7'; #unitSerialNumber
	#my $snmpOidLocation	= $snmpOidUnitTable .  '8'; #unitLocation
	#my $snmpOidContact	= $snmpOidUnitTable .  '9'; #unitContact
	my $snmpOidAdmURL	= $snmpOidUnitTable . '10'; #unitAdminURL
	
	$exitCode = 0;
	my $designation = trySNMPget($snmpOidDesignation . '.1');
	$exitCode = 3 if (!defined $designation);
	if ($exitCode==0) {
		my $model = trySNMPget($snmpOidModel . '.1');
		my $serial = trySNMPget($snmpOidSerial . '.1');
		#my $location = trySNMPget($snmpOidLocation . '.1');
		#my $contact = trySNMPget($snmpOidContact . '.1');
		my $admURL = trySNMPget($snmpOidAdmURL . '.1');
		{
			addInv2ndKeyValue("ID\t", $serial);
			addInv2ndKeyValue("Name", $designation);
			addInv2ndKeyValue("Model", $model);
			addInvAdminURL($admURL);
		}
	} 
  } #primequestUnitTableChassis
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
	{ # UnitTable - needs a lot of time
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		addTableHeader("v","Unit Table");
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidClass.(\d+)/);
		}
		
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
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

			my $printThis = 0;
			$printThis = 1 if ($serial);
			$printThis = 1 if ($main::verbose >= 3);

			if ($printThis) {
				addStatusTopic("v",undef, "Unit", $snmpID);
				addSerialIDs("v",$serial, undef);
				addKeyValue("v","Class", $pqClassText[$class]);
				addName("v",$designation);
				addLocationContact("v",$location, $contact);
				addAdminURL("v",$admURL);
				addProductModel("v",undef, $model);
				$variableVerboseMessage .= "\n";
			} # print this ?
		} # for each
	}
  } #primequestUnitTable
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
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		addTableHeader("v","Management Node Table");
		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidAddress.(\d+\.\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
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
				addMAC("v", $mac);
				addKeyValue("v","Class", $classText[$class]) if ($class);
				#$variableVerboseMessage .= "\n";
			}
		} # each
	} # system and specific table
  } #primequestManagementNodeTable
  sub primequestManagementProcessorTable {
	my $snmpOidTable = ".1.3.6.1.4.1.211.1.31.1.1.1.3.4.1."; #managementProcessorTable (2)
	my $snmpOidModel	= $snmpOidTable . '3'; #spModelName
	my $snmpOidFw		= $snmpOidTable . '4'; #spFirmwareVersion
	my @tableChecks = (
		$snmpOidModel, $snmpOidFw, 
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidModel.(\d+\.\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","Agent Management Processor Table") if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
			my $model = $entries->{$snmpOidModel . '.' . $snmpID};
			my $fw = $entries->{$snmpOidFw . '.' . $snmpID};
			addStatusTopic("v",undef, "Processor", $snmpID);
			addProductModel("v",undef, $model);
			addKeyValue("v","FW-Version", $fw);			
		} # each
	}
  } #primequestManagementProcessorTable
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
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidBootStatus.(\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","Server Table") if ($#snmpIDs >= 0);
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
				addKeyValue("v","UUID\t",$uuid);
				#$variableVerboseMessage .= "\n";
			}
		} # each
	}
  } #primequestServerTable
  sub primequestSystemBoardTable {
	my $snmpOidTable = ".1.3.6.1.4.1.211.1.31.1.1.1.6.1.1."; #systemBoardTable (1)
	my $snmpOidModel	= $snmpOidTable . '2'; #systemBoardModelName
	my $snmpOidProduct	= $snmpOidTable . '3'; #systemBoardProductNumber
	my $snmpOidRevision	= $snmpOidTable . '4'; #systemBoardRevision
	my $snmpOidSerial	= $snmpOidTable . '5'; #systemBoardSerialNumber
	my @tableChecks = (
		$snmpOidModel, $snmpOidProduct, $snmpOidRevision, 
		$snmpOidSerial,
	);
        {
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidModel.(\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","System Board Table") if ($#snmpIDs >= 0);
 		foreach my $snmpID (@snmpIDs) {
			my $model	= $entries->{$snmpOidModel . '.' . $snmpID};
			my $product	= $entries->{$snmpOidProduct . '.' . $snmpID};
			my $rev		= $entries->{$snmpOidRevision . '.' . $snmpID};
			my $serial	= $entries->{$snmpOidSerial . '.' . $snmpID};
			$product = undef if ($product and $model and $product eq $model);
			addStatusTopic("v",undef, "SystemBoard", $snmpID);
			addSerialIDs("v",$serial, undef);
			addProductModel("v",$product,$model);
			addKeyValue("v","Revision",$rev);
		} # each
        }
  } #primequestSystemBoardTable
  sub primequestFirmwareVersionTable {
	my $snmpOidTable = ".1.3.6.1.4.1.211.1.31.1.1.1.9.2.1."; #firmwareVersionTable (2)
	my $snmpOidType		= $snmpOidTable . '2'; #fwType
	my $snmpOidModel	= $snmpOidTable . '3'; #fwModelName
	my $snmpOidVersion	= $snmpOidTable . '4'; #fwVersion
	my $snmpOidLocationNr	= $snmpOidTable . '5'; #fwLocation
	my @typeText = ("none",
		"bios", "management-controller", "remote-management-controller","pal","sal",
		"efi","baseboard-management-controller","gswb-offline0","gswb-offline1","gswb-online0",
		"gswb-online1", undef, undef, undef, undef,
		undef, undef, undef, undef, "total", 
		"..unexpected..",
	);
	my @tableChecks = (
		$snmpOidType, $snmpOidModel, $snmpOidVersion, 
		$snmpOidLocationNr,
	);
        {
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			print "$snmpKey --- $entries->{$snmpKey}\n" if ($main::verbose >= 20);
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidType.(\d+\.\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","Firmware Version Table") if ($#snmpIDs >= 0);
 		foreach my $snmpID (@snmpIDs) {
			my $model	= $entries->{$snmpOidModel . '.' . $snmpID};
			my $type	= $entries->{$snmpOidType . '.' . $snmpID};
			my $version	= $entries->{$snmpOidVersion . '.' . $snmpID};
			my $locnr	= $entries->{$snmpOidLocationNr . '.' . $snmpID};
			$type = 0 if (!defined $type);
			$type = 21 if ($type != 20 and $type > 11);
			$snmpID =~ m/(\d+)\.\d+/;
			my $unitId = $1;
			my $unitType = "Chassis";
			$unitType	= "SystemBoard" if ($unitId >= 19);
			$unitType	= "MMB" if ($unitId >= 136);
			addStatusTopic("v",undef, "Firmware", $unitId);
			addKeyValue("v", "Unit", $unitType);
			addKeyValue("v", "Type", $typeText[$type]);
			addProductModel("v",undef,$model);
			addKeyValue("v","Version",$version);
			addKeyValue("v","LocationNr",$locnr);
		} # each
        }
  } #primequestFirmwareVersionTable
  sub primequestDeployLanInterfaceTable {
	my $snmpOidTable = ".1.3.6.1.4.1.211.1.31.1.1.1.10.3.1."; #deployLanInterfaceTable (2)
	my $snmpOidMAC	= $snmpOidTable . '3';#dplLanMacAddress
	my @tableChecks = (
		$snmpOidMAC,
	);
        {
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			print "$snmpKey --- $entries->{$snmpKey}\n" if ($main::verbose >= 20);
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidMAC.(\d+\.\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","Lan Interface Table") if ($#snmpIDs >= 0);
 		foreach my $snmpID (@snmpIDs) {
			my $mac	= $entries->{$snmpOidMAC . '.' . $snmpID};
			$snmpID =~ m/(\d+)\.(\d+)/;
			my $unitId = $1;
			my $ifIf = $2;
			$mac = undef if ($mac =~ m/FF:FF:FF:FF:FF:FF/);
			next if (!$mac);
			addStatusTopic("v",undef, "LanIF", $snmpID);
			addMAC("v", $mac);
		} # each
	}
  } #primequestDeployLanInterfaceTable
  sub primequestTrustedPlatformModuleTable { # 2013-06 ... EMPTY TABLE
	my $snmpOidTable = '.1.3.6.1.4.1.211.1.31.1.1.1.6.8.1.'; #trustedPlatformModuleTable (1)
	my $snmpOidHW		= $snmpOidTable . '2'; #tpmHardwareAvailable
	my $snmpOidBiosEnabled	= $snmpOidTable . '3'; #tpmBiosEnabled
	my $snmpOidEnabled	= $snmpOidTable . '4'; #tpmEnabled
	my $snmpOidActivated	= $snmpOidTable . '5'; #tpmActivated
	my $snmpOidOwnership	= $snmpOidTable . '6'; #tpmOwnership
	my @tableChecks = (
		$snmpOidHW, $snmpOidBiosEnabled, $snmpOidEnabled, $snmpOidActivated, 
		$snmpOidOwnership,
	);
	my @uftText = ("none",
		"unknown", "false", "true", "..unexpected..",
	);
	{
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			print "$snmpKey --- $entries->{$snmpKey}\n" if ($main::verbose >= 20);
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidHW.(\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		addTableHeader("v","Trusted Platform Module Table") if ($#snmpIDs >= 0);
		foreach my $snmpID (@snmpIDs) {
			my $enabled		= $entries->{$snmpOidEnabled . '.' . $snmpID};
			my $activated	= $entries->{$snmpOidActivated . '.' . $snmpID};
			my $hw	= $entries->{$snmpOidHW . '.' . $snmpID};
			my $bios	= $entries->{$snmpOidBiosEnabled . '.' . $snmpID};
			my $own	= $entries->{$snmpOidOwnership . '.' . $snmpID};
			$enabled = 0 if (! defined $enabled);		$enabled = 4 if ($enabled > 4);
			$activated = 0 if (! defined $activated);	$activated = 4 if ($activated > 4);
			$hw = 0 if (! defined $hw);			$hw = 4 if ($hw > 4);
			$bios = 0 if (! defined $bios);			$bios = 4 if ($bios > 4);
			$own = 0 if (! defined $own);			$own = 4 if ($own > 4);
			addStatusTopic("v",undef, "TPM", $snmpID);
			addKeyValue("v", "Enabled\t\t", $uftText[$enabled]);
			addKeyValue("v", "Activated\t", $uftText[$activated]);
			addKeyValue("v", "HardwareAvailable", $uftText[$hw]) if ($enabled and $enabled==3 and $activated and $activated==3);
			addKeyValue("v", "BiosEnabled\t", $uftText[$bios]) if ($enabled and $enabled==3 and $activated and $activated==3);
			addKeyValue("v", "Ownership\t", $uftText[$own]) if ($enabled and $enabled==3 and $activated and $activated==3);
		} # each
	}

  } #primequestTrustedPlatformModuleTable
#------------
  sub RFC1213_Inventory {
	my $part = shift;
	RFC1213sysinfo() if (defined $part and $part == 0);
	# other values: IF ?
	RFC1213_ipAddrTable() if (defined $part and $part == 1);
  }
  sub inventorySvAgent {
	my $invent = 0;
	my $sc = 0;
	my $lrc = 0;
	$lrc = svOsSystemStartTime() if ($optInventory);
	sc_powerOnTime() if ($optInventory and !$lrc);
	primergyServerSerialID() if ($optInventory);
	sc2ServerTable("UUID") if ($optInventory);
	status_sieStatus() if ($optInventory);
	addInv2ndKeyValue("Components", "@components") if ($#components >= 0);
	$lrc = svOsInfoTable();
	inv_sniInventory(0) if ($optInventory and !$lrc);
	$invent = 1 if (!$exitCode);
	sc2CheckAgentInfo() if ($optInventory);
	if ($exitCode == 0) {
		sc2UnitTable("I") if ($optInventory);
		sc2ManagementNodeTable_Parent() if ($optInventory);
	}
	sc2ServerTable("MEM")	if ($optInventory);
	sc2ServerTable("BIOS")	if ($optInventory);
	sc_sniScBiosVersionString() if ($optInventory);
	BIOS_sniBios()		if ($optInventory);
	sc2VirtualIoManagerTable() if ($optInventory);
	$lrc = svOsClusterInfoTable()	if ($optInventory);
	inv_sniInventory(1)	if ($optInventory  and !$lrc);

	sc2SystemBoardTable()	    if ($optInventory);
	sc2ManagementProcessorTable()	if ($optInventory);
	sc2TrustedPlatformModuleTable() if ($optInventory);
	inv_sniInvAgentTable()		if ($optInventory);

	$lrc = svOsProcessTable()	if ($optInvProcesses);
	inv_sniLoadedProcessTable()	if ($optInvProcesses and !$lrc);
	sc2ComponentStatusSensorTable() if ($optInvCss);
	sc2ManagementNodeTable()	if ($optInvNetwork);
	sc2PowerSupplyRedundancyConfigurationTable() if ($optInventory);
	vv_sieVvInfoTable()		if ($optInvFw);

	# SC.mib
	#... pciUtilizationTable 1.3.6.1.4.1.231.2.10.2.2.5.4.13
  } #inventorySvAgent
  sub inventoryPrimergyBlade {
	s31SysChassis("ID");
	s31AgentInfo();
	s31SysCtrlInfo_Strings();
	s31SysChassis("VIOM");

	s31BladesInside();

	s31SysCtrlInfo_Counter();
	s31MgmtBladeTable();
	s31_Network() if ($optInvNetwork);
  }
  sub inventoryPrimequest {
	primequestUnitTableChassis();
	primequestManagementProcessorTable(); # here are a kind of version info
	primequestManagementNodeTable() if ($optInventory);
	primequestServerTable()		if ($optInventory);
	primequestSystemBoardTable()	if ($optInventory);
	primequestTrustedPlatformModuleTable() if ($optInventory); #EMPTY TABLE FOR CASSIOPEIA 2013/06

	primequestUnitTable() if ($optInvUnit); # needs a lot of time !

	primequestFirmwareVersionTable() if ($optInvFw);

	primequestDeployLanInterfaceTable() if ($optInvNetwork);

	# PSA ? ... only interessting if SV-Agent is installed on servers inside
  }
sub inventory {
	my $rfc = 0;
	my $svagent = 0;
	my $s31 = 0;
	my $pq = 0;

	#$|++; # for unbuffered stdout print (due to Perl documentation)
	print "INVENTORY DATA FOR HOST = $optHost\n";
	{ # RFC1213 Uptime
		addInv1stLevel("Standard System Information");
		RFC1213sysinfoUpTime(1);
		$rfc = 1 if ($exitCode == 0);
	}
	return if (!$rfc);
	RFC1213_Inventory(0) if (!$exitCode);
        { #### search Agent type and Agent version information
		if ($rfc) { # Status.mib - SV Agent
			$exitCode = 0;
			status_sieStAgentInfo();
			if ($exitCode == 0) {
				$svagent = 1;
			}
		}
		if ($rfc and !$svagent) { # S31.mib - Agent ... there is no version info available
			s31CheckAgentInfo();
			if ($exitCode == 0) {
				$s31 = 1;
			}
		}
		if ($rfc and !$svagent and !$s31) { # MMB-COM-MIB.mib Agent Info
			mmbcomCheckAgentInfo();
			if ($exitCode == 0) {
				$pq = 1;
			}
		}
		if ($pq) {
			mmbcomAgentInfo();
			$exitCode = 0 if ($pq);
		}
		my $agtName	= $agentVersion{"Name"};
		my $agtCompany	= $agentVersion{"Company"};
		my $agtVersion	= $agentVersion{"Version"};
		$agtName	= "N/A" if (!$agtName);
		addInv1stLevel("Used Agent") if (!$isiRMC);
		addInv1stLevel("Used Firmware") if ($isiRMC);
		addInv2ndKeyValue("Type", "ServerView Agent") if ($svagent and !$isiRMC);
		addInv2ndKeyValue("Type", "iRMC Firmware") if ($svagent and $isiRMC);
		addInv2ndKeyValue("Type", "PRIMERGY Management Blade Agent") if ($s31);
		addInv2ndKeyValue("Type", "PRIMEQUEST Agent") if ($pq);
		#addInv2ndKeyValue("Name", $agtName); 
		addInv2ndKeyValue("Company", $agtCompany); 
		addInv2ndKeyValue("Version", $agtVersion); 
	} # agent version
	if ($isiRMC) {
		addInv1stLevel("Used Agent");
		svOsPropertyTable();
	}

	addInv1stLevel("Agent Information about the System") if ($optInventory);;
	inventorySvAgent() if ($svagent);
	inventoryPrimergyBlade() if ($s31);
	inventoryPrimequest() if ($pq);
	RFC1213_Inventory(1) if ($optInvNetwork and !$svagent); # IPv4 Addresses
	if (!$s31 and !$pq) {
		RAIDsvrStatus();
	}
	$exitCode = 0;
} #inventory
#------------ ZABBIX HELPER
  sub ZRFC1213sysName {
	# RFC1213.mib
	my $snmpOidSystem = '.1.3.6.1.2.1.1.'; #system
	my $snmpOidName		= $snmpOidSystem . '5.0'; #sysName.0
	my $name = trySNMPget($snmpOidName);
	return $name;
  } #ZRFC1213sysName
  sub Zs31SysCtrlOverallStatus {
	my $snmpOidBladeStatus = '.1.3.6.1.4.1.7244.1.1.1.3.1.5.0'; #s31SysCtrlOverallStatus.0
	my $bladestatus = trySNMPget($snmpOidBladeStatus,"BladeStatus");
	$bladestatus = 0 if (!defined $bladestatus or $bladestatus < 0);
	$bladestatus = 5 if ($bladestatus and $bladestatus > 4);
	my @statusString = ( 'UNAVAILABLE', 
		'UNKNOWN', 'OK', 'DEGRADED', 'CRITICAL', 'UNEXPECTED', );
	return $statusString[$bladestatus];
  } #Zs31SysCtrlOverallStatus
  sub Zs31SysChassisSerialNumber {
	my $snmpOidSysChassis = ".1.3.6.1.4.1.7244.1.1.1.3.5."; #s31SysChassis
	my $snmpOidBladeID	= $snmpOidSysChassis . '1.0'; #s31SysChassisSerialNumber.0
	
	my $serverID = trySNMPget($snmpOidBladeID);
	return $serverID;
  }  # Zs31SysChassisSerialNumber
  sub Zs31SysCtrlHousingType {
	my $snmpOidSysCtrlInfoGrp = ".1.3.6.1.4.1.7244.1.1.1.3.1."; #s31SysCtrlInfo
 	my $snmpOidHousing	= $snmpOidSysCtrlInfoGrp . '4.0'; #s31SysCtrlHousingType
	my $housing		= trySNMPget($snmpOidHousing);
	return $housing;
  }
  sub Zs31MgmtBladeFirmwareVersion {
	my $snmpOidMgmtBladeTable = '.1.3.6.1.4.1.7244.1.1.1.2.1.1.'; #s31MgmtBladeTable (1)
	my $snmpOidStatus	= $snmpOidMgmtBladeTable .  '2'; #s31MgmtBladeStatus
	my $snmpOidFWVersion	= $snmpOidMgmtBladeTable .  '9'; #s31MgmtBladeFirmwareVersion
	my @tableChecks = (
		$snmpOidStatus,  
		$snmpOidFWVersion,
	);
	my @statusText = ("none",
		"unknown", "ok", "not-present",	"error", "critical",
		"standby", "..unexpected..",
	);
	my $version = undef;
	{ # BLADE ManagementBlade
		#my $entries = $main::session->get_entries( -columns => \@tableChecks );
		my $entries = getSNMPtable(\@tableChecks);
		my @snmpIDs = ();

		foreach my $snmpKey ( keys %{$entries} ) {
			#print "$snmpKey --- $entries->{$snmpKey}\n";
			push(@snmpIDs, $1) if ($snmpKey =~ m/$snmpOidStatus.(\d+)/);
		}
		@snmpIDs = Net::SNMP::oid_lex_sort(@snmpIDs);
		
		foreach my $snmpID (@snmpIDs) {
			my $status = $entries->{$snmpOidStatus . '.' . $snmpID};
			my $fwversion	= $entries->{$snmpOidFWVersion . '.' . $snmpID};
			$status = 0 if (!defined $status or $status < 0);
			$status = 7 if ($status > 7);

			$version = $fwversion if ($status 
			    and ($status==2 or $status==4 or $status==5));
			return $version if ($version);
		} # each
	}
	return $version;
  } #Zs31MgmtBladeFirmwareVersion

  sub ZsieStSystemStatusValue {
	# Status.mib
	my $snmpOidPrefix = '1.3.6.1.4.1.231.2.10.2.11.'; #sieStatusAgent
	my $snmpOidSysStat		= $snmpOidPrefix . '2.1.0'; #sieStSystemStatusValue.0
	my $srvCommonSystemStatus = undef; 
	my @subSysStatusText = ( 'UNAVAILABLE', 
		'OK', 'DEGRADED', 'ERROR', 'FAILED', 'UNKNOWN', 'UNEXPECTED', );
	$srvCommonSystemStatus = trySNMPget($snmpOidSysStat,"SystemStatus");
	$srvCommonSystemStatus = 0 if (!$srvCommonSystemStatus or $srvCommonSystemStatus < 0);
	$srvCommonSystemStatus = 6 if ($srvCommonSystemStatus and $srvCommonSystemStatus > 5);
	return $subSysStatusText[$srvCommonSystemStatus];
  } #ZsieStSystemStatusValue
  sub Zsc2UnitSerialNumber {
	# Server identification (via serial number)
	my $snmpOidServerID = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.7.1'; #sc2UnitSerialNumber.1
	{	
		my $serverID = trySNMPget($snmpOidServerID,"ServerID");
		return $serverID;
	}
  } # Zsc2UnitSerialNumber
  sub Zsc2UnitManufacturer {
	# SC2.mib
	my $snmpOidPrefix = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable.1.
	my $snmpOidFirstUnitManufacturer = $snmpOidPrefix . '6.1'; #sc2UnitManufacturer
	my $vendor = 'UNAVAILABLE';
	$vendor = trySNMPget($snmpOidFirstUnitManufacturer,"UnitManufacturer");
	$vendor = 'UNAVAILABLE' if (!defined $vendor);
	return $vendor;
  } #Zsc2UnitManufacturer
  sub Zsc2UnitModelName {
	my $snmpOidUnitTable = '.1.3.6.1.4.1.231.2.10.2.2.10.2.3.1.'; #sc2UnitTable
	my $snmpOidModel	= $snmpOidUnitTable . '5.1'; #sc2UnitModelName.1
	my $model = undef;
	$model = trySNMPget($snmpOidModel);
	return $model;
  } #Zsc2UnitModelName
#------------ ZABBIX 
  sub zabbixBladeMMB {
	if ($optZabbix =~ m/overall/i) {
	    my $stateString = "UNKNOWN";
	    $stateString = Zs31SysCtrlOverallStatus();
	    return $stateString;
	}
	if ($optZabbix =~ m/serial/i) {
	    my $serial = "UNAVAILABLE";
	    $serial = Zs31SysChassisSerialNumber();
	    $serial = "UNAVAILABLE" if (!$serial);
	    return $serial;
	}
	if ($optZabbix =~ m/firmware/i) {
	    my $version = "UNAVAILABLE";
	    $version = Zs31MgmtBladeFirmwareVersion();
	    $version = "UNAVAILABLE" if (!$version);
	    return $version;
	}
	elsif ($optZabbix =~ m/model/i) {
	    my $model = "UNAVAILABLE";
	    $model = Zs31SysCtrlHousingType();
	    if ($model and $model =~ m/BX/) {
		$model = "PRIMERGY $model";
		$model =~ s/S/ S/;
	    } else {
		$model = "UNAVAILABLE";
	    }
	    return $model;
	}
  } #zabbixBladeMMB
  sub zabbixServer {
	if ($optZabbix =~ m/overall/i) {
	    my $stateString = "UNKNOWN";
	    $stateString = ZsieStSystemStatusValue(); # Status.mib
	    return $stateString;
	}
	elsif ($optZabbix =~ m/serial/i) {
	    my $serial = "UNAVAILABLE";
	    $serial = Zsc2UnitSerialNumber();
	    $serial = "UNAVAILABLE" if (!$serial);
	    return $serial;
	}
	elsif ($optZabbix =~ m/firmware/i) {
	    my $version = "UNAVAILABLE";
	    status_sieStAgentInfo();
	    $version = $agentVersion{"Version"} if ($agentVersion{"Version"});
	    return $version;
	} # firmware
	elsif ($optZabbix =~ m/vendor/i) {
	    my $vendor = Zsc2UnitManufacturer();
	    $vendor = "UNAVAILABLE" if (!defined $vendor);
	    return $vendor;
	} # vendor
	elsif ($optZabbix =~ m/model/i) {
	    my $model = "UNAVAILABLE";
	    $model = Zsc2UnitModelName();
	    return $model;
	} # model
	
  } #zabbixServer
  sub processZabbixData {
	my $s31 = 0;
	
	# test if S31.mib info is available - PRIMERGY BLADE MMB
	s31CheckAgentInfo();
	if ($exitCode == 0) {
		$s31 = 1;
	}
	$exitCode = 3;

	if ($optZabbix =~ m/overall/i	or $optZabbix =~ m/serial/i or $optZabbix =~ m/firmware/i
	or  $optZabbix =~ m/model/i	or $optZabbix =~ m/vendor/i) 
	{
	    my $response = "UNKNOWN";
	    $response = "UNAVAILABLE" 
		if ($optZabbix =~ m/serial/i or $optZabbix =~ m/firmware/i or $optZabbix =~ m/model/i
		or  $optZabbix =~ m/vendor/i);
	    $response = zabbixBladeMMB() if ($s31);
	    $response = zabbixServer() if (!$s31);
	    finalize(1,$response);
	} elsif ($optZabbix =~ m/name/i) {
	    my $response = ZRFC1213sysName();
	    finalize(1,$response);
	}
  } #processZabbixData
#------------ MAIN PART
# get command-line parameters
handleOptions();

# set timeout
local $SIG{ALRM} = sub {
	#### TEXT LANGUAGE AWARENESS
	print "$0" . 'UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($optTimeout);

openSNMPsession();

#$optInventory = 999 if (!defined $optInventory);

RFC1213sysinfoUpTime(0);
if ($exitCode == 0) {
	{
		processZabbixData() if ($optZabbix);
		inventory() if (!$optZabbix);
	}
} # SNMP acessible

closeSNMPsession();

# output to nagios
$notifyMessage =~ s/^\s*//gm; # remove leading blanks
$notifyMessage =~ s/\s*$//m; # remove last blanks
$notifyMessage = undef if ($main::verbose < 1 and ($exitCode==0));
$longMessage =~ s/^\s*//m; # remove leading blanks
$longMessage =~ s/\s*$//m; # remove last blanks
$variableVerboseMessage =~ s/^\s*//m; # remove leading blanks
$variableVerboseMessage =~ s/\s*$//m; # remove last blanks
$variableVerboseMessage = undef if ($variableVerboseMessage eq "\n");
my $stateString = $state[$exitCode];
$stateString = '' if ($optInventory and $exitCode == 0);
finalize(
	$exitCode, 
	$stateString, 
	($msg?$msg:''),
	(! $notifyMessage ? '': "\n" . $notifyMessage),
	(! $longMessage ? '' : "\n" . $longMessage),
	($performanceData ? "\n |" . $performanceData : ''),
);
#	($main::verbose >= 2 or $main::verboseTable) ? "\n" . $variableVerboseMessage: '',
################ EOSCRIPT


