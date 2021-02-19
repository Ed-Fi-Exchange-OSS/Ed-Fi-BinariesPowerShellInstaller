

function Install-NETSettings($b, $installPathForBinaries, $versionWithNoPeriods, $environment) {
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
        if ($b.envAppSettings[$versionWithNoPeriods][$environment]) { 
            Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods][$environment] 
        }
        else {
            Set-AppSettingsInWebConfig $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods]
        }
    }
    if ($b.envConnectionStrings -and $b.envConnectionStrings[$environment]) { Set-ConnectionStringsInWebConfig $appPhysicalPath $b.envConnectionStrings[$environment] }

    # v2.x
    if ($versionWithNoPeriods -eq "v260") { 
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
}

function Install-NETCoreSettings($b, $installPathForBinaries, $versionWithNoPeriods, $environment) {

    $appPhysicalPath = ""
    if ($b.name -eq 'Dbs') {
        $appPhysicalPath = "$installPathForBinaries\" + $b.name + "\configuration.json"
    }
    else {
        $appPhysicalPath = "$installPathForBinaries\" + $b.name + "\appsettings.json"
    }
    Write-Host "     Updating " $b.name " appsettings.json..." -ForegroundColor Cyan
    Write-Host "      File @: " $appPhysicalPath

    # Apply connection strings
    if ($b.connectionStrings) { Add-CoreConnStringsConfiguration $appPhysicalPath $b.connectionStrings }

   
    if ($b.envConnectionStrings) {
        if ($b.envConnectionStrings -and $b.envConnectionStrings[$environment]) { 
            Add-CoreConnStringsConfiguration $appPhysicalPath $b.envConnectionStrings[$environment] 
        }
        else {
            Add-CoreConnStringsConfiguration $appPhysicalPath $b.envConnectionStrings
        }
    }
    # Apply ApiSettings
    if ($b.coreAppsettings) { Add-CoreAppSettingsConfiguration $appPhysicalPath $b.coreAppsettings }
  
    if ($b.envAppSettings) {
        if ($b.envAppSettings[$versionWithNoPeriods][$environment]) { 
            Add-CoreAppSettingsConfiguration $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods][$environment] 
        }
        else {
            Add-CoreAppSettingsConfiguration $appPhysicalPath $b.envAppSettings[$versionWithNoPeriods]
        }
    }
}

# Region: Web.Config Functions

# dictionarry in this case is a Hash with @{"xPath" = "Value"}
# for example: @{"//initialization" = "<users>....</users>"}
Function Set-TagInWebConfig($webConfigPath, $dictionary) {
    # Load XML File and Content
    $xml = [xml](Get-Content $webConfigPath)

    foreach ($key in $dictionary.Keys) {
        # Select the xPath Node
        $xmlNode = $xml.SelectSingleNode($key)

        # Update content.
        $xmlNode.SetAttribute('enabled', $true)
        $xmlNode.RemoveAttribute('configSource')
        $xmlNode.InnerXML = $dictionary[$key]
    }

    #Once done save.
    $xml.Save($webConfigPath)
}

Function Set-AttributeValueInWebConfig($webConfigPath, $xPath, $attribute, $value) {
    $xml = [xml](Get-Content $webConfigPath)

    # Use XPath to find the appropriate node
    if (($node = $xml.SelectSingleNode($xPath))) {
        Write-Host "       -> Setting '$xPath' $attribute = $value"
        $node.SetAttribute($attribute, $value)
    }

    $xml.Save($webConfigPath)
}

function Add-CoreAppSettingsConfiguration($path, $settings) {
    $appSettingsJson = Get-Content $path -raw | ConvertFrom-Json
    

    foreach ($key in $settings.Keys) {
        if ( [bool]$appSettingsJson.Psobject.Properties.Name -contains $key) {
            $appSettingsJson.update | % { $appSettingsJson.$key = $settings[$key] }
        }
        else {
            $appSettingsJson | Add-Member -MemberType NoteProperty -Name $key -Value $settings[$key]
        }
       
    }

    $appSettingsJson | ConvertTo-Json -depth 32 | set-content $path
}

function Add-CoreConnStringsConfiguration($path, $connSettings) {
    $appSettingsJson = Get-Content $path -raw | ConvertFrom-Json
    

    foreach ($key in $connSettings.Keys) {

        if ( [bool]$appSettingsJson.ConnectionStrings.Psobject.Properties.Name -contains $key) {
            $appSettingsJson.update | % { $appSettingsJson.ConnectionStrings.$key = $connSettings[$key] }
        }
        else {
            $appSettingsJson.ConnectionStrings | Add-Member -MemberType NoteProperty -Name $key -Value $connSettings[$key]
        }
    }

    $appSettingsJson | ConvertTo-Json -depth 32 | set-content $path
}

Function Set-AppSettingsInWebConfig($webConfigPath, $dictionary) {
    $xml = [xml](Get-Content $webConfigPath)

    foreach ($key in $dictionary.Keys) {
        # Use XPath to find the appropriate node
        if (($addKey = $xml.SelectSingleNode("//appSettings/add[@key = '$key']"))) {
            Write-Host "       -> Setting '$key' to value $($dictionary[$key])"
            $addKey.SetAttribute('value', $dictionary[$key])
        }
    }

    $xml.Save($webConfigPath)
}

Function Set-ConnectionStringsInWebConfig($webConfigPath, $connectionStrings) {
    $xml = [xml](Get-Content $webConfigPath)

    foreach ($key in $connectionStrings.Keys) {
        # Use XPath to find the appropriate node
        if (($addKey = $xml.SelectSingleNode("//connectionStrings/add[@name = '$key']"))) {
            Write-Host "       -> Setting '$key' to value $($connectionStrings[$key])"
            $addKey.SetAttribute('connectionString', $connectionStrings[$key])
        }
    }

    $xml.Save($webConfigPath)
}

Function Set-Log4NetLogFileInWebConfig($webConfigPath, $logFile) {
    $xml = [xml](Get-Content $webConfigPath)

    foreach ($key in $logFile.Keys) {
        # Use XPath to find the appropriate node
        if (($addKey = $xml.SelectSingleNode("//log4net/appender/file"))) {
            Write-Host "       -> Setting '$key' to value $($logFile[$key])"
            $addKey.SetAttribute('value', $logFile[$key])
        }
    }

    $xml.Save($webConfigPath)
}
