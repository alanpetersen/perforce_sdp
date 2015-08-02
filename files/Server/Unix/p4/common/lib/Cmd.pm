package Cmd;

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

Cmd.pm - Execute system calls, honoring globals $Cmd::Verbosity and $Cmd::NoOp.

=head1 VERSION

2.6.0

=head1 DESCRIPTION

This modules provides the Cmd::Run() function, which executes system calls.  It honors $Cmd::NoOp ("no operation"). By default, commands are displayed rather than executed if $Cmd::NoOp is set.

The caller can determine the verbosity level at which a descriptive comment is displayed, and the verbosity level at which the output of the command (both stdout and stderr) are displayed.

Whether or not it is displayed, the $Cmd::Output variable contains the output (both stdout and stderr) of the command executed.

The exit code of the system call is available as $Cmd::ExitCode.

=head1 PUBLIC DATA

=head2 $Cmd::NoOp:

If $Cmd::NoOp is set to 1, then Cmd::Run() will display commands rather than executing them.  This provides script developers with a standard way to provide users a way to show commands that would be run before actually running them.

This variable is exported and is global.

=head2 $Cmd::Verbosity:

This determines the amount of output, in the form of a numeric value from 1 (quiet, fatal errors only) to 6 (high debugging).  See Msg.pm for more detail.

This variable is exported and is global.


=head2 $Cmd::ExitCode:

Contains exit code returned from the last command executed by Cmd::Run().

=head2 $Cmd::Output:

The $Cmd::Output string contains the the output of a command executed with the Cmd::Run() routine.

=head1 PUBLIC FUNCTIONS

=cut

require Exporter;

use strict;
use File::Temp;
use POSIX qw(uname);
use Msg;
use Misc;

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use vars qw($ExitCode $NoOp $Output $Verbosity $IGNORE_NO_OP $HONOR_NO_OP);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "2.6.0";

   # Exported variable initialization.
   $ExitCode = 0;
   $NoOp = 0;
   $Output = "";
   $Verbosity = $INFO;

   # Exported constants for readability.
   $HONOR_NO_OP = 0;
   $IGNORE_NO_OP = 1;
}

# Package interface standards.  By default, any export can be blocked.
@ISA = qw(Exporter);

@EXPORT = qw(
   Run
   $NoOp
   $Verbosity
   $IGNORE_NO_OP
   $HONOR_NO_OP
);

@EXPORT_OK = qw(
   $ExitCode
   $Output
);

# Prototypes for public functions.
sub Run($;$$$$);

#==============================================================================
# Internal Functions
#==============================================================================

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------

=head2 Run()

Cmd($I<cmd>; $I<desc>, $I<ignoreNoOpFlag>, $I<desc_v>, $I<out_v>) returns exit code from $I<cmd>

=head3 Description-Cmd

This runs a command, and interacts with $I<Cmd::Verbosity> and $I<Cmd::NoOp> in a standard fashion.  See descriptions of $I<Cmd::Verbosity> and $I<Cmd::NoOp> in Misc.pm.  It also sets $I<Cmd::ExitCode> and $I<Cmd::Output>.

=head3 Parameters-Cmd

$I<cmd> - Command to run in the system shell.  "2E<gt>&1" will be appended to the command, redirecting standard error to standard out.

Note that the command can contain an input redirect, a 'E<lt>' character.  It may I<not> contain output redirection ('2E<gt>' or '2E<gt>&1').

This parameter is required; all others are optional.

$I<desc> - Description of the command to run (optional).

$I<ignoreNoOpFlag> - If set to 1, command is executed even if $Cmd::NoOp is set.  If this optional parameter is omitted, the default behavior is to honor the NoOp flag (i.e. not execute the command if $Cmd::NoOp is Set).

This flag should only be used for commands that do not affect data, to honor the spirit of the $Cmd::NoOp flag.  For example, it is appropriate to ignore the $Cmd::NoOp setting for a directory listing command, but not one that removes a directory tree.

For readability, $IGNORE_NO_OP and $HONOR_NO_OP constants can be passed in.

$I<desc_v> - The verbostiy level at or above which the description is displayed (optional).  The default is $INFO.  See Msg.pm for verbosity levels.

$I<out_v> - The verbostiy level at or above which the command output is displayed (optional).  The default is $DEBUG.  See Msg.pm for verbosity levels.

=head3 Output-Cmd

Output depends on the verbosity setting:

=over 4

=item 1

None

=item 2

Commmand description only (typical).

=item 3

Command description and the actual command to run.

=item 4

Command description, actual command to run, and output of the command.

=back

=head3 Returns-Cmd

The return value of the system call is returned.  The output of the executed command is displayed if $I<Cmd::Verbosity> E<gt> 3, and is also available in the calling environment via the global variable $Cmd::Output. The $I<Cmd::CmdExitCode> contains the exit status of the return command. This should be checked instead of $?, since $? is not set in NoOp mode.

=head3 Examples-Cmd

=head4 List *.cfg files in a directory tree:

C<Cmd::Run ("DIR /S/B/A-D *.cfg", "\nListing cfg files:\n");>

C<my @FileList = split ('\n', $Cmd::Output);>

=head4 Run quietly at normal verbosity, showing the description only at DEBUG or higher verobsity level, and executing the command even if in NoOp mode, and showing output only at the maximum TRACE debug level.

C<Cmd::Run ("DIR /S/B/A-D *.cfg", "\nListing cfg files:\n", $IGNORE_NO_OP, $DEBUG, $TRACE);>

=cut

#------------------------------------------------------------------------------
sub Run($;$$$$)
{
   $Msg->trace("Cmd::Run(@_)");
   my ($cmd, $desc, $ignoreNoOpFlag, $desc_v, $out_v) = @_;

   $desc_v = $INFO unless ($desc_v);
   $out_v = $DEBUG unless ($out_v);

   if ($desc && ($desc ne "")) {
      print "$Msg::MsgLevelText{$desc_v}: $desc\n" if ($Verbosity >= $desc_v);
   }

   $Msg->debug("Executing command: [$cmd].");
   $Output = "";
   $ExitCode = 0;

   if ($NoOp && ( ! $ignoreNoOpFlag))
   {
      $Msg->info("NO-OP: Would run: [$cmd].");
      return $ExitCode;
   } else {
      $Output = `$cmd 2>&1`;
      $ExitCode = $?;

      print $Output if ($Output ne "" && ($Verbosity >= $out_v));

      return $ExitCode;
   }
}

# Return package load success.
1;
