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

    keep_group_unset form-in group "/p4/common/bin/triggers/keep_group_unset.py %formfile% %user%"

This script is designed to run as a form in trigger on the server. It changes any unlimited
group values to unset.
"""

import os
import re
import sys
import random
import shutil

user = sys.argv[2]
# Exit if the admin user is modifying the form.
if user == "p4admin":
  sys.exit(0)

tempfile = str(random.random())
input = open(sys.argv[1], "r")
output = open(tempfile, "w")
admingroup = False

for line in input.readlines():
# Exit if group being modified is the admin group.
  if re.search(r"^Group:.*admin$", line):
    admingroup = True
    break
  if re.search(r"^Max.*:", line):
    line = re.sub("unlimited", "unset" , line)
  output.write(line)

input.close()
output.close()

if admingroup == False:
  os.remove(sys.argv[1])
  shutil.copy(tempfile, sys.argv[1])

os.remove(tempfile)

sys.exit(0)
