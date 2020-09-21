# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of simple logging utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.
# Note: Depends on $global:tempPathForBinaries.

############################################################

Function Start-Logging() {
    # Log everything to help debug
    $ErrorActionPreference="SilentlyContinue"
    Stop-Transcript | out-null
    $ErrorActionPreference = "Continue"
    Set-Location $global:tempPathForBinaries
    $path = $global:tempPathForBinaries + "Log.txt"
    Write-Host "Starting log file @ $path"
    Start-Transcript -path $path -append
}

Function Stop-Logging() {
    # Stop logging
    Stop-Transcript
}