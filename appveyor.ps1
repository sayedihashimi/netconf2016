

function Get-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptDir = Get-ScriptDirectory


Set-Location (Join-Path $scriptDir 'samples\src\StarterWeb')
dotnet restore
msbuild StarterWeb.xproj /p:DeployOnBuild=$true /p:PublishProfile='SayedStarterWeb - Web Deploy' /p:Username=$env:starterWebPubUsername /p:Password=$env:starterWebPubPassword /p:Configuration=Release