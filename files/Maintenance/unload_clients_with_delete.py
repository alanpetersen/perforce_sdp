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
This script will unload clients that have not been accessed since the number
of weeks specified in the maintenance.cfg file.

This version of unload clients will delete clients with exclusive checkouts
since unload will not unload those clients.

It also deletes shelves from the clients to be deleted since delete will not
delete a client with a shelf.
"""

import os
import re
import sys
import string
import accessdates
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

###############################################################################
def unload_clients( command, del_command ):
  clients = []

# Generate list of exclusively opened files.
  os.system('%s -ztag opened -a | grep -A 3 "+F*l" > excllist.txt' % (p4))

  if os.path.isfile("excllist.txt"):
    input = open( "excllist.txt", "r" )
    # Create list of clients with exclusively opened files.
    for line in input.readlines():
      line = line.strip()
      if re.search("\.\.\. client ", line):
        client = line[11:]
        client = client.strip()
        clients.append( client )
  
    input.close()
    os.remove( "excllist.txt" )

# Read list of clients to be unloaded.
  if os.path.isfile("clients.txt"):
    clientsfile = open( "clients.txt", "r" )
  
    for client in clientsfile.readlines():
      client = client.rstrip()
      # Deleted clients with exclusively opened files since unload won't unload them.  
      if client in clients:
        # Delete shelves from client
        os.system('%s -Ztag changes -s shelved -c %s > shelved.txt' % (p4, client))
        if os.path.isfile("shelved.txt"):
          shelvedfile = open("shelved.txt", "r")
          for changeline in shelvedfile.readlines():
            if re.search("\.\.\. change ", changeline):
              changenum = changeline[11:]
              changenum = changenum.strip()
              os.system('%s shelve -c %s -df' % (p4, changenum))
          shelvedfile.close()
          os.remove("shelved.txt")
        os.system('%s client -f -d %s' % (p4, client))
      else:
        os.system(('%s unload -f -L -z -c %s') % (p4, client))
  
    clientsfile.close()

###############################################################################
# main
if __name__ == '__main__':
  # Generate list of clients to be unloaded.
  accessdates.createlist( "clients", "client", weeks )
  unload_clients( "clients", "client" )
  os.remove( "clients.txt")

