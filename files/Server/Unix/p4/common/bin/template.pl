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
# Environment Setup and Library Includes
#==============================================================================
require 5.010;
use strict;
use File::Basename;
use File::Temp;
use Getopt::Long;
use Cwd;
use OS;
use Msg;
use Cmd;
use Misc;

BEGIN
{
    $main::ThisScript = basename($0);
    $main::ThisScript =~ s/\.exe$/\.pl/i;
    $main::VERSION = "1.0.0";
    @main::InitialCmdLine = @ARGV;
    $main::InitialDir = cwd();
    chomp $main::InitialDir;
}

# Prototypes for Local Functions.
sub usage (;$);

#==============================================================================
# Declarations
#==============================================================================
$Msg = Msg::new();

#==============================================================================
# Command Line Parsing
#==============================================================================
# Note:  -h and -man are reserved commands with special meanings for all
# scripts.  The -h gives a short usages message [just showing options]
# while the -man options shows the man page.
Getopt::Long::config "no_ignore_case";
Getopt::Long::config "auto_abbrev";

GetOptions(\%main::CmdLine, "help", "man", "verbosity=s", "noop")
    or $Msg->logdie("\nUsage Error:  Unrecognized argument.\n");

# Validate command line arguments.
usage("man") if $main::CmdLine{'man'};
usage() if $main::CmdLine{'help'};
$NoOp = 1 if $main::CmdLine{'noop'};

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
    $Msg->SetLevel ($TRACE);
}

$Msg->info("Initial Directory:\n\t$main::InitialDir\n
Running $main::ThisScript v$main::VERSION\n
Command Line was:\n\t$main::ThisScript @main::InitialCmdLine");

## BLAH BLAH BLAH

$Msg->info("All Processing Complete");

exit 0;

#==============================================================================
# Local Functions
#==============================================================================

#------------------------------------------------------------------------------
# Terminal Processing.
#------------------------------------------------------------------------------
#END
#{
#}

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
   $main::ThisScript [-v <level>] [-noop]
 OR
   $main::ThisScript [-h|-man]
";
    }

    exit 1;
}

__END__

=head1 NAME

template.pl - Perl script template.

=head1 VERSION

1.0.0

=head1 SYNOPSIS

template.pl [-v I<level>] [-noop]

OR

template.pl {-h|-man}

=head1 DESCRIPTION

=head2 Overview

=head1 ARGUMENTS

=head2 -v[erbosity] I<level>

Specify the verbosity level, from 1-4. 1 is quiet mode; only error output is displayed.  2 is normal verbosity; some messages displayed. 3 is noisy. 4 is debug-level verbosity.

=head2 -noop

Specify No Op mode, indicating that the script should display what it would do with given arguments and environment, but take no action that affects data.

=head2 -h|-man

Display a usage message.  The -h display a short synopsis only, while -man displays this message.

=head1 EXAMPLES

=head2 Example 1

Typical human usage example:

C<template.pl -h>

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

=back

=head1 RETURN STATUS

Zero indicates normal completion, Non-Zero indicates an error.

=cut
