@ECHO off

if x%1==x (GOTO Usage)

IF %1 == - (
   CD /D %OLDPWD%
   SET OLDPWD=%CD%
   CD
   GOTO Exit
) ELSE (
   SET OLDPWD=%CD%
   CD /D %1
   CD
   GOTO Exit
)

:Usage
ECHO : 
ECHO : Usage Examples:
ECHO :    GO X:\some\dir   # Don't need to do "X:" first.
ECHO :
ECHO : OR
ECHO :
ECHO :    GO -             # Go back to prior dir.
ECHO :

:Exit