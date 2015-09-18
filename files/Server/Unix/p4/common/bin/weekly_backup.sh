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

# This script must be called using the p4master_run script in order to properly set
# the environment variables for the script to reference. The p4master_run scripts
# source /p4/common/bin/p4_vars to set the environment variables that this script
# depends on.
#
# This script requires the offline_db directory to contain a restored copy of the
# most recent checkpoint to play the cut off journal into.
#
# This script is using the following external variables:
#
# SDP_INSTANCE - The instance of Perforce that is being backed up. Always an
# integer value.
#
# P4HOME - Server's home directory.
# P4BIN - Command line client name for the instance being backed up.
# P4DBIN - Server executable name for the instance being backed up.
# P4ROOT - Server's root directory. p4/root, p4_N/root
# P4PORT - TCP/IP port for the server instance being backed up.
# P4JOURNAL - Location of the Journal for the server instance being backed up.
#
#
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 

. /p4/common/bin/p4_vars $SDP_INSTANCE
. /p4/common/bin/backup_functions.sh

switch_db_files () {
   log "Switching out db files..."
   [[ -d $SAVEDIR ]] || mkdir -p $SAVEDIR
   rm -f $SAVEDIR/db.* >> $LOGFILE 2>&1
   mv $P4ROOT/db.* $SAVEDIR >> $LOGFILE 2>&1
   mv $OFFLINE_DB/db.* $P4ROOT >> $LOGFILE 2>&1 || die "Move of offline db file to $P4ROOT failed."
}

######### Start of Script ##########
check_vars
set_vars
check_uid
check_dirs
ckp_running
/p4/common/bin/p4login
get_journalnum
rotate_last_run_logs
log "Start $P4SERVER Checkpoint"
get_offline_journal_num
replay_journals_to_offline_db
stop_p4d
# Sleep 30 seconds to give everything a chance to exit.
sleep 5
truncate_journal
replay_journal_to_offline_db

if [[ $EDGESERVER -eq 1 ]]; then
   replay_active_journal_to_offline_db
fi

switch_db_files
start_p4d
echo Removing db files from $SAVEDIR since we know the journal successfully replayed at this point. >> $LOGFILE
rm -f $SAVEDIR/db.* >> $LOGFILE 2>&1
recreate_weekly_offline_db_files
get_offline_journal_num
replay_journals_to_offline_db
replay_journal_to_offline_db
ROOTDIR=$OFFLINE_DB
dump_checkpoint
remove_old_checkpoints_and_journals
check_disk_space
remove_old_logs
log "End $P4SERVER Checkpoint"
mail_log_file "$HOSTNAME $P4SERVER Weekly maintenance log."
set_counter
ckp_complete
