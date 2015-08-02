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
# against an LDAP/Active Directory account.  It will handle multiple domains.
#
# Optionally, if $local_passwd_file is defined (details below), this script
# will authenticate users from a local password file versioned in Perforce.
# This can be used to allow a class of users that exist in Perforce but
# not in the LDAP/Active Directory domain.
#
# sample trigger usage:
#  ad auth-check auth "/p4/common/bin/triggers/AD_ssl_auth.pl %user%"
#

use strict;

use Net::LDAPS;

$|=1;

#------------------------------------------------------------------------------
#  Define Variables

# AD connect timeout
my $timeout = 10;

# Set AD server info. 
my $ad_port = "636";    # AD Port, should probably leave.
my $ad_host = "AD.IP";  # Put hostname or IP address of your AD server here.

# AD read Account.
# Full DN including user.
my $ad_read_dn   = 'CN=user,CN=Users,DC=test,DC=domain,DC=com';
my $ad_read_p    = 'Password';

my $ad;
my @entries;
my $local_passwd_file;
my $mesg;
my $password;
my $password_on_file;
my $p4_user;
my $ret;
my $root_dn;
my @users;
my $tc;

#------------------------------------------------------------------------------
# Get Passsword from User

open(STDERR, ">&STDOUT") or die "Can't dup stdout";

if (scalar(@ARGV != 1)) { die "\nUsage:\nAD_auth.pl \%username\%\n" }

$p4_user = shift;
chomp $p4_user;

$password = <STDIN>;
$password =~ s/\r\n//g;
chomp $password;

if ($password =~ /^$/) { die "Null passwords not allowed" }

#------------------------------------------------------------------------------
# Authenticate from a local password file.

# To enable local password file verification for selected accounts,
# create a password file in Perforce, and set $local_password_file to
# the Perforce depot path of that file.  The file should be tightly
# locked down in the protections table, and ideally placed in a secure
# depot.  Changelists that affect that file should be set as 'restricted'
# (for 2010.2+ servers).
# 
# The password file is expected to contain one-line entries containing
# simply a user and then the password, delimited by a space, e.g:
#
# Autobuild MyP@ssw0rd
#
# Lines starting with '#' or containing only whitepsace are ignored.
#
# If enabled, users listed in this file with authenticate from this file.
# Others will authenticagte from AD/LDAP.
#
### Comment next line to disable local password file authentication!
$local_passwd_file = "/p4/common/bin/triggers/localpasswd.txt";

# If $local_passwd_file is defined, first search for the user in that file.
# If the user is found, authenticate using that password.  Otherwise, simply
# fall through to AD/LDAP authentication.

if ($local_passwd_file)
{
   foreach (`cat $local_passwd_file 2>&1`)
   {
      if (/$p4_user /)
      {
         $password_on_file = $_;
	 $password_on_file =~ s/$p4_user //;
	 chomp $password_on_file;
	 exit 0 if ($password eq $password_on_file);

	 # If the password matched, the line above exited. Otherwise ...
         print "Local Password File Authentication Failed.  Access Denied.\n";
	 exit 1;

	 last;
      }
   }
}

#------------------------------------------------------------------------------
# Authenticate against Active Directory/LDAP.

$ad = Net::LDAPS->new($ad_host, port => $ad_port, timeout => $timeout ) ||
   die "Unable to connect with read account";

$mesg = $ad->bind ("$ad_read_dn", password => $ad_read_p, version => 3 ) ||
   die "Unable to bind\n";


$mesg = $ad->search( base   => '',
   filter => "(objectclass=*)",
   scope => 'base' );

$ret = 1;

$tc = Net::LDAPS->new($ad_host, port => $ad_port, timeout => $timeout ) ||
   die "Unable to connect with read account";

@entries = ($mesg->entries);
foreach my $entry (@entries)
{
   $root_dn = $entry->get_value('rootDomainNamingContext');

   $mesg = $ad->search   ( base   => $root_dn,
      filter => "(samaccountname=$p4_user)",
      scope => 'sub',
      attrs  => ['mail'] ) || next;

   @users = ($mesg->entries);
   next if (! defined $users[0]);

   $mesg = $tc->bind(dn => $users[0]->dn(), password => $password) || next;

   if (! $mesg->code) { $ret = 0; last }
}

if ($ret) { print "Authentication Failed.  Access Denied.\n" }
exit $ret;
