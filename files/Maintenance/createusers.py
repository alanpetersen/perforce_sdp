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
# This script will create a group of users all at once based on an input file.
# The input file should contain the users in the following format, one per line:
# user,email,fullname
#
# Run as python createusers.py userlist.csv

import sys
import os
import re
from subprocess import *
import shutil
import setpass
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

if platform.system() == "Windows": 
  p4="p4.exe -p %s -u %s" % (server, p4user)
else:
  p4="/p4/1/bin/p4_1  -p %s -u %s" % (server, p4user)

os.system('echo %s| %s login' % (passwd, p4))

def loadconfig():
    user = ()
    users = []
    
    usersfile = sys.argv[1]
    
    usersfile = open(usersfile, "r")

    for line in usersfile.readlines():
        user = (re.match("^(.*),(.*),(.*)", line).groups())
#        log("DEBUG", "User %s added." % (user[0]))
        users.append(user)

    if users == []:
        log("ERROR", "No users found in config file.")

    usersfile.close()
    return users

def log(msglevel="DEBUG", message=""):
    if msglevel == "ERROR":
        print(message)
        sys.exit(1)
    else:
        print(message)

def runp4cmd(cmd):
    try:
        pipe = Popen(p4 + cmd, shell=True, stdin=PIPE, stdout=PIPE, universal_newlines=True)
        stdout, stderr = pipe.communicate()
        log("DEBUG", stdout)
        if pipe.returncode != 0:
            log("ERROR", "%s%s generated the following error: %s" % (p4, cmd, stderr))
        else:
            return stdout
    except OSError as err:
        log("ERROR", "Execution failed: %s" % (err))

def process_servers(users):
    """
    Each user line contains three components as follows:
    user,email,full name
    """
    
    file = "user.txt"
    
    for user in users:
        userfile = open(file, "w")
        userfile.write("User:\t%s\nEmail:\t%s\nFullName:\t%s\n" % (user[0], user[1], user[2]))
        userfile.close()
        cmd = "user -f -i < user.txt"
        runp4cmd(cmd)
        os.remove(file)
        setpass.setpassword(user[0])

def main():
    if len(sys.argv) < 1:
        print("This program requires the file containing the list of users as a paramter.\nThe users file should contain 'username,email,full name' 1 per line.")
    users = loadconfig()
    process_servers(users)

if __name__ == "__main__":
    main()
