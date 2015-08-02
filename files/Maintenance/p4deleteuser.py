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

# Usage:
#	p4deleteuser.py [instance] user_to_remove
#	p4deleteuser.py [instance] file_with_users_to_remove
#
# What this scripts does:
#   Removes user and any clients/shelves owned by that user.
#
# instance defaults to 1 if not given.

import os
import sys
import string
import accessdates
import removeuserfromgroups
import re
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
weeks = int(config.get(SDP_INSTANCE, 'weeks'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

sim = 0
clientlist = []

######################################################################################################
def delete_clients (clientlist, sim):
  for client in clientlist:
    print("Deleting Client: %s" % (client))
    if sim == 0:
      client = client.rstrip()
      os.system('%s -Ztag changes -s shelved -c %s > shelved.txt' % (p4, client))
      shelvedfile = open("shelved.txt", "r")
      for changeline in shelvedfile.readlines():
        if re.search("\.\.\. change ", changeline):
          changenum = changeline[11:]
          changenum = changenum.strip()
          os.system('%s shelve -c %s -df' % (p4, changenum))
      os.system('%s client -df -Fs %s' % (p4, client))
      shelvedfile.close()
      os.remove("shelved.txt")

######################################################################################################
def delete_users (userlist, sim):
  for user in userlist:
    print("Deleting User: %s" % user)
    if sim == 0:
      os.system ("%s user -f -d %s" % (p4, user))

######################################################################################################
def get_clients (userlist):
  for user in userlist:
    for line in os.popen('%s clients -u %s' % (p4, user)):
      client = line.split()[1]
      clientlist.append(client)
    for line in os.popen('%s clients -u %s -U' % (p4, user)):
      client = line.split()[1]
      clientlist.append(client)
    for line in os.popen('%s opened -u %s' % (p4, user)):
      client = re.sub('.*\@', '', line)
      client = re.sub('\*exclusive\*', '', client)
      client = re.sub('\*locked\*', '', client)
      client = client.strip()
      if client not in clientlist:
        clientlist.append(client)

######################################################################################################
def cleanup():
  os.remove ('groups.txt')

######################################################################################################
def setup():
  os.system ('%s groups > groups.txt' % p4)

######################################################################################################
def mainbody(userorfile):
  userlist = []
  
  try:
    input = open(userorfile, "r")
  except:
    print("Unable to open file %s assuming it is the username." % userorfile)
    user = userorfile.strip()
    userlist.append(user)
    removeuserfromgroups.automain(userlist)
    get_clients(userlist)
    delete_clients (clientlist, sim)
    delete_users (userlist, sim)
    cleanup()
    sys.exit (0)

  for line in input.readlines():
    line = line.rstrip()
    userlist.append(line)
  
  input.close()

  removeuserfromgroups.automain(userlist)
  get_clients(userlist)
  delete_clients(clientlist, sim)
  delete_users(userlist, sim)
  cleanup()

######################################################################################################
def automain():
  accessdates.createlist("users", "user", weeks)
  setup()
  mainbody("users.txt")

######################################################################################################
def main():
  if len (sys.argv) < 2:
    print("Read the usage section at the top of the script for required parameters.")
    sys.exit(1)

  setup()

# Handle the optional instance parameter shift
  if len(sys.argv) > 2:
    mainbody(sys.argv[2])
  else:
    mainbody(sys.argv[1])

######################################################################################################
if __name__ == '__main__':
  main()
