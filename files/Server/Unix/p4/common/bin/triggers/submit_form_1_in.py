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
# This script checks the input of the description form for the path specified in the triggers table.
#
# Trigger table entry:
#	submitform1_in change-submit //depot/somepath/... "/p4/common/bin/triggers/submit_form_1_in.py %changelist% %user%"

import sys
import os
import platform
import re

USAGE = """
This command requires a changelist as the first parameter.
For Example:
  /p4/common/bin/triggers/submit_form_1_in.py %changelist%
"""

###############################################################################
def main():
  ## Confirm we have enough parameters
  if len(sys.argv) < 2:
    print USAGE
    sys.exit (1)

  changelist = sys.argv[1]
  cmd = os.popen("/p4/common/bin/p4master_run 1 /p4/1/bin/p4_1 describe %s" % changelist, "r")
  exitcode = 1

  for line in cmd.readlines():
    match = re.search(r"Incident:\s+(\d+).*", line)
    if match:
      exitcode = 0

  cmd.close()

  if exitcode:
    print("You did not enter a valid Incident.")

  sys.exit(exitcode)

###############################################################################
if __name__ == '__main__':
  main()
