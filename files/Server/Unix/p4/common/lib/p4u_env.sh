declare Version=2.1.1
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
# Standard Environment for bash scripts.

# Use 'set -a' mode to export everything in this file.
set -a

# Require variables to be declared.
set -u

# Set aliaes for common commands.  This is a safety/security precaution to
# help ensure intended commands are run, rather than identically named
# programs elsewhere in the PATH.  Paths may need to adjusted if run on
# different systems.

alias rm=/bin/rm
alias mkdir=/bin/mkdir
alias mkpath="/bin/mkdir -p"
alias printf="/usr/bin/printf"

# Initialize GARBAGE to be empty.  This contains a list of files to be
# removed upon termination of the script.
declare GARBAGE=""
declare RGARBAGE=""

# Provide a baseline default VERBOSITY.  Scripts may override this to define
# a default for a specific script.  Script users may override this on a per-run
# basis. Scale:
# 1=errors only
# 2=errors and warnings
# 3=normal
# 4=verbose
declare -i VERBOSITY=5

# Store just the name of the current script, useful for logging.
declare THISSCRIPT=${0##*/}

# Store the initial command line in $CMDLINE, useful for logging.
declare CMDLINE="$0 $*"

# Initialize the NO_OP ("no operation") test mode.  If set to 1, scripts
# interpret this to mean "show what would be done, without executing any
# data-affecting commands.":w
declare -i NO_OP=0

# Globals for runCmd, containing last command, its exit code and output.
declare CMDLAST=""
declare -i CMDEXITCODE=0
declare CMDOUTPUT=""

# Globals for runRemoteCmd, containing last command, its exit code and output.
declare RCMDLAST=""
declare -i RCMDEXITCODE=0
declare RCMDOUTPUT=""

# Header, 79 characters of screen-splitting divider.
declare H="\n==============================================================================="

# At the end of this file, return to default behavior, undoing 'set -a' above.
set +a
