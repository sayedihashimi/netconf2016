
$thisScriptDir = split-path -parent $MyInvocation.MyCommand.Definition
$env:NODE_PATH="$env:APPDATA\npm\node_modules"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External"
$env:path+=";${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Web\External\git"


$pubTemp = 'C:\temp\publish-out\temp'
if(-not (Test-Path $pubTemp)){ New-Item -Path $pubTemp -ItemType Directory }
$projectDir = "$thisScriptDir\samples\src\StarterWeb"
$packDir = "$pubTemp\$([datetime]::now.Ticks)"

function InstallDotNetCli{
    [cmdletbinding()]
    param()
    process{
        [string]$dotnetInstallUrl = 'https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.ps1'
        $oldloc = Get-Location
        try{
            Set-Location ($slnfile.DirectoryName)
            $tempfile = '{0}.ps1' -f ([System.IO.Path]::GetTempFileName())
            (new-object net.webclient).DownloadFile($dotnetInstallUrl,$tempfile)
            $installArgs = ''
            if(-not ([string]::IsNullOrWhiteSpace($dotnetInstallChannel))){
                $installArgs = '-Channel ' + $dotnetInstallChannel
            }
            Invoke-Expression "& `"$tempfile`" $installArgs"
            $env:path+=";$env:localappdata\Microsoft\dotnet\bin"
            & dotnet --version
            Remove-Item $tempfile -ErrorAction SilentlyContinue
        }
        finally{
            Set-Location $oldloc
        }
    }
}

InstallDotNetCli
dotnet -v
get-command dotnet
function Invoke-CommandString{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [string[]]$command,
        
        [Parameter(Position=1)]
        $commandArgs,

        $ignoreErrors,

        [switch]$disableCommandQuoting
    )
    process{
        foreach($cmdToExec in $command){
            'Executing command [{0}]' -f $cmdToExec | Write-Verbose
            
            # write it to a .cmd file
            $destPath = "$([System.IO.Path]::GetTempFileName()).cmd"
            if(Test-Path $destPath){Remove-Item $destPath|Out-Null}
            
            try{
                $commandstr = $cmdToExec
                if(-not $disableCommandQuoting -and $commandstr.Contains(' ') -and (-not ($commandstr -match '''.*''|".*"' ))){
                    $commandstr = ('"{0}"' -f $commandstr)
                }

                '{0} {1}' -f $commandstr, ($commandArgs -join ' ') | Set-Content -Path $destPath | Out-Null

                $actualCmd = ('"{0}"' -f $destPath)

                cmd.exe /D /C $actualCmd
                
                if(-not $ignoreErrors -and ($LASTEXITCODE -ne 0)){
                    $msg = ('The command [{0}] exited with code [{1}]' -f $commandstr, $LASTEXITCODE)
                    throw $msg
                }
            }
            finally{
                if(Test-Path $destPath){Remove-Item $destPath -ErrorAction SilentlyContinue |Out-Null}
            }
        }
    }
}
try{    
    # create temp dir for packout
    New-Item -Path $packDir -ItemType Directory
    'projDir [{0}]. packDir [{1}]' -f $projectDir,$packDir | Write-Host -ForegroundColor Green
    Set-Location $projectDir
    'before'|Write-Host
    
    # dotnet.exe publish --output $packDir --configuration Release
    Invoke-CommandString -command dotnet -commandArgs 'publish --output $packDir --configuration Release' -ignoreErrors
    
    'after'|Write-Host

    # get username and password from a file outside source control
    $pubUsername=$env:pubUsername
    $pubPassword=$env:pubPassword    
    
    $pubxmlpath=([System.IO.Path]::GetFullPath('.\Properties\PublishProfiles\SayedStarterWeb - Web Deploy.pubxml'))
    & '.\Properties\PublishProfiles\SayedStarterWeb - Web Deploy-publish.ps1' -packOutput $packDir -pubProfilePath 'C:\data\mycode\netconf2016\samples\src\StarterWeb\Properties\PublishProfiles\SayedStarterWeb - Web Deploy.pubxml' -publishproperties @{'Username'=$pubUsername}
}
finally{
    Pop-Location
    if(Test-Path $packDir){
        Remove-Item -Path $packDir -Recurse -ErrorAction SilentlyContinue | Out-Null
    }    
}
