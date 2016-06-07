# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties=@{}, $packOutput, $pubProfilePath, $nugetUrl)

# to learn more about this file visit https://go.microsoft.com/fwlink/?LinkId=524327
$publishModuleVersion = '1.1.0'

function Get-PublishModulePath{
    [cmdletbinding()]
    param()
    process{
        $keysToCheck = @('hklm:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\{0}',
                         'hklm:\SOFTWARE\Microsoft\VisualStudio\{0}',
                         'hklm:\SOFTWARE\Wow6432Node\Microsoft\VWDExpress\{0}',
                         'hklm:\SOFTWARE\Microsoft\VWDExpress\{0}'
                         )
        $versions = @('14.0', '15.0')

        [string]$publishModulePath=$null
        :outer foreach($keyToCheck in $keysToCheck){
            foreach($version in $versions){
                if(Test-Path ($keyToCheck -f $version) ){
                    $vsInstallPath = (Get-itemproperty ($keyToCheck -f $version) -Name InstallDir -ErrorAction SilentlyContinue | select -ExpandProperty InstallDir -ErrorAction SilentlyContinue)
                    
                    if($vsInstallPath){
                        $installedPublishModulePath = "{0}Extensions\Microsoft\Web Tools\Publish\Scripts\{1}\" -f $vsInstallPath, $publishModuleVersion
                        if(!(Test-Path $installedPublishModulePath)){
                            $vsInstallPath = $vsInstallPath + 'VWDExpress'
                            $installedPublishModulePath = "{0}Extensions\Microsoft\Web Tools\Publish\Scripts\{1}\" -f  $vsInstallPath, $publishModuleVersion
                        }
                        if(Test-Path $installedPublishModulePath){
                            $publishModulePath = $installedPublishModulePath
                            break outer;
                        }
                    }
                }
            }
        }

        $publishModulePath
    }
}

$publishModulePath = Get-PublishModulePath

$defaultPublishSettings = New-Object psobject -Property @{
    LocalInstallDir = $publishModulePath
}

function Enable-PackageDownloader{
    [cmdletbinding()]
    param(
        $toolsDir = "$env:LOCALAPPDATA\Microsoft\Web Tools\Publish\package-downloader-$publishModuleVersion\",
        $pkgDownloaderDownloadUrl = 'https://go.microsoft.com/fwlink/?LinkId=524325') # package-downloader.psm1
    process{
        if(get-module package-downloader){
            remove-module package-downloader | Out-Null
        }

        if(!(get-module package-downloader)){
            if(!(Test-Path $toolsDir)){ New-Item -Path $toolsDir -ItemType Directory -WhatIf:$false }

            $expectedPath = (Join-Path ($toolsDir) 'package-downloader.psm1')
            if(!(Test-Path $expectedPath)){
                'Downloading [{0}] to [{1}]' -f $pkgDownloaderDownloadUrl,$expectedPath | Write-Verbose
                (New-Object System.Net.WebClient).DownloadFile($pkgDownloaderDownloadUrl, $expectedPath)
            }
        
            if(!$expectedPath){throw ('Unable to download package-downloader.psm1')}

            'importing module [{0}]' -f $expectedPath | Write-Output
            Import-Module $expectedPath -DisableNameChecking -Force
        }
    }
}

function Enable-PublishModule{
    [cmdletbinding()]
    param()
    process{
        if(get-module publish-module){
            remove-module publish-module | Out-Null
        }

        if(!(get-module publish-module)){
            $localpublishmodulepath = Join-Path $defaultPublishSettings.LocalInstallDir 'publish-module.psm1'
            if(Test-Path $localpublishmodulepath){
                'importing module [publish-module="{0}"] from local install dir' -f $localpublishmodulepath | Write-Verbose
                Import-Module $localpublishmodulepath -DisableNameChecking -Force
                $true
            }
        }
    }
}

Add-Type -As System.IO.Compression.FileSystem
function InternalNew-ZipFile {
	#.Synopsis
	#  Create a new zip file, optionally appending to an existing zip...
	[CmdletBinding()]
	param(
		# The path of the zip to create
		[Parameter(Position=0, Mandatory=$true)]
		$ZipFilePath,
 
		# Items that we want to add to the ZipFile
		[Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("PSPath","Item")]
		[string[]]$InputObject = $Pwd,
 
        [string]$rootFolder = $pwd,

        [string]$relpathinzip,

		# Append to an existing zip file, instead of overwriting it
		[Switch]$Append,
 
		# The compression level (defaults to Optimal):
		#   Optimal - The compression operation should be optimally compressed, even if the operation takes a longer time to complete.
		#   Fastest - The compression operation should complete as quickly as possible, even if the resulting file is not optimally compressed.
		#   NoCompression - No compression should be performed on the file.
		[System.IO.Compression.CompressionLevel]$Compression = "Optimal"
	)
	begin {
		# Make sure the folder already exists
		[string]$File = Split-Path $ZipFilePath -Leaf
		[string]$Folder = $(if($Folder = Split-Path $ZipFilePath) { Resolve-Path $Folder } else { $Pwd })
		$ZipFilePath = Join-Path $Folder $File
		# If they don't want to append, make sure the zip file doesn't already exist.
		if(!$Append) {
			if(Test-Path $ZipFilePath) { Remove-Item $ZipFilePath }
		}
		$Archive = [System.IO.Compression.ZipFile]::Open( $ZipFilePath, "Update" )
	}
	process {
        try{
            Set-Location $rootFolder
		    foreach($path in $InputObject) {
			    foreach($item in Resolve-Path $path) {
				    # Push-Location so we can use Resolve-Path -Relative
				    # This will get the file, or all the files in the folder (recursively)
				    foreach($file in Get-ChildItem $item -Recurse -File -Force | % FullName) {
					    # Calculate the relative file path
                        $relative = InternalGet-RelativePath -fromPath $rootFolder -toPath $file
                        if(-not [string]::IsNullOrWhiteSpace($relpathinzip)){
                            $relative = $relpathinzip.TrimEnd('\').TrimEnd('/') + '\' + $relative.TrimEnd('\').TrimEnd('/') + '\'
                        }

					    # Add the file to the zip
					    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $file, $relative, $Compression)
				    }
			    }
		    }
        }
        catch{
            Pop-Location
        }
	}
	end {
		$Archive.Dispose()
		Get-Item $ZipFilePath
	}
}

function InternalGet-RelativePath{
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$fromPath,

        [Parameter(Position=0,Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$toPath
    )
    process{
        $fromPathToUse = (Resolve-Path $fromPath).Path
        if( (Get-Item $fromPathToUse) -is [System.IO.DirectoryInfo]){
            $fromPathToUse += [System.IO.Path]::DirectorySeparatorChar
        }

        $toPathToUse = (Resolve-Path $toPath).Path
        if( (Get-Item $toPathToUse) -is [System.IO.DirectoryInfo]){
            $toPathToUse += [System.IO.Path]::DirectorySeparatorChar
        }

        [uri]$fromUri = New-Object -TypeName 'uri' -ArgumentList $fromPathToUse
        [uri]$toUri = New-Object -TypeName 'uri' -ArgumentList $toPathToUse

        [string]$relPath = $toPath
        # if the Scheme doesn't match just return toPath
        if($fromUri.Scheme -eq $toUri.Scheme){
            [uri]$relUri = $fromUri.MakeRelativeUri($toUri)
            $relPath = [Uri]::UnescapeDataString($relUri.ToString())

            if([string]::Equals($toUri.Scheme, [Uri]::UriSchemeFile, [System.StringComparison]::OrdinalIgnoreCase)){
                $relPath = $relPath.Replace([System.IO.Path]::AltDirectorySeparatorChar,[System.IO.Path]::DirectorySeparatorChar)
            }
        }

        if([string]::IsNullOrWhiteSpace($relPath)){
            $relPath = ('.{0}' -f [System.IO.Path]::DirectorySeparatorChar)
        }

        #'relpath:[{0}]' -f $relPath | Write-verbose

        # return the result here
        $relPath
    }
}


try{

    if (!(Enable-PublishModule)){
        Enable-PackageDownloader
        Enable-NuGetModule -name 'publish-module' -version $publishModuleVersion -nugetUrl $nugetUrl
    }

    'Calling Publish-AspNet' | Write-Verbose
    
    # call Publish-AspNet to perform the publish operation
    Publish-AspNet -publishProperties $publishProperties -packOutput $packOutput -pubProfilePath $pubProfilePath

    $archiveFolder = [System.IO.Path]::GetFullPath((join-path ($publishProperties['publishUrl']) 'archive'))
    if(-not (Test-Path $archiveFolder)){
        New-Item -Path $archiveFolder -ItemType Directory
    }
    $zippath = [System.IO.Path]::GetFullPath((Join-Path $archiveFolder ([datetime]::Now.ToString('yyMMdd.hhmmss.ff.\z\i\p'))))
    $zipfiles = (Get-ChildItem $archiveFolder -Recurse -File).FullName
    '-----------------------------' | Write-Output
    $zipfiles | Write-Output
    '-----------------------------' | Write-Output
    'packout: {0} files: {1} ' -f $packOutput, $zipfiles | Write-Output
    InternalNew-ZipFile -ZipFilePath c:\temp\foo.zip -rootFolder $archiveFolder -InputObject $zipfiles
}
catch{
    "An error occurred during publish.`n{0}" -f $_.Exception.Message | Write-Error
}