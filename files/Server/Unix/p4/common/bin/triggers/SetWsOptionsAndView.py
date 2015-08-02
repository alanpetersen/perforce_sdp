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
       SetWsOptsAndView form-out client "/p4/common/bin/triggers/SetWsOptionsAndView.py %formfile%"

This script is designed to run as a form out trigger on the server. It
will:
* Preset the options set in the OPTIONS variable,
* Change the SubmitOption from "submitunchanged" to "leaveunchanged", and
* Initialize the view to something that forces the user to set a reasonable
  default.

Do not use both SetWsOptions.py and SetWsOptionsAndView.py.
"""

import os
import re
import string
import sys
import random
import shutil

# This dictionary is a list of default options paired with the desired options.
# You only need to include the options you want to change.
OPTIONS = {}
OPTIONS["nomodtime"] = "modtime" 
OPTIONS["normdir"] = "rmdir"

tempfile = str(random.random())
input = open(sys.argv[1], "r")
output = open(tempfile, "w")
existing = False

for line in input.readlines():
    if re.search(r"^Access:", line):
        existing = True
        break
    try:
        if re.search(r"^Client:", line):
            ws_name = line.split()[1]

        if re.search(r"^Options:", line):
            for defaultvalue in iter(OPTIONS):
                line = re.sub(defaultvalue, OPTIONS[defaultvalue], line)

        if re.search(r"^SubmitOptions:", line):
            line = re.sub("submitunchanged", "leaveunchanged", line)

        if re.search(r"^View:", line):
            output.write(line)
            output.write("\t//EditMe-AdjustThisPath/... //%s/AndThisPath/..." % ws_name)
            break
        output.write(line)

    except:
        print("Non unicode characters in %s" % line)


input.close()
output.close()

if existing == False:
    os.remove(sys.argv[1])
    shutil.copy(tempfile, sys.argv[1])
os.remove(tempfile)

sys.exit(0)
