REM ------------------------------------------------------------------------------
REM Copyright (c) Perforce Software, Inc., 2007-2015. All rights reserved
REM
REM Redistribution and use in source and binary forms, with or without
REM modification, are permitted provided that the following conditions are met:
REM
REM 1  Redistributions of source code must retain the above copyright
REM    notice, this list of conditions and the following disclaimer.
REM
REM 2.  Redistributions in binary form must reproduce the above copyright
REM     notice, this list of conditions and the following disclaimer in the
REM     documentation and/or other materials provided with the distribution.
REM
REM THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
REM "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
REM LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
REM FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE
REM SOFTWARE, INC. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
REM SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
REM LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
REM DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
REM ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
REM TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
REM THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
REM DAMAGE.
REM ------------------------------------------------------------------------------

REM This script is used to send email to all of your Perforce users.
REM Create a file called message.txt that contains the body of your message.
REM Then call this script and pass the subject in quotes as the only parameter.

REM It makes a copy of the previous email list, then call make_email_list.py
REM to generate a new one from Perforce.

REM The reason for making the copy is so that you will always have an email list that
REM you can use to send email with. Just comment out the call to python mmake_email_list.py
REM below, and run the script. It will use the current list to send email from. This is
REM handy in case your server goes off-line.

copy emaillist.txt emaillist.prev
python make_email_list.py
python pymail.py -t emaillist.txt -s %1 -i message.txt

