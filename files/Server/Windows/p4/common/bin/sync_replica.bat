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

:: This script must run for a replica under a login that has access to the %REMOTE_DEPOTDATA_ROOT%
:: share on the master server. That same login also has to have access to the replica server.

@echo off
set current_script_dir=%~p0
call %current_script_dir%p4env.bat %1
if errorlevel 1 (
   echo Sync Replica aborted - invalid config file found.
   echo .
   exit /B 1
)

if x%SDP_INSTANCE% == x (
   echo Sync Replica aborted - no instance specified.
   echo .
   exit /B 1
)

set LOG=%LOGS_DIR%\sync_replica.log

echo Start Sync Replica > %LOG% 2>&1
date /t  >> %LOG% 2>&1
time /t  >> %LOG% 2>&1

:: Need to login to the Master server (via P4TARGET)
if not exist %ADMIN_PASS_FILE% (
    set errmsg=Can't find admin password file %ADMIN_PASS_FILE%
    echo %errmsg%
    exit /b 1
)
%SDP_INSTANCE_BIN_DIR%\p4 -p %P4TARGET% -u %SDP_P4SUPERUSER% login -a < %ADMIN_PASS_FILE%
if not %ERRORLEVEL% EQU 0 goto ERROR

echo xcopy /D /I %REMOTE_CHECKPOINTS_DIR%\*.* %CHECKPOINTS_DIR%\*.* >> %LOG% 2>&1
xcopy /D /I %REMOTE_CHECKPOINTS_DIR%\*.* %CHECKPOINTS_DIR%\*.* >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo Determining current journal counter with 'p4 counter journal'.>> %LOG%
for /F %%F in ('%SDP_INSTANCE_BIN_DIR%\p4 -p %P4TARGET% -u %SDP_P4SUPERUSER% counter journal') do (set JNL=%%F)
if %JNL%x == x (
   echo ERROR:>>%LOG%
   echo ERROR:  Could not determine journal counter; JNL not set!>>%LOG%
   echo ERROR:>>%LOG%
   goto ERROR
)

echo Journal counter %JNL% found.>> %LOG%

set /a REMOVEJNL=%JNL%-%KEEPCKPS%-1 >> %LOG% 2>&1

echo attrib -r %CHECKPOINTS_DIR%\*.%REMOVEJNL%.*  >> %LOG% 2>&1
attrib -r %CHECKPOINTS_DIR%\*.%REMOVEJNL%.*  >> %LOG% 2>&1
echo del %CHECKPOINTS_DIR%\*.%REMOVEJNL%.*  >> %LOG% 2>&1
del %CHECKPOINTS_DIR%\*.%REMOVEJNL%.*  >> %LOG% 2>&1
echo del %OFFLINE_DB_DIR%\db.*  >> %LOG% 2>&1
del %OFFLINE_DB_DIR%\db.*  >> %LOG% 2>&1

REM Unset P4NAME to allow p4d 2012.2 to recover checkpoint
set P4NAME=
echo %SDP_INSTANCE_BIN_DIR%\p4d.exe -r %OFFLINE_DB_DIR% -jr -z %CHECKPOINTS_DIR%\p4_%REMOTE_SDP_INSTANCE%.ckp.%JNL%.gz >> %LOG% 2>&1
%SDP_INSTANCE_BIN_DIR%\p4d.exe -r %OFFLINE_DB_DIR% -jr -z %CHECKPOINTS_DIR%\p4_%REMOTE_SDP_INSTANCE%.ckp.%JNL%.gz  >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo End Sync Replica >> %LOG% 2>&1
date /t  >> %LOG% 2>&1
time /t  >> %LOG% 2>&1

set ERRORTEXT=

goto SKIP_ERROR

:ERROR
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1
echo Sync Replica Failed >> %LOG% 2>&1
echo Sync Replica Failed - please see %LOG%
echo .
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1

set ERRORTEXT=Sync Replica Failed!

:SKIP_ERROR

%SCRIPTS_DIR%\blat.exe -install %mailhost% %mailfrom% 
%SCRIPTS_DIR%\blat.exe %LOG% -to %maillist% -subject "%ERRORTEXT% %COMPUTERNAME% %SDP_INSTANCE_P4SERVICE_NAME% Sync Replica log"


if "%ERRORTEXT%x" == "x" (
    echo .
    echo Sync Replica completed successfully! See %LOG%
)

:END
