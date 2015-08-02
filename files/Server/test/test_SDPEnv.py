# -*- encoding: UTF8 -*-

# test_create_env.py
# Tests create_env.py in SDP (Server Deployment Package)

import os
import sys
import copy
import imp
import re
import socket
import string
import time
import types
import shutil
import tempfile
import getopt
import fileinput
import traceback

# import P4

import unittest

# Add the nearby "code" directory to the module loading path to pick up p4
sys.path.insert(0, os.path.join('..', 'setup'))

from SDPEnv import SDPException, SDPConfigException, SDPInstance, SDPConfig

#---Code
verbose = 0
slow = 1

# The default temporary file prefix starts with an '@'.  But
# that would mean that temporary files will look like revision
# specifications to Perforce.  So use a prefix that's acceptable
# to Perforce.
tempfile.gettempprefix = lambda: '%d.' % os.getpid()

# We need to log to a log file.  The SDPTest log will get redirected to
# this file, as will the output of various commands.

log_filename = (time.strftime('SDPTest.%Y%m%dT%H%M%S.log',
                                 time.gmtime(time.time())))
log_filename = os.path.abspath(log_filename)
log_file = open(log_filename, "a")

def log_exception():
    type, val, tb = sys.exc_info()
    log_message(string.join(traceback.format_exception(type, val, tb), ''))
    del type, val, tb

def log_message(msg):
    date = time.strftime('%Y-%m-%d %H:%M:%S UTC',
                         time.gmtime(time.time()))
    log_file.write("%s  %s\n" % (date, msg))
    log_file.flush()
    if verbose:
        print("%s  %s\n" % (date, msg))

def sorted_ini(config_lines):
    "Sorts the config lines based on name of sections - for reliable comparison"
    result = []
    sections = {}
    sname = ""
    for line in [l.strip() for l in config_lines]:
        if not line or (len(line) > 0 and line[0] == '#'):
            continue
        if line and line[0] == '[':
            sname = line
            sections[sname] = []
        else:
            sections[sname].append(line)
    for sname in sorted(sections.keys()):
        result.append(sname)
        result.extend(sections[sname])
    return result

sys.stdout.write("SDPTest test suite, logging to %s\n" % log_filename)
sys.stdout.flush()

# Perforce
#
# This class supplies test methods.
# It also provides "system", which is like os.system,
# but captures output, checks for errors, and writes to the log.

class Perforce:

    # Temporary directory for Perforce server and associated files.
    p4dir = "test"

    # Run command and check results
    #
    # Calls an external program, raising an exception upon any error
    # and returning standard output and standard error from the program,
    # as well as writing them to the log.

    def system(self, command, ignore_failure = 0, input_lines = None):
        log_file.write('Executing %s\n' % repr(command))
        (child_stdin, child_stdout) = os.popen4(command)
        if input_lines:
            child_stdin.writelines(input_lines)
            child_stdin.close()
        output = child_stdout.read()
        result = child_stdout.close()
        log_file.write(output)
        if not ignore_failure and result:
            message = ('Command "%s" failed with result code %d.' %
                       (command, result))
            log_file.write(message + '\n')
            raise message
        return output

# The SDPTest_base class is a generic test case.
# Other test cases will inherit from this class.
#
# When a class implements several test cases, the methods that implement
# test cases (in the PyUnit sense) should have names starting "test_".
# When a class implements a single test case, the method should be
# called "runTest".

class SDPTest_base(unittest.TestCase):

    # Set up everything so that test cases can run
    #
    p4d = Perforce()
    p4api_ver = "2005.1"

    def setup_everything(self, config_changes = {}):
        pass
        # for key, value in config_changes.items():
            # setattr(config, key, value)

    def log_result(self, msg="", output=[]):
        type, val, tb = sys.exc_info()
        log_message(msg + '\n' + string.join(traceback.format_stack(limit=2), ''))
        if len(output) > 0:
            import pprint
            pp = pprint.PrettyPrinter(indent=4)
            log_message(pp.pformat(output))
        # if len(self.p4.warnings) > 0:
            # log_message("Warnings: " + "\n".join(self.p4.warnings))
        # if len(self.p4.errors) > 0:
            # log_message("Errors: " + "\n".join(self.p4.errors))

    def write_to_file(self, fname, results):
        temp_file = open(fname, "w")
        for l in results:
            temp_file.write(l)
        temp_file.close()

    def setUp(self):
        self.setup_everything()

    def run_test(self):
        pass

#--- Test Cases

class config_validation_base(SDPTest_base):
    "Basic config validation tests"

    def setUp(self):
        super(config_validation_base, self).setUp()
        self.required_options  = [x.lower() for x in "P4NAME SDP_SERVICE_TYPE SDP_HOSTNAME SDP_INSTANCE SDP_P4PORT_NUMBER SDP_OS_USERNAME".split()]
        self.required_options.extend([x.lower() for x in "METADATA_ROOT DEPOTDATA_ROOT LOGDATA_ROOT".split()])

    def create_data(self, data):
        return "\n".join([x.strip() for x in data.split()])

    def configNotValid(self, data, reqd_msg):
        "Test and catch exception"
        sc = SDPConfig(config_data=self.create_data(data))
        with self.assertRaisesRegexp(SDPConfigException, reqd_msg) as cm:
            sc.isvalid_config()
        return str(cm.exception)

class required_options_missing(config_validation_base):
    def runTest(self):
        "Test required options must be present"

        # First we test for reqd options
        reqd_options_missing_msg = "The following required options are missing"

        # No required options specified
        data = """[Master]
        some_var=some_val
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        for opt in self.required_options:
            self.assertRegex(errmsg, opt)

        # p4name still missing as it is blank
        data = """[Master]
        p4name=
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        self.assertRegex(errmsg, "p4name")

        # Now we specify the value so make sure it isn't present in the output
        data = """[Master]
        p4name=some_val
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        self.assertNotRegex(errmsg, "p4name")

        # Now provide all values
        data = """[Master]
                P4NAME=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=1777
                SDP_INSTANCE=1
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        sc = SDPConfig(config_data=self.create_data(data))
        self.assertTrue(sc.isvalid_config())

class config_field_validation(config_validation_base):
    def runTest(self):
        "Test config fields must be valid"

        data = """[Master]
                P4NAME=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=a1213
                SDP_INSTANCE=1
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        errmsg = self.configNotValid(data, "SDP_P4PORT_NUMBER must be numeric")
        self.assertRegex(errmsg, "Master")

        data = """[Master]
                P4NAME=Master
                SDP_SERVICE_TYPE=non-standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=1213
                SDP_INSTANCE=1
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        errmsg = self.configNotValid(data, "SDP_SERVICE_TYPE must be one of "
            "'standard, replica, forwarding-replica, build-server'")
        self.assertRegex(errmsg, "Master")

class output_file_contents(config_validation_base):
    def runTest(self):
        "Test output scripts are correct"

        self.maxDiff = None # Show all differences

        # Provide all values
        default_data = """[DEFAULT]
                maillist=rcowham@perforce.com
                mailfrom=sdp@test.com
                mailhost=unknownserver@perforce.com
                python=c:\python27
                ADMIN_PASS_FILENAME=adminpass.txt
                KEEPCKPS=7
                KEEPLOGS=7
                LIMIT_ONE_DAILY_CHECKPOINT=false
                """

        hostname = socket.gethostname().lower()
        master_data = """[Master]
                P4NAME=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=%s
                SDP_P4PORT_NUMBER=1777
                SDP_INSTANCE=1
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """ % (hostname)
        sc = SDPConfig(config_data=self.create_data(default_data + master_data))
        self.assertTrue(sc.isvalid_config())

        sc.write_master_config_ini()

        expected_dirs = [r'E:\p4\1\root',
                        r'G:\p4\1',
                        r'F:\p4\1\bin',
                        r'F:\p4\1\tmp',
                        r'F:\p4\1\depots',
                        r'F:\p4\1\checkpoints',
                        r'F:\p4\1\ssl',
                        r'F:\p4\common\bin',
                        r'F:\p4\common\bin\triggers',
                        r'E:\p4\1\root\save',
                        r'E:\p4\1\offline_db',
                        r'G:\p4\1\logs',
                        r'F:\p4\config']
        dirs = sc.get_instance_dirs()
        self.assertEquals(expected_dirs, dirs)
        expected_cmds = {hostname: [
                        r'F:\p4\common\bin\instsrv.exe p4_1 "F:\p4\1\bin\p4s.exe"',
                        r'F:\p4\1\bin\p4.exe set -S p4_1 P4ROOT=E:\p4\1\root',
                        r'F:\p4\1\bin\p4.exe set -S p4_1 P4JOURNAL=G:\p4\1\logs\journal',
                        r'F:\p4\1\bin\p4.exe set -S p4_1 P4NAME=Master',
                        r'F:\p4\1\bin\p4.exe set -S p4_1 P4PORT=1777',
                        r'F:\p4\1\bin\p4.exe set -S p4_1 P4LOG=G:\p4\1\logs\Master.log']}
        cmds = sc.get_service_install_cmds()
        self.assertEquals(expected_cmds, cmds)

        master_data = r"""[Master]
                P4NAME=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=%s
                SDP_P4PORT_NUMBER=1777
                SDP_INSTANCE=1
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:\master
                DEPOTDATA_ROOT=F:\master
                LOGDATA_ROOT=G:\master
                """ % (hostname)
        replica_data = r"""[Replica1]
                P4NAME=Replica1
                SDP_SERVICE_TYPE=replica
                SDP_HOSTNAME=%s
                SDP_P4PORT_NUMBER=1778
                SDP_INSTANCE=2
                SDP_OS_USERNAME=p4admin
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:\replica
                DEPOTDATA_ROOT=F:\replica
                LOGDATA_ROOT=G:\replica
                """ % (hostname)
        sc = SDPConfig(config_data=self.create_data(default_data + master_data + replica_data))
        self.assertTrue(sc.isvalid_config())

        # Make sure config written is correct
        expected_config = r"""# Global sdp_config.ini


                [1:win-b7uq3e1tn83]
                p4port=win-b7uq3e1tn83:1777
                p4name=Master
                sdp_os_username=p4admin
                sdp_p4serviceuser=fred
                metadata_root=E:\master
                depotdata_root=F:\master
                logdata_root=G:\master
                sdp_p4superuser=admin
                admin_pass_filename=adminpass.txt
                mailfrom=sdp@test.com
                maillist=rcowham@perforce.com
                mailhost=unknownserver@perforce.com
                python=c:\python27
                keepckps=7
                keeplogs=7
                limit_one_daily_checkpoint=false

                [2:win-b7uq3e1tn83]
                p4port=win-b7uq3e1tn83:1778
                p4name=Replica1
                sdp_os_username=p4admin
                sdp_p4serviceuser=fred
                metadata_root=E:\replica
                depotdata_root=F:\replica
                logdata_root=G:\replica
                sdp_p4superuser=admin
                admin_pass_filename=adminpass.txt
                mailfrom=sdp@test.com
                maillist=rcowham@perforce.com
                mailhost=unknownserver@perforce.com
                python=c:\python27
                keepckps=7
                keeplogs=7
                limit_one_daily_checkpoint=false""".split("\n")
        expected_config_lines = sorted_ini([l.strip() for l in expected_config])
        sc.write_master_config_ini()
        with open("sdp_config.ini", "r") as fh:
            lines = sorted_ini([l.strip() for l in fh.readlines()])
            self.assertListEqual(expected_config_lines, lines)

        expected_dirs = [r'E:\master\p4\1\root',
                        r'G:\master\p4\1',
                        r'F:\master\p4\1\bin',
                        r'F:\master\p4\1\tmp',
                        r'F:\master\p4\1\depots',
                        r'F:\master\p4\1\checkpoints',
                        r'F:\master\p4\1\ssl',
                        r'F:\master\p4\common\bin',
                        r'F:\master\p4\common\bin\triggers',
                        r'E:\master\p4\1\root\save',
                        r'E:\master\p4\1\offline_db',
                        r'G:\master\p4\1\logs',
                        r'F:\master\p4\config',
                        r'E:\replica\p4\2\root',
                        r'G:\replica\p4\2',
                        r'F:\replica\p4\2\bin',
                        r'F:\replica\p4\2\tmp',
                        r'F:\replica\p4\2\depots',
                        r'F:\replica\p4\2\checkpoints',
                        r'F:\replica\p4\2\ssl',
                        r'F:\replica\p4\common\bin',
                        r'F:\replica\p4\common\bin\triggers',
                        r'E:\replica\p4\2\root\save',
                        r'E:\replica\p4\2\offline_db',
                        r'G:\replica\p4\2\logs',
                        r'F:\replica\p4\config']
        dirs = sc.get_instance_dirs()
        self.assertEquals(expected_dirs, dirs)
        expected_cmds = {hostname: [
                        r'F:\master\p4\common\bin\instsrv.exe p4_1 "F:\master\p4\1\bin\p4s.exe"',
                        r'F:\master\p4\1\bin\p4.exe set -S p4_1 P4ROOT=E:\master\p4\1\root',
                        r'F:\master\p4\1\bin\p4.exe set -S p4_1 P4JOURNAL=G:\master\p4\1\logs\journal',
                        r'F:\master\p4\1\bin\p4.exe set -S p4_1 P4NAME=Master',
                        r'F:\master\p4\1\bin\p4.exe set -S p4_1 P4PORT=1777',
                        r'F:\master\p4\1\bin\p4.exe set -S p4_1 P4LOG=G:\master\p4\1\logs\Master.log',
                        r'F:\replica\p4\common\bin\instsrv.exe p4_2 "F:\replica\p4\2\bin\p4s.exe"',
                        r'F:\replica\p4\2\bin\p4.exe set -S p4_2 P4ROOT=E:\replica\p4\2\root',
                        r'F:\replica\p4\2\bin\p4.exe set -S p4_2 P4JOURNAL=G:\replica\p4\2\logs\journal',
                        r'F:\replica\p4\2\bin\p4.exe set -S p4_2 P4NAME=Replica1',
                        r'F:\replica\p4\2\bin\p4.exe set -S p4_2 P4PORT=1778',
                        r'F:\replica\p4\2\bin\p4.exe set -S p4_2 P4LOG=G:\replica\p4\2\logs\Replica1.log']}
        cmds = sc.get_service_install_cmds()
        self.assertEquals(expected_cmds, cmds)

        bat_prefix = 'p4 -p %s:1777 -u admin ' % (hostname)
        expected_bat_contents = {'Master': [
                bat_prefix + r'configure set Master#journalPrefix=F:\master\p4\1\checkpoints\p4_1',
                bat_prefix + r'serverid Master',
                bat_prefix + r'configure set Master#serverlog.file.8=G:\master\p4\1\logs\integrity.csv',
                bat_prefix + r'configure set Master#serverlog.retain.8=7',
                bat_prefix + r'configure set Master#serverlog.file.3=G:\master\p4\1\logs\errors.csv',
                bat_prefix + r'configure set Master#serverlog.retain.3=7',
                bat_prefix + r'configure set Master#serverlog.file.7=G:\master\p4\1\logs\events.csv',
                bat_prefix + r'configure set Master#serverlog.retain.7=7',
                bat_prefix + r'configure set db.peeking=2',
                bat_prefix + r'configure set dm.user.noautocreate=2',
                bat_prefix + r'configure set dm.user.resetpassword=1',
                bat_prefix + r'configure set filesys.P4ROOT.min=1G',
                bat_prefix + r'configure set filesys.depot.min=1G',
                bat_prefix + r'configure set filesys.P4JOURNAL.min=1G',
                bat_prefix + r'configure set spec.hashbuckets=99',
                bat_prefix + r'configure set monitor=1',
                bat_prefix + r'configure set server=3',
                bat_prefix + r'configure set net.tcpsize=128k',
                bat_prefix + r'configure set server.commandlimits=2',
                bat_prefix + r'configure set Replica1#journalPrefix=F:\replica\p4\2\checkpoints\p4_2',
                bat_prefix + r'configure set Replica1#P4PORT=1778',
                bat_prefix + r'configure set Replica1#P4TARGET=%s:1777' % (hostname),
                bat_prefix + r'configure set Replica1#P4TICKETS=F:\replica\p4\2\p4tickets.txt',
                bat_prefix + r'configure set Replica1#P4LOG=G:\replica\p4\2\logs\Replica1.log',
                bat_prefix + r'configure set Replica1#server=3',
                bat_prefix + r'configure set "Replica1#startup.1=pull -i 1"',
                bat_prefix + r'configure set "Replica1#startup.2=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.3=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.4=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.5=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#lbr.replication=readonly"',
                bat_prefix + r'configure set "Replica1#db.replication=readonly"',
                bat_prefix + r'configure set "Replica1#serviceUser=Replica1"'],
                 'Replica1': [
                            r'p4 -p %s:1778 -u admin serverid Replica1' % (hostname)]}
        bat_contents = sc.get_configure_bat_contents()
        self.assertEquals(expected_bat_contents, bat_contents)

# RUNNING THE TESTS
def tests():
    if len(sys.argv) == 1:
        suite = unittest.TestSuite()
        # Decide which tests to run

        tests = [required_options_missing, config_field_validation, output_file_contents]
        # tests = [login]
        for t in tests:
            suite.addTest(t())
        return suite
    else:
        # Unfortunately the following doesn't work with pdb, but is OK otherwise
        loader = unittest.defaultTestLoader
        module = __import__('__main__')
        suite = loader.loadTestsFromName(sys.argv[1], module)
        return suite

def main():
    # Filter out our arguments before handing unknown ones on
    argv = []
    argv.append(sys.argv[0])
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hv",
                        ["help", "verbose"])
    except getopt.GetoptError:
        print("Usage: -v/verbose")
        sys.exit(2)

    for opt, arg in opts:
        if opt in ("-v", "--verbose"):
            verbose = 1
            argv.append("-v")
        elif opt in ("-h", "--help"):
            argv.append("-h")   # pass it through
        else:   # If unknown pass them on
            argv.append(opt)
            argv.append(arg)
    # unittest.main(defaultTest="tests", argv=argv)
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(tests())

if __name__ == "__main__":
    main()
