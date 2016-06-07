
$thisScriptDir = split-path -parent $MyInvocation.MyCommand.Definition
$env:NODE_PATH="$env:APPDATA\npm\node_modules"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External\git"


$pubTemp = 'C:\temp\publish-out\temp'
if(-not (Test-Path $pubTemp)){ New-Item -Path $pubTemp -ItemType Directory }
$projectDir = "$thisScriptDir\samples\src\StarterWeb"
$packDir = "$pubTemp\$([datetime]::now.Ticks)"

try{
    Set-Location $projectDir
    # create temp dir for packout
    New-Item -Path $packDir -ItemType Directory
    dotnet publish --output $packDir --configuration Release

    # get username and password from a file outside source control
    $secretsFile = "$netconfsecretsroot\2016.netconf\init-starterweb.ps1"
    if(Test-Path ($secretsFile)){
        . $secretsFile
    }
    
    $pubxmlpath=([System.IO.Path]::GetFullPath('.\Properties\PublishProfiles\SayedStarterWeb - Web Deploy.pubxml'))
    & '.\Properties\PublishProfiles\SayedStarterWeb - Web Deploy-publish.ps1' -packOutput $packDir -pubProfilePath 'C:\data\mycode\netconf2016\samples\src\StarterWeb\Properties\PublishProfiles\SayedStarterWeb - Web Deploy.pubxml' -publishproperties @{'Username'=$pubUsername}
}
finally{
    Pop-Location
    if(Test-Path $packDir){
        Remove-Item -Path $packDir -Recurse -ErrorAction SilentlyContinue | Out-Null
    }    
}
