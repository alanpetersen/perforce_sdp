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
# This script modifies the description of the change form for the Perforce users listed in the
# submit_form_1_users group.
#
# Trigger table entry:
#	submitform1 form-out change "/p4/common/bin/triggers/submit_form_1.py %formfile% %user%"

import os
import sys
import re

###############################################################################
def main():
  formfile = sys.argv[1]
  triggeruser = sys.argv[2]
  triggeruser = triggeruser.strip()

  desc_repl = """
  Incident:

  Description:

  Reviewed by:
  """

  for group in os.popen("p4 groups -i %s" % (triggeruser)).readlines():
    group = group.strip()
    if (group.find("submit_form_1_users") == 0):
      with open(formfile) as f:
        content = f.read()

      content = content.replace("<enter description here>", desc_repl)

      with open(formfile, "w") as f:
        f.write(content)

  sys.exit(0)

###############################################################################
if __name__ == '__main__':
  main()
