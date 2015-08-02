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
  python checkusers.py

This script will generate a list of all user names that are listed in any group,
but do not have a user account on the server. The results are written to removeusersfromgroups.txt.
You can pass that to removeuserfromgroups.py to do the cleanup.
"""

import os
import re
import string
import sys
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

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

users = []
groupusers = []
groups = []

def main():
  try:
    for user in os.popen( "%s users -a" % p4 ).readlines():
      user = re.sub( r" <.*", r"", user )
      user = user.strip()
      user = user.lower()
      users.append( user )
  except:
    print("Non unicode user name on server. Some user names may have been skipped.")

  for group in os.popen("%s groups" % p4).readlines():
    group = group.strip()
    groups.append(group)

  for group in groups:
    pastOwners = 0
    for user in os.popen("%s group -o %s" % (p4, group)).readlines():
      user = user.strip()
      if re.match(r"Owners:", user):
        pastOwners = 1
        continue
      if pastOwners == 1:
        user = user.lower()
        if user in groupusers:
          continue
        else:
          if not re.search("users:", user):
            if user:
              groupusers.append(user)

  groupusers.sort()

  userfile = open("removeusersfromgroups.txt", "w")

  for groupuser in groupusers:
    if groupuser in users:
      continue
    else:
      userfile.write("%s\n" % groupuser)

  userfile.close()

###############################################################################
# main
if __name__ == "__main__":
  main()
