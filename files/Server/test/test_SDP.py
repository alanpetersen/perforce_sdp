#!/usr/bin/env python3
# -*- encoding: UTF8 -*-

# test_SDP.py
# Tests SDP (Server Deployment Package) on Linux VMs
# Intended to be run from with a Vagrant VM.

from __future__ import print_function

import os, sys, re, socket, time, shutil, logging, time, pwd, stat
import P4
import unittest
import fileinput, subprocess

LOGGER_NAME = 'SDPTest'
mkdirs_file = '/depotdata/sdp/Server/Unix/setup/mkdirs.sh'

MAILTO = 'mailto-admin@example.com'
MAILFROM = 'mailfrom-admin@example.com'

logger = logging.getLogger(LOGGER_NAME)

class NotSudo(Exception):
    pass

def get_host_ipaddress():
    try:
        address = socket.gethostbyname(socket.gethostname())
        # On my system, this always gives me 127.0.0.1. Hence...
    except:
        address = ''
    if not address or address.startswith('127.'):
        # ...the hard way.
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('4.2.2.1', 0))
        address = s.getsockname()[0]
        s.detach()
    logger.debug('IPAddress: %s' % address)
    return address

def init_logging():
    global logger
    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s:%(name)s:%(levelname)s: %(message)s')
    fh = logging.FileHandler('/tmp/%s.log' % LOGGER_NAME, mode='w')
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    logger.addHandler(fh)

def do_unlink(filename):
    "Unlink file if it exists"
    if os.path.lexists(filename):
        os.unlink(filename)

def substitute_vars(line, instance, port):
    line = line.rstrip()
    if line.startswith('export MAILTO='):
        print("export MAILTO=%s" % MAILTO)
    elif line.startswith('export SSL_PREFIX=ssl:'):
        print("export SSL_PREFIX=")
    elif line.startswith('export MAILFROM='):
        print("export MAILFROM=%s" % MAILFROM)
    elif line.startswith('export P4MASTERPORTNUM='):
        print("export P4MASTERPORTNUM=%s" % port)
    else:
        print(line)
    
def configure_p4_vars(instance, port):
    "Configure p4_vars"
    for line in fileinput.input('/p4/common/bin/p4_vars', inplace=True):
        substitute_vars(line, instance, port)

def configure_instance_vars(instance, port):
    "Configure instance vars"
    for line in fileinput.input('/p4/common/config/p4_%s.vars' % instance, inplace=True):
        substitute_vars(line, instance, port)

class SDPTest_base(unittest.TestCase):
    "Generic test class for others to inherit"

    def setup_everything(self):
        if 'perforce' != pwd.getpwuid(os.getuid())[0]:
            raise Exception("This test harness should be run as user 'perforce'")
        try:
            result = subprocess.check_call("sudo ls > /dev/null", shell=True, timeout=20)
        except Exception as e:
            raise NotSudo("This test harness must be run as user perforce with sudo privileges or it will not work")

    def setUp(self):
        self.setup_everything()

    def run_test(self):
        pass

    def run_cmd(self, cmd, get_output=True, timeout=5, stop_on_error=True):
        "Run cmd logging input and output"
        output = ""
        try:
            logger.debug("Running: %s" % cmd)
            if get_output:
                output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True, shell=True, timeout=timeout)
                logger.debug("Output:\n%s" % output)
            else:
                result = subprocess.check_call(cmd, stderr=subprocess.STDOUT, shell=True, timeout=timeout)
                logger.debug('Result: %d' % result)
        except Exception as e:
            if get_output:
                logger.debug("Failed Output: %s" % output)
            if stop_on_error:
                msg = 'Failed sudo_cmd: %s' % str(e)
                logger.debug(msg)
                self.fail(msg)
        return output

    def sudo_cmd(self, cmd, get_output=True, stop_on_error=True):
        "Run cmd with sudo"
        output = self.run_cmd("sudo %s" % cmd, get_output=get_output, stop_on_error=stop_on_error)
        return output

    def configure_mkdirs(self, instance):
        "Configure mkdirs.sh with a couple of key variables"
        ipaddr = get_host_ipaddress()
        for line in fileinput.input(mkdirs_file, inplace=True):
            line = line.rstrip()
            if line.startswith('P4DNSNAME'):
                print("P4DNSNAME=%s" % ipaddr)
            elif line.startswith('P4ADMINPASS'):
                print("P4ADMINPASS=Password1")
            elif line.startswith('MASTERINSTANCE'):
                print("MASTERINSTANCE=%s" % instance)
            else:
                print(line)

    def run_mkdirs(self, instance):
        "Runs the mkdirs script"
        output = self.sudo_cmd("%s %s" % (mkdirs_file, instance))
        valid_lines = ["Verified: Running as root.",
                        "It is recommended that the perforce's umask be changed to 0026 to block world access to Perforce files.",
                        "Add umask 0026 to perforce's .bash_profile to make this change."]
        for line in output.split('\n'):
            line = line.strip()
            if line and line not in valid_lines:
                self.fail('Unexpected line in mkdirs output:\n%s' % line)

#--- Test Cases

class configure_master(SDPTest_base):

    def check_dirs(self, rootdir, dirlist):
        "Checks specified directories are present"
        found_dirs = self.run_cmd("find %s -type d" % rootdir, stop_on_error=False).split()
        for d in [x.strip() for x in dirlist.split()]:
            self.assertIn(d, found_dirs)

    def p4service(self, cmd, instance, stop_on_error=True):
        "Start or stop service"
        self.run_cmd("/p4/%s/bin/p4d_%s_init %s" % (instance, instance, cmd), get_output=False, stop_on_error=stop_on_error)

    def remove_test_dirs(self, instances):
        "Remove all appropriate directories created"
        dirs_to_remove = "/depotdata/sdp /depotdata/p4 /metadata/p4 /logs/p4".split()
        for d in dirs_to_remove:
            if os.path.exists(d):
                self.sudo_cmd("rm -rf %s" % d)
        for instance in instances:
            for f in ["/p4/%s" % instance, "/p4/common"]:
                if os.path.lexists(f):
                    self.sudo_cmd("unlink %s" % f)

    def liveCheckpointTest(self, instance):
        "Test live checkpoint script"
        self.assertFalse(os.path.exists('/p4/%s/offline_db/db.domain' % instance))
        self.run_cmd('/p4/common/bin/live_checkpoint.sh %s' % instance)
        # Quick check on c=log file contents
        log_contents = self.readLog('checkpoint.log', instance)
        self.assertRegex(log_contents, "Checkpointing to /p4/%s/checkpoints/p4_%s.ckp" % (instance, instance))
        self.assertRegex(log_contents, "Rotating /p4/%s/logs/journal" % instance)
        # Make sure offline db is present
        self.assertTrue(os.path.exists('/p4/%s/offline_db/db.domain' % instance))

    def dailyBackupTest(self, instance):
        "Test daily backup script"
        jnl_counter = self.p4run('counter', 'journal')[0]['value']
        self.run_cmd('/p4/common/bin/daily_backup.sh %s' % instance)
        # Quick check on c=log file contents
        log_contents = self.readLog('checkpoint.log', instance)
        self.assertRegex(log_contents, "Dumping to /p4/%s/checkpoints/p4_%s.ckp" % (instance, instance))
        self.assertRegex(log_contents, "Rotating /p4/%s/logs/journal" % instance)
        new_jnl_counter = self.p4run('counter', 'journal')[0]['value']
        self.assertEqual(int(new_jnl_counter), int(jnl_counter) + 1)

    def readLog(self, log_name, instance):
        "Read the appropriate log file contents"
        with open('/p4/%s/logs/%s' % (instance, log_name), 'r') as fh:
            log_contents = fh.read()
        return log_contents

    def verifyTest(self, instance):
        "Test verify script"
        verify_cmd = '/p4/common/bin/p4verify.sh %s' % instance
        self.run_cmd(verify_cmd)
        log_contents = self.readLog('p4verify.log', instance)
        for depot in ["depot", "specs"]:
            verify_ok = re.compile("verify -qz //%s/...\nexit: 0" % depot, re.MULTILINE)
            self.assertRegex(log_contents, verify_ok)
        # Streams depot doesn't have any files so gives an error - we just search for it
        self.assertRegex(log_contents, re.compile("verify -qz //streams/...\n[^\n]*\nexit: 0", re.MULTILINE))
        self.assertRegex(log_contents, re.compile("verify -U -q //unload/...\n[^\n]*\nexit: 0", re.MULTILINE))
        self.assertNotRegex(log_contents, "//archive")
        # Now create verify errors and make sure we see them
        orig_depot_name = '/p4/%s/depots/depot' % instance
        new_depot_name = orig_depot_name + '.new'
        os.rename(orig_depot_name, new_depot_name)
        self.run_cmd(verify_cmd, stop_on_error=False)
        log_contents = self.readLog('p4verify.log', instance)
        for depot in ["depot"]:
            verify_ok = re.compile("verify -qz //%s/...\nerror: [^\n]*MISSING!\nexit: 1" % depot, re.MULTILINE)
            self.assertRegex(log_contents, verify_ok)
        # Rename things back again and all should be well!
        os.rename(new_depot_name, orig_depot_name)
        self.run_cmd(verify_cmd, stop_on_error=True)
        log_contents = self.readLog('p4verify.log', instance)
        for depot in ["depot", "specs"]:
            verify_ok = re.compile("verify -qz //%s/...\nexit: 0" % depot, re.MULTILINE)
            self.assertRegex(log_contents, verify_ok)

    def weeklyBackupTest(self, instance):
        "Test weekly backup script"
        jnl_counter = self.p4run('counter', 'journal')[0]['value']
        self.run_cmd('/p4/common/bin/weekly_backup.sh %s' % instance, timeout=35)
        # Quick check on c=log file contents
        log_contents = self.readLog('checkpoint.log', instance)
        self.assertRegex(log_contents, "Dumping to /p4/%s/checkpoints/p4_%s.ckp" % (instance, instance))
        self.assertRegex(log_contents, "Rotating /p4/%s/logs/journal" % instance)
        self.p4.disconnect()    # Need to reconnect as weekly has restarted p4d
        self.p4.connect()
        new_jnl_counter = self.p4run('counter', 'journal')[0]['value']
        self.assertEqual(int(new_jnl_counter), int(jnl_counter) + 1)

    def configureServer(self, instance):
        "Set various configurables for master"
        configurables = """
            security=3
            defaultChangeType=restricted
            run.users.authorize=1
            db.peeking=2
            dm.user.noautocreate=2
            dm.user.resetpassword=1
            filesys.P4ROOT.min=1G
            filesys.depot.min=1G
            filesys.P4JOURNAL.min=1G
            p4 configure unset monitor
            server=3
            net.tcpsize=256k
            lbr.bufsize=256k
            server.commandlimits=2
            serverlog.retain.3=7
            serverlog.retain.7=7
            serverlog.retain.8=7""".split("\n")
        instance_configurables = """
            journalPrefix=/p4/${SDP_INSTANCE}/checkpoints/p4_${SDP_INSTANCE}
            server.depot.root=/p4/${SDP_INSTANCE}/depots
            serverlog.file.3=/p4/${SDP_INSTANCE}/logs/errors.csv
            serverlog.file.7=/p4/${SDP_INSTANCE}/logs/events.csv
            serverlog.file.8=/p4/${SDP_INSTANCE}/logs/integrity.csv""".split("\n")
        for c in [x.strip() for x in configurables]:
            self.p4run("configure set %s" % c)
        for ic in instance_configurables:
            ic = ic.strip()
            ic.replace("${SDP_INSTANCE}", instance)
            self.p4run("configure set %s" % ic)

    def configureReplication(self):
        "Configures stuff required for replication"

    def p4run(self, *args):
        "Run the command logging"
        logger.debug('p4 cmd: %s' % ",".join([str(x) for x in args]))
        result = self.p4.run(args)
        logger.debug('result: %s' % str(result))
        return result

    def resetTest(self, instances):
        for instance in instances:
            self.sudo_cmd("ps -ef | grep p4d_%s | awk '{print $2}' | xargs kill > /dev/null 2>&1" % instance, stop_on_error=False)
        self.remove_test_dirs(instances)
        self.sudo_cmd("cp -R /sdp /depotdata/sdp")
        self.sudo_cmd("sudo chown -R perforce:perforce /depotdata/sdp")
        for f in ["/p4/p4.crontab", "/p4/p4.crontab.replica"]:
            if os.path.exists(f):
                os.remove(f)
        for instance in instances:
        	filename = "/p4/%s" %instance
        	do_unlink(filename)
        	do_unlink(filename.lower())

    def configureInstance(self, instance, port):
        "Configure the master instance"
        # Stop the Perforce service if currently running from a previous run in case it is accessing dirs
        self.resetTest(instance)
        self.configure_mkdirs(instance)
        self.run_mkdirs(instance)
        depotdata_dir_list = """
            /depotdata/p4
            /depotdata/p4/SDP_INSTANCE
            /depotdata/p4/SDP_INSTANCE/depots
            /depotdata/p4/SDP_INSTANCE/bin
            /depotdata/p4/SDP_INSTANCE/tmp
            /depotdata/p4/SDP_INSTANCE/checkpoints
            /depotdata/p4/common
            /depotdata/p4/common/bin
            /depotdata/p4/common/bin/triggers
            /depotdata/p4/common/lib""".replace("SDP_INSTANCE", instance)
        logdata_dir_list = """
            /logs
            /logs/p4
            /logs/p4/SDP_INSTANCE
            /logs/p4/SDP_INSTANCE/logs""".replace("SDP_INSTANCE", instance)
        metadata_dir_list = """
            /metadata
            /metadata/p4
            /metadata/p4/SDP_INSTANCE
            /metadata/p4/SDP_INSTANCE/root
            /metadata/p4/SDP_INSTANCE/root/save
            /metadata/p4/SDP_INSTANCE/offline_db""".replace("SDP_INSTANCE", instance)
        self.check_dirs('/depotdata', depotdata_dir_list)
        self.check_dirs('/logs', logdata_dir_list)
        self.check_dirs('/metadata', metadata_dir_list)
        configure_instance_vars(instance, port)
        configure_p4_vars(instance, port)
        
    def instanceTest(self, instance, port):
        # So now we want to start up the Perforce service
        self.p4service("start", instance)

        p4 = P4.P4()
        self.p4 = p4
        p4.port = 'localhost:%s' % port
        p4.user = 'p4admin'
        p4.connect()

        # Create our user and set password
        user = p4.fetch_user('p4admin')
        p4.save_user(user)
        p4.run_password('', 'Password1')
        p4.password = 'Password1'
        p4.run_login()
        # Make him superuser
        prot = p4.fetch_protect()
        p4.save_protect(prot)

        # Things to setup
        # - create spec depot
        # - create a workspace and add at least one file
        # - configure the various tunables
        # - create server definitions - master and replica
        # - create service user for replica
        # - run daily_checkpoint - check for error
        # - run live_checkpoint - make sure offline_db seeded
        # - run daily checkpoint more than once - create change lists in between times
        # - run weekly_checkpoint - check result

        p4.run('configure', 'set', 'server.depot.root=/p4/%s/depots' % instance)
        p4.run('admin', 'restart')
        p4.disconnect() # New depot won't show up unless we do this 
        time.sleep(1)
        p4.connect()
        if instance == 'Master':
            if not os.path.lexists("/p4/%s" % instance.lower()):
                self.run_cmd("ln -s /p4/%s /p4/%s" % (instance, instance.lower()))
		
        depot = p4.fetch_depot('specs')
        self.assertEqual(depot['Map'], 'specs/...')
        depot['Type'] = 'spec'
        p4.save_depot(depot)

        depot = p4.fetch_depot('unload')
        self.assertEqual(depot['Map'], 'unload/...')
        depot['Type'] = 'unload'
        p4.save_depot(depot)

        depot = p4.fetch_depot('archive')
        self.assertEqual(depot['Map'], 'archive/...')
        depot['Type'] = 'archive'
        p4.save_depot(depot)

        depot = p4.fetch_depot('streams')
        self.assertEqual(depot['Map'], 'streams/...')
        depot['Type'] = 'stream'
        p4.save_depot(depot)

        p4.disconnect() # New depot won't show up unless we do this 
        p4.connect()

        depots = p4.run_depots()
        self.assertEqual(5, len(depots))

        ws_name = 'test_ws'
        ws = p4.fetch_client(ws_name)
        ws['Root'] = '/tmp/test_ws'
        ws['View'] = ['//depot/main/... //%s/...' % ws_name]
        p4.save_client(ws)
        p4.client = ws_name

        if not os.path.exists(ws['Root']):
            os.mkdir(ws['Root'])
        fname = '/tmp/%s/file1' % ws_name
        if os.path.exists(fname):
            os.chmod(fname, stat.S_IWRITE)
            os.unlink(fname)
        with open(fname, 'w') as fh:
            fh.write('test data\n')
        p4.run_add(fname)
        chg = p4.fetch_change()
        chg['Description'] = 'Initial file'
        p4.save_submit(chg)

        changes = p4.run_changes()
        self.assertEqual(1, len(changes))

        self.liveCheckpointTest(instance)
        self.dailyBackupTest(instance)
        self.dailyBackupTest(instance)
        # Manually rotate journals again and ensure daily backup handles that
        self.p4run('admin', 'journal', '/p4/%s/checkpoints/p4_%s' % (instance, instance))
        self.dailyBackupTest(instance)

        self.verifyTest(instance)

        # Tests:
        # - totalusers.py
        # - the various _init scripts
        # 

        print('\n\nAbout to run weekly backup which sleeps for 30 seconds, so be patient...!')
        self.weeklyBackupTest(instance)
        # print(p4.run_admin('stop'))

    def runTest(self):
        "Configure the master instance"
        instances = ["1", "Master"]
        self.resetTest(instances)
        self.configureInstance("1", "1667")
        self.instanceTest("1", "1667")
        self.resetTest(instances)
        self.configureInstance("Master", "2667")
        self.instanceTest("Master", "2667")

if __name__ == "__main__":
    init_logging()
    unittest.main()
