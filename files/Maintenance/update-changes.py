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
        update-changes.py [instance] file_containing_list_of_changes

instance defaults to 1 if not given.

This script simply forces an update on all changelists in the file passed in.

The SetCFOptions-forced.py trigger adds the Type: restricted field on the update.

Generate changes file with:

p4 changes | cut -d " " -f 2 > changes.txt

"""

USAGE = """
Usage:
  update-changes.py [instance] <textfile>
        
textfile should be a file containing 1 changelist number per line.

instance defaults to 1 if not given.
"""

import os
import re
import string
import sys
import time
import platform
import ConfigParser

if len(sys.argv) > 2:
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

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

if len(sys.argv) < 2:
  print (USAGE)
  sys.exit(1)

# Handle optional instance parameter shift.
if len(sys.argv) > 2:
  changes_file = sys.argv[2]
else:
  changes_file = sys.argv[1]

try:
  input = open(changes_file, "r" )
except:
  print("Unable to open file %s." % changes_file )
  sys.exit (2)

for line in input.readlines():
  line = line.rstrip()
  line = '%s change -o "%s" > temp.txt' % (p4, line)
  os.system (line)
  os.system ('%s change -f -i < temp.txt' % p4)

input.close()
os.remove('temp.txt')

