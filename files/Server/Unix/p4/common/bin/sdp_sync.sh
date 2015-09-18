#!/bin/bash
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
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 

. /p4/common/bin/p4_vars $SDP_INSTANCE
. /p4/common/bin/backup_functions.sh

export P4U_ENV=$P4CLIB/p4u_env.sh
export P4U_LOG=unset
export VERBOSITY=${VERBOSITY:-3}

# Environment isolation.  For stability and security reasons, prepend
# PATH to include dirs where known-good scripts exist.
# known/tested PATH and, by implication, executables on the PATH.
export PATH=$P4CBIN:$PATH:~/bin:.
export P4CONFIG=${P4CONFIG:-.p4config}

[[ -r "$P4U_ENV" ]] || {
   echo -e "\nError: Cannot load environment from: $P4U_ENV\n\n"
   exit 1
}

declare Version=1.1.1
declare CfgFile=$P4CBIN/sdp-sync.cfg
declare HostList=
declare -i EmailAlways=0
declare -i EmailOnFailure=0
declare -i RemoveOldLogs=0
declare -i SilentMode=0

source $P4U_ENV
source $P4CLIB/libcore.sh
source $P4CLIB/libp4u.sh

#==============================================================================
# Local Functions

#------------------------------------------------------------------------------
# Function: terminate
function terminate
{
   # Disable signal trapping.
   trap - EXIT SIGINT SIGTERM

   declare -i sendEmail=0

   # Don't litter.
   cleanTrash

   vvmsg "$THISSCRIPT: EXITCODE: $OverallReturnStatus"

   # Stop logging.
   if [[ "${P4U_LOG}" != off ]]; then
      stoplog

      # Email.
      [[ $EmailAlways -eq 1 ]] && sendEmail=1
      [[ $EmailOnFailure -eq 1 && $OverallReturnStatus -ne 0 ]] && sendEmail=1

      if [[ $sendEmail -eq 1 ]]; then
         emailStatus="OK"
         [[ $OverallReturnStatus -ne 0 ]] && emailStatus="Error"

         local mail_sender_opt=$(get_mail_sender_opt)
         runCmd "$SDPMAIL -s \"${HOSTNAME%%\.*} p4_$SDP_INSTANCE sdp_sync [$emailStatus]\" \$mail_sender_opt \$MAILTO < $P4U_LOG"
      fi
   fi

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

$THISSCRIPT sdp_sync.sh [-h <host1>[,<host2>,...]] [-i <n>] [-r] [-e|-E] [-L <log>] [-si] [-v<n>] [-n|-N] [-D]

or

$THISSCRIPT [-h|-man]
"
   if [[ $style == -man ]]; then
      echo -e "
DESCRIPTION:
	This script keeps Perforce Server Deployment Package (SDP) scripts in
	sync on all SDP hosts, as defined by the SDP_HOSTS setting in the
	$P4CBIN/sdp_sync.cfg file.

	This script is intended to be called by a cron job the master server.
	It then does ssh calls to the remaining SDP hosts.

	Each target host is expect to have a P4CONFIG file named
	/p4/.p4config.SDP that defines Perforce environment settings that
	point to Perforce workspaces that enable versioning of the SDP on that
	host.  For pure read-only replicas, the P4PORT value in that P4CONFIG
	file must point to the master server.  Forwarding replicas and Edge
	Servers can point P4PORT to the master server or locally.

	The worskpaces must be configured for each host.  Typically they
	reference paths in the Perforce server that are common across
	all SDP servers, e.g. to populate the /p4/common/bin folder.
	Other paths are host-specific, like the /p4/<n>/bin folders
	that indicate which instances are active on the machine as well
	as which type of servers are active for each instance (p4d,
	p4p, p4broker, etc.).

	This depends on ssh keys being setup such that the Perforce login
	(as defined by OSUSER in $P4CBIN/p4_vars) can ssh without a password
	to all SDP  hosts.  (To simplify failover, the backup servers should
	also be able to ssh to each other without a password; security
	implications should be considered here.)

OPTIONS:
 -h <host1>[,<host2>,...]
	Specify a comma-delimited list of hosts to push to.  By default,
	the SDP_HOSTS value defined in the config file $CfgFile
	determines the list of hosts to push to.

 -i <n>
	Specify the SDP instance number (e.g 1 for /p4/1, to for /p4/2) for
	the SDP instance that contains the SDP. The default is to use
	the \$SDP_INSTANCE variable if defined, or else '1'.

 -r
	Specify this option to remove old sdp_sync.*.log files.  If this option
	is specified, log files named /p4/<n>/logs/sdp_sync.*.log (where '<n>'
	is the SDP instance number) that are older than the number of days
	indicated by the KEEPLOGS setting in $P4CBIN/p4_vars are removed.

	The old log removal occurs only upon successful completion.

 -e	Send email to MAILTO value defined in $P4CBIN/p4_vars in event
	of failure only.

 -E	Send email to MAILTO value defined in $P4CBIN/p4_vars.

 -v<n>	Set verbosity 1-5 (-v1 = quiet, -v5 = highest).

 -L <log>
	Specify the path to a log file, or the special value 'off' to disable
	logging.  By default, all output (stdout and stderr) goes to a log
	file named sdp_sync.<datestame>.log in $LOGS.

	NOTE: This script is self-logging.  That is, output displayed on the screen
	is simultaneously captured in the log file.  Do not run this script with
	redirection operators like '> log' or '2>&1', and do not use 'tee.'

-si	Operate silently.  All output (stdout and stderr) is redirected to the log
	only; no output appears on the terminal.  This cannot be used with
	'-L off'.
      
 -n	No-Op.  Prints commands instead of running them.

 -N	No-Op.  Similar to '-n', but this command does execute the 'ssh' calls to
	get to the remote host, but then does 'p4 sync -n' rather than' 'p4 sync'
	on the remote host.

 -D     Set extreme debugging verbosity.

HELP OPTIONS:
 -h	Display short help message
 -man	Display man-style help message

FILES:
	The SDP environment file $P4CBIN/p4_vars definse various
	SDP settings, and is used by several SDP scripts.

	The config file $CfgFile defines the SDP_HOSTS value.

EXAMPLES:
	Recommended crontab usage for SDP Instance 1:
	$P4CBIN/$THISSCRIPT -i 1 -si -r -e < /dev/null > /dev/null 2>&1

	The redirect to /dev/null is to avoid any output that
	would generate a duplicate email from cron.  Output is not lost;
	it is written to a timestampped log file:
	$P4HOME/logs/sdp_sync.<timestamp>.log

SEE ALSO:
"
   fi

   exit 1
}

#==============================================================================
# Command Line Processing

declare -i shiftArgs=0

set +u
while [[ $# -gt 0 ]]; do
   case $1 in
      (-i) export SDP_INSTANCE=$2; shiftArgs=1;;
      (-h) HostList=$2; shiftArgs=1;;
      (-r) RemoveOldLogs=1;;
      (-e) EmailOnFailure=1;;
      (-E) EmailAlways=1;;
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
      (-N) export NO_OP=2;;
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

source $P4CBIN/p4_vars $SDP_INSTANCE
source $P4CBIN/sdp_sync.cfg
[[ $P4U_LOG == unset ]] && export P4U_LOG="${LOGS}/sdp_sync.$(date +'%Y%m%d-%H%M%S').log"

set -u

#==============================================================================
# Command Line Verification

[[ $SilentMode -eq 1 && $P4U_LOG == off ]] && \
   usageError "Cannot use '-si' with '-L off'."

[[ $EmailOnFailure -eq 1 && $P4U_LOG == off ]] && \
   usageError "Cannot use '-e' or '-E' with '-L off'."

[[ $EmailAlways -eq 1 && $EmailOnFailure -eq 1 ]] && \
   usageError "The '-e' and '-E' flags are mutually exclusive."

# If '-h <host1>[,<host2>,...]' was specified as a comma-separated list
# on the command line, overide the SDP_HOSTS value defined in
# the config file.
[[ -n "$HostList" ]] && export SDP_HOSTS="$(echo $HostList|tr ',' ' ')"

#==============================================================================
# Main Program

trap terminate EXIT SIGINT SIGTERM

get_mail_sender_opt

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

[[ -z "$SDP_HOSTS" ]] && bail "The SDP_HOSTS variable is not defined in $CfgFile.  Aborting."

# Just in case commas were used instead of spaces in the config file, translate them
# to spaces here.
for host in $(echo $SDP_HOSTS|tr ',' ' '); do
   if [[ $NO_OP -eq 0 || $NO_OP -eq 1 ]]; then
      runRemoteCmd $host "export P4CONFIG=/p4/.p4config.SDP\n$P4BIN set\n$P4BIN -s info -s\np4 -s sync\n" "Syncing SDP workspace on $host." 1 1 || OverallReturnStatus=1
   else
      runRemoteCmd $host "export P4CONFIG=/p4/.p4config.SDP\nexport P4ENVIRO=/tmp/tmp.p4enviro.$$.$RANDOM\n$P4BIN set\n$P4BIN -s info -s\np4 -s sync -n\n" "Checking to see if files need to be sync'd on host $host." 0 1 || OverallReturnStatus=1
   fi
done

if [[ $OverallReturnStatus -eq 0 ]]; then
   msg "${H}\nAll processing completed successfully.\n"

   if [[ $RemoveOldLogs -eq 1 ]]; then
      if [[ $NO_OP -eq 0 ]]; then
         msg "Cleanup: Removing $P4HOME/logs/sdp_sync.*.log files older than $KEEPLOGS days old (if any):"
         /bin/find $P4HOME/logs/ -name "sdp_sync.*.log" -mtime +$KEEPLOGS -print -exec /bin/rm -f {} \;
      else
         msg "NO_OP: Would remove $P4HOME/logs/sdp_sync.*.log files older than $KEEPLOGS days old (if any):"
         /bin/find $P4HOME/logs/ -name "sdp_sync.*.log" -mtime +$KEEPLOGS -print
      fi
   fi
else
   msg "${H}\nProcessing completed, but with errors.  Scan above output carefully.\n" 
fi

# Illustrate using $SECONDS to display runtime of a script.
msg "That took about $(($SECONDS/3600)) hours $(($SECONDS%3600/60)) minutes $(($SECONDS%60)) seconds.\n"

# See the terminate() function, which is really where this script exits.
exit $OverallReturnStatus
