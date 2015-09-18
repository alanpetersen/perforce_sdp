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

set CkpNum=%1
set JnlNum=%2
set KeepCkpsNum=%3
set KeepLogsNum=%4
set ORIG_DIR=%CD%

if %KeepLogsNum%x == x (
   echo Usage Error: remove_old_logs.bat CkpNum JnlNum KeepCkps KeepLogs
   exit /b 1
)

set /A OldJnlNum="JnlNum - KeepLogsNum"
set /A OldCkpNum="CkpNum - KeepCkpsNum"

if %CkpNum%x == x (
   echo Warning: CkpNum not defined.  No old logs deleted.
   exit /b 1
)

if %JnlNum%x == x (
   echo Warning: JnlNum not defined.  No old logs deleted.
   exit /b 1
)

if %KeepCkpsNum%x == x (
   echo Warning: KeepCkpsNum not defined.  No old logs deleted.
   exit /b 1
)

if %KeepLogsNum%x == x (
   echo Warning: KeepLogsNum not defined.  No old logs deleted.
   exit /b 1
)

if %LOGS_DIR%x == x (
   echo Warning: LOGS not defined.  No old logs deleted.
   exit /b 1
)

if %OldJnlNum%x == x (
   echo Warning: OldJnlNum could not be calculated.  No old logs deleted.
   exit /b 1
)

if %OldCkpNum%x == x (
   echo Warning: OldCkpNum could not be calculated.  No old logs deleted.
   exit /b 1
)

:ROTATE_ACTIVE_SERVER_LOG

cd /D "%LOGS_DIR%"

IF EXIST %P4LOG% (
   call :REPORT Rotating active server %P4LOG% to %P4LOG%.%JnlNum%.
   call :EXECUTE move %P4LOG% %P4LOG%.%JnlNum%
) ELSE (
   call :REPORT Warning:  Server log file '%P4LOG%' not found.
)

:CLEAN_SERVER_LOGS

if %KeepLogsNum% == 0 (
   call :REPORT Skipping cleanup of old server logs because KEEPLOGS is set to 0.
   goto CLEAN_CHECKPOINT_LOGS
)

call :REPORT Removing old server logs.
call :REPORT Keeping latest %KeepLogsNum%, per KEEPLOGS setting in sdp_config.ini.
if exist %P4LOG%.%JnlNum% (
   call :REPORT Latest server log number is %P4LOG%.%JnlNum%.
)

if %OldJnlNum% LSS 8 (
   call :REPORT No old server logs need to be deleted.
   goto CLEAN_CHECKPOINT_LOGS
) ELSE (
   call :REPORT Deleting existing server logs numbered 8-%OldJnlNum%.  Delete 1-7 manually.
)

for /L %%C in (%OldJnlNum%, -1, 8) do (
   if exist %P4LOG%.%%C (
      call :EXECUTE DEL /F /Q %P4LOG%.%%C
   )
)

:CLEAN_CHECKPOINT_LOGS

if %KeepCkpsNum% == 0 (
   call :REPORT Skipping cleanup of old checkpoint logs because KEEPCKPS is set to 0.
   goto END
)

call :REPORT Removing old checkpoint logs.
call :REPORT Keeping latest %KeepCkpsNum%, per KEEPCKPS setting in sdp_config.ini.

if %OldCkpNum% LSS 8 (
   call :REPORT No old checkpoint logs need to be deleted.
   goto END
) ELSE (
   call :REPORT Deleting existing checkpoint logs numbered 8-%OldCkpNum%.  Delete 1-7 manually.
)

for /L %%D in (%OldCkpNum%, -1, 8) do (
   if exist checkpoint.log.%%D (
      call :EXECUTE DEL /F /Q checkpoint.log.%%D 
   )
)

goto :END

::------------------------------------------------
:REPORT
:: Report string and save to log (if appropriate)
echo .
echo %*
goto :EOF

::------------------------------------------------
:EXECUTE
:: Execute specified command after logging it
call :REPORT %*
%*
goto :EOF

:END

echo Log cleanup processing complete.
echo .

cd /d "%ORIG_DIR%"

exit /b 0
