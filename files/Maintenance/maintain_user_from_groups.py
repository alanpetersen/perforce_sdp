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

#
# Usage:
#	maintain_user_froup_groups.py [instance]
#
# Defaults to instance 1 if parameter not given.
#
# What this scripts does:
#	Reads users from groups
#	Creates any missing user accounts
#   Removes accounts that are not in the group

# Set this for your environment to get the correct email address for your users.

import os
import os.path
import re
import sys
import string
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
domain = (config.get(SDP_INSTANCE, 'domain'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

clientlist = []
users = []
groupusers = []

###############################################################################
def getusers():
	userfile = open( 'users.txt', 'r' )

	for user in userfile.readlines():
		user = re.sub( r'<.*', r'', user )
		user = user.strip()
		if user:
			users.append(user)
	
	userfile.close()

###############################################################################
def getgroupusers():
	groups = open( 'groups.txt', 'r' )

	for group in groups.readlines():
		group = group.rstrip()
		os.system('%s group -o %s > %s.txt' % (p4, group,group))
		users = open('%s.txt' % group, 'r')
		inusers = 0
		for user in users.readlines():
			user = user.strip()
			if re.search('^Users:', user):
				inusers = 1
				continue
			if inusers:
				if user:
					groupusers.append(user)
		users.close()
		os.remove('%s.txt' % group)
	
	groups.close()
	
###############################################################################
def createuser(user):
	os.system("%s -c %s user -f -o %s > userspec.txt" % (p4, domain, user))
	os.system("%s user -f -i < userspec.txt" % p4)
	os.remove("userspec.txt")

###############################################################################
def get_clients (clientlist, userlist):
	try:
		ztagclients = open ("ztagclients.txt")
	except:
		print ("Unable to open file ztagclients.txt")
		sys.exit (3)

	for line in ztagclients.readlines():
		if line [0:11] == "... client ":
			clientname = line[11:].strip()
		else:
			if line [0:10] == "... Owner ":
				owner = line[10:].strip()
				# If that client is owned by user in userlist, add it to clientlist for deletion
				if (owner in userlist):
					print ("Adding client %s to list for deletion." % (clientname))
					clientlist.append (clientname)
	ztagclients.close()

	try:
		ztagfiles = open ("ztagfiles.txt")
	except:
		print ("Unable to open file ztagfiles.txt")
		sys.exit (3)

	for line in ztagfiles.readlines ():
		if line [0:9] == "... user ":
			username = line[9:].strip()
		else:
			if line[0:11] == "... client ":
				clientname = line[11:].strip()
				# If that client is owned by user in userlist, add it to clientlist for deletion
				if (username in userlist):
					if (clientname in clientlist):
						print ("Client %s already scheduled for deletion." % (clientname))
					else:
						print ("Adding client %s to list for deletion" % (clientname))
						clientlist.append (clientname)
	ztagfiles.close()

###############################################################################
def delete_clients (clientlist):
	for client in clientlist:
		print ("Deleting Client: %s" % (client))
		os.system ("%s client -f -d %s" % (p4, client))

###############################################################################
def delete_users (userlist):
	for user in userlist:
		print ("Deleting User: %s" % (user))
		os.system ("%s user -f -d %s" % (p4, user))

###############################################################################
def cleanup():
	os.remove ('users.txt')
	os.remove ('groups.txt')
	os.remove ('ztagclients.txt')
	os.remove ('ztagfiles.txt')

###############################################################################
def setup():
	os.system ('%s users > users.txt' % p4)
	os.system ('%s groups > groups.txt' % p4)
	os.system ('%s -Ztag clients > ztagclients.txt' % p4)
	os.system ('%s -Ztag opened -a > ztagfiles.txt' % p4)

###############################################################################
def main():
	removeusers = []
	addusers = []

	setup()
	getusers()
	getgroupusers()

	for user in users:
		if user not in groupusers:
			removeusers.append(user)
			print('Adding user %s to removeusers' % user)

	for user in groupusers:
		if user not in users:
			addusers.append(user)
			print('Adding user %s to addusers' % user)

	get_clients (clientlist, removeusers)
	delete_clients (clientlist)
	delete_users (removeusers)

	for user in addusers:
		createuser(user)
	
	cleanup()

###############################################################################
if __name__ == '__main__':
	main()

