# YubiKey Locker

[![Release](https://github.com/SpechtLabs/YubiKey-Locker/actions/workflows/release.yml/badge.svg)](https://github.com/SpechtLabs/YubiKey-Locker/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/SpechtLabs/YubiKey-Locker?sort=semver)](https://github.com/SpechtLabs/YubiKey-Locker/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20x64-0078D6.svg)](#requirements)

> Pull your YubiKey, and Windows locks. No hotkey, no habit to remember, no thinking about it.

YubiKey Locker is a tiny Windows service that watches for your security key being unplugged and locks the workstation the instant it disappears. Walk away with your key and the machine is already locked behind you. It installs once, runs as an auto-start background service, and never prompts for admin rights again after setup.

**[Full documentation & getting started →](https://yubikey-locker.specht-labs.de)**

## The problem it solves

Screen-lock discipline relies on you remembering to press Win+L every single time you stand up. You won't, not always, and the one time you forget is the time it matters. Timeout-based auto-lock is the usual fallback, but a five-minute idle timer is five minutes of an unlocked machine sitting unattended.

YubiKey Locker ties the lock to a physical action you already take: removing the key you carry with you. There's nothing to remember and nothing to configure in the common case. The moment the key leaves the port, the session is locked.

It runs as a `LocalSystem` Windows service so it works before and across logins, survives reboots, and needs the one-time UAC prompt only at install. Ships as a single self-contained executable with **no .NET runtime to install** on the target machine.

## Install

Grab the latest `YubiKey-Locker-<version>-win-x64.zip` from the [releases page](https://github.com/SpechtLabs/YubiKey-Locker/releases), extract it, then:

```powershell
# from the extracted folder
./install.ps1
```

Approve the one-time UAC prompt. The service is copied into `%ProgramFiles%\WindowsLocker`, registered as auto-start, and started immediately. That's it — pull your key to test.

To remove it:

```powershell
./uninstall.ps1
```

## How it works

A Windows service lives in *Session 0* and can't lock your interactive desktop directly, so YubiKey Locker does it in two steps:

1. It subscribes to **WMI PnP device-removal events**, filtered to your key's USB vendor id (`1050` = Yubico).
2. On removal it resolves the active console session's user token (`WTSQueryUserToken`) and launches `rundll32 user32.dll,LockWorkStation` in that session via `CreateProcessAsUser`. `LocalSystem` holds the `SeTcbPrivilege` this needs.

Duplicate events from a single unplug are de-bounced, and the lock is fail-safe: if no active session or user token can be resolved, it logs and does nothing rather than misfiring.

## Configuration

Configuration is optional; the defaults match any YubiKey. Settings live in `WindowsLocker.ini` next to the executable (`%ProgramFiles%\WindowsLocker\WindowsLocker.ini`). Edit it, then restart the service.

```ini
# USB Vendor ID (hex, no "0x"). 1050 = Yubico.
VendorId=1050

# Optional USB Product ID (hex). Empty = match ANY device from the vendor.
ProductId=
```

```powershell
# apply changes
sc.exe stop WindowsLocker; sc.exe start WindowsLocker
```

Any USB security key or token works, not just YubiKeys — set `VendorId` to your device's vendor id. Activity is logged to **Event Viewer → Windows Logs → Application** under the source `WindowsLocker`.

## Build from source

Requires the [.NET 10 SDK](https://dotnet.microsoft.com/download).

```powershell
./build.ps1          # publishes to .\publish\WindowsLocker.exe
./install.ps1        # builds if needed, then installs the service
```

Releases are cut by [`.github/workflows/release.yml`](.github/workflows/release.yml), which publishes a self-contained single-file binary on every pushed `v*` tag:

```shell
git tag v1.0.0
git push origin v1.0.0
```

## Requirements

- Windows x64
- Running a release: nothing — the binary is self-contained
- Building from source: .NET 10 SDK

## License

Apache 2.0. See [LICENSE](./LICENSE).
