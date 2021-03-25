Import-Module "$PSScriptRoot\IO" -Force
Import-Module "$PSScriptRoot\SSL" -Force
Import-Module "$PSScriptRoot\MsSQLServer" -Force
Import-Module "$PSScriptRoot\IIS" -Force 
Import-Module "$PSScriptRoot\Chocolatey" -Force
Import-Module "$PSScriptRoot\Logging" -Force


Function IsEdfiVersionNetCore ($versionWithNoPeriods) {
    switch ($versionWithNoPeriods) {
        "v510" { return $true }
        Default { return $false }
    }
}
Function Install-EdFiPrerequisites($isCore) {
    $allPreReqsInstalled = $true
    
    Write-Host "Ensurering all Prerequisites are installed:"

    # Ensure the following are installed.
    Install-Chocolatey
    
    # If SQL Server Already installed ensure correct version is installed.
    Install-SQLServerModule
    Find-MsSQLServerDependency "."

    # Lets install the ones that need a reboot/powershell restart
    Install-MsSQLServerExpress

    Install-IISPrerequisites
    Install-IISUrlRewrite

    if ($isCore) {
        Install-NetCore31
    }
    else {
        Install-NetFramework48
    }
    
    # If not all Pre Reqs installed halt!
    if (!$allPreReqsInstalled) { Write-Error "Error: Missing Prerequisites. Look above for list." -ErrorAction Stop }
}



Function Install-EdFiAPIPrerequisitesWithOUTUrlRewrite() {
    $allPreReqsInstalled = $true
    
    Write-Host "Ensurering all Prerequisites are installed:"

    # Ensure the following are installed.
    Install-Chocolatey
    
    Install-NetFramework48
    
    Install-IISPrerequisites
    
    # If not all Pre Reqs installed halt!
    if (!$allPreReqsInstalled) { Write-Error "Error: Missing Prerequisites. Look above for list." -ErrorAction Stop }
}

Function Install-EdFiAPIPrerequisitesWithUrlRewrite() {
    $allPreReqsInstalled = $true
    
    Write-Host "Ensurering all Prerequisites are installed:"

    # Ensure the following are installed.
    Install-Chocolatey
    
    Install-NetFramework48
    
    Install-IISPrerequisites
    Install-IISUrlRewrite
    
    # If not all Pre Reqs installed halt!
    if (!$allPreReqsInstalled) { Write-Error "Error: Missing Prerequisites. Look above for list." -ErrorAction Stop }
}