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

@echo off
set current_script_dir=%~p0
call %current_script_dir%p4env.bat %1
if errorlevel 1 (
   echo Verify aborted - invalid config file found.
   echo .
   exit /B 1
)

set LOG=%LOGS_DIR%\p4verify.log
set P4USER=%SDP_P4SUPERUSER%
set STATUS=OK: All scanned depots verified OK.

echo If there are errors in this log, contact support@perforce.com. > %LOG%

@call %SCRIPTS_DIR%\p4login.bat >> %LOG% 2>&1
if not %ERRORLEVEL% EQU 0 goto ERROR

FOR /F "usebackq tokens=2,4" %%i IN (`%SDP_INSTANCE_BIN_DIR%\p4 depots`) DO call :verify_depot %%i %%j

goto check_status

:verify_depot
set dname=%1
set dtype=%2
set doverify=false
IF x%dtype%==xlocal set doverify=true
IF x%dtype%==xstream set doverify=true
IF x%dtype%==xspec set doverify=true
IF x%doverify%==xtrue (
    echo === Started verify of %SDP_INSTANCE_P4SERVICE_NAME% //%dname%/... at: >> %LOG%
    DATE /t >> %LOG%
    TIME /t >> %LOG%
    %SDP_INSTANCE_BIN_DIR%\p4 verify -q //%dname%/...  >> %LOG% 2>&1
) else (
    echo Ignoring depot %dname% of type %dtype%>>%LOG%
)
goto :EOF


:check_status
set STATUS=

find "BAD" %LOG% > nul
if %ERRORLEVEL% EQU 0 SET STATUS=Warning: Verify errors detected.  Review the log: %LOG%. 

find "MISSING" %LOG% > nul
if %ERRORLEVEL% EQU 0 SET STATUS=Warning: Verify errors detected.  Review the log: %LOG%.

find /I "MAX" %LOG% > nul
if %ERRORLEVEL% EQU 0 SET STATUS=Warning: Max Limit error detected.  Review the log: %LOG%.

if "%STATUS%x" == "x" goto SKIP_ERROR

:ERROR
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1
echo Verify Failed >> %LOG% 2>&1
echo Verify Failed - please see %LOG%
echo .
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1

set ERRORTEXT=Daily Checkpoint Failed!

:SKIP_ERROR

TIME /t >> %LOG%
echo Operation complete. Sending email. >> %LOG%

%SCRIPTS_DIR%\blat.exe -install %mailhost% %mailfrom%
%SCRIPTS_DIR%\blat.exe %LOG% -to %maillist% -subject "%COMPUTERNAME% %SDP_INSTANCE_P4SERVICE_NAME% Verification log: %STATUS%"

if "%STATUS%x" == "x" (
    echo .
    echo Verify completed successfully! See %LOG%
)
