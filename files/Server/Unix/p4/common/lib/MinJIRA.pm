package MinJIRA;

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

MinJIRA.pm - Minimal JIRA interface module.

=head1 VERSION

1.1.0

=head1 DESCRIPTION

Provides a minimal interface to JIRA via the JIRA REST API.

=head1 PUBLIC DATA

None

=head1 PUBLIC FUNCTIONS

=cut

require Exporter;

use strict;
use JSON;
use JIRA::Client::Automated;
use Msg;

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "1.1.0";

}

# Package interface standards.  By default, any export can be blocked.
@ISA = qw(Exporter);

# Prototypes for public functions.
sub GetIssueStatus($$$$;);

#==============================================================================
# Internal Functions
#==============================================================================

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------

=head2 GetIssueStatus()

GetIssueStatus ($I<issueKey>, $I<JURL>, $I<JUser>, $I<JPassword>;)

=head3 Description-GetIssueStatus

Determines if the MinJIRA is Mac.

=head3 Parameters-GetIssueStatus

=over 4

=item *

$I<issueKey> - Self-explanatory.

=item *

$I<JURL>

URL for the JIRA server.

=item *

$I<JUser>

JIRA user for accessing the REST API.

=item *

$I<JPassword>

Password for the JIRA user.

=back

=head3 Returns-GetIssueStatus

Returns the JIRA issue status string on success.

=cut

#------------------------------------------------------------------------------
sub GetIssueStatus ($$$$;)
{
   $Msg->trace("CALL MinJIRA::GetIssueStatus(@_)");
   my ($issueKey, $jurl, $juser, $jpwd) = @_;
   my $jira;
   my %issueHash;
   my $issueHashRef;
   my %fieldsHash;
   my $fieldsHashRef;
   my %statusHash;
   my $statusHashRef;
   my $issueStatus = "Undefined_JIRA_Issue_Status";

   if ($issueKey =~ /^\w+-\d+/) {
      $Msg->trace ("This issue key looks valid: [$issueKey].");
   } else {
      $Msg->error ("This issue key does NOT look valid: [$issueKey].");
      return $issueStatus;
   }

   $jira = JIRA::Client::Automated->new($jurl, $juser, $jpwd);

   $issueHashRef = $jira->get_issue ($issueKey);

   %issueHash = %$issueHashRef;

   $Msg->debug ("JIRA Issue top-level fileds:");

   foreach (keys %issueHash) {
      $Msg->trace ("I: [$_]:  [$issueHash{$_}].");
   }

   $fieldsHashRef = $issueHash{'fields'};
   %fieldsHash = %$fieldsHashRef;

   foreach (keys %fieldsHash) {
      $Msg->trace ("F: [$_]");
   }

   $statusHashRef = $fieldsHash{'status'};
   %statusHash = %$statusHashRef;

   foreach (keys %statusHash) {
      $Msg->trace ("S: [$_]");
   }

   $issueStatus = $statusHash{'name'};

   return $issueStatus;
}

# Return package load success.
1;
