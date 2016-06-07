# Copyright (c) Microsoft Open Technologies, Inc. All rights reserved.
# Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

[cmdletbinding(SupportsShouldProcess=$true)]
param($publishProperties=@{}, $packOutput, $pubProfilePath, $nugetUrl)

'*** Publish properties:' | Write-Output
foreach($key in $publishProperties.Keys){
    '{0}={1}' -f $key,$publishProperties[$key] | Write-Output
}

'*** Publish properties as json' | Write-Output
$publishProperties | ConvertTo-Json -Depth 4 | Write-Output
