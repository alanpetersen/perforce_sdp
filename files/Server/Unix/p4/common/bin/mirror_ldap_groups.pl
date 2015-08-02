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

#==============================================================================
# Initialization and Declarations

require 5.005;
use strict;
use File::Basename;
use Getopt::Long;
use Net::LDAP;
use OS;
use Msg;
use Cmd;
use Misc;

BEGIN
{
    $main::ThisScript = basename($0);
    $main::ThisScript =~ s/\.exe$/\.pl/i;
    # Keep the VERSION value here the same as in the documentation at the bottom
    # of this script.  Search for the '=head1 NAME' tag.
    $main::VERSION = "2.4.0";
    @main::InitialCmdLine = @ARGV;
    $main::InitialDir = OS::IsUnix() ? $ENV{PWD} : `cd`;
    chomp $main::InitialDir;
}

# Prototypes for Local Functions.
sub usage (;$);
sub load_cfg_data($;);
sub is_standard_p4_user ($;);
sub bind_to_ldap ($$$$;);
sub process_ldap_group ($;);
sub disconnect_from_ldap ();
sub create_p4_user ($$$;);
sub restrict_group_membership ($$;);
sub generate_p4_group_spec ($$$;);

my $CfgFile = "mirror_ldap_groups.cfg";
my %Config;
my $Host;
my $Port;
my $Group;
my $GroupList; # Comma-separated list as provided on the command line.
my $UsageOK = 1;
my $UsersCreated = 0;
my $UsersUpdated = 0;
my $GroupsUnchanged = 0;
my $GroupsModified = 0; # Includes created and updated.
my $TotalUpdates = 0;
my $TotalErrors = 0;
my $EmptyLDAPGroupCount = 0;
my $GroupUpdateErrors = 0;
my $UserCreateErrors = 0;
my $UserUpdateErrors = 0;
my $Owner;
my @GroupOwners;
my $GroupOwnersCount = 0;
my $UpdateGroupOwners = 0;
my $ProcessLDAPSubgroups = 1;
my $EnforceStrictSubgroupMembership = 0;
my $SubgroupUsersRemovedCount = 0;
my @TopLevelGroupUsers;
my $TopLevelGroupUserCount = 0;
my $LDAP;
my $P4BIN;
my $P4TMP;
my $CaseHandling;
my $ExitStatus = 1;
$Msg = Msg::new();

#==============================================================================
# Internal Functions

#------------------------------------------------------------------------------
# Function: load_cfg_data()
#
# Load LDAP bind account information and other values from a text file, and
# store the name/value pairs in the global %Config hash.
# 
# Input: Config file, absolute or relative path.
#
# Output: Status messages only.
sub load_cfg_data ($;)
{
   $Msg->trace ("CALL load_cfg_data (@_)");
   my ($cfgFile) = @_;
   my $name;
   my $value;
   my $dataSanity=1;

   $Msg->info("Loading configuration data from [$cfgFile].");

   open (CFG, "<$cfgFile") or
      $Msg->logdie ("Couldn't open config file [$cfgFile]: $!");

   while (<CFG>) {
      next if (/^\s*\#/); # Ignore comments.
      next if (/^\s*$/); # Ignore blank lines.
      s/\s*\#.*$//g; # Trim inline comments.
      s/^\s*//; # Zap leading whitespace.
      s/\s+$//; # Zap trailing whitespace.
      chomp;
      $name = $_;
      $name =~ s/ .*$//;
      $value = $_;
      $value =~ s/^.*? //;
      $Config{$name} = $value;
   }

   close (CFG);

   if ($Verbosity >= $DEBUG) {
      print "\n\nConfiguration Data Loaded:\n";
      for (sort keys %Config) {
         printf ("%-32s[%s]\n", $_, $Config{$_});
      }
   }

   # Verify that require values are defined.
   for ("LDAP_BIND_USER", "LDAP_BIND_PASSWORD", "LDAP_READ_DN", "DEFAULT_EMAIL_DOMAIN") {
      if ( ! $Config{$_}) {
         $Msg->error ("Missing required configuration setting for $_.");
         $dataSanity = 0;
      }
   }

   $dataSanity || $Msg->logdie("Missing required values.  Aborting.");

   $Msg->debug("Configuration data loaded OK.");
}

#------------------------------------------------------------------------------
# Function: is_standard_p4_user ()
#
# Input: userid
#
# Return true if user is a 'standard' type Perforce user account known
# to exist (i.e. not an 'operator' or 'service' user).  Return false if the
# user does not exist.  Connection or other errors will also result in a
# negative indication.
sub is_standard_p4_user ($;)
{
   my ($p4User) = @_;

   Cmd::Run ("$P4BIN -s users $p4User", "", 1);

   return ($Cmd::Output =~ /^info: / ) ? 1 : 0;
}

#------------------------------------------------------------------------------
# Function: bind_to_ldap ()
#
# Connect to LDAP, and set the global variable $LDAP.
#
# Input: LDAP host, port, bind user, and bind password.
#
# Aborts if LDAP connection fails.
sub bind_to_ldap ($$$$;)
{
   $Msg->trace ("CALL bind_to_ldap (@_)");
   my ($host, $port, $bindUser, $bindPassword) = @_;
   my $error;

   # Connect to the LDAP server.
   $LDAP = Net::LDAP->new ($host, port => $port) or
      $Msg->logdie ("$@");

   $error = $LDAP->bind ($bindUser, password => $bindPassword) or
      $Msg->logdie ("$@\nBind Exit Code: " . $error->code);

   $Msg->debug ("Bind Status Return Code: " . $error->code);
   $Msg->info ("Successfully connected to LDAP server.");
}

#------------------------------------------------------------------------------
# Function: process_ldap_group ()
#
# Given an LDAP group, query its membership, and then further query additional
# details for each user (email, full name).  Determine whether the group
# lists any users that do not yet have Perforce accounts, and create them.
# Optionally, process LDAP subgroups.  Make a call to generate_p4_group_spec()
# to update the group spec.
#
# Input: Group name.
#
sub process_ldap_group ($;)
{
   $Msg->trace ("CALL process_ldap_group (@_)");
   my ($group) = @_;

   my $user;
   my $fullName;
   my $email;

   my $groupMember;
   my @groupInfo;
   my $groupSearch = undef;
   my $subGroup;
   my $subGroupSearch = undef;
   my @userList;
   my @subGroupList;
   my $subGroupCount = 0;
   my $userCount = 0;
   my @members;
   my @memberInfo;
   my $memberInfoSearch = undef;

   $Msg->info ("Mirroring LDAP Group [$group].");

   # Find the LDAP group object.
   $groupSearch = $LDAP->search (base => $Config{'LDAP_READ_DN'},
      filter => "(&(objectClass=group)(sAMAccountName=$group))",
      attrs => ['member']);

   if ($groupSearch->count() == 0) {
      $Msg->warn ("Group [$group] has no members.  Ignoring it.");
      $EmptyLDAPGroupCount++;
      return;
   }

   $Msg->debug ("Search Status Return Code: " .  $groupSearch->code);

   # Get the group members from LDAP, and then look up the Perforce
   # required metadata for each user.  In Perforce terms, we need
   # values for 'Name', 'FullName', and 'Email' fields on the user
   # spec.  In LDAP terms, those values are 'sAMAccountName',
   # 'displayName', and 'mail', respectiviely.
   @members = $groupSearch->entry(0)->get_value ('member');
   @memberInfo = ();
   foreach $groupMember (@members) {
      # Find group members that are users (i.e. not subgroups).
      $memberInfoSearch = $LDAP->search (base => "$groupMember",
         filter => "(&(objectClass=user))",
         attrs => ['sAMAccountName', 'displayName', 'mail']);

      if ($memberInfoSearch->count() > 0) {
         $user = lc($memberInfoSearch->entry(0)->get_value ('sAMAccountName'));

         if ($memberInfoSearch->entry(0)->get_value ('displayName')) {
            $fullName = $memberInfoSearch->entry(0)->get_value ('displayName');
         } else {
            # If the LDAP value for 'displayName' is unset, set 'fullName'
            # to $user.
            $fullName = $user;
         }

         if ($memberInfoSearch->entry(0)->get_value ('mail')) {
            $email = $memberInfoSearch->entry(0)->get_value ('mail');
         } else {
            # If the LDAP value for 'mail' is unset, set 'email'
            # using the default email domain, as a guess.
            $email = $memberInfoSearch->entry(0)->get_value ('mail');
            $email = "$user\@$Config{'DEFAULT_EMAIL_DOMAIN'}";
         }

         $userList [$userCount++] = $user;
         create_p4_user ($user, $fullName, $email);
      }

      # Find members of the given group that are themselves groups.
      $subGroupSearch = $LDAP->search (base => "$groupMember",
         filter => "(&(objectClass=group))",
         attrs => ['sAMAccountName']);

      if ($subGroupSearch->count () > 0) {
         $subGroup = $subGroupSearch->entry(0)->get_value ('sAMAccountName');
         $subGroupList [$subGroupCount++] = $subGroup;

         if ($ProcessLDAPSubgroups && ! $EnforceStrictSubgroupMembership) {
            process_ldap_group ($subGroup)
         } else {
            $Msg->warn("LDAP Subgroup [$subGroup] ignored.");
         }
      }
   }

   generate_p4_group_spec ($group, \@userList, \@subGroupList);
}

#------------------------------------------------------------------------------
# Function: disconnect_from_ldap ()
# 
# Self-explanatory.
#
sub disconnect_from_ldap ()
{
   $Msg->trace ("CALL disconnect_from_ldap (@_)");
   $LDAP->unbind();
   $Msg->info ("Disconnected from LDAP.");
}

#------------------------------------------------------------------------------
# Function: create_p4_user ()
#
# Create a 'standard' type Perforce user account if it doesn't already exist.
#
# Input: User info array containing account name, full name, and email.
#
# Output:
# Displays users created.
#
# Error Handling:
# On failure, dislplay error from Perforce indicating cause of failure
# (e.g out of licenses, connection error, etc.), and increments global
# variables $UserCreateErrors or $UserUpdateErrors.
sub create_p4_user ($$$;)
{
   $Msg->trace ("CALL create_p4_user(@_)");
   my ($p4User, $fullName, $email) = @_;
   my $currentUserData;
   my $currentFullName;
   my $currentEmail;
   my $newUserSpec;
   my $tmpFile;

   $newUserSpec = "User:\t$p4User\n\nEmail:\t$email\n\nFullName:\t$fullName\n\n";
   $tmpFile = "$P4TMP/tmp.p4_user.$p4User.spec";

   # If the user account already exists, just check to see if the full name
   # or email address fields should be updated.
   if (is_standard_p4_user ($p4User)) {
      $currentUserData = `$P4BIN -ztag user -o $p4User`;
      $currentFullName = $currentUserData;
      $currentFullName =~ s/^.*\.\.\. FullName //s;
      $currentFullName =~ s/\n.*$//s;
      $currentFullName =~ s/\s+$//s;
      $currentEmail = $currentUserData;
      $currentEmail =~ s/^.*\.\.\. Email //s;
      $currentEmail =~ s/\n.*$//s;
      $currentEmail =~ s/\s+$//s;

      if (($email =~ /$currentEmail/) && ($fullName =~ /$currentFullName/)) {
         return;
      } else {
         open(TMP, ">$tmpFile") or
            $Msg->logdie ("Failed to create temp file [$tmpFile]: $!\nAborting.");
         $Msg->trace ("UPDATED USER SPEC: [$newUserSpec]");
         print TMP $newUserSpec;
         close (TMP);

         Cmd::Run ("$P4BIN -s user -i -f < $tmpFile");
         # Spoof success in NoOp mode.
         $Cmd::Output = "info: User $p4User updated. (FAKE  OUTPUT)" if $NoOp;

         if ($Cmd::Output =~ /info: User .* saved/) {
            $Msg->info ("Updated Perforce user account for [$p4User].\n");
            unlink $tmpFile;
            $UsersUpdated++;
         } else {
            $Msg->error ("\nFailed to update Perforce user [$p4User]:\n$Cmd::Output\n\nSpec file is: $tmpFile\n");
            $UserUpdateErrors++;
         }
      }
   } else {
      open(TMP, ">$tmpFile") or
         $Msg->logdie ("Failed to create temp file [$tmpFile]: $!\nAborting.");
      $Msg->trace ("NEW USER SPEC: [$newUserSpec]");
      print TMP $newUserSpec;
      close (TMP);

      Cmd::Run ("$P4BIN -s user -i -f < $tmpFile");
      # Spoof success in NoOp mode.
      $Cmd::Output = "info: User $p4User saved. (FAKE OUTPUT)" if $NoOp;

      if ($Cmd::Output =~ /info: User .* saved/) {
         $Msg->info ("Created Perforce user for [$p4User].\n");
         unlink $tmpFile;
         $UsersCreated++;
      } else {
         $Msg->error ("\nFailed to create Perforce user [$p4User]:\n$Cmd::Output\n\nSpec file is: $tmpFile\n");
         $UserCreateErrors++;
      }
   }
}

#------------------------------------------------------------------------------
# Function: restrict_group_membership ()
#
# Restricts the membership of a group to a provided list of users.  Any users
# not in the provided list are removed from the group.  This can be used, for
# example, to enforce a requirement that users in a subgroup are also listed
# in the parent group.
#
# Input: group name, reference to array of valid users.
sub restrict_group_membership ($$;)
{
   $Msg->trace ("CALL restrict_group_membership (@_)");
   my ($group, $userListRef) = @_;
   my $userBlock;
   my $groupSpec;
   my $tmpFile;
   my $found;
   my $usersFoundCount = 0;
   my $usersNotFoundCount = 0;
   my $gu; # Group's users.
   my $vu; # Valid users from the provided list.

   $tmpFile = "$P4TMP/tmp.p4_group.$group.spec";

   $groupSpec = `$P4BIN group -o $group`;
   $groupSpec =~ s/^#.*?\n//mg; # Trim comments.

   $userBlock = "\nUsers:\n";

   foreach $gu (grep (/\.\.\. Users\d+ /,
      `$P4BIN -ztag group -o $group`)) {
      $gu =~ s/^\.\.\. Users\d+ //;
      chomp $gu;
      $found = 0;
      foreach $vu (@$userListRef) {
         $Msg->trace ("Comparing [$gu] to [$vu], case $CaseHandling comparison.");
         if ($CaseHandling eq "insensitive") {
            $found = 1 if ($gu =~ /^$vu$/i);
         } else {
            $found = 1 if ($gu eq $vu);
         }
         last if ($found);
      }

      if ($found) {
         $userBlock = "$userBlock\t$gu\n";
         $usersFoundCount++;
      } else {
         $Msg->warn ("Enforcing Group Membership Restriction due to -b2: Removing user [$gu] from group [$group].");
         $usersNotFoundCount++;
      }
   }

   if ($usersNotFoundCount) {
      $SubgroupUsersRemovedCount += $usersNotFoundCount;
      # Splice in the trimmed 'Users:' block into the
      # group spec returned from the server.
      $groupSpec =~ s/\nUsers:.*?\n\n/$userBlock/s;

      open(TMP, ">$tmpFile") or
         $Msg->logdie ("Failed to create temp file [$tmpFile]: $!");
      $Msg->trace ("GROUP SPEC: [$groupSpec]");
      print TMP $groupSpec;
      close (TMP);

      Cmd::Run ("$P4BIN -s group -i < $tmpFile");
      # Spoof success in NoOp mode.
      $Cmd::Output = "info: Group $group transmogrified. (FAKE  OUTPUT)" if $NoOp;

      # The  output may indicate 'created', 'upated' or even 'not updated'.
      # Since we expect updates as users were trimmed, require an affirmative indication
      # of a successful update, or else count it as an error.
      if ($Cmd::Output =~ /info: Group .* not updated/) {
         $Msg->error ("\nFailed to trim Perforce group [$group]:\n$Cmd::Output\n\nSpec file is: $tmpFile");
         $GroupUpdateErrors++;
      } elsif ($Cmd::Output =~ /info: Group .* (created|updated|saved|transmogrified)/) {
         unlink $tmpFile;
         $Msg->info ("Created/Updated Perforce group [$group].\n");
         $GroupsModified++;
      } else {
         $Msg->error ("\nFailed to create/update Perforce group [$group]:\n$Cmd::Output\n\nSpec file is: $tmpFile");
         $GroupUpdateErrors++;
      }
   } else {
      $Msg->debug ("Perforce group [$group] did not require trimming.");
      $GroupsUnchanged++;
   }
}

#------------------------------------------------------------------------------
# Function: generate_p4_group_spec ()
#
# Generate an updated Perforce group spec.  Start by extracting the current
# group spec from the server (which may or may not already exist).  Then
# splice in the new 'Users' and 'Subgroups' (and optionally 'Owners') fields.
#
# This splicing approach makes the script less likely to require modification
# to work with different versions of P4D that may add or remove fields of the
# Group spec.  It also ensures modifications to the group spec made outside
# this script are not overwritten as the group spec is updated.
#
# Input: group, array of users, array of subgroups.
sub generate_p4_group_spec ($$$;)
{
   $Msg->trace ("CALL generate_p4_group_spec (@_)");
   my ($p4Group, $p4UserListRef, $p4SubGroupListRef) = @_;
   my $userBlock;
   my $subGroupBlock;
   my $ownersBlock;
   my $groupSpec;
   my $tmpFile;

   $tmpFile = "$P4TMP/tmp.p4_group.$p4Group.spec";

   $groupSpec = `$P4BIN group -o $p4Group`;
   $groupSpec =~ s/^#.*?\n//mg; # Trim comments.

   $userBlock = "\nUsers:\n";
   foreach my $u (@$p4UserListRef) {
      $userBlock = "$userBlock\t$u\n";
   }
   $userBlock = "$userBlock\n";

   # Splice in the new 'Users:' block into the
   # group spec returned from the server.
   $groupSpec =~ s/\nUsers:.*?\n\n/$userBlock/s;

   if ($ProcessLDAPSubgroups) {
      $subGroupBlock = "\nSubgroups:\n";
      foreach my $g (@$p4SubGroupListRef) {
         $subGroupBlock = "$subGroupBlock\t$g\n";
      }
      $subGroupBlock = "$subGroupBlock\n";

      # Splice in the new 'Subgroups:' block into the
      # group spec returned from the server.
      $groupSpec =~ s/\nSubgroups:.*?\n\n/$subGroupBlock/s;
   }

   if ($UpdateGroupOwners) {
      $ownersBlock = "\nOwners:\n";
      foreach my $o (@GroupOwners) {
         $ownersBlock = "$ownersBlock\t$o\n";
      }
      $ownersBlock = "$ownersBlock\n";

      # Splice in the new 'Subgroups:' block into the
      # group spec returned from the server.
      $groupSpec =~ s/\nOwners:.*?\n\n/$ownersBlock/s;
   }

   # In the mode where we enforce strict subgroup membership,
   # we ignore LDAP groups, and instead review members of
   # the Perforce Subgroups.  Remove any that aren't in the
   # parent group.
   if ($EnforceStrictSubgroupMembership) {
      foreach my $g (grep (/\.\.\. Subgroups\d+ /,
         `$P4BIN -ztag group -o $p4Group`)) {
         $g =~ s/^\.\.\. Subgroups\d+ //;
         chomp $g;
         restrict_group_membership ($g, $p4UserListRef);
      }
   }

   open(TMP, ">$tmpFile") or
      $Msg->logdie ("Failed to create temp file [$tmpFile]: $!");
   $Msg->trace ("GROUP SPEC: [$groupSpec]");
   print TMP $groupSpec;
   close (TMP);

   Cmd::Run ("$P4BIN -s group -i < $tmpFile");
   # Spoof success in NoOp mode.
   $Cmd::Output = "info: Group $p4Group transmogrified. (FAKE  OUTPUT)" if $NoOp;

   # The  output may indicate 'created', 'upated' or even 'not updated'.
   # All are indications of success for this purpose.
   if ($Cmd::Output =~ /info: Group .* not updated/) {
      unlink $tmpFile;
      $GroupsUnchanged++;
      $Msg->info ("Perforce group [$p4Group] unchanged.\n");
   } elsif ($Cmd::Output =~ /info: Group .* (created|updated|saved|transmogrified)/) {
      unlink $tmpFile;
      $Msg->info ("Created/Updated Perforce group [$p4Group].\n");
      $GroupsModified++;
   } else {
      $Msg->error ("\nFailed to create/update Perforce group [$p4Group]:\n$Cmd::Output\n\nSpec file is: $tmpFile");
      $GroupUpdateErrors++;
   }
}

#------------------------------------------------------------------------------
# Function: usage ()
# Description:
#   Display usage message and exit.
#
# Input:
# $1 - Usage Style, either man for man page or null, indicating only a usage
# syntax message is desired.
#
# Output: Message
#
# Return Values: Program Exits with status 1.
#
# Side Effects: Program terminates.
#------------------------------------------------------------------------------
sub usage (;$)
{
    my $style  = shift || "h";
    my $scriptDocFile = $main::ThisScript;
    my $perlDocOutput;

    # Be sure to keep the short "syntax only" version of the usage message
    # in sync with the info in POD style at the top of the script.
    if ($style eq "man")
    {
        $scriptDocFile =~ s/\.(pl|exe)$/\.html/i;
        $scriptDocFile = "$scriptDocFile.html" unless ($scriptDocFile =~ /\.html$/);

        if ( -r $main::ThisScript)
        {
            $perlDocOutput = `perldoc $main::ThisScript 2>&1`;
            print "\n$main::ThisScript v$main::VERSION\n";
            print $perlDocOutput;
        } else {
           usage("h");
        }
        exit 1;
    } else
    {
        print "\n$main::ThisScript v$main::VERSION\n
Usage:
   $main::ThisScript [-c <cfg_file>] [-g <group>[,<group2>,...]] [-o <user>[,<user2>,...]] [-i|-b2] [-s <ldap_host>] [-p <ldap_port>] [-d|-D] [-n]
 OR
   $main::ThisScript [-h|-man]
";
    }

    exit 1;
}

#==============================================================================
# Command Line Parsing
#==============================================================================
# Note:  -h and -man are reserved commands with special meanings for all
# scripts.  The -h gives a short usages message [just showing options]
# while the -man options shows the man page.
Getopt::Long::config "no_ignore_case";
Getopt::Long::config "auto_abbrev";

GetOptions(\%main::CmdLine, "help", "man", "debug", "DEBUG", "noop",
   "cfg=s", "server=s", "port=s", "groups=s", "owners=s", "ignore", "b2")
    or die "\nUsage Error:  Unrecognized argument.\n";

# Validate command line arguments.
usage("man") if $main::CmdLine{'man'};
usage() if $main::CmdLine{'help'};
$Verbosity = $DEBUG if $main::CmdLine{'debug'};
$Verbosity = $TRACE if $main::CmdLine{'DEBUG'};
$Msg->SetLevel ($Verbosity);
$NoOp = 1 if $main::CmdLine{'noop'};

$CfgFile = $main::CmdLine{'cfg'} if $main::CmdLine{'cfg'};

# Load the configuration file before we complete command
# line parsing, as some command line validity checks depend
# on whether the config file has defaults for some values.
load_cfg_data ($CfgFile);

if (($main::CmdLine{'ignore'}) and ($main::CmdLine{'b2'})) {
   $Msg->error ("The '-i' and '-b2' flags are mutually exclusive.");
   $UsageOK = 0;
}

$ProcessLDAPSubgroups = 0 if $main::CmdLine{'ignore'};

if ($main::CmdLine{'b2'}) {
   $EnforceStrictSubgroupMembership = 1;
   $ProcessLDAPSubgroups = 0;
}

if ($main::CmdLine{'owners'}) {
   $UpdateGroupOwners = 1;
   foreach $Owner (split ',', $main::CmdLine{'owners'}) {
      $GroupOwners [$GroupOwnersCount++] = $Owner;
   }
}

if ($main::CmdLine{'server'}) {
   $Host = $main::CmdLine{'server'};
} elsif ($Config{'LDAP_HOST'}) {
   $Host = $Config{'LDAP_HOST'};
} else {
   $Msg->error ("No LDAP host defined. Specify '-s <ldap_server>' on the command line, or set LDAP_HOST in the config file.");
   $UsageOK = 0;
}

if ($main::CmdLine{'port'}) {
   $Port = $main::CmdLine{'port'};
} elsif ($Config{'LDAP_PORT'}) {
   $Port = $Config{'LDAP_PORT'};
} else {
   $Msg->error ("No LDAP port defined. Specify '-p <ldap_port>' on the command line, or set LDAP_PORT in the config file.");
   $UsageOK = 0;
}

if ($main::CmdLine{'groups'}) {
   $GroupList = $main::CmdLine{'groups'};
} elsif ($Config{'LDAP_GROUPS'}) {
   $GroupList = $Config{'LDAP_GROUPS'};
} else {
   $Msg->error ("No group or group list defined. Specify '-g <group>[,<group2>,...]' on the command line, or set LDAP_GROUPS in the config file.");
   $UsageOK = 0;
}

if ( ! $UsageOK)
{
   $Msg->logdie ("Invalid usage, per errors reported above.  Aborting.");
}

# If there are unhandled fragments on the command line, give a usage error.
$Msg->logdie ("\nUnrecognized command line fragments:  @ARGV.")
    unless $#ARGV == -1;

#==============================================================================
# Main Program
#==============================================================================

$Msg->info ("Initial Directory:\n\t$main::InitialDir
Running $main::ThisScript v$main::VERSION
Command Line:\n\t$main::ThisScript @main::InitialCmdLine\n" .
Misc::FormattedTimestamp('L') . "\n");

$Msg->debug ("Host:\t$Host\nPort:\t$Port\nGroup(s):\t$GroupList");

if ($ENV{'P4BIN'}) {
   $P4BIN = $ENV{'P4BIN'};
} else {
   $Msg->warn ("Missing environment setting for P4BIN with path to the 'p4' executable.  Using just 'p4' and trusting PATH.");
   $P4BIN = "p4"
}

if ($ENV{'P4TMP'}) {
   $P4TMP = $ENV{'P4TMP'};
} else {
   $Msg->warn ("Missing environment setting for P4TMP.  Using /tmp.");
   $P4TMP = "/tmp"
}

Cmd::Run ("$P4BIN -s info -s", "", 1);

if ($Cmd::Output =~ /info: Case Handling:/) {
   $CaseHandling = $Cmd::Output;
   $CaseHandling =~ s/^.* Case Handling: //s;
   $CaseHandling =~ s/\n.*$//s;
   $Msg->debug ("Case Handling mode is [$CaseHandling].");
} else {
   $Msg->logdie ("Can't connect to Perforce server:\n$Cmd::Output\n");
}

bind_to_ldap ($Host, $Port, $Config{'LDAP_BIND_USER'},
   $Config{'LDAP_BIND_PASSWORD'});

foreach $Group (split ',', $GroupList) {
   process_ldap_group ($Group);
}

disconnect_from_ldap();

$TotalErrors = $GroupUpdateErrors + $UserCreateErrors +
   $UserUpdateErrors;
$TotalUpdates = $UsersCreated + $UsersUpdated + $GroupsModified;

if ($TotalErrors) {
   $Msg->warn (Misc::FormattedTimestamp ('L') .
":\nProcessing complete, but errors were detected.

Processing Summary:
Empty LDAP Groups:   $EmptyLDAPGroupCount (empty LDAP groups ignored).
User Creation:       $UserCreateErrors errors, $UsersCreated created OK.
User Updates:        $UserUpdateErrors errors, $UsersUpdated modifed OK.
Group Modification:  $GroupUpdateErrors errors, $GroupsModified modified OK, $GroupsUnchanged unchanged.");

   if ($EnforceStrictSubgroupMembership) {
      if ($Verbosity >= $INFO) {
         print "Users Removed from
         Subgroups: $SubgroupUsersRemovedCount.\n";
      }
   }

   if ($Verbosity >= $INFO) {
      print "Total Updates:       $TotalErrors errors, $TotalUpdates successful updates\n\n";
   }

   $ExitStatus = 1;
} else {
   $Msg->info (Misc::FormattedTimestamp('L') .
":\nAll processing completed.  No errors detected.

Processing Summary:
Users Created:   $UsersCreated.
Users Updated:   $UsersUpdated.
Groups Modifed:  $GroupsModified (updated or created), $GroupsUnchanged unchanged.");

   if ($EnforceStrictSubgroupMembership) {
      if ($Verbosity >= $INFO) {
         print "
Users Removed
 from Subgroups: $SubgroupUsersRemovedCount.\n";
      }
   }

   if ($Verbosity >= $INFO) {
      print "Total Updates:   $TotalUpdates\n";
   }

   $ExitStatus = 0;
}

$Msg -> debug ("Exit Status: $ExitStatus");
exit $ExitStatus;

__END__

=head1 NAME

mirror_ldap_groups.pl v2.4.0 - Mirror specified LDAP groups in Perforce.

=head1 SYNOPSIS

mirror_ldap_groups.pl [-c I<cfg_file>] [-g I<group>[,I<group2>,...]] [-o I<user>[,I<user2>,...]] [-i|-b2] [-s I<ldap_server>] [-p I<ldap_port>] [-d|-D] [-n]

OR

mirror_ldap_groups.pl {-h|-man}

=head1 DESCRIPTION

=head2 Overview

This script is as a one-way integration from LDAP to Perforce.  It mirrors group membership of a specified list of groups from an LDAP server, such as Active Directory (AD), into Perforce.

For each group processed, a corresponding Perforce group of the same name is created, and updated to contain the same users.  If the users in AD do not yet exist in Perforce, Perforce accounts are created using the information available from AD (so long as there are available licenses).  Changes to the FullName and Email address fields are detected in LDAP and propagated to Perforce.

If the LDAP group includes other groups, they are mirrored as Perforce subgroups by default.  If the LDAP group is empty, a warning message is displayed, and processing continues.  Empty LDAP groups are not treated as errors, and do not cause a non-zero return status.

The 'Users' and 'Subgroups' fields of the Perforce group spec are updated based on information from AD.  Other fields, such as 'Owners', timeouts and Max* settings, are unaffected.

=head2 Usage Notes

The list of AD groups to process can be specified in the config file or the command line.

Upon completion, a summary of errors and updates is displayed.

This script is intended to be called routinely (e.g every 10 minutes by a cron job or other scheduler).

=head1 ARGUMENTS

=head2 -c[fg] I<cfg_file>

Specify the config file to use.  The default is mirror_ldap_groups.cfg in the current directory.

=head2 -g[roups] I<group>[,I<group2>,...]

Specify a comma-delimited list of LDAP groups to mirror in Perforce.  Subordinate groups are implied and need not be listed explicitly.

=head2 -o[wners] I<user>[,I<user2>,...]

Specify a comma-delimited list of users to replace the 'Owners' field of the specified group(s).

=head2 -i[gnore]

If the -i flag is specified, any groups defined in LDAP that are members of the specified groups are ignored, rather than mirrored as Subgroups in Perforce.  The 'Subgroups' field the group spec is unaffected with '-i'.

The '-i' flag is incompatible with '-b2'.

=head2 -b2

Specify '-b2' to enable a custom behavior for handling Subgroups in Perforce.  When '-b2' is specified, any groups defined defined in LDAP that are members of the specified groups are ignored (similar to '-i').  Instead, the membership of any existing Subgroups defined in the group spec in Perforce is queried, and compared against the membership if the parent group.  Perforce Subgroups may contain only a subset of the users defined in the specified group (the parent group) when '-b2' is specified.  Any users detected in subgroups of the specified group are removed from the group.  Other than removal from the group, those accounts are not otherwise affected.

The '-b2' flag is incompatible with '-i'.

=head2 -s[erver] I<ldap_server>

Specify the LDAP server (DNS name or IP address).  A default value can be configured by adding an LDAP_HOST value in the configuration file.

=head2 -p[ort] I<ldap_port>

Specify the LDAP server port.  A default value can be configured by adding an LDAP_PORT value in the configuration file.

=head2 -d[ebug]

Enable verbose debug mode.

=head2 -D[EBUG]

Same as '-d', but even more pedantic (verbose, noisy).

=head2 -n[oop]

Specify No Op mode, indicating that the script should display what it would do with given arguments and environment, but take no action that affects data.  Users that would be added to Perforce are displayed, but those users are not actually added.

=head2 -h[elp]|-man

Display a usage message.  The -h display a short synopsis only, while -man displays this manual page.

=head1 EXAMPLES

The C<p4master_run> wrapper script is called first, providing the Perforce instance number.  This ensures the necessary Perforce environment settings are loaded from C</p4/common/bin/p4_vars>.

These examples use the long options, e.g. '-groups' rather than '-g'; both styles are equivalent.

=head2 Example 1 - Automation Example

A typical usage example, as might be coded in the wrapper script:

C<p4master_run 1 mirror_ldap_groups.pl -groups p4.users -server ad.mycompany.com -port 389>

=head2 Example 2 - Illustrating More Options

Example running against Perforce server instance 2, processing multiple groups and a non-default config file containing LDAP server and bind account info:

C<p4master_run 2 mirror_ldap_groups.pl -groups p4.dev,p4.qa,p4.automation -cfg mirror_ldap_groups.mycompany.cfg>

=head2 Example 3 - No-Op

A No-Op Usage Example, with maximum verbosity:

C<p4master_run 1 mirror_ldap_groups.pl -groups p4.users -server ad.mycompany.com -port 389 -noop -DEBUG>

=head2 Example 4 - Usage

Get usage info on the comand line:

C<mirror_ldap_groups.pl -h>

or:

C<mirror_ldap_groups.pl -man>

=head1 CONFIGURATION FILE

The config file must define the following values:

=head2 File Format

The config file contains variables names and their, separated by the first space on the line.  Any subsequent spaces are interpreted as part of the value.  Comment lines start with '#'.  Blank lines are ignored, as are leading and trailing whitespace.

=head2 Required Entries

At a minimum, the config file must define these entries:

=over 4

=item *

LDAP_BIND_USER

Define a static 'bind' account that has enough access within LDAP query basic user data and read group data.

=item *

LDAP_BIND_PASSWORD

Define the password for the  LDAP_BIND_USER.

=item *

LDAP_READ_DN

Define the DN string for the bind user.  Your resident LDAP guru can help provide this.

=item *

DEFAULT_EMAIL_DOMAIN

Define a default email domain, just in case the LDAP query for a user's email comes up blank.  This is used to guess the user's email domain as I<userid@default_email_domain>.

=back

=head2 Optional Entries

If these optional values are defined, they don't need to be provided on the command line.  If the corresponding command line flag is provided, the value in the config file is ignored.

=over 4

=item *

LDAP_HOST

Specify the LDAP or Active Directory server (DNS name or IP address).  If LDAP_HOST is defined in the config file, the '-s' flag is not required on the command line.

=item *

LDAP_PORT

Specify the port to connect to LDAP on.  This corresponds to the '-p' flag on the command line.  If the LDAP_PORT value is defined in the config file, the '-s' flag is not required on the command line.

=item *

LDAP_GROUPS

The LDAP_GROUPS value may list a single group or a comma-delimted list of groups.  If the LDAP_GROUPS value is defined in the config file, the '-g' flag is not required on the command line.

=back

=head1 USER REMOVAL

Users removed from LDAP are not automatically removed from Perforce.

=head2 User Removal Procedure

The following manual procedure illustrates how user accounts that do not exist in any Perforce group can be detected and optionally removed.

Users that do not exist in any group in Perforce can be detected with this command:

=over 4

C<checkusers_not_in_group.py> > C<users_not_in_any_group.txt>

C<cat users_not_in_any_group.txt>

=back

The users listed in the C<users_not_in_any_group.txt> file can be considered candidates for removal.

The recommended procedure for removing a user is to use the P4Admin user interface to manually remove user accounts, following whatever policy and procedures are identified for removing users in your organization.  Using P4Admin makes it easy to evaluate the impact of removing an account, indicating (for example) which workspaces will be removed.  Workspace remove can be problematic if the user to be removed created (and thus is listed as the owner of) workspaces actively used by other users or official builds.

The script C<p4deleteuser.py> is a forceful and potentially dangerous user removal script, as it will remove all workspaces for which the user is indicated as the owner, and cancel any checked out files.  If  you decide that script is appropriate, you can hand-edit and trim the list of users in C<users_not_in_any_group.txt> to create a new file, C<users_to_remove.txt>.  Then remove those user accounts with this command:

=over 4

C<p4deleteuser.py users_to_remove.txt>

=back

The C<checkusers_not_in_group.py> and C<p4deleteuser.py> scripts can be found in the Maintenance folder of the Server Delpoyment Package (SDP).

=head1 RELATED SOFTWARE

This depends on several Perl Modules.  Key modules are:

=over 4

=item *

B<OS.pm> - Abstraction layer for platform (e.g. Mac/Linux/Windows) variations.

=item *

B<Cmd.pm> - Shell command line wrapper.

=item *

B<Misc.pm> - Misc Perl utils.

=item *

B<Msg.pm> - Message interface to encourage consistent look and feel, and simplify logging.

=back

=head1 RETURN STATUS

Zero indicates normal completion, Non-Zero indicates an error.  In event of a non-zero exit code, all output (stdout and stderr) should be scanned to determine the cause.  Generaly a clearn indication will be given upon failure.

=cut
