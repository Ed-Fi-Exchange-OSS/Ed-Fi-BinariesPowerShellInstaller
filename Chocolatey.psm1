Function Install-Chocolatey(){
    if(!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe"))
    {
        Write-Host "Installing: Cocholatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }else{Write-Host "Skipping: Cocholatey is already installed."}
}