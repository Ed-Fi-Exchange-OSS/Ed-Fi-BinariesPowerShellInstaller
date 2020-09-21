# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of functions to activate the Chronic Absenteeism Metabase Dashboards.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################
Import-Module "$PSScriptRoot\BinaryInstall" -Force
Import-Module "$PSScriptRoot\MsSQLServer" -Force
Import-Module "$PSScriptRoot\Chocolatey" -Force 
Import-Module "$PSScriptRoot\IO" -Force
Import-Module "$PSScriptRoot\Logging" -Force

$universalPassword = "EdfiUs3r"

function Install-JavaRuntimeEnvironment {
    # If Java is not installed then lets install Open JDK
    if(!(Test-Path 'HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment'))
    {
        Write-Host "Installing: Java Runtime..."
        #choco install javaruntime -y
        choco install openjdk11 -y
    }else{Write-Host "Skipping: Java Runtime as it is already installed."}
}

function Install-Chrome {
    if(!(Find-SoftwareInstalled "Google Chrome"))
    {
        Write-Host "Installing: Google Chrome..."
        choco install googlechrome -y --ignore-checksums
    }else{Write-Host "Skipping: Google Chrome as it is already installed."}
}
function Install-PowerBi {
    if(!(Find-SoftwareInstalled "Microsoft Power BI Desktop (x64)"))
    {
        Write-Host "Installing: Power Bi..."
        choco install powerbi -y
    }else{Write-Host "Skipping: Power Bi as it is already installed."}
}

function Get-PowerBiTemplate {

    # Ensure Directory Exists
	$directoryPath = $global:tempPathForBinaries + "powerbi"
	New-Item -ItemType Directory -Force -Path $directoryPath
    
    $outputpath = "$directoryPath\ChronicAbsenteeismDashboard.pbit"
    
    Write-HostStep "Downloading PowerBI Template..."
    $url = "http://toolwise.net/ChronicAbsenteeismDashboard.pbit"
    
    Invoke-DownloadFile $url $outputpath
}

function Open-PowerBiTemplate{
    Write-HostStep "Opening Power Bi Chronic Absenteeism Dashboard"
    $directoryPath = $global:tempPathForBinaries + "powerbi\ChronicAbsenteeismDashboard.pbit"
    Start-Process $directoryPath
}
function Install-PostgreSQL {
    if(!(Test-Path 'HKLM:\Software\PostgreSQL'))
    {
        Write-Host "Installing: PostgreSQL..."
        $params = "/Password:$universalPassword"
        choco install postgresql12 --params $params -y
    }else{Write-Host "Skipping: PostgreSQL as it is already installed."}
}
function Install-PGAdmin {
    # Install PGAdmin
    if(!(Test-Path 'HKLM:\Software\pgAdmin 4\'))
    {
        Write-Host "Installing: pgadmin4..."
        choco install pgadmin4 -y
    }else{Write-Host "Skipping: pgadmin4 as it is already installed."}
}

function Install-CHRABPrerequisites {
    Install-Chocolatey
    Install-JavaRuntimeEnvironment
    Install-Chrome
    Install-PostgreSQL
    Install-PGAdmin
    Install-MsSQLServerExpress
    Install-MsSSMS
    
    #Refres env and reload path in the Shell
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    refreshenv
}

function Install-ODSWithAMTandSampleData{
    # Ensure SQL Server has TCP enabled
    Enable-SQLServerTCPIP

    Write-HostStep "Restoring sample data"
    # Restore the Populated template that has AMT as the prod db.
    $newDbName = "v3.4.0_Production_EdFi_Ods"
    Remove-SqlDatabase $newDbName
    $backupLocation = "C:\inetpub\wwwroot\v3.4.0Production\dbs\"
    $dataFileDestination = Get-MsSQLDataFileDestination
    $logFileDestination = Get-MsSQLLogFileDestination
    $mssqlDb = @{src="EdFi_Ods_Populated_Template";dest="EdFi_Ods";environment="Production"}
    Restore-Database $mssqlDb $newDbName $backupLocation $dataFileDestination $logFileDestination

    # Ensure we have the readonly user in the Db
    Add-SQLUserWithPassword '.' $newDbName 'edfi-metabase' $universalPassword 'db_datareader'
}

function Install-MetabaseDatabases {
	# get the dump file
	$url = "http://toolwise.net/metabase.sql"
    $outputpath = "C:\Ed-Fi\metabase.sql"
    Invoke-WebRequest -Uri $url -OutFile $outputpath
	
	# Create the Metabase db and restore it
	$databaseName = "metabase";
    $env:PGPASSWORD = $universalPassword;
    psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = 'metabase';";
	psql -U postgres -c "DROP DATABASE IF EXISTS $databaseName";
	psql -U postgres -c "CREATE DATABASE $databaseName WITH ENCODING 'UTF8'";
    pg_restore -U postgres -d $databaseName -1 $outputpath

    # Restore the Populated template that has AMT as the prod db.
    Install-ODSWithAMTandSampleData
}

function Get-Metabase {
	# Ensure Directory Exists
	$directoryPath = $global:tempPathForBinaries + "metabase"
	New-Item -ItemType Directory -Force -Path $directoryPath
    
    $outputpath = "$directoryPath\metabase.jar"

    if(!(Test-Path $outputpath -PathType Leaf)) {
        Write-Host "Downloading METABASE"
        $url = "https://downloads.metabase.com/v0.36.4/metabase.jar"
        
        Invoke-DownloadFile $url $outputpath

    } else { Write-Host "Skipping METABASE as it is aready downloaded." }
}

function Invoke-Metabase {
    $env:MB_DB_TYPE="postgres"
    $env:MB_DB_DBNAME="metabase"
    $env:MB_DB_PORT="5432"
    $env:MB_DB_USER="postgres"
    $env:MB_DB_PASS=$universalPassword
    $env:MB_DB_HOST="localhost"

    $metabasePath = $global:tempPathForBinaries + "metabase\metabase.jar"
    Write-HostStep "Metabse with "
    java -jar $metabasePath
}

# Accessible Endpoints
function Install-CHRAB {

    # Start logging
    Start-Logging

    # 1) Install Prereqs...
    Install-CHRABPrerequisites

    #2) Download Metabase
    Get-Metabase

    #3) Install Db and Base Dashboard
    Install-MetabaseDatabases

    #4) Run Metabase
    Invoke-Metabase

    #Stop logging
    Stop-Logging
}

function Install-CHRABMetabase {
    Install-CHRAB
}

function Open-CHRAB {
    Invoke-Metabase
}

function Open-CHRABMetabase {
    Open-CHRAB
}

function Install-EdFiV34AndCHRAB {
    Install-EdFiProductionV34
    Install-CHRAB
}

function Install-CHRABPowerBi{
    Install-PowerBi
    Get-PowerBiTemplate
    Install-ODSWithAMTandSampleData
    Open-PowerBiTemplate
}

function Open-CHRABPowerBi
{
    Open-PowerBiTemplate
}