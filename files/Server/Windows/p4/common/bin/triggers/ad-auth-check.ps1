#REQUIRES -Version 2.0

<#
 This is an auth-check trigger for Perforce.
 See detailed comments below for function Is-ADLoginValid
#>
param (
    [string]$user
)

<#
The following module needs to be installed on the Perforce server machine
(where this script will be run by the Perforce server).
Download (if necessary), install it and switch on the module.
To install, see downloads and instructions:
  http://blogs.msdn.com/b/rkramesh/archive/2012/01/17/how-to-add-active-directory-module-in-powershell-in-windows-7.aspx
Then use Control Panel > Programs and Features > Windows Features
  Enable the following entry:
      Remote Server Administration Tools >
        Role Administration Tools >
          AD DS and AD LDS Tools >
            Active Directory Module for Windows PowerShell
#>
Import-Module ActiveDirectory

<#  
.SYNOPSIS  
    Validates supplied user and password against the current ActiveDirectory server        
.DESCRIPTION  
    This is intended to be run as a standard Perforce auth-check trigger.
    
    It expects the password to be provided on STDIN (Standard input).
    The username is specified.
    
    A typical p4 triggers entry to enable this is:
    
        ad-auth-check auth-check auth "powershell -ExecutionPolicy bypass -File c:\triggers\ad-auth-check.ps1 -user %user%"
        
    You may need to provide the full pathname to powershell.
    DON'T FORGET TO RESTART Perforce Service AFTER ADDING NEW TRIGGER!!!
    
    Requirements:
        - ActiveDirectory module noted above
        - The account under which the Perforce Server Service is running should be
          in ActiveDirectory (so that default AD server is set).
.NOTES  
    File Name      : ad-auth-check.ps1  
    Author         : Robert Cowham (rcowham@perforce.com)
    Prerequisite   : PowerShell V2 over Vista and upper.
    Copyright 2014 - Perforce Software, Inc.  See LICENSE.txt for legal information.
.LINK  
    Script posted:  
        TBC
#>
Function Is-ADLoginValid {
    param (
        [String]$user
    )
    [String]$password=$input

    # The following command uses the currently configured ActiveDirectory server
    $aduser = Get-ADUser $user -Properties UserPrincipalName
    Write-Host "Logging in user: "$aduser.UserPrincipalName -NoNewline
    if ((new-object directoryservices.directoryentry "", $aduser.UserPrincipalName, $password).psbase.name -ne $null) {
        exit 0
    } else {
        exit 1
    }
}

# Pipe the standard input for the script into the function directly.
$input | Is-ADLoginValid -user $user
