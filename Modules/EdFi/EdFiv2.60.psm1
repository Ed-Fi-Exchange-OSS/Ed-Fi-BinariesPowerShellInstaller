Import-Module "$PSScriptRoot\MsSQLServer" -Force
Import-Module "$PSScriptRoot\IIS" -Force 
Import-Module "$PSScriptRoot\Chocolatey" -Force
function RunBaseEdFiInstallv260($environment, $edfiVersion) {

    # Initial Parameters and Variables used as Settings
    #$edfiVersion = "3.3.0" # major versions supported: 3.3.0  TODO: 3.2.0
    #$environment = "Production" # values are: Sandbox, Production
    $iisRootFolder = "C:\inetpub\wwwroot"
    $installPathForBinaries = "$iisRootFolder\v$edfiVersion$environment" # The final path where the binaries will be installed.

    #IIS Settings
    $parentSiteName = "Default Web Site"
    $applicationPool = "DefaultAppPool"
    $virtualDirectoryName = "v$edfiVersion$environment"
    $appsBaseUrl = "https://localhost/$virtualDirectoryName"
    $apiBaseUrl = "$appsBaseUrl/api"

    #MsSQL Db Settings
    $sqlServerInstance = "."
    $dbNamePrefix = "v$edfiVersion" + "_" + "$environment" + "_" #For example: prefix would be v3.3.0_Production_  so the dbs will be v3.3.0_Production_EdFi_ODS
    $dbNameSufix = ""
    $integratedSecurityUser = "IIS APPPOOL\DefaultAppPool"
    $integratedSecurityRole = 'sysadmin'
    
    $packageVerificationHash = @{ 
        Api          = "ED9BF01EC19F85F70F70C7F15AF27CF45CDE5987175204BD748548C2C28E889A";
        AdminApp     = "99DE262DD94CCBE4314FEA866992FE159D09784D6F6DC10AFB958DBE4BA7F840";
        Dbs          = "52C82FBB95EACBADB01150A8E26A2B7E20BFC54DDE043DCEFE9466A881A04E1D";
        Docs         = "981F309AA4E09D8B370C2D24EA10AB82CF88C0D400C3B97A828C6A366734EA08";
        SandboxAdmin = "2EDFDA252E9A81CC7A7C54C35EFC39D72A00AB729E8E3F8206181E2CDA079820";
    }



    # Binaries Metadata
    $binaries = @(  
        @{  name = "Api"; type = "WebApp";
            requiredInEnvironments = @("Production", "Staging", "Sandbox")
            url = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.WebApi.EFA/$edfiVersion";
            iisAuthentication = @{ "anonymousAuthentication" = $true 
                "windowsAuthentication"                      = $false
            }
            envAppSettings = @{
                Production = @{ "owin:appStartup" = 'SharedInstance'; };
                Sandbox    = @{ "owin:appStartup" = 'ConfigSpecificSandbox' };
            }
            databases = @(  #all environments
                @{src = "EdFi_Admin"; dest = "" }
                @{src = "EdFi_Security"; dest = "" }
                # Environment Specific
                @{src = "EdFi_Ods_Minimal_Template"; dest = "EdFi_Ods"; environment = "Production" }
                @{src = "EdFi_Ods_Minimal_Template"; dest = ""; environment = "Sandbox" }
                @{src = "EdFi_Ods_Populated_Template"; dest = ""; environment = "Sandbox" }
            )
            envConnectionStrings = @{
                Production = @{
                    "EdFi_Ods"               = "Server=.; Database=$dbNamePrefix" + "EdFi_ODS; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_Admin"             = "Server=.; Database=$dbNamePrefix" + "EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_Security"          = "Server=.; Database=$dbNamePrefix" + "EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_master"            = "Server=.; Database=master; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "BulkOperationDbContext" = "Server=.; Database=$dbNamePrefix" + "EdFi_Bulk; Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
                }
                Sandbox    = @{
                    "EdFi_Ods"               = "Server=.; Database=$dbNamePrefix" + "EdFi_{0}; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_Admin"             = "Server=.; Database=$dbNamePrefix" + "EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_Security"          = "Server=.; Database=$dbNamePrefix" + "EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                    "EdFi_master"            = "Server=.; Database=master; Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                    "BulkOperationDbContext" = "Server=.; Database=$dbNamePrefix" + "EdFi_Bulk; Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
                };
            }
            logFile = @{ "file" = '${ProgramData}\Ed-Fi-ODS-API\Log-' + "$dbNamePrefix" + ".txt" };
        }
        @{  name = "Dbs"; type = "Databases"; 
            requiredInEnvironments = @("Production", "Staging", "Sandbox")
            url = "http://www.toolwise.net/EdFi v$edfiVersion databases with Sample Ext.zip"; 
        }
        @{  name = "SandboxAdmin"; type = "WebApp";
            description = "This is the SandboxAdmin tool.";
            requiredInEnvironments = @("Sandbox")
            environment = "Sandbox";
            url = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.Admin.Web.EFA/$edfiVersion"
            iisAuthentication = @{ "anonymousAuthentication" = $true 
                "windowsAuthentication"                      = $false
            }
            connectionStrings = @{
                "EdFi_Ods"                   = "Server=.; Database=$dbNamePrefix" + "EdFi_{0};      Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                "EdFi_Admin"                 = "Server=.; Database=$dbNamePrefix" + "EdFi_Admin;    Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                "EdFi_Security"              = "Server=.; Database=$dbNamePrefix" + "EdFi_Security; Trusted_Connection=True; Persist Security Info=True; Application Name=EdFi.Ods.WebApi;"
                "EdFi_master"                = "Server=.; Database=master;        Trusted_Connection=True; Application Name=EdFi.Ods.WebApi;"
                "UniqueIdIntegrationContext" = "Server=.; Database=$dbNamePrefix" + "UniqueId;     Trusted_Connection=True; MultipleActiveResultSets=True; Application Name=EdFi.Ods.WebApi;"
            };
            appSettings = @{ "apiStartup:type" = 'Sandbox' };
            webConfigTagInsert = @{"//initialization" = '<users><add name="Test Admin" email="test@ed-fi.org" password="***REMOVED***" admin="true" /></users>' };
            webConfigTagPostInstall = @{"//initialization" = '' };
            webConfigAttributePostInstall = New-Object PSObject -Property @{ xPath = "//initialization"; attribute = "enabled"; value = "False" }
            logFile = @{ "file" = '${ProgramData}\Ed-Fi-ODS-Admin\Log-' + "$dbNamePrefix" + ".txt" };
        }
        @{  name = "Docs"; type = "WebApp";
            description = "This is the Swagger Api Docs web site.";
            requiredInEnvironments = @("Production", "Staging", "Sandbox")
            url = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.Ods.SwaggerUI.EFA/$edfiVersion";
            iisAuthentication = @{ "anonymousAuthentication" = $true 
                "windowsAuthentication"                      = $false
            }
            envAppSettings = @{
                "swagger.webApiMetadataUrl" = "$apiBaseUrl/metadata/{section}/api-docs" 
            };
        }
        @{ name                    = "AdminApp";
            description            = "This is the Production\SahredInstance AdminApp. Not to be confucesd with the SandboxAdmin.";
            type                   = "WebApp";
            requiredInEnvironments = @("Production", "Staging")
            url                    = "https://www.myget.org/F/ed-fi/api/v2/package/EdFi.ODS.AdminApp.Web/$edfiVersion";
            iisAuthentication      = @{ 
                "anonymousAuthentication" = $false
                "windowsAuthentication"   = $true
            }
            appSettings            = @{
                "ProductionApiUrl" = "$appsBaseUrl/api"
                "SwaggerUrl"       = "$appsBaseUrl/docs"
            };
            connectionStrings      = @{
                "EdFi_Ods_Production" = "Server=.; Database=$dbNamePrefix" + "EdFi_Ods; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
                "EdFi_Admin"          = "Server=.; Database=$dbNamePrefix" + "EdFi_Admin; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
                "EdFi_Security"       = "Server=.; Database=$dbNamePrefix" + "EdFi_Security; Trusted_Connection=True; Application Name=EdFi.AdminApp;"
            };
            logFile                = @{ "file" = '${ProgramData}\Ed-Fi-ODS-AdminApp\Log-' + "$dbNamePrefix" + ".txt" };
            secretJsonv260         = @{"AdminCredentials.UseIntegratedSecurity" = $true };
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
    foreach ($b in $binaries | Where-Object { ($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments) }) {
        #build destination path for binay. Note: all NuGet packages are zips.
        $downloadUrl = $b.url
        $destPath = "$global:tempPathForBinaries\" + $b.name + "$edfiVersion.zip"
        $expectedHash = $packageVerificationHash[$b.name]
        
        # Optimization (Caching Packages): Check to see if file exists. If it does NOT then download.
        if (!(Test-Path $destPath -PathType Leaf) -Or !(Assert-FileHashIsEqual $expectedHash $destPath)) {
            Write-Host " Downloading (" $downloadUrl ") to -> " $destPath
            Invoke-DownloadFile $downloadUrl $destPath
        }

        # Ensure that the download file is not corrupted. (This could happen in the event there is a )
        Write-Host "Verifying downloaded file integrity (Hash Check)"
        if (!(Assert-FileHashIsEqual $expectedHash $destPath)) {
            Write-Error "Error: File downloaded is corrupt. Please ensure machine does NOT have a firewall, proxy or policy that is preventing this file from being downloaded. To diagnose you can copy the following address into your browser. ($downloadUrl)" -ErrorAction Stop
        }

        #2.1) Once downloaded unzip to install path.
        $installPath = "$installPathForBinaries\" + $b.name
        Write-Host "     Installing '"$b.name"' to -> $installPath"
        Expand-Archive -LiteralPath $destPath -DestinationPath $installPath -Force
    }

    #2.1) Set folder permissions to the installPathForBinaries so that the IIS_IUSRS can (Read & Execute)
    #     Additionally for the AdminApp setup it is necessary to have the IIS_IUSRS (write) permission.
    Write-HostStep "Step: Setting file system permissions"
    Write-Host "     Setting permissions on: $installPathForBinaries"
    Set-PermissionsOnPath $installPathForBinaries "IIS_IUSRS" "ReadAndExecute"
    if ($environment -eq "Production") { Set-PermissionsOnPath "$installPathForBinaries\AdminApp" "IIS_IUSRS" "FullControl" }

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
    foreach ($b in $binaries | Where-Object { ($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments)) }) {
        $appName = $b.name
        $appPhysicalPath = "$installPathForBinaries\" + $b.name
        $applicationIISPath = "$parentSiteName/$virtualDirectoryName/$appName"

        # Create Web Application
        New-WebApplication -Name $appName  -Site "$parentSiteName\$virtualDirectoryName" -PhysicalPath $appPhysicalPath -ApplicationPool $applicationPool -Force

        # Set IIS Authentication settings
        if ($b.iisAuthentication) {
            foreach ($key in $b.iisAuthentication.Keys) {
                Write-Host "     $key  = " $b.iisAuthentication.Item($key)
                Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/$key" -Name Enabled -Value $b.iisAuthentication.Item($key) -PSPath IIS:\ -Location "$applicationIISPath"
            }
        }
    }

    #4) Update Web.config values AppSettings, ConnStrings and Log Files
    Write-HostStep "Step: IIS Configuring Web.Config appSettings, connectionStrings, logfiles & secret.json properties"
    foreach ($b in $binaries | Where-Object { ($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments)) }) {
        $appPhysicalPath = "$installPathForBinaries\" + $b.name + "\Web.Config"

        Write-Host "     Updating " $b.name " web.config..." -ForegroundColor Cyan
        Write-Host "      File @: " $appPhysicalPath

        # Apply global settings
        if ($b.appSettings) { Set-AppSettingsInWebConfig $appPhysicalPath $b.appSettings }
        if ($b.connectionStrings) { Set-ConnectionStringsInWebConfig $appPhysicalPath $b.connectionStrings }
        if ($b.logFile) { Set-Log4NetLogFileInWebConfig $appPhysicalPath $b.logFile }
        if ($b.webConfigTagInsert) { Set-TagInWebConfig $appPhysicalPath $b.webConfigTagInsert }

        # Environment and Version Specifics
        if ($b.envAppSettings) {
            if ($b.envAppSettings[$environment]) { 
                Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings[$environment] 
            }
            else {
                Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings
            }
        }
        if ($b.envConnectionStrings -and $b.envConnectionStrings[$environment]) { Set-ConnectionStringsInWebConfig $appPhysicalPath $b.envConnectionStrings[$environment] }

        if ($b.name -eq "AdminApp") {
            $secretJsonPhysicalPath = "$installPathForBinaries\" + $b.name + "\secret.json"
            Write-Host "     Setting secret JSON to use Integrated Security: " $secretJsonPhysicalPath
            Set-IntegratedSecurityInSecretJsonFile($secretJsonPhysicalPath)
        }

        if ($b.name -eq "Docs") {
            $swaggerDefaultHtmlPath = "$installPathForBinaries\" + $b.name + "\default.html"
            Write-Host "     Setting Swagger Docs path to work with Virtual Directories" $swaggerDefaultHtmlPath
            Set-DocsHTMLPathsToWorkWithVirtualDirectories($swaggerDefaultHtmlPath)
        }
    }

    #5) Restore needed Databases
    Write-HostStep "Step: MsSQL Restoring databases"
    $backupLocation = "$installPathForBinaries\dbs\"
    Restore-EdFiDatabases $binaries $environment $dbNamePrefix $dbNameSufix $backupLocation

    #6) MsSQL Ensure that the "IIS APPPOOL\DefaultAppPool" user has security login and has Server Roles -> sysadmin.
    Add-SQLUser $sqlServerInstance $integratedSecurityUser $integratedSecurityRole

    if ($environment -eq "Sandbox") {
        #Some sites like the Sandbox Admin need to be initiallized and then Web.Config updated.
        Write-HostStep "Step: Post deploy steps."
        if ($environment -eq "Sandbox") { Initialize-Url "$appsBaseUrl/SandboxAdmin" }

        foreach ($b in $binaries | Where-Object { ($_.type -eq "WebApp") -and (($_.requiredInEnvironments.Contains($environment)) -or (!$_.requiredInEnvironments)) }) {
            $appPhysicalPath = "$installPathForBinaries\" + $b.name + "\Web.Config"

            if ($b.webConfigTagPostInstall) { 
                Write-Host "     Updating " $b.name " web.config..." -ForegroundColor Cyan
                Write-Host "      File @: " $appPhysicalPath
                Set-TagInWebConfig $appPhysicalPath $b.webConfigTagPostInstall
            }

            if ($b.webConfigAttributePostInstall) {
                Set-AttributeValueInWebConfig $appPhysicalPath $b.webConfigAttributePostInstall.xPath $b.webConfigAttributePostInstall.attribute $b.webConfigAttributePostInstall.value
            }
        }
    }

    #Final step Copy the html to the IIS root folder
    Write-HostStep "Step: Deploying Ed-Fi default HTML to IIS root"
    Install-EdFiIndexHTML $iisRootFolder

}

Function Set-IntegratedSecurityInSecretJsonFile($jsonFilePath) {
    $a = Get-Content $jsonFilePath -raw | ConvertFrom-Json

    $a.update | % { $a.AdminCredentials.UseIntegratedSecurity = "true" }
    
    $a | ConvertTo-Json -depth 32 | set-content $jsonFilePath
}

Function Set-DocsHTMLPathsToWorkWithVirtualDirectories($swaggerDefaultHtmlPath) {
    $fileContent = Get-Content $swaggerDefaultHtmlPath
    $fileContent[3] += "<base href='docs/' />"
    $fileContent | Set-Content $swaggerDefaultHtmlPath
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
    if (!$allPreReqsInstalled) { Write-Error "Error: Missing Prerequisites. Look above for list." -ErrorAction Stop }
}