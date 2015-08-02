#!/usr/bin/env python
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

"""
This script makes sure that all Perforce users are in the limits group.
"""

import sys, os, string, re

instance=sys.argv[1]

os.system("/p4/common/bin/p4master_run %s /p4/common/bin/p4login" % instance)
os.system("/p4/common/bin/p4master_run %s /p4/%s/bin/p4_%s group -o limits > %s_limits.txt" % (instance, instance, instance, instance))
os.system("/p4/common/bin/p4master_run %s /p4/%s/bin/p4_%s users > %s_users.txt" % (instance, instance, instance, instance))

users = open("%s_users.txt" % instance, "r")

limits = open("%s_limits.txt" % instance, "r")
output = open("%s_newlimits.txt" % instance, "w")

userlist = []

for user in users.readlines():
        user = re.sub( r"<.*", r"", user )
        user = user.strip()
        if user != "":
                userlist.append(user)

users.close()

for line in limits.readlines():
        if line != "\n":
                output.write(line)

limits.close()

for user in userlist:
        output.write("\t%s\n" % user)

output.close()

os.system("/p4/common/bin/p4master_run %s /p4/%s/bin/p4_%s group -i < %s_newlimits.txt > /dev/null" % (instance, instance, instance, instance))

os.remove("%s_users.txt" % instance)
os.remove("%s_limits.txt" % instance)
os.remove("%s_newlimits.txt" % instance)


