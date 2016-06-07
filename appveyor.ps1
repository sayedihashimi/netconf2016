

function Get-ScriptDirectory{
    split-path (((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path)
}
$scriptDir = Get-ScriptDirectory

$env:NODE_PATH="$env:APPDATA\npm\node_modules"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External\git"
npm install gulp -g
npm install gulp-util -g
Set-Location (Join-Path $scriptDir 'samples\src\StarterWeb')
dotnet restore
#msbuild StarterWeb.xproj /p:DeployOnBuild=true /p:PublishProfile='SayedStarterWeb - Web Deploy' /p:Username=$env:starterWebPubUsername /p:Password=$env:starterWebPubPassword /p:Configuration=Release

<#
.SYNOPSIS
    You can add this to you build script to ensure that psbuild is available before calling
    Invoke-MSBuild. If psbuild is not available locally it will be downloaded automatically.
#>
function EnsurePsbuildInstlled{
    [cmdletbinding()]
    param(
        # TODO: Change to master when 1.1.9 gets there
        [string]$psbuildInstallUri = 'https://raw.githubusercontent.com/ligershark/psbuild/dev/src/GetPSBuild.ps1',

        [System.Version]$minVersion = (New-Object -TypeName 'system.version' -ArgumentList '1.1.9.1')
    )
    process{
        # see if there is already a version loaded
        $psbuildNeedsInstall = $true
        [System.Version]$installedVersion = $null
        try{
            Import-Module psbuild -ErrorAction SilentlyContinue | Out-Null
            $installedVersion = Get-PSBuildVersion
        }
        catch{
            $installedVersion = $null
        }

        if( ($installedVersion -ne $null) -and ($installedVersion.CompareTo($minVersion) -ge 0) ){
            'Skipping psbuild install because version [{0}] detected' -f $installedVersion.ToString() | Write-Verbose
        }
        else{
            'Installing psbuild from [{0}]' -f $psbuildInstallUri | Write-Verbose
            (new-object Net.WebClient).DownloadString($psbuildInstallUri) | iex

            # make sure it's loaded and throw if not
            if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
                throw ('Unable to install/load psbuild from [{0}]' -f $psbuildInstallUri)
            }
        }
    }
}

EnsurePsbuildInstlled
$buildProps = @{
    'DeployOnBuild'='true'
    'PublishProfile'='SayedStarterWeb - Web Deploy'
    'Username'=$env:starterWebPubUsername
    'Configuration'='Release'
    'WebPublishMethod'='MSDeploy'
}
$projFile = "$scriptDir\samples\src\StarterWeb\StarterWeb.xproj"
Invoke-MSBuild -projectsToBuild $projFile -properties $buildProps -password $env:starterWebPubPassword 