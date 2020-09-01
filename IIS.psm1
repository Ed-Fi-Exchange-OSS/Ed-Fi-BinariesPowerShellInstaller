############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of IIS - Internet Information Services utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################
Function Install-IISPrerequisites() {
    $allPreReqsInstalled = $true;
    # Throw this infront 'IIS-ASP', to make fail.
    $prereqs = @('IIS-WebServerRole','IIS-WebServer','IIS-CommonHttpFeatures','IIS-HttpErrors','IIS-ApplicationDevelopment','NetFx4Extended-ASPNET45','IIS-NetFxExtensibility45','IIS-HealthAndDiagnostics','IIS-HttpLogging','IIS-Security','IIS-RequestFiltering','IIS-Performance','IIS-WebServerManagementTools','IIS-ManagementConsole','IIS-BasicAuthentication','IIS-WindowsAuthentication','IIS-StaticContent','IIS-DefaultDocument','IIS-ISAPIExtensions','IIS-ISAPIFilter','IIS-HttpCompressionStatic','IIS-ASPNET45');
    # 'IIS-IIS6ManagementCompatibility','IIS-Metabase', 'IIS-HttpRedirect', 'IIS-LoggingLibraries','IIS-RequestMonitor''IIS-HttpTracing','IIS-WebSockets', 'IIS-ApplicationInit'?

    Write-Host "Ensuring all IIS prerequisites are already installed."
    foreach($p in $prereqs)
    {
        if((Get-WindowsOptionalFeature -Online -FeatureName $p).State -eq "Disabled") { $allPreReqsInstalled = $false; Write-Host "Prerequisite not installed: $p" }
    }

    if($allPreReqsInstalled){ Write-Host "Skipping: All IIS prerequisites are already installed." }
    else { Enable-WindowsOptionalFeature -Online -FeatureName $prereqs }
}

Function Install-SSLCertOnIIS(){
    $certThumbprint = (Install-TrustedSSLCertificate).Thumbprint
    Write-Host "     Found cert" $certThumbprint
    $siteName = "Default Web Site"
    $binding = Get-WebBinding -Name $siteName -Protocol "https"
    if(!$binding) {
        Write-Host "     No https binding defined on IIS"
        New-WebBinding -Name $siteName -IP "*" -Port 443 -Protocol https
        $binding = Get-WebBinding -Name $siteName -Protocol "https"
    }
    $binding.AddSslCertificate($certThumbprint,"my")    
}

Function Install-IISUrlRewrite() {
# URLRewrite Module (File exists or Registry entry?)
    if(!(Test-Path "$env:SystemRoot\system32\inetsrv\rewrite.dll")) { 
        Write-Host "     Installing: Url-Rewrite Module..."
        choco install urlrewrite /y    
    }else { Write-Host "     Skipping: UrlRewrite module is already installed." }
}

Function IsNetVersionInstalled($major, $minor){
    $DotNetInstallationInfo = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse
    $InstalledDotNetVersions = $DotNetInstallationInfo | Get-ItemProperty -Name 'Version' -ErrorAction SilentlyContinue
    $InstalledVersionNumbers = $InstalledDotNetVersions | ForEach-Object {$_.Version -as [System.Version]}
    #$InstalledVersionNumbers;
    $Installed3Point5Versions = $InstalledVersionNumbers | Where-Object {$_.Major -eq $major -and $_.Minor -eq $minor}
    $DotNet3Point5IsInstalled = $Installed3Point5Versions.Count -ge 1
    return $DotNet3Point5IsInstalled
}

Function Install-NetFramework48() {
    if(!(IsNetVersionInstalled 4 8)){
        Write-Host "     Installing: .Net Version 4.8"
        choco install dotnetfx -y
        # Will need to restart so lets give the user a message and exit here.
        Write-BigMessage ".Net Framework Requires a Restart" "Please restart this computer and re run the install."
        Write-Error "Please Restart" -ErrorAction Stop
    }else{ Write-Host "     Skiping: .Net Version 4.8 as it is already installed." }
}