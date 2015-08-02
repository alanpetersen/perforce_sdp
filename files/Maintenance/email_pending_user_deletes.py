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
This script will email users that their accounts haven't been accessed in the number of weeks defined
in the weeks variable, and warn them that it will be deleted in one week if they do not use it.
"""

import os
import re
import smtplib
import traceback
import sys
import string
import traceback
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
weeks1warn = int(config.get(SDP_INSTANCE, 'weeks1warn'))
weeks2warn = int(config.get(SDP_INSTANCE, 'weeks2warn'))
administrator = config.get(SDP_INSTANCE, 'administrator')
complain_from = config.get(SDP_INSTANCE, 'complain_from')
cc_admin = (config.get(SDP_INSTANCE, 'cc_admin'))
mailhost = config.get(SDP_INSTANCE, 'mailhost')
repeat = int(config.get(SDP_INSTANCE, 'repeat'))
sleeptime = int(config.get(SDP_INSTANCE, 'sleeptime'))

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))


message = """
Your Perforce account hasn't been used in the last %s weeks. It will be deleted
in one week unless you log into Perforce before that time.

Thanks for your cooperation,
The Perforce Admin Team
"""

def complain(mailport,complaint):
  '''
  Send a plaintive message to the human looking after this script if we
  have any difficulties.  If no email address for such a human is given,
  send the complaint to stderr.
  '''
  complaint = complaint + '\n'
  if administrator:
    mailport.sendmail(complain_from,[administrator],\
      'Subject: Perforce User Account Deletion Review Daemon Problem\n\n' + complaint)
  else:
    sys.stderr.write(complaint)

def mailit(mailport, sender, recipient, message):
  '''
  Try to mail message from sender to the user using SMTP object
  mailport.  complain() if there are any problems.
  '''

  recipients = []
  recipients.append(recipient)
  if cc_admin:
    recipients.append(cc_admin)
  
  try:
    failed = mailport.sendmail(sender, recipients, message)
  except:
    failed = string.join(apply(traceback.format_exception,sys.exc_info()),'')

  if failed:
    complain( mailport, 'The following errors occurred:\n\n' +\
               repr(failed) +\
              '\n\nwhile trying to email from\n' \
              + repr(sender) + '\nto ' \
              + repr(recipient) + '\nwith body\n\n' + message)

def warnusers( weeks, mailport ):
  accessdates.createlist( "users", "user", weeks )

  userlist = open( "users.txt", "r" )

  for user in userlist.readlines():
    user = user.rstrip()
    os.system( '%s user -o "%s" > user.txt' % (p4, user))
    userfile = open( "user.txt", "r" )
    for userline in userfile.readlines():
      m2 = re.search( "^Email:\s(.*)\s", userline )
      if m2:
        email = m2.group(1)
    userfile.close()
    subject = "Subject: User: %s scheduled for deletion." % user
    messagebody = 'From: ' + administrator + '\n' +\
    'To: ' + email + '\n' + subject + '\n' + (message % weeks)
    mailit(mailport, administrator, email, messagebody)

  userlist.close()

  if(os.path.isfile("users.txt")):
    os.remove( "users.txt" )
  if(os.path.isfile("user.txt")):
    os.remove( "user.txt" )

def loop_body(mailhost):
# Note: there's a try: wrapped around everything so that the program won't
# halt.  Unfortunately, as a result you don't get the full traceback.
# If you're debugging this script, remove the special exception handlers
# to get the real traceback, or figure out how to get a real traceback,
# by importing the traceback module and defining a file object that
# will take the output of traceback.print_exc(file=mailfileobject)
# and mail it (see the example in cgi.py)
	try:
		mailport=smtplib.SMTP(mailhost)
	except:
		sys.stderr.write('Unable to connect to SMTP host "' + mailhost \
		+ '"!\nWill try again in ' + repr(sleeptime) \
		+ ' seconds.\n')
	else:
		try:
			warnusers( weeks, mailport )
		except:
			complain(mailport,'Client Deletion Warning Review daemon problem:\n\n%s' % \
				string.join(apply(traceback.format_exception, sys.exc_info()),''))
		try:
			mailport.quit()
		except:
			sys.stderr.write('Error while doing SMTP quit command (ignore).\n')

def main():
  while(repeat):
    loop_body(mailhost)
    time.sleep(sleeptime)
  else:
    loop_body(mailhost)

###############################################################################
# main
if __name__ == '__main__':
  main()
