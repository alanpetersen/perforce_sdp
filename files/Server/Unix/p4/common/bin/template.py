#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""@template.py PythonScriptTemplate
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
template.py - Python script template.  EDITME

"""

# Python 2.7/3.3 compatibility.
from __future__ import print_function

import sys

# Python 2.7/3.3 compatibility.
if sys.version_info[0] >= 3:
   from configparser import ConfigParser
else:
   from ConfigParser import ConfigParser

import argparse
import textwrap
import os.path
from datetime import datetime
import logging

DEFAULT_CFG_FILE='template.py.cfg'
DEFAULT_LOG_FILE='template.log'
DEFAULT_VERBOSITY='INFO'

LOGGER_NAME = 'template.py'
DEFAULTS_SECTION = 'Defaults'

class Main:
   """ EDITME Documentation for MyClass.
   EDITME
   """

   def __init__(self, *argv):
      """ Initialization.  Process command line argument and initialize logging.
      """
      parser = argparse.ArgumentParser(
         formatter_class=argparse.RawDescriptionHelpFormatter,
         description=textwrap.dedent('''\
            NAME
         
            template.py
            
            VERSION
            
            1.0.0
            
            DESCRIPTION
            
            EDITME - Describe this script.
            
            EXAMPLES
            
            EXIT CODES
            
            Zero indicates normal completion.  Non-zero indicates an error.
            
            '''),
         epilog="Copyright (c) 2008-2015 Perforce Software, Inc.  Provided for use as defined in the Perforce Consulting Services Agreement."
      )
      
      parser.add_argument('first', help="First positional arg.")
      parser.add_argument('second', help="Second positional arg.")
      #parser.add_argument('-r', '--reqarg', nargs='?', action='store_true', required=True, help="Sample required \(positional\) argument.")
      parser.add_argument('-n', '--NoOp', action='store_true', help="Take no actions that affect data (\"No Operation\").")
      parser.add_argument('-c', '--config', default=DEFAULT_CFG_FILE, help="Config file, relative or absolute path. Default: " + DEFAULT_CFG_FILE)
      parser.add_argument('-L', '--log', default=DEFAULT_LOG_FILE, help="Default: " + DEFAULT_LOG_FILE)
      parser.add_argument('-v', '--verbosity', 
         nargs='?', 
         const="INFO",
         default=DEFAULT_VERBOSITY,
         choices=('DEBUG', 'WARNING', 'INFO', 'ERROR', 'FATAL') ,
         help="Output verbosity level. Default is: " + DEFAULT_VERBOSITY)
      
      self.myOptions = parser.parse_args()
      
      self.logger = logging.getLogger(LOGGER_NAME)
      self.logger.setLevel(self.myOptions.verbosity)
      h = logging.StreamHandler()
      # df = datestamp formatter; bf= basic formatter.
      df = logging.Formatter('%(asctime)s %(levelname)s: %(message)s', datefmt='%m/%d/%Y %H:%M:%S')
      bf = logging.Formatter('%(levelname)s: %(message)s')
      h.setFormatter(bf)
      self.logger.addHandler (h)

      self.logger.debug ("Command Line Options: %s\n" % self.myOptions)
      
      if (self.myOptions.NoOp):
         self.logger.info ("Running in NO OP mode.")

   def readConfig(self):
      self.parser = ConfigParser()
      self.myOptions.parser = self.parser    # for later use

      try:
         self.parser.readfp(open(self.myOptions.config))

      except:
         self.logger.warn ('Could not read config file [%s].  Ignoring it.' % self.myOptions.config)
         return False

      if self.parser.has_section(DEFAULTS_SECTION):
         if self.parser.has_option(DEFAULTS_SECTION, "MyVar"):
            myVar = self.parser.get(DEFAULTS_SECTION, "MyVar")
            self.logger.debug ('MyVar value is [%s].' % myVar)
            self.logger.debug ('Loaded data from config file [%s].' % self.myOptions.config)
      else:
         self.logger.fatal ('No [%s] section in config file.  Aborting.' % DEFAULTS_SECTION)
         return False

      return True
      

   def sample(self):
      """Sample Method"""
      self.readConfig()

      self.logger.info ("Processing...")

if __name__ == '__main__':
   """ Main Program
   """
   main = Main(*sys.argv[1:])
   Main.sample(main)
