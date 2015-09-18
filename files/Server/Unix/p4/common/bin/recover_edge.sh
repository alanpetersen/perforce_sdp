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

# This script is designed to rebuild an Edge server from a checkpoint off the master. 
# You have to first copy the checkpoint from the master to the edge server before running this script.
# Then you run this script on the Edge server with the instance number and full path and filename
# of the master checkpoint as parameters.
#
# Run example:
#  ./recover.sh 1 /depotdata/p4_1.ckp.9188.gz
 
if [[ "$1" == "" ]]; then
   echo You must pass in the instance number as the first parameter to this script.
   exit 1
fi

if [[ "$2" == "" ]]; then
   echo You must pass in the full path and filename of the checkpoint you copied over from the master server.
   exit 2
fi

INSTANCE=$1
MASTERCKP=$2

rm -f /p4/${INSTANCE}/offline_db/db.*
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/offline_db/ -K db.have,db.working,db.resolve,db.locks,db.revsh,db.workingx,db.resolvex -jr -z $MASTERCKP
/p4/${INSTANCE}/bin/p4d_${INSTANCE}_init stop
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/root/ -k db.have,db.working,db.resolve,db.locks,db.revsh,db.workingx,db.resolvex,db.view,db.label,db.revsx,db.revux -jd /p4/${INSTANCE}/checkpoints/edgedump
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/offline_db -jr /p4/${INSTANCE}/checkpoints/edgedump
rm -f /p4/${INSTANCE}/root/db.*
rm -f /p4/${INSTANCE}/root/state
rm -f /p4/${INSTANCE}/root/rdb.lbr
rm -f /p4/${INSTANCE}/logs/journal
mv /p4/${INSTANCE}/offline_db/db.* /p4/${INSTANCE}/root/
/p4/${INSTANCE}/bin/p4d_${INSTANCE}_init start
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/offline_db/ -K db.have,db.working,db.resolve,db.locks,db.revsh,db.workingx,db.resolvex -jr -z $MASTERCKP
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/offline_db -jr /p4/${INSTANCE}/checkpoints/edgedump
/p4/${INSTANCE}/bin/p4d_${INSTANCE} -r /p4/${INSTANCE}/offline_db -jd -z /p4/${INSTANCE}/checkpoints/rebuilt_edge_dump.gz
echo Rebuilt checkpoint is: /p4/${INSTANCE}/checkpoints/rebuilt_edge_dump.gz
echo If you run this script the night before a weekly_backup.sh is going to run, 
echo you need to delete the highest numbered checkpoint in /p4/${INSTANCE}/checkpoints
echo and rename /p4/${INSTANCE}/checkpoints/rebuilt_edge_dump.gz to replace that file.
