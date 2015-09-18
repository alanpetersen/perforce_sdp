::-----------------------------------------------------------------------------
:: Copyright (c) Perforce Software, Inc., 2007-2015. All rights reserved
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

:: This calls parse_config_ini.bat to get specific instance values.
:: It provides validates parameters to some extent.
::

@echo off

SET SDP_INSTANCE=
if %1x==x (
    echo ERROR: Required SDP_INSTANCE value not defined.
    echo .
    exit /b 1
)

set SDP_INSTANCE=%1
set current_script_dir=%~p0
call %current_script_dir%parse_config_ini.bat %SDP_INSTANCE%
if %ERRORLEVEL% GTR 0 (
    echo Error parsing config file.
    exit /b 1
)

@setlocal enableextensions enabledelayedexpansion
for %%c in (sdp_global_root) do (
    if "x!%%c!" == "x" (
        echo Missing required environment variable %%c in sdp_config.ini
        exit /b 1
    )
)
endlocal

:: ===================================================
:: DEFAULT Configuration section
:: You shouldn't need to change variables in this section
:: ===================================================

set SDP_INSTANCE_HOME=%SDP_GLOBAL_ROOT%\p4\%SDP_INSTANCE%

set SDP_INSTANCE_BIN_DIR=%SDP_INSTANCE_HOME%\bin
set SDP_INSTANCE_SSL_DIR=%SDP_INSTANCE_HOME%\ssl

:: Perforce environment variables - keep the logical relationships
set P4CONFIG=p4config.txt
set P4ROOT=%SDP_INSTANCE_HOME%\root
set P4LOG=%SDP_INSTANCE_HOME%\logs\%SDP_INSTANCE%.log
set P4JOURNAL=%SDP_INSTANCE_HOME%\logs\journal

set P4USER=%SDP_P4SUPERUSER%
set P4TICKETS=%SDP_INSTANCE_BIN_DIR%\P4Tickets.txt
set P4TRUST=%SDP_INSTANCE_BIN_DIR%\P4Trust.txt
set P4ENVIRO=%SDP_INSTANCE_BIN_DIR%\P4Enviro.txt

set SDP_INSTANCE_P4SERVICE_NAME=P4_%SDP_INSTANCE%

:: Get the P4PORT value for this instance.
for /F %%F in ('%SDP_INSTANCE_BIN_DIR%\p4.exe set -S %SDP_INSTANCE_P4SERVICE_NAME% P4PORT') DO (set %%F)

set SCRIPTS_DIR=%SDP_GLOBAL_ROOT%\p4\common\bin
set LOGS_DIR=%SDP_INSTANCE_HOME%\logs
set OFFLINE_DB_DIR=%SDP_INSTANCE_HOME%\offline_db
set CHECKPOINTS_DIR=%SDP_INSTANCE_HOME%\checkpoints
set REMOTE_CHECKPOINTS_DIR=%REMOTE_DEPOTDATA_ROOT%\p4\%REMOTE_SDP_INSTANCE%\checkpoints

set ADMIN_PASS_FILE=%SCRIPTS_DIR%\%ADMIN_PASS_FILENAME%

PATH=%SDP_INSTANCE_BIN_DIR%;%SCRIPTS_DIR%;%PATH%
