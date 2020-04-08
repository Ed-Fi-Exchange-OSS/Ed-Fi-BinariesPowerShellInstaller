############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Downloads Ed-Fi binaries from the published MyGet feed and installs them.
#              After install it does appropriate configuration to have applications running.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.
# Know issues and future todo's: (look at the .PSM1 file)
 
############################################################

Import-Module "$PSScriptRoot\BinaryInstall" -Force #-Verbose #-Force

Write-HostStep "Ed-Fi binary installer functions loaded correctly."
Write-Host "To install Ed-Fi run any of the following commands:" 
Write-Host "    Install-EdFiProduction" 
Write-Host "    Install-EdFiSandbox"