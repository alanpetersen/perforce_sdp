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
set SCRIPT_NAME=weekly_backup.bat
set SCRIPT_TASK=Weekly Checkpoint
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
set OFF_JNL=

cd /d "%LOGS_DIR%"

:: Initialize log with a call to p4login.
call %SCRIPTS_DIR%\p4login > %LOG% 2>&1
if not %ERRORLEVEL% EQU 0 goto ERROR

call :CHECK_OFFLINE_DB_EXISTS

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

date /t >> %LOG%
time /t >> %LOG%

echo Determining current journal counter with 'p4 counter journal'.>> %LOG%

for /F %%F in ('%SDP_INSTANCE_BIN_DIR%\p4 counter journal') do (set JNL=%%F)
if %JNL%x == x (
   echo ERROR:>>%LOG%
   echo ERROR:  Could not determine journal counter; JNL not set!>> %LOG%
   echo ERROR:>>%LOG%
   goto ERROR
)

date /t > %LOG%
time /t >> %LOG%

set /A CKP=JNL+1
if %CKP%x == x (
   echo ERROR:>>%LOG%
   echo ERROR:  Could not determine next checkpoint number; CKP not set!>>%LOG%
   echo ERROR:>>%LOG%
   goto ERROR
)

echo Live checkpoint/journal numbers are %CKP%/%JNL%.>> %LOG%

:: Find out the current journal counter for our offline database
:: Dump just the db.counters table to stdout and parse for the counter
for /F "tokens=5" %%F in ('"%SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jd - db.counters | findstr @journal@"') do (set OFF_JNL=%%F)
if %OFF_JNL%x == x (
    echo ERROR:>>%LOG%
    echo ERROR:  Could not determine offline journal counter; OFF_JNL not set!>>%LOG%
    echo ERROR:>>%LOG%
    goto ERROR
)

:: Turn "@123@" to "123"
set OFF_JNL=%OFF_JNL:~1,-1%

echo Offline journal number is %OFF_JNL%.>> %LOG%

sc queryex %SDP_INSTANCE_P4SERVICE_NAME% | find /I "PID" > pid.txt
for /F "tokens=1,2 delims=: " %%i in (pid.txt) DO (set P4SPID=%%j)

svcinst stop -n %SDP_INSTANCE_P4SERVICE_NAME% >> %LOG% 2>&1

REM Wait for service to stop.
:RETRY
echo Waiting for service %SDP_INSTANCE_P4SERVICE_NAME% to stop...
timeout /t 60
sc query %SDP_INSTANCE_P4SERVICE_NAME% | find /I "stopped"
if not %ERRORLEVEL% == 0 goto RETRY

date /t >> %LOG%
time /t >> %LOG%

echo Start %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK%>> %LOG%
echo .>> %LOG%

echo Cutting off current journal>> %LOG%
echo %SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT% -jj %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%>> %LOG%
%SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT% -jj %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME% >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

time /t >> %LOG%

echo Applying all oustanding journal files to offline_db>> %LOG%
echo .>> %LOG%

for /L %%J in (%OFF_JNL%,1,%JNL%) do (
    echo %SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jr %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%J>> %LOG%
    %SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jr %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%J >> %LOG% 2>&1
    if NOT ERRORLEVEL 0 goto ERROR
    time /t >> %LOG%
)

date /t >> %LOG%
time /t >> %LOG%
echo Swapping out db.* files>> %LOG%
echo .  >> %LOG% 2>&1

if not exist %P4ROOT%\save mkdir %P4ROOT%\save

echo del /f /q %P4ROOT%\save\db.*>> %LOG%
del /f /q %P4ROOT%\save\db.* >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo move /y %P4ROOT%\db.* %P4ROOT%\save>> %LOG%
move /y %P4ROOT%\db.* %P4ROOT%\save >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo move /y %OFFLINE_DB_DIR%\db.* %P4ROOT%>> %LOG%
move /y %OFFLINE_DB_DIR%\db.* %P4ROOT% >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

echo Restarting Perforce Server>> %LOG%
time /t >> %LOG%

net start %SDP_INSTANCE_P4SERVICE_NAME% >> %LOG% 2>&1

date /t >> %LOG%
time /t >> %LOG%

echo Dump out new checkpoint from previous live db files.>> %LOG%
echo %SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT%\save -jd -z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz>> %LOG%
%SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT%\save -jd -z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

date /t >> %LOG%
time /t >> %LOG%
echo Deleting %P4ROOT%\save\db.* after successful completion of checkpoint.>> %LOG%
echo /f /q %P4ROOT%\save\db.*>> %LOG%
del /f /q %P4ROOT%\save\db.* >> %LOG% 2>&1

echo Recreate offline db files for quick recovery process.>> %LOG%
echo .>> %LOG%
echo %SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jr -z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz>> %LOG%
%SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jr -z %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%CKP%.gz >> %LOG% 2>&1
if NOT ERRORLEVEL 0 goto ERROR

set ERRORTEXT=

goto SKIP_ERROR

::------------------------------------------------
:CHECK_OFFLINE_DB_EXISTS
:: Check offline_db has some data
if not exist %OFFLINE_DB_DIR%\db.counters (
    call :REPORT The offline db files don't exist: %OFFLINE_DB_DIR%
    call :REPORT Please run live_checkpoint.bat to create the offline database.
    call :REPORT Note that this may take some considerable amount of time and lock
    call :REPORT your live server - BE CAREFULL!!!!
    goto ERROR
)
goto :EOF

::------------------------------------------------
:REPORT
:: Report string and save to log
echo .
echo %*
echo . >> %LOG%
echo %* >> %LOG%
goto :EOF

::------------------------------------------------

:SERVERUPERROR
echo .  >> %LOG% 2>&1
echo Server is still up, cannot continue!!!!!  >> %LOG% 2>&1
echo .  >> %LOG% 2>&1

:ERROR
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1
echo %SCRIPT_TASK% Failed >> %LOG% 2>&1
echo %SCRIPT_TASK% Failed - please see %LOG%
echo .
echo ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR >> %LOG% 2>&1

set ERRORTEXT=%SCRIPT_TASK% Failed!

:SKIP_ERROR

date /t >> %LOG%
time /t >> %LOG%

echo End %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK%>> %LOG%

echo Checking Disk Space>> %LOG%

%SDP_INSTANCE_BIN_DIR%\p4 diskspace >> %LOG% 2>&1

cd /d "%SCRIPTS_DIR%"

if "%ERRORTEXT%x" == "x" (
   echo Calling %SCRIPTS_DIR%\remove_old_logs.bat %CKP% %JNL% %KEEPCKPS% %KEEPLOGS%>> %LOG%
   call %SCRIPTS_DIR%\remove_old_logs.bat %CKP% %JNL% %KEEPCKPS% %KEEPLOGS% >> %LOG% 2>&1
   echo Calling %SCRIPTS_DIR%\remove_old_checkpoints.bat %CKP% %KEEPCKPS%>> %LOG%
   call %SCRIPTS_DIR%\remove_old_checkpoints.bat %CKP% %KEEPCKPS% >> %LOG% 2>&1
) else (
   echo Skipping removal of old checkpoints, checkpoint and server logs due to error.>>%LOG%
)

cd /d "%LOGS_DIR%"

if exist %LOGFILE%.%CKP% (
   if exist %LOGFILE%.%CKP%.old (del /f /q %LOGFILE%.%CKP%.old >> %LOG% 2>&1)
   move /y %LOGFILE%.%CKP% %LOGFILE%.%CKP%.old >> %LOG% 2>&1
)

echo Copying %LOG% to %LOGFILE%.%CKP% >> %LOG%
copy /y %LOG% %LOGFILE%.%CKP% > NUL

TIME /t >> %LOG%
echo Operation complete. Sending email. >> %LOG%

%SCRIPTS_DIR%\blat.exe -install %mailhost% %mailfrom%
%SCRIPTS_DIR%\blat.exe %LOG%.%CKP% -to %maillist% -subject "%ERRORTEXT% %COMPUTERNAME% %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK% log"

if "%ERRORTEXT%x" == "x" (
    echo .
    echo %SCRIPT_TASK% completed successfully! See %LOG%
)

del %CHECKPOINTS_DIR%\ckp_running.txt

:END

CD /D "%ORIG_DIR%"
