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

set current_script_dir=%~p0
call %current_script_dir%p4env.bat %1s
if errorlevel 1 (
   echo Replica status aborted - invalid config file found.
   echo .
   exit /B 1
)
set LOG=%LOGS_DIR%\replica_status.log

@call %SCRIPTS_DIR%\p4login.bat
%SDP_INSTANCE_BIN_DIR%\p4 -p %P4PORT% -u %SDP_P4SUPERUSER% pull -lj > %LOG% 2>&1

%SCRIPTS_DIR%\blat.exe -install %mailhost% %admin% 
%SCRIPTS_DIR%\blat.exe %LOG% -to %maillist% -subject "%COMPUTERNAME% %SDP_INSTANCE_P4SERVICE_NAME% Daily Replica Status"
