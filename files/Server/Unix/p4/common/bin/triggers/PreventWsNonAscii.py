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
       PreventWSNonASCII form-save client "/p4/common/bin/triggers/PreventWsNonAscii.py %formfile%"

This script is designed to run as a form save trigger on the server.  It will cause
a workspace save to fail if any non-ascii characters are present in the workspace spec.

It also will block odd characters from the workspace name.
"""

import os
import re
import string
import sys

input = open(sys.argv[1], "r")
found = False
allowed = []
allowed.extend(string.whitespace)
allowed.extend(string.punctuation)
allowed.extend(string.digits)
allowed.extend(string.ascii_letters)
pattern =  r"""[^%s]"""
regexp = re.compile(pattern % "".join(allowed))

for line in input.readlines():
    if (re.search(r"^Client:", line) or re.search(r"^Label", line)):
        if re.search(r"[\\!$%^&()<>+=]", line):
            print("\\!$%^&()<>+= not allowed in form name.")
            found = True
            break
    try:
        if re.search(regexp, line.replace("\\","/")):
            print("Non-ASCII characters found in form form: %s" % line)
            found = True
            break
    except:
        print("Non unicode characters in %s" % line)
        found = True
        break

input.close()

if found:
    sys.exit(1)
else:
    sys.exit(0)
