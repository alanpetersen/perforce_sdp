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

:: Place the new p4.exe and p4d.exe binaries into the <depotdata>:\p4\common\bin
:: folder prior to running this script.

@echo off
set current_script_dir=%~p0
set SCRIPT_NAME=2013.3_upgrade.bat
set SCRIPT_TASK=Upgrade Server from pre2013.3 Version
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

setlocal enableextensions

set ORIG_DIR=%CD%
set LOGFILE=upgrade.log
set LOG=%LOGS_DIR%\%LOGFILE%
set JNL=
set CKP=
set OFF_JNL=

cd /d "%LOGS_DIR%"

@echo on

:: Initialize the log file with a call to p4login.
call %SCRIPTS_DIR%\p4login > %LOG% 2>&1
if not %ERRORLEVEL% EQU 0 goto ERROR

call :REPORT_TIME

call :CHECK_EXISTS %SCRIPTS_DIR%\p4.exe
if not %ERRORLEVEL% EQU 0 goto ERROR
call :CHECK_EXISTS %SCRIPTS_DIR%\p4d.exe
if not %ERRORLEVEL% EQU 0 goto ERROR

:: Check if we are in admin mode - things won't work otherwise - can't stop the service.
net session > NUL 2>&1
IF not %ERRORLEVEL% EQU 0 (
    call :ERROR_REPORT You must run %SCRIPT_NAME% with Administrator privileges.
    goto ERROR
)

call :REPORT Determining current journal counter with 'p4 counter journal'.
for /F %%F in ('%SDP_INSTANCE_BIN_DIR%\p4 counter journal') do (set JNL=%%F)
if %JNL%x == x (
   call :ERROR_REPORT Could not determine journal counter; JNL not set!
   goto ERROR
)

call :REPORT_TIME

set /A CKP=JNL+1
if %CKP%x == x (
   call :ERROR_REPORT Could not determine next checkpoint number; CKP not set!
   goto ERROR
)

call :REPORT Live checkpoint/journal numbers are %CKP%/%JNL%.

set LATEST_CHECKPOINT=%CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.ckp.%JNL%.gz
if not exist %LATEST_CHECKPOINT% (
	call :REPORT Required checkpoint file %LATEST_CHECKPOINT% is missing - can't upgrade!
	call :REPORT Run daily_backup.bat to create the appropriate checkpoint file before re-running this script.
	call :REPORT If necessary you may need to set limit_one_daily_checkpoint=false in c:\p4\config\sdp_config.ini first.
	goto END
)

:: ======================================
call :REPORT Recreating offline_db from checkpoint with new executable.
call :REPORT Will proceed with upgrading service once this has been done.
call :REPORT To see how long this is likely to take, see previous checkpoint.log files.

call :EXECUTE %SCRIPTS_DIR%\p4d.exe -r %OFFLINE_DB_DIR% -z -jr %LATEST_CHECKPOINT%
if NOT ERRORLEVEL 0 goto ERROR

call :REPORT_TIME

:: ======================================
:: Find out the current journal counter for our offline database
:: Dump just the db.counters table to stdout and parse for the counter
for /F "tokens=5" %%F in ('"%SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jd - db.counters | findstr @journal@"') do (set OFF_JNL=%%F)
if %OFF_JNL%x == x (
    Call :ERROR_REPORT Could not determine offline journal counter; OFF_JNL not set!
    goto ERROR
)

:: Turn "@123@" to "123"
set OFF_JNL=%OFF_JNL:~1,-1%

call :REPORT Offline journal number is %OFF_JNL%.

sc queryex %SDP_INSTANCE_P4SERVICE_NAME% | find /I "PID" > pid.txt
for /F "tokens=1,2 delims=: " %%i in (pid.txt) DO (set P4SPID=%%j)

call :EXECUTE svcinst stop -n %SDP_INSTANCE_P4SERVICE_NAME%

REM Wait for service to stop.
:RETRY
Call :REPORT Waiting for service %SDP_INSTANCE_P4SERVICE_NAME% to stop...
timeout /t 60
sc query %SDP_INSTANCE_P4SERVICE_NAME% | find /I "stopped"
if not %ERRORLEVEL% == 0 goto RETRY

call :REPORT_TIME

Call :REPORT Start %SDP_INSTANCE_P4SERVICE_NAME% %SCRIPT_TASK%

Call :REPORT Cutting off current journal
call :EXECUTE %SDP_INSTANCE_BIN_DIR%\p4d -r %P4ROOT% -jj %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%
if NOT ERRORLEVEL 0 goto ERROR

call :REPORT_TIME

call :REPORT Copy in the new binaries
call :EXECUTE copy %SCRIPTS_DIR%\p4.exe %SDP_INSTANCE_BIN_DIR%
if NOT ERRORLEVEL 0 goto ERROR
call :EXECUTE copy %SCRIPTS_DIR%\p4d.exe %SDP_INSTANCE_BIN_DIR%
if NOT ERRORLEVEL 0 goto ERROR
call :EXECUTE copy %SCRIPTS_DIR%\p4d.exe %SDP_INSTANCE_BIN_DIR%\p4s.exe
if NOT ERRORLEVEL 0 goto ERROR

Call :REPORT  Applying all oustanding journal files to offline_db

for /L %%J in (%OFF_JNL%,1,%JNL%) do (
    call :EXECUTE %SDP_INSTANCE_BIN_DIR%\p4d -r %OFFLINE_DB_DIR% -jr %CHECKPOINTS_DIR%\%SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%J
    if NOT ERRORLEVEL 0 goto ERROR
    call :REPORT_TIME
)

Call :REPORT Moving offline_db files to live root
if not exist %P4ROOT%\save mkdir %P4ROOT%\save

call :EXECUTE del /f /q %P4ROOT%\save\db.*
if NOT ERRORLEVEL 0 goto ERROR

call :EXECUTE move /y %P4ROOT%\db.* %P4ROOT%\save
if NOT ERRORLEVEL 0 goto ERROR

call :EXECUTE move /y %OFFLINE_DB_DIR%\db.* %P4ROOT%
if NOT ERRORLEVEL 0 goto ERROR

CALL :report Restart Live Service
call :EXECUTE net start %SDP_INSTANCE_P4SERVICE_NAME%
if NOT ERRORLEVEL 0 goto ERROR

call :REPORT Server should now be started - please test it!

Call :REPORT Recreating offline_db again.
call :EXECUTE %SCRIPTS_DIR%\p4d.exe -r %OFFLINE_DB_DIR% -z -jr %LATEST_CHECKPOINT%
if NOT ERRORLEVEL 0 goto ERROR

call :REPORT_TIME
call :REPORT %SCRIPT_TASK% successfully completed! You can also check %LOG%.

goto END

::------------------------------------------------
:CHECK_EXISTS
:: Check specified file exists    
IF exist %1 goto :EOF
call :ERROR_REPORT New version of executable %1 must exist before running %SCRIPT_TASK%
exit /b 1

::------------------------------------------------
:REPORT
:: Report string and save to log    
echo .
echo %*
echo . >> %LOG%
echo %* >> %LOG%
goto :EOF

::------------------------------------------------
:ERROR_REPORT
:: Report error and crash
call :REPORT ERROR!!!!!!
call :REPORT %*
call :REPORT ERROR!!!!!!
goto :ERROR

::------------------------------------------------
:EXECUTE
:: Execute specified command after logging it
call :REPORT %*
%* >> %LOG% 2>&1
goto :EOF

::------------------------------------------------
:REPORT_TIME
:: Output accurate date/time - and log it
:: Use embedded for loop to turn unicode into ascii
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do @for /f "delims=" %%B in ("%%j") do set ldt=%%B if '.%%i.'=='.LocalDateTime.'
set ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2% %ldt:~8,2%:%ldt:~10,2%:%ldt:~12,6%
call :REPORT %ldt%
goto :EOF

::------------------------------------------------
:ERROR
echo An ERROR occured in %SCRIPT_TASK% process, please check %LOG% for the errors.
exit /b 1

:END
