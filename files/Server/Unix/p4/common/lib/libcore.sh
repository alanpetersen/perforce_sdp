declare Version=2.1.2
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
# Library Functions.

#------------------------------------------------------------------------------
# Function: bail
#
# Input:
# $1 - error message
# $2 - Return code, default is 1
#------------------------------------------------------------------------------
function bail {
   declare msg=$1
   declare -i rc

   rc=${2:-1}
   echo -e "\n$THISSCRIPT: FATAL: $msg\n\n" >&2

   exit $rc
}

#------------------------------------------------------------------------------
# Function: initlog
#------------------------------------------------------------------------------
function initlog
{
   echo -e "${H}\n$THISSCRIPT started at $(date) as pid $$:\nInitial Command Line:\n$CMDLINE\nLog file is: ${P4U_LOG}\n\n"
}

#------------------------------------------------------------------------------
# Function: stoplog
function stoplog
{
   sleep 1
   echo -e "\n$THISSCRIPT stopped at $(date).\n\nLog file is: ${P4U_LOG}${H}\n"
}

#------------------------------------------------------------------------------
# Function: errmsg
#
# Description: Display an error message.
#
# Input:
# $1 - error message
#------------------------------------------------------------------------------
function errmsg {
 
   echo -e "$THISSCRIPT: ERROR: $1\n" >&2
}

#------------------------------------------------------------------------------
# Function: warnmsg
#
# Description: Display a warning message, but only if $VERBOSITY > 1.
#
# Input:
# $1 - warning message
#------------------------------------------------------------------------------
function warnmsg {

   [[ $VERBOSITY -gt 1 ]] && echo -e "$THISSCRIPT: WARNING: $1\n"
}

#------------------------------------------------------------------------------
# Function: msg
#
# Description:  Display a normal message.  Uses the VERBOSITY env var, and
# displays messages only if $VERBOSITY > 2.
#
# Input:
# $1 - message
#------------------------------------------------------------------------------
function msg {

   [[ $VERBOSITY -gt 2 ]] && echo -e "$1\n"
}

#------------------------------------------------------------------------------
# Function: vmsg
#
# Description:  Display a verbose message.  Uses the VERBOSITY env var, and
# displays messages only if $VERBOSITY > default 3.
#
# Input:
# $1 - message
#------------------------------------------------------------------------------
function vmsg {
   [[ $VERBOSITY -gt 3 ]] && echo -e "$1\n"
}

#------------------------------------------------------------------------------
# Function: vvmsg
#
# Description:  Display a very verbose message.  Uses the VERBOSITY env var, and
# displays messages only if $VERBOSITY > default 4.
#
# Input:
# $1 - message
#------------------------------------------------------------------------------
function vvmsg {
   [[ $VERBOSITY -gt 4 ]] && echo -e "$1\n"
}

#------------------------------------------------------------------------------
# Function: cleanTrash
#
# Usage: During operation of your program, append the $GARBAGE variable
# with garbage file or directory names, e.g.
#    GARBAGE+=" $tmpFile"
#
# Specify absolute paths for garbage files, or else ensure that the paths
# specified will be valid when the rm command is run.
#
# To specify remote garbage to clean up, append the $RGARBAGE variable,
# e.g.
#    RGARBAGE+=" $other_host:$tmpFile"
#
# Input:
# $1 - Optionally specify 'verbose'; otherwise this routine does its
#      work silently.
#------------------------------------------------------------------------------
function cleanTrash {
   declare vmode=${1:-silent}
   declare v=$VERBOSITY

   [[ "$vmode" == "silent" ]] && export VERBOSITY=1

   if [[ -n "$GARBAGE" ]]; then
      runCmd "/bin/rm -rf $GARBAGE" "Cleaning up garbage files.\n"
   fi

   if [[ -n "$RGARBAGE" ]]; then
      for rFile in $RGARBAGE; do
         rHost=${rFile%%:*}
         rFile=${rFile##*:}
         runRemoteCmd "$rHost" "/bin/rm -f $rFile" "Cleaning up remote garbage file [$rHost:$rFile].\n"
      done
   fi

   export VERBOSITY=$v
}


#------------------------------------------------------------------------------
# Function: runCmd
#
# Short: Run a command with with optional description, honoring $VERBOSITY
# and $NO_OP settings.
#
# Input:
# $1 - cmd.  The command to run.  The command is displayed first
#      if $VERBOSITY > 3.
# $2 - textDesc.  Text description of command to run. This is displayed
#      if $VERBOSITY > 2.
#      This parameter is optional.
# $3 - honorNoOpFlag.  Pass in 1 to mean "Yes, honor the $NO_OP setting
#      and display (but don't run) commands if $NO_OP is set."  Otherwise
#      $NO_OP is ignored, and the command is always run.
#      This parameter is optional; the default value is 1.
# $4 - ShowOutputFlag.  If set to 1, show output regardless of $VERBOSITY
#      value.  Otherwise, only show output if VERBOSITY > 4.
#      This parameter is optional; the default value is 1.
# $5 - CaptureOutputFlag.  If set to 1, attempt to capture the output,
#      otherwise, do not.  The default is 1.  This should be set to 0
#      in cases where commands generate large amounts of output that do
#      not require further processing or parsing.  Regardless of the
#      value specified, the output of commands containing redirection
#      operators '<' and/or '>'  are not captured.
#
# Description:
#    Display an optional description of a command, and then run the
# command.  This is affected by $NO_OP and $VERBOSITY.  If $NO_OP is
# set, the command is shown, but not run, provided $honorNoOpFlag is 1.
# The description is not shown if $VERBOSITY < 3.
#
# The variables CMDLAST, CMDEXITCODE, and CMDOUTPUT are set each time
# runCmd is called, containing the last command run, its exit code and
# output in string and file forms.
#
# If the command contains redirect operators '>' or '<', it is executed
# by being written as a generated temporary bash script.  The CMDOUTPUT
# value is set to "Output Not Captured." in that case.
#
# Usage Example:
#    Run the 'ls' command on $path, and bail if the return status of the
# executed command is non-zero, and run it even if $NO_OP is set:
#
#   runCmd "ls $path" "Contents of [$path]:" 0 || bail "Couldn't ls [$path]."
#
#------------------------------------------------------------------------------
function runCmd {
   declare cmd=$1
   declare textDesc=${2:-""}
   declare -i honorNoOpFlag=${3:-1}
   declare -i showOutputFlag=${4:-1}
   declare -i captureOutputFlag=${5:-1}
   declare tmpScript=

   CMDLAST=$cmd
   CMDEXITCODE=0
   CMDOUTPUT=""

   [[ -n "$textDesc" ]] && msg "$textDesc"

   if [[ $honorNoOpFlag -eq 1 && $NO_OP -eq 1 ]]; then
      vmsg "NO-OP: Would execute: \"$cmd\"\n"
   else
      vmsg "Executing: \"$cmd\"."

      # Execute the command, and immediately capture the return status.
      # Capture ouput if $captureOutputFlag is 1 and there are no redirect
      # operators.
      if [[ $captureOutputFlag -eq 0 || $cmd == *"<"* || $cmd == *">"* ]]; then
         tmpScript=/tmp/tmp.runCmd.$$.$RANDOM
         echo -e "#!/bin/bash\n$cmd\n" > $tmpScript
         chmod +x $tmpScript
         $tmpScript
         CMDEXITCODE=$?
         CMDOUTPUT="Output Not Captured."

      else
         CMDOUTPUT=$($cmd 2>&1)
         CMDEXITCODE=$?
      fi

      [[ $showOutputFlag -eq 1 ]] && msg "\n$CMDOUTPUT\nEXIT_CODE: $CMDEXITCODE\n"
      return $CMDEXITCODE
   fi

   return 0
}

#------------------------------------------------------------------------------
# Function: runRemoteCmd
#
# Short: Run a remote command on another host, with functionlity otherwise
# similar to runCmd.  Execute by generating a temporary remote /bin/bash script to
# insulate against shell compatibility issues, so things work as expected
# even if the default login shell is a foreign shell like tcsh.
#
# Input:
# $1 - host.  Specify the remote hostname.  Note that SSH keys must be
#      configured to allow remote executation without a password for
#      automation of remote processing.
# $2 - cmd.  The command to run.  The command is displayed first
#      if $VERBOSITY > 3.
# $3 - textDesc.  Text description of command to run. This is displayed
#      if $VERBOSITY > 2.
#      This parameter is optional.
# $4 - honorNoOpFlag.  Pass in 1 to mean "Yes, honor the $NO_OP setting
#      and display (but don't run) commands if $NO_OP is set."  Otherwise
#      $NO_OP is ignored, and the command is always run.
#      This parameter is optional; the default value is 1.
# $5 - ShowOutputFlag.  If set to 1, show output regardless of $VERBOSITY
#      value.  Otherwise, only show output if VERBOSITY > 4.
#      This parameter is optional; the default value is 1.
#
# Description:
#    Display an optional description of a command, and then run the
# command on a remote host.  This is affected by $NO_OP and $VERBOSITY.
# If $NO_OP is set, the command is shown, but not run, provided
# $honorNoOpFlag is 1. The description is not shown if $VERBOSITY <3.
#
# The variables RCMDLAST, RCMDEXITCODE, RCMDOUTPUT are set each time this
# is run, containing the last command run, its exit code and output.
#
# To insultate against shell incompatibilites and the default login shell
# possibly being something other than bash, a bash script is generated
# and then executed on the remote host.
#
# Usage Example:
#    Run the 'ls' command on $path, and bail if the return status of the
# executed command is non-zero, and run it even if $NO_OP is set:
#
#   runRemoteCmd scm02 "ls $path" "In [$path]:" 0 || bail "Couldn't ls [$path]."
#
#------------------------------------------------------------------------------
function runRemoteCmd {
   declare host=$1
   declare rCmd=$2
   declare textDesc=${3:-""}
   declare -i honorNoOpFlag=${4:-1}
   declare -i showOutputFlag=${5:-1}
   declare remoteScript="/tmp/${USER}.runRemoteCmd.$$.$RANDOM.tmp"
   declare outputFile="/tmp/libcore.runCmd.$USER.tmp.$RANDOM.$$"
   declare ec=""

   RCMDLAST=${rCmd}
   RCMDEXITCODE=0
   RCMDOUTPUT=""

   [[ -n "$textDesc" ]] && msg "$textDesc"

   if [[ $honorNoOpFlag -eq 1 && $NO_OP -eq 1 ]]; then
      vmsg "NO-OP: Would execute: \"$rCmd\"\n"
   else
      vmsg "Executing: \"$rCmd\" on remote host ${host}."

      # Generate a script with the command to execute on the remote host.
      echo -e "#!/bin/bash\n$rCmd\necho REMOTE_EXIT_CODE: \$?\n" > $remoteScript
      chmod +wx $remoteScript
      vvmsg "Script to execute [$remoteScript]:\n$(cat $remoteScript)\n"

      runCmd "scp -pq $remoteScript ${host}:${remoteScript}" || \
         bail "Failed to copy script to remote host!"

      ( ssh -n $host $remoteScript ) > $outputFile 2>&1 &

      while [[ /bin/true ]]; do
         sleep 2
         #vvmsg "Checking remote process log [$outputFile]."
         ec=$(grep -a "REMOTE_EXIT_CODE:" $outputFile)
         if [[ $? -eq 0 ]]; then
            ec=${ec##*REMOTE_EXIT_CODE: }
            ec=${ec%% *}
	    RCMDEXITCODE=$ec
            break
         fi
      done

      RCMDOUTPUT=$(cat $outputFile)

      GARBAGE+=" ${remoteScript} ${outputFile}"
      RGARBAGE+=" ${host}:$remoteScript"

      [[ $showOutputFlag -eq 1 ]] && msg "\n$RCMDOUTPUT\n"
      return $RCMDEXITCODE
   fi

   return 0
}

#------------------------------------------------------------------------------
# Function: usageError (usage error message)
#
# $1 - message
#------------------------------------------------------------------------------
function usageError {

   echo -e "$THISSCRIPT: ERROR: $1\n"
   usage -h
}

#------------------------------------------------------------------------------
# Append to PATH variable, removing duplicate entries.
# NOT CURRENTLY FUNCTIONAL!
#------------------------------------------------------------------------------
function appendPath {
   declare myPath=$1
   declare newPath=
   declare -A paths=
   local IFS=:
   for e in $(echo $PATH:$myPath); do
      if [[ -z "${paths[$e]}" ]]; then
         newPath="$newPath:$e"
         paths[$e]=1
      fi
   done
   export PATH=$(echo $newPath)
}

#------------------------------------------------------------------------------
# Prepend to PATH variable, removing duplicate entries.
# NOT CURRENTLY FUNCTIONAL!
#------------------------------------------------------------------------------
function prependPath {
   declare myPath=$1
   declare newPath=
   declare -A paths=
   local IFS=:
   for e in $(echo $myPath:$PATH); do
      if [[ -z "${paths[$e]}" ]]; then
         newPath="$newPath:$e"
         paths[$e]=1
      fi
   done
   export PATH=$(echo $newPath)
}

#------------------------------------------------------------------------------
# Clean the PATH variable by removing duplicate entries.
# NOT CURRENTLY FUNCTIONAL!
#------------------------------------------------------------------------------
function cleanPath {
   declare newPath=
   declare -A paths=
   local IFS=:
   for e in $(echo $PATH); do
      if [[ -z "${paths[$e]}" ]]; then
         newPath="$newPath:$e"
         paths[$e]=1
      fi
   done
   export PATH=$(echo $newPath)
}

#------------------------------------------------------------------------------
# Function rotate_default_log()
# Rotates and optionally compresses the default log ($P4U_LOG).
# Args:
# $1 - CompressionStyle. Values are:
# 0 - No compression (the default).
# 1 - Compress with gzip
# 2 - Compress with bzip2 --best
#------------------------------------------------------------------------------
function rotate_default_log {
   declare compressionStyle=${1:-0}
   declare newLog=

   if [[ "$P4U_LOG" != "off" ]]; then
      if [[ -e "$P4U_LOG" ]]; then
         declare -i i=1
         while [[ -e "$P4U_LOG.$i" ]]; do i=$(($i+1)); done
         newLog=${P4U_LOG}.$i
         mv "$P4U_LOG" "$newLog"
         if ((compressionStyle == 1)); then
            /usr/bin/gzip $newLog
         elif ((compressionStyle == 2)); then
            /usr/bin/bzip2 --best $newLog
         fi
      fi
   fi
}

#------------------------------------------------------------------------------
# Function: show_versions
#
# Show the version of our script plus any imported library that identifies it
# version in the expected way, with a "Version=" def'n (or "declare Version=").
# Silently ignore files that do not identify their version this way.
function show_versions
{
   declare v=

   for bash_lib in $0 $BASH_LIBS; do
      v=$(egrep -i "^(declare Version|Version)=" $bash_lib|head -1)
      [[ -n "$v" ]] || continue
      v=${v#*=}
      echo $bash_lib v$v
   done

   echo "BASH_VERSION: $BASH_VERSION"
}

