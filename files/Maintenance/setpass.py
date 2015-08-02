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
This script will set the password for a user to the value set in the password
variable in the main function.

The name of the user to set the password for is passed as a parameter to the file.

Usage:
	python setpass.py [instance] user
	
instance defaults to 1 if not given.
"""

import os
import string
import sys
import time
import platform
from subprocess import *
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
defaultpass = (config.get(SDP_INSTANCE, 'default_user_password'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

if platform.system() == "Windows": 
  p4="p4.exe"
else:
  p4="/p4/1/bin/p4_1"

###############################################################################
def log(msglevel="DEBUG", message=""):
  if msglevel == "TEST":
    print("Running in test mode. Command run would have been:\n", message)
  elif msglevel == "ERROR":
    print(message)
    sys.exit(1)
  elif (verbosity == "3"):
    print(message)
  elif (verbosity == "2" and msglevel == "INFO"):
    print(message)

###############################################################################
def setpassword(user):
  try:
    cmd = ' passwd %s' % (user)
    pipe = Popen(p4 + cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE, universal_newlines=True)
    stderr = pipe.stdin.write(defaultpass)
    pipe.stdin.flush()
    time.sleep(2)
    stderr = pipe.stdin.write(defaultpass)
    pipe.stdin.flush()
    pipe.stdin.close()
    if pipe.wait() != 0:
      log("ERROR", "Password reset failed.\n%s%s generated the following error: %s" % (p4, cmd, stderr))
  except OSError as err:
    log("ERROR", "Execution failed: %s" % (err))

def main():
  if len (sys.argv) < 2:
    print ("Read the usage section at the top of the script for required parameters.")
    sys.exit(1)
  if len(sys.argv) > 2: 
    user = sys.argv[2]
  else:
    user = sys.argv[1]

  setpassword(user)

###############################################################################
if __name__ == '__main__':
  main()
