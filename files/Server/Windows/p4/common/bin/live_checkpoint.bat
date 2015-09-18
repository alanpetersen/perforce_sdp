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
set SCRIPT_NAME=live_checkpoint.bat
set SCRIPT_TASK=Live Checkpoint

call %current_script_dir%p4env.bat %1
if errorlevel 1 (
   echo %SCRIPT_TASK% aborted - invalid config file found.
   echo .
   exit /B 1
)

if x%SDP_INSTANCE% == x (
   echo %SCRIPT_TASK% aborted - no instance parameter specified.
   echo .
   exit /B 1
)

set ORIG_DIR=%CD%
set LOGFILE=checkpoint.log
set LOG=%LOGS_DIR%\%LOGFILE%
set JNL=
set CKP=

cd /d "%LOGS_DIR%"

:: Initialize log with a call to p4login.
call %SCRIPTS_DIR%\p4login > %LOG% 2>&1
date /t >> %LOG%
time /t >> %LOG%

if NOT ERRORLEVEL 0 goto ERROR

if exist %CHECKPOINTS_DIR%\ckp_running.txt (
    echo "Last checkpoint process hasn't completed. Check the backup process." >> %LOG%
    goto ERROR
) else (
    echo "Checkpoint running." > %CHECKPOINTS_DIR%\ckp_running.txt
)

:: Check if we are in admin mode - things won't work otherwise - can't stop the service.
net session > NUL 2>&1
IF not %ERRORLEVEL% EQU 0 ( 
    ECHO You must run %SCRIPT_NAME% with Administrator privileges.>> %LOG% 
    goto ERROR
) 


echo Determining current journal counter with 'p4 counter journal'. >> %LOG%

for /F %%F in ('%SDP_INSTANCE_BIN_DIR%\p4 counter journal') do (set JNL=%%F) 
if %JNL%x == x (
   echo ERROR:>>%LOG%
   echo ERROR:  Could not determine journal counter; JNL not set!>>%LOG%
   echo ERROR:>>%LOG%
   goto ERROR 
)
   
set /A CKP=JNL+1
if %CKP%x == x (
   echo ERROR:>>%LOG%
   echo ERROR:  Could not determine next checkpoint number; CKP not set!>>%LOG%
   echo ERROR:>>%LOG%
   goto ERROR
)

echo Checkpoint/journal numbers are %CKP%/%JNL%.>> %LOG%

echo Start %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK%>> %LOG%
echo .>> %LOG%
echo %SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT% -jc -Z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%>> %LOG%
%SDP_INSTANCE_BIN_DIR%\p4d -r "%P4ROOT%" -jc -Z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME% >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo Recreating Off-line db files from %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz.>> %LOG%
echo .>> %LOG%
echo del /f /q %OFFLINE_DB_DIR%\db.*>> %LOG%
del /f /q %OFFLINE_DB_DIR%\db.* >> %LOG% 2>&1
echo %SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -z -jr %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz>> %LOG%
%SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -z -jr %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

set ERRORTEXT=

goto SKIPERROR

:ERROR
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1
echo %SCRIPT_TASK% Failed >> %LOG% 2>&1
echo %SCRIPT_TASK% Failed - please see %LOG%
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1

set ERRORTEXT=%SCRIPT_TASK% failed!

:SKIPERROR

date /t >> %LOG%
time /t >> %LOG%

echo End %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK% >> %LOG%

echo Renaming server log files.>> %LOG%
echo . >> %LOG%

cd /d "%SCRIPTS_DIR%"

if "%ERRORTEXT%x" == "x" (
   echo Calling %SCRIPTS_DIR%\remove_old_logs.bat %CKP% %JNL% %KEEPCKPS% %KEEPLOGS% >> %LOG%
   call %SCRIPTS_DIR%\remove_old_logs.bat %CKP% %JNL% %KEEPCKPS% %KEEPLOGS% >> %LOG% 2>&1
) else (
   echo Skipping old checkpoint and server log removal due to error.>>%LOG%
)

cd /d "%LOGS_DIR%"

if exist %LOGFILE%.%CKP% (
   if exist %LOGFILE%.%CKP%.old (del /f /q %LOGFILE%.%CKP%.old >> %LOG% 2>&1)
   move /y %LOGFILE%.%CKP% %LOGFILE%.%CKP%.old >> %LOG% 2>&1
)

echo Copying %LOG% to %LOGFILE%.%CKP% >> %LOG%
copy /y %LOG% %LOGFILE%.%CKP% > NUL

%SCRIPTS_DIR%\blat.exe -install %mailhost% %mailfrom% 
%SCRIPTS_DIR%\blat.exe %LOG%.%CKP% -to %maillist% -subject "%ERRORTEXT% %COMPUTERNAME% %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK% log"

if "%ERRORTEXT%x" == "x" (
    echo .
    echo %SCRIPT_TASK% completed successfully! See %LOG%
)

:END

del %CHECKPOINTS_DIR%\ckp_running.txt

cd /d "%ORIG_DIR%"

