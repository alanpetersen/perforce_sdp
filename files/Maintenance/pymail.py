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

import os
import sys
import getopt
import smtplib
from email.mime.text import MIMEText
import ConfigParser

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

def usage():
  print("pymail.py -t <to-address or address file> -s <subject> -i <input file>")
  sys.exit()

def mail(inputfile, subject, toAddr):
  fp = open(inputfile, 'rb')
  msg = MIMEText(fp.read())
  fp.close()

  msg['Subject'] = subject
  msg['From'] = fromAddr
  if(len(replyToAddr)):
    msg.add_header('reply-to', replyToAddr)
  msg['To'] = toAddr

  try:
    print("Sending mail to: %s" % toAddr)
    s = smtplib.SMTP(mailSMTPhost, mailSMTPport)
    if mailsecure:
      s.starttls()
      s.login(mailUser, mailPass)
    s.sendmail(msg['From'], msg['To'], msg.as_string())
    s.quit()
  except smtplib.SMTPException:
    print("Error: unable to send email to %s." % msg['To'])

def main(argv):
  inputfile = ''
  subject = ''
  toAddr = ''
  addressfile = ''

  try:
    opts, args = getopt.getopt(argv, "ht:s:i:")
  except:
    usage()

  for opt, arg in opts:
    if opt == '-h':
      usage()
    elif opt == '-i':
      inputfile = arg
    elif opt == '-t':
      toAddr = arg
      if os.path.isfile(arg):
        addressfile = arg
    elif opt == '-s':
      subject = arg

  if (len(subject) == 0 or len(toAddr) == 0 or len(inputfile) == 0):
    usage()

  if addressfile:
    addresses = open(addressfile, "r")
    for address in addresses.readlines():
      mail(inputfile, subject, address.strip())
    addresses.close()
  else:
    mail(inputfile, subject, toAddr)

if __name__ == "__main__":
  main(sys.argv[1:])
