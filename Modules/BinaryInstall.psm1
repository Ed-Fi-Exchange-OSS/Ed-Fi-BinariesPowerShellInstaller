# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Downloads Ed-Fi binaries from the published MyGet feed and installs them.
#              After install it does appropriate configuration to have applications running.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.
# Know issues and future todo's:
#   1) What about DSC? Should we contemplate Desired State Configuration?
#   2) TODO: As of now you can not provide a MsSQL connection string and only does local "."
 
############################################################

Import-Module "$PSScriptRoot\IO" -Force
Import-Module "$PSScriptRoot\SSL" -Force
Import-Module "$PSScriptRoot\MsSQLServer" -Force
Import-Module "$PSScriptRoot\IIS" -Force 
Import-Module "$PSScriptRoot\Chocolatey" -Force
Import-Module "$PSScriptRoot\Logging" -Force

# Helper functions
Function RunBaseEdFiInstall($environment, $edfiVersion) {

    # Initial Parameters and Variables used as Settings
    #$edfiVersion = "3.3.0" # major versions supported: 3.3.0  TODO: 3.2.0
    #$environment = "Production" # values are: Sandbox, Production
    $versionWithNoPeriods = 'v'+$edfiVersion.Replace(".", "")
    $installPathForBinaries = "C:\inetpub\wwwroot\v$edfiVersion$environment" # The final path where the binaries will be installed.

    #IIS Settings
    $parentSiteName = "Default Web Site"
    $applicationPool = "DefaultAppPool"
    $virtualDirectoryName = "v$edfiVersion$environment"
    $appsBaseUrl = "https://localhost/$virtualDirectoryName"
    $apiBaseUrl = "$appsBaseUrl/api"

    #MsSQL Db Settings
    $sqlServerInstance = "."
    $backupLocation = "$installPathForBinaries\dbs\"
    $dbNamePrefix = "v$edfiVersion" + "_" + "$environment" + "_" #For example: prefix would be v3.3.0_Production_  so the dbs will be v3.3.0_Production_EdFi_ODS
    $dbNameSufix = ""
    $integratedSecurityUser = "IIS APPPOOL\DefaultAppPool"
    $integratedSecurityRole = 'sysadmin'
    # SQL Server Path Variables (You can override with your desired path)
    $dataFileDestination = Get-MsSQLDataFileDestination
    $logFileDestination  = Get-MsSQLLogFileDestination

    # Binaries Metadata
    $binaries = @(  
                    @{  name = "Api"; type = "WebApp";
                        requiredInEnvironments = @("Production","Staging","Sandbox")
                        url = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.WebApi.EFA/$edfiVersion";
                        iisAuthentication = @{ "anonymousAuthentication" = $true 
                                                "windowsAuthentication" = $false
                                             }
                        envAppSettings = @{
                            v260 = @{ 
                                       Production = @{ "owin:appStartup" = 'SharedInstance'; };
                                       Sandbox    = @{ "owin:appStartup" = 'ConfigSpecificSandbox' };
                                    }
                            v320 = @{  
                                        Production = @{ "apiStartup:type" = 'SharedInstance' };
                                        Sandbox    = @{ "apiStartup:type" = 'Sandbox' };
                                    }
                            v330 = @{  
                                        Production = @{ "apiStartup:type" = 'SharedInstance' };
                                        Sandbox    = @{ "apiStartup:type" = 'Sandbox' };
                                    }
                            v340 = @{  
                                        Production = @{ "apiStartup:type" = 'SharedInstance' };
                                        Sandbox    = @{ "apiStartup:type" = 'Sandbox' };
                                    }
                        }
                        databases = @(  #all environments
                                        @{src="EdFi_Admin";dest=""}
                                        @{src="EdFi_Security";dest=""}
                                        # Environment Specific
                                        @{src="EdFi_Ods_Minimal_Template";dest="EdFi_Ods";environment="Production"}
                                        @{src="EdFi_Ods_Minimal_Template";dest="";environment="Sandbox"}
                                        @{src="EdFi_Ods_Populated_Template";dest="";environment="Sandbox"}
                                    )
                        envConnectionStrings = @{
                            Production = @{
                                            "EdFi_Ods"               = "Server=.; Database=$dbNamePrefix"+"EdFi_ODS; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Admin"             = "Server=.; Database=$dbNamePrefix"+"EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Security"          = "Server=.; Database=$dbNamePrefix"+"EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_master"            = "Server=.; Database=master; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "BulkOperationDbContext" = "Server=.; Database=$dbNamePrefix"+"EdFi_Bulk; Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
                                          }
                            Sandbox = @{
                                            "EdFi_Ods"               = "Server=.; Database=$dbNamePrefix"+"EdFi_{0}; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Admin"             = "Server=.; Database=$dbNamePrefix"+"EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Security"          = "Server=.; Database=$dbNamePrefix"+"EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_master"            = "Server=.; Database=master; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "BulkOperationDbContext" = "Server=.; Database=$dbNamePrefix"+"EdFi_Bulk; Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
                                        };
                        }
                        logFile = @{ "file" = '${ProgramData}\Ed-Fi-ODS-API\Log-'+"$dbNamePrefix"+".txt" };
                    }
                    @{  name="Dbs"; type="Databases"; 
                        requiredInEnvironments = @("Production","Staging","Sandbox")
                        url="http://www.toolwise.net/EdFi v$edfiVersion databases with Sample Ext.zip"; }
                    @{  name="SandboxAdmin"; type="WebApp";
                        description = "This is the SandboxAdmin tool.";
                        requiredInEnvironments = @("Sandbox")
                        environment = "Sandbox";
                        url="https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.Admin.Web.EFA/$edfiVersion"
                        urlVersionOverride = @{
                            #v340 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.Admin.Web.EFA/3.3.0"
                            v340 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.SandboxAdmin.Web.EFA/3.4.0"
                        }
                        iisAuthentication = @{ "anonymousAuthentication" = $true 
                                                "windowsAuthentication" = $false
                                            }
                        connectionStrings = @{
                                            "EdFi_Ods"                   = "Server=.; Database=$dbNamePrefix"+"EdFi_{0};      Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Admin"                 = "Server=.; Database=$dbNamePrefix"+"EdFi_Admin;    Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_Security"              = "Server=.; Database=$dbNamePrefix"+"EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                                            "EdFi_master"                = "Server=.; Database=master;        Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                                            "UniqueIdIntegrationContext" = "Server=.; Database=$dbNamePrefix"+"UniqueId;     Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
                                            };
                        appSettings = @{ "apiStartup:type" = 'Sandbox' };
                        webConfigTagInsert = @{"//initialization" = '<users><add name="Test Admin" email="test@ed-fi.org" password="***REMOVED***" admin="true" /></users>'};
                        webConfigTagPostInstall = @{"//initialization" = ''};
                        webConfigAttributePostInstall = New-Object PSObject -Property @{ xPath="//initialization";attribute="enabled";value="False"}
                        logFile = @{ "file" = '${ProgramData}\Ed-Fi-ODS-Admin\Log-'+"$dbNamePrefix"+".txt" };
                    }
                    @{  name="Docs"; type="WebApp";
                        description="This is the Swagger Api Docs web site.";
                        requiredInEnvironments = @("Production","Staging","Sandbox")
                        url="https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.SwaggerUI.EFA/$edfiVersion";
                        urlVersionOverride = @{
                            #v340 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.SwaggerUI.EFA/3.3.0"
                             v340 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.SwaggerUI.EFA/3.4.0"
                        }
                        iisAuthentication = @{ "anonymousAuthentication" = $true 
                                                "windowsAuthentication" = $false
                                            }
                        envAppSettings = @{
                            v260 = @{ "swagger.webApiMetadataUrl" = "$apiBaseUrl/metadata/{section}/api-docs" }
                            v320 = @{
                                "swagger.webApiMetadataUrl" = "$apiBaseUrl/metadata/"
                                "swagger.webApiVersionUrl"  = "$apiBaseUrl" };
                            v330 = @{
                                "swagger.webApiMetadataUrl" = "$apiBaseUrl/metadata/"
                                "swagger.webApiVersionUrl"  = "$apiBaseUrl" };
                            v340 = @{
                                "swagger.webApiMetadataUrl" = "$apiBaseUrl/metadata/"
                                "swagger.webApiVersionUrl"  = "$apiBaseUrl" };
                        };
                    }
                    @{ name="AdminApp";
                        description="This is the Production\SahredInstance AdminApp. Not to be confucesd with the SandboxAdmin.";
                        type="WebApp";
                        requiredInEnvironments = @("Production","Staging")
                        url="https://www.myget.org/F/ed-fi/api/v2/package/EdFi.ODS.AdminApp.Web/$edfiVersion";
                        urlVersionOverride = @{
                            v340 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.ODS.AdminApp.Web/3.3.0"
                            v320 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.ODS.AdminApp.Web/3.2.0.1"
                            v250 = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.ODS.AdminApp.Web/2.5.1"
                        }
                        iisAuthentication = @{ 
                                                "anonymousAuthentication" = $false
                                                "windowsAuthentication" = $true
                                            }
                        appSettings = @{
                                        "ProductionApiUrl" = "$appsBaseUrl/api"
                                        "SwaggerUrl" = "$appsBaseUrl/docs"
                                    };
                        connectionStrings = @{
                                                "EdFi_Ods_Production" = "Server=.; Database=$dbNamePrefix"+"EdFi_Ods; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
                                                "EdFi_Admin"          = "Server=.; Database=$dbNamePrefix"+"EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
                                                "EdFi_Security"       = "Server=.; Database=$dbNamePrefix"+"EdFi_Security; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
                                            };
                        logFile = @{ "file" = '${ProgramData}\Ed-Fi-ODS-AdminApp\Log-'+"$dbNamePrefix"+".txt" };
                        secretJsonv260 = @{"AdminCredentials.UseIntegratedSecurity"=$true};
                    }
                )

    #Starting Install
    Write-HostInfo "Installing Ed-Fi v$edfiVersion ($environment) from Ed-Fi MyGet feed binaries."
    # 0) Ensure all Prerequisites are installed.
    Write-HostStep "Step: Ensuring all Prerequisites are installed."
    Install-EdFiPrerequisites

    #1) Ensure temp path is accessible and exists if not create it.
    Write-HostStep "Step: Ensuring temp path is accessible. ($global:tempPathForBinaries)"
    New-Item -ItemType Directory -Force -Path $global:tempPathForBinaries

    #2) Download necesarry binaries and unzip them to its final install location.
    Write-HostStep "Step: Downloading and Unziping all binaries."
    foreach ($b in $binaries | Where-Object {($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments)}) {
        #build path for binay. Note: all NuGet packages are zips.
        $destPath = "$global:tempPathForBinaries\" + $b.name + "$edfiVersion.zip"

        # Optimization (Caching Packages): Check to see if file exists. If it does NOT then download.
        # TODO: Maybe add a force parameter here if(... -and !Force)
        if(!(Test-Path $destPath -PathType Leaf)){
            # TODO: Remove once Ed-Fi versions align. For example: right now api 3.3.0 has admin app 3.3.0. but 3.2.0 has 3.2.0.1
            #Invoke-DownloadFile $b.url $destPath
            $downloadUrl = $b.url
            if($b.urlVersionOverride -and $b.urlVersionOverride[$versionWithNoPeriods]){ $downloadUrl = $b.urlVersionOverride[$versionWithNoPeriods] }

            Write-Host "     Downloading " $downloadUrl " to -> " $destPath
            Invoke-DownloadFile $downloadUrl $destPath
        }

        #2.1) Once downloaded unzip to install path.
        $installPath = "$installPathForBinaries\"+$b.name
        Write-Host "     Installing '"$b.name"' to -> $installPath"
        Expand-Archive -LiteralPath $destPath -DestinationPath $installPath -Force
    }

    #2.1) Set folder permissions to the installPathForBinaries so that the IIS_IUSRS can (Read & Execute)
    #     Additionally for the AdminApp setup it is necessary to have the IIS_IUSRS (write) permission.
    Write-HostStep "Step: Setting file system permissions"
    Write-Host "     Setting permissions on: $installPathForBinaries"
    Set-PermissionsOnPath $installPathForBinaries "IIS_IUSRS" "ReadAndExecute"
    if($environment -eq "Production"){ Set-PermissionsOnPath "$installPathForBinaries\AdminApp" "IIS_IUSRS" "Write" }

    #3) Configuring IIS
    Write-HostStep "Step: Configuring IIS"
    Write-Host "     Installing self signed SSL certificate on IIS\localhost"
    Install-SSLCertOnIIS
    #3.1) Insatlling Virtual Directory
    Write-Host "     IIS Creating Virtual Directory. ($parentSiteName\$virtualDirectoryName)" 
    New-WebVirtualDirectory -Site $parentSiteName -Name $virtualDirectoryName -PhysicalPath $installPathForBinaries -Force

    #3.2) Insatlling Web Sites
    # Only look for WebApps within the environment or non-environment specific and create WebApplications
    Write-HostStep "Step: IIS Creating WebApplications and Configuring Authetication Settings"
    foreach ($b in $binaries | Where-Object {($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments))}) {
        $appName = $b.name
        $appPhysicalPath = "$installPathForBinaries\"+$b.name
        $applicationIISPath = "$parentSiteName/$virtualDirectoryName/$appName"

        # Create Web Application
        New-WebApplication -Name $appName  -Site "$parentSiteName\$virtualDirectoryName" -PhysicalPath $appPhysicalPath -ApplicationPool $applicationPool -Force

        # Set IIS Authentication settings
        if($b.iisAuthentication) {
            foreach($key in $b.iisAuthentication.Keys)
            {
                Write-Host "     $key  = " $b.iisAuthentication.Item($key)
                Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/$key" -Name Enabled -Value $b.iisAuthentication.Item($key) -PSPath IIS:\ -Location "$applicationIISPath"
            }
        }
    }

    #4) Update Web.config values AppSettings, ConnStrings and Log Files
    Write-HostStep "Step: IIS Configuring Web.Config appSettings, connectionStrings, logfiles & secret.json properties"
    foreach ($b in $binaries | Where-Object {($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments))}) {
        $appPhysicalPath = "$installPathForBinaries\"+$b.name+"\Web.Config"

        Write-Host "     Updating " $b.name " web.config..." -ForegroundColor Cyan
        Write-Host "      File @: " $appPhysicalPath

        # Apply global settings
        if($b.appSettings)       { Set-AppSettingsInWebConfig $appPhysicalPath $b.appSettings }
        if($b.connectionStrings) { Set-ConnectionStringsInWebConfig $appPhysicalPath $b.connectionStrings}
        if($b.logFile)           { Set-Log4NetLogFileInWebConfig $appPhysicalPath $b.logFile}
        if($b.webConfigTagInsert){ Set-TagInWebConfig $appPhysicalPath $b.webConfigTagInsert}

        # Environment and Version Specifics
        if($b.envAppSettings) {
            if($b.envAppSettings[$versionWithNoPeriods][$environment]){ 
                Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods][$environment] 
            } else {
                Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods]
            }
        }
        if($b.envConnectionStrings -and $b.envConnectionStrings[$environment]) { Set-ConnectionStringsInWebConfig $appPhysicalPath $b.envConnectionStrings[$environment] }

        # v2.x
        if($versionWithNoPeriods -eq "v260") { 
            if($b.name -eq "AdminApp") {
                $secretJsonPhysicalPath = "$installPathForBinaries\"+$b.name+"\secret.json"
                Write-Host "     Setting secret JSON to use Integrated Security: " $secretJsonPhysicalPath
                Set-IntegratedSecurityInSecretJsonFile($secretJsonPhysicalPath)
            }

            if($b.name -eq "Docs") {
                $swaggerDefaultHtmlPath = "$installPathForBinaries\"+$b.name+"\default.html"
                Write-Host "     Setting Swagger Docs path to work with Virtual Directories" $swaggerDefaultHtmlPath
                Set-DocsHTMLPathsToWorkWithVirtualDirectories($swaggerDefaultHtmlPath)
            }
        }
    }

    #5) Restore needed Databases
    Write-HostStep "Step: MsSQL Restoring databases"
    $apiDatabases = ($binaries | Where-Object {$_.name -eq "Api"}).databases;

    foreach($db in $apiDatabases | Where-Object {($_.environment -eq $environment) -or (!$_.environment)}) {
        $newDbName = Get-DestDbName $db $dbNamePrefix $dbNameSufix
        Restore-Database $db $newDbName $backupLocation $dataFileDestination $logFileDestination
    }

    #6) MsSQL Ensure that the "IIS APPPOOL\DefaultAppPool" user has security login and has Server Roles -> sysadmin.
    Add-SQLUser $sqlServerInstance $integratedSecurityUser $integratedSecurityRole

    if($environment -eq "Sandbox") {
        #Some sites like the Sandbox Admin need to be initiallized and then Web.Config updated.
        Write-HostStep "Step: Post deploy steps."
        if($environment -eq "Sandbox"){ Initialize-Url "$appsBaseUrl/SandboxAdmin" }

        foreach ($b in $binaries | Where-Object {($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments))}) 
        {
            $appPhysicalPath = "$installPathForBinaries\"+$b.name+"\Web.Config"

            if($b.webConfigTagPostInstall){ 
                Write-Host "     Updating " $b.name " web.config..." -ForegroundColor Cyan
                Write-Host "      File @: " $appPhysicalPath
                Set-TagInWebConfig $appPhysicalPath $b.webConfigTagPostInstall
            }

            if($b.webConfigAttributePostInstall){
                Set-AttributeValueInWebConfig $appPhysicalPath $b.webConfigAttributePostInstall.xPath $b.webConfigAttributePostInstall.attribute $b.webConfigAttributePostInstall.value
            }
        }
    }
}

Function Install-EdFiPrerequisites() {
    $allPreReqsInstalled = $true
    
    Write-Host "Ensurering all Prerequisites are installed:"

    # Ensure the following are installed.
    Install-Chocolatey
    
    # If SQL Server Already installed ensure correct version is installed.
    Find-MsSQLServerDependency "."

    # Lets install the ones that need a reboot/powershell restart
    Install-MsSQLServerExpress
    Install-NetFramework48
    
    Install-IISPrerequisites
    Install-IISUrlRewrite
    
    # If not all Pre Reqs installed halt!
    if(!$allPreReqsInstalled){ Write-Error "Error: Missing Prerequisites. Look above for list." -ErrorAction Stop }
}

Function Get-Password($length)
{
    if(!$length) { $length = 30 }
    $r = New-Guid
    return $r.ToString().Replace('-','').Substring(0,$length)
}

# Region: Web.Config Functions

# dictionarry in this case is a Hash with @{"xPath" = "Value"}
# for example: @{"//initialization" = "<users>....</users>"}
Function Set-TagInWebConfig($webConfigPath, $dictionary)
{
    # Load XML File and Content
    $xml = [xml](Get-Content $webConfigPath)

    foreach($key in $dictionary.Keys)
    {
        # Select the xPath Node
        $xmlNode = $xml.SelectSingleNode($key)

        # Update content.
        $xmlNode.SetAttribute('enabled',$true)
        $xmlNode.RemoveAttribute('configSource')
        $xmlNode.InnerXML = $dictionary[$key]
    }

    #Once done save.
    $xml.Save($webConfigPath)
}

Function Set-AttributeValueInWebConfig($webConfigPath, $xPath, $attribute, $value)
{
    $xml = [xml](Get-Content $webConfigPath)

    # Use XPath to find the appropriate node
    if(($node = $xml.SelectSingleNode($xPath)))
    {
        Write-Host "       -> Setting '$xPath' $attribute = $value"
        $node.SetAttribute($attribute,$value)
    }

    $xml.Save($webConfigPath)
}

Function Set-AppSettingsInWebConfig($webConfigPath, $dictionary)
{
    $xml = [xml](Get-Content $webConfigPath)

    foreach($key in $dictionary.Keys)
    {
        # Use XPath to find the appropriate node
        if(($addKey = $xml.SelectSingleNode("//appSettings/add[@key = '$key']")))
        {
            Write-Host "       -> Setting '$key' to value $($dictionary[$key])"
            $addKey.SetAttribute('value',$dictionary[$key])
        }
    }

    $xml.Save($webConfigPath)
}

Function Set-ConnectionStringsInWebConfig($webConfigPath, $connectionStrings)
{
    $xml = [xml](Get-Content $webConfigPath)

    foreach($key in $connectionStrings.Keys)
    {
        # Use XPath to find the appropriate node
        if(($addKey = $xml.SelectSingleNode("//connectionStrings/add[@name = '$key']")))
        {
            Write-Host "       -> Setting '$key' to value $($connectionStrings[$key])"
            $addKey.SetAttribute('connectionString',$connectionStrings[$key])
        }
    }

    $xml.Save($webConfigPath)
}

Function Set-Log4NetLogFileInWebConfig($webConfigPath, $logFile)
{
    $xml = [xml](Get-Content $webConfigPath)

    foreach($key in $logFile.Keys)
    {
        # Use XPath to find the appropriate node
        if(($addKey = $xml.SelectSingleNode("//log4net/appender/file")))
        {
            Write-Host "       -> Setting '$key' to value $($logFile[$key])"
            $addKey.SetAttribute('value',$logFile[$key])
        }
    }

    $xml.Save($webConfigPath)
}

#TODO: Make this function more generic. Function Set-ValuesInJsonFile($jsonFilePath, $dictionary)
Function Set-IntegratedSecurityInSecretJsonFile($jsonFilePath) {
    $a = Get-Content $jsonFilePath -raw | ConvertFrom-Json

    $a.update | % {$a.AdminCredentials.UseIntegratedSecurity = "true"}
    
    $a | ConvertTo-Json -depth 32| set-content $jsonFilePath
}

Function Initialize-Url($url){
        
        $HttpReq = [System.Net.HttpWebRequest]::Create($url)
        $HttpReq.Timeout = 600 * 1000

        write-host "     Warming up URL '$Url' with $($HttpReq.Timeout) millisecond timeout."
        
        try { $HttpReq.GetResponse() }
        catch [System.Net.WebException] {
            #write-host "Error status: $($_.Exception.status)"
            if ($_.Exception.status -eq [System.Net.WebExceptionStatus]::TrustFailure) {
                write-host "SSL validation error"
                write-error $_
            }
            elseif ($ignoreInternalServerErrors) {
                write-host "Caught and ignored an internal server error"
            }
            else {
                write-host "Non-SSL error (possibly an internal server error of some kind?)"
                write-error $_
            }
        }
}

Function Set-PermissionsOnPath($path, $user, $permision){
    $acl = Get-Acl $path
    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user, $permision, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($ar)
    Set-Acl $path $acl
}

Function Set-DocsHTMLPathsToWorkWithVirtualDirectories($swaggerDefaultHtmlPath)
{
    $fileContent = Get-Content $swaggerDefaultHtmlPath
    $fileContent[3]+="<base href='docs/' />"
    $fileContent | Set-Content $swaggerDefaultHtmlPath
}

Function Install-EdFiProductionV34 {

    Start-Logging

    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Production" "3.4.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

    Stop-Logging
    # If no error then lets write a 
    if (!$error) { Write-SuccessInstallFile  }
}

Function Install-EdFiSandboxV34 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Sandbox" "3.4.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiProductionV33 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Production" "3.3.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiSandboxV33 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Sandbox" "3.3.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiProductionV32 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Production" "3.2.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiSandboxV32 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Sandbox" "3.2.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiProductionV26 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Production" "2.6.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

Function Install-EdFiSandboxV26 {
    # Used to measure execution time.
    $start_time = Get-Date
    RunBaseEdFiInstall "Sandbox" "2.6.0"
    #DONE
    Write-Output "Done... Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}