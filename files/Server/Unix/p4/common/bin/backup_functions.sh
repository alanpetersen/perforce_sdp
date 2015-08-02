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

set -u

# Common functions used in all backup scripts.

check_vars () {
    if [ -z "$SDP_INSTANCE" -o -z "$P4HOME" -o -z "$P4PORT" -o -z "$P4ROOT" -o -z "$P4JOURNAL" -o -z "$P4BIN" -o -z "$P4DBIN" -o -z "$P4TICKETS" -o -z "$KEEPCKPS" -o -z "$KEEPLOGS" -o -z "$CHECKPOINTS" -o -z "$LOGS" ]; then
   	echo "Use p4master_run when calling this script."
   	echo "Required external variable not set. Abort!"
   	exit 1
    fi
}

set_vars () {
    RC=/etc/init.d/p4d_${SDP_INSTANCE}_init
    [ -f "$RC" ] || RC=/p4/$SDP_INSTANCE/bin/p4d_${SDP_INSTANCE}_init
    LOGFILE=$LOGS/checkpoint.log
    OFFLINE_DB=${P4HOME}/offline_db
    SAVEDIR=${P4ROOT}/save
    EDGESERVER=0
    $P4BIN -u $P4USER -p $P4PORT login < /p4/common/bin/adminpass > /dev/null
    $P4BIN -u $P4USER -p $P4PORT server -o $SERVERID | grep ^Services | grep "edge-server" > /dev/null
      if [ `echo $?` -eq 0 ]; then
          EDGESERVER=1
      fi
}

log () {
    echo -n `date`    2>&1 >> "$LOGFILE"
    echo " $0: $@" 2>&1 >> "$LOGFILE"
}

# Decide depending on our mail utility, how to specify sender (if we need to)
get_mail_sender_opt () {
    local mail_sender_opt=""
    if [ ! -z "$MAILFROM" ]; then
        # Default for CentOS/RHEL, but allow GNU Mailutils alternative flag instead
        mail_sender_opt="-S from=$MAILFROM"
        local mail_ver=`$SDPMAIL -V`
        [[ "$mail_ver" =~ "GNU Mailutils" ]] && mail_sender_opt="-aFrom:$MAILFROM"
    fi
    echo "$mail_sender_opt"
}

mail_log_file () {
    local subject=$1
    local mail_sender_opt=$(get_mail_sender_opt)
    $SDPMAIL -s "$subject" $mail_sender_opt $MAILTO < "$LOGFILE"
}

die () {	# send mail and exit
    # mail the error (with more helpful subject line than cron)
    log "ERROR!!! - $HOSTNAME $P4SERVER $0: $@"
    mail_log_file "ERROR!!! - $HOSTNAME $P4SERVER $0: $@"
    exit 1
}

checkdir () {
   local dir=$1
    [ -w $dir ] && return
    if [ "$check" = 1 ]   # --check, run interactively.  just tell user.
    then
		echo "$0: $dir is not writable!"
		dirs_ok=false
	else
		die "$dir is not writable. Abort!"
    fi
}

check_dirs () {
    # Check that key dirs are writable
    dirs_ok=true
    for dir in $OFFLINE_DB $CHECKPOINTS $LOGS; do
    checkdir $dir    # aborts on failure.
    done
}

check_disk_space () {
    # Add the results of df -h or df -m to the log file.
    log "Checking disk space..."
    $P4BIN diskspace >> "$LOGFILE" 2>&1
}

get_journalnum () {
    # get the current journal and checkpoint serial numbers.
    JOURNALNUM=`$P4BIN -u $P4USER -p $P4PORT counter journal 2>> $LOGFILE` || \
    die "Cannot get the checkpoint number. Abort!"
    # If we are on an edge server, the journal has already rotated, so we have to decrement the value
    # so that we replay the correct journal file and create the correct checkpoint number on the
    # edge server.
    if [ $EDGESERVER -eq 1 ]; then
        JOURNALNUM=$(($JOURNALNUM - 1))
    fi
    CHECKPOINTNUM=$(($JOURNALNUM + 1))
}

get_offline_journal_num () {
    # Get the journal number of the offline database
    if [ ! -f $OFFLINE_DB/db.counters ]; then
      die "Offline database not found. Consider creating it with live_checkpoint.sh. Be aware that it locks the live system and can take a long time! Abort!"
      log "Offline database not found."
    fi
    OFFLINEJNLNUM=`$P4DBIN -r $OFFLINE_DB -jd - db.counters | grep '@journal@' | cut -d "@" -f 8 2>> $LOGFILE` || \
    die "Cannot get the offline journal number. Abort!"
    log "Offline journal number is: $OFFLINEJNLNUM"
    if [ $OFFLINEJNLNUM -gt $JOURNALNUM ]; then
      die "$JOURNALNUM already replayed into the offline database."
    fi 
}

replay_journals_to_offline_db () {
    log "Replay any unreplayed journals to the offline database"
    for (( j=$OFFLINEJNLNUM; $j <= (($JOURNALNUM-1)); j++ )); do
        log "Replay journal ${P4SERVER}.jnl.${OFFLINEJNLNUM} to offline db."
        # curly braces are necessary to capture the output of 'time'
        { time $P4DBIN -r $OFFLINE_DB -jr -f ${CHECKPOINTS}/${P4SERVER}.jnl.${j}; } \
        >> "$LOGFILE" 2>&1 || { die "Offline journal replay failed. Abort!"; }
    done
}
 
remove_old_checkpoints_and_journals () {
    if [ $KEEPCKPS -eq 0 ]; then
        log "Skipping cleanup of old checkpoints because KEEPCKPS is set to 0."
    elif [ $(($JOURNALNUM-$KEEPCKPS)) -gt 7 ]; then
        log "Deleting obsolete checkpoints and journals. Keeping latest $KEEPCKPS  per KEEPCKPS setting in p4_vars."

        STARTNUM=$(($JOURNALNUM-$KEEPCKPS-100))
        if [ $STARTNUM -lt 0 ]; then
            STARTNUM=0
        fi

        # Remove selected checkpoint and journal files based on
        # journal counter, regardless of whether compressed or not.
        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPCKPS)); j++ )); do
            I_CKPFILE=${CHECKPOINTS}/${P4SERVER}.ckp.$j
            I_JNLFILE=${CHECKPOINTS}/${P4SERVER}.jnl.$j

            if [ -f "$I_CKPFILE" ]; then
                log "rm -f $I_CKPFILE"
                rm -f "$I_CKPFILE"
            fi
            
            if [ -f "${I_CKPFILE}.md5" ]; then
                log "rm -f ${I_CKPFILE}.md5"
                rm -f "${I_CKPFILE}.md5"
            fi


            if [ -f "$I_JNLFILE" ]; then
                log "rm -f $I_JNLFILE"
                rm -f "$I_JNLFILE"
            fi

            I_CKPFILE=${CHECKPOINTS}/${P4SERVER}.ckp.$j.gz
            I_JNLFILE=${CHECKPOINTS}/${P4SERVER}.jnl.$j.gz

            if [ -f "$I_CKPFILE" ]; then
                log "rm -f $I_CKPFILE"
                rm -f "$I_CKPFILE"
            fi

            if [ -f "${I_CKPFILE}.md5" ]; then
                log "rm -f ${I_CKPFILE}.md5"
                rm -f "${I_CKPFILE}.md5"
            fi

            if [ -f "$I_JNLFILE" ]; then
                log "rm -f $I_JNLFILE"
                rm -f "$I_JNLFILE"
            fi
        done
    else
        log "No old checkpoints and journals need to be deleted."
    fi
}

stop_p4d () {
   log "Shutting down the p4 server"
   $RC stop >> "$LOGFILE" 2>&1
   COUNTER=`ps -ef | grep -i $P4DBIN | grep -v grep | wc -l`
   while [ $COUNTER != "0" ]
   do
      sleep 5
      COUNTER=`ps -ef | grep -i $P4DBIN | grep -v grep | wc -l`
   done
   log "p4 stop finished -- p4 should be down now."
}

start_p4d () {
   log "Starting the p4 server"
   $RC start >> "$LOGFILE" 2>&1
   sleep 3	# Give it a few seconds to start up
   # Confirm that it started - success below means it did
   if $P4BIN -u $P4USER -p $P4PORT info >/dev/null 2>&1 ; then
      log "Server restarted successfully - p4 should be back up now."
   else
      log "Error: Server does not appear to have started."
   fi
}

truncate_journal () {
    [[ -f ${CHECKPOINTS}/${P4SERVER}.ckp.${CHECKPOINTNUM}.gz ]] && die "Checkpoint ${CHECKPOINTS}/${P4SERVER}.ckp.${CHECKPOINTNUM}.gz already exists, check the backup process."
    if [ $EDGESERVER -eq 0 ]; then
        [[ -f ${CHECKPOINTS}/${P4SERVER}.jnl.${JOURNALNUM} ]] && die "Journal ${CHECKPOINTS}/${P4SERVER}.jnl.${JOURNALNUM} already exists, check the backup process."
        log "Truncating journal..."
        # 'p4d -jj' does a copy-then-delete, instead of a simple mv.
        # during 'p4d -jj' the perforce server will hang the responses to clients.
        # curly braces are necessary to capture the output of 'time'
        { time $P4DBIN -r $P4ROOT -J $P4JOURNAL -jj ${CHECKPOINTS}/${P4SERVER}; } \
            >> "$LOGFILE" 2>&1 || \
                { start_p4d; die "Journal rotation failed. Abort!"; }
    fi
}

replay_journal_to_offline_db () {
    log "Replay journal to offline db."
    # curly braces are necessary to capture the output of 'time'
    { time $P4DBIN -r $OFFLINE_DB -jr -f ${CHECKPOINTS}/${P4SERVER}.jnl.${JOURNALNUM}; } \
        >> "$LOGFILE" 2>&1 || \
	    { die "Journal replay failed. Abort!"; }
}

replay_active_journal_to_offline_db () {
    log "Replay active journal to offline db."
    # curly braces are necessary to capture the output of 'time'
    { time $P4DBIN -r $OFFLINE_DB -jr -f ${P4JOURNAL}; } \
        >> "$LOGFILE" 2>&1 || \
            { die "Active Journal replay failed. Abort!"; }
}

dump_checkpoint () {
	log "Dump out new checkpoint from db files in $ROOTDIR."
    # curly braces are necessary to capture the output of 'time'
    { time $P4DBIN -r $ROOTDIR -jd -z ${CHECKPOINTS}/${P4SERVER}.ckp.${CHECKPOINTNUM}.gz; } \
        >> "$LOGFILE" 2>&1 || \
	    { die "New checkpoint dump failed!"; }
}

recreate_offline_db_files () {
	log "Recreate offline db files for quick recovery process."
	rm -f ${OFFLINE_DB}/db.* >> "$LOGFILE"
    # curly braces are necessary to capture the output of 'time'
    { time $P4DBIN -r $OFFLINE_DB -jr -z ${CHECKPOINTS}/${P4SERVER}.ckp.${CHECKPOINTNUM}.gz; } \
        >> "$LOGFILE" 2>&1 || \
	    { log "Restore of checkpoint to $OFFLINE_DB failed!"; }
}

recreate_weekly_offline_db_files () {
        log "Recreate offline db files for quick recovery process."
        rm -f ${OFFLINE_DB}/db.* >> "$LOGFILE"
    LASTCKP=`ls -t ${CHECKPOINTS}/${P4SERVER}.ckp.*.gz | head -1`
    # curly braces are necessary to capture the output of 'time'
    { time $P4DBIN -r $OFFLINE_DB -jr -z ${LASTCKP}; } \
        >> "$LOGFILE" 2>&1 || \
            { die "Restore of checkpoint to $OFFLINE_DB failed!"; }
}


# At the start of each run for live_checkpoint.sh, daily_backup.sh, and
# weekly_backup.sh, before *any* logging activity occurs, rotate the logs
# from the most recent prior run, always named "checkpoint.log" or "log".
rotate_last_run_logs () {
    # Rotate prior checkpoint.log
    [[ -f "$LOGFILE" ]] && mv -f "$LOGFILE" "$LOGFILE.$JOURNALNUM"

    # Rotate prior server log.
    if [ -f "$LOGS/log" ]; then
        mv -f "$LOGS/log" "$LOGS/log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd "$LOGS"
	rm -f "log.$JOURNALNUM.gz"
        gzip "log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd - > /dev/null
    fi

    # Rotate prior broker log.
    if [ -f "$LOGS/p4broker.log" ]; then
        mv -f "$LOGS/p4broker.log" "$LOGS/p4broker.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd "$LOGS"
	rm -f "p4broker.log.$JOURNALNUM.gz"
        gzip "p4broker.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd - > /dev/null
    fi

    # Rotate prior audit log.
    if [ -f "$LOGS/audit.log" ]; then
        mv -f "$LOGS/audit.log" "$LOGS/audit.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd "$LOGS"
	rm -f "audit.log.$JOURNALNUM.gz"
        gzip "audit.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd - > /dev/null
    fi

    # Rotate prior sync_replica log.
    if [ -f "$LOGS/sync_replica.log" ]; then
        mv -f "$LOGS/sync_replica.log" "$LOGS/sync_replica.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd "$LOGS"
        rm -f "sync_replica.log.$JOURNALNUM.gz"
        gzip "sync_replica.log.$JOURNALNUM" >> $LOGFILE 2>&1
        cd - > /dev/null
    fi
}

remove_old_logs () {
    # Remove old Checkpoint Logs
    # Use KEEPCKPS rather than KEEPLOGS, so we keep the same number
    # of checkpoint logs as we keep checkpoints.
    # Avoid automatically removing #'s 1-7 in any case.
    STARTNUM=$(($JOURNALNUM-$KEEPLOGS-100))
    if [ $STARTNUM -lt 0 ]; then
        STARTNUM=0
    fi

    if [ $KEEPCKPS -eq 0 ]; then
        log "Skipping cleanup of old checkpoint logs because KEEPCKPS is set to 0."
    elif [ $(($JOURNALNUM-$KEEPCKPS)) -gt 7 ]; then
        log "Deleting old checkpoint logs.  Keeping latest $KEEPCKPS, per KEEPCKPS setting in p4_vars."
        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPCKPS)); j++ )); do
            I_LOGFILE="$LOGS/checkpoint.log.$j"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
        done
    else
        log "No old checkpoint logs need to be deleted."
    fi

    if [ $KEEPLOGS -eq 0 ]; then
        log "Skipping cleanup of old server logs because KEEPLOGS is set to 0."
    elif [ $(($JOURNALNUM-$KEEPLOGS)) -gt 7 ]; then
        log "Deleting old server logs.  Keeping latest $KEEPLOGS, per KEEPLOGS setting in p4_vars."

        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPLOGS)); j++ )); do
            I_LOGFILE="$LOGS/log.$j"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
            I_LOGFILE="$LOGS/log.$j.gz"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
        done

        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPLOGS)); j++ )); do
            I_LOGFILE="$LOGS/p4broker.log.$j"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
            I_LOGFILE="$LOGS/p4broker.log.$j.gz"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
        done

        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPLOGS)); j++ )); do
            I_LOGFILE="$LOGS/audit.log.$j"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
            I_LOGFILE="$LOGS/audit.log.$j.gz"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
        done

        for (( j=$STARTNUM; $j <= (($JOURNALNUM-$KEEPLOGS)); j++ )); do
            I_LOGFILE="$LOGS/sync_replica.log.$j"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
            I_LOGFILE="$LOGS/sync_replica.log.$j.gz"
            if [ -f "$I_LOGFILE" ]; then
                log "rm -f $I_LOGFILE"
                rm -f "$I_LOGFILE"
            fi
        done
    else
        log "No old server logs need to be deleted."
    fi
}

set_counter() {
    $P4BIN -u $P4USER -p $P4PORT login < /p4/common/bin/adminpass > /dev/null
    $P4BIN -u $P4USER -p $P4PORT counter lastSDPCheckpoint "$(date +'%s (%y/%m/%d %H:%M:%S %z %Z)')" > /dev/null
}
