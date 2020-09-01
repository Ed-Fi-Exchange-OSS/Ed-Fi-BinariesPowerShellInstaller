Import-Module "$PSScriptRoot\MsSQLServer" -Force
Import-Module "$PSScriptRoot\Chocolatey" -Force 

function Install-JavaRuntimeEnvironment {
    if(!(Test-Path 'HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment'))
    {
        Write-Host "Installing: Java Runtime..."
        choco install javaruntime -y
    }else{Write-Host "Skipping: Java Runtime as it is already installed."}
}

function Install-Chrome {
    if(!(Test-Path 'HKLM:\SOFTWARE\Google\Chrome'))
    {
        Write-Host "Installing: Google Chrome..."
        choco install googlechrome -y
    }else{Write-Host "Skipping: Google Chrome as it is already installed."}
}
function Install-PostgreSQL {
    if(!(Test-Path 'HKLM:\Software\PostgreSQL'))
    {
        Write-Host "Installing: PostgreSQL..."
        choco install postgresql12 --params '/Password:EdfiUs3r' -y
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

function Install-MetabaseDatabases {
	# get the dump file
	$url = "http://toolwise.net/metabase.sql"
    $outputpath = "C:\Ed-Fi\metabase.sql"
    Invoke-WebRequest -Uri $url -OutFile $outputpath
	
	# Create the Metabase db and restore it
	$databaseName = "metabase";
    $env:PGPASSWORD = 'EdfiUs3r';
    psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = 'metabase';";
	psql -U postgres -c "DROP DATABASE IF EXISTS $databaseName";
	psql -U postgres -c "CREATE DATABASE $databaseName WITH ENCODING 'UTF8'";
    pg_restore -U postgres -d $databaseName -1 $outputpath
    
    # Restore the Populated template that has AMT as the prod db.
    $newDbName = "v3.4.0_Production_EdFi_Ods"
    Remove-SqlDatabase $newDbName
    $backupLocation = "C:\inetpub\wwwroot\v3.4.0Production\dbs\"
    $dataFileDestination = Get-MsSQLDataFileDestination
    $logFileDestination = Get-MsSQLLogFileDestination
    $mssqlDb = @{src="EdFi_Ods_Populated_Template";dest="EdFi_Ods";environment="Production"}
    Restore-Database $mssqlDb $newDbName $backupLocation $dataFileDestination $logFileDestination
}

function Get-Metabase {
	# Ensure Directory Exists
	$directoryPath = "C:\Ed-Fi\binaries\metabase"
	New-Item -ItemType Directory -Force -Path $directoryPath
    
    $outputpath = "$directoryPath\metabase.jar"

    if(!(Test-Path $outputpath -PathType Leaf)) {
        Write-Host "Downloading METABASE"
        $url = "https://downloads.metabase.com/v0.36.4/metabase.jar"
        Invoke-WebRequest -Uri $url -OutFile $outputpath
    } else { Write-Host "Skipping METABASE as it is aready downloaded." }
}

function Invoke-Metabase {
    $env:MB_DB_TYPE="postgres"
    $env:MB_DB_DBNAME="metabase"
    $env:MB_DB_PORT="5432"
    $env:MB_DB_USER="postgres"
    $env:MB_DB_PASS="EdfiUs3r"
    $env:MB_DB_HOST="localhost"
    java -jar C:\Ed-Fi\binaries\metabase\metabase.jar
}

function Install-CHRAB {
    # 1) Install Prereqs...
    Install-CHRABPrerequisites

    #2) Download Metabase
    Get-Metabase

    #3) Install Db and Base Dashboard
    Install-MetabaseDatabases

    #4) Run Metabase
    Invoke-Metabase
}