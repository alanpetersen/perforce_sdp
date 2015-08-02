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
Usage:
	python protect_groups.py remove_groups.txt p4.protect

This script will drop all lines in the protect tabel that have a group referenced from the file
groups.txt passed into the script. The list of groups to drop is passed in as the first parameter
and the protect table is passed in as the 2nd parameter.

remove_groups.txt is generated using protect_groups.py - See that script for details.

Run "p4 protect -o > p4.protect" to generate the protections table.

You can redirect the output of this script to a file called new.p4.protect and then you can compare
the original p4.protect and the new.p4.protect. If everything looks okay, you can update the protections
table by running:

p4 protect -i < new.p4.protect

"""

import os
import re
import string
import sys

p4groups = []

groups = open( sys.argv[1], "r" )
protect = open( sys.argv[2], "r" )

for group in groups.readlines():
	group = group.rstrip()
	group = group.lower()
	p4groups.append( group )

for line in protect.readlines():
	line = line.rstrip()
	origline = line
	line = line.lower()
	match = re.match(".*group (.*) \* .*", line)
	if (match != None):
		if match.group(1).lower() in p4groups:
			continue
		else:
			print(origline)
	else:
		print(origline)
			
groups.close()
protect.close()

