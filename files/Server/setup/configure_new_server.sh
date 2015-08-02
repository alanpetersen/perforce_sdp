#!/bin/bash
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
# Set P4PORT and P4USER and run p4 login before running this script.
# Also run p4 triggers and put in the SetDefaultDepotSpeMapField.py trigger first as well.

# Verify instance value
INSTANCE=$1
if [[ -n "$INSTANCE" ]]; then
   source /p4/common/bin/p4_vars $INSTANCE
else
    echo "Error: An instance argument is required."
    exit 1
fi

# Basic secruity features.
p4 configure set defaultChangeType=restricted
p4 configure set run.users.authorize=1

# The server.depot.root configurable was introduced in 2014.1.
if [[ "$P4D_VERSION" > "2014.1" ]]; then
   p4 configure set server.depot.root=$DEPOTS
fi

p4 configure set journalPrefix=$CHECKPOINTS/p4_${INSTANCE}
p4 configure set dm.user.noautocreate=2
p4 configure set dm.user.resetpassword=1
p4 configure set filesys.P4ROOT.min=1G
p4 configure set filesys.depot.min=1G
p4 configure set filesys.P4JOURNAL.min=1G

p4 configure set server=3
p4 configure set monitor=1

# For P4D 2013.2+, setting db.reorg.disable=1 has been shown
# to significantly improve performance when Perforce databases (db.*
# files) are stored on some solid state storage devices, while not
# making a difference on others.  It should be considered.
### [[ "$P4D_VERSION" > "2013.1" ]] && p4 configure set db.reorg.disable=1

# Set net.tcpsize when P4D is 2014.2 or less.  In 2014.2
# the default changes from 2014.1, and this configurable
# is best not set explicitly.
[[ "$P4D_VERSION" < "2014.2" ]] && p4 configure set net.tcpsize=512k

p4 configure set lbr.autocompress=1
p4 configure set lbr.bufsize=1M
p4 configure set serverlog.file.3=$LOGS/errors.csv
p4 configure set serverlog.retain.3=7
p4 configure set serverlog.file.7=$LOGS/events.csv
p4 configure set serverlog.retain.7=7
p4 configure set serverlog.file.8=$LOGS/integrity.csv
p4 configure set serverlog.retain.8=7
p4 depot -o specs | sed 's/^Type:\tlocal/Type: spec/g' | p4 depot -i
p4 depot -o unload | sed 's/^Type:\tlocal/Type: unload/g' | p4 depot -i

# Load shedding and other performance-preserving configurable.
# See: http://answers.perforce.com/articles/KB/1272
# For p4d 2013.1+
[[ "$P4D_VERSION" > "2013.1" ]] && p4 configure set server.maxcommands=2500

# For p4d 2012.2+, set net.maxwait to drop a client connection if waits
# too long for any single network read or write.
[[ "$P4D_VERSION" > "2012.2" ]] && p4 configure set net.maxwait=600

# For p4d 2013.2+ -Turn off max* commandline overrides.
[[ "$P4D_VERSION" > "2013.2" ]] && p4 configure set server.commandlimits=2

echo See http://www.perforce.com/perforce/doc.current/manuals/p4dist/chapter.replication.html#replication.verifying
echo if you are also setting up a replica server.
p4 configure set rpl.checksum.auto=1
p4 configure set rpl.checksum.change=2
p4 configure set rpl.checksum.table=1
p4 configure set rpl.compress=3

p4 counter SDP_DATE `date "+%Y-%m-%d"`
p4 counter SDP_VERSION "$SDP_VERSION"

echo -e "\nIt is recommended that you run 'p4 configure set security=3' or\n'p4 configure set security=4'.\nSee: http://www.perforce.com/perforce/doc.current/manuals/p4sag/chapter.superuser.html#DB5-49899\n"

