
$thisScriptDir = split-path -parent $MyInvocation.MyCommand.Definition

$pubTemp = 'C:\temp\publish-out\temp'
if(-not (Test-Path $pubTemp)){ New-Item -Path $pubTemp -ItemType Directory }

$extraFilesDir = "$thisScriptDir\samples\src\ExtraFiles"
$packDir = "$pubTemp\$([datetime]::now.Ticks)"
try{
    Set-Location $extraFilesDir
    # create temp dir for packout
    New-Item -Path $packDir -ItemType Directory
    dotnet publish --output $packDir --configuration Release

    & .\Properties\PublishProfiles\ToFileSys-publish.ps1 -packOutput $packDir -pubProfilePath '.\Properties\PublishProfiles\ToFileSys.pubxml'
}
finally{
    if(Test-Path $packDir){
        Remove-Item -Path $packDir -Recurse -ErrorAction SilentlyContinue | Out-Null
    }
    Pop-Location
}
