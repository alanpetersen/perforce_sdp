package Msg;

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

Msg.pm - Output messages with verbosity control.

=head1 VERSION

2.6.0

=head1 DESCRIPTION

This package provides a standard way to write log messages, and sets the global $Cmd::Verbosity setting.

Other variations of this package provide additional logging channels (e.g. file appenders, screen appenders, etc.).  This version is optimized to minizme external dependencies.

=head1 PUBLIC DATA

=head1 EXAMPLES

Here is a typical usage example:

=over 4

C<$Msg = Msg::new();> # Done once at the start of a program.

C<$Msg->info("This is a normal info message.");>

C<$Msg->logdie ("Famous last words:  Ahhhhhh!");>

=back

=head1 PUBLIC FUNCTIONS

=cut

require Exporter;

use strict;
use File::Path;
use File::Basename;
#use IO::Handle;
use POSIX qw(uname);

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $FATAL $ERROR $WARN $INFO $DEBUG $TRACE $Msg $Level %MsgLevelText);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "2.6.0";

   ($FATAL, $ERROR, $WARN, $INFO, $DEBUG, $TRACE) = (1, 2, 3, 4, 5, 6);
   $Level = $INFO;

   $MsgLevelText{'1'} = "FATAL";
   $MsgLevelText{'2'} = "ERROR";
   $MsgLevelText{'3'} = "WARN";
   $MsgLevelText{'4'} = "INFO";
   $MsgLevelText{'5'} = "DEBUG";
   $MsgLevelText{'6'} = "TRACE";
}

# Package interface standards.
@ISA = qw(Exporter);
@EXPORT = qw($Msg $FATAL $ERROR $WARN $INFO $DEBUG $TRACE);
@EXPORT_OK = qw(SetLevel $LogFile $Level %MsgLevelText);

# Prototypes for public functions.
sub new();
sub SetLevel ($$;);
sub fatal ($$;);
sub error ($$;);
sub warn ($$;);
sub info ($$;);
sub debug ($$;);
sub trace ($$;);
sub logdie ($$;);

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------
sub new ()
{
   my $self = {};
   shift;
   bless ($self);
   return $self;
}

#------------------------------------------------------------------------------

=head2 SetLevel()

SetLevel($I<verbosity>;)

=head3 Description-SetLevel

Set the logging/output verbosity level.  Each log message has an assigned verbosity level.  Messages at or below the current verobsity level are displayed.  Messages above the specified level are suppressed.  A higher numeric value generally results in increased log output.

For example, specifying a value of 4 causes FATAL, ERROR, WARN, and INFO messages to be displayed, while DEBUG and TRACE messages are suppressed.

The Misc::Verobsity value is assigned to the same value.

=head3 Parameters-SetLevel

$I<verbosity> - Specify the verbosity as a numeric value from 1-6.  Each numeric value corresponds to a certain type of message:

=over 4

=item 1 = FATAL

=item 2 = ERROR

=item 3 = WARN

=item 4 = INFO

=item 5 = DEBUG

=item 6 = TRACE

=back

For example, specifying a value of 4 causes FATAL, ERROR, WARN, and INFO messages to be displayed, while DEBUG and TRACE messages are suppressed.

=head3 Returns-SetLevel

None

=head3 Examples-SetLevel

To enable INFO-level logging:

C<Msg::SetLevel (4);>

=cut

#------------------------------------------------------------------------------
sub SetLevel ($$;)
{
   shift;
   $Level = shift;
   $Cmd::Verbosity = $Level;
}

#------------------------------------------------------------------------------
sub fatal ($$;)
{
   shift;
   my ($msg) = @_;
   print "FATAL: $msg\n" if ($Level >= $FATAL);
}

#------------------------------------------------------------------------------
sub error ($$;)
{
   shift;
   my ($msg) = @_;
   print "ERROR: $msg\n" if ($Level >= $ERROR);
}

#------------------------------------------------------------------------------
sub warn ($$;)
{
   shift;
   my ($msg) = @_;
   print "WARN: $msg\n" if ($Level >= $WARN);
}

#------------------------------------------------------------------------------
sub info ($$;)
{
   shift;
   my ($msg) = @_;
   print "INFO: $msg\n" if ($Level >= $INFO);
}

#------------------------------------------------------------------------------
sub debug ($$;)
{
   shift;
   my ($msg) = @_;
   print "DEBUG: $msg\n" if ($Level >= $DEBUG);
}

#------------------------------------------------------------------------------
sub trace ($$;)
{
   shift;
   my ($msg) = @_;
   print "TRACE: $msg\n" if ($Level >= $TRACE);
}

sub logdie ($$;)
{
   shift;
   my ($msg) = @_;
   die "\n\nFATAL:  $msg\n\n";
}

# Return package load success.
1;
