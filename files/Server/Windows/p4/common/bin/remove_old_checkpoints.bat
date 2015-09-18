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
set KeepCkpNum=%2

if %CkpNum%x == x (
   echo Usage Error: remove_old_checkpoints.bat CkpNum KeepCkpNum
   exit /b 1
)

if %KeepCkpNum%x == x (
   echo Usage Error: remove_old_checkpoints.bat CkpNum KeepCkpNum
   exit /b 1
)

:: I = Highest checkpoint number to remove.
set /A I="CkpNum - KeepCkpNum"

:: J = Highest journal number to remove.
set /A J="I - 1"

if %KeepCkpNum%x == x (
   echo Warning: KeepCkpNum not defined.  No old checkpoints deleted.
   exit /b 1
)

if %KeepCkpNum% == 0 (
   echo Info: KEEPCKPS set to 0.  No old checkpoints deleted.
   exit /b 0
)

if %CHECKPOINTS_DIR%x == x (
   echo Warning: CHECKPOINTS not defined.  No old checkpoints deleted.
   exit /b 1
)

if %SDP_INSTANCE_P4SERVICE_NAME%x == x (
   echo Warning: P4SERVICE not defined.  No old checkpoints deleted.
   exit /b 1
)

if %KeepCkpNum% == 0 (
   echo .
   echo Skipping cleanup of old checkpoint files because KEEPCKPS is set to 0.
   echo .
   exit /b 0
)

echo Removing old checkpoint and journal files.
echo Keeping latest %KeepCkpNum%, per KEEPCKPS setting in sdp_config.ini.
echo Latest checkpoint file is number %CKP%.
echo .

if %I% LSS 8 (
   echo No checkpoint or journal files need to be deleted.
   echo .
   exit /b 0
) ELSE (
   echo Deleting existing checkpoints numbered 8-%I%.  Delete 1-7 manually.
   echo Deleting existing journals numbered 7-%J%.  Delete 1-6 manually.
   echo .
)

set ORIG_DIR=%CD%
cd /D "%CHECKPOINTS_DIR%"

for /L %%C in (%I%, -1, 8) do (
   if exist %SDP_INSTANCE_P4SERVICE_NAME%.ckp.%%C.gz (
      echo DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.ckp.%%C.gz
      DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.ckp.%%C.gz
      DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.ckp.%%C.gz.md5
   )
)

for /L %%D in (%J%, -1, 7) do (
   if exist %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D.gz (
      echo DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D.gz
      DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D.gz
   )
   if exist %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D (
      echo DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D
      DEL /F /Q %SDP_INSTANCE_P4SERVICE_NAME%.jnl.%%D
   )
)

echo Checkpoint and journal file cleanup complete.
echo .

cd /d "%ORIG_DIR%"

exit /b 0
