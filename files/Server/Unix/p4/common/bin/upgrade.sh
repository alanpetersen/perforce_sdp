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
#-----------------------------------------------------------------------------
export SDP_INSTANCE=${SDP_INSTANCE:-Undefined} 
export SDP_INSTANCE=${1:-$SDP_INSTANCE} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the Perforce instance as a parameter to this script." 
   exit 1 
fi 
. /p4/common/bin/p4_vars $SDP_INSTANCE

AWK=awk
ID=id
MAIL=mail

OS=`uname`
if [ "${OS}" = "SunOS" ] ; then
  AWK=/usr/xpg4/bin/awk
  ID=/usr/xpg4/bin/id
  MAIL=mailx
elif [ "${OS}" = "AIX" ] ; then
  AWK=awk
  ID=id
  MAIL=mail
fi

export AWK
export ID
export MAIL

cd /p4/common/bin
common_dir=`pwd -P` 

. /p4/common/bin/backup_functions.sh

if [ -d $common_dir ]; then
  cd $common_dir
else
  echo $common_dir does not exist.
  exit 1
fi

######### Start of Script ##########

check_vars
set_vars
check_dirs

[ -f $common_dir/p4 ] || { echo "No p4 in $common_dir" ; exit 1 ;}
[ -f $common_dir/p4d ] || { echo "No p4d in $common_dir" ; exit 1 ;}

chmod 777 $common_dir/p4
chmod 700 $common_dir/p4d
[[ -f $common_dir/p4broker ]] && chmod 755 $common_dir/p4broker

P4RELNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4DRELNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $3}'`
P4BLDNUM=`./p4 -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`
P4DBLDNUM=`./p4d -V | grep -i Rev. | $AWK -F / '{print $4}' | awk '{print $1}'`
CURRENT_RELNUM=`./p4d_${SDP_INSTANCE}_bin -V | grep -i Rev. | $AWK -F / '{print $3}'`

LOGFILE=$LOGS/upgrade.log

if [ -f $LOGFILE ]; then
  rm -f $LOGFILE
fi

log "Start $P4SERVER Upgrade"

[ -f p4_$P4RELNUM.$P4BLDNUM ] || cp p4 p4_$P4RELNUM.$P4BLDNUM
[ -f p4d_$P4DRELNUM.$P4DBLDNUM ] || cp p4d p4d_$P4DRELNUM.$P4DBLDNUM
[ -f p4_${P4RELNUM}_bin ] && unlink p4_${P4RELNUM}_bin
ln -s p4_$P4RELNUM.$P4BLDNUM p4_${P4RELNUM}_bin   >> "$LOGFILE" 2>&1
[ -f p4d_${P4DRELNUM}_bin ] && unlink p4d_${P4DRELNUM}_bin
ln -s p4d_$P4DRELNUM.$P4DBLDNUM p4d_${P4DRELNUM}_bin   >> "$LOGFILE" 2>&1
[ -f p4_bin ] && unlink p4_bin
ln -s p4_${P4RELNUM}_bin p4_bin >> "$LOGFILE" 2>&1

if [[ -L p4broker_${SDP_INSTANCE}_bin ]]; then
  /p4/${SDP_INSTANCE}/bin/p4broker_${SDP_INSTANCE}_init stop
  P4BRELNUM=`./p4broker -V | grep -i Rev. | $AWK -F / '{print $3}'`
  P4BBLDNUM=`./p4broker -V | grep -i Rev. | $AWK -F / '{print $4}' | $AWK '{print $1}'`
  [[ -f p4broker_$P4BRELNUM.$P4BBLDNUM ]] || cp p4broker p4broker_$P4BRELNUM.$P4BBLDNUM
  [[ -L p4broker_${P4BRELNUM}_bin ]] && unlink p4broker_${P4BRELNUM}_bin
  ln -s p4broker_$P4BRELNUM.$P4BBLDNUM p4broker_${P4BRELNUM}_bin
  [[ -L p4broker_${SDP_INSTANCE}_bin ]] && unlink p4broker_${SDP_INSTANCE}_bin
  ln -s p4broker_${P4BRELNUM}_bin p4broker_${SDP_INSTANCE}_bin
  /p4/${SDP_INSTANCE}/bin/p4broker_${SDP_INSTANCE}_init start
fi

/p4/common/bin/p4login

if [ "$P4REPLICA" == "FALSE" ] || [ $EDGESERVER -eq 1 ] ; then
  get_journalnum
fi

stop_p4d

# Don't upgrade the database for minor upgrades
if [ $CURRENT_RELNUM != $P4DRELNUM ]; then
  if [ "$P4REPLICA" == "FALSE" ] || [ $EDGESERVER -eq 1 ] ; then
    if [ "$P4REPLICA" == "FALSE" ] ; then
      truncate_journal
      sleep 1
    fi
    replay_journal_to_offline_db
    sleep 1
  fi
  unlink p4d_${SDP_INSTANCE}_bin  >> "$LOGFILE" 2>&1
  ln -s p4d_${P4DRELNUM}_bin p4d_${SDP_INSTANCE}_bin  >> "$LOGFILE" 2>&1
  $P4DBIN -r $P4ROOT -J off -xu >> "$LOGFILE" 2>&1
  if [ "$P4REPLICA" == "FALSE" ] || [ $EDGESERVER -eq 1 ] ; then
    $P4DBIN -r $OFFLINE_DB -J off -xu >> "$LOGFILE" 2>&1
  fi
fi

start_p4d

log "Finish $P4SERVER Upgrade"

