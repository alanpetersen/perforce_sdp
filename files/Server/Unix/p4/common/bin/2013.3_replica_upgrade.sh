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

# This script requires the full path and name of the current checkpoint file copied
# over from the master server as a parameter. This should be the same checkpoint used
# to upgrade the master server to 2013.3+
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 

. /p4/common/bin/p4_vars $SDP_INSTANCE
. /p4/common/bin/backup_functions.sh

recreate_offline_db_files_2013.3 () {
   log "Recreate offline db files for 2013.3 upgrade process."
   rm -f ${OFFLINE_DB}/db.* >> "$LOGFILE"
   # curly braces are necessary to capture the output of 'time'
   # if $P4DBIN is not a link, then it is a wrapper around p4d with the -C1 flag.
   if [[ ! -L $P4DBIN ]]; then
      { time /p4/common/bin/p4d_${P4DRELNUM}_bin -C1 -r $OFFLINE_DB -J off -jr -z ${CHECKPOINT_FILE}; } >> "$LOGFILE" 2>&1 || \
         { log "ERROR - Restore of checkpoint to $OFFLINE_DB failed!"; }
   else
      { time /p4/common/bin/p4d_${P4DRELNUM}_bin -r $OFFLINE_DB -J off -jr -z ${CHECKPOINT_FILE}; } >> "$LOGFILE" 2>&1 || \
         { log "ERROR - Restore of checkpoint to $OFFLINE_DB failed!"; }
   fi
}

switch_db_files () {
   log "Switching out db files..."
   [[ -d $SAVEDIR ]] || mkdir -p $SAVEDIR
   rm -f $SAVEDIR/db.* >> $LOGFILE 2>&1
   mv $P4ROOT/db.* $SAVEDIR >> $LOGFILE 2>&1
   mv $OFFLINE_DB/db.* $P4ROOT >> $LOGFILE 2>&1 || die "Move of offline db file to $P4ROOT failed."
}


AWK=awk
ID=id
MAIL=mail

OS=`uname`
if [[ "${OS}" = "SunOS" ]]; then
   AWK=/usr/xpg4/bin/awk
   ID=/usr/xpg4/bin/id
   MAIL=mailx
elif [[ "${OS}" = "AIX" ]]; then
   AWK=awk
   ID=id
   MAIL=mail
fi

export AWK
export ID
export MAIL

cd /p4/common/bin
common_dir=`pwd -P` 

if [[ -d $common_dir ]]; then
   cd $common_dir
else
   echo $common_dir does not exist.
   exit 1
fi

######### Start of Script ##########

if [[ -z "$2" ]]; then
   echo "Checkpoint parameter not supplied."
   echo "See comments at the top of this script for the required parameter."
   exit 1
fi

CHECKPOINT_FILE = $2
[[ -f ${CHECKPOINT_FILE} ]] || { echo "Checkpoint ${CHECKPOINT_FILE} missing!" ; exit 1 ;}

check_vars
set_vars

# override LOGFILE setting from set_vars which will point to checkpoint.log
LOGFILE=$LOGS/upgrade.log

if [[ -f $LOGFILE ]]; then
   rm -f $LOGFILE
fi

check_dirs
check_uid

[[ -f $common_dir/p4 ]] || { echo "No p4 in $common_dir" ; exit 1 ;}
[[ -f $common_dir/p4d ]] || { echo "No p4d in $common_dir" ; exit 1 ;}

chmod 777 $common_dir/p4
chmod 700 $common_dir/p4d

P4RELNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4DRELNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4BLDNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`
P4DBLDNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`
CURRENT_RELNUM=`./p4d_${SDP_INSTANCE}_bin -V | grep -i Rev. | $AWK -F / '{print $3}'`


log "Start $P4SERVER Replica Upgrade"

[[ -f p4_$P4RELNUM.$P4BLDNUM ]] || cp p4 p4_$P4RELNUM.$P4BLDNUM
[[ -f p4d_$P4DRELNUM.$P4DBLDNUM ]] || cp p4d p4d_$P4DRELNUM.$P4DBLDNUM
[[ -f p4_${P4RELNUM}_bin ]] && unlink p4_${P4RELNUM}_bin
ln -s p4_$P4RELNUM.$P4BLDNUM p4_${P4RELNUM}_bin   >> "$LOGFILE" 2>&1
[[ -f p4d_${P4DRELNUM}_bin ]] && unlink p4d_${P4DRELNUM}_bin
ln -s p4d_$P4DRELNUM.$P4DBLDNUM p4d_${P4DRELNUM}_bin   >> "$LOGFILE" 2>&1
[[ -f p4_bin ]] && unlink p4_bin
ln -s p4_${P4RELNUM}_bin p4_bin >> "$LOGFILE" 2>&1

recreate_offline_db_files_2013.3
stop_p4d
sleep 5
log "Changing p4d link to new version."
unlink p4d_${SDP_INSTANCE}_bin  >> "$LOGFILE" 2>&1
ln -s p4d_${P4DRELNUM}_bin p4d_${SDP_INSTANCE}_bin >> "$LOGFILE" 2>&1
log "Upgrading $OFFLINE_DB"
$P4DBIN -r $OFFLINE_DB -J off -xu >> "$LOGFILE" 2>&1
switch_db_files
log "Removing old journal, state, and rdb.lbr."
rm -f /p4/${SDP_INSTANCE}/logs/journal >> "$LOGFILE" 2>&1
rm -f /p4/${SDP_INSTANCE}/root/rdb.lbr >> "$LOGFILE" 2>&1
rm -f /p4/${SDP_INSTANCE}/root/state >> "$LOGFILE" 2>&1
start_p4d
log "Removing db files from $SAVEDIR"
rm -f ${SAVEDIR}/db.* >> "$LOGFILE" 2>&1
recreate_offline_db_files_2013.3
log "Upgrading $OFFLINE_DB"
$P4DBIN -r $OFFLINE_DB -J off -xu >> "$LOGFILE" 2>&1

log "Finish $P4SERVER Replica Upgrade"
