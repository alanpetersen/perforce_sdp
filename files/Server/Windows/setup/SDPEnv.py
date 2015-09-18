# SDPEnv.py
# Utilities for creating or validating an environment based on a master configuration file

#------------------------------------------------------------------------------
# Copyright (c) Perforce Software, Inc., 2007-2014. All rights reserved
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

from __future__ import print_function

import os
import os.path
import sys
import subprocess
import socket
import shutil
import glob
import re
import textwrap
import logging
import argparse
import hashlib
import stat
import datetime
from collections import defaultdict

# Python 2.7/3.3 compatibility.
python3 = sys.version_info[0] >= 3

if python3:
    from configparser import ConfigParser
    from io import StringIO
else:
    from ConfigParser import ConfigParser
    from StringIO import StringIO

MODULE_NAME = 'SDPEnv'
DEFAULT_CFG_FILE = 'sdp_master_config.ini'
DEFAULT_LOG_FILE = '%s.log' % MODULE_NAME
DEFAULT_VERBOSITY = 'INFO'
DEFAULT_SDP_GLOBAL_ROOT = r'c:'

LOGGER_NAME = '%s.log' % MODULE_NAME

# Default values when configuring a new server
TEMPLATE_SERVER_CONFIGURABLES = "template_configure_new_server.bat"

class SDPException(Exception):
    "Base exceptions"
    pass
class SDPConfigException(SDPException):
    "Exceptions in config"
    pass

def readTemplateServerConfigurables():
    """Returns the file as a list, with only the interesting lines"""
    path = os.path.join(os.path.dirname(__file__), TEMPLATE_SERVER_CONFIGURABLES)
    with open(path) as fh:
        lines = [line.strip() for line in fh.readlines()]
        result = [line for line in lines if not line.startswith("::")]
        return result

def copy_file(sourcefile, dest):
    "Handle if target is read-only"
    destfile = dest
    if os.path.isdir(dest):
        destfile = os.path.join(dest, os.path.basename(sourcefile))
    if os.path.exists(destfile):
        os.chmod(destfile, stat.S_IWRITE)
    shutil.copy(sourcefile, destfile)

def remove_config_whitespace(config_filename):
    separator = "="
    with open(config_filename, "r") as fh:
        lines = fh.readlines()
    fp = open(config_filename, "w")
    for line in lines:
        line = line.strip()
        if not line.startswith("#") and separator in line:
            assignment = line.split(separator, 1)
            assignment = [x.strip() for x in assignment]
            fp.write("%s%s%s\n" % (assignment[0], separator, assignment[1]))
        else:
            fp.write(line + "\n")

def merge_configs(src_filename, dest, config_data=None):
    """Merge the specified values in the config files"""
    dest_filename = dest
    if os.path.isdir(dest):
        dest_filename = os.path.join(dest, os.path.basename(src_filename))
    src_config_file = open(src_filename)
    dest_config_file = open(dest_filename)
    src_config = ConfigParser()
    dest_config = ConfigParser()
    if python3:
        src_config.read_file(src_config_file)
        dest_config.read_file(dest_config_file)
    else:
        src_config.readfp(src_config_file)
        dest_config.readfp(dest_config_file)
    for src_section in src_config.sections():
        if not dest_config.has_section(src_section):
            dest_config.add_section(src_section)
        for name, value in src_config.items(src_section):
            dest_config.set(src_section, name, value)
    dest_config_file.close()
    with open(dest_filename, "w") as dest_config_file:
        dest_config.write(dest_config_file)
    remove_config_whitespace(dest_filename)

def file_md5(filename):
    m = hashlib.md5()
    with open(filename, mode = 'rb') as fh:
        contents = fh.read()
        m.update(contents)
        return m.digest()

def contents_md5(contents):
    m = hashlib.md5()
    if python3:
        m.update(contents.encode())
    else:
        m.update(contents)
    return m.digest()

def files_different(src, dest, src_contents=None):
    "Decide if source and dest are different - note dest might be a dir"
    if not os.path.exists(dest):
        return True
    destfile = dest
    if os.path.isdir(dest):
        destfile = os.path.join(dest, os.path.basename(src))
    if not os.path.exists(destfile):
        return True
    if src_contents:
        md5src = contents_md5(src_contents.replace("\n", "\r\n"))
    else:
        md5src = file_md5(src)
    md5dest = file_md5(destfile)
    return md5src != md5dest

def joinpath(root, *path_elts):
    "Deals with drive roots or a full path as the root"
    if len(root) > 0 and root[-1] == ":":
        return os.path.join(root, os.sep, *path_elts)
    else:
        return os.path.join(root, *path_elts)

def running_as_administrator():
    "Makes sure current process has admin rights"
    output = ""
    try:
        output = subprocess.check_output("net session", universal_newlines=True,
                                    stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as e:
        output = e.output
    return not re.search(r"Access is denied", output)

def mklink(linkname, target):
    "Create the specified link"
    output = ""
    try:
        output = subprocess.check_output('mklink /d "%s" "%s"' % (linkname, target),
                                    universal_newlines=True,
                                    stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as e:
        output = e.output
    except UnicodeDecodeError as e: 
        raise SDPException("Unicode error calling subprocess - if using Python 3 then consider setting code page: chcp 850")
    if not os.path.exists(linkname):
        raise SDPException("Error creating link '%s' to '%s':\n%s" % (
                linkname, target, output))

def find_record(rec_list, key_field, search_key):
    "Returns dictionary found in list of them"
    for rec in rec_list:
        if rec[key_field].lower() == search_key.lower():
            return rec
    return None

def rtrim_slash(dir_path):
    "Remove trailing slash if it exists"
    if dir_path[-1] == os.sep:
        dir_path = dir_path[:-1]
    return dir_path

class SDPInstance(object):
    "A single instance"

    def __init__(self, config, section, options):
        "Expects a configparser"
        self._attrs = {}
        self.options = options
        def_dir_attrs = ('sdp_global_root metadata_root depotdata_root logdata_root').split()
        def_attrs = ('sdp_serverid sdp_service_type sdp_p4port_number '
                     'sdp_p4superuser_password remote_depotdata_root').split()
        def_attrs.extend(def_dir_attrs)
        for def_attr in def_attrs:
            self._attrs[def_attr] = ""
        if not ":" in section:
            raise SDPConfigException("Section names must be of format [<SDP_INSTANCE>:<SDP_HOSTNAME>]")
        sdp_instance, sdp_hostname = section.split(":")
        default_hostname = "__OUTPUT_OF_HOSTNAME_COMMAND_ON_SERVER_PLEASE_UPDATE__"
        current_hostname = socket.gethostname()
        if sdp_hostname.upper() == default_hostname:
            msg = "Section name '%s' still contains default value\n" % section
            msg += "Please change hostname (after colon) to real value,\n"
            msg += "e.g. current machine hostname:\n    '%s'" % current_hostname
            raise SDPConfigException(msg)            
        self._attrs['sdp_instance'] = sdp_instance
        self._attrs['sdp_hostname'] = sdp_hostname
        for item in config.items(section):
            if item[0] in def_dir_attrs:
                self._attrs[item[0]] = rtrim_slash(item[1])
            else:
                self._attrs[item[0]] = item[1]
        self._init_dirs()

    def __iter__(self):
        return self._attrs.__iter__()

    def _init_dirs(self):
        """Initialises directory names for this instance"""
        curr_scriptdir = os.path.dirname(os.path.realpath(__file__))
        self._attrs["sdp_global_root_dir"] = DEFAULT_SDP_GLOBAL_ROOT
        if 'sdp_global_root' in self._attrs and len(self.sdp_global_root) > 0:
            self._attrs["sdp_global_root_dir"] = self.sdp_global_root
        self._attrs["installer_sdp_common_bin_dir"] = os.path.abspath(os.path.join(curr_scriptdir, '..', 'p4', 'common', 'bin'))
        # These dirs contain links as part of them
        self._attrs["instance_dir"] = joinpath(self.sdp_global_root_dir, 'p4', self.sdp_instance)
        self._attrs["bin_dir"] = joinpath(self.instance_dir, 'bin')
        self._attrs["common_dir"] = joinpath(self.sdp_global_root_dir, 'p4', 'common')
        self._attrs["common_bin_dir"] = joinpath(self.common_dir, 'bin')
        self._attrs["root_dir"] = joinpath(self.instance_dir, 'root')
        self._attrs["checkpoints_dir"] = joinpath(self.instance_dir, 'checkpoints')
        self._attrs["logs_dir"] = joinpath(self.instance_dir, 'logs')
        self._attrs["sdp_config_dir"] = joinpath(self.sdp_global_root_dir, 'p4', 'config')

    def links_and_dirs(self):
        """return things in order - real directories before the links to them"""
        metadata_instance = joinpath(self.metadata_root, 'p4', self.sdp_instance)
        depotdata_instance = joinpath(self.depotdata_root, 'p4', self.sdp_instance)
        logdata_instance = joinpath(self.logdata_root, 'p4', self.sdp_instance)
        return([
                (None, joinpath(self.sdp_global_root_dir, 'p4')),
                (None, metadata_instance),
                (self.instance_dir, depotdata_instance),
                (None, logdata_instance),
                (self.common_dir, joinpath(self.depotdata_root, 'p4', 'common')),
                (self.sdp_config_dir, joinpath(self.depotdata_root, 'p4', 'config')),
                (None, self.common_bin_dir),
                (None, joinpath(self.common_bin_dir, 'triggers')),
                (None, self.bin_dir),
                (None, joinpath(self.instance_dir, 'tmp')),
                (None, joinpath(self.instance_dir, 'depots')),
                (None, joinpath(self.instance_dir, 'checkpoints')),
                (None, joinpath(self.instance_dir, 'ssl')),
                (self.root_dir, joinpath(metadata_instance, 'root')),
                (None, joinpath(self.root_dir, 'save')),
                (joinpath(self.instance_dir, 'offline_db'), joinpath(metadata_instance, 'offline_db')),
                (self.logs_dir, joinpath(logdata_instance, 'logs'))
                ])

    def __getitem__(self, name):
        return object.__getattribute__(self, '_attrs').get(name)

    def is_current_host(self):
        """Checks against current hostname"""
        return socket.gethostname().lower() == self._attrs["sdp_hostname"].lower()

    def is_specified_instance(self):
        """Checks against global options"""
        if not self.options.specified_instance:
            return True
        return self.options.specified_instance.lower() == self._attrs["sdp_instance"].lower()

    def __getattribute__(self, name):
        """Only allow appropriate attributes"""
        if name in ["_attrs", "_init_dirs", "get", "is_current_host", "is_specified_instance", "options", "links_and_dirs"]:
            return object.__getattribute__(self, name)
        else:
            if not name in object.__getattribute__(self, '_attrs'):
                raise AttributeError("Unknown attribute '%s'" % name)
            return object.__getattribute__(self, '_attrs').get(name, "")


class SDPConfig(object):
    """The main class to process SDP configurations"""

    def __init__(self, config_data=None, logStream=None):
        self.config = None
        if logStream is None:
            logStream = sys.stdout
        self.instances = {}
        self.commands = []  # List of command files to run - and their order
        self.options = None
        self.parse_args()
        self.logger = logging.getLogger(LOGGER_NAME)
        self.logger.setLevel(logging.INFO)
        h = logging.StreamHandler(logStream)
        bf = logging.Formatter('%(levelname)s: %(message)s')
        h.setFormatter(bf)
        self.logger.addHandler(h)
        self.logger.debug("Command Line Options: %s\n" % self.options)
        self._read_config(self.options.config_filename, config_data)

    def parse_args(self):
        parser = argparse.ArgumentParser(
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=textwrap.dedent('''\
            NAME

                SDPEnv.py

            VERSION

                1.0.0

            DESCRIPTION

                Create the environment for an SDP (Server Deployment Package)

            EXAMPLES

                SDPEnv.py --help

            '''),
            epilog="Copyright (c) 2008-2014 Perforce Software, Inc.  "
                "See LICENSE file for legal information and disclaimers."
        )
        parser.add_argument('-y', '--yes', action='store_true',
                            help="Perform actual changes such as directory creation and file copying."
                            "Without this flag the tool is effectively in reporting mode only.")
        parser.add_argument('-c', '--config_filename', default=DEFAULT_CFG_FILE,
                            help="Master config file, relative or absolute path. Default: " + DEFAULT_CFG_FILE)
        parser.add_argument('-i', '--instance', dest='specified_instance',
                            help="Configure specified instance only (ignoring others specified in master config file). "
                            "Useful for adding a new instance to an existing configuration.")
        self.options = parser.parse_args()

    def _read_config(self, config_filename, config_data):
        """Read the configuration file"""
        if config_data:  # testing
            config_file = StringIO(config_data)
        else:
            if not os.path.exists(config_filename):
                raise SDPException("Master config file not found: '%s'" % config_filename)
            config_file = open(config_filename)
        self.config = ConfigParser()
        if python3:
            self.config.read_file(config_file)
        else:
            self.config.readfp(config_file)
        self.logger.info("Found the following sections: %s" % self.config.sections())
        for section in self.config.sections():
            self.instances[section] = SDPInstance(self.config, section, self.options)

    def isvalid_config(self):
        """Check configuration read is valid"""
        required_options = ("sdp_serverid sdp_service_type sdp_hostname sdp_instance sdp_p4port_number "
                            "metadata_root depotdata_root logdata_root").split()
        errors = []
        specified_instance_found = False
        for instance_name in self.instances.keys():
            missing = []
            fields = {}
            instance = self.instances[instance_name]
            if instance.is_specified_instance():
                specified_instance_found = True
            # Check for require fields
            for opt in required_options:
                if instance[opt] == "":
                    missing.append(opt)
                else:
                    fields[opt] = instance[opt]
            if missing:
                errors.append("The following required options are missing '%s' in instance '%s'" % (
                        ", ".join(missing), instance_name))
            # Check for numeric fields
            field_name = "sdp_p4port_number"
            if field_name in fields:
                if not instance[field_name].isdigit():
                    errors.append("%s must be numeric in instance '%s'" % (field_name.upper(), instance_name))
            # Check for restricted values
            field_name = "sdp_service_type"
            if field_name in fields:
                valid_service_types = "standard replica forwarding-replica build-server".split()
                if not instance[field_name] in valid_service_types:
                    errors.append("%s must be one of '%s' in instance '%s'" % (field_name.upper(),
                                ", ".join(valid_service_types), instance_name))
            # Replicas should specify a couple of fields
            replica_types = "replica forwarding-replica build-server".split()
            if instance.sdp_service_type in replica_types:
                for field_name in ["remote_depotdata_root"]:
                    if instance[field_name] == "":
                        errors.append("Field %s must have a value for replica instance '%s'" % (field_name.upper(),
                                    instance_name))
        if self.options.specified_instance and not specified_instance_found:
            errors.append("Instance '%s' specified but not found in the config file" % self.options.specified_instance)
        if errors:
            raise SDPConfigException("\n".join(errors))
        return True

    def get_master_instance_name(self):
        """Assumes valid config"""
        #TODO - this assumes only one standard section
        for instance_name in self.instances:
            if self.instances[instance_name]["sdp_service_type"] == "standard":
                return instance_name
        raise SDPConfigException("No master section found")

    def write_master_config_ini(self):
        """Write the appropriate configure values"""
        common_settings = """sdp_serverid sdp_p4serviceuser
                sdp_global_root
                sdp_p4superuser admin_pass_filename
                mailfrom maillist mailhost
                python remote_depotdata_root
                keepckps keeplogs limit_one_daily_checkpoint""".split()
        instance_names = self.instances.keys()
        master_name = self.get_master_instance_name()
        master_instance = self.instances[master_name]
        lines = []
        lines.append("# Global sdp_config.ini")
        lines.append("")
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            if not instance.is_specified_instance():
                continue
            lines.append("\n[%s:%s]" % (instance.sdp_instance, instance.sdp_hostname))
            lines.append("%s=%s:%s" % ("p4port", instance.sdp_hostname, instance.sdp_p4port_number))
            for setting in common_settings:
                lines.append("%s=%s" % (setting, instance[setting]))
            if instance.sdp_service_type in ["replica", "forwarding-replica", "build-server"]:
                lines.append("remote_sdp_instance=%s" % (master_instance.sdp_instance))
                lines.append("p4target=%s:%s" % (master_instance.sdp_hostname,
                                                 master_instance.sdp_p4port_number))

        sdp_config_file = "sdp_config.ini"
        self.commands.append(sdp_config_file)
        self.logger.info("Config file written: %s" % sdp_config_file)
        with open(sdp_config_file, "w") as fh:
            for line in lines:
                fh.write("%s\n" % line)

    def get_configure_bat_contents(self, templateLines=None):
        """Return the information to be written into configure bat files per instance"""
        if templateLines is None:
            templateLines = readTemplateServerConfigurables()
        cmd_lines = {}   # indexed by instance name
        instance_names = self.instances.keys()
        master_instance_name = self.get_master_instance_name()
        master_instance = self.instances[master_instance_name]
        master_id = master_instance.sdp_serverid
        cmd_lines[master_id] = []

        p4cmd = "p4 -p %s:%s -u %s" % (master_instance.sdp_hostname, master_instance.sdp_p4port_number,
                                                      master_instance.sdp_p4superuser)
        p4configurecmd = "%s configure set" % (p4cmd)
        if master_instance.is_specified_instance():
            path = joinpath(master_instance.checkpoints_dir, "p4_%s" % master_instance.sdp_instance)
            cmd_lines[master_id].append("%s %s#journalPrefix=%s" % (p4configurecmd, master_instance.sdp_serverid, path))

            for line in [x.strip() for x in templateLines]:
                if line:
                    newLine = line.replace("p4 configure set", p4configurecmd)
                    if newLine.startswith("p4 counter SDP"):
                        newLine = '%s counter SDP "%s"' % (p4cmd, datetime.date.today().isoformat())
                    cmd_lines[master_id].append(newLine)

        # Now set up all the config variables for replication
        for instance_name in [s for s in instance_names if s != master_id]:
            instance = self.instances[instance_name]
            if not instance.is_specified_instance():
                continue
            if not instance.sdp_service_type in ["replica", "forwarding-replica", "build-server"]:
                continue
            path = joinpath(instance.checkpoints_dir, "p4_%s" % instance.sdp_instance)
            cmd_lines[master_id].append("%s %s#journalPrefix=%s" % (p4configurecmd, instance.sdp_serverid, path))
            cmd_lines[master_id].append('%s %s#P4TARGET=%s:%s' % (p4configurecmd, instance.sdp_serverid,
                                                   master_instance.sdp_hostname,
                                                   master_instance.sdp_p4port_number))
            tickets_path = joinpath(instance.instance_dir, "p4tickets.txt")
            cmd_lines[master_id].append('%s %s#P4TICKETS=%s' % (p4configurecmd, instance.sdp_serverid, tickets_path))
            log_path = joinpath(instance.logs_dir, "%s.log" % instance.sdp_serverid)
            cmd_lines[master_id].append('%s %s#P4LOG=%s' % (p4configurecmd, instance.sdp_serverid, log_path))
            cmd_lines[master_id].append('%s "%s#startup.1=pull -i 1"' % (p4configurecmd, instance.sdp_serverid))
            for i in range(2, 6):
                cmd_lines[master_id].append('%s "%s#startup.%d=pull -u -i 1"' % (p4configurecmd, instance.sdp_serverid, i))
            cmd_lines[master_id].append('%s %s#lbr.replication=readonly' % (p4configurecmd, instance.sdp_serverid))
            if instance.sdp_service_type in ["replica", "build-server", "forwarding-replica"]:
                cmd_lines[master_id].append('%s %s#db.replication=readonly' % (p4configurecmd, instance.sdp_serverid))
            if instance.sdp_service_type in ["forwarding-replica"]:
                cmd_lines[master_id].append('%s %s#rpl.forward.all=1' % (p4configurecmd, instance.sdp_serverid))
            cmd_lines[master_id].append('%s %s#serviceUser=%s' % (p4configurecmd, instance.sdp_serverid, instance.sdp_serverid))
        return cmd_lines

    def write_configure_bat_contents(self, cmd_lines):
        "Write the appropriate configure bat files for respective instances"
        command_files = []
        for instance_name in cmd_lines.keys():
            command_file = "configure_%s.bat" % (instance_name)
            command_files.append(command_file)
            with open(command_file, "w") as fh:
                for line in cmd_lines[instance_name]:
                    fh.write("%s\n" % line)
        return command_files

    def get_instance_links_and_dirs(self):
        """
        Get a list of instance dirs valid on the current machine.
        Returned as tuples of (link_name, link_target).
        """
        links_and_dirs = []
        instance_names = sorted(self.instances.keys())
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            # Only create dirs when we are on the correct hostname
            if not instance.is_specified_instance():
                continue
            if not instance.is_current_host():
                self.logger.info("Ignoring directories on '%s' for instance '%s'" % (instance.sdp_hostname, instance.sdp_instance))
                continue
            links_and_dirs.extend(instance.links_and_dirs())
        # Remove duplicates
        result = []
        for dl in links_and_dirs:
            if dl not in result:
                result.append(dl)
        return result

    def check_src_files_exist(self, files_to_copy_list):
        missing_src_files = []
        for src, dest in files_to_copy_list:
            if not os.path.exists(src) and not src in missing_src_files:
                missing_src_files.append(src)
        return missing_src_files

    def mk_links_and_dirs(self, links_and_dirs, files_to_copy_list, files_to_merge_list):
        "Make all appropriate directories on this machine and copy in files"
        if not self.options.yes:
            self.logger.info("The following directories/links would be created with the -y/--yes flag")
        missing_src_files = self.check_src_files_exist(files_to_copy_list)
        if missing_src_files:
            raise SDPException("Missing files to copy to instance: '%s'" % (", ".join(missing_src_files)))
        for linkname, target in links_and_dirs:
            if linkname:
                if not os.path.exists(target):
                    self.logger.info("Creating target dir '%s'" % target)
                    if self.options.yes:
                        os.makedirs(target)
                if not os.path.exists(linkname):
                    self.logger.info("Creating link '%s' to '%s'" % (linkname, target))
                    if self.options.yes:
                        mklink(linkname, target)
            else:
                if not os.path.exists(target):
                    self.logger.info("Creating target dir '%s'" % target)
                    if self.options.yes:
                        os.makedirs(target)

        files_copied = defaultdict(list)
        for file_pair in files_to_copy_list:
            src, dest = file_pair
            if files_different(src, dest):
                if src not in files_copied or dest not in files_copied[src]:
                    files_copied[src].append(dest)
                    self.logger.info("Copying '%s' to '%s'" % (src, dest))
                    if self.options.yes:
                        copy_file(src, dest)
        for file_pair in files_to_merge_list:
            src, dest = file_pair
            self.logger.info("Merging '%s' into '%s'" % (src, dest))
            if self.options.yes:
                merge_configs(src, dest)
        instance_names = self.instances.keys()
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            if not instance.is_specified_instance():
                continue
            # Only create dirs when we are on the correct hostname
            if not instance.is_current_host():
                self.logger.info("Ignoring directories on '%s' for instance '%s'" % (instance.sdp_hostname, instance.sdp_instance))
                continue
            for filename in ['daily_backup.bat', 'p4verify.bat', 'replica_status.bat', 'sync_replica.bat',
                             'weekly_backup.bat', 'weekly_sync_replica.bat']:
                dest_filename = os.path.join(instance.bin_dir, filename)
                src_contents = self.instance_bat_contents(filename, instance.sdp_instance, instance.common_bin_dir)
                if files_different(None, dest_filename, src_contents):
                    self.logger.info("Creating instance bat file '%s'" % (dest_filename))
                    if self.options.yes:
                        self.create_instance_bat(dest_filename, src_contents)

            if self.options.yes:
                admin_pass_filename = os.path.join(instance.common_bin_dir, instance.admin_pass_filename)
                with open(admin_pass_filename, "w") as fh:
                    fh.write(instance.sdp_p4superuser_password)

    def get_instance_files_to_copy(self):
        "Get a list of all files to copy to the instances"
        instance_names = self.instances.keys()
        curr_scriptdir = os.path.dirname(os.path.realpath(__file__))
        file_list = []
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            if not instance.is_specified_instance():
                continue
            # Only create dirs when we are on the correct hostname
            if not instance.is_current_host():
                self.logger.info("Ignoring files to copy on '%s' for instance '%s'" % (instance.sdp_hostname,
                                instance.sdp_instance))
                continue
            for filename in glob.glob(os.path.join(instance.installer_sdp_common_bin_dir, '*.*')):
                file_list.append((filename, os.path.join(instance.common_bin_dir, os.path.basename(filename))))
            for filename in glob.glob(os.path.join(instance.installer_sdp_common_bin_dir, 'triggers', '*.*')):
                file_list.append((filename, os.path.join(instance.common_bin_dir, 'triggers', os.path.basename(filename))))
            file_list.append((os.path.join(curr_scriptdir, 'p4.exe'), instance.bin_dir))
            file_list.append((os.path.join(curr_scriptdir, 'p4d.exe'), instance.bin_dir))
            file_list.append((os.path.join(curr_scriptdir, 'p4d.exe'), os.path.join(instance.bin_dir, 'p4s.exe')))
            if not self.options.specified_instance:
                file_list.append((os.path.join(curr_scriptdir, 'sdp_config.ini'), instance.sdp_config_dir))
            serverid_file = os.path.join(curr_scriptdir, '%s_server.id' % instance.sdp_serverid)
            with open(serverid_file, "w") as fh:
                fh.write("%s" % instance.sdp_serverid)
            file_list.append((serverid_file, os.path.join(instance.root_dir, 'server.id')))
        return file_list

    def get_files_to_merge(self):
        "Get a list of all files to update - only if an instance is specified"
        file_list = []
        if not self.options.specified_instance:
            return file_list
        instance_names = self.instances.keys()
        curr_scriptdir = os.path.dirname(os.path.realpath(__file__))
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            if not instance.is_specified_instance():
                continue
            file_list.append((os.path.join(curr_scriptdir, 'sdp_config.ini'), instance.sdp_config_dir))
        return file_list

    def bat_file_hostname_guard_lines(self, hostname):
        lines = ['@echo off',
            'FOR /F "usebackq" %%i IN (`hostname`) DO SET HOSTNAME=%%i',
            'if /i "%s" NEQ "%s" (' % ('%HOSTNAME%', hostname),
            '  echo ERROR: This command file should only be run on machine with hostname "%s"' % (hostname),
            '  exit /b 1',
            ')',
            '@echo on']
        return lines

    def get_service_install_cmds(self):
        "Configure any services on the current machine"
        cmds = {}
        instance_names = sorted(self.instances.keys())
        for instance_name in instance_names:
            instance = self.instances[instance_name]
            hostname = instance.sdp_hostname.lower()
            if not instance.is_specified_instance():
                continue
            self.logger.info("Creating service configure commands on '%s' for instance '%s' in install_services_%s.bat" % (
                        hostname, instance.sdp_instance, hostname))
            # Install services
            if hostname not in cmds:
                cmds[hostname] = []
            instsrv = joinpath(instance.common_bin_dir, 'instsrv.exe')

            cmd = '%s p4_%s "%s"' % (instsrv, instance.sdp_instance,
                                    os.path.join(instance.bin_dir, 'p4s.exe'))
            cmds[hostname].append(cmd)
            p4cmd = os.path.join(instance.bin_dir, 'p4.exe')
            cmds[hostname].append('%s set -S p4_%s P4ROOT=%s' % (p4cmd, instance.sdp_instance, instance.root_dir))
            cmds[hostname].append('%s set -S p4_%s P4JOURNAL=%s' % (p4cmd, instance.sdp_instance,
                                                       os.path.join(instance.logs_dir, 'journal')))
            cmds[hostname].append('%s set -S p4_%s P4NAME=%s' % (p4cmd, instance.sdp_instance,
                                                       instance.sdp_serverid))
            cmds[hostname].append('%s set -S p4_%s P4PORT=%s' % (p4cmd, instance.sdp_instance,
                                                       instance.sdp_p4port_number))
            log_path = joinpath(instance.logs_dir, "%s.log" % instance.sdp_serverid)
            cmds[hostname].append('%s set -S p4_%s P4LOG=%s' % (p4cmd, instance.sdp_instance, log_path))
        return cmds

    def write_service_install_cmds(self, cmds):
        "Configure any services on the various machines"
        command_files = []
        if not cmds:
            return command_files
        for instance_name in self.instances:
            instance = self.instances[instance_name]
            hostname = instance.sdp_hostname.lower()
            if hostname in cmds:
                command_file = "install_services_%s.bat" % hostname
                if not command_file in command_files:
                    command_files.append(command_file)
                with open(command_file, "w") as fh:
                    # Write a safeguarding header for specific hostname
                    lines = self.bat_file_hostname_guard_lines(hostname)
                    lines.extend(cmds[hostname])
                    for line in lines:
                        fh.write("%s\n" % line)
        return command_files

    def instance_bat_contents(self, fname, instance, common_bin_dir):
        "Creates instance specific batch files which call common one"
        hdrlines = """::-----------------------------------------------------------------------------
            :: Copyright (c) 2012-2014 Perforce Software, Inc.  Provided for use as defined in
            :: the Perforce Consulting Services Agreement.
            ::-----------------------------------------------------------------------------

            set ORIG_DIR=%CD%
            """.split("\n")
        lines = [line.strip() for line in hdrlines]
        lines.append("")
        lines.append('cd /d "%s"\n' % common_bin_dir)
        lines.append('@call %s %s\n' % (fname, instance))
        lines.append('cd /d %ORIG_DIR%\n')
        return "\n".join(lines)

    def create_instance_bat(self, dest_filename, contents):
        "Creates instance specific batch files which call common one"
        with open(dest_filename, "w") as fh:
            fh.write(contents)

    def process_config(self):
        "Process and produce the various files"
        self.isvalid_config()
        if self.options.yes and not running_as_administrator():
            raise SDPException("This action must be run with Administrator rights")
        self.write_master_config_ini()
        links_and_dirs = self.get_instance_links_and_dirs()
        files_to_copy = self.get_instance_files_to_copy()
        files_to_merge = self.get_files_to_merge()
        self.mk_links_and_dirs(links_and_dirs, files_to_copy, files_to_merge)
        cmds = self.get_service_install_cmds()
        command_files = self.write_service_install_cmds(cmds)
        cmd_lines = self.get_configure_bat_contents()
        command_files.extend(self.write_configure_bat_contents(cmd_lines))
        print("\n\n")
        if self.options.yes:
            print("Please run the following commands:")
        else:
            print("The following commands have been created - but you are in report mode so no directories have been created")
        for cmd in command_files:
            print("    %s" % cmd)
        print("You will also need to seed the replicas from a checkpoint and run the appropriate commands on those machines")
        if not self.options.yes:
            self.logger.info("Running in reporting mode: use -y or --yes to perform actions.")
def main():
    "Initialization.  Process command line argument and initialize logging."
    try:
        sdpconfig = SDPConfig()
        sdpconfig.process_config()
    except SDPException as e:
        print(str(e))
    except SDPConfigException as e:
        print(str(e))

if __name__ == '__main__':
    main()
