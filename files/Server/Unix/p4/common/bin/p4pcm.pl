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

# For a summary of command line options, run:  p4pcm.pl -h

# This runs on Unix/Linux systems only.
# Log file is p4pcm.log

use strict;
use File::Find;
use File::Basename;
use Getopt::Long;
use POSIX;

#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------
BEGIN
{
    $main::ThisScript = basename($0);
}

#------------------------------------------------------------------------------
# Prototypes for local functions.
#------------------------------------------------------------------------------
sub usage();
sub getDriveSpace($;);

#------------------------------------------------------------------------------
# Declarations
#------------------------------------------------------------------------------
#  $freespace is less than $threshhold1, then start deleting files.
#  $threshhold2 is the amount of diskspace we want available/free constantly.
my $acctime;
my $rmfile;
my $topdir;
my $threshold1 = 10737418240; # 10GB
my $threshold2 = 21474836480; # 20GB
my $totalsize;
my $freespace;
my $timestamp;
my $datestamp;
my @rmlist;
my @date_sorted;
my %oldest;

#------------------------------------------------------------------------------
# Parse command line.
#------------------------------------------------------------------------------
Getopt::Long::config "no_ignore_case";
Getopt::Long::config "auto_abbrev";

GetOptions(\%main::CmdLine, "help", "noop", "dir=s", "tlow=s", "thigh=s")
   or die "\nUsage Error:  Unrecognized argument.\n";

# Validate command line arguments.
usage() if $main::CmdLine{'help'};

# The '-d <topdir>' argument is required.
usage() unless ($main::CmdLine{'dir'});

$topdir = $main::CmdLine{'dir'};

$datestamp = strftime("\%Y-\%m-\%d",localtime);
$threshold1 = $main::CmdLine{'tlow'} if ($main::CmdLine{'tlow'});
$threshold2 = $main::CmdLine{'thigh'} if ($main::CmdLine{'thigh'});

#------------------------------------------------------------------------------
# Main Program.
#------------------------------------------------------------------------------
$timestamp = strftime("\%H:\%M:\%S",localtime);
my ($name, $dir, $ext) = fileparse($0, '\..*');
my $logfile = "$name.log";
open (LOG, ">>$logfile");
print "Log file is: $logfile\n";
print LOG "$datestamp ============= $timestamp ================\n";

# Check if $topdir exists and that it's a directory.
if (-e $topdir && -d $topdir) {
        # Find the total amount of free space in $topdir.
        ($totalsize, $freespace) = getDriveSpace($topdir);
        print LOG "$datestamp Free Space = $freespace\n";
        #  compare $freespace to $threshold1
        if ( $freespace < $threshold1 ) {
               #  while $freespace is less than $threshold2
               #  Find oldest file based on "Date Modified"
               find (sub {$oldest{$File::Find::name} = -M if -f;}, $topdir);
               @date_sorted = sort {(stat($a))[9] <=> (stat($b))[9] } 
keys %oldest;
               while ( $freespace < $threshold2 ) {
                      $rmfile = shift @date_sorted;
                      last unless ($rmfile);
                      $freespace += (stat($rmfile))[7];
                      push(@rmlist, $rmfile);
               }
               #  if @rmlist exists, delete it + log
               if ( @rmlist ) {
                      #  record the files that will be deleted
                      print LOG "$datestamp File \t Size \t Accessed\n";
                      foreach $rmfile ( @rmlist ) {
                            $acctime = (stat($rmfile))[9];
                            print LOG "$datestamp $rmfile \t " . 
(stat($rmfile))[7] . "\t" . scalar(localtime($acctime)) . "\n";
                      }
                      # Delete files to free space.
                      if ($main::CmdLine{'noop'})
                      {
                         print LOG "NO-OP: $datestamp @rmlist would have been deleted\n";
                      } else
                      {
                         print LOG "$datestamp Files deleted:\n@rmlist\n\n";
                         unlink @rmlist or print LOG "$datestamp ERROR: 
                         Files not deleted:\n@rmlist\n";
                      }
               }
        } else {
               #  log: theres enough free space in $topdir until next time
               print LOG "$datestamp No files need to be deleted\n";
        }
}

#  Stop logging.
$timestamp = strftime("\%H:\%M:\%S",localtime);
print LOG "$datestamp ============= $timestamp ================\n";
close(LOG);

#------------------------------------------------------------------------------
# Function: usage()
# Displays usage message.
#------------------------------------------------------------------------------
sub usage ()
{
   print "\nUsage:\n
   $main::ThisScript -d \"proxy cache dir\" [-tlow <low_threshold>] [-thigh <high_threshold>] [-n]
or
   $main::ThisScript -h

This utility removes files in the proxy cache if the amount
of free disk space falls below the low threshold (default 10GB).
It removes files (oldest first) until the high threshold is
(default 20GB) is reached.

The '-d \"proxy cache dir\"' argument is required.

Use '-n' to show what files would be removed.
";
   exit  1;;
}

#------------------------------------------------------------------------------
# Function getDriveSpace($topdir)
# Returns a 2-element array containing $totalspace and $freespace, i.e.
#    returns ($totalspace, $freespace).
#------------------------------------------------------------------------------
sub getDriveSpace($;)
{
   my ($topdir) = @_;
   my $totalSpace;
   my $freeSpace;
   my $dirInfo;
   my $junk;

   # Run 'df -k $topdir', and extract the total and available space values,
   # using $junk to ignore extranneous information.
   $dirInfo = `df -k $topdir`;
   $dirInfo =~ s/^.*?\n//; # Zap the header line.
   $dirInfo =~ s/\s+/,/gs; # Replace whitespace with comma as field delimiter.
   ($junk, $totalSpace, $junk, $freeSpace, $junk, $junk) = split (',',$dirInfo);
   return ($totalSpace, $freeSpace);
}
