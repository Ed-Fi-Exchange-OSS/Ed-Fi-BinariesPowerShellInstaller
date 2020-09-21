# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of IO utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################
Function Write-SuccessInstallFile(){
    $path = $global:tempPathForBinaries + "Ed-Fi-BinInstall.txt"
    $content = 'Ed-Fi Installed Successfully on:'+ (Get-Date)
    Add-Content -Path $path -Value $content
}

Function Write-HostInfo($message) { 
    $divider = "----"
    for($i=0;$i -lt $message.length;$i++){ $divider += "-" }
    Write-Host $divider -ForegroundColor Cyan
    Write-Host " " $message -ForegroundColor Cyan
    Write-Host $divider -ForegroundColor Cyan 
}

Function Write-HostStep($message) { 
    Write-Host "*** " $message " ***"-ForegroundColor Green
}

Function Write-BigMessage($title, $message) {
    $divider = "*** "
    for($i=0;$i -lt $message.length;$i++){ $divider += "*" } 
    Write-Host $divider -ForegroundColor Green
    Write-Host "*"-ForegroundColor Green
    Write-Host "*** " $title " ***"-ForegroundColor Green
    Write-Host "*"-ForegroundColor Green
    Write-Host "* " $message " *"-ForegroundColor Green
    Write-Host "*"-ForegroundColor Green
    Write-Host $divider -ForegroundColor Green
}


Function Invoke-DownloadFile($url, $outputpath) {
    # Turn off the download progress bar as its faster this way.
    #$ProgressPreference = 'SilentlyContinue'
    #Invoke-WebRequest -Uri $url -OutFile $outputpath

    $wc = New-Object net.webclient
    $wc.Downloadfile($url, $outputpath)
}

