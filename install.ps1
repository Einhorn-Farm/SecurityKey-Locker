#Requires -Version 5.1
<#
    Installs WindowsLocker as an auto-start Windows service running as
    LocalSystem. Requires administrator rights ONCE (for this install only);
    afterwards the service starts automatically at every boot with no prompt.

    Works in two layouts:
      * Release  - WindowsLocker.exe sits next to this script (no SDK needed).
      * Source   - no prebuilt exe; the script builds it with the .NET SDK.

    Files are copied into %ProgramFiles%\WindowsLocker so the service keeps
    working even if you delete the download/source folder.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'WindowsLocker')
)

$ErrorActionPreference = 'Stop'

# --- self-elevate if not already admin ---
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevation required - requesting administrator rights..."
    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallDir `"$InstallDir`""
    return
}

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$svcName = 'WindowsLocker'

# --- locate the executable to install ---
$srcExe = $null
if (Test-Path (Join-Path $root 'WindowsLocker.exe')) {
    # Release layout: prebuilt exe next to the script.
    $srcExe = Join-Path $root 'WindowsLocker.exe'
}
elseif (Test-Path (Join-Path $root 'publish\WindowsLocker.exe')) {
    # Already-built source layout.
    $srcExe = Join-Path $root 'publish\WindowsLocker.exe'
}
elseif (Test-Path (Join-Path $root 'build.ps1')) {
    # Source layout without a build yet: build it (needs the .NET SDK).
    Write-Host "No prebuilt executable found - building from source..."
    & (Join-Path $root 'build.ps1')
    $srcExe = Join-Path $root 'publish\WindowsLocker.exe'
}
if (-not $srcExe -or -not (Test-Path $srcExe)) {
    throw "Could not find or build WindowsLocker.exe."
}

# --- locate the config file (optional) ---
$srcIni = $null
foreach ($candidate in @((Join-Path $root 'WindowsLocker.ini'), (Join-Path $root 'publish\WindowsLocker.ini'))) {
    if (Test-Path $candidate) { $srcIni = $candidate; break }
}

# --- stop/remove any previous instance BEFORE overwriting files ---
if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
    Write-Host "Existing service found - reinstalling..."
    & sc.exe stop $svcName | Out-Null
    Start-Sleep -Seconds 2
    & sc.exe delete $svcName | Out-Null
    Start-Sleep -Seconds 1
}

# --- copy files into the stable install location ---
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$exePath = Join-Path $InstallDir 'WindowsLocker.exe'
Copy-Item $srcExe $exePath -Force
if ($srcIni) {
    # Don't clobber an existing user-edited config on reinstall.
    $destIni = Join-Path $InstallDir 'WindowsLocker.ini'
    if (-not (Test-Path $destIni)) { Copy-Item $srcIni $destIni -Force }
}
Write-Host "Installed files to $InstallDir"

# --- event log source ---
if (-not [System.Diagnostics.EventLog]::SourceExists($svcName)) {
    New-EventLog -LogName Application -Source $svcName
    Write-Host "Created event log source '$svcName'."
}

# --- create service (LocalSystem = has SeTcbPrivilege needed to lock session) ---
& sc.exe create $svcName binPath= "$exePath" start= auto obj= LocalSystem `
    DisplayName= "Windows Locker (YubiKey)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "sc.exe create failed (exit $LASTEXITCODE)." }

& sc.exe description $svcName "Locks the workstation immediately when your YubiKey / security key is removed." | Out-Null

# auto-restart the service if it ever crashes
& sc.exe failure $svcName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null

& sc.exe start $svcName | Out-Null
if ($LASTEXITCODE -ne 0) { throw "sc.exe start failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "WindowsLocker installed and running." -ForegroundColor Green
Write-Host "It will now start automatically at every boot - no further prompts."
Write-Host "Remove your YubiKey to test. Logs appear in Event Viewer > Windows Logs > Application (source 'WindowsLocker')."
