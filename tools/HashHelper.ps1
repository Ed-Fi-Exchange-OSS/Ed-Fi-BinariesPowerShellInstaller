# This file is only used to get the hashes for the binaries and add them to the hash verification
Function Get-BinaryHash {
    $baseFilePath = 'C:\Users\Damian\Downloads'
    $fileName = 'EdFi.Suite3.Ods.SwaggerUI.5.1.0'
    $filePath = "$baseFilePath\$fileName.nupkg"

    Write-Host $filePath
    
    if (!(Test-Path $filePath -PathType Leaf)) {
        Write-Host 'File does not exist'
        return $false 
    }

    $currentFileHash = (Get-FileHash -Path $filePath).Hash
    
    Write-Host $currentFileHash
}

Get-BinaryHash