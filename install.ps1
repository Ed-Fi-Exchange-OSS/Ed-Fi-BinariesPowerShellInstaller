# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Install script that downloads the repo zip en loads mosules.

############################################################

# 1) Ensure the working directory exists
$global:pathToWorkingDir = "C:\Ed-Fi\BinaryInstaller\"
Write-Host "Step: Ensuring working path is accessible. ($global:pathToWorkingDir)"
New-Item -ItemType Directory -Force -Path $pathToWorkingDir


# 2) Download and unzip the github powershell scripts (in zip format)
$packageUrl = "https://github.com/Ed-Fi-Exchange-OSS/Ed-Fi-BinariesPowerShellInstaller/archive/main.zip"
$outputpath = "$global:pathToWorkingDir\main.zip"
Invoke-WebRequest -Uri $packageUrl -OutFile $outputpath
Expand-Archive -LiteralPath $outputpath -DestinationPath $global:pathToWorkingDir -Force

# 3) Execute script
$global:pathToAssets = "$global:pathToWorkingDir\Ed-Fi-BinariesPowerShellInstaller-main\"
$pathToMainScript = "$global:pathToAssets\binaryInstall.ps1"
Invoke-Expression -Command $pathToMainScript