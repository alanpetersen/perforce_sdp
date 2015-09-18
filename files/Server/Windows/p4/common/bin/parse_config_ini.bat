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

:: Parses the ini file
:: The name is hardcoded and expected to be ..\..\config\sdp_config.ini from the location of this .bat file!

@setlocal enableextensions enabledelayedexpansion
@echo off

if not x%~1==x (
    set SDP_INSTANCE=%~1
    goto CheckINI
)
if not x%SDP_INSTANCE%==x (
    goto CheckINI
)

@echo off
echo ERROR: Required SDP_INSTANCE value not defined (either as parameter or in environment).
echo .
exit /b 1

:CheckINI

set current_script_dir=%~p0
set ini_file=%current_script_dir%..\..\config\sdp_config.ini

if exist %ini_file% (
    goto :ParseINI
)

@echo off
echo ERROR: sdp_config.ini file doesn't exist (%ini_file%)
echo .
exit /b 1

:ParseINI

FOR /F "usebackq" %%i IN (`hostname`) DO SET HOSTNAME=%%i

:: Write a batch file to set the env variables - this filename can't be a variable because of endlocal later.
echo @echo off> _temp_set.bat

set area_found=0
set area=[%SDP_INSTANCE%:%hostname%]
set currarea=
for /f "usebackq delims=" %%a in ("!ini_file!") do (
    set ln=%%a
    if "x!ln:~0,1!"=="x[" (
        set currarea=!ln!
    ) else (
        if not "x!ln:~0,1!"=="x#" (
            for /f "tokens=1,2 delims==" %%b in ("!ln!") do (
                set currkey=%%b
                set currval=%%c
                if /i "x!area!"=="x!currarea!" (
                    set area_found=1
                    echo set !currkey!=!currval!>> _temp_set.bat
                )
            )
        )
    )
)
if %area_found% equ 0 (
    Echo Could not find configuration for instance/hostname %area%.
    Echo .
    Exit /b 1
)

endlocal
    
:: This must be done after the endlocal call above.
call _temp_set.bat

:exit
