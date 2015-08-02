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
This script will email users that their clients haven't been accessed in the number of weeks defined
in the weeks variable, and warn them that it will be deleted in one week if they do not use it.
"""

import os
import re
import smtplib
import traceback
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
Your workspace, %s will be unloaded in %s unless you use it to get the lastest
revision of a file. The sync will update the access time, and your
client will not be unloaded.

If your workspace is unloaded, you can reload it with the following command:

p4 reload -c %s

If you need to keep this workspace active:
Just login to Perforce using the workspace, right click any file, and choose the
option "Get Latest Revision".

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
      'Subject: Perforce Email Client Deletion Review Daemon Problem\n\n' + complaint)
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

def mailwarning( client, warningtime, mailport ):
  os.system( '%s client -o "%s" > client.txt' % ( p4, client ) )
  clientfile = open( "client.txt", "r" )
  for clientline in clientfile.readlines():
    m = re.search( r"^Owner:\s(.*)\s", clientline)
    if m:
      owner = m.group(1)
      os.system( '%s user -o "%s" > owner.txt' % (p4, owner) )
      ownerfile = open( "owner.txt", "r" )
      email = owner
      for ownerline in ownerfile.readlines():
        m2 = re.search( "^Email:\s(.*)\s", ownerline )
        if m2:
          email = m2.group(1)
      ownerfile.close()
      os.remove( "owner.txt" )
      subject = "Subject: Client: %s scheduled for deletion." % client
      messagebody = 'From: ' + administrator + '\n' +\
      'To: ' + email + '\n' + subject + '\n' + (message % (client, warningtime, client))
      mailit(mailport, administrator, email, messagebody)
  clientfile.close()
  os.remove( "client.txt" )


def warnusers( weeks1warn, weeks2warn, mailport ):
  clients1warn = []
  clients2warn = []

  accessdates.createlist( "clients", "client", weeks2warn )
  clientlist = open( "clients.txt", "r" )
  for client in clientlist.readlines():
    client = client.rstrip()
    client = re.sub("\$", "\\\$", client)
    clients2warn.append( client )
  clientlist.close()
  os.remove( "clients.txt" )

  accessdates.createlist( "clients", "client", weeks1warn )
  clientlist = open( "clients.txt", "r" )
  for client in clientlist.readlines():
    client = client.rstrip()
    client = re.sub("\$", "\\\$", client)
    if client not in clients2warn:
      clients1warn.append( client )
  clientlist.close()
  os.remove( "clients.txt" )

  for client in clients1warn:
    mailwarning( client, "two weeks", mailport )
  for client in clients2warn:
    mailwarning( client, "one week", mailport )
             

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
			warnusers( weeks1warn, weeks2warn, mailport )
		except:
			complain(mailport,'Client Deletion Review daemon problem:\n\n%s' % \
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
