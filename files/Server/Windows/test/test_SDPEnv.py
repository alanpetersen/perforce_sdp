# -*- encoding: UTF8 -*-

# test_SDPEnv.py
# Tests the SDP (Server Deployment Package)

from __future__ import print_function

import os
import sys
import logging
import socket
import unittest
import textwrap


python3 = sys.version_info[0] >= 3

if python3:
    from io import StringIO
else:
    from StringIO import StringIO

# Add the nearby "code" directory to the module loading path to pick up p4
sys.path.insert(0, os.path.join('..', 'setup'))

import SDPEnv
from SDPEnv import SDPConfigException, SDPConfig

#---Code
verbose = 0
slow = 1

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

#--- Test Cases

class PyTestCase(unittest.TestCase):
    """Provide compatibility for 2.7 and 3.3"""

    def assertRegex(self, text, expected_regex, msg=None):
        if python3:
            super(PyTestCase, self).assertRegex(text, expected_regex, msg=msg)
        else:
            self.assertRegexpMatches(text, expected_regex, msg=msg)

    def assertNotRegex(self, text, expected_regex, msg=None):
        if python3:
            super(PyTestCase, self).assertNotRegex(text, expected_regex, msg=msg)
        else:
            self.assertNotRegexpMatches(text, expected_regex, msg=msg)

class config_validation_base(PyTestCase):
    "Basic config validation tests"

    def setUp(self):
        super(config_validation_base, self).setUp()
        self.required_options = ("sdp_serverid sdp_service_type sdp_p4port_number "
                                  "metadata_root depotdata_root logdata_root").split()

    def create_data(self, data):
        return "\n".join([x.strip() for x in data.split()])

    def configNotValid(self, data, reqd_msg):
        "Test and catch exception"
        sc = self.createSDPConfig(self.create_data(data))
        if python3:
            with self.assertRaisesRegex(SDPConfigException, reqd_msg) as cm:
                sc.isvalid_config()
        else:
            with self.assertRaisesRegexp(SDPConfigException, reqd_msg) as cm:
                sc.isvalid_config()
        return str(cm.exception)

    def createSDPConfig(self, data):
        """Creates an SDPConfig object"""
        self.stdoutput = StringIO()
        self.logger = logging.getLogger(SDPEnv.LOGGER_NAME)
        sc = SDPConfig(config_data=self.create_data(data), logStream=self.stdoutput)
        return sc

class required_options_missing(config_validation_base):
    def runTest(self):
        "Test required options must be present"

        # First we test for reqd options
        reqd_options_missing_msg = "The following required options are missing"

        # No required options specified
        data = """[Master:MasterHostname]
        some_var=some_val
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        for opt in self.required_options:
            self.assertRegex(errmsg, opt)

        # sdp_serverid still missing as it is blank
        data = """[Master:MasterHostname]
        sdp_serverid=
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        self.assertRegex(errmsg, "sdp_serverid")

        # Now we specify the value so make sure it isn't present in the output
        data = """[Master:MasterHostname]
        sdp_serverid=some_val
        """
        errmsg = self.configNotValid(data, reqd_options_missing_msg)
        self.assertNotRegex(errmsg, "sdp_serverid")

        # Now provide all values
        data = """[Master:MasterHostname]
                SDP_SERVERID=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=1777
                SDP_INSTANCE=1
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        sc = self.createSDPConfig(self.create_data(data))
        self.assertTrue(sc.isvalid_config())

        data = r"""[1:__OUTPUT_OF_HOSTNAME_COMMAND_ON_SERVER_PLEASE_UPDATE__]
                SDP_SERVERID=MAster
                SDP_SERVICE_TYPE=replica
                SDP_HOSTNAME=some-host
                SDP_P4PORT_NUMBER=1778
                SDP_INSTANCE=2
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        reqd_msg = "Section name '.*' still contains default value"
        if python3:
            with self.assertRaisesRegex(SDPConfigException, reqd_msg) as cm:
                sc = self.createSDPConfig(self.create_data(data))
        else:
            with self.assertRaisesRegexp(SDPConfigException, reqd_msg) as cm:
                sc = self.createSDPConfig(self.create_data(data))
                
class config_field_validation(config_validation_base):
    def runTest(self):
        "Test config fields must be valid"

        data = """[Master:MasterHostname]
                SDP_SERVERID=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=a1213
                SDP_INSTANCE=1
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        errmsg = self.configNotValid(data, "SDP_P4PORT_NUMBER must be numeric")
        self.assertRegex(errmsg, "Master")

        data = """[Master:MasterHostname]
                SDP_SERVERID=Master
                SDP_SERVICE_TYPE=non-standard
                SDP_HOSTNAME=WIN-B7UQ3E1TN83
                SDP_P4PORT_NUMBER=1213
                SDP_INSTANCE=1
                SDP_P4SUPERUSER=admin
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        errmsg = self.configNotValid(data, "SDP_SERVICE_TYPE must be one of "
            "'standard, replica, forwarding-replica, build-server'")
        self.assertRegex(errmsg, "Master")

        data = r"""[Replica1:ReplicaHostname]
                SDP_SERVERID=Replica1
                SDP_SERVICE_TYPE=replica
                SDP_HOSTNAME=some-host
                SDP_P4PORT_NUMBER=1778
                SDP_INSTANCE=2
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """
        errmsg = self.configNotValid(data, "Field REMOTE_DEPOTDATA_ROOT must have a value for replica instance")

class output_file_contents(config_validation_base):
    def runTest(self):
        "Test output scripts are correct"

        self.maxDiff = None # Show all differences

        # Provide all values
        default_data = r"""[DEFAULT]
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
        master_data = """[Master:MasterHostname]
                SDP_SERVERID=Master
                SDP_SERVICE_TYPE=standard
                SDP_HOSTNAME=%s
                SDP_P4PORT_NUMBER=1777
                SDP_INSTANCE=1
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """ % (hostname)
        sc = self.createSDPConfig(self.create_data(default_data + master_data))
        self.assertTrue(sc.isvalid_config())

        sc.write_master_config_ini()

        expected_dirs = [(None, r'c:\p4'),
                        (None, r'E:\p4\1'),
                        (r'c:\p4\1', r'F:\p4\1'),
                        (None, r'G:\p4\1'),
                        (r'c:\p4\common', r'F:\p4\common'),
                        (r'c:\p4\config', r'F:\p4\config'),
                        (None, r'c:\p4\common\bin'),
                        (None, r'c:\p4\common\bin\triggers'),
                        (None, r'c:\p4\1\bin'),
                        (None, r'c:\p4\1\tmp'),
                        (None, r'c:\p4\1\depots'),
                        (None, r'c:\p4\1\checkpoints'),
                        (None, r'c:\p4\1\ssl'),
                        (r'c:\p4\1\root', r'E:\p4\1\root'),
                        (None, r'c:\p4\1\root\save'),
                        (r'c:\p4\1\offline_db', r'E:\p4\1\offline_db'),
                        (r'c:\p4\1\logs', r'G:\p4\1\logs')
                        ]
        dirs = sc.get_instance_links_and_dirs()
        self.assertEqual(expected_dirs, dirs)
        expected_cmds = {hostname: [
                        r'c:\p4\common\bin\instsrv.exe p4_1 "c:\p4\1\bin\p4s.exe"',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4ROOT=c:\p4\1\root',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4JOURNAL=c:\p4\1\logs\journal',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4NAME=Master',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4PORT=1777',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4LOG=c:\p4\1\logs\Master.log']}
        cmds = sc.get_service_install_cmds()
        self.assertEqual(expected_cmds, cmds)

        master_data = r"""[1:%s]
                SDP_SERVERID=Master
                SDP_SERVICE_TYPE=standard
                SDP_P4PORT_NUMBER=1777
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                """ % (hostname)
        replica_data = r"""[2:%s]
                SDP_SERVERID=Replica1
                SDP_SERVICE_TYPE=replica
                SDP_P4PORT_NUMBER=1778
                SDP_P4SUPERUSER=admin
                SDP_P4SERVICEUSER=fred
                METADATA_ROOT=E:
                DEPOTDATA_ROOT=F:
                LOGDATA_ROOT=G:
                REMOTE_DEPOTDATA_ROOT=\\SomeServer\f$
                """ % (hostname)
        sc = self.createSDPConfig(self.create_data(default_data + master_data + replica_data))
        self.assertTrue(sc.isvalid_config())

        # Make sure config written is correct
        expected_config = (r"""# Global sdp_config.ini


                [1:%s]
                p4port=%s:1777
                sdp_serverid=Master
                sdp_p4serviceuser=fred
                sdp_global_root=
                sdp_p4superuser=admin
                admin_pass_filename=adminpass.txt
                mailfrom=sdp@test.com
                maillist=rcowham@perforce.com
                mailhost=unknownserver@perforce.com
                python=c:\python27
                remote_depotdata_root=
                keepckps=7
                keeplogs=7
                limit_one_daily_checkpoint=false

                [2:%s]
                p4port=%s:1778
                sdp_serverid=Replica1
                sdp_p4serviceuser=fred
                sdp_global_root=
                sdp_p4superuser=admin
                admin_pass_filename=adminpass.txt
                mailfrom=sdp@test.com
                maillist=rcowham@perforce.com
                mailhost=unknownserver@perforce.com
                python=c:\python27
                remote_depotdata_root=\\SomeServer\f$
                keepckps=7
                keeplogs=7
                limit_one_daily_checkpoint=false
                remote_sdp_instance=1
                p4target=%s:1777""" % (hostname, hostname, hostname, hostname, hostname)).split("\n")
        expected_config_lines = sorted_ini([l.strip() for l in expected_config])
        sc.write_master_config_ini()
        with open("sdp_config.ini", "r") as fh:
            lines = sorted_ini([l.strip() for l in fh.readlines()])
            self.assertListEqual(expected_config_lines, lines)

        expected_dirs = [(None, r'c:\p4'),
                        (None, r'E:\p4\1'),
                        (r'c:\p4\1', r'F:\p4\1'),
                        (None, r'G:\p4\1'),
                        (r'c:\p4\common', r'F:\p4\common'),
                        (r'c:\p4\config', r'F:\p4\config'),
                        (None, r'c:\p4\common\bin'),
                        (None, r'c:\p4\common\bin\triggers'),
                        (None, r'c:\p4\1\bin'),
                        (None, r'c:\p4\1\tmp'),
                        (None, r'c:\p4\1\depots'),
                        (None, r'c:\p4\1\checkpoints'),
                        (None, r'c:\p4\1\ssl'),
                        (r'c:\p4\1\root', r'E:\p4\1\root'),
                        (None, r'c:\p4\1\root\save'),
                        (r'c:\p4\1\offline_db', r'E:\p4\1\offline_db'),
                        (r'c:\p4\1\logs', r'G:\p4\1\logs'),
                        (None, r'E:\p4\2'),
                        (r'c:\p4\2', r'F:\p4\2'),
                        (None, r'G:\p4\2'),
                        (None, r'c:\p4\2\bin'),
                        (None, r'c:\p4\2\tmp'),
                        (None, r'c:\p4\2\depots'),
                        (None, r'c:\p4\2\checkpoints'),
                        (None, r'c:\p4\2\ssl'),
                        (r'c:\p4\2\root', r'E:\p4\2\root'),
                        (None, r'c:\p4\2\root\save'),
                        (r'c:\p4\2\offline_db', r'E:\p4\2\offline_db'),
                        (r'c:\p4\2\logs', r'G:\p4\2\logs')
                        ]
        dirs = sc.get_instance_links_and_dirs()
        self.assertEqual(expected_dirs, dirs)
        expected_cmds = {hostname: [
                        r'c:\p4\common\bin\instsrv.exe p4_1 "c:\p4\1\bin\p4s.exe"',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4ROOT=c:\p4\1\root',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4JOURNAL=c:\p4\1\logs\journal',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4NAME=Master',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4PORT=1777',
                        r'c:\p4\1\bin\p4.exe set -S p4_1 P4LOG=c:\p4\1\logs\Master.log',
                        r'c:\p4\common\bin\instsrv.exe p4_2 "c:\p4\2\bin\p4s.exe"',
                        r'c:\p4\2\bin\p4.exe set -S p4_2 P4ROOT=c:\p4\2\root',
                        r'c:\p4\2\bin\p4.exe set -S p4_2 P4JOURNAL=c:\p4\2\logs\journal',
                        r'c:\p4\2\bin\p4.exe set -S p4_2 P4NAME=Replica1',
                        r'c:\p4\2\bin\p4.exe set -S p4_2 P4PORT=1778',
                        r'c:\p4\2\bin\p4.exe set -S p4_2 P4LOG=c:\p4\2\logs\Replica1.log']}
        cmds = sc.get_service_install_cmds()
        self.assertEqual(expected_cmds, cmds)

        bat_prefix = 'p4 -p %s:1777 -u admin ' % (hostname)
        expected_bat_contents = {"Master": [
                bat_prefix + r'configure set Master#journalPrefix=c:\p4\1\checkpoints\p4_1',
                bat_prefix + r'configure set Replica1#journalPrefix=c:\p4\2\checkpoints\p4_2',
                bat_prefix + r'configure set Replica1#P4TARGET=%s:1777' % (hostname),
                bat_prefix + r'configure set Replica1#P4TICKETS=c:\p4\2\p4tickets.txt',
                bat_prefix + r'configure set Replica1#P4LOG=c:\p4\2\logs\Replica1.log',
                bat_prefix + r'configure set "Replica1#startup.1=pull -i 1"',
                bat_prefix + r'configure set "Replica1#startup.2=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.3=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.4=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.5=pull -u -i 1"',
                bat_prefix + r'configure set Replica1#lbr.replication=readonly',
                bat_prefix + r'configure set Replica1#db.replication=readonly',
                bat_prefix + r'configure set Replica1#serviceUser=Replica1']}
        bat_contents = sc.get_configure_bat_contents([])
        self.assertEqual(expected_bat_contents, bat_contents)

        # Test if we provide a sample file that it will be appropriately added
        template_configure_bat_lines = textwrap.dedent("""
                p4 configure set db.peeking=2
                p4 configure set defaultChangeType=restricted
                p4 configure set run.users.authorize=1
                p4 configure set dm.user.noautocreate=2
                p4 configure set dm.user.resetpassword=1
                p4 configure set filesys.P4ROOT.min=1G
                p4 configure set filesys.depot.min=1G
                p4 configure set filesys.P4JOURNAL.min=1G
                p4 configure set monitor=1
                p4 configure set server=3""").split("\n")

        expected_bat_contents = {"Master": [
                bat_prefix + r'configure set Master#journalPrefix=c:\p4\1\checkpoints\p4_1',
                bat_prefix + r'configure set db.peeking=2',
                bat_prefix + r'configure set defaultChangeType=restricted',
                bat_prefix + r'configure set run.users.authorize=1',
                bat_prefix + r'configure set dm.user.noautocreate=2',
                bat_prefix + r'configure set dm.user.resetpassword=1',
                bat_prefix + r'configure set filesys.P4ROOT.min=1G',
                bat_prefix + r'configure set filesys.depot.min=1G',
                bat_prefix + r'configure set filesys.P4JOURNAL.min=1G',
                bat_prefix + r'configure set monitor=1',
                bat_prefix + r'configure set server=3',
                bat_prefix + r'configure set Replica1#journalPrefix=c:\p4\2\checkpoints\p4_2',
                bat_prefix + r'configure set Replica1#P4TARGET=%s:1777' % (hostname),
                bat_prefix + r'configure set Replica1#P4TICKETS=c:\p4\2\p4tickets.txt',
                bat_prefix + r'configure set Replica1#P4LOG=c:\p4\2\logs\Replica1.log',
                bat_prefix + r'configure set "Replica1#startup.1=pull -i 1"',
                bat_prefix + r'configure set "Replica1#startup.2=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.3=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.4=pull -u -i 1"',
                bat_prefix + r'configure set "Replica1#startup.5=pull -u -i 1"',
                bat_prefix + r'configure set Replica1#lbr.replication=readonly',
                bat_prefix + r'configure set Replica1#db.replication=readonly',
                bat_prefix + r'configure set Replica1#serviceUser=Replica1']}
        bat_contents = sc.get_configure_bat_contents(template_configure_bat_lines)
        self.assertEqual(expected_bat_contents, bat_contents)

        # Check for valid server.id files - not too worried about the other files for now
        instance_files_to_copy = sc.get_instance_files_to_copy()
        targets = [x[1] for x in instance_files_to_copy]
        self.assertTrue(r'c:\p4\1\root\server.id' in targets)
        self.assertTrue(r'c:\p4\1\bin\p4s.exe' in targets)
        self.assertTrue(r'c:\p4\2\root\server.id' in targets)
        self.assertTrue(r'c:\p4\2\bin\p4s.exe' in targets)

# RUNNING THE TESTS
if __name__ == "__main__":
    unittest.main()
