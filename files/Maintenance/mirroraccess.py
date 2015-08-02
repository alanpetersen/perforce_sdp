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
This script will add a user to all the groups of another user in Perforce.

Usage:

	python mirroraccess.py instance user1 user2 <user3> <user4> ... <userN>

user1 = user to mirror access from.
user2 = user to mirror access to.
<user3> ... <userN> = additional users to mirror access to.
"""

import os
import re
import string
import sys
import time
import platform
import ConfigParser

if len (sys.argv) < 4:
  print ("You have to pass three parameters in for this script.")
  print ("The instance number of the server, the User to mirror access from, and the user to mirror access to.")
  sys.exit(1)

SDP_INSTANCE = str(sys.argv[1])

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

######################################################################################################
def main():
	mirroreduser = sys.argv[2]

	os.system ("p4 groups %s > mirror_groups.txt" % (mirroreduser))
	groups = open ("mirror_groups.txt", "r")

	for group in groups.readlines():
		group = group.rstrip()
		os.system ("p4 group -o %s > mirror_group.txt" % (group))
		input = open ("mirror_group.txt", "r")
		output = open ("mirror_newgroup.txt", "w")
		for line in input.readlines():
			if line != "\n":
				output.write (line)
		for newuser in sys.argv[3:]:
			output.write ("\t%s\n" % (newuser))
		input.close ()
		output.close ()
		os.system ("p4 group -i < mirror_newgroup.txt")
		os.remove ("mirror_group.txt")
		os.remove ("mirror_newgroup.txt")

	groups.close ()
	os.remove ("mirror_groups.txt")

######################################################################################################
if __name__ == '__main__':
	main()
