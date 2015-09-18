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
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 
. /p4/common/bin/p4_vars $SDP_INSTANCE
. /p4/common/bin/backup_functions.sh

LOGFILE=$LOGS/edge_shelf_replicate.log
STATUS="OK: Shelves replicated."
declare -i EXIT_CODE=0
 
P4="$P4BIN -p $P4PORT -u $P4USER"
 
/p4/common/bin/p4login
 
# Print shelved files on Edge replica. 
for d in `$P4 -s depots|grep "^info: Depot " |\
   grep -v --perl-regexp "^info: Depot \S+ \d{4}\/\d{2}\/\d{2} (remote|archive|unload) " |\
   cut -d ' ' -f 3`; do
   echo === Started replication of //$d/... at $(date). >> $LOGFILE
   echo Running $P4 changes -s shelved //$d/... >> $LOGFILE
   $P4 changes -s shelved //$d/... | cut -d " " -f 2 | while read cl; do
      echo Running $P4 print //$d/...@=$cl >> $LOGFILE
      $P4 print //$d/...@=$cl > /dev/null
   done

   if [[ $? -ne 0 ]]; then
      STATUS="Error: Replication failed.  Review the log [$LOGFILE]."
      EXIT_CODE=1
   fi
done

echo Edge replication complated at $(date). >> $LOGFILE

mail_log_file "$HOSTNAME $P4SERVER Edge shelf replication Log ($STATUS)"
 
exit $EXIT_CODE
