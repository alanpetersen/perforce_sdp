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
This script is normally called by another script, such as archivelabels.py

However, if run standalone, it will generate 4 files with a list of specs
that should be archived based on the number of weeks in maintenance.cfg

The file generated are:

branches.txt
clients.txt
labels.txt
users.txt
"""

import os
import re
import string
import sys
import time
import platform
import ConfigParser

if len(sys.argv) > 1:
  SDP_INSTANCE = str(sys.argv[1])
else:
  SDP_INSTANCE = '1'

config = ConfigParser.RawConfigParser()
config.read('maintenance.cfg')

##########################################################################
#####                                                                #####
#####  CONFIGURATION VARIABLES: Modify in maintenance.cfg as needed. #####
#####                                                                #####

server = (config.get(SDP_INSTANCE, 'server'))
p4user = (config.get(SDP_INSTANCE, 'p4user'))
passwd = (config.get(SDP_INSTANCE, 'passwd'))
weeks = int(config.get(SDP_INSTANCE, 'weeks'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

def log(msglevel="DEBUG", message=""):
  if msglevel == "ERROR":
    print(message)
    sys.exit(1)
  else:
    print(message)

def createlist(command, match_command, weeks):
  now = int(time.time ())
  totalseconds = weeks * 7 * 24 * 60 * 60
  cutoff = now - totalseconds

  command_pattern = re.compile("^\.\.\. %s (.*)" % (match_command), re.IGNORECASE)
  access_pattern = re.compile("^\.\.\. Access (.*)", re.IGNORECASE)

  os.system("%s -Ztag %s > ztag.txt" % (p4, command))
  ztagfile = open("ztag.txt", "r")

  specs = []
  try:
    line = ztagfile.readline()
    while line:
      match = command_pattern.match(line)
      if match != None:
        specname = match.group(1)

      match = access_pattern.match(line)
      if match != None:
         access = match.group(1)
         specs.append("%s,%s" % (access, specname))
      line = ztagfile.readline()
  except:
        log("ERROR", "Non unicode character in ztag.txt")

  ztagfile.close()
  specs.sort()

  finalfile = open("%s.txt" % (command), "w")
  for line in specs:
    splitline = line.split(",")
    if cutoff > int(splitline[0]):
      finalfile.write(splitline[1] + "\n")
  finalfile.close()

  os.remove("ztag.txt")

def main():
  # The final generated file {client,label,user}dates.txt will output a list of
  # {client,label,user}s that have not been accessed in the specified number of
  #  weeks.  Change the second parameter below if you want a different number 
  # of weeks.

  createlist("branches", "branch", weeks)
  createlist("clients", "client", weeks)
  createlist("labels", "label", weeks)
  createlist("users", "user", weeks)

###############################################################################
# main
if __name__ == "__main__":
  main()
