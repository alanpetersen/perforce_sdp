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

#
# This trigger script ensures that 'Map:' field on a depot spec is not the 
# unmodified server default, which stores values under the P4ROOT folder.
# The value is set to the standard SDP location for depot storage, but only
# if the current value is the unmodified server default.
#
# Enable this in the triggers table.  On a Linux server, the entry looks
# like this:
#
#   DepotSpecMapField form-out depot "/p4/common/bin/triggers/SetDefaultDepotSpecMapField.py %formfile% 1"
#
# The second paramter, a 1 (one) in the example above, is the instance number.
# If there are multiple Perforce server instances, this trigger should be
# installed in each instance, with the appropriate instance number.
#
# On a Windows server, the triggers table requires an extra argument.  It looks
# like this:
#
#   DepotSpecMapField form-out depot "python <depotdrive>\p4\common\bin\triggers\SetDefaultDepotSpecMapField.py %formfile% 1 <depotdrive>"
#
# where the second parameter is the instance number, and <depotdrive> is the
# drive letter for your depot volume, such as F:
#
# See 'p4 help triggers' for more info.

from __future__ import print_function

import os
import sys
import re
import random
import platform
import shutil

def cleanexit():
  input.close()
  output.close()
  os.remove(tempfile)
  sys.exit(0)

def argserror():
  print("Invalid number of parameters supplied, see comments for instructions.")
  sys.exit(1)

###############################################################################
# main
if __name__ == "__main__":
  OS = platform.system()
  tempfile = str(random.random())

  if OS == "Windows":
    if len(sys.argv) < 4:
      argserror()
    else:
      DepotDrive = sys.argv[3]
  else:
    if len(sys.argv) < 3:
      argserror()
    else:
      DepotDrive = ""

  DepotSpecFile = sys.argv[1]
  Instance = sys.argv[2]
  mapline = "^Map:\t%s/p4/%s" % (DepotDrive, Instance)
  maptext = r"Map:      %s/p4/%s/depots/" % (DepotDrive, Instance)

  input = open(DepotSpecFile, "r")
  output = open(tempfile, "w")

  for line in input.readlines():
    if re.search("^Depot:\t", line):
      DepotName = re.sub("^Depot:\t", "", line)
      DepotName = DepotName.strip()
    if re.search("^Type:\tremote", line):
      cleanexit()
    if re.search(mapline, line, re.IGNORECASE):
      cleanexit()
    if re.search("^Map:\t", line):
      if not re.search("^Map:\t%s\/\.\.\." % DepotName, line):
        cleanexit()
      line = maptext + DepotName + "/..."
      output.write(line)
    else:
      output.write(line)

  input.close()
  output.close()

  os.remove(DepotSpecFile)
  shutil.copyfile(tempfile, DepotSpecFile)
  os.remove(tempfile)

  sys.exit(0)

