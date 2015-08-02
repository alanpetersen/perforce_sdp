#!/bin/bash
#------------------------------------------------------------------------------
# Copyright (c) Perforce Software, Inc., 2007-2015. All rights reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met#
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

# Generate an SDP instance-specific variant of the generic
# P4Broker config file.  Display to standard output.

# Usage#
# cd /p4/common/bin
# gen_default_broker_cfg.sh SDP_INSTANCE > /tmp/p4broker.cfg.ToBeReviewed
#
# The final p4broker.cfg should end up here:
# /p4/common/config/p4_${SDP_INSTANCE}.${SERVERID}.broker.cfg

export SDP_INSTANCE=${1:-Undefined} 
if [[ $SDP_INSTANCE == Undefined ]]; then 
   echo "Instance parameter not supplied." 
   echo "You must supply the SDP instance as a parameter to this script." 
   exit 1 
fi 
. /p4/common/bin/p4_vars $SDP_INSTANCE

$P4BROKERBIN -C | sed "s#/p4/broker/.p4tickets#$P4TICKETS#g" |\
   sed "s#/p4/broker#$P4HOME/bin#g" |\
   sed "s#broker.log#$LOGS/p4broker.log#g" |\
   sed "s#1667#$P4BROKERPORT#g" |\
   sed "s#localhost:1666#$P4PORT#g" |\
   sed "s#perforce-admins@example.com#$MAILTO#g"

