# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

############################################################
 
# Author: Douglas Loyo, Sr. Solutions Architect @ MSDF
 
# Description: Module contains a collection of SSL utility functions.

# Note: This powershell has to be ran with Elevated Permissions (As Administrator) and in a x64 environment.

############################################################
Function Install-TrustedSSLCertificate()
{
    $certFriendlyName = 'Ed-Fi localhost SSL'
    
    # See if we already have it installed.
    If($cert = Get-EdFiSSLCertInstalled $certFriendlyName){
        Write-Host "     Skipping: Certificate '$certFriendlyName' already exists."
        return $cert
    }

    Write-Host "Installing: '$certFriendlyName' certificate in Cert:\LocalMachine\My and then in Cert:\LocalMachine\Root"
    #Create self signed certificate
    $params = @{
                  DnsName = "localhost"
                  NotAfter = (Get-Date).AddYears(10)
                  CertStoreLocation = 'Cert:\LocalMachine\My'
                  KeyExportPolicy = 'Exportable'
                  FriendlyName = $certFriendlyName
                  KeyFriendlyName = $certFriendlyName
                  KeyDescription = 'This is a self signed certificate for running the Ed-Fi ODS\API and tools on the local IIS with a valid SSL.'
               }

    # Create certificate
    $selfSignedCert = New-SelfSignedCertificate @params
    
    # New certificates can only be installed into MY store. So lets export it and import it into LocalMachine\Root
    # We need to import into LocalMachine\Root so that its a valid trusted SSL certificate.
    $certPath = $global:tempPathForBinaries + "edfiLocalhostSSL.crt"
    Export-Certificate -Cert $selfSignedCert -FilePath $certPath
    $certInRoot = Import-Certificate -CertStoreLocation 'Cert:\LocalMachine\Root' -FilePath $certPath
    $certInRoot.FriendlyName = $certFriendlyName

    return $selfSignedCert
}

Function Get-EdFiSSLCertInstalled($certificateFriendlyName)
{
    $certificates = Get-ChildItem Cert:\LocalMachine\My

    foreach($cert in $certificates)
    {
        if($cert.FriendlyName -eq $certificateFriendlyName){ return $cert; }
    }

    return $null;
}