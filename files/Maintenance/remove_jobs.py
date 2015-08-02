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
	remove_jobs.py list_of_jobs

This script will remove all of the fixes associated with jobs and then delete
the jobs listed in the file passed as the first argument. The list can be
created with p4 jobs > jobs.txt. The script will handles the extra text one
the lines.
"""

import os
import re
import string
import sys
import time
import platform
import ConfigParser

USAGE = """
Usage:
	remove_jobs.py <textfile>

textfile should be a file containing 1 job per line.
"""

if len (sys.argv) < 2:
 print (USAGE)
 sys.exit(1)

if len(sys.argv) > 2:
  SDP_INSTANCE = str(sys.argv[1])
  jobs_file = sys.argv[2]
else:
  SDP_INSTANCE = '1'
  jobs_file = sys.argv[1]

config = ConfigParser.RawConfigParser()
config.read('maintenance.cfg')

##########################################################################
#####                                                                #####
#####  CONFIGURATION VARIABLES: Modify in maintenance.cfg as needed. #####
#####                                                                #####

server = (config.get(SDP_INSTANCE, 'server'))
p4user = (config.get(SDP_INSTANCE, 'p4user'))
passwd = (config.get(SDP_INSTANCE, 'passwd'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

def main():
  try:
    input = open( jobs_file, "r" )
  except:
    print("Unable to open file %s." % jobs_file)
    sys.exit(2)

  for job in input.readlines():
    job = re.sub(r" on .*", r"", job)
    job = re.sub(r"< ", r"", job)
    job = job.strip()
    command = "%s fixes -j %s > fixes.txt" % (p4, job)
    os.system(command)
    if os.path.isfile("fixes.txt"):
      fixes = open("fixes.txt", "r")
      for fixline in fixes.readlines():
        if re.search("fixed by", fixline):
          match = re.match(".* fixed by change (\d+) on .*", fixline).groups()[0]
          os.system("%s fix -d -c %s %s" % (p4, match, job))
      fixes.close()
    os.system("%s job -d %s" % (p4, job))

  input.close()
  os.remove("fixes.txt")

###############################################################################
# main
if __name__ == "__main__":
  main()
