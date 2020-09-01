# 


# 1) Ensure the working directory exists
$pathToWorkingDir = "C:\Ed-Fi\BinaryInstaller\"
Write-Host "Step: Ensuring working path is accessible. ($pathToWorkingDir)"
New-Item -ItemType Directory -Force -Path $pathToWorkingDir


# 2) Download and unzip the github powershell scripts (in zip format)
$packageUrl = "https://github.com/dougloyo/EdFiBinaryInstaller/archive/master.zip"
$outputpath = "$pathToWorkingDir\master.zip"
Invoke-WebRequest -Uri $packageUrl -OutFile $outputpath
Expand-Archive -LiteralPath $outputpath -DestinationPath $pathToWorkingDir -Force

# 3) Execute script
$pathToMainScript = "$pathToWorkingDir\EdFiBinaryInstaller-master\binaryInstall.ps1"
Invoke-Expression -Command $pathToMainScript

