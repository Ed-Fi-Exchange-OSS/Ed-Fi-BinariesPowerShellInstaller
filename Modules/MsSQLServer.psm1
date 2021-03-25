# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################

# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF

# Description: Module contains a collection of MsSQL Server utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################

function Install-SQLServerModule
{
    Write-Host "Ensuring the Powershell SQLModule is available."
    # Check to see if the module has been installed first.
    If(-Not (Get-InstalledModule | Where-Object -Property Name -eq SqlServer)) {
        Install-Module -Name SqlServer -Force
    }

    # Lets make sure we have the module imported.
    If(-Not (Get-Module SqlServer)) {
        Import-Module SqlServer -Force
    }
}

function Get-MsSQLServerDependency {
    # MsSQL Server
    if (!(Find-IfMsSQLServerInstalled ".")) { Write-Error "Error: Missing Prerequisites. The MsSQL Server Prerequisit is missing." -ErrorAction Stop }
}

function Get-MsSQLServerVersion($serverInstance) {
    If(Find-IfMsSQLServerInstalled ".") {
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverInstance
        return $server.Version.Major
    } else {return 0}
}

function Find-MsSQLServerDependency($serverInstance) {
    If(Find-IfMsSQLServerInstalled ".") {
        $ver = Get-MsSQLServerVersion $serverInstance
        If($ver -lt 14){
            Write-BigMessage "Detected SQL Server Version $ver Already Installed" "This Quick Start requires MsSQL Server 2017 or higher."
            Write-Error "Please install apropriate version of SQL Server." -ErrorAction Stop
        }
    } else { Write-Host "No Ms SQL Server Installed." }
}

function Get-MsSQLDataFileDestination {
    $2017Path = "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA"
    $2019Path = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA"
    if(Test-Path $2017Path){ return $2017Path }
    if(Test-Path $2019Path){ return $2019Path }
    #Write-Error "SQL Server Path not Found. Please Install MsSQL Server or review the path $2019Path" -ErrorAction Stop
}

function Get-MsSQLLogFileDestination {
    $2017Path = "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA"
    $2019Path = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA"
    if(Test-Path $2017Path){ return $2017Path }
    if(Test-Path $2019Path){ return $2019Path }
   #Write-Error "SQL Server Path not Found. Please Install MsSQL Server or review the path $2019Path" -ErrorAction Stop
}

function Find-IfMsSQLServerInstalled($serverInstance) {
    If(Test-Path 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL') { return $true }
    try {
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverInstance
        $ver = $server.Version.Major
        Write-Host " MsSQL Server version detected :" $ver
        return ($ver -ne $null)
    }
    Catch {return $false}
    
    return $false
}


function Install-MsSQLServerExpress {
    if(!(Find-IfMsSQLServerInstalled "."))
    {
        Write-Host "Installing: MsSQL Server Express..."
        choco install sql-server-express -o -ia "'/IACCEPTSQLSERVERLICENSETERMS /Q /ACTION=install /INSTANCEID=MSSQLSERVER /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=EdfiUs3r /TCPENABLED=1 /UPDATEENABLED=FALSE'" -f -y
        #Refres env and reload path in the Shell
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        refreshenv

        # Test to see if we need to close PowerShell and reopen.
        # If .Net is already installed then we need to check to see if the MsSQL commands for SMO are avaialble.
        # We do this check because if .net is not installed we will reboot later.
        if((IsNetVersionInstalled 4 8)){
            If(-Not (Find-PowershellCommand Restore-SqlDatabase)) {
                # Will need to restart so lets give the user a message and exit here.
                Write-BigMessage "SQl Server Express Requires a PowerShell Session Restart" "Please close this PowerShell window and open a new one as an Administrator and run install again."
                Write-Error "Please restart this Powershell session/window and try again." -ErrorAction Stop
            }
        }
    } else {
        Write-Host "Skipping: MsSQL Express there is already a SQL Server installed."
    }
}
function Install-MsSSMS {
    if(!(Find-SoftwareInstalled 'SQL Server Management Studio'))
    {
        Write-Host "Installing: SSMS  Sql Server Management Studio..."
        choco install sql-server-management-studio -y
    }else{Write-Host "Skipping: SSMS  Sql Server Management Studio as it is already installed."}
}

function Add-SQLUser($serverInstance, $User, $Role) {
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverInstance
    if ($server.Logins.Contains($User)) { Write-Host "     Skipping: User '$User' already part of the MsSQL Logins" }
    else {
        # Add the WindowsUser
        $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $server, $User
        $SqlUser.LoginType = 'WindowsUser'
        $sqlUser.PasswordPolicyEnforced = $false
        $SqlUser.Create()

        # Add to the role.
        $serverRole = $server.Roles | where {$_.Name -eq $Role}
        $serverRole.AddMember("$User")
    }
}

function Add-SQLUserWithPassword($serverInstance, $DatabaseName, $User, $Pass, $Role) {
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverInstance

    if ($server.Logins.Contains($User)) { Write-Host "     Skipping: User '$User' already part of the MsSQL Logins" }
    else {
        Write-Host "Creating SQL server login $User..."
        # Create the SQL Login
        $login = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $server, $User
        $login.Name = $User
        $login.LoginType = 'SqlLogin'
        $login.PasswordPolicyEnforced = $false
        $login.PasswordExpirationEnabled = $false
        $login.Create($Pass)
    }

    $database = $server.Databases[$DatabaseName]
    if($database.Users.Contains($User)){Write-Host "     Skipping: Adding User '$User' to Db '$DatabaseName' as its already associated." }
    else {
        Write-Host "Adding $User to database $DatabaseName"
        # Add to DB with the role.
        $newUser =  New-Object Microsoft.SqlServer.Management.Smo.User($server.Databases[$DatabaseName], $User)
        $newUser.Login = $User
        $newUser.Create()
        $newUser.AddToRole($Role)
    }
}

function Restore-Database($db, $dbDestinationName, $backupLocation, $dataFileDestination, $logFileDestination) {
    $originDbName = $db.src;
    $newDbName = $dbDestinationName;

	$dataFileOrigin = $originDbName
	$logFileOrigin  = $originDbName+"_log"
	$dataFileLocation = "$dataFileDestination\$newDbName.mdf"
    $logFileLocation  = "$logFileDestination\$newDbName"+"_log.ldf"
    
    $bakFilePath = "$backupLocation$originDbName.bak"

	Write-Host "     Restoring database $newDbName"
    
    $originalLogicalFileNames = Get-LogicalFileNameFromBakFile $bakFilePath

    $dataFileOrigin = $originalLogicalFileNames.logFileLogicalName
	$logFileOrigin = $originalLogicalFileNames.dataFileLogicalName

	$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($dataFileOrigin, $dataFileLocation)
    $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($logFileOrigin, $logFileLocation)

    $DBServer = New-Object Microsoft.SqlServer.Management.Smo.Server '.'
    $DBServer.KillAllProcesses($newDbName)
    if (!($null -eq $DBServer.Databases[$newDbName].UserAccess)){
        $DBServer.Databases[$newDbName].UserAccess = [Microsoft.SqlServer.Management.Smo.DatabaseUserAccess]::Single #set to single user
    }

    # Write-Host "***Debugging***"
    # Write-Host "Data Relocation:"
    # Write-Host "        origin: $dataFileOrigin"
    # Write-Host "        destin: $dataFileLocation"
    # Write-Host "Log Relocation:"
    # Write-Host "        origin: $logFileOrigin"
    # Write-Host "        destin: $logFileLocation"
    # Write-Host "    Running Command:> Restore-SqlDatabase -ServerInstance '.' -Database $newDbName -BackupFile $backupLocation$originDbName.bak -RelocateFile @($RelocateData,$RelocateLog) -ReplaceDatabase"
    $ver = Get-MsSQLServerVersion "."
    Write-Host "     MsSQL Server Version $ver"

    if($ver -eq 14) {
       Restore-SqlDatabase -ServerInstance "." -Database "$newDbName" -BackupFile $bakFilePath -ReplaceDatabase
    }
    else {
        Restore-SqlDatabase -InputObject $DBServer -Database "$newDbName" -BackupFile $bakFilePath -ReplaceDatabase -RelocateFile @($RelocateData,$RelocateLog)
    }
}

function Remove-SqlDatabase($databaseName) {
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server(".")
    $db = $server.databases[$databaseName]
    if ($db) {
      $server.KillAllprocesses($databaseName)
      $db.Drop()
    }
  }

function Get-DestDbName($dbmetadata, $prefix, $sufix) {

    $dbname = if($dbmetadata.dest){ $dbmetadata.dest }else{ $dbmetadata.src }

    if($prefix -And $sufix){"$prefix$dbname$sufix"; return}
    if($prefix){"$prefix$dbname"; return}
    if($sufix){"$dbname$sufix"; return}

    $dbname
}

function Enable-SQLServerTCPIP() {
    $wmi = new-object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer')
    $computerName = (get-item env:\computername).Value
    $uri = "ManagedComputer[@Name='$computerName']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Tcp']"
    $Tcp = $wmi.GetSmoObject($uri)
    $Tcp.IsEnabled = $true
    $Tcp.Alter()
}

function Get-LogicalFileNameFromBakFile($fullPathToBakFile) {
    #$fullPathToBakFile = "C:\Ed-Fi\QuickStarts\PowerBIChronicAbsenteeism\Db\EdFi.Ods.Populated.Template.bak"
    $dt = Invoke-Sqlcmd "restore filelistonly from disk='$fullPathToBakFile'"

    $result = @{
        logFileLogicalName = ""
        dataFileLogicalName = ""
    }

    foreach ($r in $dt)
    {
        if ($r.Type -eq "L") { $result.logFileLogicalName = $r.LogicalName }
        if ($r.Type -eq "D") { $result.dataFileLogicalName = $r.LogicalName }
        # write-host "$($r.Type) $($r.LogicalName)  $($r.PhysicalName)"
    }

    return $result
}

function Invoke-SQLFilesOnDb($folder, $connStr) {    
    $sqlFiles = Get-Childitem -Path $folder

    foreach($file in $sqlFiles)
    {
        Write-Host "    Executing file" $file
        Invoke-Sqlcmd -InputFile "$folder\$file"  -ConnectionString $connStr
    }
}