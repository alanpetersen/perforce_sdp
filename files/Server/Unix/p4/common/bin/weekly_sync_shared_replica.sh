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

# Intended to be run on a replica machine to sync replica from its corresponding master
# Like sync_replica.sh but for use in a regular crontab
#
# NOTE!!!
# logs must not be a shared volume with this script.
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 
. /p4/common/bin/p4_vars $SDP_INSTANCE
. /p4/common/bin/backup_functions.sh

######### Start of Script ##########
check_vars
set_vars

LOGFILE=$LOGS/sync_replica.log

$P4BIN -u $P4USER -p ${SSL_PREFIX}${P4MASTER}:${P4MASTERPORTNUM} login < /p4/common/bin/adminpass > /dev/null 2>&1
JOURNALNUM=`$P4BIN -u $P4USER -p ${SSL_PREFIX}${P4MASTER}:${P4MASTERPORTNUM} counter journal`

if [[ "$JOURNALNUM" == "" ]]; then
   die "Error:  Couldn't get journal number from master.  Aborting."
fi

rotate_last_run_logs
log "Starting weekly_sync_shared_replica.sh"

recreate_weekly_offline_db_files
get_offline_journal_num
replay_journals_to_offline_db

/p4/common/bin/p4master_run $SDP_INSTANCE /p4/${SDP_INSTANCE}/bin/p4d_${SDP_INSTANCE}_init stop >> $LOGFILE 2>&1

# Sleep 10 seconds to give everything a chance to exit.
sleep 10

log "Server should be down now."
log "Moving offline db into root."
cd /p4/${SDP_INSTANCE}/root
rm -f save/db.* >> $LOGFILE 2>&1
mv db.* save >> $LOGFILE 2>&1
mv /p4/${SDP_INSTANCE}/offline_db/db.* . >> $LOGFILE 2>&1
rm -f state >> $LOGFILE 2>&1
rm -f rdb.lbr >> $LOGFILE 2>&1
rm -f /p4/$SDP_INSTANCE/logs/journal >> $LOGFILE 2>&1

$P4BIN -p ${SSL_PREFIX}${P4MASTER}:${P4MASTERPORTNUM} login < /p4/common/bin/adminpass > /dev/null 2>&1
$P4BIN -p ${SSL_PREFIX}${P4MASTER}:${P4MASTERPORTNUM} login $P4SERVICEUSER > /dev/null 2>&1
/p4/common/bin/p4master_run $SDP_INSTANCE /p4/${SDP_INSTANCE}/bin/p4d_${SDP_INSTANCE}_init start >> $LOGFILE 2>&1

log "Server should be back up now."

$P4BIN -p ${SSL_PREFIX}${P4MASTERPORTNUM} login < /p4/common/bin/adminpass > /dev/null 2>&1
$P4BIN -p ${SSL_PREFIX}${P4MASTERPORTNUM} pull -lj >> $LOGFILE

rm -f save/db.* >> $LOGFILE 2>&1
recreate_weekly_offline_db_files
get_offline_journal_num
replay_journals_to_offline_db

check_disk_space
remove_old_logs
$P4BIN -p ${SSL_PREFIX}${P4MASTERPORTNUM} pull -lj >> $LOGFILE

log "End $P4SERVER Checkpoint"
mail_log_file "$HOSTNAME $P4SERVER Weekly sync shared replica log."
