#! /usr/bin/perl -w
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#    For information : contact@merethis.com
####################################################################
#
# Script init
#

use strict;
use Net::SNMP qw(:snmp);
use FindBin;
use lib "$FindBin::Bin";
use lib "/usr/local/nagios/libexec";
use lib "/tmp" ;
#use utils qw($TIMEOUT %ERRORS &print_revision &support);
use Nagios::Plugin qw(%ERRORS);

use vars qw($PROGNAME);
use Getopt::Long;
use vars qw($opt_h $opt_V $opt_H $opt_C $opt_v $opt_o $opt_c $opt_w $opt_t $opt_p $opt_k $opt_u);

$PROGNAME = $0;
sub print_help ();
sub print_usage ();

Getopt::Long::Configure('bundling');
GetOptions
    ("h"   => \$opt_h, "help"         => \$opt_h,
     "u=s" => \$opt_u, "username=s"   => \$opt_u,
     "p=s" => \$opt_p, "password=s"   => \$opt_p,
     "k=s" => \$opt_k, "key=s"        => \$opt_k,
     "V"   => \$opt_V, "version"      => \$opt_V,
     "v=s" => \$opt_v, "snmp=s"       => \$opt_v,
     "C=s" => \$opt_C, "community=s"  => \$opt_C,
     "w=s" => \$opt_w, "warning=s"    => \$opt_w,
     "c=s" => \$opt_c, "critical=s"   => \$opt_c,
     "H=s" => \$opt_H, "hostname=s"   => \$opt_H);

if ($opt_V) {
    print_revision($PROGNAME,'$Revision: 1.0');
    exit $ERRORS{'OK'};
}

if ($opt_h) {
    print_help();
    exit $ERRORS{'OK'};
}

$opt_H = shift unless ($opt_H);
(print_usage() && exit $ERRORS{'OK'}) unless ($opt_H);

my $snmp = "1";
if ($opt_v && $opt_v =~ /^[0-9]$/) {
$snmp = $opt_v;
}

if ($snmp eq "3") {
if (!$opt_u) {
print "Option -u (--username) is required for snmpV3\n";
exit $ERRORS{'OK'};
}
if (!$opt_p && !$opt_k) {
print "Option -k (--key) or -p (--password) is required for snmpV3\n";
exit $ERRORS{'OK'};
}elsif ($opt_p && $opt_k) {
print "Only option -k (--key) or -p (--password) is needed for snmpV3\n";
exit $ERRORS{'OK'};
}
}

($opt_C) || ($opt_C = shift) || ($opt_C = "public");

my $DS_type = "GAUGE";
($opt_t) || ($opt_t = shift) || ($opt_t = "GAUGE");
$DS_type = $1 if ($opt_t =~ /(GAUGE)/ || $opt_t =~ /(COUNTER)/);


my $name = $0;
$name =~ s/\.pl.*//g;
my $day = 0;

#===  create a SNMP session ====

my ($session, $error);
if ($snmp eq "1" || $snmp eq "2") {
    ($session, $error) = Net::SNMP->session(-hostname => $opt_H, -community => $opt_C, -version => $snmp);
    if (!defined($session)) {
	print("UNKNOWN: SNMP Session : $error\n");
	exit $ERRORS{'UNKNOWN'};
    }
    }elsif ($opt_k) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp, -username => $opt_u, -authkey => $opt_k);
    if (!defined($session)) {
	print("UNKNOWN: SNMP Session : $error\n");
	exit $ERRORS{'UNKNOWN'};
    }
    }elsif ($opt_p) {
	($session, $error) = Net::SNMP->session(-hostname => $opt_H, -version => $snmp,  -username => $opt_u, -authpassword => $opt_p);
    if (!defined($session)) {
	print("UNKNOWN: SNMP Session : $error\n");
	exit $ERRORS{'UNKNOWN'};
    }
}

my $result ;
my $boxes_label = "inboxes";
my $boxes_unit  = "boxes";
my $users_label = "users";
my $users_unit  = "u";
my $return_result ;
my $return_code = 0 ;
my $perfparse = "" ;
my $outlabel = "Mirapoint mailboxes: ";
my @oids= (".1.3.6.1.4.1.3246.2.2.1.1.11.0",".1.3.6.1.4.1.3246.2.2.1.1.12.0") ;
# .1.3.6.1.4.1.3246.2.2.1.1.12.0 = inboxes
# .1.3.6.1.4.1.3246.2.2.1.1.11.0 = users

$result = $session->get_request(-varbindlist => \@oids) ;
my $total_inboxes = $result->{".1.3.6.1.4.1.3246.2.2.1.1.12.0"} ;
my $total_users   = $result->{".1.3.6.1.4.1.3246.2.2.1.1.11.0"} ;

$outlabel.="$total_inboxes boxes for a total of $total_users users " ;
$perfparse .= "'$boxes_label'=".$total_inboxes."$boxes_unit;" ;
$perfparse .= " '$users_label'=".$total_users."$users_unit;" ;
	
if (defined($opt_c) && defined($opt_w)) {
    if ($total_users > $opt_w) {
	if ($total_users > $opt_c) {
	    $return_code = 2 ;
	}else {
	    $return_code = 1 ;
	}
    }
    $perfparse.="$opt_w;$opt_c;" ;
}else {
    $perfparse.=";;" ;
}

$perfparse .="0;;" ;

if ($return_code == 0) {
    $outlabel.="OK" ;
}elsif($return_code == 1){
    $outlabel.="WARNING" ;
}elsif($return_code == 2){
    $outlabel.="CRITICAL" ;
}else {
    $outlabel.="UNKNOWN" ;
}
print $outlabel." | ".$perfparse."\n" ;
exit($return_code) ;


sub print_usage () {
    print "Usage:";
    print "$PROGNAME\n";
    print "   -H (--hostname)   Hostname to query - (required)\n";
    print "   -C (--community)  SNMP read community (defaults to public,\n";
    print "                     used with SNMP v1 and v2c\n";
    print "   -v (--snmp_version)  1 for SNMP v1 (default)\n";
    print "                        2 for SNMP v2c\n";
    print "   -t (--type)       Data Source Type (GAUGE or COUNTER) (GAUGE by default)\n";
    print "   -k (--key)        snmp V3 key\n";
    print "   -p (--password)   snmp V3 password\n";
    print "   -u (--username)   snmp v3 username \n";
    print "   -V (--version)    Plugin version\n";
    print "   -h (--help)       usage help\n";
    print "   -w warningThreshold (%)\n" ;
    print "   -c criticalThreshold (%)\n" ;
}

sub print_help () {
    print "##############################################\n";
    print "#                ADEO Services               #\n";
    print "##############################################\n";
    print_usage();
    print "\n";
}
