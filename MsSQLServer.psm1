############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of MsSQL Server utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################
function Get-MsSQLServerDependency{
    # MsSQL Server
    if (!(Test-Path 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL')) { Write-Error "Error: Missing Prerequisites. The MsSQL Server Prerequisit is missing." -ErrorAction Stop }
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


function Install-MsSQLServerExpress {
    if(!(Test-Path 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL'))
    {
        Write-Host "Installing: MsSQL Express..."
        choco install sql-server-express -o -ia "'/IACCEPTSQLSERVERLICENSETERMS /Q /ACTION=install /INSTANCEID=MSSQLSERVER /INSTANCENAME=MSSQLSERVER /SECURITYMODE=SQL /SAPWD=EdfiUs3r /TCPENABLED=1 /UPDATEENABLED=FALSE'" -f -y
        #Refres env and reload path in the Shell
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        refreshenv
    }else{Write-Host "Skipping: MsSQL Express as it is already installed."}
}
function Install-MsSSMS {
    if(!(Test-Path 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL'))
    {
        Write-Host "Installing: SSMS - Sql Server Management Studio..."
        choco install sql-server-management-studio -y
    }else{Write-Host "Skipping: SSMS - Sql Server Management Studio as it is already installed."}
}

Function Add-SQLUser($serverInstance, $User, $Role) {
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server "."
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

Function Restore-Database($db, $dbDestinationName, $backupLocation, $dataFileDestination, $logFileDestination) {
    $originDbName = $db.src;
    $newDbName = $dbDestinationName;

	$dataFileOrigin = $originDbName
	$logFileOrigin  = $originDbName+"_log"
	$dataFileLocation = "$dataFileDestination\$newDbName.mdf"
	$logFileLocation  = "$logFileDestination\$newDbName"+"_log.ldf"
	  
	Write-Host "     Restoring database $newDbName"
	  
	#Some special cases...
	if($newDbName -like '*Populated_Template*' )
	{
	    $dataFileOrigin = "EdFi_Ods_Populated_Template"
	    $logFileOrigin = "EdFi_Ods_Populated_Template_log"
	}
	  
	#Some special cases...
	if($newDbName -like '*minimal*')
	{
	    $dataFileOrigin = "EdFi_Ods_Minimal_Template"
	    $logFileOrigin = "EdFi_Ods_Minimal_Template_log"
	}
	  
	$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("$dataFileOrigin", "$dataFileLocation")
    $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("$logFileOrigin", "$logFileLocation")
    Write-Host "***Debugging***"
    Write-Host "Data Relocation:" 
    Write-Host "        origin: $dataFileOrigin"
    Write-Host "        destin: $dataFileLocation" 
    Write-Host "Log Relocation:" 
    Write-Host "        origin: $logFileOrigin"
    Write-Host "        destin: $logFileLocation" 
    Write-Host "    Running Command:> Restore-SqlDatabase -ServerInstance '.' -Database $newDbName -BackupFile $backupLocation$originDbName.bak -RelocateFile @($RelocateData,$RelocateLog) -ReplaceDatabase"
	Restore-SqlDatabase -ServerInstance "." -Database "$newDbName" -BackupFile "$backupLocation$originDbName.bak" -RelocateFile @($RelocateData,$RelocateLog) -ReplaceDatabase
}

function Remove-SqlDatabase($databaseName) {    
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server(".")
    $db = $server.databases[$databaseName]
    if ($db) {
      $server.KillAllprocesses($databaseName)
      $db.Drop()
    }
  }

Function Get-DestDbName($dbmetadata, $prefix, $sufix) {
    
    $dbname = if($dbmetadata.dest){ $dbmetadata.dest }else{ $dbmetadata.src }

    if($prefix -And $sufix){"$prefix$dbname$sufix"; return}
    if($prefix){"$prefix$dbname"; return}
    if($sufix){"$dbname$sufix"; return}

    $dbname         
}