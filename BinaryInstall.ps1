############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Downloads Ed-Fi binaries from the published MyGet feed and installs them.
#              After install it does appropriate configuration to have applications running.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.
# Know issues and future todo's: (look at the .PSM1 file)
 
############################################################

#Clear all errors before starting.
$error.clear()

# Base path to download files and store Logs and so.
$global:tempPathForBinaries = "C:\Ed-Fi\BinaryInstaller\"

Import-Module "$PSScriptRoot\Modules\BinaryInstall" -Force #-Verbose #-Force
Import-Module "$PSScriptRoot\Modules\CHRABQuickStart" -Force #-Verbose #-Force

# 1) Ensure the working directory exists
$global:pathToWorkingDir = "C:\Ed-Fi\BinaryInstaller\"
Write-Host "Step: Ensuring working path is accessible. ($global:pathToWorkingDir)"
New-Item -ItemType Directory -Force -Path $pathToWorkingDir

Write-HostInfo "Ed-Fi binary installer functions loaded correctly."
Write-Host "To install Ed-Fi run any of the following commands:" 
Write-HostStep " Ed-Fi ODS\API v3.4.0"
Write-Host "    Install-EdFiProductionV34" 
Write-Host "    Install-EdFiSandboxV34"
Write-HostStep " Ed-Fi ODS\API v3.3.0"
Write-Host "    Install-EdFiProductionV33" 
Write-Host "    Install-EdFiSandboxV33"
Write-HostStep " Ed-Fi ODS\API v3.2.0"
Write-Host "    Install-EdFiProductionV32" 
Write-Host "    Install-EdFiSandboxV32"
Write-HostStep " Ed-Fi ODS\API v2.6.0"
Write-Host "    Install-EdFiProductionV26" 
Write-Host "    Install-EdFiSandboxV26"
Write-Host ""