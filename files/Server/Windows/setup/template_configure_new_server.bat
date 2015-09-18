::-----------------------------------------------------------------------------
:: Copyright (c) Perforce Software, Inc., 2007-2014. All rights reserved
::
:: Redistribution and use in source and binary forms, with or without
:: modification, are permitted provided that the following conditions are met:
::
:: 1  Redistributions of source code must retain the above copyright
::    notice, this list of conditions and the following disclaimer.
::
:: 2.  Redistributions in binary form must reproduce the above copyright
::     notice, this list of conditions and the following disclaimer in the
::     documentation and/or other materials provided with the distribution.
::
:: THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
:: "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
:: LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
:: FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE
:: SOFTWARE, INC. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
:: SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
:: LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
:: DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
:: ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
:: TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
:: THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
:: DAMAGE.
::-----------------------------------------------------------------------------
::
:: This file is intended to be parsed by SDPEnv.py and used to create a custom
:: version for each instance that is being configured.
::
:: It is possible to edit and run this file directly, in which case you may
:: wish to uncomment the values in the section below (which are normally
:: created by SDPEnv.py processing)
:: If you do run it manually then:
::  - Set P4PORT and P4USER and run p4 login before running this script.
::  - If you are running a pre-2014.1 server, you should also run p4 triggers
::    put in the SetDefaultDepotSpeMapField.py trigger first as well. 

set instance=%1

::-----------------------------------------------------------------------------
:: Values written by SDPEnv.py:
::
:: The server.depot.root configurable is valid for P4D 2014.1+
::      p4 configure set server.depot.root=c:\p4\%instance%\depots
::      p4 configure set journalPrefix=c:\p4\%instance%\checkpoints\p4_%instance%
:: The db.peeking configurable is valid for P4D 2013.3+
::      p4 configure set db.peeking=2
::
:: The following are valid for replication scenarios
::      p4 configure set rpl.checksum.auto=1
::      p4 configure set rpl.checksum.change=2
::      p4 configure set rpl.checksum.table=1
::      p4 configure set rpl.compress=3

p4 configure set defaultChangeType=restricted
p4 configure set run.users.authorize=1
p4 configure set dm.user.noautocreate=2
p4 configure set dm.user.resetpassword=1
p4 configure set filesys.P4ROOT.min=1G
p4 configure set filesys.depot.min=1G
p4 configure set filesys.P4JOURNAL.min=1G
p4 configure set monitor=1
p4 configure set server=3
:: The net.tcpsize is best left unset for 2014.2+ servers.
p4 configure set net.tcpsize=512k
p4 configure set lbr.bufsize=1M
:: 2013.2 - Turn off max* commandline overrides.
p4 configure set server.commandlimits=2

p4 counter SDP "%DATE%"

echo It is also recommended that you run "p4 configure set security=3"
