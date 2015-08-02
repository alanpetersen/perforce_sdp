#!/usr/local/ActivePerl-5.16/bin/perl -w
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

#==============================================================================
# Environment Setup and Library Includes
#==============================================================================
require 5.005;
use strict;
use File::Basename;
use File::Temp;
use Getopt::Long;
use OS;
use Msg;
use Cmd;
use Misc;
use Cwd;
use JIRA::Client::Automated;
use JSON;

BEGIN
{
    $main::ThisScript = basename($0);
    $main::ThisScript =~ s/\.exe$/\.pl/i;
    $main::VERSION = "1.2.1";
    @main::InitialCmdLine = @ARGV;
    $main::InitialDir = cwd();
    chomp $main::InitialDir;
}

# Prototypes for Local Functions.
sub usage (;$);

#==============================================================================
# Declarations
#==============================================================================
my %IssueHash;
my $IssueHashRef;
my %FieldsHash;
my $FieldsHashRef;
my %StatusHash;
my $StatusHashRef;
my $IssueKey;
my $JIRA;

# Define JURL, JUser, and JPassword.
my $JURL = "http://jira.yourcompany.com";
my $JUser = "your_jira_user";
my $JPassword = "your_jira_password";

$Msg = Msg::new();

#==============================================================================
# Command Line Parsing
#==============================================================================
# Note:  -h and -man are reserved commands with special meanings for all
# scripts.  The -h gives a short usages message [just showing options]
# while the -man options shows the man page.
Getopt::Long::config "no_ignore_case";
Getopt::Long::config "auto_abbrev";

GetOptions(\%main::CmdLine, "help", "man", "verbosity=s", "noop",
    "issue=s", "URL=s", "JUser=s", "Password=s")
    or $Msg->logdie("\nUsage Error:  Unrecognized argument.\n");

# Validate command line arguments.
usage("man") if $main::CmdLine{'man'};
usage() if $main::CmdLine{'help'};
$NoOp = 1 if $main::CmdLine{'noop'};

if ($main::CmdLine{'issue'}) {
   $IssueKey = uc($main::CmdLine{'issue'});
} else {
   $Msg->logdie ("The '-i <issue>' argument is required.");
}

$JURL = $main::CmdLine{'URL'} if ($main::CmdLine{'URL'});
$JUser = $main::CmdLine{'JUser'} if ($main::CmdLine{'JUser'});
$JPassword = $main::CmdLine{'Password'} if ($main::CmdLine{'Password'});

# If there are unhandled fragments on the command line, give a usage error.
$Msg->logdie("\nUsage Error:  Unrecognized command line fragments:  @ARGV.")
    unless $#ARGV == -1;

#==============================================================================
# Main Program
#==============================================================================
# Note on comment usage: Normal comments just have a '#', special comments
# that are intended to draw developers attention use '##', comments like:
## Note:  This function should be deleted after the next release!

if ($main::CmdLine{'verbosity'}) {
    $Msg->SetLevel ($main::CmdLine{'verbosity'});
} else {
    $Msg->SetLevel ($INFO);
}

$Msg->debug("Initial Directory:\n\t$main::InitialDir\n
Running $main::ThisScript v$main::VERSION\n
Command Line was:\n\t$main::ThisScript @main::InitialCmdLine");

$JIRA = JIRA::Client::Automated->new($JURL, $JUser, $JPassword);
$IssueHashRef = $JIRA->get_issue ($IssueKey);

%IssueHash = %$IssueHashRef;

$Msg->debug ("JIRA Issue top-level fileds:");

foreach (keys %IssueHash) {
   $Msg->debug ("I: [$_]:  [$IssueHash{$_}].");
}

$FieldsHashRef = $IssueHash{'fields'};
%FieldsHash = %$FieldsHashRef;

foreach (keys %FieldsHash) {
   $Msg->debug ("F: [$_]");
}

$StatusHashRef = $FieldsHash{'status'};
%StatusHash = %$StatusHashRef;

foreach (keys %StatusHash) {
   $Msg->debug ("S: [$_]");
}

$Msg->info("Status of JIRA Issue [$IssueKey] is [$StatusHash{'name'}]");

exit 0;

#==============================================================================
# Local Functions
#==============================================================================

#------------------------------------------------------------------------------
# Subroutine: usage (required function)
#
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

    # Be sure to keep the short "syntax only" version of the usage message
    # in sync with the info in POD style at the top of the script.
    if ($style eq "man")
    {
        $scriptDocFile =~ s/\.(pl|exe)$/\.html/i;
        $scriptDocFile = "$scriptDocFile.html" unless ($scriptDocFile =~ /\.html$/);

        if ( -r $main::ThisScript)
        {
            Cmd::Run ("perldoc $main::ThisScript", "", 1);
            print $Cmd::Output;
            exit (1) if ($Cmd::ExitCode == 0);
        }

        # If perldoc.exe or the  source *.pl script isn't available,
        # display a message indicating the existence of HTML docs.
        print "
    $main::ThisScript v$main::VERSION

    See $scriptDocFile for more info.\n\n";
        exit 1;
    } else
    {
        print "
$main::ThisScript v$main::VERSION\n
Usage:
   $main::ThisScript -i <issue> [-U <JIRA_URL>] [J <JIRA_User>] [-P <JIRA_Password>] [-v <level>] [-noop]
 OR
   $main::ThisScript [-h|-man]
";
    }

    exit 1;
}

__END__

=head1 NAME

get_JIRA_issue_status.pl -  Display the status of a JIRA issue.

=head1 VERSION

1.2.1

=head1 SYNOPSIS

get_JIRA_issue_status.pl -i I<issue> [-U I<JIRA_URL>] [-J I<JIRA_User>] [-P I<JIRA_password>] [-v I<level>] [-noop]

OR

get_JIRA_issue_status.pl {-h|-man}

=head1 DESCRIPTION

This demonstrates the MinJIRA.pm wrapper module, which is in turn a wrapper to JIRA::Client::Automated module available from CPAN, the Contributed Perl Archive Network.

=head2 Overview

The default JIRA connection settings are simply (and perhaps insecurely) hard-coded in this script, with command line overrides available.  Search for the JURL, JUser, and JPassword settings to update the defaults for your site.  Provide local settings for testing, or provide them on the command line.

=head1 ARGUMENTS

=head2 -i I<issue>

Specify the JIRA issue.  This is required.

=head2 -U I<JIRA_URL>

Specify the JIRA URL, something like C<http://jira.yourcompany.com:8080> or C<https://jira.yourcompany.com>.

Depending on how JIRA is configured, the port number may or may not be required, and it may be http or https.

=head2 -J I<JIRA_User>

Specify the JIRA userid.  Your access to JIRA is dependent on the access of this account.

=head2 -P I<JIRA_Password>

Specify the JIRA password.  If your password contains certain specail characters, like a '!', you will need to escape them with a backslash, e.g.:

-P PasswordWithABang\!

=head2 -v[erbosity] I<level>

Specify the verbosity level, from 1-4. 6 is quiet mode; only error output is displayed.  4 is normal verbosity; some messages displayed. 5 is noisy. 6 is debug-level verbosity.

=head2 -noop

Specify No Op mode, indicating that the script should display what it would do with given arguments and environment, but take no action that affects data.

=head2 -h|-man

Display a usage message.  The -h display a short synopsis only, while -man displays this message.

=head1 EXAMPLES

=head2 Typical Usage

C<get_JIRA_issue_status.pl -i PROJ-1239>

=head1 RELATED SOFTWARE

This depends on several Perl Modules.  Key modules are:

=over 4

=item *

B<OS.pm> - Abstraction layer for platform (e.g. Linux/Windows) variations.

=item *

B<Cmd.pm> - Command line wrapper.

=item *

B<Misc.pm> - Misc Perl utils.

=item *

B<Msg.pm> - Message interface to encourage consistent look and feel, and simplify logging.

=item *

B<JIRA::Client::Automated.pm> - This module is available from CPAN, and is provides the core JIRA interaction logic.  Tested with versions 1.02 thru 1.1.

=back

=head1 RETURN STATUS

Zero indicates normal completion, Non-Zero indicates an error.

=cut
