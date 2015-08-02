#!/bin/bash
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
# Declarations and Environment

# Allow override of P4U_HOME, which is set only when testing P4U scripts.
export P4U_HOME=${P4U_HOME:-/p4/common/bin}
export P4U_LIB=${P4U_LIB:-/p4/common/lib}
export P4U_ENV=$P4U_LIB/p4u_env.sh
export P4U_LOG="/tmp/template.sh.$(date +'%Y%m%d-%H%M%S').log"
export VERBOSITY=${VERBOSITY:-3}

# Environment isolation.  For stability and security reasons, prepend
# PATH to include dirs where known-good scripts exist.
# known/tested PATH and, by implication, executables on the PATH.
export PATH=$P4U_HOME:$PATH:~/bin:.
export P4CONFIG=${P4CONFIG:-.p4config}

[[ -r "$P4U_ENV" ]] || {
   echo -e "\nError: Cannot load environment from: $P4U_ENV\n\n"
   exit 1
}

declare BASH_LIBS=$P4U_ENV
BASH_LIBS+=" $P4U_LIB/libcore.sh"
BASH_LIBS+=" $P4U_LIB/libp4u.sh"

for bash_lib in $BASH_LIBS; do
   source $bash_lib
done


. $P4U_ENV
. $P4U_LIB/libcore.sh
. $P4U_LIB/libp4u.sh

declare Version=1.0.0
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

$THISSCRIPT EDITME <required> literal [-optional] [-L <log>] [-si] [-v<n>] [-n] [-D]

or

$THISSCRIPT [-h|-man|-V]
"
   if [[ $style == -man ]]; then
      echo -e "
DESCRIPTION: EDITME

OPTIONS:
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
      
	EDITME: This is useful when running from cron, as it prevents automatic
	email from being sent by cron directly, as it does when a script called
	from cron generates any output.  This script is then responsible for
	email handling, if any is to be done.

 -n	No-Op.  Prints commands instead of running them.

 -D     Set extreme debugging verbosity.

HELP OPTIONS:
 -h	Display short help message
 -man	Display man-style help message
 -V	Dispay version info for this script and its libraries.

FILES:

EXAMPLES:

SEE ALSO:
"
   fi

   exit 1
}

#==============================================================================
# Command Line Processing

declare SampleArgument=""; ### EDITME
declare -i shiftArgs=0

set +u
while [[ $# -gt 0 ]]; do
   case $1 in
      (-s) SampleArgument=$2; shiftArgs=1;; ### EDITME
      (-h) usage -h;;
      (-man) usage -man;;
      (-V) show_versions; exit 1;;
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

#==============================================================================
# Command Line Verification

[[ $SilentMode -eq 1 && $P4U_LOG == off ]] && \
   usageError "Cannot use '-si' with '-L off'."

#==============================================================================
# Main Program

trap terminate EXIT SIGINT SIGTERM

declare -i OverallReturnStatus=0

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

runCmd "ls /tmp/xxx" "List."

echo "foo"
echo "bar" >&2

runCmd "ls" "Sample Arg is [$SampleArgument].  Directory List:" 1 1

runCmd "/bin/sleep 1" "Taking a short nap." 1 0

# Illustrate stringing together a series of commands using a '|'.
# runCmd can handle this.
runCmd "ls -lrt|grep \"Dec 16\"|head -2|tail -1" "Showing last file:" 1 1

warnmsg "Sample WarningMsg 1"
errmsg "Sample Error Message 2"
warnmsg "Sample WarningMsg 3"
errmsg "Sample Error Message 4"

runRemoteCmd scm02 "sleep 4\nls -lrt /tmp/" 0 1

if [[ $OverallReturnStatus -eq 0 ]]; then
   msg "${H}\nAll processing completed successfully.\n"
else
   msg "${H}\nProcessing completed, but with errors.  Scan above output carefully.\n" 
fi

# Illustrate using $SECONDS to display runtime of a script.
msg "That took about $(($SECONDS/3600)) hours $(($SECONDS%3600/60)) minutes $(($SECONDS%60)) seconds.\n"

# See the terminate() function, which is really where this script exits.
exit $OverallReturnStatus
