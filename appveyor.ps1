
$scriptDir = split-path -parent $MyInvocation.MyCommand.Definition

$env:NODE_PATH="$env:APPDATA\npm\node_modules"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External\git"
npm install gulp -g
npm install gulp-util -g
Set-Location (Join-Path $scriptDir 'samples\src\StarterWeb')
dotnet restore
msbuild StarterWeb.xproj /p:DeployOnBuild=true /p:PublishProfile='SayedStarterWeb - Web Deploy' /p:Username=$env:starterWebPubUsername /p:Password=$env:starterWebPubPassword /p:Configuration=Release
