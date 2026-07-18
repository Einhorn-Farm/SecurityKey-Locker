#Requires -Version 5.1
<#
    Builds WindowsLocker using the .NET 10 SDK and publishes a framework-
    dependent executable into the .\publish folder.
#>
[CmdletBinding()]
param(
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$csproj  = Join-Path $root 'WindowsLocker.csproj'
$publish = Join-Path $root 'publish'

$dotnet = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
if (-not (Test-Path $dotnet)) { $dotnet = 'dotnet' }

Write-Host "Publishing WindowsLocker ($Configuration)..."
& $dotnet publish $csproj -c $Configuration -o $publish
if ($LASTEXITCODE -ne 0) {
    throw "Build failed (dotnet exit code $LASTEXITCODE)."
}

Write-Host "Build succeeded: $(Join-Path $publish 'WindowsLocker.exe')"
