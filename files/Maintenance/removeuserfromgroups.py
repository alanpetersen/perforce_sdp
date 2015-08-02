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

USAGE = """
This script will look for the specified users in all groups and remove them.

Usage:
  removeuserfromgroups.py [instance] USER
  removeuserfromgroups.py [instance] FILE

USER can be a single username or, it can be a FILE with a list of users.

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

def removeuserfromfile(groupfile, username):
  infile = open (groupfile, "r")
  outfile = open (groupfile + ".new", "w")
  for line in infile.readlines():
    if username.lower() != (line.strip()).lower():
      outfile.write(line)
  infile.close()
  outfile.close()
  os.remove(groupfile)
  newgroupfile = groupfile + ".new"
  os.rename(newgroupfile, groupfile)

def removeuser(username):
  usersgroups = []
  for line in os.popen("%s groups %s" % (p4, username)):
    line = line.strip()
    print("Removing %s from %s" % (username, line))
    groupname = re.sub("/", "_", line)
    groupfile = "%s.group" % groupname
    if not os.path.exists(groupfile):
      os.system ("%s group -o %s > %s" % (p4, line, + groupfile))
    usersgroups.append (line)
    if line not in groups:
      groups.append (line.strip())

  for group in usersgroups:
    groupname = re.sub("/", "_", group)
    groupfile = "%s.group" % groupname
    removeuserfromfile(groupfile, username)

def savegroups():
  print("Saving groups on server")
  for group in groups:
    groupname = re.sub("/", "_", group)
    groupfile = "%s.group" % groupname
    os.system ("%s group -i < %s" % (p4, groupfile))

def cleanup():
  print("Cleaning temp files")
  for group in groups:
    try:
      groupname = re.sub("/", "_", group)
      groupfile = "%s.group" % groupname
      os.remove(groupfile)
    except:
      print("Failed to delete %s." % groupfile)

def automain(userlist):
  global initialized
  initialized = 0
  global groups
  groups = []
  for user in userlist:
    removeuser(user)
  savegroups()
  cleanup()

def main():
  if len (sys.argv) < 2:
    print(USAGE)
    sys.exit (1)

# Handle the optional instance parameter shift
  if len(sys.argv) > 2:
    userorfile=(sys.argv[2])
  else:
    userorfile=(sys.argv[1])		

  global initialized
  initialized = 0
  global groups
  groups = []

  try:
    userlistfile = open( userorfile, "r" )
    for line in userlistfile.readlines():
      line = line.strip()
      if line:
        removeuser(line)
    userlistfile.close()
  except:
    print("No file %s available, assuming it is the actual user name." % userorfile)
    removeuser(userorfile.strip())

  savegroups()
  cleanup()

if __name__ == '__main__':
  main()
