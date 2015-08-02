#!/usr/bin/env python
# Copyright (c) 2014 Perforce Software, Inc.  Provided for use as defined in
# the Perforce Consulting Services Agreement.

import argparse
import bcrypt # install from https://code.google.com/p/py-bcrypt/
import ConfigParser
import sys
import getpass
import ldap
import logging
import marshal
import os
from os import remove, close
from shutil import move
from subprocess import Popen, PIPE, STDOUT
from tempfile import mkstemp

CONFIG = ConfigParser.ConfigParser()

# Configuration values
TIMEOUT = 10
LOCAL_PASSWORD_FILE = None
P4 = None
P4PORT = None
P4USER = None
P4TICKETS = None

# p4MarshalCmd
#     executes the p4 command, results sent to a list
def p4MarshalCmd(cmd,quiet=False):
	logging.debug("p4MarshalCmd()")
	env = os.environ.copy()
	# set the P4TICKETS environment variable if supplied
	if(P4TICKETS is not None):
		logging.debug("Setting P4TICKETS={0}".format(P4TICKETS))
		env['P4TICKETS'] = P4TICKETS
	else:
		logging.debug("P4TICKETS unset")

	if not quiet:
		logging.debug("p4 {0}".format(" ".join([P4, "-p", P4PORT, "-u", P4USER, "-G"] + cmd)))
	list = []
	pipe = Popen([P4, "-p", P4PORT, "-u", P4USER, "-G"] + cmd, env=env, stdout=PIPE).stdout
	try:
		while 1:
			record = marshal.load(pipe)
			list.append(record)
	except EOFError:
		pass
	pipe.close()
	return list

# updateLocalPassword
#     adds an entry in the local password file for the specified user account
def updateLocalPassword(username):
	logging.debug("updateLocalPassword()")
	# get the password from the user
	password = getpass.getpass("Enter password (will not appear) > ")
	reenter = getpass.getpass("Type it again (will not appear) > ")
	# check for match
	if(not password == reenter):
		print("Passwords do not match")
		sys.exit(1)
	# encrypt and hash the password
	hashed = bcrypt.hashpw(password, bcrypt.gensalt(10))
	passfileLine = "%s:%s\n"%(username,hashed)
	fh, abs_path = mkstemp()
	new_file = open(abs_path,'w')
	if (not os.path.exists(LOCAL_PASSWORD_FILE)):
		open(LOCAL_PASSWORD_FILE, 'a').close()
	old_file = open(LOCAL_PASSWORD_FILE)
	foundOldEntry = False
	for line in old_file:
		if len(line.strip()) == 0:
			continue
		if line.startswith("%s:"%username):
			new_file.write(passfileLine)
			foundOldEntry = True
		else:
			new_file.write(line)
	if not foundOldEntry:
		new_file.write(passfileLine)
	# close temp file
	new_file.close()
	close(fh)
	old_file.close()
	# Remove original password file
	remove(LOCAL_PASSWORD_FILE)
	# Move new file
	move(abs_path, LOCAL_PASSWORD_FILE)

# localUserExists
#      checks to see if the user exists in the local password file. returns True or False
def localUserExists(username):
	logging.debug("localUserExists()")
	exists = False
	if LOCAL_PASSWORD_FILE is not None and os.path.isfile(LOCAL_PASSWORD_FILE):
		f = open(LOCAL_PASSWORD_FILE)
		for line in f:
			if line.startswith("%s:"%username):
				exists = True
				break
		f.close()
	return exists

# getLocalPassword
#      retrieves the local password entry (if there is one) for the specified user
def getLocalPassword(username):
	logging.debug("getLocalPassword()")
	password = None
	if LOCAL_PASSWORD_FILE is not None and os.path.isfile(LOCAL_PASSWORD_FILE):
		f = open(LOCAL_PASSWORD_FILE)
		for line in f:
			line = line.strip()
			if line.startswith("%s:"%username):
				parts = line.split(":",2)
				password = parts[1]
				break
		f.close()
	return password

# getUserGroups
#      retrieves the list of groups for a user using the p4 groups username command
def getUserGroups(userid):
	logging.debug("getUserGroups()")
	groups = []
	results = p4MarshalCmd(['groups',userid])
	for r in results:
		if b'group' in r:
			groups.append(r.get(b'group').decode("utf-8"))
	return groups

# checkLDAPPassword
#      checks the user and password against the LDAP server
def checkLDAPPassword(userid, password):
	auth_result = 1
	logging.debug("checkLDAPPassword()")
	
	# retrieve the groups to which this user belongs
	groups = getUserGroups(userid)
	if(len(groups) == 0):
		logging.debug("no groups found for {0}... using default".format(userid))
		groups.append(CONFIG.get('globals', 'default.perforce.group'))
	logging.debug("{0} groups: ".format(userid) + ' '.join(groups))
	# the following is needed to allow Python to accept a non-CA cert
	ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
	
	for s in CONFIG.sections():
		if(not s == "globals"):
			try:
				group = CONFIG.get(s, "perforce.group")
				if(group in groups):
					serverURL = CONFIG.get(s, "server.url")
					logging.debug("connecting to server: {0}".format(serverURL))
					acctDomain = CONFIG.get(s, "account.domain")
					# initialize the LDAP connection
					con = ldap.initialize(serverURL)
					# set the timeout value (just in case the server is not responding)
					con.set_option(ldap.OPT_TIMEOUT, TIMEOUT)
					con.set_option(ldap.OPT_NETWORK_TIMEOUT, TIMEOUT)
					try:
						# try to use a simple bind to connect to the server. The benefit
						# of using a simple bind is that we don't need a special search
						# account to retrieve the user's DN
						domainAcct = userid + acctDomain
						# Note, this line will normally work with an AD server if you set
						# acctDomain to the Active Directory Domain Name
						# domainAcct = acctDomain + "\\" + userid
						logging.debug("attempting to bind with {0}".format(domainAcct))
						con.simple_bind_s(domainAcct, password)
						auth_result = 0
					except Exception as e:
						# if bind throws an exception, then access is DENIED
						auth_result = 1
					break
			except:
				continue
	return auth_result

# doAuthenticate
#    main routine for performing the authentication logic
def doAuthenticate(userid):
	logging.debug("doAuthenticate()")
	# this is the main routine for doing the authentication logic

	password = None
	# default behavior is to deny access (return code 1) so let's set 
	# that here and then see if we can prove it wrong
	result = 1
	
	# let's see if we're running in test mode
	if(args.test):
		# since we are in test mode, let's prompt the user for a password
		password = getpass.getpass("Enter password (will not appear) > ")
	else:
		# since we are not in test mode, we read password from STDIN
		# The password is passed to the auth-check trigger by a perforce client when 
		# the user performs a 'p4 login' and is prompted for a password
		password = sys.stdin.read().rstrip() 

	# check to see if the password is empty. since we are using simple LDAP binding
	# we do not want to allow empty passwords, but we really should not allow empty
	# passwords ever anyway.
	if(len(password.strip()) == 0):
		logging.debug("empty password -- rejected")
		return result

	# check to see if the user account exists in the local password file
	# if user exists in local password file, we will not consult LDAP
	if(localUserExists(userid)):
		# get the local password, if there is one
		localPassword = getLocalPassword(userid)
		# user exists in local password file, now check the password by
		# encrypting the supplied password and comparing it to the one
		# retrieved from the local password file
		if(bcrypt.hashpw(password, localPassword) == localPassword):
			result = 0
	else:
		# user doesn't exist in the local password file, so check user in LDAP
		result = checkLDAPPassword(userid, password)
		
	# ok, we're done... return the result
	return result

####### MAIN METHOD #
# this is the main entry point for the script. This is where the magic happens!
if __name__ == '__main__':
	# set up the argument parser and parse the command-line arguments
	parser = argparse.ArgumentParser(description='auth-check trigger implementation.')
	parser.add_argument('-u', '--user', dest='username', default=None, help='the username to authenticate')
	parser.add_argument('-c', '--config', dest='configfile', required=True, help='the configuration file')
	parser.add_argument('-e', '--edit', dest='edit', action='store_true', help='edit the local password file')
	parser.add_argument('-t', '--test', dest='test', action='store_true', help='run in test mode')
	parser.add_argument('-v', '--verbose', dest='verbose', action='store_true', help='override configuration and set logging level to DEBUG')
	args = parser.parse_args()
	
	# set the userid from the command-line arguments
	userid = args.username

	# read the config file specified on the command line
	CONFIG.read(args.configfile)
	
	# read in the information from the configuration file
	LOCAL_PASSWORD_FILE = CONFIG.get('globals', 'passwd.file')
	P4 = CONFIG.get('globals', 'p4.path')
	P4PORT = CONFIG.get('globals', 'p4.port')
	P4USER = CONFIG.get('globals', 'p4.user')
	TIMEOUT = CONFIG.getint('globals', 'timeout')
	try:
		P4TICKETS = CONFIG.get('globals', 'p4.tickets')
	except:
		pass

	# configure the logging level
	logLevel = logging.WARN
	try:
		logLevelStr = CONFIG.get('globals', 'log.level')
		if(logLevelStr == "DEBUG"):
			logLevel = logging.DEBUG
		elif(logLevelStr == "ERROR"):
			logLevel = logging.ERROR
	except:
		pass

	# configure the log file
	logFile = None
	try:
		logFile = CONFIG.get('globals', 'log.file')
	except:
		pass

	if logFile is not None and not args.test:
		logging.basicConfig(filename=logFile, format='%(asctime)s [%(levelname)s] %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logLevel)
	else:
		logging.basicConfig(format='[%(levelname)s] %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logLevel)

	if(args.test):
		# in test mode, we are checking the ability for the script
		# to authenticate a user (or not)
		print("---- TEST MODE ----")
		if(args.username == None):
			userid = raw_input("enter username: ")
		result = doAuthenticate(userid)
		if(result):
			print("Invalid credentials. Access to Perforce would be denied.")
		else:
			print("Credentials were valid. Access to Perforce would be allowed")
	elif(args.edit):
		print("---- EDIT MODE ----")
		if(args.username == None):
			userid = raw_input("enter username: ")
		updateLocalPassword(userid)
	else:
		# doing the authentication for real!
		result = doAuthenticate(userid)
		# now check the result, returning "authentication failed" error if result is not 0
		if (result):
			logging.warning("login failure for user: {0}".format(userid))
			msg = CONFIG.get('globals', 'auth.failed.message')
			print(msg)
		# exit with the result code
		#    0 = access granted
		#    1 = access denied
		sys.exit(result)

	sys.exit(0)
