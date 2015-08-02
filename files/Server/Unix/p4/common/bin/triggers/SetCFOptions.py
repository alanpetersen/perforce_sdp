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
Usage:
       SetCFOpts form-out change "python /p4/common/bin/triggers/SetCFOptions.py %formfile%"

This script is designed to run as a form out trigger on a change form.  It
changes the 'Type:' field from 'public' to 'restricted', thus making
changelist metadata (description, etc.) available only to users who have
at least list access on files affected by any given changelist.  It
requires a p4d 2010.2+ server.

This operates only on new changelist forms.

Side Effects: This might have an impact on performance of 'p4 changes'
commands.  It is intended for environments that value security of changelist-
related metadata.
"""

import os
import re
import string
import sys
import random
import shutil

tempfile = str(random.random())
input = open(sys.argv[1], "r")
output = open(tempfile, "w")

for line in input.readlines():
    if re.search ("^Change:", line):
        if not re.search ("^Change:\tnew", line):
            input.close()
            output.close()
            os.remove(tempfile)
            sys.exit(0)
    if re.search ("^Description:", line):
        line = re.sub ("^Description:", "Type:\trestricted\n\nDescription:", line)
    output.write(line)

input.close()
output.close()
os.remove(sys.argv[1])
shutil.copy(tempfile, sys.argv[1])
os.remove(tempfile)

sys.exit(0)
