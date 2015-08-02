#!/usr/bin/python
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

# Based initially on //public/perforce/utils/reviewd/p4review.py#4
#
# Perforce review daemon
#
# This script emails descriptions of new changelists and/or new or modified
# jobs to users who have expressed an interest in them.  Users express
# interest in reviewing changes and/or jobs by setting the "Reviews:" field
# on their user form (see "p4 help user").  Users are notified of changes
# if they review any file involved in that change. Users are notified of
# job updates if they review "//depot/jobs". (This value is configurable
# - see the <jobpath> configuration variable, below).
#
# If run directly with the <repeat> configuration variable = 1, the script
# will sleep for "sleeptime" seconds and then run again.  On UNIX you can
# run the script from cron by setting <repeat> = 0 and adding the following
# line to the cron table with "crontab -e:"
#
#        * * * * * /path/to/p4review.py
#
# This will run the script every minute.  Note that if you use cron you
# should be sure that the script will complete within the time allotted.
#
# The CONFIGURATION VARIABLES below should be examined and in some
# cases changed.
#
#
# Common errors and debugging tips:
#
# -> Error: "command not found" (Windows) or "name: not found" (UNIX) errors.
#
#     - On Windows, check that "p4" is on your PATH or set:
#       p4='"c:/program files/perforce/p4"' (or to the appropriate path).
#       (NOTE the use of " inside the string to prevent interpretation of
#       the command as "run c:/program with arguments files/perforce/p4...")
#
#     - On UNIX, set p4='/usr/local/bin/p4' (or to the appropriate path)
#
# -> Error: "You don't have permission for this operation"
#
#     - Check that the user you set os.environ['P4USER'] to (see below)
#       has "review" or "super" permission via "p4 protect".
#       This user should be able to run "p4 -u username counter test 42"
#       (this sets the value of a counter named "test" to 42)
#
# -> Error: "Unable to connect to SMTP host"
#
#     - check that the mailhost is set correctly - try "telnet mailhost 25"
#       and see if you connect to an SMTP server.  Type "quit" to exit
#
# -> Problem: The review daemon seems to run but you don't get email
#
#     - check the output of "p4 counters" - you should see a counter named
#       "review"
#     - check the output of "p4 reviews -c changenum" for a recent change;
#       if no one is reviewing the change then no email will be sent.
#       Check the setting of "Reviews:" on the user form with "p4 user"
#     - check that your email address is set correctly on the user form
#       (run "p4 reviews" to see email addresses for all reviewers,
#       run "p4 user" to set email address)
#
# -> Problem: Multiple job notifications are sent
#
#     - the script should be run on the same machine as the Perforce
#       server; otherwise time differences between the two machines can
#       cause problems. This is because the job review mechanism uses a
#       timestamp. The change review mechanism uses change numbers, so
#       it's not affected by this problem.


import sys, os, string, re, time, smtplib, traceback
import ConfigParser

config = ConfigParser.RawConfigParser()

#######################################################################
#####                                                             #####
#####  CONFIGURATION VARIABLES: Modify in p4review.cfg as needed. #####
#####                                                             #####

SDP_INSTANCE = sys.argv[1]
config.read('/p4/common/config/p4_%s.p4review.cfg' % (SDP_INSTANCE))

SECTION="1"
debug = int(config.get(SECTION, 'debug'))
administrator = config.get(SECTION, 'administrator')
mailhost = config.get(SECTION, 'mailhost')
repeat = int(config.get(SECTION, 'repeat'))
sleeptime = int(config.get(SECTION, 'sleeptime'))
limit_emails = int(config.get(SECTION, 'limit_emails'))
limit_description = int(config.get(SECTION, 'limit_description'))
notify_changes = int(config.get(SECTION, 'notify_changes'))
notify_jobs = int(config.get(SECTION, 'notify_jobs'))
bcc_admin = int(config.get(SECTION, 'bcc_admin'))
send_to_author = int(config.get(SECTION, 'send_to_author'))
reply_to_admin = int(config.get(SECTION, 'reply_to_admin'))
maildomain = config.get(SECTION, 'maildomain')
complain_from = config.get(SECTION, 'complain_from')
jobpath = config.get(SECTION, 'jobpath')
datefield = config.get(SECTION, 'datefield')
servername = config.get(SECTION, 'servername')

P4PORT = os.environ['P4PORT']

if maildomain == 'None':
    maildomain = None

os.system("/p4/%s/bin/p4_%s login -a < /p4/common/bin/adminpass > /dev/null" % (SDP_INSTANCE, SDP_INSTANCE))
    # This user must have Perforce review privileges (via "p4 protect")

p4 = '/p4/%s/bin/p4_%s' % (SDP_INSTANCE, SDP_INSTANCE)
    # The path of your p4 executable. You can use
    # just 'p4' if the executable is in your path.
    # NOTE: Use forward slashes EVEN ON WINDOWS,
    # since backslashes have a special meaning in Python)

#############                                                    ##########
#############           END OF CONFIGURATION VARIABLES           ##########
#############                                                    ##########
###########################################################################

bcc_admin = bcc_admin and administrator # don't Bcc: None!
if administrator and reply_to_admin:
  replyto_line='Reply-To: '+administrator+'\n'
else:
  replyto_line=''


def complain(mailport,complaint):
  '''
  Send a plaintive message to the human looking after this script if we
  have any difficulties.  If no email address for such a human is given,
  send the complaint to stderr.
  '''
  complaint = complaint + '\n'
  if administrator:
    mailport.sendmail(complain_from,[administrator],\
      'Subject: Perforce Review Daemon Problem\n\n' + complaint)
  else:
    sys.stderr.write(complaint)

def check_length(body):
  '''
  Prevent changelist with descriptions of greater than limit_description
  from being sent.
  '''
  if len(body) > limit_description:
  	truncate_body = """\
  
  ...
  WARNING: Changelist/Job truncated! REASON: Too many characters.
  Raise limit_description value in Review Daemon. To see the full change
  or job description, run 'p4 describe -s <chg#>' or 'p4 job -o <job#>'
  directly against the Perforce server.
  
  """
  	body = body[:limit_description]
	body = body + truncate_body
  return body    

def mailit(mailport, sender, recipients, message):
  '''
  Try to mail message from sender to list of recipients using SMTP object
  mailport.  complain() if there are any problems.
  '''
  if debug:
    if not administrator:
      print 'Debug mode, no mail sent: would have sent mail ' \
            + 'from %s to %s' % (sender,recipients)
      return
    print 'Sending mail from %s to %s (normally would have sent to %s)' \
           % (sender,administrator,recipients)
    message = message + '\nIN DEBUG MODE: would normally have sent to %s' \
              % recipients
    recipients =  administrator      # for testing or initial setup
  try:
    failed = mailport.sendmail(sender, recipients, message)
  except:
    failed = string.join(apply(traceback.format_exception,sys.exc_info()),'')

  if failed:
    complain( mailport, 'The following errors occurred:\n\n' +\
               repr(failed) +\
              '\n\nwhile trying to email from\n' \
              + repr(sender) + '\nto ' \
              + repr(recipients) + '\nwith body\n\n' + message)


def set_counter(mailport,counter,value):
  if debug: print 'setting counter %s to %s' % (counter,repr(value))
  set_result = os.system('%s counter %s %s > /dev/null' % (p4,counter,value))
  if set_result !=0:
    complain(mailport,'Unable to set review counter - check user %s ' \
                       + 'has review privileges\n(use p4 protect)"' \
                       % os.environ['P4USER'])


def parse_p4_review(command,ignore_author=None):
  reviewers_email = []
  reviewers_email_and_fullname = []

  if debug>1: print 'parse_p4_review: %s' % command
  for line in os.popen(command,'r').readlines():
    if debug>1: print line
    # sample line: james <james@perforce.com> (James Strickland)
    #              user   email                fullname
    try:
      (user,email,fullname) = re.match( r'^(\S+) <(\S+)> \((.+)\)$', line).groups()

      if maildomain:      # for those who don't use "p4 user" email addresses
        email= '%s@%s' % (user, maildomain)

      if user != ignore_author:
        reviewers_email.append(email)
        reviewers_email_and_fullname.append('"%s" <%s>' % (fullname,email))
    except:
      print("Error:", sys.exc_info())
      continue

  if debug>1: print reviewers_email, reviewers_email_and_fullname
  return reviewers_email,reviewers_email_and_fullname


def change_reviewers(change,ignore_author=None):
  '''
  For a given change number (given as a string!), return list of
  reviewers' email addresses, plus a list of email addresses + full names.
  If ignore_author is given then the given user will not be included
  in the lists.
  '''
  return parse_p4_review(p4 + ' reviews -c ' + change,ignore_author)


def review_changes(mailport,limit_emails=100):
  '''
  For each change which hasn't been reviewed yet send email to users
  interested in reviewing the change.  Update the "review" counter to
  reflect the last change reviewed.  Note that the number of emails sent
  is limited by the variable "limit_emails"
  '''
  if debug:
    no_one_interested=1
    current_change=int(os.popen(p4 + ' counter change').read())
    current_review=int(os.popen(p4 + ' counter review').read())
    print 'Looking for changes to review after change %d and up to %d.' \
           % (current_review, current_change)

    if current_review==0:
      print 'The review counter is set to zero.  You may want to set\
it to the last change with\n\n  %s -p %s -u %s counter review %d\n\nor \
set it to a value close to this for initial testing. (The -p and -u may \
not be necessary, but they are printed here for accuracy.)'\
% (p4,os.environ['P4PORT'],os.environ['P4USER'],current_change)
  change = None

  for line in os.popen(p4 + ' review -t review','r').readlines():
    # sample line: Change 1194 jamesst <js@perforce.com> (James Strickland)
    #              change #    author   email             fullname
    if debug: print line[:-1]
    try:
      (change,author,email,fullname) = re.match( r'^Change (\d+) (\S+) <(\S+)> \(([^\)]+)\)', line).groups()

      if maildomain: # for those who don't use "p4 user" email addresses
        email= '%s@%s' % (author, maildomain)

      if send_to_author:
        (recipients,recipients_with_fullnames) = change_reviewers(change)
      else:
        (recipients,recipients_with_fullnames) = change_reviewers(change,author)

      if bcc_admin: recipients.append(administrator)

      if debug:
        if recipients:
          no_one_interested=0
          print ' users interested in this change: %s' % recipients
        else:
          print ' no users interested in this change'
      if not recipients: continue  # no one is interested

      message = 'From: ' + fullname + ' <' + email + '>\n' +\
                'To: ' + string.join(recipients_with_fullnames,', ') + '\n' +\
                'Subject: %s:%s change ' % (servername, P4PORT) + change + ' for review\n' +\
                replyto_line +\
                '\n' +\
                check_length(os.popen(p4 + ' describe -s ' + change,'r').read())

      mailit(mailport, email, recipients, message)
      limit_emails = limit_emails - 1
      if limit_emails <= 0:
        break
    except:
      print("Error:", sys.exc_info())
      continue


  if debug and change and no_one_interested:
    print 'No users were interested in any of the changes above - perhaps \
    no one has set the Reviews: field in their client spec?  (please see \
    p4 help user").'

  # if there were change(s) reviewed in the above loop, update the counter
  if change: set_counter(mailport,'review',change)


def job_reviewers(jobname,ignore_author=None):
  '''
  For a given job, return list of reviewers' email addresses,
  plus a list of email addresses + full names.
  If ignore_author is given then the given user will not be included
  in the lists.
  '''
  return parse_p4_review(p4 + ' reviews ' + jobpath,ignore_author)
           # not the most efficient solution...


def review_jobs(mailport,limit_emails=100):
  '''
  For each job which hasn't been reviewed yet send email to users
  interested in reviewing the job.  Update the "jobreview" counter to
  reflect the last time this function was evaluated.  Note that the number
  of emails sent is limited by the variable "limit_emails" - ***currently
  this causes extra job notifications to be dropped...not optimal...
  '''
  start_time = int(os.popen(p4 + ' counter jobreview').read())
  query_time = int(time.time())
  start_time_string = \
     time.strftime('%Y/%m/%d:%H:%M:%S',time.localtime(start_time))
  query_time_string = \
     time.strftime('%Y/%m/%d:%H:%M:%S',time.localtime(query_time))
  query = \
     '%s>%s&%s<=%s' % (datefield, start_time_string, datefield,\
                       query_time_string)

  if debug:
    no_one_interested=1
    print 'Looking for jobs to review after\n%s \
          (%d seconds since 1 Jan 1970 GMT) \
          and up to\n%s (%d seconds since 1 Jan 1970 GMT).' \
          % (start_time_string, start_time, query_time_string, query_time)

  jobname=None

  for line in os.popen(p4 + ' jobs -e "' + query + '"','r').readlines():
    # sample line: job000001 on 1998/08/10 by james *closed* 'comment'
    #              jobname      date          author
    if debug: print line[:-1]
    try:
      (jobname,author) = re.match( r'^(\S+) on \S+ by (\S+)', line).groups()
      match = re.match( r'^\S+\s+<(\S+)>\s+\(([^\)]+)\)', \
      os.popen(p4 + ' users ' + author,'r').read() )
      if match:
        (email,fullname) = match.groups()
        if maildomain:     # for those who don't use "p4 user" email addresses
          email= '%s@%s' % (author, maildomain)
      else:
        email = administrator
        fullname = "Unknown user: " + author
        complain(mailport,'Unkown user %s found in job %s' % (author,jobname))

      if send_to_author:
        (recipients,recipients_with_fullnames) = job_reviewers(jobname)
      else:
        (recipients,recipients_with_fullnames) = job_reviewers(jobname,author)

      if bcc_admin: recipients.append(administrator)

      if debug:
        if recipients:
          no_one_interested=0
          print ' users interested in this job: %s' % recipients
        else:
          print ' no users interested in this job'
      if not recipients: continue  # no one is interested

      message = 'From: ' + fullname + ' <' + email + '>\n' +\
                'To: ' + string.join(recipients_with_fullnames,', ') + '\n' +\
                'Subject: %s:%s job ' % (servername, P4PORT) + jobname + ' for review\n' +\
                replyto_line +\
                '\n'
      job_body = ''
      for line in os.popen(p4 + ' job -o ' + jobname,'r').readlines():
        if line[0] != '#': job_body = job_body + line
      message = message + check_length(job_body)

      mailit(mailport, email, recipients, message)
      limit_emails = limit_emails - 1
      if limit_emails <= 0:
        complain( mailport, 'email limit exceeded in job review \n- extra jobs dropped!')
        break
    except:
      print("Error:", sys.exc_info())
      continue

  if debug and jobname and no_one_interested:
      print 'No users were interested in any of the jobs above - \
             perhaps no one has set the Reviews: field in their client\
             spec to include the "jobpath", namely "%s".  Please see "p4 \
             help user").' % jobpath
  set_counter(mailport,'jobreview',query_time)

def loop_body(mailhost):
  # Note: there's a try: wrapped around everything so that the program won't
  # halt.  Unfortunately, as a result you don't get the full traceback.
  # If you're debugging this script, remove the special exception handlers
  # to get the real traceback, or figure out how to get a real traceback,
  # by importing the traceback module and defining a file object that
  # will take the output of traceback.print_exc(file=mailfileobject)
  # and mail it (see the example in cgi.py)
  if debug: print 'Trying to open connection to SMTP (mail) \
                   server at host %s' % mailhost
  try:
    mailport=smtplib.SMTP(mailhost)
  except:
    sys.stderr.write('Unable to connect to SMTP host "' + mailhost \
                      + '"!\nWill try again in ' + repr(sleeptime) \
                      + ' seconds.\n')
  else:
    if debug: print 'SMTP connection open.'
    try:
      if notify_changes: review_changes(mailport,limit_emails)
      if notify_jobs: review_jobs(mailport,limit_emails)
    except:
      complain(mailport,'Review daemon problem:\n\n%s' % \
                  string.join(apply(traceback.format_exception,\
                  sys.exc_info()),''))
    try:
      mailport.quit()
    except:
      sys.stderr.write('Error while doing SMTP quit command (ignore).\n')


if __name__ == '__main__':
  if debug: print 'Entering main loop.'
  while(repeat):
    loop_body(mailhost)
    if debug: print 'Sleeping for %d seconds.' % sleeptime
    time.sleep(sleeptime)
  else:
    loop_body(mailhost)
  if debug: print 'Done.'
