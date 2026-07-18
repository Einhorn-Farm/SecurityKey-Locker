#Requires -Version 5.1
<#
    Installs SecurityKeyLocker as an auto-start Windows service running as
    LocalSystem. Requires administrator rights ONCE (for this install only);
    afterwards the service starts automatically at every boot with no prompt.

    Works in two layouts:
      * Release  - SecurityKeyLocker.exe sits next to this script (no SDK needed).
      * Source   - no prebuilt exe; the script builds it with the .NET SDK.

    Files are copied into %ProgramFiles%\SecurityKeyLocker so the service keeps
    working even if you delete the download/source folder.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'SecurityKeyLocker')
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
$svcName = 'SecurityKeyLocker'

# --- locate the executable to install ---
$srcExe = $null
if (Test-Path (Join-Path $root 'SecurityKeyLocker.exe')) {
    # Release layout: prebuilt exe next to the script.
    $srcExe = Join-Path $root 'SecurityKeyLocker.exe'
}
elseif (Test-Path (Join-Path $root 'publish\SecurityKeyLocker.exe')) {
    # Already-built source layout.
    $srcExe = Join-Path $root 'publish\SecurityKeyLocker.exe'
}
elseif (Test-Path (Join-Path $root 'build.ps1')) {
    # Source layout without a build yet: build it (needs the .NET SDK).
    Write-Host "No prebuilt executable found - building from source..."
    & (Join-Path $root 'build.ps1')
    $srcExe = Join-Path $root 'publish\SecurityKeyLocker.exe'
}
if (-not $srcExe -or -not (Test-Path $srcExe)) {
    throw "Could not find or build SecurityKeyLocker.exe."
}

# --- locate the config file (optional) ---
$srcIni = $null
foreach ($candidate in @((Join-Path $root 'SecurityKeyLocker.ini'), (Join-Path $root 'publish\SecurityKeyLocker.ini'))) {
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
$exePath = Join-Path $InstallDir 'SecurityKeyLocker.exe'
Copy-Item $srcExe $exePath -Force
if ($srcIni) {
    # Don't clobber an existing user-edited config on reinstall.
    $destIni = Join-Path $InstallDir 'SecurityKeyLocker.ini'
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
    DisplayName= "Security Key Locker" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "sc.exe create failed (exit $LASTEXITCODE)." }

& sc.exe description $svcName "Locks the workstation immediately when your USB security key is removed." | Out-Null

# auto-restart the service if it ever crashes
& sc.exe failure $svcName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null

& sc.exe start $svcName | Out-Null
if ($LASTEXITCODE -ne 0) { throw "sc.exe start failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "SecurityKeyLocker installed and running." -ForegroundColor Green
Write-Host "It will now start automatically at every boot - no further prompts."
Write-Host "Remove your security key to test. Logs appear in Event Viewer > Windows Logs > Application (source 'SecurityKeyLocker')."
