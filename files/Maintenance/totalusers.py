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

import sys
import os
import platform
import re
from subprocess import *
import shutil

case_sensitive = False

if platform.system() == "Windows":
    p4="p4.exe"
else:
    p4="/p4/1/bin/p4_1"

def loadconfig():
    global case_sensitive
    
    robots = set()
    servers = []
    
    cfgfile = open("totalusers.cfg", "r")

    for line in cfgfile.readlines():
        if (re.search("^#", line) or re.search("^\s*$", line)):
            continue

        if re.search("^case_sensitive", line):
            if re.match("^case_sensitive=1.*", line):
                case_sensitive = True
                log("DEBUG", "Operating in case sensitive mode.")
            else:
                log("DEBUG", "Operating in case insensitive mode.")

        if re.search("^ROBOT", line):
            robotuser = (re.match("^ROBOT\|(.*)", line).groups()[0])
            if case_sensitive:
                log("DEBUG", "Robot user %s added." % (robotuser))
                robots.add(robotuser)
            else:
                log("DEBUG", "Robot user %s added." % (robotuser.lower()))
                robots.add(robotuser.lower())

        if re.search("^SERVER", line):
            server = (re.match("^SERVER\|(.*)\|(.*)", line).groups())
            log("DEBUG", "Server %s added." % (server[0]))
            servers.append(server)

    if servers == []:
        log("ERROR", "No servers found in config file.")

    cfgfile.close()
    return servers, robots

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

def process_servers(servers, robots):
    """
    Each server line contains four components as follows:
    SERVER|port|user
    """
    users = []
    useremail = {}
    accesstimes = {}
    userserver = {}

    for server in servers:
        args = " -p %s -u %s " % (server[0], server[1])
        runp4cmd(args + "users > users.txt")
        userfile = open( "users.txt", "r")
        for userline in userfile.readlines():
            user = re.match("(.*) <(.*)> .*accessed (.*)", userline).groups()
            if case_sensitive:
                username = user[0]
            else:
                username = user[0].lower()
                if username not in users and username not in robots:
                   users.append(username)
                   if (user[1] != None):
                        useremail[username] = user[1]
                   else:
                        useremail[username] = username
                   accesstimes[username] = user[2]
                   userserver[username] = server[0]
        userfile.close()
        os.remove("users.txt")
    
    count = 0
    users.sort()
    
    totalusersfile = "totalusers.csv"

    totalusers = open(totalusersfile, "w")
    
    for user in users:
        totalusers.write("%s,%s,%s,%s\n" % (user, useremail[user], accesstimes[user], userserver[user]))
        count += 1

    totalusers.close()
    print("\nTotal number of users: %s" % (count))
    print("User list is in %s" % (totalusersfile))    

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print("This program doesn't accept any arguments. Just update the totalusers.cfg file "
        "and run the program.")
    servers, robots = loadconfig()
    process_servers(servers, robots)
    sys.exit(0)
