package MinP4;

#------------------------------------------------------------------------------
# Copyright (c) Perforce Software, Inc., 2007-2014. All rights reserved
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

=head1 NAME

MinP4.pm - Minimal Perforce interface.

=head1 VERSION

1.3.0

=head1 DESCRIPTION

Minimal Perforce interface, not to be confused with the more comprehensive P4Perl API (the P4.pm module).

=head1 PUBLIC DATA

None.

=head1 PUBLIC FUNCTIONS

=cut

require Exporter;

use strict;
use File::Temp;
use POSIX qw(uname);
use Misc;
use Msg;
use Cmd;

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "1.3.0";
}

# Package interface standards.  By default, any export can be blocked.
@ISA = qw(Exporter);
@EXPORT_OK = qw(
   FindJIRAIssues
   GenChangelist
   GenGlobalWorkspace
   GenStreamWorkspace
   GenWorkspace
   GetBranchPaths
   GetChangelistFiles
);

# Prototypes for public functions.
sub FindJIRAIssues ($$;);
sub GenChangelist($$$$;);
sub GenGlobalWorkspace($$$;);
sub GenStreamWorkspace($$$$;);
sub GenWorkspace($$$$;);
sub GetBranchPaths($$$;$);
sub GetChangelistFiles($$;);

#==============================================================================
# Internal Functions
#==============================================================================

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------

# Find JIRA issues in the changelist description.

=head2 FindJIRAIssues()

FindJIRAIssues($I<change_desc>, $I<issueArrayRef>)

=head3 Description-FindJIRAIssues

Find JIRA issue keys in a Perforce changelist description.

=head3 Parameters-FindJIRAIssues

=over 4

=item *

$I<changelist>

=item *

$I<issueArrayRef>

A reference to an array containing a list of issues.

=back

=head3 Output-FindJIRAIssues

None.

=head3 Returns-FindJIRAIssues

None.

=head3 Examples-FindJIRAIssues

Sample call:

C<MinP4::FindJIRAIssues ($change_desc, \@issuesList);>

=cut

#------------------------------------------------------------------------------

sub FindJIRAIssues ($$;)
{
   $Msg->trace ("CALL MinP4::FindJIRAIssues(@_)");
   my ($changeDesc, $issueArrayRef) = @_;
   my $issue;
   my $issueCount = 0;

   foreach (split '\n', $changeDesc) {
      foreach (split ' ', $_) {
         next if (/\[\s*review/i);
         next if (/\#review/i);
         if (/[A-Z]{1}([A-Z]|[0-9])+\-\d+/i) {
            # We found a JIRA issue.  Clean up the text, removing
            # whitespace and text following the numnbers.
            s/\s//g;
            s/(\.|\;|\:).*$//g;

            # Normalize the JIRA issue to uppercase,
            # then capture it.
            $_ = uc($_); # Normalize to uppercase.
            @$issueArrayRef[$issueCount++]=$_;
         }
      }
   }
}

#------------------------------------------------------------------------------

=head2 GenChangelist()

GenChangelist($I<P4PORT>, $I<P4USER>, $I<P4CLIENT>, $I<Desc>;)

=head3 Description-GenChangelist

Generate a Perforce changelist.

=head3 Parameters-GenChangelist

=over 4

=item *

$I<P4PORT>

=item *

$I<P4USER>

=item *

$I<P4CLIENT>

=item *

$I<Desc> - Description for the generated Perforce changelist, quoted.

=back

=head3 Output-GenChangelist

None except for errors.

=head3 Returns-GenChangelist

This returns the generated changelist number.

In NoOp mode, '999999' is returned.

In event of error, a 0 is returned.

=head3 Examples-GenChangelist

Sample call:

C<my $cl = MinP4::GenChangelist ("perforce:1666", "p4admin", "p4admin.demo_ws", "This is my description.");>

C<die "Error!" if ($cl == 0);>

=cut

#------------------------------------------------------------------------------

sub GenChangelist($$$$;)
{
   $Msg->trace ("CALL MinP4::GenChangelist(@_)\n");
   my ($P4PORT, $P4USER, $P4CLIENT, $desc) = @_;
   my $tmpFile;
   my $changelist = 0;
   my $changeSpec;

   if ($NoOp) {
      $changelist = "999999";
      return $changelist;
   }

   $tmpFile = Misc::GenTempFilename();
   $changeSpec = "Change: new\n\nClient: $P4CLIENT\n\nUser: $P4USER\n\nStatus: new\n\nDescription:\n\t$desc\n\n";

   open (TMP, ">$tmpFile") or $Msg->logdie ("Error: Failed to create temp file [$tmpFile]: $!\n");
   print TMP $changeSpec;
   close (TMP);

   Cmd::Run ("/p4/common/bin/p4 -p $P4PORT -u $P4USER -c $P4CLIENT -s change -i < $tmpFile",
      "Generating pending changelist.", 0, $INFO);

   if ($Cmd::Output =~ /info: Change \d+/) {
      $changelist = $Cmd::Output;
      $changelist =~ s/^.*info: Change //;
      $changelist =~ s/ .*$//s;
   } else {
      $Msg->error ("Error generating changelist.  Spec:\n$changeSpec\n\nOutput:\n$Cmd::Output\n");
      return 0;
   }
   return $changelist;
}

#------------------------------------------------------------------------------

=head2 GenWorkspace()

GenWorkspace($I<P4PORT>, $I<P4USER>, $I<P4CLIENT>, $I<path>;)

=head3 Description-GenWorkspace

Generate a Perforce workspace.  Honors $NoOp and $Verbosity.  In $NoOp mode, the workspace spec is shown, but the workspace is not created on the Perforce server.

=head3 Parameters-GenWorkspace

=over 4

=item *

$I<P4PORT>

=item *

$I<P4USER>

=item *

$I<P4CLIENT>

=item *

$I<path> - A View path in Perforce depot syntax.  It should start with "//some_depot", and may contain more folders.  A "/..." will be appended to the value specified.

=back

=head3 Output-GenWorkspace

Displays a message indicating workspace creation, or an error message.

Honors $Verbosity setting.

=head3 Returns-GenWorkspace

None.

=head3 Examples-GenWorkspace

Sample call:

C<MinP4::GenWorkspace ("perforce:1666", "p4admin", "p4admin.demo_ws", "//here/there") or $Msg-E<gt>logdie ("Failed to create workspace.");>

=cut

#------------------------------------------------------------------------------

sub GenWorkspace($$$$;)
{
   $Msg->trace ("CALL MinP4::GenWorkspace(@_)\n");
   my ($P4PORT, $P4USER, $P4CLIENT, $path) = @_;
   my $tmpFile;
   my $clientSpec;
   my $hostname = `hostname`;
   chomp $hostname;

   $clientSpec = "Client: $P4CLIENT\n\nOwner: $P4USER\n\nHost: $hostname\n\nDescription:\n\tGenerated workspace.\n\nRoot: /p4/1/tmp/ws/$P4CLIENT\n\nOptions: noallwrite noclobber nocompress unlocked modtime rmdir\n\nSubmitOptions: revertunchanged\n\nLineEnd: local\n\nView:\n\t$path/... //$P4CLIENT/...\n\n";

   if ($NoOp) {
      $Msg->debug ("No-Op: Would have generated workspace with this spec:\n$clientSpec\n");
      return 1;
   }

   $tmpFile = Misc::GenTempFilename();

   open (TMP, ">$tmpFile") or $Msg->logdie ("Error: Failed to create temp file [$tmpFile]: $!\n");
   print TMP $clientSpec;
   close (TMP);

   Cmd::Run ("/p4/common/bin/p4 -p $P4PORT -u $P4USER -c $P4CLIENT -s client -i < $tmpFile",
      "Generating workspace $P4CLIENT.", 0, $INFO);

   if ($Cmd::Output =~ /exit: 0/) {
      $Msg->info ("Generated workspace [$P4CLIENT].");
      return 1;
   } else {
      $Msg->error ("Failed to generate workspace [$P4CLIENT].\n\nSpec:\n$clientSpec\n\nOutput:\n$Cmd::Output\n\n");
      return 0;
   }
}

#------------------------------------------------------------------------------

=head2 GenGlobalWorkspace()

GenGlobalWorkspace($I<P4PORT>, $I<P4USER>, $I<P4CLIENT>;)

=head3 Description-GenGlobalWorkspace

Generate a Perforce workspace with a wide view, seeing all depots of type 'local' the user has access to.  Honors $NoOp and $Verbosity.  In $NoOp mode, the workspace spec is shown, but the workspace is not created on the Perforce server.

=head3 Parameters-GenGlobalWorkspace

=over 4

=item *

$I<P4PORT>

=item *

$I<P4USER>

=item *

$I<P4CLIENT>

=back

=head3 Output-GenGlobalWorkspace

Displays a message indicating workspace creation, or an error message.

Honors $Verbosity setting.

=head3 Returns-GenGlobalWorkspace

None.

=head3 Examples-GenGlobalWorkspace

Sample call:

C<MinP4::GenGlobalWorkspace ("perforce:1666", "p4admin", "p4admin.all.demo_ws") or $Msg-E<gt>logdie ("Failed to create global workspace.");>

=cut

sub GenGlobalWorkspace($$$;)
{
   $Msg->trace ("CALL MinP4::GenGlobalWorkspace(@_)\n");
   my ($P4PORT, $P4USER, $P4CLIENT) = @_;
   my $tmpFile;
   my $clientSpec;
   my $depot;
   my $hostname = `hostname`;
   chomp $hostname;

   $clientSpec = "Client: $P4CLIENT\n\nOwner: $P4USER\n\nHost: $hostname\n\nDescription:\n\tGenerated workspace.\n\nRoot: /p4/1/tmp/ws/$P4CLIENT\n\nOptions: noallwrite noclobber nocompress unlocked modtime rmdir\n\nSubmitOptions: revertunchanged\n\nLineEnd: local\n\nView:\n";

   # Get the list of all local depots, but don't display it even in high verbosity mode.
   Cmd::Run ("/p4/common/bin/p4 -p $P4PORT -u $P4USER -c none -s depots",
      "Getting list of local depots visible to user $P4USER.", 1, $TRACE);

   foreach (split '\n', $Cmd::Output) {
      next unless /^info: Depot .* \d{4}\/\d{2}\/\d{2} local /;
      s/^info: Depot //;
      s/ .*$//;
      chomp;
      $depot = $_;
      $clientSpec = "$clientSpec\t//$depot/... //$P4CLIENT/$depot/...\n";
   }

   $clientSpec = "$clientSpec\n";

   if ($NoOp) {
      $Msg->debug ("No-Op: Would have generated workspace with this spec:\n$clientSpec\n");
      return 1;
   }

   $tmpFile = Misc::GenTempFilename();

   open (TMP, ">$tmpFile") or $Msg->logdie ("Error: Failed to create temp file [$tmpFile]: $!\n");
   print TMP $clientSpec;
   close (TMP);

   Cmd::Run ("/p4/common/bin/p4 -p $P4PORT -u $P4USER -c $P4CLIENT -s client -i < $tmpFile",
      "Generating workspace [$P4CLIENT].", 0, $INFO);

   if ($Cmd::Output =~ /exit: 0/) {
      $Msg->info ("Generated workspace [$P4CLIENT].");
      return 1;
   } else {
      $Msg->error ("Failed to generate workspace [$P4CLIENT].\n\nSpec:\n$clientSpec\n\nOutput:\n$Cmd::Output\n\n");
      return 0;
   }
}

#------------------------------------------------------------------------------

=head2 GenStreamWorkspace()

GenStreamWorkspace($I<P4PORT>, $I<P4USER>, $I<P4CLIENT>, $I<stream>;)

=head3 Description-GenStreamWorkspace

Generate a Perforce workspace with a wide view, seeing all depots of type 'local' the user has access to.  Honors $NoOp and $Verbosity.  In $NoOp mode, the workspace spec is shown, but the workspace is not created on the Perforce server.

=head3 Parameters-GenStreamWorkspace

=over 4

=item *

$I<P4PORT>

=item *

$I<P4USER>

=item *

$I<P4CLIENT>

=item *

$I<stream>

=back

=head3 Output-GenStreamWorkspace

Displays a message indicating workspace creation, or an error message.

Honors $Verbosity setting.

=head3 Returns-GenStreamWorkspace

None.

=head3 Examples-GenStreamWorkspace

Sample call:

C<MinP4::GenStreamWorkspace ("perforce:1666", "p4admin", "p4admin.all.demo_ws", "//fgs/main/") or $Msg-E<gt>logdie ("Failed to create global workspace.");>

=cut

sub GenStreamWorkspace($$$$;)
{
   $Msg->trace ("CALL MinP4::GenStreamWorkspace(@_)\n");
   my ($P4PORT, $P4USER, $P4CLIENT, $stream) = @_;
   my $tmpFile;
   my $clientSpec;
   my $hostname = `hostname`;
   chomp $hostname;

   $clientSpec = "Client: $P4CLIENT\n\nOwner: $P4USER\n\nHost: $hostname\n\nDescription:\n\tGenerated workspace.\n\nRoot: /p4/1/tmp/ws/$P4CLIENT\n\nOptions: noallwrite noclobber nocompress unlocked modtime rmdir\n\nSubmitOptions: revertunchanged\n\nLineEnd: local\n\nStream: $stream\n\n";

   if ($NoOp) {
      $Msg->debug ("No-Op: Would have generated workspace with this spec:\n$clientSpec\n");
      return 1;
   }

   $tmpFile = Misc::GenTempFilename();

   open (TMP, ">$tmpFile") or $Msg->logdie ("Error: Failed to create temp file [$tmpFile]: $!\n");
   print TMP $clientSpec;
   close (TMP);

   Cmd::Run ("/p4/common/bin/p4 -p $P4PORT -u $P4USER -c $P4CLIENT -s client -i < $tmpFile",
      "Generating workspace [$P4CLIENT] for stream [$stream].", 0, $INFO);

   if ($Cmd::Output =~ /exit: 0/) {
      $Msg->info ("Generated stream workspace [$P4CLIENT].");
      return 1;
   } else {
      $Msg->error ("Failed to generate workspace [$P4CLIENT].\n\nSpec:\n$clientSpec\n\nOutput:\n$Cmd::Output\n\n");
      return 0;
   }
}

#------------------------------------------------------------------------------

=head2 GetBranchPaths()

GetBranchPaths ($I<branchSpecName>, $I<leftOrRight>, \@I<fileArrayRef>, $I<keepExclusions>)

=head3 Description-GetBranchPaths

Populate an array with source or target paths of a branch spec.

This routine properly handles paths with spaces in the name.

=head3 Parameters-GetBranchPaths

=over 4

=item *

$I<branch_spec>

The name of the branch spec.

=item *

$I<leftOrRight>

Pass 1 for paths on the left side of the branch spec, or 2 for paths on the right.

=item *

\@I<fileArrayRef>

Pass in a reference to the array of paths to populate.

=item *

$I<keep_exclusions>

Set to 1 to keep Exclusionary mappings in the reivew returned.  By default, they are excluded.

=back

=head3 Returns-GetBranchPaths

Returns 1 on and populates the paths array, or 0 on error.

=head3 Examples-GetBranchPaths

=head4 Get Source Branch Paths:

C<my @files;>

C<my $branch = "dev_FS247";>

C<MinP4::GetBranchPaths ($branchName, 1, \@files) or $Msg-E<gt>logdie ("Couldn't get branch paths.");>

=head4 Get Target Branch Paths:

C<my @files;>

C<my $branch = "dev_FS247";>

C<MinP4::GetBranchPaths ($branchName, 2, \@files);>

=cut

#------------------------------------------------------------------------------

sub GetBranchPaths ($$$;$)
{
   $Msg->trace("CALL MinP4::GetBranchPaths (@_)");
   my ($branchSpecName, $sourceOrTarget, $pathsArrayRef, $keepExclusions) = @_;
   my $path;
   my $i = 0;

   Cmd::Run ("p4 -ztag branch -o $branchSpecName",
      "Getting details for branch spec [$branchSpecName]", 1, $DEBUG);

   if ($Cmd::Output =~ /\.\.\. Access /) {
      if ($sourceOrTarget == 1) {
         foreach (split ('\n', $Cmd::Output)) {
            next unless (/^\.\.\. View\d+ /);
            s/^\.\.\. View\d+ //;

            if (/^\-/ or /^\"\-/) {
               next unless ($keepExclusions);
            }

            # Consider entries with and without spaces needing double
            # quotes, and with and without exclusionary mappings.
            if (/\"\-\/\//) {
               s/^.*\"\/\//\"\-\/\//;
            } elsif (/\-\/\//) {
               s/^.*\-\/\//\-\/\//;
            } elsif (/\"\/\//) {
               s/^.*\"\-\/\//\"\-\/\//;
            } else {
               s/^.*\/\//\/\//;
            }

            #if (/\"/) { $_ = "\"$_"; }

            $Msg->trace ("Adding source path [$_].\n");
            @$pathsArrayRef[$i++] = $_;
         }
      } else {
         foreach (split ('\n', $Cmd::Output)) {
            next unless (/^\.\.\. View\d+ /);
            s/^\.\.\. View\d+ //;
            s/ \"*\/\/.*$//s;

            if (/^\-/ or /^\"\-/) {
               next unless ($keepExclusions);
            }

            $Msg->trace ("Adding target path [$_].\n");
            @$pathsArrayRef[$i++] = $_;
         }
      }
   } elsif ($Cmd::Output =~ /\.\.\. Branch /) {
      $Msg->error ("Branch [$branchSpecName] does not exist.");
      return 0;
   } else {
      $Msg->error ("Failed to process branch spec [$branchSpecName]:\n$Cmd::Output\n");
      return 0;
   }
   return 1;
}

#------------------------------------------------------------------------------

=head2 GetChangelistFiles()

GetChangelistFiles ($I<changeInfo>, \@I<fileArrayRef>; $I<keepExclusions>)

=head3 Description-GetChangelistFiles

Populate an array with file paths from a changelist.

This routine properly handles paths with spaces in the name.

=head3 Parameters-GetChangelistFiles

=over 4

=item *

$I<changeInfo>

Provide 'p4 describe' output changelist info obtained by a command like the this sample:

C<p4 -ztag describe -s 30434>

=item *

=item *

\@I<fileArrayRef>

Pass in a reference to the array of paths to populate.

=item *

$I<keep_exclusions>

Set to 1 to keep Exclusionary mappings in the returned.  By default, they are excluded.

=back

=head3 Returns-GetChangelistFiles

Returns 1 on and populates the paths array, or 0 on error.

=head3 Examples-GetChangelistFiles

=head4 Get changes from change 31110

C<my @files;>

C<my @changelist = "31110";>

C<Cmd::Run("p4 -ztag describe -s $changelist");>

C<MinP4::GetChangelistFiles ($Cmd::Output, \@files) or $Msg-E<gt>logdie ("Couldn't get files paths.");>

=cut

#------------------------------------------------------------------------------

sub GetChangelistFiles ($$;)
{
   $Msg->trace("CALL MinP4::GetChangelistFiles (@_)");
   my ($changelist, $filesArrayRef) = @_;
   my $file;
   my $i = 0;

   Cmd::Run ("p4 -ztag describe -s $changelist",
      "Getting changelist data.", 1, $DEBUG);

   if ($Cmd::Output =~ /\.\.\. change /) {
      foreach (split ('\n', $Cmd::Output)) {
         next unless /^\.\.\. depotFile\d+ /;
         $file = $_;
         $file =~ s/^\.\.\. depotFile\d+ //;
         chomp $file;
         @$filesArrayRef[$i++] = $file;
      }
   } else {
      $Msg->logdie ("Could not get details for change %changelist:\n$Cmd::Output\nAborting\n");
   }

   if ($Cmd::Verbosity >= $DEBUG) {
      $Msg->debug("Changelist files:");
      foreach (@$filesArrayRef) {
         print "$_\n";
      }
   }
}

# Return package load success.
1;
