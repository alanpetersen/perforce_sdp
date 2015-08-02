package OS;

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

OS.pm - Module OS detection modules and platform abstraction.

=head1 VERSION

2.6.0

=head1 DESCRIPTION

Provides modules to query, show, and handle run on different operating systems, standardizing that to some degree.

=head1 PUBLIC DATA

=head2 @OS::OS:

@OS::OS contains information about the current operating system, in the form of an array returned by POSIX::uname().  The values are:

=over 4

=item *

$OS::OS[0] - $sysname, e.g. "Windows NT".

=item *

$OS::OS[1] - $nodename (aka hostname or %COMPUTERNAME%), e.g. "BUILD_SVR_042".

=item *

$OS::OS[2] - $release, e.g. "5.1".

=item *

$OS::OS[3] - $version, e.g. "Build 2600 (Service Pack 2)".

=item *

$OS::OS[4] - $machine, e.g. "x86".

=back

=head2 $OS::PS

This is the directory separator character, a '/' in Unix-like systems, or a '\' on Windows.

=head1 PUBLIC FUNCTIONS

=cut

require Exporter;

use strict;
use POSIX qw(uname);
use Msg;

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use vars qw(@OS $PS);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "2.6.0";

   # Exported variable initialization.
   @OS = POSIX::uname();
   $PS = ($OS[0] =~ /Windows/) ? "\\" : "/";
}

# Package interface standards.  By default, any export can be blocked.
@ISA = qw(Exporter);
@EXPORT = qw($PS @OS);
@EXPORT_OK = qw(IsMac IsUnix IsWindows Show);

# Prototypes for public functions.
sub IsMac();
sub IsUnix();
sub IsWindows();
sub Show();

#==============================================================================
# Internal Functions
#==============================================================================

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------

=head2 IsMac()

IsMac () returns 1 if the operating system based on the Apple Darwin kernel.

=head3 Description-IsMac

Determines if the OS is Mac.

=head3 Parameters-IsMac

None

=head3 Returns-IsMac

Returns 1 if running on a Mac.

=cut

#------------------------------------------------------------------------------
sub IsMac ()
{
   return 1 if ($OS::OS[0] =~ /(Darwin)/i);
   return 0;
}

#------------------------------------------------------------------------------

=head2 IsUnix()

IsUnix () returns 1 if operating system is Unix or Linux, 0 otherwise.

=head3 Description-IsUnix

Determines if the OS is Unix-like (including Linux).

=head3 Parameters-IsUnix

None

=head3 Returns-IsUnix

Returns 1 if running on a Unix-like operating system, including Linux.

=cut

#------------------------------------------------------------------------------
sub IsUnix ()
{
   return 1 if ($OS::OS[0] =~ /(Unix|Linux)/i);
   return 0;
}

#------------------------------------------------------------------------------

=head2 IsWindows()

IsUnix () returns 1 if operating system is Windows, 0 otherwise.

=head3 Description-IsWindows

Determines if the OS is Windows.

=head3 Parameters-IsWindows

None

=head3 Returns-IsWindows

Returns 1 if running on a Win-like operating system, including Linux.

=cut

#------------------------------------------------------------------------------
sub IsWindows ()
{
   return 1 if ($OS::OS[0] =~ /Windows/i);
   return 0;
}

#------------------------------------------------------------------------

=head2 Show()

Show ()

Displays operating system info in @OS::OS, as given by POSIX::uname(). Also displays the path separator charater in $OS::PS, e.g. '\' or '/'.

=head3 Parameters-Show

None

=cut

#------------------------------------------------------------------------------
sub Show ()
{
   $Msg->info("Operating System Info:
   \$sysname   = $OS[0]
   \$nodename  = $OS[1]
   \$release   = $OS[2]
   \$version   = $OS[3]
   \$machine   = $OS[4]
   Path Separator = [$PS]\n\n");
}

#------------------------------------------------------------------------------

# Return package load success.
1;
