package Misc;

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

Misc.pm - Module with miscellaneous utilities.

=head1 VERSION

2.6.0

=head1 DESCRIPTION

This utility modules includes some basic utilities for formatting dates/time stamps, generating unique temporary filenames, calculated future and past dates, etc.

=head1 PUBLIC DATA

=head1 PUBLIC FUNCTIONS

Public funtions are exported and can be called without explicit namespacing.

=cut

require Exporter;

use strict;
use Time::Local;
use File::Temp;
use POSIX qw(uname);
use Msg;

# The next line avoids problems with 'use strict'.
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# Initialization processing occurs in the BEGIN block.
BEGIN
{
   # Keep $VERSION value the same as at the top of this file.
   $VERSION = "2.6.0";
}

# Package interface standards.  By default, any export can be blocked.
@ISA = qw(Exporter);
@EXPORT = qw(
   CheckEnv
   CleanDir
   GenTempFilename
   CalculateDate
   FormattedTimestamp
);

# Prototypes for public functions.
sub CheckEnv();
sub CleanDir($$$;$);
sub GenTempFilename();
sub CalculateDate($;$);
sub FormattedTimestamp(;$);

#==============================================================================
# Internal Functions
#==============================================================================

#==============================================================================
# Public Functions
#==============================================================================

#------------------------------------------------------------------------------

=head2 CheckEnv()

CheckEnv () returns 1 if neede environment vars are defined, or 0 otherwise.

=head3 Description-CheckEnv

This checks that key system environment variables are set.

=head4 User Environment Checks

Checks that the following are set:

=over 4

=item *

C<P4U_HOME>

=back

=head3 Parameters-CheckEnv

None

=head3 Returns-CheckEnv

Returns 1 if the environment is OK, 0 or otherwise.

=head3 Examples-CheckEnv

A sample check for admin environment might look like:

C<Misc::CheckEnv() or $Msg->logdie("\nError: Environment check failed!\n");>

=cut

#------------------------------------------------------------------------------
sub CheckEnv ()
{
   my $envOK = 1;

   $Msg->info("Performing environment checks.");

   foreach ("P4U_HOME")
   {
      if ($ENV{$_} eq "")
      {
         $Msg->warn("Error:  The $_ environment variable is not set!");
         $envOK = 0;
      }
   }

   return $envOK;
}

#------------------------------------------------------------------------------

=head2 GenTempFilename()

GenTempFilename ()

=head3 Description-GenTempFilename

This replaces POSIX::tmpnam(), which generates temp filenames at the root of the directory tree on Windows.  This is not compatible with Windows Vista, which restricts access to the root directory.

This implementation uses POSIX::tmpnam() to generate a unique pathname, but prepends the directory specified by the %TEMP% environment variable.

This behavior applies only when run on Windows.  When run on Unix, this simply returns the value returned by POSIX::tmpnam().

=head3 Parameters-GenTempFilename

None.

=head3 Parameters-ToDo

=head3 Returns-GenTempFilename

Returns a string to a unqiue filename, suitable for using as a temporary working file.

=head3 Examples-GenTempFilename

Typical Example:

C<my $TmpFile = Misc::GenTempFilename();>

=cut

#------------------------------------------------------------------------------
sub GenTempFilename ()
{
   my $tempFilename;

   # For Windows, use the %TEMP% dir.
   if (OS::IsWindows())
   {
      $tempFilename = $ENV{TEMP} . POSIX::tmpnam() . "txt";
   } else
   {
      $tempFilename = POSIX::tmpnam();
   }

   return $tempFilename;
}

#------------------------------------------------------------------------------

=head2 CalculateDate()

CalculateDate($I<daysBack>; $I<startDate>) returns $I<theDateBackThen>

=head3 Description-CalculateDate

Return the calendar date of a day n days back.

=head3 Parameters-CalculateDate

$I<daysBack> - the number of days back to count.  Note that a negative number can be supplied to count forward.

$I<startDate> - I<Optional> - Specify the date to start counting back from, in YYYY/MM/DD format.  The default is to count back from the current date.

=head3 Returns-CalculateDate

A string containing the date I<n> days back, in YYYY/MM/DD format.

=head3 Examples-CalculateDate

=head4 Example 1

To set a date string 45 days back from today:

C<$DateString = CalculateDate (45);>

=head4 Example 2

To set a date string 7 days forward from a particular date, say 2006/03/05:

C<$DateString = Misc::CalculateDate (-7, "2006/03/05");>

=cut

#------------------------------------------------------------------------------
sub CalculateDate ($;$)
{
   my ($daysBack, $startDate) = @_;

   # The date back then.
   my $theDateBackThen; my $theTimeBackThen;
   #                 Jan  Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
   my @daysInMonth = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

   my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);

   # Adjust forward-calcluations.
   if ($daysBack < 0) { $daysBack--; }

   # Normalize values returned from localtim().
   $year += 1900; $mon += 1;

   # Leap Years are years evenly divisible, except centurial years that are
   # not evenly divisible by 400.  So 1700, 1800, 1900 and 2100 are not leap
   # years, but 1600, 2000, and 2400 are.
   # If Leap Year, 29 days in Feb.
   if ($year % 4)
   {
      # Unless it's a centurial year not divisible by 400, it's a leap year.
      $daysInMonth[1] = 29 unless ((($year % 100) == 0) and ($year % 400));
   }

   # If a start date was specified, override the values for $year, $mon,
   # and $mday.
   if ($startDate)
   {
      my $i;
      $year = $startDate;
      $year =~ s/\/.*$//;
      $mon = $startDate;
      $mon =~ s/^.*?\///;
      $mon =~ s/\/.*$//;
      $mon =~ s/^0//;
      $mday = $startDate;
      $mday =~ s/^.*\///;
      $mday =~ s/^0//;
      $yday = 0;
      $mon -= 1;

      for ($i = 0; $i < $mon; $i++) { $yday += $daysInMonth[$mon-1]; }

      $yday += $mday;
      if ($daysBack > 0) { $yday++; }
      if ($daysBack < 0) { $yday--; }
   }

   while ($daysBack > $yday)
   {
      $daysBack -= 364;  # Close enuff.
      $year -= 1;
   }

   $yday -= $daysBack;

   $theTimeBackThen = Time::Local::timelocal_nocheck( 0,0,0,$yday,0,$year-1900);
   ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
   localtime($theTimeBackThen);
   $year += 1900; $mon += 1;

   $theDateBackThen = sprintf ("%04d/%02d/%02d", $year, $mon, $mday);

   return $theDateBackThen;
}

#------------------------------------------------------------------------------

=head2 FormattedTimestamp()

FormattedTimestamp(;$I<format>) returns $I<timestamp>

=head3 Description-FormattedTimestamp

Return a date/time stamp in a variety of useful formats.

=head3 Parameters-FormattedTimestamp

$I<format> - Optional format argument, either 'D', 'N', or 'L':

=over 4

=item D

Default format; more-readable than numeric.  Example: B<2001Oct02-142259>

=item N

Numeric, scalar-comparisons possible.  Example: B<20011002-142259>

=item L

Long-winded, but nice.  Example: B<Tue, 2 Oct 2001, 14:22:59>

=back

=head3 Returns-FormattedTimestamp

TimeStamp string

=head3 Examples-FormattedTimestamp

To get the timestamp in long format:

C<$Timestamp = FormattedTimestamp ("L");>

=cut

#------------------------------------------------------------------------------
sub FormattedTimestamp (;$)
{
   my ($format) = @_;
   if (! @_) { $format=""; }

   my $buf = "";
   my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
      "Sep", "Oct", "Nov", "Dec");
   my @wdays = ("Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat", "Sun");

   my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
   localtime(time);

   $year+=1900; $mon += 1;

   if ($format eq "" || $format eq "D")
   {
      $buf = sprintf("%04d%3s%02d-%02d%02d%02d" ,$year, $months[$mon-1], $mday, $hour, $min, $sec);
   } elsif ($format eq "N")
   {
      $buf = sprintf("%04d%02d%02d-%02d%02d%02d", $year, $mon, $mday, $hour, $min, $sec);
   }
   else
   {
      $buf = sprintf("%s, %d %3s %04d, %02d:%02d:%02d", $wdays[$wday], $mday, $months[$mon-1], $year, $hour, $min, $sec);
   }

   return $buf;
}

# Return package load success.
1;
