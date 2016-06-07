

function Get-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptDir = Get-ScriptDirectory

$env:NODE_PATH="$env:APPDATA\npm\node_modules"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External\git"

Set-Location (Join-Path $scriptDir 'samples\src\StarterWeb')
dotnet restore
msbuild StarterWeb.xproj /p:DeployOnBuild=$true /p:PublishProfile='SayedStarterWeb - Web Deploy' /p:Username=$env:starterWebPubUsername /p:Password=$env:starterWebPubPassword /p:Configuration=Release