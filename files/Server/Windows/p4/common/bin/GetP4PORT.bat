@ECHO OFF

if x%1==x (GOTO Usage)

:: Note: This script goes to some effort to avoid any side effects.
:: The P4CONFIG and P4PORT values must be cleared, but they are set
:: back to their original values when done.
SET INSTANCE=%1
SET ORIG_P4CONFIG=%P4CONFIG%
SET ORIG_P4PORT=%P4PORT%
SET P4CONFIG=
SET P4PORT=

FOR /F %%F IN ('%SDP_INSTANCE_BIN_DIR%\p4 set -S P4_%INSTANCE% P4PORT') DO (
   ECHO %%F
)

GOTO WrapUp

:Usage
ECHO : Usage:
ECHO :    GetP4PORT.bat Instance
ECHO :
ECHO : Example:
ECHO :    GetP4PORT.bat 1

:WrapUp

IF NOT x%ORIG_P4CONFIG%==x (SET P4CONFIG=%ORIG_P4CONFIG%)
IF NOT x%ORIG_P4PORT%==x (SET P4PORT=%ORIG_P4PORT%)
