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
	python protect_groups.py [instance] protect_groups.txt > remove_groups.txt

instance defaults to 1 if not given.

This script will list all the groups mentioned in "p4 protect" that are not a Perforce group.
You need to pull the groups from p4 protect with:

p4 protect -o | grep group |  cut -d " " -f 3 | sort | uniq > protect_groups.txt and pass protect_groups.txt to this script.
"""

import os
import re
import string
import sys
import platform
import ConfigParser

if len(sys.argv) > 1:
  SDP_INSTANCE = str(sys.argv[1])
  protect_groups = sys.argv[2]
else:
  SDP_INSTANCE = '1'
  protect_groups = sys.argv[1]

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

p4groups = []
groupusers = []

def main():
  if len(sys.argv) < 1:
    print("This script requires a file with the list of groups in the protections table as a parameter. See the top of the script for instructions.")

  try:
    for group in os.popen( "%s groups" % p4 ).readlines():
      group = group.rstrip()
      group = group.lower()
      p4groups.append( group )
  except:
    print("Non unicode group name on server. Some group names may have been skipped.")

  input = open( protect_groups, "r" )

  for line in input.readlines():
    line = line.rstrip()
    line = line.lower()
    if line in p4groups:
      continue
    else:
      print(line)
  input.close()

###############################################################################
# main
if __name__ == "__main__":
  main()
