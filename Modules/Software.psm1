# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of utility functions that help check if software is installed and if powershell commands are available.

############################################################

Function Find-SoftwareInstalled($software)
{
    # To debug use this in your powershell
    # (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName
    return (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Contains $software
}

Function Find-PowershellCommand($command) {
    # Save the current Error Action Preference
    $currentErrorActionPreference=$ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {if(Get-Command $command){return $true}}
    Catch {return $false}
    Finally {$ErrorActionPreference=$currentErrorActionPreference}
}