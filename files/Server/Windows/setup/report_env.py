# report_env.py
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
import sys

import P4

from SDPEnv import SDPException, SDPConfig, find_record

class SDPConfigReport(SDPConfig):

    # Validate:
    # - master server on this host first - then any replica servers
    # - server exists (so serverid)
    # - server is of correct type
    # - adminpass file exists
    # - adminpass file is correct
    # - any replica users exist as service users
    # - replica users have long password timeout
    # - configure variables are as expected (warn if different - not always an error)
    # - if on replica then P4TICKETS variables

    def report_config(self):
        "Reports on whether the current configuration is valid - talks to master server"
        errors = []
        info = []
        p4 = P4.P4()
        m_name = self.get_master_instance_name()
        m_instance = self.instances[m_name]
        if m_instance.is_current_host():
            p4.port = m_instance.sdp_p4port_number
            p4.user = m_instance.sdp_p4superuser
            p4.connect()
            p4.password = m_instance.sdp_p4superuser_password
            try:
                p4.run_login()
            except P4.P4Exception as e:
                print("Failed to login to '%s' as user '%s': %s" % (
                    p4.port, p4.user, p4.password))
                return
            servers = p4.run_servers()
            m_svr = find_record(servers, 'ServerID', m_name)
            if not m_svr:
                errors.append("Error: no 'server' record defined for instance '%s' - use 'p4 server' to define" %
                            m_name)
            elif m_svr['Services'] != 'standard':
                errors.append("Error: 'server' record for instance '%s' must have 'Services: standard'" % m_name)
                info.append("Server record exists for master instance '%s'" % m_name)

            users = p4.run_users("-a")
            for i_name in self.instances.keys():
                instance = self.instances[i_name]
                svr = find_record(servers, 'ServerID', i_name)
                if not svr:
                    errors.append("Error: no 'server' record defined for instance '%s' - use 'p4 server' to define" %
                            i_name)
                else:
                    info.append("Server record exists for instance '%s'" % i_name)
                    if svr['Services'] != instance.sdp_service_type:
                        errors.append("Error: 'server' record for instance '%s' defines Services as '%s' - expected '%s'" %
                                (i_name, svr['Services'], instance.sdp_service_type))
                if i_name != m_name:
                    user = find_record(users, 'User', instance.sdp_serverid)
                    if not user:
                        errors.append("Error: no 'user' record defined for instance '%s' - use 'p4 user' to define a service user" %
                                i_name)
                    else:
                        info.append("User record exists for instance '%s'" % i_name)
                        if user['Type'] != 'service':
                            errors.append("Error: 'user' record for instance '%s' defines Type as '%s' - expected '%s'" %
                                    (i_name, user['Type'], 'service'))
                # Check admin password file and contents
                admin_pass_filename = os.path.join(instance.common_bin_dir, instance.admin_pass_filename)
                if not os.path.exists(admin_pass_filename):
                    errors.append("Admin password file does not exist: %s" % admin_pass_filename)
                else:
                    info.append("Admin password file exists")
                    password = ""
                    with open(admin_pass_filename, "r") as fh:
                        password = fh.read()
                    p4.password = password
                    try:
                        result = p4.run_login()
                        self.logger.debug('Login result: %s' % str(result))
                        info.append("Admin password is correct")
                    except Exception as e:
                        errors.append("Failed to login - admin password is not correct: '%s', %s" % (password, e.message()))
        if p4.connected():
            p4.disconnect()

        links_and_dirs = self.get_instance_links_and_dirs()
        files_to_copy = self.get_instance_files_to_copy()
        files_to_merge = self.get_files_to_merge()
        self.mk_links_and_dirs(links_and_dirs, files_to_copy, files_to_merge)
        print("\nThe following environment values were checked:")
        print("\n".join(info))
        if errors:
            print("\nThe following ERRORS/WARNINGS encountered:")
            print("\n".join(errors))
        else:
            print("\nNo ERRORS/WARNINGS found.")

def main():
    try:
        sdpreport = SDPConfigReport()
        sdpreport.report_config()
    except SDPException as e:
        print("ERROR: ", str(e))
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
