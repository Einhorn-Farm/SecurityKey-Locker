using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;

namespace WindowsLocker
{
    /// <summary>
    /// Background worker: watches for removal of the configured security key
    /// and locks the interactive workstation session when it disappears.
    /// </summary>
    public sealed class LockerWorker : BackgroundService
    {
        // Ignore duplicate removal events fired for the same physical unplug
        // (a single YubiKey exposes several PnP entities: HID, smartcard, FIDO...).
        private static readonly TimeSpan DebounceWindow = TimeSpan.FromSeconds(3);

        private readonly object _lock = new object();
        private DeviceRemovalWatcher _watcher;
        private DateTime _lastLockUtc = DateTime.MinValue;

        protected override Task ExecuteAsync(CancellationToken stoppingToken)
        {
            AppConfig config = AppConfig.Load();
            Logger.Info(string.Format(
                "Starting. Watching for removal of USB device VID_{0}{1}.",
                config.VendorId,
                string.IsNullOrEmpty(config.ProductId) ? string.Empty : ("&PID_" + config.ProductId)));

            _watcher = new DeviceRemovalWatcher(config, OnSecurityKeyRemoved);
            _watcher.Start();

            // Nothing to loop over here - WMI delivers events on its own threads.
            return Task.CompletedTask;
        }

        public override Task StopAsync(CancellationToken cancellationToken)
        {
            if (_watcher != null)
            {
                _watcher.Dispose();
                _watcher = null;
            }
            Logger.Info("Stopped.");
            return base.StopAsync(cancellationToken);
        }

        private void OnSecurityKeyRemoved(string deviceId)
        {
            lock (_lock)
            {
                DateTime now = DateTime.UtcNow;
                if (now - _lastLockUtc < DebounceWindow)
                {
                    return; // duplicate event from the same unplug
                }
                _lastLockUtc = now;
            }

            Logger.Info("Security key removed (" + deviceId + ") -> locking workstation.");
            try
            {
                SessionLocker.LockActiveSession();
            }
            catch (Exception ex)
            {
                Logger.Error("Failed to lock workstation: " + ex);
            }
        }
    }
}
