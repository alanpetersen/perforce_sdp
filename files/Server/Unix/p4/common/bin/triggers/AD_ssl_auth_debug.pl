#!/usr/bin/perl -w
#------------------------------------------------------------------------------
# Copyright (c) Perforce Software, Inc., 2007-2015. All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1  Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE
# SOFTWARE, INC. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#------------------------------------------------------------------------------

#
# Overview: This trigger script authenticates a Perforce userid against
# against an AD sAMAccount name.  It will handle multiple domains.
#
# This debug version of the script is meant to be used on the commandline. 
#  AD_auth_debug.pl <username>"

use strict;

use Net::LDAPS;

$|=1;

######################## Set Variables ####################################

# AD connect timeout
my $timeout = 10;

# Set AD server info. 
my $ad_port = "636";    # AD Port, should probably leave.
my $ad_host = "AD IP";  # Put IP of your AD server here

# AD read Account.
# Full DN including user.  You don't need to use an Administrator account
# any account should do I suggest you change the below line to a standard user.
my $ad_read_dn   = 'CN=user,CN=Users,DC=test,DC=domain,DC=com';
my $ad_read_p    = 'Password';

###########################################################################
open(STDERR, ">&STDOUT") or die "Can't dup stdout";

if (scalar(@ARGV != 1)) { die "\nUsage:\nAD_auth.pl \%username\%\n" }

my $p4_user = shift;
chomp $p4_user;

print "\nIn this DEBUG script, the password will be shown for visual verification.\n";

print "Please enter your password: ";
my $password = <STDIN>;
$password =~ s/\r\n//;
chomp $password;

if ($password =~ /^$/) { die "Null passwords not allowed" }

print "Proceeding with the following details:\n\n";
print "  User set to:        $p4_user\n";
print "  Password set to:    $password\n\n";
print "  Connecting to IP:   $ad_host\n";
print "  Connecting to Port: $ad_port\n\n";
print "  Using read DN:      $ad_read_dn\n";
print "  Using read DN p:    $ad_read_p\n\n"; 

#####  Authenticate! ######################################################
my $ad = Net::LDAPS->new($ad_host, port => $ad_port, timeout => $timeout ) ||
	die "Unable to connect with read account";

my $mesg = $ad->bind ("$ad_read_dn", password => $ad_read_p, version => 3 ) ||
	die "Unable to bind\n";


$mesg = $ad->search( base   => '',
                     filter => "(objectclass=*)",
                     scope => 'base' );
my $ret = 1;

my $tc = Net::LDAPS->new($ad_host, port => $ad_port, timeout => $timeout ) ||
  die "Unable to connect with read account";

my @entries = ($mesg->entries);
print "Doing base query.  Scanning for root domain naming context\n";
foreach my $entry (@entries) {
 my $root_dn = $entry->get_value('rootDomainNamingContext');
 print "  Got root db: $root_dn\n";
 $mesg = $ad->search   ( base   => $root_dn,
                         filter => "(samaccountname=$p4_user)",
                         scope => 'sub',
                         attrs  => ['mail'] ) || next;

	my @users = ($mesg->entries);
	print "Checking if user exists here\n";
	next if (! defined $users[0]);
	print "User is defined\n";
	print "Attempting to bind ".$users[0]->dn()."with password $password\n";
	$mesg = $tc->bind(dn => $users[0]->dn(), password => $password) || next;
	print "Got message back\n";
	if (! $mesg->code) { $ret = 0; last }
	print "Seem to have gotten an error code skipped last exit.\nError Code: ".$mesg->error."\n";
}

if ($ret) { print "Authentication Failed.  Access Denied\n" }
exit $ret;
