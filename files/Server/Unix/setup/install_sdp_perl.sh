#!/bin/bash
declare Version=1.0.4

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
# Declarations and Environment

# Allow override of P4U_HOME, which is set only when testing P4U scripts.
export P4CBIN=${P4CBIN:-/p4/common/bin}
export P4U_HOME=${P4U_HOME:-/p4/common/bin}
export P4U_LIB=${P4U_LIB:-/p4/common/lib}
export P4U_ENV=$P4U_LIB/p4u_env.sh
export P4U_LOG="/p4/1/tmp/install_sdp_perl.sh.$(date +'%Y%m%d-%H%M%S').log"
export VERBOSITY=${VERBOSITY:-3}

# Environment isolation.  For stability and security reasons, prepend
# PATH to include dirs where known-good scripts exist.
# known/tested PATH and, by implication, executables on the PATH.
export PATH=$P4U_HOME:$PATH:~/bin:/usr/local/bin:$PATH
export P4CONFIG=${P4CONFIG:-.p4config}

[[ -r "$P4U_ENV" ]] || {
   echo -e "\nError: Cannot load environment from: $P4U_ENV\n\n"
   exit 1
}

source $P4U_ENV
source $P4U_LIB/libcore.sh
source $P4U_LIB/libp4u.sh

declare -i SilentMode=0

#==============================================================================
# Local Functions

#------------------------------------------------------------------------------
# Function: terminate
function terminate
{
   # Disable signal trapping.
   trap - EXIT SIGINT SIGTERM

   # Don't litter.
   cleanTrash

   vvmsg "$THISSCRIPT: EXITCODE: $OverallReturnStatus"

   # Stop logging.
   [[ "${P4U_LOG}" == off ]] || stoplog

   # With the trap removed, exit.
   exit $OverallReturnStatus
}

#------------------------------------------------------------------------------
# Function: usage (required function)
#
# Input:
# $1 - style, either -h (for short form) or -man (for man-page like format).
#------------------------------------------------------------------------------
function usage
{
   declare style=${1:--h}

   echo "USAGE for $THISSCRIPT v$Version:

$THISSCRIPT [-R rel] [-P perl_rel] [-r perl_root] [-f] [-d downloads_dir] [-w work_dir] [-L <log>] [-si] [-v<n>] [-n] [-D]

or

$THISSCRIPT [-h|-man]
"
   if [[ $style == -man ]]; then
      echo -e "
DESCRIPTION:
	This builds installs ActivePerl, the Perforce API, and
	P4Perl to the standard SDP location.

PLATFORM SUPPORT:
	This works on Red Hat Linux and CentOS platforms.  It works on
	CentOS 6.4 and 6.5 and likely on other Linux derivatives
	with no modification.

	It currently supports only the bin.linux26_64 (Linux) and
	bin.darwin90x86_64 (Mac OSX/Darwin) architectures.

REQUIREMENTS:
	The Perforce Server Deployment Packge (Rev SDP/Unix/2014.3+)
	must be installed and configured.  In particular the SDP
	Environment file [$SDPEnvFile] must define
	a value for OSUSER.

	Development utilities such as 'make' and the 'gcc' compiler
	must be installed and available in the PATH.

	The 'wget' utility must be installed and available in the
	PATH.  (Note that 'wget' is not installed with OSX by
	default, at least not os of OSX 10.9/Mavericks.  However,
	it can be acquired and compiled using XCode).

OPTIONS:
 -R rel
	Specify the Perforce release, e.g. r14.2.  The default is r14.1.
	This is used for both the Perforce API and P4Perl.

 -P perl_rel
	Specify the ActivePerl release, e.g. 5.16.3.1604  The default
	is 5.16.3.1604.

 -r perl_root
	Specify the python root.  The default is
	$PerlRoot

	This can be used doing a dry run of an an installation.
	It should not be used for a production install, since the SDP
	environment file, /p4/common/bin/p4_vars, defines the default
	Perl root in the PATH.

 -f 	Specify -f (force) to re-install the SDP pythin if it is
	already installed.  By default, in will be installed only
	if the Perl root dir (see -r) does not exist.

 -w work_dir
	Specify the working dir.  By default, a temporary working directory
	is created under $Tmp, with a random name.  This temporary working
	directory can be removed upon successful completion.

 -d downloads_dir
	Specify a directory to use to find downloads.
	
	The default is: $DownloadsDir

	The downloads directory is checked for these needed tarfiles:
	$PerlTarFile
	$P4APITarFile
	$P4PerlTarFile

 -v<n>	Set verbosity 1-5 (-v1 = quiet, -v5 = highest).

 -L <log>
	Specify the path to a log file, or the special value 'off' to disable
	logging.  By default, all output (stdout and stderr) goes to:
	$(dirname ${P4U_LOG}).

	NOTE: This script is self-logging.  That is, output displayed on the screen
	is simultaneously captured in the log file.  Do not run this script with
	redirection operators like '> log' or '2>&1', and do not use 'tee.'

 -si	Operate silently.  All output (stdout and stderr) is redirected to the log
	only; no output appears on the terminal.  This cannot be used with
	'-L off'.
      
 -n	No-Op.  Prints commands instead of running them.

 -D     Set extreme debugging verbosity.

HELP OPTIONS:
 -h	Display short help message
 -man	Display man-style help message

FILES:

EXAMPLES:

SEE ALSO:
"
   fi

   exit 1
}

#==============================================================================
# Command Line Processing

declare -i shiftArgs=0
declare -i Force=0
#declare -i KeepWorkingDir=0
declare -i KeepWorkingDir=1
declare PerlRoot=/p4/common/perl
declare Tmp=${P4TMP:-/p4/1/tmp}
declare WorkingDir=$Tmp/isp.$$.$RANDOM
declare DownloadsDir=$Tmp/downloads/p4perl
declare BuildDir=
declare APIDir=
declare ApiArch=
declare RunUser=
declare RunArch=x86_64
declare PerforceRel=r14.1
declare PerlRel=5.18.4.1804
declare GLibcVer=glibc-2.5-298913
declare PerlTarFile=ActivePerl-${PerlRel}-${RunArch}-linux-${GLibcVer}.tar.gz
declare P4APITarFile=p4api.tgz
declare P4PerlTarFile=p4perl.tgz
declare SDPEnvFile=/p4/common/bin/p4_vars
declare ThisArch=
declare ThisOS=

set +u
while [[ $# -gt 0 ]]; do
   case $1 in
      (-R) PerforceRel=$2; shiftArgs=1;;
      (-R) PerlRel=$2; shiftArgs=1;;
      (-r) PerlRoot=$2; shiftArgs=1;;
      (-f) Force=1;;
      (-w)
         if [[ ${2^^} == KEEP ]]; then
            KeepWorkingDir=1
         else
            WorkingDir=$2
            KeepWorkingDir=1
         fi
      ;;
      (-d) DownloadsDir=$2; shiftArgs=1;;
      (-h) usage -h;;
      (-man) usage -man;;
      (-v1) export VERBOSITY=1;;
      (-v2) export VERBOSITY=2;;
      (-v3) export VERBOSITY=3;;
      (-v4) export VERBOSITY=4;;
      (-v5) export VERBOSITY=5;;
      (-L) export P4U_LOG=$2; shiftArgs=1;;
      (-si) SilentMode=1;;
      (-n) export NO_OP=1;;
      (-D) set -x;; # Debug; use 'set -x' mode.
      (*) usageError "Unknown arg ($1).";;
   esac

   # Shift (modify $#) the appropriate number of times.
   shift; while [[ $shiftArgs -gt 0 ]]; do
      [[ $# -eq 0 ]] && usageError "Bad usage."
      shiftArgs=$shiftArgs-1
      shift
   done
done
set -u

[[ $KeepWorkingDir -eq 0 ]] && GARBAGE+="$WorkingDir"

#==============================================================================
# Command Line Verification

[[ $SilentMode -eq 1 && $P4U_LOG == off ]] && \
   usageError "Cannot use '-si' with '-L off'."

#==============================================================================
# Main Program

trap terminate EXIT SIGINT SIGTERM

declare -i OverallReturnStatus=0

[[ ! -d $Tmp ]] && bail "Missing SDP tmp dir [$Tmp]. Aborting."

if [[ "${P4U_LOG}" != off ]]; then
   touch ${P4U_LOG} || bail "Couldn't touch log file [${P4U_LOG}]."

   # Redirect stdout and stderr to a log file.
   if [[ $SilentMode -eq 0 ]]; then
      exec > >(tee ${P4U_LOG})
      exec 2>&1
   else
      exec >${P4U_LOG}
      exec 2>&1
   fi

   initlog
fi

if [[ ! -r "$SDPEnvFile" ]]; then
   bail "Missing or unreadable SDP Environment File [$SDPEnvFile].  Aborting."
fi

RunUser=$(grep '^export OSUSER=' /p4/common/bin/p4_vars |\
   tail -1 | cut -d '=' -f 2)
RunUser=$(echo $RunUser)

if [[ -n "$RunUser" ]]; then
   msg "The OSUSER defined in the SDP environment file is $RunUser."
else
   bail "Could not detect OSUSER in SDP environment file [$SDPEnvFile]. Aborting."
fi

if [[ $USER == $RunUser ]]; then
   msg "Verified:  Running as $USER."
else
   bail "Running as $USER.  Run this only as the OSUSER [$RunUser] defined in the SDP Environment File [$SDPEnvFile]. Aborting."
fi

msg "Starting $THISSCRIPT v$Version at $(date) with command line:\n\t$CMDLINE\n\n"

msg "Verifying dependencies."

[[ -z "$(which gcc 2>/dev/null)" || -z "$(which g++ 2>/dev/null)" ]] && \
   bail "No gcc found in the path.  You may need to install it.  Please\n check that the gcc.x86_64 and gcc-c++.x86_64 packages are\n installed, e.g. with:\n\tyum install -y gcc.x86_64 gcc-c++.x86_64\n\n"

[[ -z "$(which wget 2>/dev/null)" ]] && \
   bail "No wget found in the path.  You may need to install it.  Please check that the wget.x86_64 packages is installed, e.g. with:\n\tyum install -y wget.x86_64\n\n"

ThisArch=$(uname -m)

if [[ $ThisArch == $RunArch ]]; then
   msg "Verified:  Running on a supported architecture [$ThisArch]."
   ThisOS=$(uname -s)
   ApiArch=UNDEFINED_API_ARCH
   case $ThisOS in
      (Darwin) ApiArch="darwin90x86_64";;
      (Linux) ApiArch="linux26x86_64";;
      (*) bail "Unsupported value returned by 'uname -m': $ThisOS. Aborting.";;
   esac
else
   bail "Running on architecture $ThisArch.  Run this only on hosts with '$RunArch' architecture. Aborting."
fi

if [[ -d $PerlRoot ]]; then
   if [[ $Force -eq 0 ]]; then
      bail "The SDP Perl root directory exists: [$PerlRoot]. Aborting."
   else
      runCmd "/bin/rm -rf $PerlRoot" || bail "Could not remove SDP Perl root dir [$PerlRoot]. Aborting."
   fi
fi

if [[ ! -d $WorkingDir ]]; then
   runCmd "/bin/mkdir -p $WorkingDir" || bail "Could not create working dir [$WorkingDir]."
fi

if [[ ! -d $DownloadsDir ]]; then
   runCmd "/bin/mkdir -p $DownloadsDir" || bail "Could not create downloads dir [$DownloadsDir]."
fi

cd "$DownloadsDir" || bail "Could not cd to [$DownloadsDir]."

msg "Downloading dependencies to $DownloadsDir."

if [[ ! -r $PerlTarFile ]]; then
   runCmd "wget -q --no-check-certificate http://downloads.activestate.com/ActivePerl/releases/$PerlRel/$PerlTarFile" ||\
      bail "Could not get $PerlTarFile."
else
   msg "Skipping download of existing $PerlTarFile file."
fi

if [[ ! -r $P4APITarFile ]]; then
   runCmd "wget -q ftp://ftp.perforce.com/perforce/$PerforceRel/bin.$ApiArch/$P4APITarFile" ||\
      bail "Could not get file '$P4APITarFile' $Rel"
else
   msg "Skipping download of existing $P4APITarFile file."
fi

if [[ ! -r $P4PerlTarFile ]]; then
   runCmd "wget -q ftp://ftp.perforce.com/perforce/$PerforceRel/bin.tools/$P4PerlTarFile" ||\
      bail "Could not get file '$P4PerlTarFile'"
else
   msg "Skipping download of existing $P4PerlTarFile."
fi

cd "$WorkingDir" || bail "Could not cd to working dir [$WorkingDir]."

BuildDir=$(tar -tzf $DownloadsDir/$PerlTarFile|head -1|cut -d '/' -f1)

runCmd "tar -xzpf $DownloadsDir/$PerlTarFile"

cd "$BuildDir" || bail "Could not cd to build dir [$BuildDir]."

echo -e "yes\nyes\n" > tmp.input.txt

./install.sh --license-accepted --prefix=$PerlRoot < tmp.input.txt ||\
   bail "Failed to install ActivePerl."

export PATH=$PerlRoot/site/bin:$PerlRoot/bin:$PATH

cd "$WorkingDir" || bail "Could not cd to working dir [$WorkingDir]."

APIDir=$PWD/$(tar -tf $DownloadsDir/$P4APITarFile|head -1|cut -d '/' -f1)
runCmd "tar -xzpf $DownloadsDir/$P4APITarFile"

BuildDir=$(tar -tzf $DownloadsDir/$P4PerlTarFile|head -1|cut -d '/' -f1)

runCmd "tar -xzpf $DownloadsDir/$P4PerlTarFile"

cd "$BuildDir" || bail "Could not cd to build dir [$BuildDir]."

echo "Building P4Perl, logging to $PWD/build.log"

runCmd "perl Makefile.PL -apidir=$APIDir < /dev/null" \
   "Generating Makefile for building P4Perl." ||\
   bail "Failed to generate Makefile for P4Perl."

runCmd "make install" "Building and installing P4Perl." ||\
   bail "Failed to build P4Perl."

msg "Add this to your PATH:  $PerlRoot/site/bin:$PerlRoot/bin"
msg "Add this to your MANPATH:  $PerlRoot/site/man:$PerlRoot/man"

if [[ $OverallReturnStatus -eq 0 ]]; then
   msg "${H}\nSuccess.  P4Perl is ready.\n"
else
   msg "${H}\nProcessing completed, but with errors.  Scan above output carefully.\n" 
fi

# Illustrate using $SECONDS to display runtime of a script.
msg "That took about $(($SECONDS/3600)) hours $(($SECONDS%3600/60)) minutes $(($SECONDS%60)) seconds.\n"

# See the terminate() function, which is really where this script exits.
exit $OverallReturnStatus
