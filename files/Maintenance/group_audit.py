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
# This script emails the owners of each group with instructions on how to validate the membership of the groups they own.
#

import string
import os
import sys
import getopt
import smtplib
from email.mime.text import MIMEText

SDP_INSTANCE = '1'

config = ConfigParser.RawConfigParser()
config.read('maintenance.cfg')

##########################################################################
#####                                                                #####
#####  CONFIGURATION VARIABLES: Modify in maintenance.cfg as needed. #####
#####                                                                #####

fromAddr = config.get(SDP_INSTANCE, 'administrator')
replyToAddr = ''
mailSMTPhost = config.get(SDP_INSTANCE, 'mailhost')
mailSMTPport = int(config.get(SDP_INSTANCE, 'mailport'))
mailsecure = int(config.get(SDP_INSTANCE, 'mailsecure'))
if mailsecure:
  mailUser = config.get(SDP_INSTANCE, 'mailuser')
  mailPass = config.get(SDP_INSTANCE, 'mailpass')

def email_owner(group, owner):
  message = """
  You are the owner of this group: %s

  As the owner, you are expected to audit the group membership on a quarterly basis.

  To edit/review the group membership, open a command prompt and run:

  p4 group -a %s

  Regards,
  Perforce Admin Team
  %s
  """

  for line in os.popen("p4 -ztag user -o %s" % owner):
    if line.startswith(r"... Email"):
      owner_email = line.lstrip(r"... Email ")
      break

  msg = MIMEText(message % (group, group, fromAddr))
  msg['Subject'] = "%s Group Audit Reminder" % group
  msg['From'] = fromAddr
  if(len(replyToAddr)):
    msg.add_header('reply-to', replyToAddr)
  msg['To'] = owner_email

  try:
    # print("Sending mail to: %s" % owner_email)
    s = smtplib.SMTP(mailSMTPhost, mailSMTPport)
    # Uncomment below for secure connections
    # s.starttls()
    # s.login(mailUser, mailPass)
    s.sendmail(msg['From'], msg['To'], msg.as_string())
    s.quit()
  except smtplib.SMTPException:
    print("Error: unable to send email to %s." % msg['To'])

def main():
	for group in os.popen("p4 groups").readlines():
		owners = 0
		group = group.rstrip()
		for line in os.popen("p4 -ztag group -o %s" % group):
			if line.startswith(r"... Users"):
				break
			if line.startswith(r"... Owners"):
				owners = 1
				owner = line.split()[2]
				email_owner(group, owner)
		if not owners:
			print("%s,No owner." % group)

if __name__ == "__main__":
  main()

