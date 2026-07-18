#Requires -Version 5.1
<#
    Stops and removes the WindowsLocker service, its event log source and its
    installed files. Requires administrator rights (self-elevates).
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'WindowsLocker')
)

$ErrorActionPreference = 'Stop'

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevation required - requesting administrator rights..."
    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallDir `"$InstallDir`""
    return
}

$svcName = 'WindowsLocker'

if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
    & sc.exe stop $svcName | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $svcName | Out-Null
    Write-Host "Service '$svcName' removed."
} else {
    Write-Host "Service '$svcName' is not installed."
}

if ([System.Diagnostics.EventLog]::SourceExists($svcName)) {
    Remove-EventLog -Source $svcName
    Write-Host "Event log source '$svcName' removed."
}

if (Test-Path $InstallDir) {
    try {
        Remove-Item -Recurse -Force $InstallDir
        Write-Host "Removed install directory '$InstallDir'."
    } catch {
        Write-Warning "Could not remove '$InstallDir': $($_.Exception.Message)"
    }
}

Write-Host "Uninstall complete." -ForegroundColor Green
